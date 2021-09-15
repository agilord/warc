import 'dart:convert';

import 'common.dart';
import 'cdxj_record.dart';

class CdxjWriter {
  final Sink<List<int>> _outputSink;
  bool _emitVersion;

  CdxjWriter({
    required Sink<List<int>> output,
    bool emitVersion = false,
  })  : _outputSink = output,
        _emitVersion = emitVersion;

  void add(CdxjRecord record) {
    if (_emitVersion) {
      _emit('!OpenWayback-CDXJ 1.0');
      _emitVersion = false;
    }
    _emit(record.toString());
  }

  void _emit(String line) {
    _outputSink.add(utf8.encode(line));
    _outputSink.add([carriageReturn, lineFeed]);
  }

  Future<void> close() async {
    _outputSink.close();
  }
}
