import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

import '../db/hive_setup.dart';

/// Built-in reader background themes.
enum ReaderTheme { paper, sepia, eyeGreen, gray, night, black }

extension ReaderThemeX on ReaderTheme {
  String get label => switch (this) {
        ReaderTheme.paper => '纸张',
        ReaderTheme.sepia => '羊皮卷',
        ReaderTheme.eyeGreen => '护眼绿',
        ReaderTheme.gray => '石墨灰',
        ReaderTheme.night => '夜间',
        ReaderTheme.black => '纯黑',
      };

  Color get background => switch (this) {
        ReaderTheme.paper => const Color(0xFFF7F3E9),
        ReaderTheme.sepia => const Color(0xFFF1E3C8),
        ReaderTheme.eyeGreen => const Color(0xFFCCE8CF),
        ReaderTheme.gray => const Color(0xFF3A3F44),
        ReaderTheme.night => const Color(0xFF1B1D1F),
        ReaderTheme.black => const Color(0xFF000000),
      };

  Color get foreground => switch (this) {
        ReaderTheme.paper => const Color(0xFF2B2B2B),
        ReaderTheme.sepia => const Color(0xFF4A3B2A),
        ReaderTheme.eyeGreen => const Color(0xFF23331F),
        ReaderTheme.gray => const Color(0xFFD8DCE0),
        ReaderTheme.night => const Color(0xFFB9BFC6),
        ReaderTheme.black => const Color(0xFF8A8F95),
      };

  bool get isDark =>
      this == ReaderTheme.gray ||
      this == ReaderTheme.night ||
      this == ReaderTheme.black;
}

/// Page turn animation style.
enum PageTurnStyle { none, slide, cover, scroll }

extension PageTurnStyleX on PageTurnStyle {
  String get label => switch (this) {
        PageTurnStyle.none => '无动画',
        PageTurnStyle.slide => '平移',
        PageTurnStyle.cover => '覆盖',
        PageTurnStyle.scroll => '上下滚动',
      };
}

/// Everything the reader needs to render a page.
class ReaderSettings {
  ReaderSettings({
    this.theme = ReaderTheme.paper,
    this.fontSize = 18,
    this.lineHeight = 1.7,
    this.letterSpacing = 0.2,
    this.pageMargin = 20,
    this.fontFamily = '系统默认',
    this.pageTurnStyle = PageTurnStyle.slide,
    this.autoPageSeconds = 0,
    this.keepScreenOn = true,
    this.showHeader = true,
    this.showFooter = true,
    this.verticalText = false,
    this.paragraphIndent = 2,
  });

  ReaderTheme theme;
  double fontSize;
  double lineHeight;
  double letterSpacing;
  double pageMargin;
  String fontFamily;
  PageTurnStyle pageTurnStyle;

  /// 0 disables auto page turning.
  int autoPageSeconds;
  bool keepScreenOn;
  bool showHeader;
  bool showFooter;
  bool verticalText;
  int paragraphIndent;

  Map<String, dynamic> toMap() => {
        'theme': theme.index,
        'fontSize': fontSize,
        'lineHeight': lineHeight,
        'letterSpacing': letterSpacing,
        'pageMargin': pageMargin,
        'fontFamily': fontFamily,
        'pageTurnStyle': pageTurnStyle.index,
        'autoPageSeconds': autoPageSeconds,
        'keepScreenOn': keepScreenOn,
        'showHeader': showHeader,
        'showFooter': showFooter,
        'verticalText': verticalText,
        'paragraphIndent': paragraphIndent,
      };

  static ReaderSettings fromMap(Map<dynamic, dynamic>? m) {
    if (m == null) return ReaderSettings();
    T pick<T>(String key, T fallback) {
      final v = m[key];
      return v is T ? v : fallback;
    }

    return ReaderSettings(
      theme: ReaderTheme.values[pick('theme', 0)],
      fontSize: pick<num>('fontSize', 18).toDouble(),
      lineHeight: pick<num>('lineHeight', 1.7).toDouble(),
      letterSpacing: pick<num>('letterSpacing', 0.2).toDouble(),
      pageMargin: pick<num>('pageMargin', 20).toDouble(),
      fontFamily: pick('fontFamily', '系统默认'),
      pageTurnStyle: PageTurnStyle.values[pick('pageTurnStyle', 1)],
      autoPageSeconds: pick('autoPageSeconds', 0),
      keepScreenOn: pick('keepScreenOn', true),
      showHeader: pick('showHeader', true),
      showFooter: pick('showFooter', true),
      verticalText: pick('verticalText', false),
      paragraphIndent: pick('paragraphIndent', 2),
    );
  }
}

/// App wide preferences.
class AppSettings {
  AppSettings({
    this.themeMode = ThemeMode.system,
    this.seedColor = 0xFF1F6FEB,
    this.shelfView = ShelfView.grid,
    this.dailyGoalMinutes = 30,
    this.dailyGoalChars = 5000,
    this.yearlyGoalBooks = 20,
    this.ttsRate = 0.5,
    this.ttsPitch = 1.0,
    this.ttsLanguage = 'zh-CN',
    this.autoTtsNextChapter = true,
    this.privacyMode = false,
    this.locale = 'zh',
  });

  ThemeMode themeMode;
  int seedColor;
  ShelfView shelfView;
  int dailyGoalMinutes;
  int dailyGoalChars;
  int yearlyGoalBooks;
  double ttsRate;
  double ttsPitch;
  String ttsLanguage;
  bool autoTtsNextChapter;
  bool privacyMode;
  String locale;

  Map<String, dynamic> toMap() => {
        'themeMode': themeMode.index,
        'seedColor': seedColor,
        'shelfView': shelfView.index,
        'dailyGoalMinutes': dailyGoalMinutes,
        'dailyGoalChars': dailyGoalChars,
        'yearlyGoalBooks': yearlyGoalBooks,
        'ttsRate': ttsRate,
        'ttsPitch': ttsPitch,
        'ttsLanguage': ttsLanguage,
        'autoTtsNextChapter': autoTtsNextChapter,
        'privacyMode': privacyMode,
        'locale': locale,
      };

  static AppSettings fromMap(Map<dynamic, dynamic>? m) {
    if (m == null) return AppSettings();
    T pick<T>(String key, T fallback) {
      final v = m[key];
      return v is T ? v : fallback;
    }

    return AppSettings(
      themeMode: ThemeMode.values[pick('themeMode', ThemeMode.system.index)],
      seedColor: pick('seedColor', 0xFF1F6FEB),
      shelfView: ShelfView.values[pick('shelfView', 0)],
      dailyGoalMinutes: pick('dailyGoalMinutes', 30),
      dailyGoalChars: pick('dailyGoalChars', 5000),
      yearlyGoalBooks: pick('yearlyGoalBooks', 20),
      ttsRate: pick<num>('ttsRate', 0.5).toDouble(),
      ttsPitch: pick<num>('ttsPitch', 1.0).toDouble(),
      ttsLanguage: pick('ttsLanguage', 'zh-CN'),
      autoTtsNextChapter: pick('autoTtsNextChapter', true),
      privacyMode: pick('privacyMode', false),
      locale: pick('locale', 'zh'),
    );
  }
}

enum ShelfView { grid, list, compact }

extension ShelfViewX on ShelfView {
  String get label => switch (this) {
        ShelfView.grid => '网格',
        ShelfView.list => '列表',
        ShelfView.compact => '极简',
      };
}

/// Thin typed wrapper over the settings box.
class SettingsRepository {
  SettingsRepository({Box<dynamic>? box})
      : _box = box ?? Hive.box<dynamic>(HiveBoxes.settings);

  final Box<dynamic> _box;

  static const _appKey = 'app';
  static const _readerKey = 'reader';

  AppSettings loadApp() =>
      AppSettings.fromMap(_box.get(_appKey) as Map?);

  Future<void> saveApp(AppSettings s) => _box.put(_appKey, s.toMap());

  ReaderSettings loadReader() =>
      ReaderSettings.fromMap(_box.get(_readerKey) as Map?);

  Future<void> saveReader(ReaderSettings s) => _box.put(_readerKey, s.toMap());
}
