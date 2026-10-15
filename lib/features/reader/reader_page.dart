import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/book.dart';
import '../../data/models/chapter.dart';
import '../../data/models/note.dart';
import '../../data/repositories/settings_repository.dart';
import '../../services/tts_service.dart';
import '../../state/providers.dart';
import 'engines/document.dart';
import 'engines/epub_engine.dart';
import 'engines/txt_engine.dart';
import 'widgets/reader_settings_sheet.dart';

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

  bool _toolbarVisible = false;
  bool _loading = true;
  String? _error;

  Timer? _autoTimer;
  Timer? _sessionTimer;

  DateTime _sessionStart = DateTime.now();
  int _sessionSeconds = 0;
  int _sessionChars = 0;
  int _lastCharMark = 0;

  TtsService? _tts;
  bool _speaking = false;

  @override
  void initState() {
    super.initState();
    _open();
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

      ReaderDocument doc;
      switch (book.format) {
        case BookFormat.txt:
          doc = await TxtDocument.open(book.filePath, rule: book.chapterRule);
        case BookFormat.epub:
          doc = await EpubDocument.open(book.filePath);
        default:
          throw BookParseException(
            '${book.format.label} 阅读引擎将在后续版本开放，当前支持 TXT / EPUB。',
          );
      }

      var chapters = doc.chapters;
      final stored = repo.chaptersOf(book.id);
      if (stored != null && stored.chapters.length == chapters.length) {
        chapters = stored.chapters;
      } else {
        await repo.saveChapters(ChapterList(bookId: book.id, chapters: chapters));
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

  // -------------------------------------------------------------------------
  // Session / progress accounting
  // -------------------------------------------------------------------------

  void _startSession() {
    _sessionStart = DateTime.now();
    _sessionTimer?.cancel();
    _sessionTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _sessionSeconds++;
    });
  }

  int _charMarkAt(int chapterIndex, int offset) {
    final doc = _doc;
    if (doc is TxtDocument && chapterIndex < _chapters.length) {
      return _chapters[chapterIndex].start + offset;
    }
    return chapterIndex * 3000 + offset;
  }

  double get _overallProgress {
    if (_chapters.isEmpty) return 0;
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
          chapterIndex: _index,
          offset: _scrollOffset.round(),
          progress: _overallProgress,
        );
  }

  Future<void> _flushSession() async {
    final book = _book;
    if (book == null) return;
    final seconds = _sessionSeconds;
    final mark = _charMarkAt(_index, _scrollOffset.round());
    final chars = (mark - _lastCharMark).clamp(0, 1 << 30);
    _sessionSeconds = 0;
    _lastCharMark = mark;
    _sessionStart = DateTime.now();
    if (seconds < 5 && chars == 0) return;
    await ref.read(statsControllerProvider).log(
          bookId: book.id,
          seconds: seconds,
          chars: chars,
          startedAt: _sessionStart,
        );
  }

  // -------------------------------------------------------------------------
  // Lifecycle
  // -------------------------------------------------------------------------

  @override
  void dispose() {
    _autoTimer?.cancel();
    _sessionTimer?.cancel();
    _flushSession();
    _persistProgress();
    _doc?.dispose();
    _tts?.stop();
    _pageController.dispose();
    super.dispose();
  }

  // -------------------------------------------------------------------------
  // Navigation
  // -------------------------------------------------------------------------

  void _goToChapter(int index, {bool animate = true}) {
    if (_chapters.isEmpty) return;
    final target = index.clamp(0, _chapters.length - 1);
    if (animate && _pageController.hasClients) {
      _pageController.animateToPage(
        target,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
    } else {
      setState(() => _index = target);
    }
  }

  void _toggleAutoPage(int seconds) {
    _autoTimer?.cancel();
    if (seconds <= 0) return;
    _autoTimer = Timer.periodic(Duration(seconds: seconds), (_) {
      if (_index + 1 < _chapters.length) {
        _goToChapter(_index + 1);
      } else {
        _autoTimer?.cancel();
      }
    });
  }

  // -------------------------------------------------------------------------
  // TTS
  // -------------------------------------------------------------------------

  Future<void> _toggleTts() async {
    final settings = ref.read(settingsControllerProvider).app;
    final tts = _tts ??= ref.read(ttsServiceProvider);
    if (_speaking) {
      await tts.stop();
      if (mounted) setState(() => _speaking = false);
      return;
    }
    await tts.configure(
      rate: settings.ttsRate,
      pitch: settings.ttsPitch,
      language: settings.ttsLanguage,
    );
    tts.onCompleted = () {
      if (!mounted) return;
      if (settings.autoTtsNextChapter && _index + 1 < _chapters.length) {
        _goToChapter(_index + 1);
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
    if (doc == null) return;
    final text = await doc.chapterText(_index);
    if (text.trim().isEmpty) return;
    await _tts?.speak(text);
  }

  // -------------------------------------------------------------------------
  // Notes
  // -------------------------------------------------------------------------

  Future<void> _addHighlight(String text, int start, int end) async {
    final book = _book;
    if (book == null || text.trim().isEmpty) return;
    await ref.read(notesControllerProvider).addHighlight(
          bookId: book.id,
          chapterIndex: _index,
          start: start,
          end: end,
          text: text,
        );
    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已添加高亮'), duration: Duration(seconds: 1)),
    );
  }

  Future<void> _addNote(String text, int start, int end) async {
    final book = _book;
    if (book == null) return;
    final controller = TextEditingController();
    final saved = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('添加笔记'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (text.trim().isNotEmpty)
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Theme.of(c).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  text,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              maxLines: 4,
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
    if (saved == null) return;
    await ref.read(notesControllerProvider).save(
          BookNote(
            id: '${book.id}-${_index}-${DateTime.now().microsecondsSinceEpoch}',
            bookId: book.id,
            type: NoteType.thought,
            chapterIndex: _index,
            start: start,
            end: end,
            text: text,
            note: saved,
          ),
        );
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _addBookmark() async {
    final book = _book;
    if (book == null) return;
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
          child: Center(
            child: Text(_error!, textAlign: TextAlign.center),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: theme.background,
      body: SafeArea(
        child: Stack(
          children: [
            _buildPager(settings),
            if (_toolbarVisible) _buildTopBar(),
            if (_toolbarVisible) _buildBottomBar(settings),
          ],
        ),
      ),
    );
  }

  Widget _buildPager(ReaderSettings settings) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTapUp: (details) {
        final width = MediaQuery.of(context).size.width;
        final dx = details.globalPosition.dx;
        if (dx < width * 0.25) {
          _goToChapter(_index - 1);
        } else if (dx > width * 0.75) {
          _goToChapter(_index + 1);
        } else {
          setState(() => _toolbarVisible = !_toolbarVisible);
        }
      },
      child: PageView.builder(
        controller: _pageController,
        itemCount: _chapters.length,
        onPageChanged: (i) {
          _flushSession();
          setState(() {
            _index = i;
            _scrollOffset = 0;
          });
          _persistProgress();
        },
        itemBuilder: (context, i) => _ChapterView(
          key: ValueKey('chapter-$i-${settings.fontSize}'),
          chapterIndex: i,
          chapters: _chapters,
          doc: _doc!,
          settings: settings,
          bookId: _book!.id,
          onScroll: (offset) => _scrollOffset = offset,
          onHighlight: _addHighlight,
          onNote: _addNote,
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    final theme = ref.watch(settingsControllerProvider).reader.theme;
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Material(
        color: theme.background.withOpacity(0.96),
        child: SafeArea(
          bottom: false,
          child: Row(
            children: [
              IconButton(
                icon: Icon(Icons.arrow_back, color: theme.foreground),
                onPressed: () => Navigator.of(context).maybePop(),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _book?.title ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: theme.foreground,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      _chapters.isEmpty ? '' : _chapters[_index].title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: theme.foreground.withOpacity(0.6),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: '目录',
                icon: Icon(Icons.list, color: theme.foreground),
                onPressed: _showChapterList,
              ),
              IconButton(
                tooltip: '笔记',
                icon: Icon(Icons.sticky_note_2_outlined, color: theme.foreground),
                onPressed: _showChapterNotes,
              ),
              IconButton(
                tooltip: _speaking ? '停止朗读' : '朗读',
                icon: Icon(
                  _speaking ? Icons.stop_circle_outlined : Icons.headphones,
                  color: theme.foreground,
                ),
                onPressed: _toggleTts,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBar(ReaderSettings settings) {
    final theme = settings.theme;
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Material(
        color: theme.background.withOpacity(0.96),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: '上一章',
                      icon: Icon(Icons.chevron_left, color: theme.foreground),
                      onPressed: () => _goToChapter(_index - 1),
                    ),
                    Expanded(
                      child: Slider(
                        value: _chapters.isEmpty
                            ? 0
                            : _index.toDouble().clamp(
                                0,
                                (_chapters.length - 1).toDouble(),
                              ),
                        max: _chapters.isEmpty
                            ? 1
                            : (_chapters.length - 1).clamp(1, 1 << 30).toDouble(),
                        divisions: _chapters.length > 1
                            ? _chapters.length - 1
                            : null,
                        label: _chapters.isEmpty ? '' : _chapters[_index].title,
                        onChanged: (v) => _goToChapter(v.round(), animate: false),
                      ),
                    ),
                    IconButton(
                      tooltip: '下一章',
                      icon: Icon(Icons.chevron_right, color: theme.foreground),
                      onPressed: () => _goToChapter(_index + 1),
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _barAction(Icons.bookmark_add_outlined, '书签', _addBookmark, theme),
                  _barAction(Icons.format_size, '排版', () => _showSettings(settings), theme),
                  _barAction(
                    Icons.timelapse,
                    '自动翻页',
                    () => _showAutoPageSheet(settings),
                    theme,
                  ),
                  _barAction(
                    Icons.list_alt,
                    '进度',
                    _showChapterList,
                    theme,
                  ),
                ],
              ),
              const SizedBox(height: 6),
            ],
          ),
        ),
      ),
    );
  }

  Widget _barAction(
    IconData icon,
    String label,
    VoidCallback onTap,
    ReaderTheme theme,
  ) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: theme.foreground, size: 22),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(color: theme.foreground, fontSize: 11),
              ),
            ],
          ),
        ),
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
              child: Text('自动翻页间隔', style: TextStyle(fontWeight: FontWeight.w600)),
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

  void _showChapterList() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        builder: (context, scrollController) => ListView.builder(
          controller: scrollController,
          itemCount: _chapters.length,
          itemBuilder: (context, i) {
            final c = _chapters[i];
            final selected = i == _index;
            return ListTile(
              dense: true,
              selected: selected,
              title: Text(
                c.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                _goToChapter(i, animate: false);
              },
            );
          },
        ),
      ),
    );
  }

  void _showChapterNotes() {
    final notes = ref.read(notesControllerProvider).forBook(widget.bookId);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        builder: (context, scrollController) {
          if (notes.isEmpty) {
            return const Center(child: Text('还没有笔记，长按选中文字即可高亮或写笔记'));
          }
          return ListView.builder(
            controller: scrollController,
            itemCount: notes.length,
            itemBuilder: (context, i) {
              final note = notes[i];
              return ListTile(
                leading: Icon(switch (note.type) {
                  NoteType.highlight => Icons.brush_outlined,
                  NoteType.bookmark => Icons.bookmark_border,
                  NoteType.thought => Icons.edit_note,
                }),
                title: Text(
                  note.text.isEmpty ? note.note : note.text,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  '${_chapterTitle(note.chapterIndex)}'
                  '${note.note.isEmpty ? '' : ' · ${note.note}'}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () {
                  Navigator.pop(context);
                  _goToChapter(note.chapterIndex, animate: false);
                },
              );
            },
          );
        },
      ),
    );
  }

  String _chapterTitle(int index) =>
      index >= 0 && index < _chapters.length ? _chapters[index].title : '未知章节';
}

/// Renders one chapter with inline highlight spans and a custom selection menu.
class _ChapterView extends ConsumerStatefulWidget {
  const _ChapterView({
    super.key,
    required this.chapterIndex,
    required this.chapters,
    required this.doc,
    required this.settings,
    required this.bookId,
    required this.onScroll,
    required this.onHighlight,
    required this.onNote,
  });

  final int chapterIndex;
  final List<ChapterMeta> chapters;
  final ReaderDocument doc;
  final ReaderSettings settings;
  final String bookId;
  final ValueChanged<double> onScroll;
  final Future<void> Function(String text, int start, int end) onHighlight;
  final Future<void> Function(String text, int start, int end) onNote;

  @override
  ConsumerState<_ChapterView> createState() => _ChapterViewState();
}

class _ChapterViewState extends ConsumerState<_ChapterView> {
  final _scrollController = ScrollController();
  String? _text;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      final max = _scrollController.position.maxScrollExtent;
      widget.onScroll(max <= 0 ? 0 : _scrollController.offset / max);
    });
    _load();
  }

  Future<void> _load() async {
    final text = await widget.doc.chapterText(widget.chapterIndex);
    if (!mounted) return;
    setState(() => _text = text);
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
    final baseStyle = TextStyle(
      fontSize: settings.fontSize,
      height: settings.lineHeight,
      letterSpacing: settings.letterSpacing,
      color: theme.foreground,
    );

    if (_text == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final notes = ref
        .watch(notesControllerProvider)
        .forBook(widget.bookId)
        .where((n) => n.chapterIndex == widget.chapterIndex && n.type == NoteType.highlight)
        .toList();

    return SingleChildScrollView(
      controller: _scrollController,
      padding: EdgeInsets.symmetric(
        horizontal: settings.pageMargin,
        vertical: 24,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (settings.showHeader)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                widget.chapters[widget.chapterIndex].title,
                style: TextStyle(
                  fontSize: settings.fontSize + 4,
                  fontWeight: FontWeight.w700,
                  color: theme.foreground,
                ),
              ),
            ),
          SelectableText.rich(
            TextSpan(
              children: _buildSpans(_text!, notes, baseStyle, theme),
            ),
            style: baseStyle,
            textAlign: TextAlign.justify,
            contextMenuBuilder: (context, editableTextState) {
              final selection = editableTextState.textEditingValue.selection;
              final full = editableTextState.textEditingValue.text;
              final hasSelection =
                  selection.isValid && !selection.isCollapsed && selection.end <= full.length;
              return AdaptiveTextSelectionToolbar.buttonItems(
                anchors: editableTextState.contextMenuAnchors,
                buttonItems: [
                  if (hasSelection)
                    ContextMenuButtonItem(
                      label: '高亮',
                      onPressed: () {
                        ContextMenuController.removeAny();
                        widget.onHighlight(
                          full.substring(selection.start, selection.end),
                          selection.start,
                          selection.end,
                        );
                      },
                    ),
                  if (hasSelection)
                    ContextMenuButtonItem(
                      label: '笔记',
                      onPressed: () {
                        ContextMenuController.removeAny();
                        widget.onNote(
                          full.substring(selection.start, selection.end),
                          selection.start,
                          selection.end,
                        );
                      },
                    ),
                  ...editableTextState.contextMenuButtonItems,
                ],
              );
            },
          ),
          const SizedBox(height: 40),
          if (settings.showFooter)
            Center(
              child: Text(
                '第 ${widget.chapterIndex + 1} / ${widget.chapters.length} 章',
                style: TextStyle(
                  fontSize: 12,
                  color: theme.foreground.withOpacity(0.5),
                ),
              ),
            ),
        ],
      ),
    );
  }

  List<TextSpan> _buildSpans(
    String text,
    List<BookNote> highlights,
    TextStyle baseStyle,
    ReaderTheme theme,
  ) {
    if (highlights.isEmpty) {
      return [TextSpan(text: _applyIndent(text), style: baseStyle)];
    }

    final marks = highlights
        .where((n) => n.end > n.start && n.end <= text.length)
        .toList()
      ..sort((a, b) => a.start.compareTo(b.start));

    final spans = <TextSpan>[];
    var cursor = 0;
    for (final note in marks) {
      if (note.start < cursor) continue;
      if (note.start > cursor) {
        spans.add(TextSpan(
          text: _applyIndent(text.substring(cursor, note.start)),
          style: baseStyle,
        ));
      }
      spans.add(TextSpan(
        text: text.substring(note.start, note.end),
        style: baseStyle.copyWith(
          backgroundColor: Color(note.color).withOpacity(0.45),
        ),
      ));
      cursor = note.end;
    }
    if (cursor < text.length) {
      spans.add(TextSpan(
        text: _applyIndent(text.substring(cursor)),
        style: baseStyle,
      ));
    }
    return spans;
  }

  /// Adds a leading indent to every paragraph, matching Chinese typesetting.
  String _applyIndent(String text) {
    final indent = widget.settings.paragraphIndent;
    if (indent <= 0) return text;
    final pad = '\u3000' * indent;
    return text
        .split('\n')
        .map((line) => line.trim().isEmpty ? line : '$pad${line.trimLeft()}')
        .join('\n');
  }
}
