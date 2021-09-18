import 'dart:convert';

import 'common.dart';
import 'cdxj_record.dart';

class CdxjWriter {
  final Sink<List<int>> _outputSink;
  final bool typed;

  CdxjWriter({
    required Sink<List<int>> output,
    this.typed = false,
  }) : _outputSink = output;

  void add(CdxjRecord record) {
    _emit(record.toString(typed: typed));
  }

  void _emit(String line) {
    _outputSink.add(utf8.encode(line));
    _outputSink.add([carriageReturn, lineFeed]);
  }

  Future<void> close() async {
    _outputSink.close();
  }
}
