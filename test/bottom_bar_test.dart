import 'package:flutter_test/flutter_test.dart';
import 'package:goodreader/data/models/bottom_bar.dart';

void main() {
  group('默认配置', () {
    test('只显示四个页面项', () {
      final config = BottomBarConfig();
      expect(config.visible, [
        BottomBarSlot.shelf,
        BottomBarSlot.notes,
        BottomBarSlot.stats,
        BottomBarSlot.settings,
      ]);
    });

    test('顺序里始终包含全部槽位', () {
      final config = BottomBarConfig();
      expect(config.order.length, BottomBarSlot.values.length);
      expect(config.order.toSet(), BottomBarSlot.values.toSet());
    });

    test('默认是固定形态、带文字、中等高度', () {
      final config = BottomBarConfig();
      expect(config.style, BottomBarStyle.fixed);
      expect(config.showLabels, isTrue);
      expect(config.narrowness, 0.35);
      expect(config.tint, BottomBarTint.inherit);
    });
  });

  group('高度', () {
    test('窄度 0 最高、1 最矮、中间取线性值', () {
      expect(BottomBarConfig(narrowness: 0).height, 76);
      expect(BottomBarConfig(narrowness: 1).height, 48);
      expect(BottomBarConfig(narrowness: 0.5).height, 62);
    });

    test('窄度越大越窄', () {
      final heights = [
        for (var i = 0; i <= 10; i++)
          BottomBarConfig(narrowness: i / 10).height,
      ];
      for (var i = 1; i < heights.length; i++) {
        expect(heights[i], lessThan(heights[i - 1]));
      }
    });

    test('越界的窄度被夹回 0..1', () {
      expect(BottomBarConfig(narrowness: -3).narrowness, 0);
      expect(BottomBarConfig(narrowness: 9).narrowness, 1);
      expect(BottomBarConfig(narrowness: 9).height, 48);
    });

    test('带文字时图标小一点', () {
      expect(BottomBarConfig(showLabels: true).iconSize, 22);
      expect(BottomBarConfig(showLabels: false).iconSize, 24);
    });
  });

  group('显示与顺序', () {
    test('关掉的项不出现在可见列表里，但仍在顺序里', () {
      final config = BottomBarConfig().withVisibility(BottomBarSlot.notes, false);
      expect(config.visible.contains(BottomBarSlot.notes), isFalse);
      expect(config.order.contains(BottomBarSlot.notes), isTrue);
      expect(config.visible.length, 3);
    });

    test('重新打开后回到原来的位置', () {
      final hidden = BottomBarConfig().withVisibility(BottomBarSlot.notes, false);
      final shown = hidden.withVisibility(BottomBarSlot.notes, true);
      expect(shown.visible[1], BottomBarSlot.notes);
    });

    test('全部关掉时退回只显示书架', () {
      var config = BottomBarConfig();
      for (final slot in BottomBarSlot.values) {
        config = config.withVisibility(slot, false);
      }
      expect(config.visible, [BottomBarSlot.shelf]);
    });

    test('动作项可以打开并出现在可见列表里', () {
      final config = BottomBarConfig().withVisibility(BottomBarSlot.ai, true);
      expect(config.visible.contains(BottomBarSlot.ai), isTrue);
      // 顺序不变，AI 仍在枚举里的位置。
      expect(
        config.visible.indexOf(BottomBarSlot.ai),
        greaterThan(config.visible.indexOf(BottomBarSlot.settings)),
      );
    });

    test('moveTo 的下标是移除之后的位置', () {
      final config = BottomBarConfig();
      // 把设置（下标 3）移到最前。
      final moved = config.moveTo(BottomBarSlot.settings, 0);
      expect(moved.order.first, BottomBarSlot.settings);
      expect(moved.order.length, config.order.length);
    });

    test('moveTo 往下拖时按下标插入', () {
      final config = BottomBarConfig();
      // 把书架（0）放到移除后的第 2 位，即原来的第 3 位。
      final moved = config.moveTo(BottomBarSlot.shelf, 2);
      expect(moved.order[2], BottomBarSlot.shelf);
      expect(moved.order[0], BottomBarSlot.notes);
      expect(moved.order[1], BottomBarSlot.stats);
    });

    test('moveTo 越界夹到两端', () {
      final config = BottomBarConfig();
      expect(config.moveTo(BottomBarSlot.shelf, 99).order.last,
          BottomBarSlot.shelf);
      expect(config.moveTo(BottomBarSlot.settings, -5).order.first,
          BottomBarSlot.settings);
    });

    test('调顺序不动显示状态', () {
      final hidden = BottomBarConfig().withVisibility(BottomBarSlot.stats, false);
      final moved = hidden.moveTo(BottomBarSlot.stats, 0);
      expect(moved.hidden.contains(BottomBarSlot.stats), isTrue);
    });
  });

  group('顺序归一化', () {
    test('重复项只留第一次', () {
      final config = BottomBarConfig(order: const [
        BottomBarSlot.stats,
        BottomBarSlot.shelf,
        BottomBarSlot.stats,
      ]);
      expect(config.order.where((s) => s == BottomBarSlot.stats).length, 1);
      expect(config.order.first, BottomBarSlot.stats);
    });

    test('缺的槽位补到末尾，不丢', () {
      final config = BottomBarConfig(order: const [BottomBarSlot.settings]);
      expect(config.order.first, BottomBarSlot.settings);
      expect(config.order.length, BottomBarSlot.values.length);
      expect(config.order.toSet(), BottomBarSlot.values.toSet());
    });

    test('传 null 得到枚举顺序', () {
      expect(BottomBarConfig(order: null).order, BottomBarSlot.values);
    });
  });

  group('页面与动作', () {
    test('只有四项是可停留的页面', () {
      final pages =
          BottomBarSlot.values.where((s) => s.isPage).toList();
      expect(pages, [
        BottomBarSlot.shelf,
        BottomBarSlot.notes,
        BottomBarSlot.stats,
        BottomBarSlot.settings,
      ]);
    });
  });

  group('序列化', () {
    test('往返不丢字段', () {
      final config = BottomBarConfig(
        style: BottomBarStyle.floating,
        showLabels: false,
        narrowness: 0.8,
        sideMargin: 24,
        tint: BottomBarTint.dark,
        order: const [BottomBarSlot.stats, BottomBarSlot.shelf],
        hidden: const {BottomBarSlot.notes},
      );
      final back = BottomBarConfig.fromMap(config.toMap());
      expect(back.style, BottomBarStyle.floating);
      expect(back.showLabels, isFalse);
      expect(back.narrowness, closeTo(0.8, 1e-9));
      expect(back.sideMargin, closeTo(24, 1e-9));
      expect(back.tint, BottomBarTint.dark);
      expect(back.order, config.order);
      expect(back.hidden, config.hidden);
    });

    test('坏数据退回默认值', () {
      final back = BottomBarConfig.fromMap(null);
      expect(back.style, BottomBarStyle.fixed);
      expect(back.order.length, BottomBarSlot.values.length);

      final partial = BottomBarConfig.fromMap(const {
        'style': 99,
        'tint': 'dark',
        'narrowness': 'wide',
      });
      expect(partial.style, BottomBarStyle.fixed);
      expect(partial.tint, BottomBarTint.inherit);
      expect(partial.narrowness, 0.35);
    });

    test('没有 hidden 键时用默认隐藏集', () {
      final back = BottomBarConfig.fromMap(const {'style': 1});
      expect(back.hidden, BottomBarConfig.defaultHidden);
    });

    test('hidden 是空列表表示全部显示', () {
      final back = BottomBarConfig.fromMap(const {'hidden': <int>[]});
      expect(back.hidden, isEmpty);
      expect(back.visible.length, BottomBarSlot.values.length);
    });

    test('越界的槽位下标被丢掉', () {
      final back = BottomBarConfig.fromMap(const {
        'hidden': [0, 99, -1, 2],
      });
      expect(back.hidden, {BottomBarSlot.shelf, BottomBarSlot.stats});
    });
  });
}
