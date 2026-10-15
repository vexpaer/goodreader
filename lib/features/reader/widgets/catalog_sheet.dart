import 'package:flutter/material.dart';

import '../../../data/models/chapter.dart';
import '../../../data/repositories/settings_repository.dart';
import '../engines/document.dart';

/// Bottom sheet with the chapter list and in-book full-text search.
class CatalogSheet extends StatefulWidget {
  const CatalogSheet({
    super.key,
    required this.theme,
    required this.chapters,
    required this.currentIndex,
    this.initialTab = 0,
    required this.search,
    required this.history,
    required this.onHistoryChanged,
    required this.onJump,
  });

  final ReaderTheme theme;
  final List<ChapterMeta> chapters;
  final int currentIndex;
  final int initialTab;
  final Future<List<SearchHit>> Function(String query) search;
  final List<String> history;
  final Future<void> Function(List<String> history) onHistoryChanged;
  final void Function(int chapterIndex, int offset) onJump;

  @override
  State<CatalogSheet> createState() => _CatalogSheetState();
}

class _CatalogSheetState extends State<CatalogSheet>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(
    length: 2,
    vsync: this,
    initialIndex: widget.initialTab.clamp(0, 1),
  );
  final _chapterFilter = TextEditingController();
  final _searchController = TextEditingController();

  List<SearchHit> _hits = const [];
  bool _searching = false;
  String? _searchedFor;
  late List<String> _history = List.of(widget.history);

  @override
  void dispose() {
    _tabs.dispose();
    _chapterFilter.dispose();
    _searchController.dispose();
    super.dispose();
  }

  List<ChapterMeta> get _filteredChapters {
    final q = _chapterFilter.text.trim().toLowerCase();
    if (q.isEmpty) return widget.chapters;
    return widget.chapters
        .where((c) => c.title.toLowerCase().contains(q))
        .toList();
  }

  Future<void> _runSearch(String raw) async {
    final query = raw.trim();
    if (query.isEmpty) return;
    setState(() {
      _searching = true;
      _searchedFor = query;
      _hits = const [];
    });

    final hits = await widget.search(query);
    final next = [query, ..._history.where((h) => h != query)];
    _history = next.take(30).toList();
    await widget.onHistoryChanged(_history);

    if (!mounted) return;
    setState(() {
      _hits = hits;
      _searching = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.72,
      maxChildSize: 0.94,
      minChildSize: 0.4,
      builder: (context, scrollController) => Column(
        children: [
          const SizedBox(height: 6),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: theme.foreground.withOpacity(0.25),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          TabBar(
            controller: _tabs,
            labelColor: theme.foreground,
            unselectedLabelColor: theme.muted,
            indicatorColor: theme.foreground,
            tabs: const [Tab(text: '目录'), Tab(text: '搜索')],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                _buildCatalog(scrollController),
                _buildSearch(scrollController),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Catalog
  // -------------------------------------------------------------------------

  Widget _buildCatalog(ScrollController scrollController) {
    final theme = widget.theme;
    final chapters = _filteredChapters;
    final read = (widget.currentIndex + 1).clamp(0, widget.chapters.length);
    final ratio = widget.chapters.isEmpty ? 0.0 : read / widget.chapters.length;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '共 ${widget.chapters.length} 章 · 已读 $read 章',
                  style: TextStyle(color: theme.muted, fontSize: 12),
                ),
              ),
              SizedBox(
                width: 90,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: ratio,
                    minHeight: 5,
                    backgroundColor: theme.foreground.withOpacity(0.15),
                    valueColor: AlwaysStoppedAnimation(theme.foreground),
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            controller: _chapterFilter,
            style: TextStyle(color: theme.foreground, fontSize: 14),
            decoration: InputDecoration(
              isDense: true,
              hintText: '筛选章节名',
              hintStyle: TextStyle(color: theme.muted, fontSize: 13),
              prefixIcon: Icon(Icons.filter_alt_outlined,
                  size: 18, color: theme.muted),
              filled: true,
              fillColor: theme.foreground.withOpacity(0.06),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
            ),
            onChanged: (_) => setState(() {}),
          ),
        ),
        Expanded(
          child: ListView.builder(
            controller: scrollController,
            padding: const EdgeInsets.only(top: 8, bottom: 24),
            itemCount: chapters.length,
            itemBuilder: (context, i) {
              final chapter = chapters[i];
              final isCurrent = chapter.index == widget.currentIndex;
              final isRead = chapter.index < widget.currentIndex;
              return ListTile(
                dense: true,
                selected: isCurrent,
                selectedTileColor: theme.foreground.withOpacity(0.08),
                leading: SizedBox(
                  width: 30,
                  child: Text(
                    '${chapter.index + 1}',
                    style: TextStyle(
                      color: isCurrent ? theme.foreground : theme.muted,
                      fontSize: 12,
                    ),
                  ),
                ),
                title: Text(
                  chapter.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isCurrent ? theme.foreground : theme.muted,
                    fontWeight:
                        isCurrent ? FontWeight.w700 : FontWeight.normal,
                    fontSize: 14,
                  ),
                ),
                trailing: isRead
                    ? Icon(Icons.check, size: 15, color: theme.muted)
                    : null,
                onTap: () => widget.onJump(chapter.index, 0),
              );
            },
          ),
        ),
      ],
    );
  }

  // -------------------------------------------------------------------------
  // Search
  // -------------------------------------------------------------------------

  Widget _buildSearch(ScrollController scrollController) {
    final theme = widget.theme;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
          child: TextField(
            controller: _searchController,
            autofocus: false,
            style: TextStyle(color: theme.foreground, fontSize: 14),
            textInputAction: TextInputAction.search,
            onSubmitted: _runSearch,
            decoration: InputDecoration(
              isDense: true,
              hintText: '全书搜索',
              hintStyle: TextStyle(color: theme.muted, fontSize: 13),
              prefixIcon:
                  Icon(Icons.search, size: 18, color: theme.muted),
              suffixIcon: IconButton(
                icon: Icon(Icons.arrow_forward, size: 18, color: theme.muted),
                onPressed: () => _runSearch(_searchController.text),
              ),
              filled: true,
              fillColor: theme.foreground.withOpacity(0.06),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
            ),
          ),
        ),
        if (_history.isNotEmpty && _searchedFor == null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
            child: Row(
              children: [
                Text('搜索历史',
                    style: TextStyle(color: theme.muted, fontSize: 12)),
                const Spacer(),
                TextButton(
                  onPressed: () async {
                    setState(() => _history = []);
                    await widget.onHistoryChanged(const []);
                  },
                  child: const Text('清空', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ),
        if (_history.isNotEmpty && _searchedFor == null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              children: _history
                  .map(
                    (h) => InputChip(
                      label: Text(h, style: const TextStyle(fontSize: 12)),
                      onPressed: () {
                        _searchController.text = h;
                        _runSearch(h);
                      },
                      onDeleted: () async {
                        setState(() => _history =
                            _history.where((e) => e != h).toList());
                        await widget.onHistoryChanged(_history);
                      },
                    ),
                  )
                  .toList(),
            ),
          ),
        Expanded(child: _buildResults(scrollController)),
      ],
    );
  }

  Widget _buildResults(ScrollController scrollController) {
    final theme = widget.theme;

    if (_searching) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_searchedFor == null) {
      return Center(
        child: Text(
          '输入关键词搜索全书内容',
          style: TextStyle(color: theme.muted, fontSize: 13),
        ),
      );
    }
    if (_hits.isEmpty) {
      return Center(
        child: Text(
          '没有找到「$_searchedFor」',
          style: TextStyle(color: theme.muted, fontSize: 13),
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '找到 ${_hits.length} 处结果',
              style: TextStyle(color: theme.muted, fontSize: 12),
            ),
          ),
        ),
        Expanded(
          child: ListView.separated(
            controller: scrollController,
            itemCount: _hits.length,
            separatorBuilder: (_, __) =>
                Divider(height: 1, color: theme.foreground.withOpacity(0.08)),
            itemBuilder: (context, i) {
              final hit = _hits[i];
              return ListTile(
                dense: true,
                title: Text(
                  hit.snippet,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: theme.foreground, fontSize: 13),
                ),
                subtitle: Text(
                  hit.chapterTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: theme.muted, fontSize: 11),
                ),
                onTap: () => widget.onJump(hit.chapterIndex, hit.start),
              );
            },
          ),
        ),
      ],
    );
  }
}
