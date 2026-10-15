import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:goodreader/features/reader/engines/txt_engine.dart';

void main() {
  group('TxtDocument.splitChapters', () {
    test('splits on Chinese chapter headings', () {
      const text = '第一章 起风了\n内容一\n\n第二章 雨来了\n内容二\n\n第三章 天晴了\n内容三';
      final chapters = TxtDocument.splitChapters(text);

      expect(chapters.length, 3);
      expect(chapters[0].title, '第一章 起风了');
      expect(chapters[2].title, '第三章 天晴了');
      expect(chapters[0].start, 0);
      expect(chapters[2].end, text.length);
    });

    test('keeps a leading preface before the first heading', () {
      const text = '这是前言部分。\n\n第一章 开始\n正文';
      final chapters = TxtDocument.splitChapters(text);

      expect(chapters.length, 2);
      expect(chapters.first.title, '开始');
      expect(chapters.first.start, 0);
    });

    test('falls back to fixed chunks when no heading exists', () {
      final text = List.filled(13000, 'a').join();
      final chapters = TxtDocument.splitChapters(text);

      expect(chapters.length, 3);
      expect(chapters[0].start, 0);
      expect(chapters[0].end, 6000);
      expect(chapters[2].end, text.length);
    });

    test('honours a custom regex rule', () {
      const text = '== 甲 ==\nA\n== 乙 ==\nB';
      final chapters = TxtDocument.splitChapters(text, rule: r'^== .* ==$');
      expect(chapters.length, 2);
    });
  });

  group('TxtDocument.decodeBytes', () {
    test('detects a UTF-8 BOM', () {
      final bytes = <int>[0xEF, 0xBB, 0xBF, ...utf8.encode('你好')];
      final result = TxtDocument.decodeBytes(Uint8List.fromList(bytes));
      expect(result.encoding, 'utf-8');
      expect(result.text, '你好');
    });

    test('decodes plain UTF-8 without BOM', () {
      final result = TxtDocument.decodeBytes(
        Uint8List.fromList(utf8.encode('第一章 开始')),
      );
      expect(result.encoding, 'utf-8');
      expect(result.text, '第一章 开始');
    });
  });
}
