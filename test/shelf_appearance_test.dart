import 'package:flutter_test/flutter_test.dart';
import 'package:goodreader/data/models/shelf_appearance.dart';

void main() {
  group('默认值', () {
    test('书脊光影默认开，横条与仅封面默认关，列数自动', () {
      const shelf = ShelfAppearance();
      expect(shelf.spineLight, isTrue);
      expect(shelf.ledge, isFalse);
      expect(shelf.coverOnly, isFalse);
      expect(shelf.columns, ShelfAppearance.autoColumns);
    });
  });

  group('自动列数', () {
    test('手机竖屏算出 3 列', () {
      // 360 宽减去左右各 16 的留白。
      expect(const ShelfAppearance().columnsFor(328), 3);
    });

    test('宽屏跟着变多', () {
      expect(const ShelfAppearance().columnsFor(568), 5);
      expect(const ShelfAppearance().columnsFor(768), 7);
    });

    test('再宽也有上限', () {
      expect(const ShelfAppearance().columnsFor(992), ShelfAppearance.maxColumns);
      expect(const ShelfAppearance().columnsFor(4000), ShelfAppearance.maxColumns);
    });

    test('太窄也不低于下限', () {
      expect(const ShelfAppearance().columnsFor(200), 2);
      expect(const ShelfAppearance().columnsFor(120), ShelfAppearance.minColumns);
      expect(const ShelfAppearance().columnsFor(0), ShelfAppearance.minColumns);
    });

    test('固定列数时不看宽度', () {
      const shelf = ShelfAppearance(columns: 4);
      expect(shelf.columnsFor(328), 4);
      expect(shelf.columnsFor(2000), 4);
    });

    test('固定列数越界被夹回合法范围', () {
      expect(const ShelfAppearance(columns: 1).columnsFor(328), 2);
      expect(const ShelfAppearance(columns: 99).columnsFor(328), 8);
    });
  });

  group('格子高度', () {
    test('封面按 2:3，文字块与横条是固定高度', () {
      // 132 × 1.5 = 198
      expect(const ShelfAppearance().tileHeight(132), closeTo(256, 1e-9));
      expect(const ShelfAppearance(ledge: true).tileHeight(132),
          closeTo(265, 1e-9));
      expect(const ShelfAppearance(coverOnly: true).tileHeight(132),
          closeTo(198, 1e-9));
      expect(
        const ShelfAppearance(coverOnly: true, ledge: true).tileHeight(132),
        closeTo(207, 1e-9),
      );
    });

    test('横条让格子高出横条那一条', () {
      final plain = const ShelfAppearance().tileHeight(120);
      final withLedge = const ShelfAppearance(ledge: true).tileHeight(120);
      expect(withLedge - plain, closeTo(ShelfAppearance.ledgeHeight, 1e-9));
    });
  });

  group('宽高比', () {
    test('比例乘回高度正好是格宽', () {
      for (final shelf in const [
        ShelfAppearance(),
        ShelfAppearance(ledge: true),
        ShelfAppearance(coverOnly: true),
        ShelfAppearance(coverOnly: true, ledge: true),
      ]) {
        for (final width in [88.0, 120.0, 132.0, 168.0]) {
          final ratio = shelf.aspectRatioFor(width);
          expect(
            ratio * shelf.tileHeight(width),
            closeTo(width, 1e-9),
            reason: 'ledge=${shelf.ledge} coverOnly=${shelf.coverOnly} w=$width',
          );
        }
      }
    });

    test('格宽非法时退回封面比例', () {
      expect(const ShelfAppearance().aspectRatioFor(0),
          closeTo(1 / ShelfAppearance.coverAspect, 1e-9));
    });

    test('仅封面时格子更方', () {
      final withText = const ShelfAppearance().aspectRatioFor(132);
      final coverOnly = const ShelfAppearance(coverOnly: true).aspectRatioFor(132);
      expect(coverOnly, greaterThan(withText));
    });
  });

  group('序列化', () {
    test('往返不丢字段', () {
      const shelf = ShelfAppearance(
        spineLight: false,
        ledge: true,
        coverOnly: true,
        columns: 5,
      );
      final back = ShelfAppearance.fromMap(shelf.toMap());
      expect(back.spineLight, isFalse);
      expect(back.ledge, isTrue);
      expect(back.coverOnly, isTrue);
      expect(back.columns, 5);
    });

    test('坏数据退回默认值', () {
      final back = ShelfAppearance.fromMap(null);
      expect(back.spineLight, isTrue);
      expect(back.ledge, isFalse);

      final partial = ShelfAppearance.fromMap(const {
        'ledge': 'yes',
        'columns': 2.5,
      });
      expect(partial.ledge, isFalse);
      expect(partial.columns, ShelfAppearance.autoColumns);
    });
  });
}
