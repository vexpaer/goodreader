import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:goodreader/data/models/stretch_border.dart';

/// 九个切片必须在横竖两个方向上都无缝拼成边框带。
void expectTilesFillBand(StretchLayout layout, String label) {
  expect(layout.slices.length, 9, reason: label);

  // 同一列三块的左右边界对齐，同一行三块的上下边界对齐。
  for (var c = 0; c < 3; c++) {
    expect(layout.slices[c].dst.left, closeTo(layout.slices[3 + c].dst.left, 1e-6));
    expect(layout.slices[3 + c].dst.left, closeTo(layout.slices[6 + c].dst.left, 1e-6));
    expect(layout.slices[c].dst.right, closeTo(layout.slices[3 + c].dst.right, 1e-6));
    expect(layout.slices[3 + c].dst.right, closeTo(layout.slices[6 + c].dst.right, 1e-6));
  }
  for (var r = 0; r < 3; r++) {
    for (var c = 1; c < 3; c++) {
      expect(layout.slices[r * 3 + c].dst.top,
          closeTo(layout.slices[r * 3].dst.top, 1e-6));
      expect(layout.slices[r * 3 + c].dst.bottom,
          closeTo(layout.slices[r * 3].dst.bottom, 1e-6));
    }
  }

  // 三列宽度之和与三行高度之和正好是边框带。
  final widths = [for (var c = 0; c < 3; c++) layout.slices[c].dst.width];
  final heights = [for (var r = 0; r < 3; r++) layout.slices[r * 3].dst.height];
  expect(widths.reduce((a, b) => a + b), closeTo(layout.band.width, 1e-6), reason: label);
  expect(heights.reduce((a, b) => a + b), closeTo(layout.band.height, 1e-6), reason: label);

  // 四个角切片正好是边框带的四个角。
  expect(layout.slices[0].dst.left, closeTo(layout.band.left, 1e-6));
  expect(layout.slices[0].dst.top, closeTo(layout.band.top, 1e-6));
  expect(layout.slices[2].dst.right, closeTo(layout.band.right, 1e-6));
  expect(layout.slices[2].dst.top, closeTo(layout.band.top, 1e-6));
  expect(layout.slices[6].dst.left, closeTo(layout.band.left, 1e-6));
  expect(layout.slices[6].dst.bottom, closeTo(layout.band.bottom, 1e-6));
  expect(layout.slices[8].dst.right, closeTo(layout.band.right, 1e-6));
  expect(layout.slices[8].dst.bottom, closeTo(layout.band.bottom, 1e-6));

  for (var i = 0; i < 9; i++) {
    expect(layout.slices[i].dst.width, greaterThanOrEqualTo(-1e-9), reason: '$label slice $i');
    expect(layout.slices[i].dst.height, greaterThanOrEqualTo(-1e-9), reason: '$label slice $i');
  }
}

/// 四个角只被等比缩放，没有被非等比拉伸变形。
void expectCornersUniform(StretchLayout layout, String label) {
  for (final i in [0, 2, 6, 8]) {
    final s = layout.slices[i];
    if (s.src.isEmpty) continue;
    final sx = s.dst.width / s.src.width;
    final sy = s.dst.height / s.src.height;
    expect(sx, closeTo(sy, 1e-6), reason: '$label corner $i ($sx vs $sy)');
  }
}

/// [closeTo] 只接数字，Rect 只能逐边比。
void expectRect(Rect actual, Rect expected, String reason) {
  expect(actual.left, closeTo(expected.left, 1e-6), reason: reason);
  expect(actual.top, closeTo(expected.top, 1e-6), reason: reason);
  expect(actual.right, closeTo(expected.right, 1e-6), reason: reason);
  expect(actual.bottom, closeTo(expected.bottom, 1e-6), reason: reason);
}

void main() {
  group('StretchBorder.create 夹住非法输入', () {
    test('可拉伸矩形被夹回图内', () {
      final b = StretchBorder.create(
        width: 100,
        height: 100,
        stretchLeft: -50,
        stretchTop: 400,
        stretchRight: 999,
        stretchBottom: -20,
      );
      expect(b.stretchLeft, 0);
      expect(b.stretchTop, 99);
      expect(b.stretchRight, 100);
      expect(b.stretchBottom, 1);
    });

    test('安全框四边各自夹到合法区间', () {
      final b = StretchBorder.create(
        width: 10,
        height: 10,
        safe: SafeArea(left: -1, top: 4, right: 9, bottom: 0.5),
      );
      final r = b.safe.rectOf(const Size(200, 100));
      expect(r.left, 0);
      expect(r.top, 100);
      expect(r.right, closeTo(0, 1e-9));
      expect(r.bottom, closeTo(50, 1e-9));
    });

    test('guess 切法取中间三分之一', () {
      final b = StretchBorder.guess(width: 300, height: 300);
      expect(b.stretchLeft, 100);
      expect(b.stretchTop, 100);
      expect(b.stretchRight, 200);
      expect(b.stretchBottom, 200);
      expect(b.isGuessCut, isTrue);
    });
  });

  group('layout 铺放', () {
    test('卡片尺寸等于图尺寸时是恒等布局', () {
      final b = StretchBorder.guess(width: 300, height: 300);
      final l = b.layout(const Size(300, 300));
      expectTilesFillBand(l, 'identity');
      expect(l.scale, closeTo(1, 1e-9));
      for (var i = 0; i < 9; i++) {
        expectRect(l.slices[i].dst, l.slices[i].src, 'slice $i');
      }
      expect(l.slices[4].dst.width, 100);
      expect(l.slices[4].dst.height, 100);
    });

    test('横长卡片上中间列吃掉多余宽度，四个角保持原尺寸', () {
      final b = StretchBorder.guess(width: 300, height: 300);
      final l = b.layout(const Size(600, 300));
      expectTilesFillBand(l, 'wide');

      expect(l.slices[0].dst.width, closeTo(100, 1e-6));
      expect(l.slices[0].dst.height, closeTo(100, 1e-6));
      expect(l.slices[2].dst.width, closeTo(100, 1e-6));
      expect(l.slices[8].dst.width, closeTo(100, 1e-6));

      // 中间列从源图 100px 拉到 400px，中间行不变。
      expect(l.slices[4].dst.width, closeTo(400, 1e-6));
      expect(l.slices[4].dst.height, closeTo(100, 1e-6));

      // 只有中间列与中间行拉伸，四个角不拉。
      expect(l.slices[0].isCorner, isTrue);
      expect(l.slices[2].isCorner, isTrue);
      expect(l.slices[6].isCorner, isTrue);
      expect(l.slices[8].isCorner, isTrue);
      expect(l.slices[4].stretchesX, isTrue);
      expect(l.slices[4].stretchesY, isTrue);
      expect(l.slices[1].stretchesX, isTrue);
      expect(l.slices[1].stretchesY, isFalse);
      expect(l.slices[3].stretchesY, isTrue);
      expect(l.slices[3].stretchesX, isFalse);
    });

    test('卡片大于图时四个角被等比放大，不会被拉变形', () {
      final b = StretchBorder.guess(width: 300, height: 300);
      final l = b.layout(const Size(600, 600));
      expectTilesFillBand(l, 'grow');
      expectCornersUniform(l, 'grow');
      expect(l.band.width, 600);
      expect(l.band.height, 600);
      expect(l.slices[0].dst.width, closeTo(200, 1e-6));
      expect(l.slices[0].dst.height, closeTo(200, 1e-6));
      expect(l.slices[4].dst.width, closeTo(200, 1e-6));
    });

    test('水平模式高度固定，只有横向拉伸', () {
      final b = StretchBorder.create(
        width: 300,
        height: 60,
        stretchLeft: 0,
        stretchTop: 0,
        stretchRight: 300,
        stretchBottom: 60,
        mode: BorderStretchMode.horizontal,
      );
      final l = b.layout(const Size(600, 400));
      expectTilesFillBand(l, 'horizontal');
      for (final s in l.slices) {
        expect(s.stretchesY, isFalse);
      }
      expect(l.slices[4].dst.width, closeTo(600, 1e-6));
      // 图片等比放大到铺满卡片宽度，所以横条高度也变成两倍。
      expect(l.slices[4].dst.height, closeTo(120, 1e-6));
    });

    test('垂直模式宽度固定，只有纵向拉伸', () {
      final b = StretchBorder.create(
        width: 60,
        height: 300,
        stretchLeft: 0,
        stretchTop: 0,
        stretchRight: 60,
        stretchBottom: 300,
        mode: BorderStretchMode.vertical,
      );
      final l = b.layout(const Size(400, 600));
      expectTilesFillBand(l, 'vertical');
      for (final s in l.slices) {
        expect(s.stretchesX, isFalse);
      }
      expect(l.slices[4].dst.height, closeTo(600, 1e-6));
      expect(l.slices[4].dst.width, closeTo(120, 1e-6));
    });

    test('比例减半时四个角随之减半，花纹更细', () {
      final b = StretchBorder.guess(width: 300, height: 300);
      const card = Size(400, 400);
      final full = b.layout(card, scale: 1.0);
      final half = b.layout(card, scale: 0.5);
      expectTilesFillBand(half, 'half');
      expect(half.slices[0].dst.width, closeTo(full.slices[0].dst.width / 2, 1e-6));
      expect(half.slices[0].dst.height, closeTo(full.slices[0].dst.height / 2, 1e-6));
      expect(half.scale, closeTo(full.scale / 2, 1e-6));
      // 边框带仍然铺满卡片，缩小的是角而不是留白。
      expect(half.band.width, closeTo(card.width, 1e-6));
    });

    test('绿线交叉拖动导致四个角放不下时整体等比缩小', () {
      final b = StretchBorder.create(
        width: 300,
        height: 300,
        stretchLeft: 250,
        stretchTop: 250,
        stretchRight: 50,
        stretchBottom: 50,
      );
      expect(b.minBand.width, closeTo(500, 1e-9));
      final l = b.layout(const Size(400, 400));
      expectTilesFillBand(l, 'crossed');
      expectCornersUniform(l, 'crossed');
      // 两个 250px 的角乘以 0.8 后各 200px，正好铺满 400px，中间没有剩余。
      expect(l.slices[0].dst.width, closeTo(200, 1e-6));
      expect(l.slices[0].dst.height, closeTo(200, 1e-6));
      expect(l.slices[4].dst.width, closeTo(0, 1e-6));
      expect(l.scale, closeTo(0.8, 1e-9));
    });

    test('边框带不超出卡片且始终居中', () {
      final b = StretchBorder.guess(width: 300, height: 300);
      const card = Size(400, 700);
      for (final scale in [0.1, 0.35, 0.6, 1.0]) {
        final l = b.layout(card, scale: scale);
        expect(l.band.left, greaterThanOrEqualTo(-1e-6));
        expect(l.band.top, greaterThanOrEqualTo(-1e-6));
        expect(l.band.right, lessThanOrEqualTo(card.width + 1e-6));
        expect(l.band.bottom, lessThanOrEqualTo(card.height + 1e-6));
        expect(l.band.center.dx, closeTo(card.width / 2, 1e-6), reason: 'scale $scale');
        expect(l.band.center.dy, closeTo(card.height / 2, 1e-6));
        expectTilesFillBand(l, 'centred $scale');
      }
    });

    test('零尺寸与非法尺寸返回空布局而不是抛异常', () {
      final b = StretchBorder.guess(width: 300, height: 300);
      expect(b.layout(Size.zero).isEmpty, isTrue);
      expect(b.layout(const Size(-10, 10)).isEmpty, isTrue);
    });
  });

  group('SafeArea', () {
    test('比例映射到卡片', () {
      const s = SafeArea(left: 0.1, top: 0.2, right: 0.3, bottom: 0.4);
      final r = s.rectOf(const Size(200, 100));
      expect(r.left, closeTo(20, 1e-9));
      expect(r.top, closeTo(20, 1e-9));
      expect(r.right, closeTo(140, 1e-9));
      expect(r.bottom, closeTo(60, 1e-9));
    });

    test('缩放卡片时安全框保持相对位置', () {
      const s = SafeArea(left: 0.1, top: 0.1, right: 0.1, bottom: 0.1);
      final a = s.rectOf(const Size(200, 200));
      final b = s.rectOf(const Size(400, 400));
      expect(b.left / a.left, closeTo(2, 1e-9));
      expect(b.width / a.width, closeTo(2, 1e-9));
    });

    test('copyWith 与相等性', () {
      const s = SafeArea(left: 0.1, top: 0.1, right: 0.1, bottom: 0.1);
      expect(
        s.copyWith(left: 0.2),
        const SafeArea(left: 0.2, top: 0.1, right: 0.1, bottom: 0.1),
      );
      expect(const SafeArea.zero(), const SafeArea(left: 0, top: 0, right: 0, bottom: 0));
    });
  });

  group('相等性与 copyWith', () {
    test('相同参数相等，改动任一字段即不等', () {
      final a = StretchBorder.guess(width: 100, height: 100);
      final b = StretchBorder.guess(width: 100, height: 100);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a.copyWith(stretchLeft: 10), isNot(a));
      expect(a.copyWith(mode: BorderStretchMode.vertical).mode, BorderStretchMode.vertical);
    });

    test('copyWith 经过校验，写坏的值仍被夹回', () {
      final a = StretchBorder.guess(width: 100, height: 100);
      expect(a.copyWith(stretchLeft: -5).stretchLeft, 0);
      expect(a.copyWith(stretchRight: 999).stretchRight, 100);
    });
  });
}
