import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../data/models/stretch_border.dart';
import '../border_paint.dart';
import 'poster_spec.dart';

/// 海报的画布。
///
/// 按逻辑尺寸排版（默认 360 宽），导出时用 `RepaintBoundary.toImage` 按倍数
/// 放大。这样字号只需要按宽度取比例，不用为每个导出尺寸写一套数值。
///
/// 边框图不是「贴在上面」，而是把内容挤到它的安全区里：安全区是用户在边框
/// 设计器里拖出来的橙框，文字就该待在那儿。
class PosterCanvas extends StatelessWidget {
  const PosterCanvas({
    super.key,
    required this.spec,
    required this.size,
    this.borderImage,
    this.borderCut,
    this.cover,
  });

  final PosterSpec spec;
  final Size size;

  /// 已解码的边框花纹图。null 表示不加边框。
  final ui.Image? borderImage;

  /// 边框的九宫格切割方式。
  final StretchBorder? borderCut;

  /// 书籍卡的封面。由调用方给出，画布只负责摆位置。
  final Widget? cover;

  @override
  Widget build(BuildContext context) {
    final metrics = PosterMetrics.of(size.width);
    final palette = spec.palette;
    final cut = borderCut;
    final image = borderImage;

    final safe = cut?.safe.rectOf(size);
    // 有安全区时内容就放在安全区里，安全区本身已经表达了边距；再套一层 padding
    // 会挤成两倍。只留一点呼吸空间。
    final inset = safe == null ? metrics.padding : metrics.gap * 0.4;
    final candidate = safe == null
        ? Offset.zero & size
        : Rect.fromLTRB(
            safe.left + inset,
            safe.top + inset,
            safe.right - inset,
            safe.bottom - inset,
          );
    // 安全区被拖得极小时，减去呼吸空间会得到负尺寸。负宽高的 Positioned 会直接
    // 断言失败，所以退到整张画布——宁可文字压在花纹上，也不要崩。
    final contentRect = candidate.width > 0 && candidate.height > 0
        ? candidate
        : Offset.zero & size;

    return SizedBox.fromSize(
      size: size,
      child: Stack(
        children: [
          Positioned.fill(child: ColoredBox(color: palette.background)),
          if (image != null && cut != null)
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _FramePainter(
                    image: image,
                    layout: cut.layout(size),
                  ),
                ),
              ),
            ),
          Positioned.fromRect(
            rect: contentRect,
            child: switch (spec.kind) {
              PosterKind.quote => _QuoteBody(
                  spec: spec,
                  metrics: metrics,
                  maxLines: spec.aspect.bodyMaxLines,
                ),
              PosterKind.book => _BookBody(
                  spec: spec,
                  metrics: metrics,
                  maxLines: spec.aspect.bodyMaxLines,
                  cover: cover,
                ),
            },
          ),
        ],
      ),
    );
  }
}

class _FramePainter extends CustomPainter {
  const _FramePainter({required this.image, required this.layout});

  final ui.Image image;
  final StretchLayout layout;

  @override
  void paint(Canvas canvas, Size size) => paintNinePatch(canvas, image, layout);

  @override
  bool shouldRepaint(_FramePainter old) =>
      old.image != image || old.layout.band != layout.band;
}

/// 摘录卡：大引号 → 正文 → 点缀短线 → 书名 → 作者。
class _QuoteBody extends StatelessWidget {
  const _QuoteBody({
    required this.spec,
    required this.metrics,
    required this.maxLines,
  });

  final PosterSpec spec;
  final PosterMetrics metrics;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final palette = spec.palette;
    final body = truncateForPoster(spec.body, maxChars: maxLines * 20);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (spec.showQuoteMark)
          Text(
            '“',
            style: TextStyle(
              fontSize: metrics.quoteMarkSize,
              height: 0.9,
              color: palette.accent,
              fontWeight: FontWeight.w700,
            ),
          ),
        Expanded(
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              body,
              maxLines: maxLines,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: metrics.bodySize,
                height: 1.85,
                letterSpacing: 0.2,
                color: palette.foreground,
              ),
            ),
          ),
        ),
        Container(width: metrics.ruleWidth, height: 2, color: palette.accent),
        SizedBox(height: metrics.gap * 0.7),
        Text(
          spec.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: metrics.titleSize * 0.62,
            height: 1.3,
            fontWeight: FontWeight.w600,
            color: palette.foreground,
          ),
        ),
        if (spec.footer.isNotEmpty) ...[
          SizedBox(height: metrics.gap * 0.28),
          Text(
            spec.footer,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: metrics.footerSize,
              letterSpacing: 1.1,
              color: palette.muted,
            ),
          ),
        ],
      ],
    );
  }
}

/// 书籍卡：封面 → 书名 → 点缀短线 → 作者 → 简介。
class _BookBody extends StatelessWidget {
  const _BookBody({
    required this.spec,
    required this.metrics,
    required this.maxLines,
    required this.cover,
  });

  final PosterSpec spec;
  final PosterMetrics metrics;
  final int maxLines;
  final Widget? cover;

  @override
  Widget build(BuildContext context) {
    final palette = spec.palette;
    final intro = truncateForPoster(spec.body, maxChars: maxLines * 18);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (cover != null) ...[
          Center(child: cover),
          SizedBox(height: metrics.gap),
        ],
        Text(
          spec.title,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: metrics.titleSize,
            height: 1.25,
            fontWeight: FontWeight.w700,
            color: palette.foreground,
          ),
        ),
        SizedBox(height: metrics.gap * 0.5),
        Container(width: metrics.ruleWidth, height: 2, color: palette.accent),
        if (spec.footer.isNotEmpty) ...[
          SizedBox(height: metrics.gap * 0.45),
          Text(
            spec.footer,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: metrics.footerSize,
              letterSpacing: 1.1,
              color: palette.muted,
            ),
          ),
        ],
        if (intro.isNotEmpty) ...[
          SizedBox(height: metrics.gap),
          Expanded(
            child: Text(
              intro,
              maxLines: maxLines,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: metrics.bodySize * 0.92,
                height: 1.72,
                color: palette.foreground,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
