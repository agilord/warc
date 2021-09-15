import 'dart:convert';
import 'dart:typed_data';

import 'common.dart';
import 'warc_parser.dart';
import 'warc_record.dart';

class WarcHttpBlock implements WarcBlock {
  Uint8List? _bytes;
  Map<String, String>? _header;
  Uint8List? _headerBytes;
  Uint8List? _payloadBytes;

  WarcHttpBlock.parseBytes(Uint8List bytes) {
    _bytes = bytes;
    final index = indexOfHeaderEnd(bytes);
    _headerBytes = index < 0 ? _bytes : Uint8List.sublistView(bytes, 0, index);
    _payloadBytes =
        index < 0 ? Uint8List(0) : Uint8List.sublistView(bytes, index);
  }

  WarcHttpBlock.fromFrames({
    required Uint8List headerBytes,
    required Uint8List payload,
  }) {
    _headerBytes = headerBytes;
    _payloadBytes = payload;
  }

  WarcHttpBlock.build({
    required Map<String, String> header,
    required Uint8List payload,
  }) {
    _header = CaseInsensitiveMap<String>(header);
    _payloadBytes = payload;
  }

  Map<String, String> get header {
    return _header ??= CaseInsensitiveMap<String>(
      parseHeaderValues(utf8
          .decode(_headerBytes!)
          .split('\n')
          .map((e) => e.trimRight())
          .where((e) => e.isNotEmpty)),
    );
  }

  @override
  Uint8List get bytes {
    if (_headerBytes == null) {
      final text = [..._header!.entries.map((e) => null), '', ''].join('\r\n');
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
