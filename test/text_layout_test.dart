import 'package:flutter_test/flutter_test.dart';
import 'package:goodreader/features/reader/text_layout.dart';

void main() {
  group('DisplayTransform.apply', () {
    test('is a no-op when nothing is configured', () {
      const transform = DisplayTransform();
      expect(transform.apply('第一行\n第二行'), '第一行\n第二行');
    });

    test('indents every non-blank line', () {
      const transform = DisplayTransform(indent: 2);
      expect(
        transform.apply('第一行\n\n第三行'),
        '\u3000\u3000第一行\n\n\u3000\u3000第三行',
      );
    });

    test('inserts a blank line between paragraphs', () {
      const transform = DisplayTransform(paragraphGap: 1);
      expect(transform.apply('甲\n乙'), '甲\n\n乙');
    });

    test('combines indent and paragraph gap', () {
      const transform = DisplayTransform(indent: 2, paragraphGap: 1);
      expect(transform.apply('甲\n乙'), '\u3000\u3000甲\n\n\u3000\u3000乙');
    });
  });

  group('offset mapping', () {
    test('round trips every offset with indentation', () {
      const text = '第一章 起风了\n内容一\n\n内容二\n结尾';
      const transform = DisplayTransform(indent: 2);
      for (var i = 0; i <= text.length; i++) {
        final display = transform.toDisplay(text, i);
        expect(transform.toRaw(text, display), i,
            reason: 'offset $i did not round trip');
      }
    });

    test('round trips every offset with indent and paragraph gap', () {
      const text = '甲段\n乙段\n丙段';
      const transform = DisplayTransform(indent: 2, paragraphGap: 1);
      for (var i = 0; i <= text.length; i++) {
        final display = transform.toDisplay(text, i);
        expect(transform.toRaw(text, display), i,
            reason: 'offset $i did not round trip');
      }
    });

    test('maps a raw offset past the inserted indent', () {
      const text = '第一行\n第二行';
      const transform = DisplayTransform(indent: 2);
      // '第' of the second line is at raw 4, display 8 (4 + 2 + 2).
      expect(transform.toDisplay(text, 4), 8);
      expect(transform.toRaw(text, 8), 4);
    });
  });

  group('buildTextRuns', () {
    test('marks the highlighted range', () {
      const text = '甲乙丙丁戊';
      final runs = buildTextRuns(
        rawText: text,
        transform: const DisplayTransform(),
        highlights: [(start: 1, end: 3, color: 0xFF00FF00)],
      );
      expect(runs.map((r) => r.text).join(), text);
      expect(runs[1].text, '乙丙');
      expect(runs[1].highlight, 0xFF00FF00);
    });

    test('keeps highlight alignment when indentation is applied', () {
      const text = '第一行\n第二行';
      const transform = DisplayTransform(indent: 2);
      final runs = buildTextRuns(
        rawText: text,
        transform: transform,
        highlights: [(start: 4, end: 6, color: 0xFF0000FF)],
      );
      expect(runs.where((r) => r.highlight != null).single.text, '第二');
      expect(runs.map((r) => r.text).join(), transform.apply(text));
    });

    test('enlarges the first visible character when drop cap is on', () {
      const text = '　　正文开始';
      final runs = buildTextRuns(
        rawText: text,
        transform: const DisplayTransform(),
        highlights: const [],
        dropCap: true,
      );
      final cap = runs.where((r) => r.dropCap).single;
      expect(cap.text, '正');
    });
  });

  group('firstVisibleIndex', () {
    test('skips spaces and ideographic spaces', () {
      expect(firstVisibleIndex('\u3000\u3000 甲'), 4);
      expect(firstVisibleIndex('   '), -1);
    });
  });
}
