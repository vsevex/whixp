import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as path;

import 'package:whixp/src/exception.dart';
import 'package:whixp/src/log/log.dart';
import 'package:whixp/src/session.dart';
import 'package:whixp/src/stanza/stanza.dart';

part 'controller.g.dart';

/// Table for storing Stream Management state.
class SMStateEntries extends Table {
  /// JID (Jabber ID) - primary key
  TextColumn get jid => text()();

  /// Stream Management ID
  TextColumn get smId => text()();

  /// Sequence number
  IntColumn get sequence => integer()();

  /// Handled count
  IntColumn get handled => integer()();

  /// Last acknowledgment
  IntColumn get lastAck => integer()();

  @override
  Set<Column> get primaryKey => {jid};
}

/// Table for storing unacked stanzas.
class UnackedStanzaEntries extends Table {
  /// Sequence number - primary key
  IntColumn get sequence => integer()();

  /// XML string of the stanza
  TextColumn get xml => text()();

  @override
  Set<Column> get primaryKey => {sequence};
}

/// Drift database definition.
@DriftDatabase(tables: [SMStateEntries, UnackedStanzaEntries])
class WhixpDatabase extends _$WhixpDatabase {
  WhixpDatabase(super.e);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (Migrator m) => m.createAll(),
      );
}

/// Manages interaction with Drift (SQLite) database for storing key-value pairs.
///
/// Each instance manages its own database, allowing multiple Transport
/// instances to use separate databases via the [path] parameter.
/// Supports proper error handling, concurrent access via SQLite, and
/// multiple instances.
class DatabaseController {
  /// The database path used by this controller instance.
  final String? _path;

  /// Drift database instance.
  WhixpDatabase? _database;

  /// Whether the database is initialized.
  bool _initialized = false;

  /// Lock for initialization to prevent race conditions.
  final _initLock = Completer<void>();
  bool _isInitializing = false;

  /// Constructs a [DatabaseController] with an optional database path.
  ///
  /// If [path] is provided, the database will be stored at the specified
  /// path. Each instance with a different path will use separate databases.
  /// If [path] is null, uses the application's default data directory.
  DatabaseController([this._path]);

  /// Initializes the database with retry logic and proper error handling.
  ///
  /// Handles initialization failures gracefully by retrying with exponential
  /// backoff. If the database is already initialized, returns immediately.
  ///
  /// Throws [DatabaseException] if initialization fails after all retries.
  Future<void> initialize({int maxRetries = 5}) async {
    if (_initialized && _database != null) {
      Log.instance.debug('Database is already initialized');
      return;
    }

    // Prevent concurrent initialization
    if (_isInitializing) {
      await _initLock.future;
      return;
    }

    _isInitializing = true;
    _initLock.complete();

    int attempt = 0;
    Duration delay = const Duration(milliseconds: 100);
    Exception? lastException;

    while (attempt < maxRetries) {
      try {
        final dbPath = await _getDatabasePath();
        final dbFile = File(path.join(dbPath, _getDatabaseName()));

        // Ensure directory exists
        final dbDir = Directory(dbPath);
        if (!await dbDir.exists()) {
          await dbDir.create(recursive: true);
        }

        // Create Drift database with native executor
        final executor =
            LazyDatabase(() => NativeDatabase.createInBackground(dbFile));

        _database = WhixpDatabase(executor);

        // Verify connection by running a simple query
        await _database!.customSelect('SELECT 1', readsFrom: {}).get();

        _initialized = true;
        Log.instance.debug('Database initialized at: ${dbFile.path}');
        return;
      } on DatabaseException catch (e) {
        lastException = e;
        attempt++;
        if (attempt >= maxRetries) {
          Log.instance.error(
            'Failed to initialize database after $maxRetries attempts: ${e.message}',
          );
          throw DatabaseException(
            'Database initialization failed: ${e.message}',
            originalException: e,
          );
        }
        Log.instance.warning(
          'Database initialization failed, retrying in ${delay.inMilliseconds}ms '
          '(attempt $attempt/$maxRetries): ${e.message}',
        );
        await Future.delayed(delay);
        delay = Duration(milliseconds: delay.inMilliseconds * 2);
      } catch (e) {
        lastException = e is Exception ? e : Exception(e.toString());
        Log.instance
            .error('Unexpected error during database initialization: $e');
        throw DatabaseException(
          'Unexpected database error: $e',
          originalException: lastException,
        );
      }
    }

    // Should never reach here, but handle it just in case
    throw DatabaseException(
      'Database initialization failed after $maxRetries attempts',
      originalException: lastException,
    );
  }

  /// Gets the database directory path.
  Future<String> _getDatabasePath() async {
    if (_path != null && _path.isNotEmpty) {
      return _path;
    }

    // Use platform-specific default directory
    try {
      if (Platform.isWindows) {
        final appData = Platform.environment['APPDATA'];
        if (appData != null) {
          return path.join(appData, 'whixp');
        }
      } else if (Platform.isMacOS) {
        final home = Platform.environment['HOME'];
        if (home != null) {
          return path.join(home, 'Library', 'Application Support', 'whixp');
        }
      } else if (Platform.isLinux) {
        final home = Platform.environment['HOME'];
        if (home != null) {
          return path.join(home, '.local', 'share', 'whixp');
        }
      }
      // Fallback to current directory
      return path.join(Directory.current.path, 'whixp');
    } catch (e) {
      Log.instance.warning(
        'Failed to determine application support directory: $e. Using current directory.',
      );
      return path.join(Directory.current.path, 'whixp');
    }
  }

  /// Generates a unique database name based on the path.
  ///
  /// If no path is provided, uses the default database name.
  /// Otherwise, creates a unique name by hashing the path.
  String _getDatabaseName() {
    if (_path == null || _path.isEmpty) {
      return 'whixp.db';
    }
    // Create a unique database name by incorporating the path
    final pathHash = _path.hashCode.toRadixString(36);
    return 'whixp_$pathHash.db';
  }

  /// Ensures the database is initialized before operations.
  void _ensureInitialized() {
    if (!_initialized || _database == null) {
      throw DatabaseException(
        'Database not initialized. Call initialize() first.',
      );
    }
  }

  /// Writes Stream Management state to the database.
  ///
  /// [jid] is the key (JID) associated with the provided [state].
  /// Returns a [Future] that completes when the write is done.
  ///
  /// Throws [DatabaseException] if the write fails.
  Future<void> writeToSMBox(String jid, Map<String, dynamic> state) async {
    _ensureInitialized();

    try {
      final smState = SMState.fromJson(state);

      await _database!.into(_database!.sMStateEntries).insertOnConflictUpdate(
            SMStateEntriesCompanion.insert(
              jid: jid,
              smId: smState.id,
              sequence: smState.sequence,
              handled: smState.handled,
              lastAck: smState.lastAck,
            ),
          );
    } catch (e) {
      Log.instance.error('Failed to write SM state for JID $jid: $e');
      throw DatabaseException(
        'Failed to write SM state: $e',
        originalException: e is Exception ? e : Exception(e.toString()),
      );
    }
  }

  /// Reads Stream Management state from the database.
  ///
  /// [jid] is the key (JID) associated with the state to be read.
  /// Returns a [Future] that completes with the [SMState] associated with [jid],
  /// or `null` if [jid] does not exist in the database.
  ///
  /// Throws [DatabaseException] if the read fails.
  Future<SMState?> readFromSMBox(String jid) async {
    _ensureInitialized();

    try {
      final query = _database!.select(_database!.sMStateEntries)
        ..where((tbl) => tbl.jid.equals(jid));

      final entry = await query.getSingleOrNull();

      if (entry == null) {
        return null;
      }

      return SMState(
        entry.smId,
        entry.sequence,
        entry.handled,
        entry.lastAck,
      );
    } catch (e) {
      Log.instance.error('Failed to read SM state for JID $jid: $e');
      throw DatabaseException(
        'Failed to read SM state: $e',
        originalException: e is Exception ? e : Exception(e.toString()),
      );
    }
  }

  /// Writes an unacked stanza to the database.
  ///
  /// [sequence] is the key (sequence number) associated with the [stanza].
  /// Returns a [Future] that completes when the write is done.
  ///
  /// Throws [DatabaseException] if the write fails.
  Future<void> writeUnackeds(int sequence, Stanza stanza) async {
    _ensureInitialized();

    try {
      await _database!
          .into(_database!.unackedStanzaEntries)
          .insertOnConflictUpdate(
            UnackedStanzaEntriesCompanion.insert(
              sequence: Value(sequence),
              xml: stanza.toXMLString(),
            ),
          );
      // Update cache
      _cachedUnackeds ??= <int, String>{};
      _cachedUnackeds![sequence] = stanza.toXMLString();
    } catch (e) {
      Log.instance
          .error('Failed to write unacked stanza for sequence $sequence: $e');
      throw DatabaseException(
        'Failed to write unacked stanza: $e',
        originalException: e is Exception ? e : Exception(e.toString()),
      );
    }
  }

  /// Cached unacked stanzas for synchronous access.
  Map<int, String>? _cachedUnackeds;

  /// Gets all unacked stanzas from the database.
  ///
  /// Returns a [Map] where keys are sequence numbers and values are XML strings,
  /// or `null` if the database is not initialized.
  ///
  /// Note: This getter returns cached data. To refresh, call [refreshUnackedsCache].
  /// For async access with fresh data, use [getUnackedsAsync].
  Map<dynamic, String>? get unackeds {
    if (!_initialized || _database == null) {
      return null;
    }
    return _cachedUnackeds;
  }

  /// Refreshes the cached unacked stanzas.
  ///
  /// Call this method to update the cache before accessing [unackeds].
  Future<void> refreshUnackedsCache() async {
    _ensureInitialized();

    try {
      final entries =
          await _database!.select(_database!.unackedStanzaEntries).get();
      _cachedUnackeds = <int, String>{};

      for (final entry in entries) {
        _cachedUnackeds![entry.sequence] = entry.xml;
      }
    } catch (e) {
      Log.instance.error('Failed to refresh unacked stanzas cache: $e');
      throw DatabaseException(
        'Failed to refresh unacked stanzas cache: $e',
        originalException: e is Exception ? e : Exception(e.toString()),
      );
    }
  }

  /// Gets all unacked stanzas from the database asynchronously.
  ///
  /// Returns a [Map] where keys are sequence numbers and values are XML strings,
  /// or an empty map if none exist.
  ///
  /// Throws [DatabaseException] if the read fails.
  Future<Map<int, String>> getUnackedsAsync() async {
    _ensureInitialized();

    try {
      final entries =
          await _database!.select(_database!.unackedStanzaEntries).get();
      final result = <int, String>{};

      for (final entry in entries) {
        result[entry.sequence] = entry.xml;
      }

      // Update cache
      _cachedUnackeds = result;

      return result;
    } catch (e) {
      Log.instance.error('Failed to read unacked stanzas: $e');
      throw DatabaseException(
        'Failed to read unacked stanzas: $e',
        originalException: e is Exception ? e : Exception(e.toString()),
      );
    }
  }

  /// Pops the first unacked stanza from the database (FIFO order).
  ///
  /// Returns the XML string of the popped stanza, or `null` if no stanzas exist.
  ///
  /// Note: This is a synchronous method that uses cached data.
  /// The database is updated asynchronously in the background.
  /// For guaranteed database consistency, use [popUnackedAsync] instead.
  String? popUnacked() {
    if (!_initialized || _database == null) {
      return null;
    }

    // Use cached data for synchronous access
    if (_cachedUnackeds == null || _cachedUnackeds!.isEmpty) {
      // Try to refresh cache if it's null
      refreshUnackedsCache().catchError((e) {
        Log.instance.warning('Failed to refresh unackeds cache: $e');
      });
      return null;
    }

    // Get the lowest sequence number
    final minSequence = _cachedUnackeds!.keys.reduce((a, b) => a < b ? a : b);
    final xml = _cachedUnackeds![minSequence];

    // Remove from cache immediately
    _cachedUnackeds!.remove(minSequence);

    // Delete from database asynchronously (fire and forget)
    _database!.delete(_database!.unackedStanzaEntries)
      ..where((t) => t.sequence.equals(minSequence))
      ..go().catchError((e) {
        Log.instance.warning('Failed to delete unacked stanza from DB: $e');
        // Re-add to cache if deletion failed
        _cachedUnackeds![minSequence] = xml!;
        return Future.value(0);
      });

    return xml;
  }

  /// Pops the first unacked stanza from the database asynchronously (FIFO order).
  ///
  /// Returns the XML string of the popped stanza, or `null` if no stanzas exist.
  ///
  /// Throws [DatabaseException] if the operation fails.
  Future<String?> popUnackedAsync() async {
    _ensureInitialized();

    try {
      // Get the entry with the lowest sequence number
      final query = _database!.select(_database!.unackedStanzaEntries)
        ..orderBy([(t) => OrderingTerm.asc(t.sequence)])
        ..limit(1);

      final entry = await query.getSingleOrNull();

      if (entry == null) {
        // Update cache
        _cachedUnackeds = {};
        return null;
      }

      final xml = entry.xml;

      // Delete the entry
      await (_database!.delete(_database!.unackedStanzaEntries)
            ..where((t) => t.sequence.equals(entry.sequence)))
          .go();

      // Update cache
      _cachedUnackeds?.remove(entry.sequence);

      return xml;
    } catch (e) {
      Log.instance.error('Failed to pop unacked stanza: $e');
      throw DatabaseException(
        'Failed to pop unacked stanza: $e',
        originalException: e is Exception ? e : Exception(e.toString()),
      );
    }
  }

  /// Closes the database and releases resources.
  ///
  /// Should be called when the controller is no longer needed.
  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
      _initialized = false;
      Log.instance.debug('Database closed');
    }
  }

  /// Clears all data from the database (useful for testing or reset).
  ///
  /// Throws [DatabaseException] if the operation fails.
  Future<void> clear() async {
    _ensureInitialized();

    try {
      await _database!.delete(_database!.sMStateEntries).go();
      await _database!.delete(_database!.unackedStanzaEntries).go();
      Log.instance.debug('Database cleared');
    } catch (e) {
      Log.instance.error('Failed to clear database: $e');
      throw DatabaseException(
        'Failed to clear database: $e',
        originalException: e is Exception ? e : Exception(e.toString()),
      );
    }
  }
}

/// Exception thrown by [DatabaseController] for database-related errors.
class DatabaseException extends WhixpException {
  /// The original exception that caused this error, if any.
  final Exception? originalException;

  /// Creates a [DatabaseException] with the given [message] and optional
  /// [originalException].
  DatabaseException(
    super.message, {
    this.originalException,
  });

  @override
  String toString() {
    if (originalException != null) {
      return 'DatabaseException: $message\nOriginal: $originalException';
    }
    return 'DatabaseException: $message';
  }
}
