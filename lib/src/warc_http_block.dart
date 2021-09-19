import 'dart:convert';
import 'dart:typed_data';

import 'package:buffer/buffer.dart';

import 'common.dart';
import 'warc_parser.dart';
import 'warc_record.dart';

class WarcHttpBlock implements WarcBlock {
  Uint8List? _bytes;
  String? _httpVersion;
  int? _statusCode;
  String? _statusReason;
  Map<String, String>? _header;
  Uint8List? _headerBytes;
  Uint8List? _payloadBytes;

  WarcHttpBlock.parseBytes(List<int> bytes) {
    _bytes = castBytes(bytes);
    final index = indexOfHeaderEnd(_bytes!);
    _headerBytes =
        index < 0 ? _bytes : Uint8List.sublistView(_bytes!, 0, index);
    _payloadBytes =
        index < 0 ? Uint8List(0) : Uint8List.sublistView(_bytes!, index);
  }

  WarcHttpBlock.fromFrames({
    required List<int> headerBytes,
    required List<int> payload,
  }) {
    _headerBytes = castBytes(headerBytes);
    _payloadBytes = castBytes(payload);
  }

  WarcHttpBlock.build({
    String httpVersion = '1.1',
    int statusCode = 200,
    String? statusReason = 'OK',
    required Map<String, String> header,
    required List<int> payload,
  }) {
    _httpVersion = httpVersion;
    _statusCode = statusCode;
    _statusReason = statusReason;
    _header = CaseInsensitiveMap<String>(header);
    _payloadBytes = castBytes(payload);
  }

  static WarcHttpBlock fromBlock(WarcBlock block) {
    if (block is WarcHttpBlock) return block;
    return WarcHttpBlock.parseBytes(block.bytes);
  }

  void _parseHeader() {
    final lines = utf8
        .decode(_headerBytes!)
        .split('\n')
        .map((e) => e.trimRight())
        .where((e) => e.isNotEmpty)
        .toList();
    if (lines.isEmpty) throw FormatException('Empty HTTP header.');
    if (!lines.first.startsWith('HTTP/')) {
      throw FormatException('Does not start with HTTP: `${lines.first}`');
    }
    final parts = lines.first.split(' ');
    if (parts.length < 2) {
      throw FormatException('Does not follows HTTP lead: `${lines.first}`');
    }
    _httpVersion = parts.first.split('/').skip(1).join('/');
    _statusCode = int.parse(parts[1]);
    _statusReason = parts.skip(2).join(' ').trim();
    _header ??= CaseInsensitiveMap<String>(parseHeaderValues(lines.skip(1)));
  }

  int get statusCode {
    if (_statusCode == null) {
      _parseHeader();
    }
    return _statusCode!;
  }

  @override
  String? get blockContentType => 'application/http';

  late final String? payloadContentType = header['Content-Type'];

  Map<String, String> get header {
    if (_header == null) {
      _parseHeader();
    }
    return _header!;
  }

  @override
  Uint8List get bytes {
    if (_headerBytes == null) {
      final firstLine = [
        'HTTP/$_httpVersion',
        '$statusCode',
        if (_statusReason != null && _statusReason!.isNotEmpty) _statusReason!,
      ].join(' ');
      final text = [
        firstLine,
        ..._header!.entries.map((e) => '${e.key}: ${e.value}'),
        '',
        '',
      ].join('\r\n');
      _headerBytes = Uint8List.fromList(utf8.encode(text));
    }
    if (_bytes == null) {
      final bb = BytesBuilder(copy: false);
      bb.add(_headerBytes!);
      bb.add(_payloadBytes!);
      _bytes = bb.takeBytes();
    }
    return _bytes!;
  }

  Uint8List get payloadBytes => _payloadBytes!;
}
