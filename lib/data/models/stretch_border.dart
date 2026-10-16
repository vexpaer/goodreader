/// 一张边框花纹图的切割与铺放方式。
///
/// 边框图按「四角 / 四边 / 中心」九块切分。四个角保持原尺寸，其余块按
/// [StretchMode] 决定的方向拉伸。三个概念各自独立存放，互不推导。
///
/// * **可拉伸矩形**（源图像素）决定四个角与四条边的边界。
/// * **安全框**（卡片比例）决定卡片上文字与图标可以占的范围。安全框与边框
///   图无关，卡片缩放时它始终按卡片计算。
/// * **原图比例**决定边框带在卡片上占多大地方，百分比越小花纹越细。
///
/// 铺放规则：四个角永远不被拉伸。卡片装不下四个角时整张图按同一个系数缩小，
/// 中间的可拉伸块随之塌到零宽，四个角不会被挤压。

import 'dart:math' as math;
import 'dart:ui';

enum StretchMode {
  /// 横竖都能拉，适合四角都有装饰的边框。
  both,

  /// 只横向拉，高度固定，适合横条花边。
  horizontal,

  /// 只纵向拉，宽度固定，适合竖条花边。
  vertical,
}

extension StretchModeLabel on StretchMode {
  String get label => switch (this) {
        StretchMode.both => '全部',
        StretchMode.horizontal => '水平',
        StretchMode.vertical => '垂直',
      };

  bool get stretchesX => this != StretchMode.vertical;
  bool get stretchesY => this != StretchMode.horizontal;
}

/// 卡片上文字与图标可占的范围，按卡片宽高的比例表示。
///
/// 存比例而不是像素，卡片尺寸变化时安全框始终落在卡片的同一相对位置。
class SafeArea {
  const SafeArea({
    this.left = 0.08,
    this.top = 0.10,
    this.right = 0.08,
    this.bottom = 0.10,
  });

  const SafeArea.zero()
      : left = 0,
        top = 0,
        right = 0,
        bottom = 0;

  final double left;
  final double top;
  final double right;
  final double bottom;

  /// 安全框在卡片上的矩形。四边各自独立夹到合法区间，不会交叉。
  Rect rectOf(Size card) => Rect.fromLTRB(
        card.width * left.clamp(0.0, 1.0),
        card.height * top.clamp(0.0, 1.0),
        card.width * (1 - right.clamp(0.0, 1.0)),
        card.height * (1 - bottom.clamp(0.0, 1.0)),
      );

  SafeArea copyWith({
    double? left,
    double? top,
    double? right,
    double? bottom,
  }) =>
      SafeArea(
        left: left ?? this.left,
        top: top ?? this.top,
        right: right ?? this.right,
        bottom: bottom ?? this.bottom,
      );

  @override
  bool operator ==(Object other) =>
      other is SafeArea &&
      other.left == left &&
      other.top == top &&
      other.right == right &&
      other.bottom == bottom;

  @override
  int get hashCode => Object.hash(left, top, right, bottom);
}

/// 边框图的一块切片。[src] 取自原图像素，[dst] 落在边框带内。
class BorderSlice {
  const BorderSlice({
    required this.src,
    required this.dst,
    required this.stretchesX,
    required this.stretchesY,
  });

  final Rect src;
  final Rect dst;
  final bool stretchesX;
  final bool stretchesY;

  bool get isCorner => !stretchesX && !stretchesY;

  @override
  String toString() =>
      'BorderSlice(src: $src, dst: $dst, x: $stretchesX, y: $stretchesY)';
}

/// 一次铺放的结果。[slices] 顺序固定为行优先：左上、上中、右上、左中、
/// 中心、右中、左下、下中、右下。
class StretchLayout {
  const StretchLayout({
    required this.band,
    required this.slices,
    required this.card,
    required this.scale,
  });

  static const empty = StretchLayout(
    band: Rect.zero,
    slices: [],
    card: Size.zero,
    scale: 0,
  );

  bool get isEmpty => slices.isEmpty;

  /// 边框带在卡片上的位置与尺寸，始终居中。
  final Rect band;

  final List<BorderSlice> slices;
  final Size card;

  /// 实际生效的图片缩放系数，源图像素乘以它得到目标像素。
  final double scale;
}

/// 边框图的切割方式与铺放规则。
///
/// 不变式由 [StretchBorder.create] 保证：可拉伸矩形被夹回图内，安全框比例被
/// 夹到 0 到 1。调用方不需要自己做校验。
class StretchBorder {
  const StretchBorder._({
    required this.width,
    required this.height,
    required this.stretchLeft,
    required this.stretchTop,
    required this.stretchRight,
    required this.stretchBottom,
    required this.safe,
    required this.mode,
  });

  factory StretchBorder.create({
    required int width,
    required int height,
    int stretchLeft = 0,
    int stretchTop = 0,
    int stretchRight = 0,
    int stretchBottom = 0,
    SafeArea? safe,
    StretchMode mode = StretchMode.both,
    double imageScale = 1.0,
  }) {
    final w = math.max(3, width);
    final h = math.max(3, height);
    return StretchBorder._(
      width: w,
      height: h,
      stretchLeft: stretchLeft.clamp(0, w - 1),
      stretchTop: stretchTop.clamp(0, h - 1),
      stretchRight: stretchRight.clamp(1, w),
      stretchBottom: stretchBottom.clamp(1, h),
      safe: safe ?? const SafeArea(),
      mode: mode,
      imageScale: imageScale.clamp(0.05, 1.0),
    );
  }

  /// 新导入一张图时的默认切法：横向与纵向都取中间三分之一。
  factory StretchBorder.guess({required int width, required int height}) {
    final w = math.max(3, width);
    final h = math.max(3, height);
    return StretchBorder.create(
      width: w,
      height: h,
      stretchLeft: w ~/ 3,
      stretchTop: h ~/ 3,
      stretchRight: (w * 2) ~/ 3,
      stretchBottom: (h * 2) ~/ 3,
    );
  }

  final int width;
  final int height;

  /// 可拉伸矩形的四条边界，源图像素。
  final int stretchLeft;
  final int stretchTop;
  final int stretchRight;
  final int stretchBottom;
  final SafeArea safe;
  final StretchMode mode;

  /// 边框图在卡片上的显示比例，百分比越小花纹越细。
  final double imageScale;

  Rect get stretchRect => Rect.fromLTRB(
        stretchLeft.toDouble(),
        stretchTop.toDouble(),
        stretchRight.toDouble(),
        stretchBottom.toDouble(),
      );

  bool get isGuessCut =>
      stretchLeft == width ~/ 3 &&
      stretchTop == height ~/ 3 &&
      stretchRight == (width * 2) ~/ 3 &&
      stretchBottom == (height * 2) ~/ 3;

  /// 四个角所需的最小尺寸。绿线交叉拖动时它会超过图片尺寸，这时必须整体缩小。
  Size get minBand => Size(
        (stretchLeft + (width - stretchRight)).toDouble(),
        (stretchTop + (height - stretchBottom)).toDouble(),
      );

  StretchBorder copyWith({
    int? stretchLeft,
    int? stretchTop,
    int? stretchRight,
    int? stretchBottom,
    SafeArea? safe,
    StretchMode? mode,
    double? imageScale,
  }) =>
      StretchBorder.create(
        width: width,
        height: height,
        stretchLeft: stretchLeft ?? this.stretchLeft,
        stretchTop: stretchTop ?? this.stretchTop,
        stretchRight: stretchRight ?? this.stretchRight,
        stretchBottom: stretchBottom ?? this.stretchBottom,
        safe: safe ?? this.safe,
        mode: mode ?? this.mode,
        imageScale: imageScale ?? this.imageScale,
      );

  /// 把边框铺到 [card] 上。[scale] 是边框图宽度的显示比例。
  ///
  /// 整张图先按 [scale] 统一缩放到 [u]（100% 时图片宽度铺满卡片宽度），
  /// 四个角跟着一起等比缩放所以花纹会变粗变细，然后再按 9-patch 让中间的
  /// 块吃掉剩余空间。缩放系数还有三个上界，各自防止溢出：图不高于卡片、
  /// 四个角不宽于卡片、四个角不高于卡片。
  StretchLayout layout(Size card, {double? scale}) {
    if (card.width <= 0 || card.height <= 0) return StretchLayout.empty;

    final requested = (scale ?? imageScale).clamp(0.05, 1.0);
    var u = requested * card.width / width;
    u = math.min(u, card.height / height);

    final min = minBand;
    if (min.width > 0) u = math.min(u, card.width / min.width);
    if (min.height > 0) u = math.min(u, card.height / min.height);
    if (u <= 0) return StretchLayout.empty;

    final bandWidth = mode.stretchesX ? card.width : width * u;
    final bandHeight = mode.stretchesY ? card.height : height * u;

    final head = stretchLeft * u;
    final tail = (width - stretchRight) * u;
    final top = stretchTop * u;
    final bottom = (height - stretchBottom) * u;
    final middleW = math.max(0.0, bandWidth - head - tail);
    final middleH = math.max(0.0, bandHeight - top - bottom);

    final colSrc = [
      0.0,
      stretchLeft.toDouble(),
      stretchRight.toDouble(),
      width.toDouble(),
    ];
    final rowSrc = [
      0.0,
      stretchTop.toDouble(),
      stretchBottom.toDouble(),
      height.toDouble(),
    ];
    final colDst = [0.0, head, head + middleW, bandWidth];
    final rowDst = [0.0, top, top + middleH, bandHeight];

    final originX = (card.width - bandWidth) / 2;
    final originY = (card.height - bandHeight) / 2;

    final slices = <BorderSlice>[];
    for (var row = 0; row < 3; row++) {
      for (var col = 0; col < 3; col++) {
        slices.add(BorderSlice(
          stretchesX: mode.stretchesX && col == 1,
          stretchesY: mode.stretchesY && row == 1,
          src: Rect.fromLTRB(
            colSrc[col],
            rowSrc[row],
            colSrc[col + 1],
            rowSrc[row + 1],
          ),
          dst: Rect.fromLTRB(
            colDst[col] + originX,
            rowDst[row] + originY,
            colDst[col + 1] + originX,
            rowDst[row + 1] + originY,
          ),
        ));
      }
    }

    return StretchLayout(
      band: Rect.fromLTWH(originX, originY, bandWidth, bandHeight),
      slices: slices,
      card: card,
      scale: u,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is StretchBorder &&
      other.width == width &&
      other.height == height &&
      other.stretchLeft == stretchLeft &&
      other.stretchTop == stretchTop &&
      other.stretchRight == stretchRight &&
      other.stretchBottom == stretchBottom &&
      other.safe == safe &&
      other.mode == mode &&
      other.imageScale == imageScale;

  @override
  int get hashCode => Object.hash(
        width,
        height,
        stretchLeft,
        stretchTop,
        stretchRight,
        stretchBottom,
        safe,
        mode,
        imageScale,
      );
}
