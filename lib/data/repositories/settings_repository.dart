import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

import '../db/hive_setup.dart';
import '../../core/theme/app_accents.dart';
import '../models/bottom_bar.dart';
import '../models/shelf_appearance.dart';
import '../models/text_conversion.dart';

/// Built-in reader background themes.
enum ReaderTheme {
  paper,
  cream,
  sepia,
  eyeGreen,
  moss,
  graphite,
  blueGray,
  warmBrown,
  night,
  black,
}

extension ReaderThemeX on ReaderTheme {
  String get label => switch (this) {
        ReaderTheme.paper => '纸张',
        ReaderTheme.cream => '米色',
        ReaderTheme.sepia => '羊皮卷',
        ReaderTheme.eyeGreen => '护眼绿',
        ReaderTheme.moss => '青苔绿',
        ReaderTheme.graphite => '石墨灰',
        ReaderTheme.blueGray => '蓝灰',
        ReaderTheme.warmBrown => '暖棕',
        ReaderTheme.night => '夜间',
        ReaderTheme.black => '纯黑',
      };

  Color get background => switch (this) {
        ReaderTheme.paper => const Color(0xFFF7F3E9),
        ReaderTheme.cream => const Color(0xFFFBF6E9),
        ReaderTheme.sepia => const Color(0xFFF1E3C8),
        ReaderTheme.eyeGreen => const Color(0xFFCCE8CF),
        ReaderTheme.moss => const Color(0xFFDCE5D4),
        ReaderTheme.graphite => const Color(0xFF3A3F44),
        ReaderTheme.blueGray => const Color(0xFF2B3440),
        ReaderTheme.warmBrown => const Color(0xFF2A211C),
        ReaderTheme.night => const Color(0xFF1B1D1F),
        ReaderTheme.black => const Color(0xFF000000),
      };

  Color get foreground => switch (this) {
        ReaderTheme.paper => const Color(0xFF2B2B2B),
        ReaderTheme.cream => const Color(0xFF3A3226),
        ReaderTheme.sepia => const Color(0xFF4A3B2A),
        ReaderTheme.eyeGreen => const Color(0xFF23331F),
        ReaderTheme.moss => const Color(0xFF2A3327),
        ReaderTheme.graphite => const Color(0xFFD8DCE0),
        ReaderTheme.blueGray => const Color(0xFFC7D2DE),
        ReaderTheme.warmBrown => const Color(0xFFD8C6B4),
        ReaderTheme.night => const Color(0xFFB9BFC6),
        ReaderTheme.black => const Color(0xFF8A8F95),
      };

  /// Secondary colour for headers, footers and progress chrome.
  Color get muted => foreground.withOpacity(0.55);

  bool get isDark =>
      this == ReaderTheme.graphite ||
      this == ReaderTheme.blueGray ||
      this == ReaderTheme.warmBrown ||
      this == ReaderTheme.night ||
      this == ReaderTheme.black;
}

/// Page turn animation style.
enum PageTurnStyle { none, slide, cover, simulation, fade }

extension PageTurnStyleX on PageTurnStyle {
  String get label => switch (this) {
        PageTurnStyle.none => '无动画',
        PageTurnStyle.slide => '平移',
        PageTurnStyle.cover => '覆盖',
        PageTurnStyle.simulation => '仿真',
        PageTurnStyle.fade => '淡入',
      };
}

/// Page frame drawn around the text column.
enum PageBorderStyle { none, line, doubleLine }

extension PageBorderStyleX on PageBorderStyle {
  String get label => switch (this) {
        PageBorderStyle.none => '无版框',
        PageBorderStyle.line => '细线',
        PageBorderStyle.doubleLine => '外细内粗',
      };
}

/// Text alignment inside the reader.
enum ReaderTextAlign { justify, left }

extension ReaderTextAlignX on ReaderTextAlign {
  String get label => switch (this) {
        ReaderTextAlign.justify => '两端对齐',
        ReaderTextAlign.left => '左对齐',
      };

  TextAlign get textAlign =>
      this == ReaderTextAlign.justify ? TextAlign.justify : TextAlign.left;
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
    this.paragraphIndent = 2,
    this.paragraphSpacing = 0,
    this.textAlign = ReaderTextAlign.justify,
    this.dropCap = false,
    this.pageTurnStyle = PageTurnStyle.slide,
    this.autoPageSeconds = 0,
    this.keepScreenOn = true,
    this.showHeader = true,
    this.showFooter = true,
    this.headerTemplate = '%章节%',
    this.footerTemplate = '%进度%',
    this.headerFooterSize = 11,
    this.pageBorder = PageBorderStyle.none,
    this.brightness = -1,
    this.highlightColor = 0xFFFFD54F,
    this.verticalText = false,
    this.chineseConversion = ChineseConversion.none,
    this.traditionalVariant = TraditionalVariant.standard,
    this.einkMode = false,
    this.scrollMode = false,
    this.pinchZoom = true,
    this.pageTurnSound = false,
    this.pageTurnHaptic = true,
  });

  ReaderTheme theme;
  double fontSize;
  double lineHeight;
  double letterSpacing;
  double pageMargin;
  String fontFamily;
  int paragraphIndent;
  double paragraphSpacing;
  ReaderTextAlign textAlign;

  /// Draws an enlarged first character at the start of every chapter.
  bool dropCap;

  PageTurnStyle pageTurnStyle;

  /// 0 disables auto page turning.
  int autoPageSeconds;
  bool keepScreenOn;
  bool showHeader;
  bool showFooter;

  /// Supports the macros listed in [ReaderMacros].
  String headerTemplate;
  String footerTemplate;
  double headerFooterSize;
  PageBorderStyle pageBorder;

  /// `-1` follows the system brightness, otherwise `0..1`.
  double brightness;

  /// Colour applied to new highlights.
  int highlightColor;

  bool verticalText;

  /// Script conversion applied to every chapter before rendering.
  ChineseConversion chineseConversion;
  TraditionalVariant traditionalVariant;

  /// E-ink friendly rendering: no page animation, flat chrome, high contrast.
  bool einkMode;

  /// Continuous vertical scrolling instead of page-by-page turning.
  bool scrollMode;

  /// Allows pinch-to-zoom on the page content.
  bool pinchZoom;

  bool pageTurnSound;
  bool pageTurnHaptic;

  Map<String, dynamic> toMap() => {
        'theme': theme.index,
        'fontSize': fontSize,
        'lineHeight': lineHeight,
        'letterSpacing': letterSpacing,
        'pageMargin': pageMargin,
        'fontFamily': fontFamily,
        'paragraphIndent': paragraphIndent,
        'paragraphSpacing': paragraphSpacing,
        'textAlign': textAlign.index,
        'dropCap': dropCap,
        'pageTurnStyle': pageTurnStyle.index,
        'autoPageSeconds': autoPageSeconds,
        'keepScreenOn': keepScreenOn,
        'showHeader': showHeader,
        'showFooter': showFooter,
        'headerTemplate': headerTemplate,
        'footerTemplate': footerTemplate,
        'headerFooterSize': headerFooterSize,
        'pageBorder': pageBorder.index,
        'brightness': brightness,
        'highlightColor': highlightColor,
        'verticalText': verticalText,
        'chineseConversion': chineseConversion.index,
        'traditionalVariant': traditionalVariant.index,
        'einkMode': einkMode,
        'scrollMode': scrollMode,
        'pinchZoom': pinchZoom,
        'pageTurnSound': pageTurnSound,
        'pageTurnHaptic': pageTurnHaptic,
      };

  static ReaderSettings fromMap(Map<dynamic, dynamic>? m) {
    if (m == null) return ReaderSettings();
    T pick<T>(String key, T fallback) {
      final v = m[key];
      return v is T ? v : fallback;
    }

    return ReaderSettings(
      theme: ReaderTheme.values[pick('theme', ReaderTheme.paper.index)],
      fontSize: pick<num>('fontSize', 18).toDouble(),
      lineHeight: pick<num>('lineHeight', 1.7).toDouble(),
      letterSpacing: pick<num>('letterSpacing', 0.2).toDouble(),
      pageMargin: pick<num>('pageMargin', 20).toDouble(),
      fontFamily: pick('fontFamily', '系统默认'),
      paragraphIndent: pick('paragraphIndent', 2),
      paragraphSpacing: pick<num>('paragraphSpacing', 0).toDouble(),
      textAlign: ReaderTextAlign.values[
          pick('textAlign', ReaderTextAlign.justify.index)],
      dropCap: pick('dropCap', false),
      pageTurnStyle:
          PageTurnStyle.values[pick('pageTurnStyle', PageTurnStyle.slide.index)],
      autoPageSeconds: pick('autoPageSeconds', 0),
      keepScreenOn: pick('keepScreenOn', true),
      showHeader: pick('showHeader', true),
      showFooter: pick('showFooter', true),
      headerTemplate: pick('headerTemplate', '%章节%'),
      footerTemplate: pick('footerTemplate', '%进度%'),
      headerFooterSize: pick<num>('headerFooterSize', 11).toDouble(),
      pageBorder: PageBorderStyle.values[pick('pageBorder', 0)],
      brightness: pick<num>('brightness', -1).toDouble(),
      highlightColor: pick('highlightColor', 0xFFFFD54F),
      verticalText: pick('verticalText', false),
      chineseConversion: ChineseConversion.values[
          pick('chineseConversion', ChineseConversion.none.index)],
      traditionalVariant: TraditionalVariant.values[
          pick('traditionalVariant', TraditionalVariant.standard.index)],
      einkMode: pick('einkMode', false),
      scrollMode: pick('scrollMode', false),
      pinchZoom: pick('pinchZoom', true),
      pageTurnSound: pick('pageTurnSound', false),
      pageTurnHaptic: pick('pageTurnHaptic', true),
    );
  }
}

/// Macros usable inside the header and footer templates.
class ReaderMacros {
  const ReaderMacros._();

  static const all = <String, String>{
    '%书名%': '当前书名',
    '%章节%': '当前章节名',
    '%卷名%': '当前卷名',
    '%进度%': '本章阅读百分比',
    '%全书%': '全书阅读百分比',
    '%页码%': '章节序号 / 总章节数',
    '%时间%': '当前时间',
    '%电量%': '电池电量',
  };

  static String render(
    String template, {
    required String bookTitle,
    required String chapterTitle,
    required String volumeTitle,
    required double chapterProgress,
    required double bookProgress,
    required int chapterIndex,
    required int chapterCount,
    required DateTime now,
    int? batteryLevel,
    bool charging = false,
  }) {
    final battery = batteryLevel == null
        ? ''
        : '$batteryLevel%${charging ? ' ⚡' : ''}';
    return template
        .replaceAll('%书名%', bookTitle)
        .replaceAll('%章节%', chapterTitle)
        .replaceAll('%卷名%', volumeTitle)
        .replaceAll('%进度%', '${(chapterProgress * 100).round()}%')
        .replaceAll('%全书%', '${(bookProgress * 100).round()}%')
        .replaceAll('%页码%', '${chapterIndex + 1}/$chapterCount')
        .replaceAll(
          '%时间%',
          '${now.hour.toString().padLeft(2, '0')}:'
              '${now.minute.toString().padLeft(2, '0')}',
        )
        .replaceAll('%电量%', battery);
  }
}

/// App wide preferences.
class AppSettings {
  AppSettings({
    this.themeMode = ThemeMode.system,
    this.seedColor = defaultAccentSeed,
    this.shelfView = ShelfView.grid,
    this.coverFill = CoverFill.crop,
    this.dailyGoalMinutes = 30,
    this.dailyGoalChars = 5000,
    this.yearlyGoalBooks = 20,
    this.ttsRate = 0.5,
    this.ttsPitch = 1.0,
    this.ttsLanguage = 'zh-CN',
    this.autoTtsNextChapter = true,
    this.privacyMode = false,
    this.locale = 'zh',
    BottomBarConfig? bottomBar,
    ShelfAppearance? shelf,
  })  : bottomBar = bottomBar ?? BottomBarConfig(),
        shelf = shelf ?? const ShelfAppearance();

  ThemeMode themeMode;
  int seedColor;
  ShelfView shelfView;
  CoverFill coverFill;
  int dailyGoalMinutes;
  int dailyGoalChars;
  int yearlyGoalBooks;
  double ttsRate;
  double ttsPitch;
  String ttsLanguage;
  bool autoTtsNextChapter;
  bool privacyMode;
  String locale;

  /// 底栏配置。整份存成一个嵌套 Map，而不是拆成七八个平铺字段：
  /// 拆开之后每次加一个底栏选项都要动一次存取两边，还容易漏。
  BottomBarConfig bottomBar;

  /// 书架陈列方式。同样整份存成嵌套 Map。
  ShelfAppearance shelf;

  Map<String, dynamic> toMap() => {
        'themeMode': themeMode.index,
        'seedColor': seedColor,
        'shelfView': shelfView.index,
        'coverFill': coverFill.index,
        'dailyGoalMinutes': dailyGoalMinutes,
        'dailyGoalChars': dailyGoalChars,
        'yearlyGoalBooks': yearlyGoalBooks,
        'ttsRate': ttsRate,
        'ttsPitch': ttsPitch,
        'ttsLanguage': ttsLanguage,
        'autoTtsNextChapter': autoTtsNextChapter,
        'privacyMode': privacyMode,
        'locale': locale,
        'bottomBar': bottomBar.toMap(),
        'shelf': shelf.toMap(),
      };

  static AppSettings fromMap(Map<dynamic, dynamic>? m) {
    if (m == null) return AppSettings();
    T pick<T>(String key, T fallback) {
      final v = m[key];
      return v is T ? v : fallback;
    }

    return AppSettings(
      themeMode: ThemeMode.values[pick('themeMode', ThemeMode.system.index)],
      seedColor: pick('seedColor', defaultAccentSeed),
      shelfView: ShelfView.values[pick('shelfView', 0)],
      coverFill: CoverFill.values[pick('coverFill', CoverFill.crop.index)],
      dailyGoalMinutes: pick('dailyGoalMinutes', 30),
      dailyGoalChars: pick('dailyGoalChars', 5000),
      yearlyGoalBooks: pick('yearlyGoalBooks', 20),
      ttsRate: pick<num>('ttsRate', 0.5).toDouble(),
      ttsPitch: pick<num>('ttsPitch', 1.0).toDouble(),
      ttsLanguage: pick('ttsLanguage', 'zh-CN'),
      autoTtsNextChapter: pick('autoTtsNextChapter', true),
      privacyMode: pick('privacyMode', false),
      locale: pick('locale', 'zh'),
      bottomBar: BottomBarConfig.fromMap(m['bottomBar']),
      shelf: ShelfAppearance.fromMap(m['shelf']),
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

/// How cover artwork fills its frame.
enum CoverFill { crop, fit, stretch }

extension CoverFillX on CoverFill {
  String get label => switch (this) {
        CoverFill.crop => '裁剪填满',
        CoverFill.fit => '完整显示',
        CoverFill.stretch => '拉伸铺满',
      };

  BoxFit get boxFit => switch (this) {
        CoverFill.crop => BoxFit.cover,
        CoverFill.fit => BoxFit.contain,
        CoverFill.stretch => BoxFit.fill,
      };
}

/// Thin typed wrapper over the settings box.
class SettingsRepository {
  SettingsRepository({Box<dynamic>? box})
      : _box = box ?? Hive.box<dynamic>(HiveBoxes.settings);

  final Box<dynamic> _box;

  static const _appKey = 'app';
  static const _readerKey = 'reader';
  static const _searchHistoryKey = 'searchHistory';

  AppSettings loadApp() => AppSettings.fromMap(_box.get(_appKey) as Map?);

  Future<void> saveApp(AppSettings s) => _box.put(_appKey, s.toMap());

  ReaderSettings loadReader() =>
      ReaderSettings.fromMap(_box.get(_readerKey) as Map?);

  Future<void> saveReader(ReaderSettings s) => _box.put(_readerKey, s.toMap());

  List<String> loadSearchHistory() {
    final raw = _box.get(_searchHistoryKey);
    if (raw is List) return raw.whereType<String>().toList();
    return const [];
  }

  Future<void> saveSearchHistory(List<String> history) =>
      _box.put(_searchHistoryKey, history.take(30).toList());
}
