import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../data/models/stretch_border.dart';
import '../border_paint.dart';

/// 边框在卡片上的实时预览，同时是设计器的编辑面。
///
/// 四条绿线是图片里可拉伸矩形的边界，橙框是卡片上文字可占的安全区。
/// 拖拽时先找最近的一条线，按到线外的空白处不会改变任何值。
class BorderPreview extends StatefulWidget {
  const BorderPreview({
    super.key,
    required this.cut,
    required this.image,
    required this.cardSize,
    required this.editable,
    required this.onChanged,
  });

  final StretchBorder cut;
  final ui.Image? image;
  final Size cardSize;
  final bool editable;
  final ValueChanged<StretchBorder> onChanged;

  @override
  State<BorderPreview> createState() => _BorderPreviewState();
}

class _BorderPreviewState extends State<BorderPreview> {
  static const _hitSlop = 20.0;

  String? _activeHandle;

  @override
  Widget build(BuildContext context) {
    final layout = widget.cut.layout(widget.cardSize);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanStart: widget.editable
          ? (d) => setState(() => _activeHandle =
              _nearestHandle(d.localPosition, layout))
          : null,
      onPanEnd: widget.editable
          ? (_) => setState(() => _activeHandle = null)
          : null,
      onPanUpdate:
          widget.editable ? (d) => _drag(d.localPosition, layout) : null,
      child: CustomPaint(
        size: widget.cardSize,
        painter: _BorderPainter(
          cut: widget.cut,
          image: widget.image,
          layout: layout,
          cardSize: widget.cardSize,
          activeHandle: _activeHandle,
        ),
      ),
    );
  }

  void _drag(Offset position, StretchLayout layout) {
    final handle = _activeHandle;
    if (handle == null) return;

    if (handle.startsWith('stretch')) {
      if (layout.scale <= 0) return;
      final band = layout.band;
      final source = Offset(
        (position.dx - band.left) / layout.scale,
        (position.dy - band.top) / layout.scale,
      );
      widget.onChanged(switch (handle) {
        'stretchLeft' => widget.cut.copyWith(stretchLeft: source.dx.round()),
        'stretchTop' => widget.cut.copyWith(stretchTop: source.dy.round()),
        'stretchRight' => widget.cut.copyWith(stretchRight: source.dx.round()),
        _ => widget.cut.copyWith(stretchBottom: source.dy.round()),
      });
      return;
    }

    final fraction = Offset(
      (position.dx / widget.cardSize.width).clamp(0.0, 1.0),
      (position.dy / widget.cardSize.height).clamp(0.0, 1.0),
    );
    widget.onChanged(switch (handle) {
      'safeLeft' =>
        widget.cut.copyWith(safe: widget.cut.safe.copyWith(left: fraction.dx)),
      'safeTop' =>
        widget.cut.copyWith(safe: widget.cut.safe.copyWith(top: fraction.dy)),
      'safeRight' => widget.cut.copyWith(
          safe: widget.cut.safe.copyWith(right: 1 - fraction.dx)),
      _ => widget.cut.copyWith(
          safe: widget.cut.safe.copyWith(bottom: 1 - fraction.dy)),
    });
  }

  /// 按到线外的空白处返回 null，所以不会误改数值。
  String? _nearestHandle(Offset position, StretchLayout layout) {
    final candidates = <MapEntry<double, String>>[];

    void consider(String name, double distance) {
      if (distance <= _hitSlop) candidates.add(MapEntry(distance, name));
    }

    if (layout.scale > 0) {
      final band = layout.band;
      consider('stretchLeft',
          (position.dx - (band.left + widget.cut.stretchLeft * layout.scale)).abs());
      consider('stretchRight',
          (position.dx - (band.left + widget.cut.stretchRight * layout.scale)).abs());
      consider('stretchTop',
          (position.dy - (band.top + widget.cut.stretchTop * layout.scale)).abs());
      consider('stretchBottom',
          (position.dy - (band.top + widget.cut.stretchBottom * layout.scale)).abs());
    }

    final safe = widget.cut.safe.rectOf(widget.cardSize);
    consider('safeLeft', (position.dx - safe.left).abs());
    consider('safeRight', (position.dx - safe.right).abs());
    consider('safeTop', (position.dy - safe.top).abs());
    consider('safeBottom', (position.dy - safe.bottom).abs());

    if (candidates.isEmpty) return null;
    candidates.sort((a, b) => a.key.compareTo(b.key));
    return candidates.first.value;
  }
}

class _BorderPainter extends CustomPainter {
  const _BorderPainter({
    required this.cut,
    required this.image,
    required this.layout,
    required this.cardSize,
    required this.activeHandle,
  });

  final StretchBorder cut;
  final ui.Image? image;
  final StretchLayout layout;
  final Size cardSize;
  final String? activeHandle;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFFF5F1E8));

    final image = this.image;
    if (image != null) {
      paintNinePatch(canvas, image, layout);
    } else {
      final wire = Paint()
        ..color = const Color(0x33000000)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1;
      canvas.drawRect(layout.band, wire);
      for (var i = 1; i < 3; i++) {
        final x = layout.band.left + layout.band.width * i / 3;
        canvas.drawLine(
            Offset(x, layout.band.top), Offset(x, layout.band.bottom), wire);
        final y = layout.band.top + layout.band.height * i / 3;
        canvas.drawLine(
            Offset(layout.band.left, y), Offset(layout.band.right, y), wire);
      }
    }

    _paintStretchLines(canvas);
    _paintSafeArea(canvas);
  }

  void _paintStretchLines(Canvas canvas) {
    final band = layout.band;
    if (band.isEmpty || layout.scale <= 0) return;

    void line(String handle, Offset a, Offset b) {
      final paint = Paint()
        ..color = handle == activeHandle
            ? const Color(0xFF1B7A43)
            : const Color(0xFF2E9E5B)
        ..strokeWidth = handle == activeHandle ? 2.6 : 1.6;
      _dashed(canvas, a, b, paint);
    }

    final x1 = band.left + cut.stretchLeft * layout.scale;
    final x2 = band.left + cut.stretchRight * layout.scale;
    final y1 = band.top + cut.stretchTop * layout.scale;
    final y2 = band.top + cut.stretchBottom * layout.scale;

    line('stretchLeft', Offset(x1, band.top), Offset(x1, band.bottom));
    line('stretchRight', Offset(x2, band.top), Offset(x2, band.bottom));
    line('stretchTop', Offset(band.left, y1), Offset(band.right, y1));
    line('stretchBottom', Offset(band.left, y2), Offset(band.right, y2));
  }

  void _paintSafeArea(Canvas canvas) {
    final safe = cut.safe.rectOf(cardSize);
    if (safe.isEmpty) return;

    canvas.drawRect(safe, Paint()..color = const Color(0x1FE2792B));
    canvas.drawRect(
      safe,
      Paint()
        ..color = activeHandle?.startsWith('safe') ?? false
            ? const Color(0xFFC25E12)
            : const Color(0xFFE2792B)
        ..strokeWidth = 1.8
        ..style = PaintingStyle.stroke,
    );
  }

  void _dashed(Canvas canvas, Offset a, Offset b, Paint paint) {
    const dash = 6.0;
    const gap = 4.0;
    final total = (b - a).distance;
    if (total <= 0) return;
    final dir = (b - a) / total;
    var travelled = 0.0;
    while (travelled < total) {
      final end = math.min(travelled + dash, total);
      canvas.drawLine(a + dir * travelled, a + dir * end, paint);
      travelled = end + gap;
    }
  }

  @override
  bool shouldRepaint(_BorderPainter old) =>
      old.cut != cut ||
      old.image != image ||
      old.cardSize != cardSize ||
      old.activeHandle != activeHandle;
}
