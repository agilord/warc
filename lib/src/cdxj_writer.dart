import 'dart:convert';

import 'package:synchronized/synchronized.dart';

import 'common.dart';
import 'cdxj_record.dart';

class CdxjWriter {
  final Sink<List<int>> _outputSink;
  final bool typed;
  final _lock = Lock();

  CdxjWriter({
    required Sink<List<int>> output,
    this.typed = false,
  }) : _outputSink = output;

  Future<void> add(CdxjRecord record) async {
    return await _lock.synchronized(() async {
      _emit(record.toString(typed: typed));
    });
  }

  void _emit(String line) {
    _outputSink.add(utf8.encode(line));
    _outputSink.add([carriageReturn, lineFeed]);
  }

  Future<void> close() async {
    return await _lock.synchronized(() async {
      _outputSink.close();
    });
  }
}
