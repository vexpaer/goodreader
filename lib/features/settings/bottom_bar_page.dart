import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/bottom_bar.dart';
import '../../state/providers.dart';
import '../home/widgets/app_bottom_bar.dart';

/// 配置底栏：显示哪些、什么顺序、什么形态、多高。
class BottomBarSettingsPage extends ConsumerWidget {
  const BottomBarSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(settingsControllerProvider);
    final config = controller.app.bottomBar;
    final theme = Theme.of(context);

    void update(BottomBarConfig next) =>
        controller.updateApp((a) => a.bottomBar = next);

    return Scaffold(
      appBar: AppBar(title: const Text('底栏')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        children: [
          _Preview(config: config),
          const SizedBox(height: 24),
          _Label('形态'),
          SegmentedButton<BottomBarStyle>(
            segments: [
              for (final style in BottomBarStyle.values)
                ButtonSegment(value: style, label: Text(style.label)),
            ],
            selected: {config.style},
            showSelectedIcon: false,
            onSelectionChanged: (value) =>
                update(config.copyWith(style: value.first)),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 6, bottom: 4),
            child: Text(
              config.style.hint,
              style: theme.textTheme.bodySmall,
            ),
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('在图标下方显示文字标签'),
            subtitle: const Text('关掉之后只剩图标，底栏更窄但要点记忆'),
            value: config.showLabels,
            onChanged: (value) => update(config.copyWith(showLabels: value)),
          ),
          const SizedBox(height: 8),
          _Label('高度'),
          _Slider(
            value: config.narrowness,
            label: '窄度 ${(config.narrowness * 100).round()}%',
            hint: '数值越大底栏越窄，实际高度 ${config.height.toStringAsFixed(0)}',
            onChanged: (value) => update(config.copyWith(narrowness: value)),
          ),
          if (config.style == BottomBarStyle.floating) ...[
            const SizedBox(height: 8),
            _Label('悬浮左右边距'),
            _Slider(
              value: config.sideMargin / 48,
              label: '${config.sideMargin.toStringAsFixed(0)}',
              hint: '距离屏幕左右边缘的距离',
              onChanged: (value) =>
                  update(config.copyWith(sideMargin: value * 48)),
            ),
          ],
          const SizedBox(height: 8),
          _Label('配色'),
          SegmentedButton<BottomBarTint>(
            segments: [
              for (final tint in BottomBarTint.values)
                ButtonSegment(value: tint, label: Text(tint.label)),
            ],
            selected: {config.tint},
            showSelectedIcon: false,
            onSelectionChanged: (value) =>
                update(config.copyWith(tint: value.first)),
          ),
          const SizedBox(height: 24),
          _Label('项目与顺序'),
          Text(
            '拖动右侧把手调整顺序。关掉的项不会从列表里消失，随时可以打开。',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            itemCount: config.order.length,
            onReorder: (oldIndex, newIndex) {
              // ReorderableListView 给的是旧列表里的下标，往下拖时要先减一。
              final target = newIndex > oldIndex ? newIndex - 1 : newIndex;
              final slot = config.order[oldIndex];
              update(config.moveTo(slot, target));
            },
            itemBuilder: (context, index) {
              final slot = config.order[index];
              final visible = !config.hidden.contains(slot);
              return ListTile(
                key: ValueKey(slot),
                contentPadding: EdgeInsets.zero,
                leading: Icon(iconFor(slot)),
                title: Text(slot.label),
                subtitle: Text(
                  visible ? slot.description : '${slot.description} · 已隐藏',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Switch(
                      value: visible,
                      onChanged: (value) =>
                          update(config.withVisibility(slot, value)),
                    ),
                    ReorderableDragStartListener(
                      index: index,
                      child: const Padding(
                        padding: EdgeInsets.only(left: 4, right: 4),
                        child: Icon(Icons.drag_handle, size: 20),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          Text(
            '前四项是可以停留的页面；其余是动作入口，点一下打开对应界面，'
            '不参与「当前选中」。全部关掉时会退回只显示书架——一条空的底栏没法用。',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _Preview extends StatelessWidget {
  const _Preview({required this.config});

  final BottomBarConfig config;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('预览', style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Container(
            height: config.height + 64,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.35),
            ),
            child: Column(
              children: [
                Expanded(
                  child: Center(
                    child: Text(
                      '页面内容',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ),
                // 预览里点不动，避免误触把预览当成真的导航。
                IgnorePointer(
                  child: AppBottomBar(
                    config: config,
                    currentSlot: BottomBarSlot.shelf,
                    onTap: (_) {},
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text, style: Theme.of(context).textTheme.titleSmall),
      );
}

class _Slider extends StatelessWidget {
  const _Slider({
    required this.value,
    required this.label,
    required this.hint,
    required this.onChanged,
  });

  final double value;
  final String label;
  final String hint;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(hint, style: theme.textTheme.bodySmall)),
            Text(label, style: theme.textTheme.bodySmall),
          ],
        ),
        Slider(value: value, onChanged: onChanged),
      ],
    );
  }
}
