/// 底栏的配置。
///
/// 目标应用把底栏做成可配置的：显示哪些项目、什么顺序、固定还是悬浮、多高、
/// 要不要文字标签、深浅色独立。这里把这些整理成一份配置，渲染与设置页都只读它。
library;

/// 底栏上一个位置的用途。
///
/// 前四个是**页面**（可以停在上面），其余是**动作**（点一下就走）。这个区分很
/// 重要：页面项参与「当前选中」的判断，动作项不参与，否则点完 AI 再回来会发现
/// 底栏没有任何一项是亮的。
enum BottomBarSlot {
  shelf,
  notes,
  stats,
  settings,
  recent,
  ai,
  sources,
  sync,
  ocr,
}

extension BottomBarSlotInfo on BottomBarSlot {
  /// 是否为可停留的页面。
  bool get isPage => switch (this) {
        BottomBarSlot.shelf ||
        BottomBarSlot.notes ||
        BottomBarSlot.stats ||
        BottomBarSlot.settings =>
          true,
        _ => false,
      };

  String get label => switch (this) {
        BottomBarSlot.shelf => '书架',
        BottomBarSlot.notes => '笔记',
        BottomBarSlot.stats => '统计',
        BottomBarSlot.settings => '设置',
        BottomBarSlot.recent => '最近',
        BottomBarSlot.ai => '助手',
        BottomBarSlot.sources => '书源',
        BottomBarSlot.sync => '同步',
        BottomBarSlot.ocr => '识图',
      };

  String get description => switch (this) {
        BottomBarSlot.shelf => '书架与书库',
        BottomBarSlot.notes => '划线、想法、书签',
        BottomBarSlot.stats => '时长、字数、热力图',
        BottomBarSlot.settings => '外观、阅读、数据',
        BottomBarSlot.recent => '直接打开上次在读的书',
        BottomBarSlot.ai => '打开阅读助手',
        BottomBarSlot.sources => '打开书源列表',
        BottomBarSlot.sync => '打开云同步',
        BottomBarSlot.ocr => '图片转文字',
      };
}

/// 底栏形态。
enum BottomBarStyle {
  /// 贴底，背景铺满整个宽度，半透明磨砂。
  fixed,

  /// 悬浮在底部上方，圆角玻璃，左右留边距。
  floating,
}

extension BottomBarStyleLabel on BottomBarStyle {
  String get label => switch (this) {
        BottomBarStyle.fixed => '固定',
        BottomBarStyle.floating => '悬浮',
      };

  String get hint => switch (this) {
        BottomBarStyle.fixed => '贴底并铺满宽度，半透明磨砂背景',
        BottomBarStyle.floating => '浮在底部上方，圆角玻璃质感，可调左右边距',
      };
}

/// 底栏配色。默认跟随应用主题，也可以强制深/浅色。
enum BottomBarTint { inherit, dark, light }

extension BottomBarTintLabel on BottomBarTint {
  String get label => switch (this) {
        BottomBarTint.inherit => '跟随主题',
        BottomBarTint.dark => '深色',
        BottomBarTint.light => '浅色',
      };
}

/// 一份完整的底栏配置。
///
/// [order] 里**永远包含全部槽位**，各一次。[hidden] 决定哪些不显示。
///
/// 这样拆是有意的：如果只存「可见项」，用户把某一项关掉再想打开时就没地方找了；
/// 而且排序和显示是两个动作，混在一个列表里会让「关掉后顺序丢失」。构造函数会
/// 归一化传进来的顺序（去重、补齐缺的、丢掉不认识的），所以坏数据不会让某一项
/// 永久消失。
class BottomBarConfig {
  BottomBarConfig({
    this.style = BottomBarStyle.fixed,
    this.showLabels = true,
    double narrowness = 0.35,
    this.sideMargin = 16,
    this.tint = BottomBarTint.inherit,
    List<BottomBarSlot>? order,
    Set<BottomBarSlot>? hidden,
  })  : narrowness = narrowness.clamp(0.0, 1.0),
        sideMargin = sideMargin.clamp(0.0, 48.0),
        order = normalizeOrder(order),
        hidden = Set.unmodifiable(hidden ?? defaultHidden);

  /// 最矮与最高。目标应用的说明是「数值越大底栏越窄」，所以窄度 0 对应最高。
  static const minHeight = 48.0;
  static const maxHeight = 76.0;

  /// 默认只放四个页面项。其余是可选的动作入口，默认关着——
  /// 九个图标挤在一条底栏上，每个都只有二十来像素宽。
  static const defaultHidden = <BottomBarSlot>{
    BottomBarSlot.recent,
    BottomBarSlot.ai,
    BottomBarSlot.sources,
    BottomBarSlot.sync,
    BottomBarSlot.ocr,
  };

  final BottomBarStyle style;

  /// 图标下方是否显示文字。
  final bool showLabels;

  /// 0 到 1。越大越窄。
  final double narrowness;

  /// 悬浮形态下距离屏幕左右边缘的距离。
  final double sideMargin;

  final BottomBarTint tint;

  /// 全部槽位，按显示顺序排列，包含被隐藏的。
  final List<BottomBarSlot> order;

  final Set<BottomBarSlot> hidden;

  /// 实际显示的项目。
  ///
  /// 全部关掉时退回「只有书架」：一条空的底栏既没法导航也不像话，而这种状态
  /// 用户点得出来（把所有开关都关掉），所以不能让它存在。
  List<BottomBarSlot> get visible {
    final shown = [
      for (final slot in order)
        if (!hidden.contains(slot)) slot,
    ];
    return shown.isEmpty ? const [BottomBarSlot.shelf] : shown;
  }

  /// 底栏高度。窄度越大，高度越小。
  double get height =>
      maxHeight - (maxHeight - minHeight) * narrowness;

  /// 图标尺寸。带文字时图标小一点，否则整条会显得挤。
  double get iconSize => showLabels ? 22 : 24;

  BottomBarConfig copyWith({
    BottomBarStyle? style,
    bool? showLabels,
    double? narrowness,
    double? sideMargin,
    BottomBarTint? tint,
    List<BottomBarSlot>? order,
    Set<BottomBarSlot>? hidden,
  }) =>
      BottomBarConfig(
        style: style ?? this.style,
        showLabels: showLabels ?? this.showLabels,
        narrowness: narrowness ?? this.narrowness,
        sideMargin: sideMargin ?? this.sideMargin,
        tint: tint ?? this.tint,
        order: order ?? this.order,
        hidden: hidden ?? this.hidden,
      );

  /// 调整某一项的显示状态，顺序不动。
  BottomBarConfig withVisibility(BottomBarSlot slot, bool visible) {
    final next = Set<BottomBarSlot>.from(hidden);
    if (visible) {
      next.remove(slot);
    } else {
      next.add(slot);
    }
    return copyWith(hidden: next);
  }

  /// 把 [slot] 挪到 [index]。
  ///
  /// [index] 是**移除之后**那份列表里的位置，越界夹到两端。这样定义是为了让
  /// 它跟 ReorderableListView 的语义对齐：那边的 `newIndex` 是在旧列表上算的，
  /// 往下拖时要先减一，界面层做这个换算，模型只认结果位置。
  BottomBarConfig moveTo(BottomBarSlot slot, int index) {
    final list = order.toList();
    final from = list.indexOf(slot);
    if (from < 0) return this;
    list.removeAt(from);
    final target = index.clamp(0, list.length);
    list.insert(target, slot);
    return copyWith(order: list);
  }

  Map<String, dynamic> toMap() => {
        'style': style.index,
        'showLabels': showLabels,
        'narrowness': narrowness,
        'sideMargin': sideMargin,
        'tint': tint.index,
        'order': order.map((s) => s.index).toList(),
        'hidden': hidden.map((s) => s.index).toList(),
      };

  /// 读回配置。坏字段逐项退回默认值，不抛异常。
  static BottomBarConfig fromMap(Object? raw) {
    if (raw is! Map) return BottomBarConfig();
    T pick<T>(String key, T fallback) {
      final value = raw[key];
      return value is T ? value : fallback;
    }

    final styleIndex = pick('style', BottomBarStyle.fixed.index);
    final tintIndex = pick('tint', BottomBarTint.inherit.index);

    return BottomBarConfig(
      style: styleIndex >= 0 && styleIndex < BottomBarStyle.values.length
          ? BottomBarStyle.values[styleIndex]
          : BottomBarStyle.fixed,
      showLabels: pick('showLabels', true),
      narrowness: pick<num>('narrowness', 0.35).toDouble(),
      sideMargin: pick<num>('sideMargin', 16).toDouble(),
      tint: tintIndex >= 0 && tintIndex < BottomBarTint.values.length
          ? BottomBarTint.values[tintIndex]
          : BottomBarTint.inherit,
      order: _decodeSlots(raw['order']),
      // 缺这个键说明是更早的版本存的，用默认值；存了空列表才是「全显示」。
      hidden: raw.containsKey('hidden')
          ? _decodeSlots(raw['hidden']).toSet()
          : null,
    );
  }

  /// 去重、丢掉越界值，缺失的槽位按枚举顺序补到末尾。
  static List<BottomBarSlot> normalizeOrder(List<BottomBarSlot>? raw) {
    final seen = <BottomBarSlot>{};
    final list = <BottomBarSlot>[];
    for (final slot in raw ?? const <BottomBarSlot>[]) {
      if (seen.add(slot)) list.add(slot);
    }
    for (final slot in BottomBarSlot.values) {
      if (seen.add(slot)) list.add(slot);
    }
    return List.unmodifiable(list);
  }

  static List<BottomBarSlot> _decodeSlots(Object? raw) {
    if (raw is! List) return const [];
    final out = <BottomBarSlot>[];
    for (final item in raw) {
      if (item is! int) continue;
      if (item < 0 || item >= BottomBarSlot.values.length) continue;
      out.add(BottomBarSlot.values[item]);
    }
    return out;
  }
}
