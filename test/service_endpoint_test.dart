import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:goodreader/data/models/service_endpoint.dart';
import 'package:goodreader/data/repositories/provider_catalog.dart';

ServiceEndpoint sample() => ServiceEndpoint(
      id: 'ep-0-1',
      kind: ServiceKind.ai,
      label: '公司的 DeepSeek',
      baseUrl: 'https://api.deepseek.com/v1/',
      secret: 'sk-abcdef123456',
      model: 'deepseek-chat',
      note: '有免费额度',
      createdAt: DateTime.fromMillisecondsSinceEpoch(1700000000000),
    );

void main() {
  group('ServiceEndpoint 归一化与脱敏', () {
    test('normalizedBaseUrl 去掉末尾斜杠并补协议', () {
      expect(sample().normalizedBaseUrl, 'https://api.deepseek.com/v1');
      expect(
        const ServiceEndpoint(
          id: 'a',
          kind: ServiceKind.sync,
          label: 'l',
          baseUrl: 'dav.example.com/dav/',
        ).normalizedBaseUrl,
        'https://dav.example.com/dav',
      );
      expect(
        const ServiceEndpoint(
          id: 'a',
          kind: ServiceKind.sync,
          label: 'l',
          baseUrl: 'http://localhost:1234/v1/',
        ).normalizedBaseUrl,
        'http://localhost:1234/v1',
      );
      expect(
        const ServiceEndpoint(
          id: 'a',
          kind: ServiceKind.ai,
          label: 'l',
          baseUrl: '   ',
        ).normalizedBaseUrl,
        '',
      );
    });

    test('maskSecret 只留首尾两位', () {
      expect(maskSecret('sk-abcdef123456'), 'sk***********56');
      expect(maskSecret('abc'), '****');
      expect(maskSecret(''), '未填写');
      expect(maskSecret('   '), '未填写');
    });

    test('toMap 不含密钥', () {
      final map = sample().toMap();
      expect(map.containsKey('secret'), isFalse);
      expect(jsonEncode(map).contains('sk-abcdef123456'), isFalse);
    });
  });

  group('ServiceEndpoint 序列化往返', () {
    test('每个字段都能原样读回', () {
      final restored =
          ServiceEndpoint.fromMap(jsonDecode(jsonEncode(sample().toMap())))!;
      expect(restored.id, 'ep-0-1');
      expect(restored.kind, ServiceKind.ai);
      expect(restored.label, '公司的 DeepSeek');
      expect(restored.baseUrl, 'https://api.deepseek.com/v1/');
      expect(restored.model, 'deepseek-chat');
      expect(restored.note, '有免费额度');
      expect(restored.enabled, isTrue);
      expect(restored.createdAt.millisecondsSinceEpoch, 1700000000000);
    });

    test('坏数据返回 null', () {
      expect(ServiceEndpoint.fromMap(null), isNull);
      expect(ServiceEndpoint.fromMap('x'), isNull);
      expect(ServiceEndpoint.fromMap(<String, dynamic>{}), isNull);
      expect(
        ServiceEndpoint.fromMap({
          'id': 'a',
          'label': 'b',
          'baseUrl': 'c',
          'kind': 99,
        }),
        isNull,
      );
    });

    test('copyWith 保留 id 与创建时间', () {
      final copy = sample().copyWith(label: '新名字', enabled: false);
      expect(copy.id, sample().id);
      expect(copy.createdAt, sample().createdAt);
      expect(copy.label, '新名字');
      expect(copy.enabled, isFalse);
      expect(copy.baseUrl, sample().baseUrl);
    });
  });

  group('ProviderCatalog', () {
    test('目录覆盖五种能力', () {
      for (final kind in ServiceKind.values) {
        expect(ProviderCatalog.ofKind(kind), isNotEmpty, reason: '$kind');
      }
    });

    test('AI 目录全部是 OpenAI 兼容端点，除了自定义项都有预置地址', () {
      for (final preset in ProviderCatalog.ai) {
        expect(preset.kind, ServiceKind.ai);
        expect(preset.name, isNotEmpty);
        if (preset.id == 'custom-ai') {
          expect(preset.defaultBaseUrl, isEmpty);
        } else {
          expect(preset.defaultBaseUrl, isNotEmpty, reason: preset.id);
          expect(preset.defaultBaseUrl.startsWith('http'), isTrue,
              reason: preset.id);
        }
      }
    });

    test('目录 id 唯一，否则 SetActive 会指错', () {
      final ids = ProviderCatalog.all.map((p) => p.id).toList();
      expect(ids.toSet().length, ids.length);
    });

    test('byId 找不到返回 null', () {
      expect(ProviderCatalog.byId('deepseek'), isNotNull);
      expect(ProviderCatalog.byId('no-such-thing'), isNull);
    });

    test('同步目录含 WebDAV 与 S3 两类', () {
      final ids = ProviderCatalog.sync.map((p) => p.id).toSet();
      expect(ids.contains('webdav'), isTrue);
      expect(ids.contains('s3'), isTrue);
      expect(ids.contains('r2'), isTrue);
    });
  });
}
