import 'dart:convert';

Uri warcfileUri(String filename, int offset) {
  return Uri(scheme: 'warcfile', path: filename, fragment: '$offset');
}

class CdxjRecord {
  final Uri uri;
  final DateTime timestamp;
  final String type;
  final Uri reference;
  final int? httpStatusCode;
  final String? mediaContentType;
  final String? recordId;

  CdxjRecord({
    required this.uri,
    required this.timestamp,
    required this.type,
    required this.reference,
    this.httpStatusCode,
    this.mediaContentType,
    this.recordId,
  });

  @override
  String toString() {
    return [
      uri.toSearchableUrl(),
      timestamp
          .toUtc()
          .toIso8601String()
          .replaceAll('-', '')
          .replaceAll(':', '')
          .replaceAll('T', '')
          .split('.')
          .first,
      type,
      json.encode({
        'uri': uri.toString(),
        if (httpStatusCode != null) 'hsc': httpStatusCode,
        if (mediaContentType != null) 'mct': mediaContentType,
        'ref': reference.toString(),
        if (recordId != null) 'rid': recordId,
      }),
    ].join(' ');
  }
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
