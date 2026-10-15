import 'package:flutter/material.dart';

import '../../../data/repositories/settings_repository.dart';

/// Bottom sheet with every reader typography, header/footer and page-turn knob.
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
  late final TextEditingController _header =
      TextEditingController(text: _s.headerTemplate);
  late final TextEditingController _footer =
      TextEditingController(text: _s.footerTemplate);

  static const _fonts = ['系统默认', 'serif', 'sans-serif', 'monospace'];
  static const _palette = <int>[
    0xFFFFD54F,
    0xFF81C784,
    0xFF64B5F6,
    0xFFE57373,
    0xFFBA68C8,
    0xFF4DB6AC,
  ];

  @override
  void dispose() {
    _header.dispose();
    _footer.dispose();
    super.dispose();
  }

  void _apply(void Function(ReaderSettings s) mutate) {
    setState(() => mutate(_s));
    widget.onChanged(mutate);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _slider('字号', _s.fontSize, 12, 34, 22,
                (v) => _apply((s) => s.fontSize = v),
                display: _s.fontSize.toStringAsFixed(0)),
            _slider('行距', _s.lineHeight, 1.0, 2.6, 16,
                (v) => _apply((s) => s.lineHeight = v),
                display: _s.lineHeight.toStringAsFixed(2)),
            _slider('字间距', _s.letterSpacing, 0, 3, 30,
                (v) => _apply((s) => s.letterSpacing = v),
                display: _s.letterSpacing.toStringAsFixed(1)),
            _slider('页边距', _s.pageMargin, 8, 48, 40,
                (v) => _apply((s) => s.pageMargin = v),
                display: _s.pageMargin.toStringAsFixed(0)),
            _slider('段首缩进', _s.paragraphIndent.toDouble(), 0, 4, 4,
                (v) => _apply((s) => s.paragraphIndent = v.round()),
                display: '${_s.paragraphIndent} 字'),
            _slider('段间距', _s.paragraphSpacing, 0, 1.5, 15,
                (v) => _apply((s) => s.paragraphSpacing = v),
                display: _s.paragraphSpacing.toStringAsFixed(1)),
            const SizedBox(height: 6),
            _label('对齐方式'),
            Wrap(
              spacing: 8,
              children: ReaderTextAlign.values
                  .map((a) => ChoiceChip(
                        label: Text(a.label),
                        selected: _s.textAlign == a,
                        onSelected: (_) => _apply((s) => s.textAlign = a),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 16),
            _label('字体'),
            Wrap(
              spacing: 8,
              children: _fonts
                  .map((f) => ChoiceChip(
                        label: Text(f),
                        selected: _s.fontFamily == f,
                        onSelected: (_) => _apply((s) => s.fontFamily = f),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 16),
            _label('划线颜色'),
            Wrap(
              spacing: 12,
              children: _palette
                  .map(
                    (c) => GestureDetector(
                      onTap: () => _apply((s) => s.highlightColor = c),
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: Color(c),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _s.highlightColor == c
                                ? Theme.of(context).colorScheme.primary
                                : Colors.black12,
                            width: _s.highlightColor == c ? 3 : 1,
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 16),
            _label('翻页动画'),
            Wrap(
              spacing: 8,
              children: PageTurnStyle.values
                  .map((style) => ChoiceChip(
                        label: Text(style.label),
                        selected: _s.pageTurnStyle == style,
                        onSelected: (_) =>
                            _apply((s) => s.pageTurnStyle = style),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 16),
            _label('自动翻页'),
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
            const Divider(height: 32),
            _label('页眉页脚'),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('显示页眉'),
              value: _s.showHeader,
              onChanged: (v) => _apply((s) => s.showHeader = v),
            ),
            _TemplateField(
              label: '页眉内容',
              controller: _header,
              enabled: _s.showHeader,
              onChanged: (v) => _apply((s) => s.headerTemplate = v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('显示页脚'),
              value: _s.showFooter,
              onChanged: (v) => _apply((s) => s.showFooter = v),
            ),
            _TemplateField(
              label: '页脚内容',
              controller: _footer,
              enabled: _s.showFooter,
              onChanged: (v) => _apply((s) => s.footerTemplate = v),
            ),
            _slider('页眉页脚字号', _s.headerFooterSize, 8, 16, 16,
                (v) => _apply((s) => s.headerFooterSize = v),
                display: _s.headerFooterSize.toStringAsFixed(0)),
            const Divider(height: 32),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('首字下沉'),
              subtitle: const Text('每章首字放大，适合小说与散文'),
              value: _s.dropCap,
              onChanged: (v) => _apply((s) => s.dropCap = v),
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

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          text,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
      );

  Widget _slider(
    String label,
    double value,
    double min,
    double max,
    int divisions,
    ValueChanged<double> onChanged, {
    required String display,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Text(
            '$label  $display',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
        ),
        Slider(
          value: value.clamp(min, max),
          min: min,
          max: max,
          divisions: divisions,
          label: display,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

/// Text field with tap-to-insert macro chips.
class _TemplateField extends StatelessWidget {
  const _TemplateField({
    required this.label,
    required this.controller,
    required this.enabled,
    required this.onChanged,
  });

  final String label;
  final TextEditingController controller;
  final bool enabled;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: enabled
                ? Theme.of(context).colorScheme.onSurface
                : Theme.of(context).colorScheme.outline,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          enabled: enabled,
          style: const TextStyle(fontSize: 14),
          decoration: const InputDecoration(
            isDense: true,
            hintText: '例如：%书名% · %章节%',
          ),
          onChanged: onChanged,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: ReaderMacros.all.entries
              .map(
                (entry) => ActionChip(
                  label: Text(entry.key, style: const TextStyle(fontSize: 11)),
                  tooltip: entry.value,
                  onPressed: enabled
                      ? () {
                          final text = '${controller.text}${entry.key}';
                          controller.text = text;
                          controller.selection = TextSelection.collapsed(
                            offset: text.length,
                          );
                          onChanged(text);
                        }
                      : null,
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 10),
      ],
    );
  }
}
