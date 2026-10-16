import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:goodreader/data/models/border_asset.dart';
import 'package:goodreader/data/models/stretch_border.dart';

BorderAsset sample() => BorderAsset(
      id: 'abc123',
      name: '四角花纹',
      path: '/data/borders/abc123.png',
      width: 420,
      height: 560,
      cut: StretchBorder.create(
        width: 420,
        height: 560,
        stretchLeft: 90,
        stretchTop: 120,
        stretchRight: 330,
        stretchBottom: 440,
        safe: const SafeArea(left: 0.12, top: 0.18, right: 0.14, bottom: 0.22),
        mode: StretchMode.horizontal,
        imageScale: 0.4,
      ),
    );

void main() {
  group('BorderAsset 序列化往返', () {
    test('每个字段都能原样读回', () {
      final original = sample();
      final restored = BorderAsset.fromMap(jsonDecode(jsonEncode(original.toMap())))!;

      expect(restored.id, original.id);
      expect(restored.name, original.name);
      expect(restored.path, original.path);
      expect(restored.width, original.width);
      expect(restored.height, original.height);
      expect(restored.cut, original.cut);
      expect(restored.cut.stretchLeft, 90);
      expect(restored.cut.stretchTop, 120);
      expect(restored.cut.stretchRight, 330);
      expect(restored.cut.stretchBottom, 440);
      expect(restored.cut.mode, StretchMode.horizontal);
      expect(restored.cut.imageScale, closeTo(0.4, 1e-9));
      expect(restored.cut.safe.left, closeTo(0.12, 1e-9));
      expect(restored.cut.safe.top, closeTo(0.18, 1e-9));
      expect(restored.cut.safe.right, closeTo(0.14, 1e-9));
      expect(restored.cut.safe.bottom, closeTo(0.22, 1e-9));
    });

    test('没指定切割方式时用中间三分之一', () {
      final asset = BorderAsset(
        id: 'x',
        name: 'n',
        path: 'p',
        width: 300,
        height: 300,
      );
      expect(asset.cut.isGuessCut, isTrue);
      expect(asset.cut.mode, StretchMode.both);
      expect(asset.cut.imageScale, 1.0);
    });
  });

  group('BorderAsset.fromMap 拒绝坏数据', () {
    test('非 Map、缺字段、字段类型不对都返回 null', () {
      expect(BorderAsset.fromMap(null), isNull);
      expect(BorderAsset.fromMap('nope'), isNull);
      expect(BorderAsset.fromMap(42), isNull);
      expect(BorderAsset.fromMap(<String, dynamic>{}), isNull);
      expect(
        BorderAsset.fromMap({
          'id': 1,
          'name': 'n',
          'path': 'p',
          'width': 10,
          'height': 10,
        }),
        isNull,
      );
      expect(
        BorderAsset.fromMap({
          'id': 'a',
          'name': 'n',
          'path': 'p',
          'width': 0,
          'height': 10,
        }),
        isNull,
      );
      expect(
        BorderAsset.fromMap({
          'id': 'a',
          'name': 'n',
          'path': 'p',
          'width': '10',
          'height': 10,
        }),
        isNull,
      );
    });

    test('模式序号越界回落 both，比例缺失回落 100%', () {
      final restored = BorderAsset.fromMap({
        'id': 'a',
        'name': 'n',
        'path': 'p',
        'width': 10,
        'height': 10,
        'mode': 99,
      })!;
      expect(restored.cut.mode, StretchMode.both);
      expect(restored.cut.imageScale, 1.0);
    });

    test('切割值越界时被夹回图内', () {
      final restored = BorderAsset.fromMap({
        'id': 'a',
        'name': 'n',
        'path': 'p',
        'width': 100,
        'height': 100,
        'stretchLeft': -20,
        'stretchRight': 999,
      })!;
      expect(restored.cut.stretchLeft, 0);
      expect(restored.cut.stretchRight, 100);
    });
  });

  group('decodeAll', () {
    test('空串与坏 JSON 返回空列表而不是抛异常', () {
      expect(BorderAsset.decodeAll(''), isEmpty);
      expect(BorderAsset.decodeAll(null), isEmpty);
      expect(BorderAsset.decodeAll('{not json'), isEmpty);
      expect(BorderAsset.decodeAll('"a string"'), isEmpty);
      expect(BorderAsset.decodeAll('{}'), isEmpty);
    });

    test('整库编解码保持顺序与内容', () {
      final assets = [sample(), sample()..name = '第二张'];
      final text = BorderAsset.encodeAll(assets);
      final restored = BorderAsset.decodeAll(text);
      expect(restored.length, 2);
      expect(restored[0].name, '四角花纹');
      expect(restored[1].name, '第二张');
      expect(restored[1].cut, assets[1].cut);
    });

    test('坏条目被跳过，好条目仍然读回', () {
      final good = sample().toMap();
      final text = jsonEncode([good, {'id': 'broken'}]);
      final restored = BorderAsset.decodeAll(text);
      expect(restored.length, 1);
      expect(restored.single.id, 'abc123');
    });
  });
}
