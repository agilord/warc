import 'dart:async';
import 'dart:convert';

import 'parser.dart';
import 'warc_record.dart';

class WarcWriter {
  final Sink<List<int>> _outputSink;
  final Converter<List<int>, List<int>>? _encoder;
  bool _isClosed = false;
  int _contentOffset = 0;
  int _encodedOffset = 0;

  WarcWriter._(this._outputSink, this._encoder);

  factory WarcWriter({
    required Sink<List<int>> output,
    Converter<List<int>, List<int>>? encoder,
  }) {
    return WarcWriter._(output, encoder);
  }

  int get contentOffset => _contentOffset;
  int get encodedOffset => _encodedOffset;

  Future<void> add(WarcRecord record) async {
    if (_isClosed) throw StateError('Writer was already closed.');

    final counterSink = _encoder == null ? null : _CounterSink(_outputSink);
    final chunkedSink = _encoder?.startChunkedConversion(counterSink!);
    final sink = chunkedSink ?? _outputSink;

    var chunkLength = 0;
    void writeChunk(List<int> data) {
      chunkLength += data.length;
      sink.add(data);
    }

    writeChunk(utf8.encode('WARC/${record.header.version}\r\n'));
    for (final key in record.header.keys) {
      writeChunk(utf8.encode('$key: ${record.header[key]}\r\n'));
    }
    writeChunk([carriageReturn, lineFeed]);
    await for (final chunk in record.payload.read()) {
      writeChunk(chunk);
    }
    writeChunk([carriageReturn, lineFeed, carriageReturn, lineFeed]);

    chunkedSink?.close();
    _contentOffset += chunkLength;
    _encodedOffset += counterSink?._offset ?? chunkLength;
  }

  Future<void> close() async {
    if (_isClosed) return;
    _isClosed = true;
    _outputSink.close();
  }
}

class _CounterSink implements Sink<List<int>> {
  int _offset = 0;
  final Sink<List<int>> _sink;

  _CounterSink(this._sink);

  @override
  void add(List<int> data) {
    _offset += data.length;
    _sink.add(data);
  }

  @override
  void close() {}
}
