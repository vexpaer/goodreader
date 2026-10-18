import 'package:flutter_test/flutter_test.dart';
import 'package:goodreader/core/theme/app_accents.dart';

void main() {
  test('十个变体，名字与色值都不重复', () {
    // 目标应用有 11 张预览图，其中 app.png 与 dark.png 主色完全一致，
    // 是同一套主题的两个名字，所以去重后是 10 套。
    expect(appAccents.length, 10);

    final names = appAccents.map((a) => a.name).toSet();
    expect(names.length, appAccents.length);

    final seeds = appAccents.map((a) => a.seed).toSet();
    expect(seeds.length, appAccents.length);
  });

  test('每个色值都是不透明的 32 位 ARGB', () {
    for (final accent in appAccents) {
      expect(accent.seed & 0xFF000000, 0xFF000000,
          reason: '${accent.name} 缺少不透明通道');
    }
  });

  test('默认配色在列表里，且是深色', () {
    final accent = accentOf(defaultAccentSeed);
    expect(accent, isNotNull);
    expect(accent!.name, '深色');
  });

  test('按色值能找回名字', () {
    for (final accent in appAccents) {
      expect(accentOf(accent.seed)?.name, accent.name);
    }
  });

  test('不认识的色值返回 null', () {
    expect(accentOf(0xFF123456), isNull);
  });

  test('深色与浅色的亮度分居两端', () {
    final dark = accentOf(0xFF010101)!;
    final light = accentOf(0xFFFDFDFD)!;
    expect(dark.color.computeLuminance(), lessThan(0.05));
    expect(light.color.computeLuminance(), greaterThan(0.9));
  });
}
