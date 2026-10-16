import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../../data/models/text_conversion.dart';

export '../../../data/models/text_conversion.dart'
    show ChineseConversion, ChineseConversionX, TraditionalVariant, TraditionalVariantX;

/// Character and phrase level Simplified/Traditional conversion.
///
/// The tables come from Unicode Unihan and OpenCC and ship as assets; see
/// `scripts/generate_convert_tables.py`. Conversion is character-count
/// preserving only for the single character tables, so callers must not assume
/// offsets survive a phrase replacement - the reader always stores note offsets
/// against the unconverted source text.
class ChineseConverter {
  ChineseConverter._({
    required Map<String, String> s2tChars,
    required Map<String, String> t2sChars,
    required Map<String, String> s2tPhrases,
    required Map<String, String> t2sPhrases,
    required Map<String, String> twChars,
    required Map<String, String> hkChars,
  })  : _s2tChars = s2tChars,
        _t2sChars = t2sChars,
        _s2tPhrases = s2tPhrases,
        _t2sPhrases = t2sPhrases,
        _twChars = twChars,
        _hkChars = hkChars;

  /// Builds a converter from already parsed tables, for tests.
  @visibleForTesting
  factory ChineseConverter.forTesting({
    Map<String, String> s2tChars = const {},
    Map<String, String> t2sChars = const {},
    Map<String, String> s2tPhrases = const {},
    Map<String, String> t2sPhrases = const {},
    Map<String, String> twChars = const {},
    Map<String, String> hkChars = const {},
  }) =>
      ChineseConverter._(
        s2tChars: s2tChars,
        t2sChars: t2sChars,
        s2tPhrases: s2tPhrases,
        t2sPhrases: t2sPhrases,
        twChars: twChars,
        hkChars: hkChars,
      );

  final Map<String, String> _s2tChars;
  final Map<String, String> _t2sChars;
  final Map<String, String> _s2tPhrases;
  final Map<String, String> _t2sPhrases;
  final Map<String, String> _twChars;
  final Map<String, String> _hkChars;

  late final List<int> _s2tLengths = _distinctLengths(_s2tPhrases);
  late final List<int> _t2sLengths = _distinctLengths(_t2sPhrases);

  static Future<ChineseConverter>? _pending;

  /// Loads the tables once per process and reuses them.
  static Future<ChineseConverter> instance() => _pending ??= _load();

  /// Drops the cached tables; only useful in tests.
  @visibleForTesting
  static void resetCache() => _pending = null;

  static Future<ChineseConverter> _load() async {
    const paths = [
      'assets/convert/s2t_chars.txt',
      'assets/convert/t2s_chars.txt',
      'assets/convert/s2t_phrases.txt',
      'assets/convert/t2s_phrases.txt',
      'assets/convert/tw_chars.txt',
      'assets/convert/hk_chars.txt',
    ];
    final loaded = await Future.wait(
      paths.map((p) => rootBundle.loadString(p)),
    );
    return ChineseConverter._(
      s2tChars: parsePairs(loaded[0]),
      t2sChars: parsePairs(loaded[1]),
      s2tPhrases: parsePairs(loaded[2]),
      t2sPhrases: parsePairs(loaded[3]),
      twChars: parsePairs(loaded[4]),
      hkChars: parsePairs(loaded[5]),
    );
  }

  /// Parses `key<TAB>value` lines.
  @visibleForTesting
  static Map<String, String> parsePairs(String source) {
    final map = <String, String>{};
    for (final line in source.split('\n')) {
      if (line.isEmpty) continue;
      final tab = line.indexOf('\t');
      if (tab <= 0) continue;
      map[line.substring(0, tab)] = line.substring(tab + 1);
    }
    return map;
  }

  static List<int> _distinctLengths(Map<String, String> phrases) {
    final lengths = phrases.keys.map((k) => k.length).toSet().toList()
      ..sort((a, b) => b.compareTo(a));
    return lengths;
  }

  /// Converts [text] according to [mode] and, for Traditional output, the
  /// requested regional [variant].
  String convert(
    String text,
    ChineseConversion mode, [
    TraditionalVariant variant = TraditionalVariant.standard,
  ]) {
    if (mode == ChineseConversion.none || text.isEmpty) return text;

    if (mode == ChineseConversion.toSimplified) {
      return _apply(text, _t2sPhrases, _t2sLengths, _t2sChars);
    }

    final traditional = _apply(text, _s2tPhrases, _s2tLengths, _s2tChars);
    return switch (variant) {
      TraditionalVariant.standard => traditional,
      TraditionalVariant.taiwan => _applyChars(traditional, _twChars),
      TraditionalVariant.hongKong => _applyChars(traditional, _hkChars),
    };
  }

  /// Longest-match phrase replacement with a single character fallback.
  static String _apply(
    String text,
    Map<String, String> phrases,
    List<int> lengths,
    Map<String, String> chars,
  ) {
    final buffer = StringBuffer();
    var index = 0;
    while (index < text.length) {
      var matched = false;
      for (final length in lengths) {
        final end = index + length;
        if (end > text.length) continue;
        final hit = phrases[text.substring(index, end)];
        if (hit != null) {
          buffer.write(hit);
          index = end;
          matched = true;
          break;
        }
      }
      if (matched) continue;
      final char = text[index];
      buffer.write(chars[char] ?? char);
      index++;
    }
    return buffer.toString();
  }

  static String _applyChars(String text, Map<String, String> chars) {
    if (chars.isEmpty) return text;
    final buffer = StringBuffer();
    for (var i = 0; i < text.length; i++) {
      final char = text[i];
      buffer.write(chars[char] ?? char);
    }
    return buffer.toString();
  }
}
