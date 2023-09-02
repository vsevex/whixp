import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:echotils/echotils.dart';
import 'package:error/error.dart';
import 'package:events_emitter/emitters/event_emitter.dart';
import 'package:ltx/ltx.dart';

part '_error.dart';

class Protocol extends EventEmitter {
  EchoStatus status = EchoStatus.offline;
  late WebSocket _socket;
  late LTXParser _parser;

  void _attachSocket(WebSocket socket) async {
    _socket = socket;

    emit('connected');
    _changeStatus(EchoStatus.connected);

    _socket
      ..listen(
        (message /** String || List<int> */) {
          Uint8List data;
          if (message is String) {
            data = Echotils.stringToArrayBuffer(message);
          } else if (message is List<int>) {
            data = Uint8List.fromList(message);
          } else {
            emit(
              'error',
              ArgumentError(
                'Error occured due the message is coming in the ${message.runtimeType} type',
              ),
            );
            return;
          }
          final utf8Data = utf8.decode(data);
          emit('input', utf8Data);
        },
        onDone: () {
          _changeStatus(EchoStatus.disconnected);
        },
      )
      ..handleError((error, trace) {
        emit('error', [error, trace]);
      });
  }

  void _attachParser(LTXParser parser) {
    _parser = parser;
  }

  Future<void> connect(String service) async {
    _changeStatus(EchoStatus.connecting, service);

    try {
      _attachSocket(await WebSocket.connect(service));
    } catch (error) {
      emit('error', error);
    }
  }

  void _changeStatus(EchoStatus status, [dynamic args]) {
    this.status = status;
    emit(status.name, args);
  }

  /// override
  void socketParameters([dynamic args /** String */]) {}
}
