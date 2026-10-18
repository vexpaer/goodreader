/// 书架的陈列方式。
///
/// 目标应用的书架有几个独立的外观开关：封面左侧的书脊光影、每行下方的立体
/// 书架、仅显示封面、按宽度自动列数。它们互不依赖，所以做成四个字段而不是
/// 一个「书架样式」枚举——枚举会变成 2×2×2 的排列组合，加一个选项就要乘 2。
library;

class ShelfAppearance {
  const ShelfAppearance({
    this.spineLight = true,
    this.ledge = false,
    this.coverOnly = false,
    this.columns = autoColumns,
  });

  /// 封面左侧压一道书脊光影。
  final bool spineLight;

  /// 每行封面下方画一条立体书架横条。
  final bool ledge;

  /// 只显示封面，不显示书名与作者。
  final bool coverOnly;

  /// 固定列数。[autoColumns] 表示按可用宽度自动算。
  final int columns;

  static const autoColumns = 0;
  static const minColumns = 2;
  static const maxColumns = 8;

  /// 一格的目标宽度。
  ///
  /// 手机竖屏可用宽度约 328，除以 110 得 2.98，四舍五入正好 3 列——这是中文
  /// 阅读器最常见的排法。用向下取整会退成 2 列，格子宽得能放下整段简介。
  static const targetItemWidth = 110.0;

  /// 书架横条的高度。
  static const ledgeHeight = 9.0;

  /// 封面下方书名加作者占的高度。
  ///
  /// 这个数必须和界面里实际的排版对上，否则网格算出来的格子装不下文字，
  /// 会溢出一条黄黑相间的警告条。所以书名与作者的行高在界面上是写死的：
  /// 8 + 13×1.25×2 + 2 + 11×1.2 = 55.7，取 58 留一点余量。
  static const textBlockHeight = 58.0;

  /// 封面本身的高宽比（2:3）。
  static const coverAspect = 1.5;

  /// 给定可用宽度算列数。固定列数时直接用，越界夹到合法范围。
  int columnsFor(double width) {
    if (columns > autoColumns) return columns.clamp(minColumns, maxColumns);
    if (width <= 0) return minColumns;
    return (width / targetItemWidth).round().clamp(minColumns, maxColumns);
  }

  /// 一格的总高。封面按 [itemWidth] 等比，横条与文字块是固定高度。
  double tileHeight(double itemWidth) =>
      itemWidth * coverAspect +
      (ledge ? ledgeHeight : 0) +
      (coverOnly ? 0 : textBlockHeight);

  /// 网格需要的宽高比。`GridView` 只认比例，所以要按实际格宽算一次。
  double aspectRatioFor(double itemWidth) {
    if (itemWidth <= 0) return 1 / coverAspect;
    return itemWidth / tileHeight(itemWidth);
  }

  ShelfAppearance copyWith({
    bool? spineLight,
    bool? ledge,
    bool? coverOnly,
    int? columns,
  }) =>
      ShelfAppearance(
        spineLight: spineLight ?? this.spineLight,
        ledge: ledge ?? this.ledge,
        coverOnly: coverOnly ?? this.coverOnly,
        columns: columns ?? this.columns,
      );

  Map<String, dynamic> toMap() => {
        'spineLight': spineLight,
        'ledge': ledge,
        'coverOnly': coverOnly,
        'columns': columns,
      };

  static ShelfAppearance fromMap(Object? raw) {
    if (raw is! Map) return const ShelfAppearance();
    T pick<T>(String key, T fallback) {
      final value = raw[key];
      return value is T ? value : fallback;
    }

    return ShelfAppearance(
      spineLight: pick('spineLight', true),
      ledge: pick('ledge', false),
      coverOnly: pick('coverOnly', false),
      columns: pick('columns', autoColumns),
    );
  }
}
