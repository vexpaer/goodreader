import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/settings_repository.dart';
import '../../state/providers.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  static const _seedColors = [
    0xFF1F6FEB,
    0xFF7C4DFF,
    0xFF00897B,
    0xFFE64A19,
    0xFFAD1457,
    0xFF455A64,
    0xFF827717,
    0xFF3949AB,
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(settingsControllerProvider);
    final app = controller.app;

    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        children: [
          _Section('外观'),
          Card(
            child: Column(
              children: [
                ListTile(
                  title: const Text('主题模式'),
                  subtitle: Text(switch (app.themeMode) {
                    ThemeMode.system => '跟随系统',
                    ThemeMode.light => '浅色',
                    ThemeMode.dark => '深色',
                  }),
                  trailing: SegmentedButton<ThemeMode>(
                    segments: const [
                      ButtonSegment(value: ThemeMode.system, label: Text('自动')),
                      ButtonSegment(value: ThemeMode.light, label: Text('浅色')),
                      ButtonSegment(value: ThemeMode.dark, label: Text('深色')),
                    ],
                    selected: {app.themeMode},
                    showSelectedIcon: false,
                    onSelectionChanged: (s) => controller
                        .updateApp((a) => a.themeMode = s.first),
                  ),
                ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('主题色', style: TextStyle(fontSize: 13)),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: _seedColors.map((c) {
                          final selected = app.seedColor == c;
                          return GestureDetector(
                            onTap: () => controller.updateApp((a) => a.seedColor = c),
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: Color(c),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: selected ? Colors.white : Colors.transparent,
                                  width: 3,
                                ),
                                boxShadow: selected
                                    ? [
                                        BoxShadow(
                                          color: Color(c).withOpacity(0.5),
                                          blurRadius: 8,
                                        ),
                                      ]
                                    : null,
                              ),
                              child: selected
                                  ? const Icon(Icons.check,
                                      size: 18, color: Colors.white)
                                  : null,
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  title: const Text('书架视图'),
                  subtitle: Text(app.shelfView.label),
                  trailing: SegmentedButton<ShelfView>(
                    segments: const [
                      ButtonSegment(value: ShelfView.grid, label: Text('网格')),
                      ButtonSegment(value: ShelfView.list, label: Text('列表')),
                      ButtonSegment(value: ShelfView.compact, label: Text('极简')),
                    ],
                    selected: {app.shelfView},
                    showSelectedIcon: false,
                    onSelectionChanged: (s) =>
                        controller.updateApp((a) => a.shelfView = s.first),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  title: const Text('封面填充'),
                  subtitle: Text(app.coverFill.label),
                  trailing: SegmentedButton<CoverFill>(
                    segments: const [
                      ButtonSegment(value: CoverFill.crop, label: Text('裁剪')),
                      ButtonSegment(value: CoverFill.fit, label: Text('完整')),
                      ButtonSegment(
                          value: CoverFill.stretch, label: Text('拉伸')),
                    ],
                    selected: {app.coverFill},
                    showSelectedIcon: false,
                    onSelectionChanged: (s) =>
                        controller.updateApp((a) => a.coverFill = s.first),
                  ),
                ),
              ],
            ),
          ),
          _Section('阅读目标'),
          Card(
            child: Column(
              children: [
                ListTile(
                  title: const Text('每日阅读时长'),
                  subtitle: Text('${app.dailyGoalMinutes} 分钟'),
                  trailing: SizedBox(
                    width: 140,
                    child: Slider(
                      value: app.dailyGoalMinutes.toDouble().clamp(5, 240),
                      min: 5,
                      max: 240,
                      divisions: 47,
                      label: '${app.dailyGoalMinutes}',
                      onChanged: (v) => controller
                          .updateApp((a) => a.dailyGoalMinutes = v.round()),
                    ),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  title: const Text('每日阅读字数'),
                  subtitle: Text('${app.dailyGoalChars} 字'),
                  trailing: SizedBox(
                    width: 140,
                    child: Slider(
                      value: app.dailyGoalChars.toDouble().clamp(500, 50000),
                      min: 500,
                      max: 50000,
                      divisions: 99,
                      label: '${app.dailyGoalChars}',
                      onChanged: (v) => controller
                          .updateApp((a) => a.dailyGoalChars = v.round()),
                    ),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  title: const Text('年度阅读目标'),
                  subtitle: Text('${app.yearlyGoalBooks} 本'),
                  trailing: SizedBox(
                    width: 140,
                    child: Slider(
                      value: app.yearlyGoalBooks.toDouble().clamp(1, 200),
                      min: 1,
                      max: 200,
                      divisions: 199,
                      label: '${app.yearlyGoalBooks}',
                      onChanged: (v) => controller
                          .updateApp((a) => a.yearlyGoalBooks = v.round()),
                    ),
                  ),
                ),
              ],
            ),
          ),
          _Section('听书'),
          Card(
            child: Column(
              children: [
                ListTile(
                  title: const Text('语速'),
                  subtitle: Text(app.ttsRate.toStringAsFixed(2)),
                  trailing: SizedBox(
                    width: 140,
                    child: Slider(
                      value: app.ttsRate.clamp(0.1, 1.0),
                      min: 0.1,
                      max: 1.0,
                      divisions: 18,
                      onChanged: (v) =>
                          controller.updateApp((a) => a.ttsRate = v),
                    ),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  title: const Text('音调'),
                  subtitle: Text(app.ttsPitch.toStringAsFixed(2)),
                  trailing: SizedBox(
                    width: 140,
                    child: Slider(
                      value: app.ttsPitch.clamp(0.5, 2.0),
                      min: 0.5,
                      max: 2.0,
                      divisions: 15,
                      onChanged: (v) =>
                          controller.updateApp((a) => a.ttsPitch = v),
                    ),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  title: const Text('朗读语言'),
                  subtitle: Text(app.ttsLanguage),
                  trailing: DropdownButton<String>(
                    value: app.ttsLanguage,
                    items: const [
                      DropdownMenuItem(value: 'zh-CN', child: Text('普通话')),
                      DropdownMenuItem(value: 'zh-TW', child: Text('国语（台湾）')),
                      DropdownMenuItem(value: 'en-US', child: Text('English')),
                      DropdownMenuItem(value: 'ja-JP', child: Text('日本語')),
                    ],
                    onChanged: (v) => controller.updateApp(
                        (a) => a.ttsLanguage = v ?? a.ttsLanguage),
                  ),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text('读完自动读下一章'),
                  value: app.autoTtsNextChapter,
                  onChanged: (v) =>
                      controller.updateApp((a) => a.autoTtsNextChapter = v),
                ),
              ],
            ),
          ),
          _Section('数据'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: const Text('GoodReader'),
                  subtitle: const Text('版本 0.1.0 · 免费开源'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.map_outlined),
                  title: const Text('功能路线图'),
                  subtitle: const Text('查看已实现与规划中的功能'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showRoadmap(context),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.delete_sweep_outlined,
                      color: Colors.redAccent),
                  title: const Text('清空书架',
                      style: TextStyle(color: Colors.redAccent)),
                  subtitle: const Text('删除所有书籍、笔记与统计（不可恢复）'),
                  onTap: () => _confirmWipe(context, ref),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmWipe(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('清空全部数据'),
        content: const Text('将删除所有书籍、笔记和阅读统计，且无法恢复。确定继续吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('确认清空'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(bookRepositoryProvider).clear();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('已清空书架')));
  }

  void _showRoadmap(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        builder: (context, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
          children: const [
            Text('GoodReader 功能路线图',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            SizedBox(height: 16),
            _RoadmapGroup('已实现（v0.1）', [
              '书架：网格 / 列表 / 极简三种视图，标签、收藏、私密书',
              '导入：TXT、EPUB（自动解析书名、作者、封面、目录）',
              '阅读器：章节翻页、点击翻页、目录跳转、进度记忆',
              '排版：6 套阅读主题、字号 / 行距 / 字距 / 边距 / 缩进、字体选择',
              '笔记：选中即高亮、写笔记、书签、全文笔记检索与导出',
              '统计：今日 / 累计时长字数、连续天数、7 日柱状图、热力图、排行',
              '听书：系统 TTS，语速音调可调，自动连读下一章',
              '设置：主题模式与主题色、阅读目标、数据清空',
            ]),
            _RoadmapGroup('下一阶段', [
              'PDF / MOBI / AZW3 / 漫画（CBZ/CBR）阅读引擎',
              '仿真翻页、水波纹翻页等动画效果',
              '书签与笔记的海报分享模板',
              'Wi-Fi 局域网传书',
              '简体 ↔ 繁体转换、竖排阅读',
            ]),
            _RoadmapGroup('规划中', [
              'AI 助手：总结 / 问答 / 人物关系图（自填 API Key）',
              '云同步：WebDAV / S3 / 网盘',
              'OCR 拍书识别',
              '多角色听书与在线 TTS',
              '成就系统与年度报告',
              '书源与规则脚本引擎',
            ]),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.title);

  final String title;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      );
}

class _RoadmapGroup extends StatelessWidget {
  const _RoadmapGroup(this.title, this.items);

  final String title;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 18, bottom: 8),
          child: Text(title,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
        ),
        for (final item in items)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('· '),
                Expanded(
                  child: Text(item, style: const TextStyle(height: 1.5)),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
