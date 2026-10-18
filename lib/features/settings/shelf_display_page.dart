import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/shelf_appearance.dart';
import '../../state/providers.dart';

/// 书架陈列。四个开关互不依赖，组合起来就是目标应用里的那几种书架外观。
class ShelfDisplayPage extends ConsumerWidget {
  const ShelfDisplayPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(settingsControllerProvider);
    final shelf = controller.app.shelf;
    final theme = Theme.of(context);

    void update(ShelfAppearance next) =>
        controller.updateApp((a) => a.shelf = next);

    return Scaffold(
      appBar: AppBar(title: const Text('书架陈列')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('封面左侧书脊光影'),
            subtitle: const Text('在封面左边压一道暗边与高光，看起来像一本有厚度的书'),
            value: shelf.spineLight,
            onChanged: (value) => update(shelf.copyWith(spineLight: value)),
          ),
          const Divider(height: 1),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('每行下方显示立体书架'),
            subtitle: const Text('封面站在一条横条上，上表面受光、下方投影'),
            value: shelf.ledge,
            onChanged: (value) => update(shelf.copyWith(ledge: value)),
          ),
          const Divider(height: 1),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('仅显示封面'),
            subtitle: const Text('不显示书名与作者，格子更矮，一屏能放更多'),
            value: shelf.coverOnly,
            onChanged: (value) => update(shelf.copyWith(coverOnly: value)),
          ),
          const SizedBox(height: 20),
          Text('每行列数', style: theme.textTheme.titleSmall),
          const SizedBox(height: 4),
          Text(
            shelf.columns == ShelfAppearance.autoColumns
                ? '按可用宽度自动调整'
                : '固定 ${shelf.columns} 列',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final option in const [
                ShelfAppearance.autoColumns,
                3,
                4,
                5,
                6,
              ])
                ChoiceChip(
                  label: Text(
                    option == ShelfAppearance.autoColumns ? '自动' : '$option 列',
                  ),
                  selected: shelf.columns == option,
                  onSelected: (_) =>
                      update(shelf.copyWith(columns: option)),
                ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            '这几项只影响书架视图，列表与极简视图只受「书脊光影」影响。',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }
}
