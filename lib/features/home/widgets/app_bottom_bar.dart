import 'package:flutter/material.dart';

import '../../../data/models/bottom_bar.dart';

/// 可配置的底栏。
///
/// 两种形态共用一套内容：固定形态贴底铺满宽度，悬浮形态圆角浮起并留左右边距。
/// 两种都做成半透明，透出一点应用背景。
///
/// 这里**没有**用 `BackdropFilter`。底栏是通过 `bottomNavigationBar` 参与布局的，
/// 内容排在它上方，背后是空的——模糊一片纯色和半透明没有区别。要让模糊有意义
/// 就得让底栏压在内容上（`extendBody`），代价是每个页面都要自己补一段底部留白，
/// 补漏了最后一项就会被盖住。这笔交换不划算。
class AppBottomBar extends StatelessWidget {
  const AppBottomBar({
    super.key,
    required this.config,
    required this.currentSlot,
    required this.onTap,
  });

  final BottomBarConfig config;

  /// 当前停留的页面项。动作项不参与选中。
  final BottomBarSlot currentSlot;

  final ValueChanged<BottomBarSlot> onTap;

  @override
  Widget build(BuildContext context) {
    final palette = _Palette.resolve(Theme.of(context), config.tint);
    final slots = config.visible;
    final content = SizedBox(
      height: config.height,
      child: Row(
        children: [
          for (final slot in slots)
            Expanded(child: _Item(
              slot: slot,
              selected: slot.isPage && slot == currentSlot,
              config: config,
              palette: palette,
              onTap: () => onTap(slot),
            )),
        ],
      ),
    );

    if (config.style == BottomBarStyle.fixed) {
      return SafeArea(
        top: false,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: palette.surface,
            border: Border(top: BorderSide(color: palette.hairline)),
          ),
          child: content,
        ),
      );
    }

    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: config.sideMargin),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: palette.hairline),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(palette.isDark ? 0.4 : 0.08),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: content,
          ),
        ),
      ),
    );
  }
}

class _Item extends StatelessWidget {
  const _Item({
    required this.slot,
    required this.selected,
    required this.config,
    required this.palette,
    required this.onTap,
  });

  final BottomBarSlot slot;
  final bool selected;
  final BottomBarConfig config;
  final _Palette palette;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? palette.foreground : palette.muted;

    return InkWell(
      onTap: onTap,
      splashColor: palette.foreground.withOpacity(0.06),
      highlightColor: Colors.transparent,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: EdgeInsets.symmetric(
              horizontal: config.showLabels ? 12 : 14,
              vertical: 3,
            ),
            decoration: BoxDecoration(
              color: selected
                  ? palette.foreground.withOpacity(0.08)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              iconFor(slot),
              size: config.iconSize,
              color: color,
            ),
          ),
          if (config.showLabels) ...[
            const SizedBox(height: 3),
            Text(
              slot.label,
              maxLines: 1,
              overflow: TextOverflow.clip,
              style: TextStyle(
                fontSize: 11,
                height: 1.1,
                color: color,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 每个槽位的图标。槽位是数据，图标是外观，所以映射放在界面层。
IconData iconFor(BottomBarSlot slot) => switch (slot) {
      BottomBarSlot.shelf => Icons.auto_stories_outlined,
      BottomBarSlot.notes => Icons.sticky_note_2_outlined,
      BottomBarSlot.stats => Icons.insights_outlined,
      BottomBarSlot.settings => Icons.settings_outlined,
      BottomBarSlot.recent => Icons.history,
      BottomBarSlot.ai => Icons.auto_awesome_outlined,
      BottomBarSlot.sources => Icons.rss_feed,
      BottomBarSlot.sync => Icons.sync,
      BottomBarSlot.ocr => Icons.document_scanner_outlined,
    };

class _Palette {
  const _Palette({
    required this.isDark,
    required this.surface,
    required this.foreground,
    required this.muted,
    required this.hairline,
  });

  final bool isDark;
  final Color surface;
  final Color foreground;
  final Color muted;
  final Color hairline;

  /// 底栏的深浅色与应用主题解耦：目标应用的底栏有独立的深浅变体，
  /// 所以这里不读 `colorScheme`，只读「该用深色还是浅色」。
  static _Palette resolve(ThemeData theme, BottomBarTint tint) {
    final isDark = switch (tint) {
      BottomBarTint.inherit => theme.brightness == Brightness.dark,
      BottomBarTint.dark => true,
      BottomBarTint.light => false,
    };

    if (isDark) {
      return _Palette(
        isDark: true,
        surface: const Color(0xE61A1B1E),
        foreground: const Color(0xFFF2F2F3),
        muted: const Color(0xFF8B8D93),
        hairline: const Color(0x1FFFFFFF),
      );
    }
    return _Palette(
      isDark: false,
      surface: const Color(0xE6FFFFFF),
      foreground: const Color(0xFF15161A),
      muted: const Color(0xFF6E7078),
      hairline: const Color(0x14000000),
    );
  }
}
