// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'controller.dart';

// ignore_for_file: type=lint
class $SMStateEntriesTable extends SMStateEntries
    with TableInfo<$SMStateEntriesTable, SMStateEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SMStateEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _jidMeta = const VerificationMeta('jid');
  @override
  late final GeneratedColumn<String> jid = GeneratedColumn<String>(
      'jid', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _smIdMeta = const VerificationMeta('smId');
  @override
  late final GeneratedColumn<String> smId = GeneratedColumn<String>(
      'sm_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _sequenceMeta =
      const VerificationMeta('sequence');
  @override
  late final GeneratedColumn<int> sequence = GeneratedColumn<int>(
      'sequence', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _handledMeta =
      const VerificationMeta('handled');
  @override
  late final GeneratedColumn<int> handled = GeneratedColumn<int>(
      'handled', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _lastAckMeta =
      const VerificationMeta('lastAck');
  @override
  late final GeneratedColumn<int> lastAck = GeneratedColumn<int>(
      'last_ack', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [jid, smId, sequence, handled, lastAck];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 's_m_state_entries';
  @override
  VerificationContext validateIntegrity(Insertable<SMStateEntry> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('jid')) {
      context.handle(
          _jidMeta, jid.isAcceptableOrUnknown(data['jid']!, _jidMeta));
    } else if (isInserting) {
      context.missing(_jidMeta);
    }
    if (data.containsKey('sm_id')) {
      context.handle(
          _smIdMeta, smId.isAcceptableOrUnknown(data['sm_id']!, _smIdMeta));
    } else if (isInserting) {
      context.missing(_smIdMeta);
    }
    if (data.containsKey('sequence')) {
      context.handle(_sequenceMeta,
          sequence.isAcceptableOrUnknown(data['sequence']!, _sequenceMeta));
    } else if (isInserting) {
      context.missing(_sequenceMeta);
    }
    if (data.containsKey('handled')) {
      context.handle(_handledMeta,
          handled.isAcceptableOrUnknown(data['handled']!, _handledMeta));
    } else if (isInserting) {
      context.missing(_handledMeta);
    }
    if (data.containsKey('last_ack')) {
      context.handle(_lastAckMeta,
          lastAck.isAcceptableOrUnknown(data['last_ack']!, _lastAckMeta));
    } else if (isInserting) {
      context.missing(_lastAckMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {jid};
  @override
  SMStateEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SMStateEntry(
      jid: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}jid'])!,
      smId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}sm_id'])!,
      sequence: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}sequence'])!,
      handled: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}handled'])!,
      lastAck: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}last_ack'])!,
    );
  }

  @override
  $SMStateEntriesTable createAlias(String alias) {
    return $SMStateEntriesTable(attachedDatabase, alias);
  }
}

class SMStateEntry extends DataClass implements Insertable<SMStateEntry> {
  /// JID (Jabber ID) - primary key
  final String jid;

  /// Stream Management ID
  final String smId;

  /// Sequence number
  final int sequence;

  /// Handled count
  final int handled;

  /// Last acknowledgment
  final int lastAck;
  const SMStateEntry(
      {required this.jid,
      required this.smId,
      required this.sequence,
      required this.handled,
      required this.lastAck});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['jid'] = Variable<String>(jid);
    map['sm_id'] = Variable<String>(smId);
    map['sequence'] = Variable<int>(sequence);
    map['handled'] = Variable<int>(handled);
    map['last_ack'] = Variable<int>(lastAck);
    return map;
  }

  SMStateEntriesCompanion toCompanion(bool nullToAbsent) {
    return SMStateEntriesCompanion(
      jid: Value(jid),
      smId: Value(smId),
      sequence: Value(sequence),
      handled: Value(handled),
      lastAck: Value(lastAck),
    );
  }

  factory SMStateEntry.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SMStateEntry(
      jid: serializer.fromJson<String>(json['jid']),
      smId: serializer.fromJson<String>(json['smId']),
      sequence: serializer.fromJson<int>(json['sequence']),
      handled: serializer.fromJson<int>(json['handled']),
      lastAck: serializer.fromJson<int>(json['lastAck']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'jid': serializer.toJson<String>(jid),
      'smId': serializer.toJson<String>(smId),
      'sequence': serializer.toJson<int>(sequence),
      'handled': serializer.toJson<int>(handled),
      'lastAck': serializer.toJson<int>(lastAck),
    };
  }

  SMStateEntry copyWith(
          {String? jid,
          String? smId,
          int? sequence,
          int? handled,
          int? lastAck}) =>
      SMStateEntry(
        jid: jid ?? this.jid,
        smId: smId ?? this.smId,
        sequence: sequence ?? this.sequence,
        handled: handled ?? this.handled,
        lastAck: lastAck ?? this.lastAck,
      );
  SMStateEntry copyWithCompanion(SMStateEntriesCompanion data) {
    return SMStateEntry(
      jid: data.jid.present ? data.jid.value : this.jid,
      smId: data.smId.present ? data.smId.value : this.smId,
      sequence: data.sequence.present ? data.sequence.value : this.sequence,
      handled: data.handled.present ? data.handled.value : this.handled,
      lastAck: data.lastAck.present ? data.lastAck.value : this.lastAck,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SMStateEntry(')
          ..write('jid: $jid, ')
          ..write('smId: $smId, ')
          ..write('sequence: $sequence, ')
          ..write('handled: $handled, ')
          ..write('lastAck: $lastAck')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(jid, smId, sequence, handled, lastAck);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SMStateEntry &&
          other.jid == this.jid &&
          other.smId == this.smId &&
          other.sequence == this.sequence &&
          other.handled == this.handled &&
          other.lastAck == this.lastAck);
}

class SMStateEntriesCompanion extends UpdateCompanion<SMStateEntry> {
  final Value<String> jid;
  final Value<String> smId;
  final Value<int> sequence;
  final Value<int> handled;
  final Value<int> lastAck;
  final Value<int> rowid;
  const SMStateEntriesCompanion({
    this.jid = const Value.absent(),
    this.smId = const Value.absent(),
    this.sequence = const Value.absent(),
    this.handled = const Value.absent(),
    this.lastAck = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SMStateEntriesCompanion.insert({
    required String jid,
    required String smId,
    required int sequence,
    required int handled,
    required int lastAck,
    this.rowid = const Value.absent(),
  })  : jid = Value(jid),
        smId = Value(smId),
        sequence = Value(sequence),
        handled = Value(handled),
        lastAck = Value(lastAck);
  static Insertable<SMStateEntry> custom({
    Expression<String>? jid,
    Expression<String>? smId,
    Expression<int>? sequence,
    Expression<int>? handled,
    Expression<int>? lastAck,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (jid != null) 'jid': jid,
      if (smId != null) 'sm_id': smId,
      if (sequence != null) 'sequence': sequence,
      if (handled != null) 'handled': handled,
      if (lastAck != null) 'last_ack': lastAck,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SMStateEntriesCompanion copyWith(
      {Value<String>? jid,
      Value<String>? smId,
      Value<int>? sequence,
      Value<int>? handled,
      Value<int>? lastAck,
      Value<int>? rowid}) {
    return SMStateEntriesCompanion(
      jid: jid ?? this.jid,
      smId: smId ?? this.smId,
      sequence: sequence ?? this.sequence,
      handled: handled ?? this.handled,
      lastAck: lastAck ?? this.lastAck,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (jid.present) {
      map['jid'] = Variable<String>(jid.value);
    }
    if (smId.present) {
      map['sm_id'] = Variable<String>(smId.value);
    }
    if (sequence.present) {
      map['sequence'] = Variable<int>(sequence.value);
    }
    if (handled.present) {
      map['handled'] = Variable<int>(handled.value);
    }
    if (lastAck.present) {
      map['last_ack'] = Variable<int>(lastAck.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SMStateEntriesCompanion(')
          ..write('jid: $jid, ')
          ..write('smId: $smId, ')
          ..write('sequence: $sequence, ')
          ..write('handled: $handled, ')
          ..write('lastAck: $lastAck, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $UnackedStanzaEntriesTable extends UnackedStanzaEntries
    with TableInfo<$UnackedStanzaEntriesTable, UnackedStanzaEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $UnackedStanzaEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _sequenceMeta =
      const VerificationMeta('sequence');
  @override
  late final GeneratedColumn<int> sequence = GeneratedColumn<int>(
      'sequence', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _xmlMeta = const VerificationMeta('xml');
  @override
  late final GeneratedColumn<String> xml = GeneratedColumn<String>(
      'xml', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [sequence, xml];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'unacked_stanza_entries';
  @override
  VerificationContext validateIntegrity(Insertable<UnackedStanzaEntry> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('sequence')) {
      context.handle(_sequenceMeta,
          sequence.isAcceptableOrUnknown(data['sequence']!, _sequenceMeta));
    }
    if (data.containsKey('xml')) {
      context.handle(
          _xmlMeta, xml.isAcceptableOrUnknown(data['xml']!, _xmlMeta));
    } else if (isInserting) {
      context.missing(_xmlMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {sequence};
  @override
  UnackedStanzaEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return UnackedStanzaEntry(
      sequence: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}sequence'])!,
      xml: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}xml'])!,
    );
  }

  @override
  $UnackedStanzaEntriesTable createAlias(String alias) {
    return $UnackedStanzaEntriesTable(attachedDatabase, alias);
  }
}

class UnackedStanzaEntry extends DataClass
    implements Insertable<UnackedStanzaEntry> {
  /// Sequence number - primary key
  final int sequence;

  /// XML string of the stanza
  final String xml;
  const UnackedStanzaEntry({required this.sequence, required this.xml});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['sequence'] = Variable<int>(sequence);
    map['xml'] = Variable<String>(xml);
    return map;
  }

  UnackedStanzaEntriesCompanion toCompanion(bool nullToAbsent) {
    return UnackedStanzaEntriesCompanion(
      sequence: Value(sequence),
      xml: Value(xml),
    );
  }

  factory UnackedStanzaEntry.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return UnackedStanzaEntry(
      sequence: serializer.fromJson<int>(json['sequence']),
      xml: serializer.fromJson<String>(json['xml']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'sequence': serializer.toJson<int>(sequence),
      'xml': serializer.toJson<String>(xml),
    };
  }

  UnackedStanzaEntry copyWith({int? sequence, String? xml}) =>
      UnackedStanzaEntry(
        sequence: sequence ?? this.sequence,
        xml: xml ?? this.xml,
      );
  UnackedStanzaEntry copyWithCompanion(UnackedStanzaEntriesCompanion data) {
    return UnackedStanzaEntry(
      sequence: data.sequence.present ? data.sequence.value : this.sequence,
      xml: data.xml.present ? data.xml.value : this.xml,
    );
  }

  @override
  String toString() {
    return (StringBuffer('UnackedStanzaEntry(')
          ..write('sequence: $sequence, ')
          ..write('xml: $xml')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(sequence, xml);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UnackedStanzaEntry &&
          other.sequence == this.sequence &&
          other.xml == this.xml);
}

class UnackedStanzaEntriesCompanion
    extends UpdateCompanion<UnackedStanzaEntry> {
  final Value<int> sequence;
  final Value<String> xml;
  const UnackedStanzaEntriesCompanion({
    this.sequence = const Value.absent(),
    this.xml = const Value.absent(),
  });
  UnackedStanzaEntriesCompanion.insert({
    this.sequence = const Value.absent(),
    required String xml,
  }) : xml = Value(xml);
  static Insertable<UnackedStanzaEntry> custom({
    Expression<int>? sequence,
    Expression<String>? xml,
  }) {
    return RawValuesInsertable({
      if (sequence != null) 'sequence': sequence,
      if (xml != null) 'xml': xml,
    });
  }

  UnackedStanzaEntriesCompanion copyWith(
      {Value<int>? sequence, Value<String>? xml}) {
    return UnackedStanzaEntriesCompanion(
      sequence: sequence ?? this.sequence,
      xml: xml ?? this.xml,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (sequence.present) {
      map['sequence'] = Variable<int>(sequence.value);
    }
    if (xml.present) {
      map['xml'] = Variable<String>(xml.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('UnackedStanzaEntriesCompanion(')
          ..write('sequence: $sequence, ')
          ..write('xml: $xml')
          ..write(')'))
        .toString();
  }
}

abstract class _$WhixpDatabase extends GeneratedDatabase {
  _$WhixpDatabase(QueryExecutor e) : super(e);
  $WhixpDatabaseManager get managers => $WhixpDatabaseManager(this);
  late final $SMStateEntriesTable sMStateEntries = $SMStateEntriesTable(this);
  late final $UnackedStanzaEntriesTable unackedStanzaEntries =
      $UnackedStanzaEntriesTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities =>
      [sMStateEntries, unackedStanzaEntries];
}

typedef $$SMStateEntriesTableCreateCompanionBuilder = SMStateEntriesCompanion
    Function({
  required String jid,
  required String smId,
  required int sequence,
  required int handled,
  required int lastAck,
  Value<int> rowid,
});
typedef $$SMStateEntriesTableUpdateCompanionBuilder = SMStateEntriesCompanion
    Function({
  Value<String> jid,
  Value<String> smId,
  Value<int> sequence,
  Value<int> handled,
  Value<int> lastAck,
  Value<int> rowid,
});

class $$SMStateEntriesTableFilterComposer
    extends Composer<_$WhixpDatabase, $SMStateEntriesTable> {
  $$SMStateEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get jid => $composableBuilder(
      column: $table.jid, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get smId => $composableBuilder(
      column: $table.smId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get sequence => $composableBuilder(
      column: $table.sequence, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get handled => $composableBuilder(
      column: $table.handled, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get lastAck => $composableBuilder(
      column: $table.lastAck, builder: (column) => ColumnFilters(column));
}

class $$SMStateEntriesTableOrderingComposer
    extends Composer<_$WhixpDatabase, $SMStateEntriesTable> {
  $$SMStateEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get jid => $composableBuilder(
      column: $table.jid, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get smId => $composableBuilder(
      column: $table.smId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get sequence => $composableBuilder(
      column: $table.sequence, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get handled => $composableBuilder(
      column: $table.handled, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get lastAck => $composableBuilder(
      column: $table.lastAck, builder: (column) => ColumnOrderings(column));
}

class $$SMStateEntriesTableAnnotationComposer
    extends Composer<_$WhixpDatabase, $SMStateEntriesTable> {
  $$SMStateEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get jid =>
      $composableBuilder(column: $table.jid, builder: (column) => column);

  GeneratedColumn<String> get smId =>
      $composableBuilder(column: $table.smId, builder: (column) => column);

  GeneratedColumn<int> get sequence =>
      $composableBuilder(column: $table.sequence, builder: (column) => column);

  GeneratedColumn<int> get handled =>
      $composableBuilder(column: $table.handled, builder: (column) => column);

  GeneratedColumn<int> get lastAck =>
      $composableBuilder(column: $table.lastAck, builder: (column) => column);
}

class $$SMStateEntriesTableTableManager extends RootTableManager<
    _$WhixpDatabase,
    $SMStateEntriesTable,
    SMStateEntry,
    $$SMStateEntriesTableFilterComposer,
    $$SMStateEntriesTableOrderingComposer,
    $$SMStateEntriesTableAnnotationComposer,
    $$SMStateEntriesTableCreateCompanionBuilder,
    $$SMStateEntriesTableUpdateCompanionBuilder,
    (
      SMStateEntry,
      BaseReferences<_$WhixpDatabase, $SMStateEntriesTable, SMStateEntry>
    ),
    SMStateEntry,
    PrefetchHooks Function()> {
  $$SMStateEntriesTableTableManager(
      _$WhixpDatabase db, $SMStateEntriesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SMStateEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SMStateEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SMStateEntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> jid = const Value.absent(),
            Value<String> smId = const Value.absent(),
            Value<int> sequence = const Value.absent(),
            Value<int> handled = const Value.absent(),
            Value<int> lastAck = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              SMStateEntriesCompanion(
            jid: jid,
            smId: smId,
            sequence: sequence,
            handled: handled,
            lastAck: lastAck,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String jid,
            required String smId,
            required int sequence,
            required int handled,
            required int lastAck,
            Value<int> rowid = const Value.absent(),
          }) =>
              SMStateEntriesCompanion.insert(
            jid: jid,
            smId: smId,
            sequence: sequence,
            handled: handled,
            lastAck: lastAck,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$SMStateEntriesTableProcessedTableManager = ProcessedTableManager<
    _$WhixpDatabase,
    $SMStateEntriesTable,
    SMStateEntry,
    $$SMStateEntriesTableFilterComposer,
    $$SMStateEntriesTableOrderingComposer,
    $$SMStateEntriesTableAnnotationComposer,
    $$SMStateEntriesTableCreateCompanionBuilder,
    $$SMStateEntriesTableUpdateCompanionBuilder,
    (
      SMStateEntry,
      BaseReferences<_$WhixpDatabase, $SMStateEntriesTable, SMStateEntry>
    ),
    SMStateEntry,
    PrefetchHooks Function()>;
typedef $$UnackedStanzaEntriesTableCreateCompanionBuilder
    = UnackedStanzaEntriesCompanion Function({
  Value<int> sequence,
  required String xml,
});
typedef $$UnackedStanzaEntriesTableUpdateCompanionBuilder
    = UnackedStanzaEntriesCompanion Function({
  Value<int> sequence,
  Value<String> xml,
});

class $$UnackedStanzaEntriesTableFilterComposer
    extends Composer<_$WhixpDatabase, $UnackedStanzaEntriesTable> {
  $$UnackedStanzaEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get sequence => $composableBuilder(
      column: $table.sequence, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get xml => $composableBuilder(
      column: $table.xml, builder: (column) => ColumnFilters(column));
}

class $$UnackedStanzaEntriesTableOrderingComposer
    extends Composer<_$WhixpDatabase, $UnackedStanzaEntriesTable> {
  $$UnackedStanzaEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get sequence => $composableBuilder(
      column: $table.sequence, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get xml => $composableBuilder(
      column: $table.xml, builder: (column) => ColumnOrderings(column));
}

class $$UnackedStanzaEntriesTableAnnotationComposer
    extends Composer<_$WhixpDatabase, $UnackedStanzaEntriesTable> {
  $$UnackedStanzaEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get sequence =>
      $composableBuilder(column: $table.sequence, builder: (column) => column);

  GeneratedColumn<String> get xml =>
      $composableBuilder(column: $table.xml, builder: (column) => column);
}

class $$UnackedStanzaEntriesTableTableManager extends RootTableManager<
    _$WhixpDatabase,
    $UnackedStanzaEntriesTable,
    UnackedStanzaEntry,
    $$UnackedStanzaEntriesTableFilterComposer,
    $$UnackedStanzaEntriesTableOrderingComposer,
    $$UnackedStanzaEntriesTableAnnotationComposer,
    $$UnackedStanzaEntriesTableCreateCompanionBuilder,
    $$UnackedStanzaEntriesTableUpdateCompanionBuilder,
    (
      UnackedStanzaEntry,
      BaseReferences<_$WhixpDatabase, $UnackedStanzaEntriesTable,
          UnackedStanzaEntry>
    ),
    UnackedStanzaEntry,
    PrefetchHooks Function()> {
  $$UnackedStanzaEntriesTableTableManager(
      _$WhixpDatabase db, $UnackedStanzaEntriesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$UnackedStanzaEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$UnackedStanzaEntriesTableOrderingComposer(
                  $db: db, $table: table),
          createComputedFieldComposer: () =>
              $$UnackedStanzaEntriesTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> sequence = const Value.absent(),
            Value<String> xml = const Value.absent(),
          }) =>
              UnackedStanzaEntriesCompanion(
            sequence: sequence,
            xml: xml,
          ),
          createCompanionCallback: ({
            Value<int> sequence = const Value.absent(),
            required String xml,
          }) =>
              UnackedStanzaEntriesCompanion.insert(
            sequence: sequence,
            xml: xml,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$UnackedStanzaEntriesTableProcessedTableManager
    = ProcessedTableManager<
        _$WhixpDatabase,
        $UnackedStanzaEntriesTable,
        UnackedStanzaEntry,
        $$UnackedStanzaEntriesTableFilterComposer,
        $$UnackedStanzaEntriesTableOrderingComposer,
        $$UnackedStanzaEntriesTableAnnotationComposer,
        $$UnackedStanzaEntriesTableCreateCompanionBuilder,
        $$UnackedStanzaEntriesTableUpdateCompanionBuilder,
        (
          UnackedStanzaEntry,
          BaseReferences<_$WhixpDatabase, $UnackedStanzaEntriesTable,
              UnackedStanzaEntry>
        ),
        UnackedStanzaEntry,
        PrefetchHooks Function()>;

class $WhixpDatabaseManager {
  final _$WhixpDatabase _db;
  $WhixpDatabaseManager(this._db);
  $$SMStateEntriesTableTableManager get sMStateEntries =>
      $$SMStateEntriesTableTableManager(_db, _db.sMStateEntries);
  $$UnackedStanzaEntriesTableTableManager get unackedStanzaEntries =>
      $$UnackedStanzaEntriesTableTableManager(_db, _db.unackedStanzaEntries);
}
