import 'package:flutter/material.dart';

import '../../../data/repositories/settings_repository.dart';

/// Top chrome of the reader: back, title, chapter and the primary actions.
class ReaderTopBar extends StatelessWidget {
  const ReaderTopBar({
    super.key,
    required this.theme,
    required this.bookTitle,
    required this.chapterTitle,
    required this.progressLabel,
    required this.speaking,
    required this.flat,
    required this.onBack,
    required this.onCatalog,
    required this.onNotes,
    required this.onSearch,
    required this.onTts,
    required this.onMore,
  });

  final ReaderTheme theme;
  final String bookTitle;
  final String chapterTitle;
  final String progressLabel;
  final bool speaking;

  /// E-ink mode drops the drop shadow from the chrome.
  final bool flat;
  final VoidCallback onBack;
  final VoidCallback onCatalog;
  final VoidCallback onNotes;
  final VoidCallback onSearch;
  final VoidCallback onTts;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: theme.background,
      elevation: flat ? 0 : 2,
      shadowColor: Colors.black26,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 56,
          child: Row(
            children: [
              IconButton(
                tooltip: '返回',
                icon: Icon(Icons.arrow_back, color: theme.foreground),
                onPressed: onBack,
              ),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      bookTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: theme.foreground,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      '$chapterTitle · $progressLabel',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: theme.muted, fontSize: 11),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: '搜索',
                icon: Icon(Icons.search, color: theme.foreground),
                onPressed: onSearch,
              ),
              IconButton(
                tooltip: '目录',
                icon: Icon(Icons.format_list_bulleted, color: theme.foreground),
                onPressed: onCatalog,
              ),
              IconButton(
                tooltip: '笔记',
                icon: Icon(Icons.sticky_note_2_outlined, color: theme.foreground),
                onPressed: onNotes,
              ),
              IconButton(
                tooltip: speaking ? '停止朗读' : '朗读',
                icon: Icon(
                  speaking ? Icons.stop_circle_outlined : Icons.headphones,
                  color: theme.foreground,
                ),
                onPressed: onTts,
              ),
              IconButton(
                tooltip: '更多',
                icon: Icon(Icons.more_vert, color: theme.foreground),
                onPressed: onMore,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bottom chrome: chapter slider plus the quick action grid.
class ReaderBottomBar extends StatelessWidget {
  const ReaderBottomBar({
    super.key,
    required this.theme,
    required this.chapterIndex,
    required this.chapterCount,
    required this.chapterTitle,
    required this.bookProgress,
    required this.autoPageSeconds,
    required this.speaking,
    required this.flat,
    required this.onSeek,
    required this.onPrev,
    required this.onNext,
    required this.onCatalog,
    required this.onTypography,
    required this.onTheme,
    required this.onBrightness,
    required this.onPageTurn,
    required this.onAutoPage,
    required this.onTts,
  });

  final ReaderTheme theme;
  final int chapterIndex;
  final int chapterCount;
  final String chapterTitle;
  final double bookProgress;
  final int autoPageSeconds;
  final bool speaking;
  final bool flat;
  final ValueChanged<int> onSeek;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onCatalog;
  final VoidCallback onTypography;
  final VoidCallback onTheme;
  final VoidCallback onBrightness;
  final VoidCallback onPageTurn;
  final VoidCallback onAutoPage;
  final VoidCallback onTts;

  @override
  Widget build(BuildContext context) {
    final max = chapterCount <= 1 ? 1.0 : (chapterCount - 1).toDouble();
    return Material(
      color: theme.background,
      elevation: flat ? 0 : 2,
      shadowColor: Colors.black26,
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
              child: Row(
                children: [
                  IconButton(
                    tooltip: '上一章',
                    icon: Icon(Icons.chevron_left, color: theme.foreground),
                    onPressed: onPrev,
                  ),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${(bookProgress * 100).toStringAsFixed(1)}% · '
                          '${chapterIndex + 1}/$chapterCount',
                          style: TextStyle(color: theme.muted, fontSize: 11),
                        ),
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: 2,
                            thumbShape:
                                const RoundSliderThumbShape(enabledThumbRadius: 6),
                            overlayShape:
                                const RoundSliderOverlayShape(overlayRadius: 14),
                            activeTrackColor: theme.foreground,
                            inactiveTrackColor: theme.foreground.withOpacity(0.2),
                            thumbColor: theme.foreground,
                          ),
                          child: Slider(
                            value: chapterIndex.toDouble().clamp(0.0, max),
                            max: max,
                            label: chapterTitle,
                            onChanged: (v) => onSeek(v.round()),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: '下一章',
                    icon: Icon(Icons.chevron_right, color: theme.foreground),
                    onPressed: onNext,
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 62,
              child: Row(
                children: [
                  _action(Icons.menu_book_outlined, '目录', onCatalog),
                  _action(Icons.text_fields, '排版', onTypography),
                  _action(Icons.palette_outlined, '背景', onTheme),
                  _action(Icons.brightness_6_outlined, '亮度', onBrightness),
                  _action(Icons.auto_stories_outlined, '翻页', onPageTurn),
                  _action(
                    Icons.timelapse,
                    autoPageSeconds > 0 ? '$autoPageSeconds 秒' : '自动翻页',
                    onAutoPage,
                  ),
                  _action(
                    speaking ? Icons.stop_circle_outlined : Icons.headphones,
                    speaking ? '停止' : '听书',
                    onTts,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _action(IconData icon, String label, VoidCallback onTap) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: theme.foreground, size: 21),
            const SizedBox(height: 5),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: theme.foreground, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }
}

/// Transient indicator shown while dragging the brightness or volume edges.
class ReaderHud extends StatelessWidget {
  const ReaderHud({
    super.key,
    required this.theme,
    required this.icon,
    required this.label,
    required this.value,
  });

  final ReaderTheme theme;
  final IconData icon;
  final String label;
  final double value;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 190,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          color: theme.isDark ? Colors.white24 : Colors.black87,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: value.clamp(0.0, 1.0),
                minHeight: 6,
                backgroundColor: Colors.white24,
                valueColor: const AlwaysStoppedAnimation(Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
