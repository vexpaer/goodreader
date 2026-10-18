import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/bottom_bar.dart';
import '../../state/providers.dart';
import '../bookshelf/bookshelf_page.dart';
import '../notes/notes_page.dart';
import '../settings/settings_page.dart';
import '../stats/stats_page.dart';
import 'widgets/app_bottom_bar.dart';

/// 主框架。底栏的项目、顺序、形态、高度都由设置决定。
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  BottomBarSlot _slot = BottomBarSlot.shelf;

  /// 可停留的页面，顺序固定。底栏的顺序是另一回事，这里不能跟着变，
  /// 否则用户调一次底栏顺序，`IndexedStack` 的下标就全错位了。
  static const _pageSlots = [
    BottomBarSlot.shelf,
    BottomBarSlot.notes,
    BottomBarSlot.stats,
    BottomBarSlot.settings,
  ];

  static const _pages = [
    BookshelfPage(),
    NotesPage(),
    StatsPage(),
    SettingsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(settingsControllerProvider).app.bottomBar;
    final current = _slot.isPage ? _slot : BottomBarSlot.shelf;
    final index = _pageSlots.indexOf(current);

    return Scaffold(
      body: IndexedStack(index: index, children: _pages),
      bottomNavigationBar: AppBottomBar(
        config: config,
        currentSlot: current,
        onTap: _onTap,
      ),
    );
  }

  void _onTap(BottomBarSlot slot) {
    if (slot.isPage) {
      setState(() => _slot = slot);
      return;
    }
    if (slot == BottomBarSlot.recent) {
      _openRecent();
      return;
    }

    // 动作项各自对应一个路由。写成 switch 表达式是为了让「所有槽位都处理过」
    // 由编译器保证：以后加一个槽位，这里会直接报缺分支。
    final route = switch (slot) {
      BottomBarSlot.ai => '/ai',
      BottomBarSlot.sources => '/sources',
      BottomBarSlot.sync => '/sync',
      BottomBarSlot.ocr => '/ocr',
      BottomBarSlot.shelf ||
      BottomBarSlot.notes ||
      BottomBarSlot.stats ||
      BottomBarSlot.settings ||
      BottomBarSlot.recent =>
        null,
    };
    if (route != null) context.push(route);
  }

  /// 「最近」直接打开上次在读的那本。没有在读的书时给一句话，而不是静默无反应。
  void _openRecent() {
    final books = ref.read(booksControllerProvider).visible;
    if (books.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('书架还没有书')),
      );
      return;
    }
    books.sort((a, b) =>
        (b.lastReadAt ?? b.addedAt).compareTo(a.lastReadAt ?? a.addedAt));
    context.push('/reader/${books.first.id}');
  }
}
