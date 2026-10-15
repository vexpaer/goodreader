import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/book.dart';
import '../../data/models/chapter.dart';
import '../../data/models/note.dart';
import '../../data/repositories/settings_repository.dart';
import '../../services/native_service.dart';
import '../../services/tts_service.dart';
import '../../state/providers.dart';
import 'engines/document.dart';
import 'engines/epub_engine.dart';
import 'engines/txt_engine.dart';
import 'text_layout.dart';
import 'widgets/catalog_sheet.dart';
import 'widgets/page_turn.dart';
import 'widgets/reader_menu.dart';
import 'widgets/reader_settings_sheet.dart';

/// Highlight palette offered by the selection menu.
const highlightPalette = <int>[
  0xFFFFD54F,
  0xFF81C784,
  0xFF64B5F6,
  0xFFE57373,
  0xFFBA68C8,
  0xFF4DB6AC,
];

class ReaderPage extends ConsumerStatefulWidget {
  const ReaderPage({super.key, required this.bookId});

  final String bookId;

  @override
  ConsumerState<ReaderPage> createState() => _ReaderPageState();
}

class _ReaderPageState extends ConsumerState<ReaderPage> {
  Book? _book;
  ReaderDocument? _doc;
  List<ChapterMeta> _chapters = const [];

  final _pageController = PageController();
  int _index = 0;
  double _scrollOffset = 0;
  int _pendingJumpOffset = 0;

  bool _toolbarVisible = false;
  bool _loading = true;
  String? _error;

  Timer? _autoTimer;
  Timer? _sessionTimer;
  Timer? _clockTimer;
  Timer? _hudTimer;

  int _sessionSeconds = 0;
  int _lastCharMark = 0;

  DateTime _now = DateTime.now();
  BatteryState? _battery;

  TtsService? _ttsInstance;
  bool _speaking = false;

  IconData _hudIcon = Icons.brightness_6_outlined;
  String _hudLabel = '亮度';

  /// Drag origin for the brightness / volume edge gestures. Kept on the state
  /// so it survives the rebuilds triggered by the HUD.
  Offset? _dragStart;

  /// Drives the HUD without rebuilding the pager on every drag frame.
  final _hud = ValueNotifier<double?>(null);

  List<String> _searchHistory = const [];
  double? _brightnessOverride;

  /// One extra page after the last chapter renders the "已读完" screen.
  int get _pageCount => _chapters.length + 1;
  bool get _onFinishPage => _index >= _chapters.length;

  @override
  void initState() {
    super.initState();
    _searchHistory = ref.read(settingsRepositoryProvider).loadSearchHistory();
    _clockTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (!mounted) return;
      setState(() => _now = DateTime.now());
    });
    _refreshBattery();
    _open();
  }

  Future<void> _refreshBattery() async {
    final state = await ref.read(nativeServiceProvider).battery();
    if (!mounted) return;
    setState(() => _battery = state);
  }

  Future<void> _open() async {
    try {
      final repo = ref.read(bookRepositoryProvider);
      final book = repo.byId(widget.bookId);
      if (book == null) {
        setState(() {
          _error = '找不到这本书';
          _loading = false;
        });
        return;
      }

      final ReaderDocument doc = switch (book.format) {
        BookFormat.txt =>
          await TxtDocument.open(book.filePath, rule: book.chapterRule),
        BookFormat.epub => await EpubDocument.open(book.filePath),
        _ => throw BookParseException(
            '${book.format.label} 阅读引擎将在后续版本开放，当前支持 TXT / EPUB。',
          ),
      };

      var chapters = doc.chapters;
      final stored = repo.chaptersOf(book.id);
      if (stored != null && stored.chapters.length == chapters.length) {
        chapters = stored.chapters;
      } else {
        await repo.saveChapters(
          ChapterList(bookId: book.id, chapters: chapters),
        );
      }

      final index = book.lastChapterIndex.clamp(
        0,
        chapters.isEmpty ? 0 : chapters.length - 1,
      );

      if (!mounted) {
        doc.dispose();
        return;
      }
      setState(() {
        _book = book;
        _doc = doc;
        _chapters = chapters;
        _index = index;
        _loading = false;
      });

      _lastCharMark = _charMarkAt(index, book.lastOffset);
      _startSession();
      _applyReaderChrome();

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_pageController.hasClients) return;
        _pageController.jumpToPage(index);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e is BookParseException ? e.message : '$e';
        _loading = false;
      });
    }
  }

  /// Applies brightness and keep-screen-on preferences for this book.
  Future<void> _applyReaderChrome() async {
    final native = ref.read(nativeServiceProvider);
    final settings = ref.read(settingsControllerProvider).reader;
    await native.keepScreenOn(settings.keepScreenOn);
    if (settings.brightness >= 0) {
      _brightnessOverride = settings.brightness;
      await native.setBrightness(settings.brightness);
    } else {
      _brightnessOverride = null;
      await native.resetBrightness();
    }
  }

  // -------------------------------------------------------------------------
  // Session accounting
  // -------------------------------------------------------------------------

  void _startSession() {
    _sessionTimer?.cancel();
    _sessionTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _sessionSeconds++;
    });
  }

  int _charMarkAt(int chapterIndex, int offset) {
    if (_doc is TxtDocument && chapterIndex < _chapters.length) {
      return _chapters[chapterIndex].start + offset;
    }
    return chapterIndex * 3000 + offset;
  }

  double get _overallProgress {
    if (_chapters.isEmpty) return 1;
    if (_onFinishPage) return 1;
    final within = _scrollOffset.clamp(0.0, 1.0);
    return ((_index + within) / _chapters.length).clamp(0.0, 1.0);
  }

  Future<void> _persistProgress() async {
    final book = _book;
    if (book == null) return;
    final current = ref.read(bookRepositoryProvider).byId(book.id);
    if (current == null) return;
    await ref.read(booksControllerProvider).recordProgress(
          current,
          chapterIndex: _index.clamp(0, _chapters.length),
          offset: _scrollOffset.round(),
          progress: _overallProgress,
        );
  }

  Future<void> _flushSession() async {
    final book = _book;
    if (book == null) return;
    final seconds = _sessionSeconds;
    final mark = _charMarkAt(_index.clamp(0, _chapters.length), _scrollOffset.round());
    final chars = (mark - _lastCharMark).clamp(0, 1 << 30);
    _sessionSeconds = 0;
    _lastCharMark = mark;
    if (seconds < 5 && chars == 0) return;
    await ref.read(statsControllerProvider).log(
          bookId: book.id,
          seconds: seconds,
          chars: chars,
        );
  }

  // -------------------------------------------------------------------------
  // Lifecycle
  // -------------------------------------------------------------------------

  @override
  void dispose() {
    _autoTimer?.cancel();
    _sessionTimer?.cancel();
    _clockTimer?.cancel();
    _hudTimer?.cancel();
    _flushSession();
    _persistProgress();
    ref.read(nativeServiceProvider).resetBrightness();
    ref.read(nativeServiceProvider).keepScreenOn(false);
    _doc?.dispose();
    _ttsInstance?.stop();
    _hud.dispose();
    _pageController.dispose();
    super.dispose();
  }

  // -------------------------------------------------------------------------
  // Navigation
  // -------------------------------------------------------------------------

  void _goToPage(int page, {bool animate = true, int offset = 0}) {
    final target = page.clamp(0, _pageCount - 1);
    setState(() => _pendingJumpOffset = offset);
    if (animate && _pageController.hasClients) {
      _pageController.animateToPage(
        target,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    } else if (_pageController.hasClients) {
      _pageController.jumpToPage(target);
    } else {
      setState(() => _index = target);
    }
  }

  void _toggleAutoPage(int seconds) {
    _autoTimer?.cancel();
    if (seconds <= 0) return;
    _autoTimer = Timer.periodic(Duration(seconds: seconds), (_) {
      if (_index + 1 < _pageCount) {
        _goToPage(_index + 1);
      } else {
        _autoTimer?.cancel();
      }
    });
  }

  // -------------------------------------------------------------------------
  // Edge gestures: brightness (left) and volume (right)
  // -------------------------------------------------------------------------

  void _handleVerticalDrag(Offset start, double primaryDelta, Size size) {
    final isLeft = start.dx < size.width * 0.25;
    final isRight = start.dx > size.width * 0.75;
    if (!isLeft && !isRight) return;

    final native = ref.read(nativeServiceProvider);
    if (isLeft) {
      _brightnessOverride ??= 0.5;
      final next = (_brightnessOverride! - primaryDelta / 320).clamp(0.02, 1.0);
      _brightnessOverride = next;
      native.setBrightness(next);
      _showHud(Icons.brightness_6_outlined, '亮度', next);
    } else {
      native.volume().then((current) {
        if (!mounted) return;
        final base = current ?? 0.5;
        final next = (base - primaryDelta / 320).clamp(0.0, 1.0);
        native.setVolume(next);
        _showHud(Icons.volume_up_outlined, '音量', next);
      });
    }
  }

  void _showHud(IconData icon, String label, double value) {
    _hudIcon = icon;
    _hudLabel = label;
    _hud.value = value;
    _hudTimer?.cancel();
    _hudTimer = Timer(const Duration(milliseconds: 900), () {
      if (mounted) _hud.value = null;
    });
  }

  // -------------------------------------------------------------------------
  // TTS
  // -------------------------------------------------------------------------

  TtsService get _ttsService {
    final existing = _ttsInstance;
    if (existing != null) return existing;
    final TtsService created = ref.read<TtsService>(ttsServiceProvider);
    _ttsInstance = created;
    return created;
  }

  Future<void> _toggleTts() async {
    final settings = ref.read(settingsControllerProvider).app;
    final tts = _ttsService;

    if (_speaking) {
      await tts.stop();
      if (mounted) setState(() => _speaking = false);
      return;
    }
    if (_onFinishPage) return;

    await tts.configure(
      rate: settings.ttsRate,
      pitch: settings.ttsPitch,
      language: settings.ttsLanguage,
    );
    tts.onCompleted = () {
      if (!mounted) return;
      if (settings.autoTtsNextChapter && _index + 1 < _chapters.length) {
        _goToPage(_index + 1);
        Future<void>.delayed(const Duration(milliseconds: 400), _speakCurrent);
      } else {
        setState(() => _speaking = false);
      }
    };
    tts.onCancelled = () {
      if (mounted) setState(() => _speaking = false);
    };
    setState(() => _speaking = true);
    await _speakCurrent();
  }

  Future<void> _speakCurrent() async {
    final doc = _doc;
    if (doc == null || _onFinishPage) return;
    final text = await doc.chapterText(_index);
    if (text.trim().isEmpty) return;
    await _ttsInstance?.speak(text);
  }

  // -------------------------------------------------------------------------
  // Notes
  // -------------------------------------------------------------------------

  Future<void> _addHighlight(
    String rawText,
    int rawStart,
    int rawEnd, {
    int? color,
  }) async {
    final book = _book;
    if (book == null) return;
    final text = rawText.substring(
      rawStart.clamp(0, rawText.length),
      rawEnd.clamp(0, rawText.length),
    );
    if (text.trim().isEmpty) return;

    final chosen = color ?? ref.read(settingsControllerProvider).reader.highlightColor;
    await ref.read(notesControllerProvider).addHighlight(
          bookId: book.id,
          chapterIndex: _index,
          start: rawStart,
          end: rawEnd,
          text: text,
          color: chosen,
        );
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _pickHighlightColor(String rawText, int start, int end) async {
    final theme = ref.read(settingsControllerProvider).reader.theme;
    final chosen = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('选择划线颜色',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: highlightPalette
                    .map(
                      (c) => GestureDetector(
                        onTap: () => Navigator.pop(context, c),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Color(c),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: theme.foreground.withOpacity(0.2),
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
          ),
        ),
      ),
    );
    if (chosen != null) {
      await _addHighlight(rawText, start, end, color: chosen);
    }
  }

  Future<void> _addNote(String rawText, int start, int end) async {
    final book = _book;
    if (book == null) return;
    final quote = rawText.substring(
      start.clamp(0, rawText.length),
      end.clamp(0, rawText.length),
    );
    final controller = TextEditingController();
    final saved = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('添加笔记'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (quote.trim().isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Theme.of(c).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  quote,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              maxLines: 4,
              autofocus: true,
              decoration: const InputDecoration(hintText: '写下你的想法…'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, controller.text),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    if (saved == null || saved.trim().isEmpty) return;
    await ref.read(notesControllerProvider).save(
          BookNote(
            id: '${book.id}-$_index-${DateTime.now().microsecondsSinceEpoch}',
            bookId: book.id,
            type: NoteType.thought,
            chapterIndex: _index,
            start: start,
            end: end,
            text: quote,
            note: saved,
          ),
        );
    if (mounted) setState(() {});
  }

  Future<void> _addBookmark() async {
    final book = _book;
    if (book == null || _onFinishPage) return;
    await ref.read(notesControllerProvider).addBookmark(
          bookId: book.id,
          chapterIndex: _index,
          offset: _scrollOffset.round(),
          text: _chapters[_index].title,
        );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已添加书签'), duration: Duration(seconds: 1)),
    );
  }

  // -------------------------------------------------------------------------
  // Build
  // -------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsControllerProvider).reader;
    final theme = settings.theme;

    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('无法打开')),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(child: Text(_error!, textAlign: TextAlign.center)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: theme.background,
      body: SafeArea(
        child: Stack(
          children: [
            _buildGestureLayer(settings),
            ValueListenableBuilder<double?>(
              valueListenable: _hud,
              builder: (context, value, _) => value == null
                  ? const SizedBox.shrink()
                  : ReaderHud(
                      theme: theme,
                      icon: _hudIcon,
                      label: _hudLabel,
                      value: value,
                    ),
            ),
            if (_toolbarVisible) _buildTopBar(theme),
            if (_toolbarVisible) _buildBottomBar(settings),
          ],
        ),
      ),
    );
  }

  Widget _buildGestureLayer(ReaderSettings settings) {
    final size = MediaQuery.of(context).size;

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTapUp: (details) {
        if (_toolbarVisible) {
          setState(() => _toolbarVisible = false);
          return;
        }
        final dx = details.globalPosition.dx;
        if (dx < size.width * 0.28) {
          _goToPage(_index - 1);
        } else if (dx > size.width * 0.72) {
          _goToPage(_index + 1);
        } else {
          setState(() => _toolbarVisible = true);
        }
      },
      onVerticalDragStart: (d) => _dragStart = d.globalPosition,
      onVerticalDragEnd: (_) => _dragStart = null,
      onVerticalDragCancel: () => _dragStart = null,
      onVerticalDragUpdate: (d) {
        final start = _dragStart;
        if (start == null) return;
        _handleVerticalDrag(start, d.primaryDelta ?? 0, size);
      },
      child: PageView.builder(
        controller: _pageController,
        physics: settings.pageTurnStyle == PageTurnStyle.none
            ? const NeverScrollableScrollPhysics()
            : const PageScrollPhysics(),
        itemCount: _pageCount,
        onPageChanged: (i) {
          _flushSession();
          setState(() {
            _index = i;
            _scrollOffset = 0;
          });
          _persistProgress();
        },
        itemBuilder: (context, i) {
          final page = i >= _chapters.length
              ? _FinishPage(
                  key: const ValueKey('finish'),
                  book: _book!,
                  theme: settings.theme,
                  chapters: _chapters,
                  onAddTag: _addTagFromFinish,
                  onRestart: () => _goToPage(0, animate: false),
                  onExit: () => Navigator.of(context).maybePop(),
                )
              : _ChapterView(
                  key: ValueKey('chapter-$i'),
                  chapterIndex: i,
                  chapters: _chapters,
                  doc: _doc!,
                  settings: settings,
                  bookId: _book!.id,
                  macroContext: _macroContext,
                  jumpOffset: _pendingJumpOffset,
                  onScroll: (offset) => _scrollOffset = offset,
                  onHighlight: (text, start, end) =>
                      _pickHighlightColor(text, start, end),
                  onNote: _addNote,
                );

          return PageTurn(
            controller: _pageController,
            index: i,
            style: settings.pageTurnStyle,
            child: page,
          );
        },
      ),
    );
  }

  _MacroContext get _macroContext => _MacroContext(
        bookTitle: _book?.title ?? '',
        chapterCount: _chapters.length,
        bookProgress: _overallProgress,
        now: _now,
        batteryLevel: _battery?.level,
        charging: _battery?.charging ?? false,
      );

  Widget _buildTopBar(ReaderTheme theme) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: ReaderTopBar(
        theme: theme,
        bookTitle: _book?.title ?? '',
        chapterTitle: _onFinishPage ? '已读完' : _chapters[_index].title,
        progressLabel: '${(_overallProgress * 100).toStringAsFixed(1)}%',
        speaking: _speaking,
        onBack: () => Navigator.of(context).maybePop(),
        onCatalog: _showCatalog,
        onNotes: _showNotes,
        onSearch: _showSearch,
        onTts: _toggleTts,
        onMore: _showMore,
      ),
    );
  }

  Widget _buildBottomBar(ReaderSettings settings) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: ReaderBottomBar(
        theme: settings.theme,
        chapterIndex: _index.clamp(0, _chapters.length),
        chapterCount: _chapters.length,
        chapterTitle: _onFinishPage ? '已读完' : _chapters[_index].title,
        bookProgress: _overallProgress,
        autoPageSeconds: settings.autoPageSeconds,
        speaking: _speaking,
        onSeek: (v) => _goToPage(v, animate: false),
        onPrev: () => _goToPage(_index - 1),
        onNext: () => _goToPage(_index + 1),
        onCatalog: _showCatalog,
        onTypography: () => _showSettings(settings),
        onTheme: _showThemePicker,
        onBrightness: _showBrightnessSheet,
        onPageTurn: _showPageTurnSheet,
        onAutoPage: () => _showAutoPageSheet(settings),
        onTts: _toggleTts,
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Sheets
  // -------------------------------------------------------------------------

  void _showSettings(ReaderSettings settings) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => ReaderSettingsSheet(
        settings: settings,
        onChanged: (mutate) =>
            ref.read(settingsControllerProvider).updateReader(mutate),
        onAutoPageChanged: _toggleAutoPage,
      ),
    );
  }

  void _showThemePicker() {
    final controller = ref.read(settingsControllerProvider);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('阅读主题',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: ReaderTheme.values.map((t) {
                    final selected = controller.reader.theme == t;
                    return GestureDetector(
                      onTap: () {
                        controller.updateReader((s) => s.theme = t);
                        setSheetState(() {});
                      },
                      child: Container(
                        width: 68,
                        height: 80,
                        decoration: BoxDecoration(
                          color: t.background,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: selected
                                ? Theme.of(context).colorScheme.primary
                                : Colors.black12,
                            width: selected ? 2 : 1,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('文',
                                style: TextStyle(
                                    color: t.foreground, fontSize: 20)),
                            const SizedBox(height: 4),
                            Text(t.label,
                                style: TextStyle(
                                    color: t.foreground, fontSize: 10)),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 26),
                const Text('版框',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  children: PageBorderStyle.values.map((b) {
                    return ChoiceChip(
                      label: Text(b.label),
                      selected: controller.reader.pageBorder == b,
                      onSelected: (_) {
                        controller.updateReader((s) => s.pageBorder = b);
                        setSheetState(() {});
                      },
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showBrightnessSheet() {
    final native = ref.read(nativeServiceProvider);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => StatefulBuilder(
        builder: (context, setSheetState) {
          final value = _brightnessOverride ?? 0.5;
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.brightness_6_outlined, size: 18),
                      const SizedBox(width: 8),
                      const Text('阅读亮度',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                      const Spacer(),
                      TextButton(
                        onPressed: () {
                          setSheetState(() => _brightnessOverride = null);
                          native.resetBrightness();
                        },
                        child: const Text('跟随系统'),
                      ),
                    ],
                  ),
                  Slider(
                    value: value.clamp(0.02, 1.0),
                    min: 0.02,
                    max: 1.0,
                    onChanged: (v) {
                      setSheetState(() => _brightnessOverride = v);
                      native.setBrightness(v);
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showPageTurnSheet() {
    final controller = ref.read(settingsControllerProvider);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text('翻页动画',
                  style: TextStyle(fontWeight: FontWeight.w600)),
            ),
            for (final style in PageTurnStyle.values)
              RadioListTile<PageTurnStyle>(
                value: style,
                groupValue: controller.reader.pageTurnStyle,
                title: Text(style.label),
                onChanged: (v) {
                  if (v == null) return;
                  controller.updateReader((s) => s.pageTurnStyle = v);
                  Navigator.pop(context);
                },
              ),
          ],
        ),
      ),
    );
  }

  void _showAutoPageSheet(ReaderSettings settings) {
    const options = [0, 5, 10, 20, 30, 60];
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text('自动翻页间隔',
                  style: TextStyle(fontWeight: FontWeight.w600)),
            ),
            for (final seconds in options)
              RadioListTile<int>(
                value: seconds,
                groupValue: settings.autoPageSeconds,
                title: Text(seconds == 0 ? '关闭' : '每 $seconds 秒'),
                onChanged: (v) {
                  if (v == null) return;
                  ref
                      .read(settingsControllerProvider)
                      .updateReader((s) => s.autoPageSeconds = v);
                  _toggleAutoPage(v);
                  Navigator.pop(context);
                },
              ),
          ],
        ),
      ),
    );
  }

  void _showCatalog({int initialTab = 0}) {
    final theme = ref.read(settingsControllerProvider).reader.theme;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.background,
      builder: (_) => CatalogSheet(
        theme: theme,
        chapters: _chapters,
        currentIndex: _index,
        initialTab: initialTab,
        search: (query) => _doc?.search(query) ?? Future.value(const []),
        history: _searchHistory,
        onHistoryChanged: (history) async {
          _searchHistory = history;
          await ref
              .read(settingsRepositoryProvider)
              .saveSearchHistory(history);
        },
        onJump: (chapterIndex, offset) {
          Navigator.pop(context);
          _goToPage(chapterIndex, animate: false, offset: offset);
        },
      ),
    );
  }

  void _showSearch() => _showCatalog(initialTab: 1);

  void _showNotes() {
    final theme = ref.read(settingsControllerProvider).reader.theme;
    final notes = ref.read(notesControllerProvider).forBook(widget.bookId);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: theme.background,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.92,
        builder: (context, scrollController) {
          if (notes.isEmpty) {
            return Center(
              child: Text(
                '还没有笔记\n长按选中文字即可高亮或写笔记',
                textAlign: TextAlign.center,
                style: TextStyle(color: theme.muted, height: 1.6),
              ),
            );
          }
          return ListView.builder(
            controller: scrollController,
            itemCount: notes.length,
            itemBuilder: (context, i) {
              final note = notes[i];
              return ListTile(
                leading: Icon(
                  switch (note.type) {
                    NoteType.highlight => Icons.brush_outlined,
                    NoteType.bookmark => Icons.bookmark_border,
                    NoteType.thought => Icons.edit_note,
                  },
                  color: note.type == NoteType.highlight
                      ? Color(note.color)
                      : theme.foreground,
                ),
                title: Text(
                  note.text.isEmpty ? note.note : note.text,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: theme.foreground, fontSize: 14),
                ),
                subtitle: Text(
                  '${_chapterTitle(note.chapterIndex)}'
                  '${note.note.isEmpty ? '' : ' · ${note.note}'}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: theme.muted, fontSize: 12),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _goToPage(note.chapterIndex, animate: false);
                },
              );
            },
          );
        },
      ),
    );
  }

  void _showMore() {
    final theme = ref.read(settingsControllerProvider).reader.theme;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: theme.background,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.bookmark_add_outlined, color: theme.foreground),
              title: Text('添加书签', style: TextStyle(color: theme.foreground)),
              onTap: () {
                Navigator.pop(context);
                _addBookmark();
              },
            ),
            ListTile(
              leading: Icon(Icons.info_outline, color: theme.foreground),
              title: Text('书籍信息', style: TextStyle(color: theme.foreground)),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      '${_book?.title}\n${_chapters.length} 章 · '
                      '${_book?.format.label} · ${_book?.encoding.toUpperCase()}',
                    ),
                  ),
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.settings_outlined, color: theme.foreground),
              title: Text('排版设置', style: TextStyle(color: theme.foreground)),
              onTap: () {
                Navigator.pop(context);
                _showSettings(ref.read(settingsControllerProvider).reader);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addTagFromFinish(String tag) async {
    final book = _book;
    if (book == null) return;
    final current = ref.read(bookRepositoryProvider).byId(book.id);
    if (current == null) return;
    final tags = {...current.tags, tag}.toList();
    await ref.read(booksControllerProvider).setTags(current, tags);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已添加标签「$tag」')),
    );
  }

  String _chapterTitle(int index) =>
      index >= 0 && index < _chapters.length ? _chapters[index].title : '未知章节';
}

/// Data needed to expand header and footer macros.
class _MacroContext {
  const _MacroContext({
    required this.bookTitle,
    required this.chapterCount,
    required this.bookProgress,
    required this.now,
    required this.batteryLevel,
    required this.charging,
  });

  final String bookTitle;
  final int chapterCount;
  final double bookProgress;
  final DateTime now;
  final int? batteryLevel;
  final bool charging;
}

/// Renders one chapter with header/footer, drop cap, page frame and inline
/// highlight spans.
class _ChapterView extends ConsumerStatefulWidget {
  const _ChapterView({
    super.key,
    required this.chapterIndex,
    required this.chapters,
    required this.doc,
    required this.settings,
    required this.bookId,
    required this.macroContext,
    required this.jumpOffset,
    required this.onScroll,
    required this.onHighlight,
    required this.onNote,
  });

  final int chapterIndex;
  final List<ChapterMeta> chapters;
  final ReaderDocument doc;
  final ReaderSettings settings;
  final String bookId;
  final _MacroContext macroContext;
  final int jumpOffset;
  final ValueChanged<double> onScroll;
  final Future<void> Function(String text, int start, int end) onHighlight;
  final Future<void> Function(String text, int start, int end) onNote;

  @override
  ConsumerState<_ChapterView> createState() => _ChapterViewState();
}

class _ChapterViewState extends ConsumerState<_ChapterView> {
  final _scrollController = ScrollController();
  String? _text;
  double _chapterProgress = 0;
  int _reportedPercent = -1;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      final max = _scrollController.position.maxScrollExtent;
      final progress = max <= 0 ? 0.0 : _scrollController.offset / max;
      _chapterProgress = progress.clamp(0.0, 1.0);
      widget.onScroll(_chapterProgress);

      // The header/footer show the chapter percentage, so only rebuild when the
      // rounded value actually changes instead of on every scroll frame.
      final percent = (_chapterProgress * 100).round();
      if (percent != _reportedPercent) {
        _reportedPercent = percent;
        setState(() {});
      }
    });
    _load();
  }

  Future<void> _load() async {
    final text = await widget.doc.chapterText(widget.chapterIndex);
    if (!mounted) return;
    setState(() => _text = text);

    if (widget.jumpOffset > 0 && text.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_scrollController.hasClients) return;
        final max = _scrollController.position.maxScrollExtent;
        final ratio = (widget.jumpOffset / text.length).clamp(0.0, 1.0);
        _scrollController.jumpTo(max * ratio);
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = widget.settings;
    final theme = settings.theme;
    final text = _text;

    if (text == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final notes = ref
        .watch(notesControllerProvider)
        .forBook(widget.bookId)
        .where((n) =>
            n.chapterIndex == widget.chapterIndex && n.type == NoteType.highlight)
        .map((n) => (start: n.start, end: n.end, color: n.color))
        .toList();

    final runs = buildTextRuns(
      rawText: text,
      transform: DisplayTransform(
        indent: settings.paragraphIndent,
        paragraphGap: (settings.paragraphSpacing * 2).round(),
      ),
      highlights: notes,
      dropCap: settings.dropCap,
    );

    final chapterTitle = widget.chapters[widget.chapterIndex].title;

    return Container(
      decoration: _borderDecoration(settings, theme),
      child: SingleChildScrollView(
        controller: _scrollController,
        padding: EdgeInsets.symmetric(
          horizontal: settings.pageMargin + 6,
          vertical: 18,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (settings.showHeader)
              _TemplateLine(
                text: ReaderMacros.render(
                  settings.headerTemplate,
                  bookTitle: widget.macroContext.bookTitle,
                  chapterTitle: chapterTitle,
                  volumeTitle: '',
                  chapterProgress: _chapterProgress,
                  bookProgress: widget.macroContext.bookProgress,
                  chapterIndex: widget.chapterIndex,
                  chapterCount: widget.macroContext.chapterCount,
                  now: widget.macroContext.now,
                  batteryLevel: widget.macroContext.batteryLevel,
                  charging: widget.macroContext.charging,
                ),
                size: settings.headerFooterSize,
                color: theme.muted,
                align: TextAlign.center,
              ),
            Padding(
              padding: const EdgeInsets.only(top: 6, bottom: 14),
              child: Text(
                chapterTitle,
                style: TextStyle(
                  fontSize: settings.fontSize + 4,
                  fontWeight: FontWeight.w700,
                  color: theme.foreground,
                ),
              ),
            ),
            SelectableText.rich(
              TextSpan(
                children: [
                  for (final run in runs)
                    TextSpan(
                      text: run.text,
                      style: _styleFor(run, settings, theme),
                    ),
                ],
              ),
              style: TextStyle(
                fontSize: settings.fontSize,
                height: settings.lineHeight,
                letterSpacing: settings.letterSpacing,
                color: theme.foreground,
                fontFamily: _fontFamily(settings.fontFamily),
              ),
              textAlign: settings.textAlign.textAlign,
              contextMenuBuilder: (context, editableTextState) {
                final selection = editableTextState.textEditingValue.selection;
                final display = editableTextState.textEditingValue.text;
                final hasSelection = selection.isValid &&
                    !selection.isCollapsed &&
                    selection.end <= display.length;

                if (!hasSelection) {
                  return AdaptiveTextSelectionToolbar.buttonItems(
                    anchors: editableTextState.contextMenuAnchors,
                    buttonItems: editableTextState.contextMenuButtonItems,
                  );
                }

                // Selection offsets live in display space; convert back to the
                // raw source offsets used by notes and bookmarks.
                final transform = DisplayTransform(
                  indent: settings.paragraphIndent,
                  paragraphGap: (settings.paragraphSpacing * 2).round(),
                );
                final rawStart = transform.toRaw(text, selection.start);
                final rawEnd = transform.toRaw(text, selection.end);

                return AdaptiveTextSelectionToolbar.buttonItems(
                  anchors: editableTextState.contextMenuAnchors,
                  buttonItems: [
                    ContextMenuButtonItem(
                      label: '划线',
                      onPressed: () {
                        ContextMenuController.removeAny();
                        widget.onHighlight(text, rawStart, rawEnd);
                      },
                    ),
                    ContextMenuButtonItem(
                      label: '笔记',
                      onPressed: () {
                        ContextMenuController.removeAny();
                        widget.onNote(text, rawStart, rawEnd);
                      },
                    ),
                    ...editableTextState.contextMenuButtonItems,
                  ],
                );
              },
            ),
            const SizedBox(height: 36),
            if (settings.showFooter)
              _TemplateLine(
                text: ReaderMacros.render(
                  settings.footerTemplate,
                  bookTitle: widget.macroContext.bookTitle,
                  chapterTitle: chapterTitle,
                  volumeTitle: '',
                  chapterProgress: _chapterProgress,
                  bookProgress: widget.macroContext.bookProgress,
                  chapterIndex: widget.chapterIndex,
                  chapterCount: widget.macroContext.chapterCount,
                  now: widget.macroContext.now,
                  batteryLevel: widget.macroContext.batteryLevel,
                  charging: widget.macroContext.charging,
                ),
                size: settings.headerFooterSize,
                color: theme.muted,
                align: TextAlign.center,
              ),
          ],
        ),
      ),
    );
  }

  BoxDecoration _borderDecoration(ReaderSettings settings, ReaderTheme theme) {
    if (settings.pageBorder == PageBorderStyle.none) {
      return const BoxDecoration();
    }
    final color = theme.foreground.withOpacity(0.22);
    if (settings.pageBorder == PageBorderStyle.doubleLine) {
      return BoxDecoration(
        border: Border.fromBorderSide(BorderSide(color: color, width: 1)),
        gradient: null,
      );
    }
    return BoxDecoration(
      border: Border.fromBorderSide(BorderSide(color: color, width: 0.8)),
    );
  }

  TextStyle _styleFor(
    TextRun run,
    ReaderSettings settings,
    ReaderTheme theme,
  ) {
    var style = TextStyle(
      fontSize: settings.fontSize,
      height: settings.lineHeight,
      letterSpacing: settings.letterSpacing,
      color: theme.foreground,
      fontFamily: _fontFamily(settings.fontFamily),
    );
    if (run.highlight != null) {
      style = style.copyWith(
        backgroundColor: Color(run.highlight!).withOpacity(0.45),
      );
    }
    if (run.dropCap) {
      style = style.copyWith(
        fontSize: settings.fontSize * 2.3,
        fontWeight: FontWeight.w700,
        height: 1.05,
      );
    }
    return style;
  }

  String? _fontFamily(String family) =>
      family == '系统默认' ? null : family;
}

class _TemplateLine extends StatelessWidget {
  const _TemplateLine({
    required this.text,
    required this.size,
    required this.color,
    required this.align,
  });

  final String text;
  final double size;
  final Color color;
  final TextAlign align;

  @override
  Widget build(BuildContext context) {
    if (text.trim().isEmpty) return const SizedBox.shrink();
    return Text(
      text,
      textAlign: align,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(fontSize: size, color: color),
    );
  }
}

/// Shown after the last chapter.
class _FinishPage extends StatelessWidget {
  const _FinishPage({
    super.key,
    required this.book,
    required this.theme,
    required this.chapters,
    required this.onAddTag,
    required this.onRestart,
    required this.onExit,
  });

  final Book book;
  final ReaderTheme theme;
  final List<ChapterMeta> chapters;
  final Future<void> Function(String tag) onAddTag;
  final VoidCallback onRestart;
  final VoidCallback onExit;

  static const _suggestedTags = ['已读完', '好书', '推荐', '想重读'];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 48),
      child: Column(
        children: [
          Icon(Icons.check_circle_outline, size: 64, color: theme.foreground),
          const SizedBox(height: 20),
          Text(
            '已读完',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: theme.foreground,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            book.title,
            textAlign: TextAlign.center,
            style: TextStyle(color: theme.muted, fontSize: 14),
          ),
          const SizedBox(height: 6),
          Text(
            '共 ${chapters.length} 章 · ${book.displayAuthor}',
            style: TextStyle(color: theme.muted, fontSize: 12),
          ),
          const SizedBox(height: 32),
          Text(
            '给这本书加个标签',
            style: TextStyle(color: theme.muted, fontSize: 13),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            children: _suggestedTags
                .map(
                  (tag) => ActionChip(
                    label: Text(tag),
                    onPressed: () => onAddTag(tag),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 40),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: onRestart,
                icon: const Icon(Icons.replay, size: 18),
                label: const Text('回到开头'),
              ),
              const SizedBox(width: 14),
              FilledButton.icon(
                onPressed: onExit,
                icon: const Icon(Icons.bookmark_outline, size: 18),
                label: const Text('返回书架'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
