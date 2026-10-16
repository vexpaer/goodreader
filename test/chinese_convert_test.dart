import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:goodreader/data/models/text_conversion.dart';
import 'package:goodreader/features/reader/convert/chinese_convert.dart';

void main() {
  group('ChineseConverter', () {
    final converter = ChineseConverter.forTesting(
      s2tChars: {'发': '發', '里': '裡', '汉': '漢', '长': '長'},
      t2sChars: {'發': '发', '裡': '里', '漢': '汉', '長': '长', '頭': '头'},
      s2tPhrases: {'头发': '頭髮', '里面': '裡面', '汉化': '漢化'},
      t2sPhrases: {'頭髮': '头发'},
      twChars: {'裡': '裏'},
      hkChars: {'裡': '裏'},
    );

    test('leaves text alone when conversion is off', () {
      expect(converter.convert('头发', ChineseConversion.none), '头发');
    });

    test('prefers the longest matching phrase', () {
      expect(
        converter.convert('我的头发很长', ChineseConversion.toTraditional),
        '我的頭髮很長',
      );
    });

    test('falls back to single character conversion', () {
      expect(
        converter.convert('汉化', ChineseConversion.toTraditional),
        '漢化',
      );
    });

    test('applies the Taiwan glyph table after conversion', () {
      expect(
        converter.convert(
          '里面',
          ChineseConversion.toTraditional,
          TraditionalVariant.taiwan,
        ),
        '裏面',
      );
    });

    test('converts back to Simplified', () {
      expect(
        converter.convert('頭髮裡面', ChineseConversion.toSimplified),
        '头发里面',
      );
    });

    test('never changes the character count', () {
      const samples = [
        '我的头发很长，里面还有故事',
        '漢化與繁體字',
        'abc 123 中文',
      ];
      for (final sample in samples) {
        for (final mode in ChineseConversion.values) {
          for (final variant in TraditionalVariant.values) {
            expect(
              converter.convert(sample, mode, variant).length,
              sample.length,
              reason: '$sample with $mode / $variant',
            );
          }
        }
      }
    });
  });

  group('shipped conversion tables', () {
    const files = [
      's2t_chars.txt',
      't2s_chars.txt',
      's2t_phrases.txt',
      't2s_phrases.txt',
      'tw_chars.txt',
      'hk_chars.txt',
    ];

    test('exist and are parseable', () {
      for (final name in files) {
        final file = File('assets/convert/$name');
        expect(file.existsSync(), isTrue, reason: '$name is missing');
        expect(file.lengthSync(), greaterThan(0), reason: '$name is empty');
        final parsed = ChineseConverter.parsePairs(file.readAsStringSync());
        expect(parsed, isNotEmpty, reason: '$name parsed to nothing');
      }
    });

    test('only contain mappings that preserve the character count', () {
      // The reader stores highlight and bookmark offsets against the source
      // text, so a conversion that changed the length would misplace them.
      for (final name in files) {
        final lines = File('assets/convert/$name').readAsLinesSync();
        for (final line in lines) {
          if (line.isEmpty) continue;
          final tab = line.indexOf('\t');
          expect(tab, greaterThan(0), reason: 'malformed line in $name: $line');
          final key = line.substring(0, tab);
          final value = line.substring(tab + 1);
          expect(
            value.length,
            key.length,
            reason: '$key -> $value in $name changes the character count',
          );
        }
      }
    });
  });
}
