import 'package:flutter/material.dart';

import '../../../data/repositories/settings_repository.dart';

/// Bottom sheet with every reader typography / theme knob.
class ReaderSettingsSheet extends StatefulWidget {
  const ReaderSettingsSheet({
    super.key,
    required this.settings,
    required this.onChanged,
    required this.onAutoPageChanged,
  });

  final ReaderSettings settings;
  final Future<void> Function(void Function(ReaderSettings s) mutate) onChanged;
  final void Function(int seconds) onAutoPageChanged;

  @override
  State<ReaderSettingsSheet> createState() => _ReaderSettingsSheetState();
}

class _ReaderSettingsSheetState extends State<ReaderSettingsSheet> {
  late final ReaderSettings _s = widget.settings;

  static const _fonts = ['系统默认', 'serif', 'sans-serif', 'monospace'];

  void _apply(void Function(ReaderSettings s) mutate) {
    setState(() => mutate(_s));
    widget.onChanged(mutate);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionTitle('阅读主题'),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: ReaderTheme.values.map((t) {
                final selected = t == _s.theme;
                return GestureDetector(
                  onTap: () => _apply((s) => s.theme = t),
                  child: Container(
                    width: 64,
                    height: 76,
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
                            style: TextStyle(color: t.foreground, fontSize: 20)),
                        const SizedBox(height: 4),
                        Text(
                          t.label,
                          style: TextStyle(color: t.foreground, fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            _SectionTitle('字号  ${_s.fontSize.toStringAsFixed(0)}'),
            Slider(
              value: _s.fontSize,
              min: 12,
              max: 34,
              divisions: 22,
              label: _s.fontSize.toStringAsFixed(0),
              onChanged: (v) => _apply((s) => s.fontSize = v),
            ),
            _SectionTitle('行距  ${_s.lineHeight.toStringAsFixed(2)}'),
            Slider(
              value: _s.lineHeight,
              min: 1.0,
              max: 2.6,
              divisions: 16,
              label: _s.lineHeight.toStringAsFixed(2),
              onChanged: (v) => _apply((s) => s.lineHeight = v),
            ),
            _SectionTitle('字间距  ${_s.letterSpacing.toStringAsFixed(1)}'),
            Slider(
              value: _s.letterSpacing,
              min: 0,
              max: 3,
              divisions: 30,
              label: _s.letterSpacing.toStringAsFixed(1),
              onChanged: (v) => _apply((s) => s.letterSpacing = v),
            ),
            _SectionTitle('页边距  ${_s.pageMargin.toStringAsFixed(0)}'),
            Slider(
              value: _s.pageMargin,
              min: 8,
              max: 48,
              divisions: 40,
              label: _s.pageMargin.toStringAsFixed(0),
              onChanged: (v) => _apply((s) => s.pageMargin = v),
            ),
            _SectionTitle('段首缩进  ${_s.paragraphIndent} 字'),
            Slider(
              value: _s.paragraphIndent.toDouble(),
              min: 0,
              max: 4,
              divisions: 4,
              label: '${_s.paragraphIndent}',
              onChanged: (v) => _apply((s) => s.paragraphIndent = v.round()),
            ),
            const SizedBox(height: 12),
            _SectionTitle('字体'),
            Wrap(
              spacing: 8,
              children: _fonts.map((f) {
                return ChoiceChip(
                  label: Text(f == '系统默认' ? f : f),
                  selected: _s.fontFamily == f,
                  onSelected: (_) => _apply((s) => s.fontFamily = f),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            _SectionTitle('翻页动画'),
            Wrap(
              spacing: 8,
              children: PageTurnStyle.values.map((style) {
                return ChoiceChip(
                  label: Text(style.label),
                  selected: _s.pageTurnStyle == style,
                  onSelected: (_) => _apply((s) => s.pageTurnStyle = style),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            _SectionTitle('自动翻页'),
            Wrap(
              spacing: 8,
              children: [0, 5, 10, 20, 30, 60].map((seconds) {
                return ChoiceChip(
                  label: Text(seconds == 0 ? '关闭' : '$seconds 秒'),
                  selected: _s.autoPageSeconds == seconds,
                  onSelected: (_) {
                    _apply((s) => s.autoPageSeconds = seconds);
                    widget.onAutoPageChanged(seconds);
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('显示页眉（章节名）'),
              value: _s.showHeader,
              onChanged: (v) => _apply((s) => s.showHeader = v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('显示页脚（进度）'),
              value: _s.showFooter,
              onChanged: (v) => _apply((s) => s.showFooter = v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('阅读时保持屏幕常亮'),
              value: _s.keepScreenOn,
              onChanged: (v) => _apply((s) => s.keepScreenOn = v),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
      ),
    );
  }
}
