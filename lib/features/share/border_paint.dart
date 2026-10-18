import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../data/models/stretch_border.dart';

/// 把九宫格的九块切片画到画布上。
///
/// 设计器与海报共用这一段：设计器要在上面再画绿线橙框，海报只要花纹本身。
/// 两份实现迟早会不一致，所以抽出来。
void paintNinePatch(
  Canvas canvas,
  ui.Image image,
  StretchLayout layout, {
  double scale = 1.0,
}) {
  // 海报会把边框从 360 逻辑宽度放大到 1080，用低质量的采样会糊成一片。
  final paint = Paint()..filterQuality = FilterQuality.medium;
  for (final slice in layout.slices) {
    if (slice.dst.isEmpty || slice.src.isEmpty) continue;
    final dst = scale == 1.0
        ? slice.dst
        : Rect.fromLTRB(
            slice.dst.left * scale,
            slice.dst.top * scale,
            slice.dst.right * scale,
            slice.dst.bottom * scale,
          );
    canvas.drawImageRect(image, slice.src, dst, paint);
  }
}
