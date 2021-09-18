import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:warc/src/warc_file_writer.dart';
import 'package:warc/src/warc_record.dart';
import 'package:warc/warc.dart';
import 'package:warc/warc_io.dart';

void main() {
  group('WarcFileWriter', () {
    late Directory output;
    late WarcFileWriter writer;
    late File warcFile;
    late File cdxjFile;

    setUpAll(() async {
      output = await Directory.systemTemp.createTemp();
      writer = WarcFileWriter(
        baseDirectoryPath: output.path,
        prefix: 'warc-test',
      );
    });

    tearDownAll(() async {
      // if needed to debug:
      // await warcFile.copy('${Directory.current.path}/x.warc.gz');
      await output.delete(recursive: true);
    });

    test('write entries', () async {
      await writer.add(WarcRecord(
        WarcHeader(
          type: WarcTypes.warcinfo,
          date: DateTime.utc(2001, 2, 3, 4, 5, 6),
          recordId: 'r-1',
          contentLength: 4,
          contentType: 'text/plain',
          targetUri: Uri.parse('http://example.com/a'),
        ),
        WarcBlock(Uint8List.fromList(utf8.encode('abcd'))),
      ));
      await writer.add(WarcRecord(
        WarcHeader(
          type: WarcTypes.response,
          date: DateTime.utc(2021, 12, 31, 23, 59, 59, 999),
          recordId: 'r-2',
          targetUri: Uri.parse('http://example.com/b'),
        ),
        WarcHttpBlock.build(
          statusCode: 200,
          header: {
            'Content-Type': 'image/none',
            'X-Server-Message': 'hello :)',
          },
          payload: Uint8List.fromList(<int>[0, 1, 2, 3, 4, 5, 6, 7, 8, 9]),
        ),
      ));
      await writer.add(WarcRecord(
        WarcHeader(
            type: WarcTypes.request,
            date: DateTime.utc(2021, 09, 09, 09, 09, 09),
            recordId: 'r-3'),
        WarcBlock(Uint8List.fromList(utf8.encode('-'))),
      ));
      await writer.close();
    });

    test('directory check', () {
      final files = output.listSync().whereType<File>();
      expect(files, hasLength(2));
      warcFile = files.firstWhere((f) => f.path.endsWith('.warc.gz'));
      cdxjFile = files.firstWhere((f) => f.path.endsWith('.cdxj'));
    });

    test('CDXJ file', () {
      final filename = warcFile.path.split('/').last;
      expect(
          cdxjFile.readAsStringSync(),
          'com,example)/a 20010203040506 {"url":"http://example.com/a","mime":"warc/warcinfo","filename":"$filename","offset":"0","length":"166","digest":"81fe8bfe87576c3ecb22426f8e57847382917acf"}\r\n'
          'com,example)/b 20211231235959 {"url":"http://example.com/b","mime":"image/none","filename":"$filename","offset":"166","length":"228","status":"200","digest":"494179714a6cd627239dfededf2de9ef994caf03"}\r\n');
    });

    test('Reading a single record with positions', () async {
      final records = await readWarc(
              warcFile.openRead(166, 166 + 228).transform(gzip.decoder))
          .toList();
      expect(records, hasLength(1));
      final r = records.single;
      final body = r.block as WarcHttpBlock;
      expect(body.header, {
        'Content-Type': 'image/none',
        'X-Server-Message': 'hello :)',
      });
      expect(body.payloadBytes, [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]);
    });

    // TODO: re-enable after gzip decoder reads full stream.
    // test('Reading everything', () async {
    //   final records =
    //       await readWarc(warcFile.openRead().transform(gzip.decoder)).toList();
    //   expect(records, hasLength(3));
    // });
  });
}
