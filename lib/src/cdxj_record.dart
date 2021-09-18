import 'dart:convert';

Uri warcfileUri(String filename, int offset) {
  return Uri(scheme: 'warcfile', path: filename, fragment: '$offset');
}

Uri wgzUri(String filename, int offset, int length,
    [int? offset2, int? length2]) {
  final fragment = StringBuffer('$offset+$length');
  if (offset2 != null && offset2 != offset) {
    fragment.write('/$offset2+$length2');
  }
  return Uri(scheme: 'wgz', path: filename, fragment: fragment.toString());
}

class CdxjRecord {
  final Uri url;
  final DateTime timestamp;
  final String mime;
  final String filename;
  final int offset;
  final int length;
  final int? status;
  final String? digest;

  CdxjRecord({
    required this.url,
    required this.timestamp,
    required this.mime,
    required this.filename,
    required this.offset,
    required this.length,
    this.status,
    this.digest,
  });

  factory CdxjRecord.parse(String value) {
    final parts = value.split(' ');
    final timestamp =
        DateTime.parse('${parts[1].substring(0, 8)}T${parts[1].substring(8)}Z');
    final map = json.decode(parts.skip(2).join(' ')) as Map<String, dynamic>;
    return CdxjRecord(
      url: Uri.parse(map['url'] as String),
      timestamp: timestamp,
      mime: map['mime'] as String,
      filename: map['filename'] as String,
      offset: _parseInt(map['offset'])!,
      length: _parseInt(map['length'])!,
      status: _parseInt(map['status']),
      digest: map['digest'] as String?,
    );
  }

  @override
  String toString({
    bool typed = false,
  }) {
    return [
      url.toSearchableUrl(),
      timestamp
          .toUtc()
          .toIso8601String()
          .replaceAll('-', '')
          .replaceAll(':', '')
          .replaceAll('T', '')
          .split('.')
          .first,
      json.encode({
        'url': url.toString(),
        'mime': mime,
        'filename': filename,
        'offset': typed ? offset : offset.toString(),
        'length': typed ? length : length.toString(),
        if (status != null) 'status': typed ? status : status.toString(),
        if (digest != null) 'digest': digest,
      }),
    ].join(' ');
  }
}

int? _parseInt(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is String) return int.parse(v);
  throw FormatException('Unknown value: $v');
}

extension UriExt on Uri {
  String toSearchableUrl() {
    final hostParts = host.split('.').reversed.join(',');
    final schemeLC = scheme.toLowerCase();
    final emitScheme = hasScheme &&
        schemeLC.isNotEmpty &&
        schemeLC != 'http' &&
        schemeLC != 'https';
    return [
      if (emitScheme) '$schemeLC://',
      hostParts,
      if (hasPort) ':$port',
      if (hostParts.isNotEmpty) ')',
      path,
      if (hasQuery) '?$query',
    ].join('');
  }
}
