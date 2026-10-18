/// 分享海报的内容与样式。
///
/// 配色不是随手挑的：`night` 直接取目标应用内容模板 CSS 里的那套值
/// （`#121418` 底 / `#EEE9DF` 字 / `#73C7B6` 点缀），其余三套取阅读主题
/// 背景图的实测平均色，所以海报和阅读界面在同一个色系里。
library;

import 'package:flutter/material.dart';

import '../../../data/models/book.dart';
import '../../../data/models/note.dart';

/// 海报内容类型。
enum PosterKind {
  /// 摘录卡：一句划线或一段想法。
  quote,

  /// 书籍卡：封面 + 书名 + 简介。
  book,
}

extension PosterKindLabel on PosterKind {
  String get label => switch (this) {
        PosterKind.quote => '摘录卡',
        PosterKind.book => '书籍卡',
      };
}

/// 海报配色。
enum PosterPalette { night, ink, sand, moss }

extension PosterPaletteStyle on PosterPalette {
  String get label => switch (this) {
        PosterPalette.night => '夜读',
        PosterPalette.ink => '墨白',
        PosterPalette.sand => '沙金',
        PosterPalette.moss => '苔青',
      };

  Color get background => switch (this) {
        PosterPalette.night => const Color(0xFF121418),
        PosterPalette.ink => const Color(0xFFF7F4EC),
        PosterPalette.sand => const Color(0xFFE8DCC3),
        PosterPalette.moss => const Color(0xFFD3D5C8),
      };

  Color get foreground => switch (this) {
        PosterPalette.night => const Color(0xFFEEE9DF),
        PosterPalette.ink => const Color(0xFF1B1A18),
        PosterPalette.sand => const Color(0xFF2A2620),
        PosterPalette.moss => const Color(0xFF22261F),
      };

  /// 次级文字。不用半透明，因为半透明在不同底色上对比度不可控。
  Color get muted => switch (this) {
        PosterPalette.night => const Color(0xFF9CA3AF),
        PosterPalette.ink => const Color(0xFF6E6A62),
        PosterPalette.sand => const Color(0xFF6B6153),
        PosterPalette.moss => const Color(0xFF5C6157),
      };

  Color get accent => switch (this) {
        PosterPalette.night => const Color(0xFF73C7B6),
        PosterPalette.ink => const Color(0xFF1F7A68),
        PosterPalette.sand => const Color(0xFFA8763E),
        PosterPalette.moss => const Color(0xFF4C6B4F),
      };

  bool get isDark => background.computeLuminance() < 0.4;
}

/// 海报比例。
enum PosterAspect { portrait, square, story }

extension PosterAspectSize on PosterAspect {
  String get label => switch (this) {
        PosterAspect.portrait => '3:4',
        PosterAspect.square => '1:1',
        PosterAspect.story => '9:16',
      };

  /// 宽 / 高。
  double get ratio => switch (this) {
        PosterAspect.portrait => 3 / 4,
        PosterAspect.square => 1.0,
        PosterAspect.story => 9 / 16,
      };

  /// 以宽度为基准算出画布尺寸。导出时按 [width] 放大到 1080 左右。
  Size canvasSize({double width = 360}) => Size(width, width / ratio);

  /// 正文最多几行。
  ///
  /// 按比例给，不是按高度算：同一段摘录在 9:16 里能放下更多行，给一样的行数
  /// 会浪费下半张图；1:1 反过来，给多了会溢出。
  int get bodyMaxLines => switch (this) {
        PosterAspect.portrait => 12,
        PosterAspect.square => 8,
        PosterAspect.story => 18,
      };
}

/// 一张海报要画什么。
class PosterSpec {
  const PosterSpec({
    this.kind = PosterKind.quote,
    this.palette = PosterPalette.night,
    this.aspect = PosterAspect.portrait,
    this.title = '',
    this.body = '',
    this.footer = '',
    this.borderAssetId,
    this.borderScale = 1.0,
    this.showQuoteMark = true,
  });

  final PosterKind kind;
  final PosterPalette palette;
  final PosterAspect aspect;

  /// 书名或标题。
  final String title;

  /// 摘录正文或简介。
  final String body;

  /// 作者、章节或来源。
  final String footer;

  /// 用图库里的哪张边框花纹图。null 表示不加边框。
  final String? borderAssetId;

  /// 边框带占画布的比例，越小花纹越细。
  final double borderScale;

  /// 摘录卡左上角的大引号。
  final bool showQuoteMark;

  PosterSpec copyWith({
    PosterKind? kind,
    PosterPalette? palette,
    PosterAspect? aspect,
    String? title,
    String? body,
    String? footer,
    Object? borderAssetId = _unchanged,
    double? borderScale,
    bool? showQuoteMark,
  }) =>
      PosterSpec(
        kind: kind ?? this.kind,
        palette: palette ?? this.palette,
        aspect: aspect ?? this.aspect,
        title: title ?? this.title,
        body: body ?? this.body,
        footer: footer ?? this.footer,
        // 边框要能被清掉，所以用哨兵值区分「没传」和「传了 null」。
        borderAssetId: identical(borderAssetId, _unchanged)
            ? this.borderAssetId
            : borderAssetId as String?,
        borderScale: borderScale ?? this.borderScale,
        showQuoteMark: showQuoteMark ?? this.showQuoteMark,
      );

  static const _unchanged = Object();

  /// 内容是否为空。空的摘录卡导出出来就是一张纯色图，没有意义。
  bool get isBlank => title.trim().isEmpty && body.trim().isEmpty;
}

/// 排版尺寸，全部按画布宽度取比例。
///
/// 按比例而不是固定值，是为了让 3:4 与 9:16 在同一个缩放倍数下看起来一致：
/// 导出时宽度固定 1080，字号跟着宽度走，比例不同只改变高度。
class PosterMetrics {
  const PosterMetrics._({
    required this.padding,
    required this.titleSize,
    required this.bodySize,
    required this.footerSize,
    required this.gap,
    required this.quoteMarkSize,
    required this.ruleWidth,
  });

  factory PosterMetrics.of(double width) {
    final safe = width <= 0 ? 360.0 : width;
    return PosterMetrics._(
      padding: safe * _paddingFactor,
      titleSize: safe * _titleFactor,
      bodySize: safe * _bodyFactor,
      footerSize: safe * _footerFactor,
      gap: safe * _gapFactor,
      quoteMarkSize: safe * _quoteFactor,
      ruleWidth: safe * _ruleFactor,
    );
  }

  static const _paddingFactor = 0.085;
  static const _titleFactor = 0.072;
  static const _bodyFactor = 0.047;
  static const _footerFactor = 0.033;
  static const _gapFactor = 0.045;
  static const _quoteFactor = 0.16;
  static const _ruleFactor = 0.09;

  final double padding;
  final double titleSize;
  final double bodySize;
  final double footerSize;
  final double gap;
  final double quoteMarkSize;

  /// 标题下方那条装饰短线。
  final double ruleWidth;
}

/// 规整海报正文。
///
/// 摘录里常带换行与缩进空格，直接排进去会出现忽长忽短的空行。这里把行内空白
/// 压成一个空格，连续空行压成一行，首尾去掉，但不合并换行本身——想法类笔记的
/// 分段是有意义的。
String normalizePosterText(String raw) {
  final unified = raw.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  final lines = unified
      .split('\n')
      .map((line) => line.replaceAll(RegExp(r'[ \t\u3000]+'), ' ').trim())
      .toList();

  final out = <String>[];
  for (final line in lines) {
    if (line.isEmpty && out.isNotEmpty && out.last.isEmpty) continue;
    out.add(line);
  }
  while (out.isNotEmpty && out.first.isEmpty) {
    out.removeAt(0);
  }
  while (out.isNotEmpty && out.last.isEmpty) {
    out.removeLast();
  }
  return out.join('\n');
}

/// 超长摘录截断。海报是一张图，塞进三千字只会缩成看不见的字。
String truncateForPoster(String text, {int maxChars = 220}) {
  final normalized = normalizePosterText(text);
  if (normalized.length <= maxChars) return normalized;
  // 回退到最近的标点或空格，避免把一句话从中间切断。
  final window = normalized.substring(0, maxChars);
  final lastBreak = window.lastIndexOf(RegExp(r'[。！？；，、\n ]'));
  final cut = lastBreak > maxChars * 0.6 ? lastBreak + 1 : maxChars;
  return '${window.substring(0, cut).trimRight()}…';
}

/// 从一条笔记生成摘录卡。
///
/// 有原文用原文，只有想法用想法：想法类笔记常常没有划线（用户直接写一段话），
/// 这时候正文就是那段话。
PosterSpec specForNote({required BookNote note, Book? book}) {
  final quote = note.text.trim().isNotEmpty ? note.text : note.note;
  // 用 author 而不是 displayAuthor：后者在作者为空时会补「佚名」，
  // 而海报上印一个「佚名」不如什么都不印。
  final author = book?.author.trim() ?? '';
  final footer = [
    if (author.isNotEmpty) author,
    '第 ${note.chapterIndex + 1} 章',
  ].join(' · ');

  return PosterSpec(
    kind: PosterKind.quote,
    title: book?.title ?? '未命名',
    body: quote,
    footer: footer,
  );
}

/// 从一本书生成书籍卡。
PosterSpec specForBook(Book book) => PosterSpec(
      kind: PosterKind.book,
      title: book.title,
      body: book.intro,
      footer: [book.displayAuthor, book.format.label].join(' · '),
    );
