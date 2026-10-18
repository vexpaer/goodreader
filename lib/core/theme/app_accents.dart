import 'package:flutter/material.dart';

/// 应用配色变体。
///
/// 色值来自目标应用主题预览图的**实测主色**（`assets/icons/variant/preview/*.png`，
/// 8×8 面积平均降采样后聚类）。10 个变体对应 11 张预览图——`app.png` 与
/// `dark.png` 的主色完全一致（`#010101` 占 75%），是同一套主题的两个名字。
///
/// 这些只是 `ColorScheme.fromSeed` 的种子，不是最终界面色。种子决定色相与
/// 冷暖，深浅由 `themeMode` 决定。
class AppAccent {
  const AppAccent(this.name, this.seed);

  final String name;
  final int seed;

  Color get color => Color(seed);
}

const appAccents = <AppAccent>[
  AppAccent('深色', 0xFF010101),
  AppAccent('浅色', 0xFFFDFDFD),
  AppAccent('银灰', 0xFFBFC0C0),
  AppAccent('炭灰', 0xFF434343),
  AppAccent('经典', 0xFFD3C3AA),
  AppAccent('蓝', 0xFF2457E1),
  AppAccent('海洋蓝', 0xFF346BEB),
  AppAccent('青', 0xFF5495EB),
  AppAccent('紫', 0xFF523CD0),
  AppAccent('紫罗兰', 0xFF5A43D9),
];

/// 找不到匹配时的默认配色（深色）。目标应用的默认主题就是深色。
const defaultAccentSeed = 0xFF010101;

/// 按种子找变体。用户存的是颜色值，名字只用于显示。
AppAccent? accentOf(int seed) {
  for (final accent in appAccents) {
    if (accent.seed == seed) return accent;
  }
  return null;
}
