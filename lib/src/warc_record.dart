import 'dart:typed_data';

class WarcRecord {
  final WarcHeader header;
  final WarcPayload payload;

  WarcRecord({
    required this.header,
    required this.payload,
  });
}

class WarcHeader {
  final String version;
  final Map<String, String> _values;

  int? _contentLength;
  WarcHeader({
    this.version = '1.1',
    Map<String, String>? values,
  }) : _values = <String, String>{
          if (values != null) ...values,
        };

  Iterable<String> get keys => _values.keys;
  String? operator [](String key) {
    if (_values.containsKey(key)) {
      return _values[key];
    }
    final lc = key.toLowerCase();
    for (final k in keys) {
      if (k.toLowerCase() == lc) {
        return _values[k];
      }
    }
    return null;
  }

  int get contentLength =>
      _contentLength ??= int.parse(this['Content-Length'] ?? '0');
}

abstract class WarcPayload {
  WarcPayload();

  factory WarcPayload.bytes(List<int> bytes) => _WarcPayloadBytes(bytes);

  Stream<List<int>> read();

  Future<List<int>> readAsBytes() async {
    final buffer = BytesBuilder(copy: false);
    await for (final chunk in read()) {
      buffer.add(chunk);
    }
    return buffer.takeBytes();
  }
}

class _WarcPayloadBytes extends WarcPayload {
  final List<int> _bytes;
  _WarcPayloadBytes(this._bytes);

  @override
  Stream<List<int>> read() {
    return Stream<List<int>>.value(_bytes);
  }

  @override
  Future<List<int>> readAsBytes() async {
    return _bytes;
  }
}
