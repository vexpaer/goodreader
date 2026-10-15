import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:fast_gbk/fast_gbk.dart';

import '../../../data/models/chapter.dart';
import 'document.dart';

/// Splits a plain text book into chapters using headings, with a fallback to
/// fixed-size chunks so that every TXT file is readable.
class TxtDocument implements ReaderDocument {
  TxtDocument._(this._text, this.chapters);

  final String _text;

  @override
  final List<ChapterMeta> chapters;

  static const defaultChapterRule =
      r'^[ \t\u3000]*((?:第\s*[0-9零一二三四五六七八九十百千万两]{1,10}\s*[章节回卷部篇集幕])|(?:Chapter\s+[0-9IVXLCivxlc]+)|(?:序章|序言|前言|楔子|引子|后记|尾声|终章|番外|大结局))[^\n]{0,40}$';

  static const _fallbackChunkSize = 6000;

  static Future<TxtDocument> open(String path, {String? rule}) async {
    final bytes = await File(path).readAsBytes();
    final decoded = decodeBytes(bytes);
    final chapters = splitChapters(decoded.text, rule: rule);
    return TxtDocument._(decoded.text, chapters);
  }

  /// Detects the encoding and decodes the raw bytes.
  static ({String text, String encoding}) decodeBytes(Uint8List bytes) {
    if (bytes.length >= 3 &&
        bytes[0] == 0xEF &&
        bytes[1] == 0xBB &&
        bytes[2] == 0xBF) {
      return (
        text: utf8.decode(bytes.sublist(3), allowMalformed: true),
        encoding: 'utf-8',
      );
    }
    if (bytes.length >= 2 && bytes[0] == 0xFF && bytes[1] == 0xFE) {
      return (text: _decodeUtf16(bytes.sublist(2), true), encoding: 'utf-16le');
    }
    if (bytes.length >= 2 && bytes[0] == 0xFE && bytes[1] == 0xFF) {
      return (
        text: _decodeUtf16(bytes.sublist(2), false),
        encoding: 'utf-16be',
      );
    }

    try {
      return (text: utf8.decode(bytes), encoding: 'utf-8');
    } on FormatException {
      // Not valid UTF-8 - assume GBK, the most common legacy Chinese encoding.
      try {
        return (
          text: GbkCodec(allowMalformed: true).decode(bytes),
          encoding: 'gbk',
        );
      } catch (_) {
        return (
          text: utf8.decode(bytes, allowMalformed: true),
          encoding: 'utf-8',
        );
      }
    }
  }

  static String _decodeUtf16(Uint8List bytes, bool littleEndian) {
    final units = <int>[];
    for (var i = 0; i + 1 < bytes.length; i += 2) {
      units.add(littleEndian
          ? bytes[i] | (bytes[i + 1] << 8)
          : (bytes[i] << 8) | bytes[i + 1]);
    }
    return String.fromCharCodes(units);
  }

  /// Builds chapter offsets for [text].
  static List<ChapterMeta> splitChapters(String text, {String? rule}) {
    final pattern = _compileRule(rule);
    final matches = pattern.allMatches(text).toList();
    final chapters = <ChapterMeta>[];

    if (matches.length >= 2) {
      if (matches.first.start > 0) {
        final head = text.substring(0, matches.first.start).trim();
        if (head.isNotEmpty) {
          chapters.add(ChapterMeta(
            index: 0,
            title: '开始',
            start: 0,
            end: matches.first.start,
          ));
        }
      }
      for (var i = 0; i < matches.length; i++) {
        final m = matches[i];
        final end = i + 1 < matches.length ? matches[i + 1].start : text.length;
        final title = m.group(0)!.trim();
        chapters.add(ChapterMeta(
          index: chapters.length,
          title: title.isEmpty ? '第 ${chapters.length + 1} 章' : title,
          start: m.start,
          end: end,
        ));
      }
    }

    if (chapters.isEmpty) {
      var cursor = 0;
      var i = 0;
      while (cursor < text.length) {
        final end =
            (cursor + _fallbackChunkSize) < text.length ? cursor + _fallbackChunkSize : text.length;
        chapters.add(ChapterMeta(
          index: i,
          title: '第 ${i + 1} 节',
          start: cursor,
          end: end,
        ));
        cursor = end;
        i++;
      }
      if (chapters.isEmpty) {
        chapters.add(ChapterMeta(index: 0, title: '正文', start: 0, end: 0));
      }
    }

    return chapters;
  }

  static RegExp _compileRule(String? rule) {
    if (rule != null && rule.trim().isNotEmpty) {
      try {
        return RegExp(rule, multiLine: true);
      } catch (_) {
        // Fall through to the built-in rule.
      }
    }
    return RegExp(defaultChapterRule, multiLine: true);
  }

  @override
  Future<String> chapterText(int index) async {
    if (index < 0 || index >= chapters.length) return '';
    final c = chapters[index];
    final start = c.start.clamp(0, _text.length);
    final end = c.end.clamp(start, _text.length);
    return _text.substring(start, end);
  }

  /// The whole decoded source, used by full-text search.
  String get fullText => _text;
}
