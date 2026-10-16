import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:goodreader/services/sync/sync_backend.dart';
import 'package:goodreader/services/sync/sync_service.dart';

class FakeBackend extends SyncBackend {
  FakeBackend({Map<String, String>? files}) : files = files ?? <String, String>{};

  /// key 是带目录的完整路径。会被 put 与 delete 修改。
  final Map<String, String> files;

  final List<String> calls = [];

  @override
  Future<void> ensureDirectory(String path) async {
    calls.add('MKCOL $path');
  }

  @override
  Future<List<RemoteEntry>> list(String path) async {
    calls.add('LIST $path');
    final prefix = '$path/';
    return [
      for (final entry in files.entries)
        if (entry.key.startsWith(prefix))
          RemoteEntry(
            path: entry.key.substring(prefix.length),
            size: entry.value.length,
            modified: DateTime.fromMillisecondsSinceEpoch(0),
          ),
    ];
  }

  @override
  Future<void> put(String path, String content) async {
    calls.add('PUT $path');
    files[path] = content;
  }

  @override
  Future<String?> get(String path) async {
    calls.add('GET $path');
    return files[path];
  }

  @override
  Future<void> delete(String path) async {
    calls.add('DELETE $path');
    files.remove(path);
  }
}

const service = SyncService();

String doc(int millis, String extra) =>
    jsonEncode({'updatedAt': millis, 'value': extra});

void main() {
  group('compare 判定', () {
    test('云端没有这份文档就上传', () {
      expect(service.compare(doc(1, 'a'), null), SyncVerdict.upload);
    });

    test('内容相同判为一致，不产生任何传输', () {
      expect(service.compare(doc(1, 'a'), doc(1, 'a')), SyncVerdict.identical);
    });

    test('本地较新上传，云端较新下载', () {
      expect(service.compare(doc(200, 'new'), doc(100, 'old')), SyncVerdict.upload);
      expect(service.compare(doc(100, 'old'), doc(200, 'new')), SyncVerdict.download);
    });

    test('时间戳缺失判为 unknown，不覆盖任何一侧', () {
      expect(service.compare('{"a":1}', '{"a":2}'), SyncVerdict.unknown);
      expect(service.compare('not json', 'also not json'), SyncVerdict.unknown);
      expect(service.compare(doc(1, 'a'), 'garbage'), SyncVerdict.unknown);
    });
  });

  group('stampOf', () {
    test('认毫秒时间戳与 ISO 字符串', () {
      final millis = SyncService.stampOf('{"updatedAt": 1700000000000}');
      expect(millis?.millisecondsSinceEpoch, 1700000000000);
      final iso = SyncService.stampOf('{"updatedAt": "2024-01-02T03:04:05.000Z"}');
      expect(iso?.year, 2024);
      expect(iso?.month, 1);
      expect(iso?.day, 2);
      expect(iso?.hour, 3);
    });

    test('坏数据返回 null', () {
      expect(SyncService.stampOf(''), isNull);
      expect(SyncService.stampOf('{'), isNull);
      expect(SyncService.stampOf('[1,2]'), isNull);
      expect(SyncService.stampOf('{"updatedAt": null}'), isNull);
      expect(SyncService.stampOf('{"updatedAt": "not a date"}'), isNull);
    });
  });

  group('run 同步流程', () {
    test('本地新云端无，上传一份', () async {
      final backend = FakeBackend();
      final local = [SyncDocument(path: 'settings.json', payload: doc(5, 'a'))];
      final applied = <SyncDocument>[];

      final report = await service.run(
        backend: backend,
        local: local,
        apply: applied.add,
      );

      expect(report.uploaded, 1);
      expect(report.downloaded, 0);
      expect(applied, isEmpty);
      expect(backend.files['goodreader/settings.json'], doc(5, 'a'));
      expect(backend.calls.first, 'MKCOL goodreader');
    });

    test('云端较新时下载并回调 apply', () async {
      final backend = FakeBackend(files: {
        'goodreader/notes.json': doc(200, 'remote'),
      });
      final local = [SyncDocument(path: 'notes.json', payload: doc(100, 'local'))];
      final applied = <SyncDocument>[];

      final report = await service.run(
        backend: backend,
        local: local,
        apply: applied.add,
      );

      expect(report.uploaded, 0);
      expect(report.downloaded, 1);
      expect(applied.length, 1);
      expect(applied.single.path, 'notes.json');
      // 调用方拿到的就是采纳后的那份。
      expect(applied.single.payload, doc(200, 'remote'));
      // 没有被反向推上去。
      expect(backend.files['goodreader/notes.json'], doc(200, 'remote'));
    });

    test('两端都改过同一条计入冲突', () async {
      final backend = FakeBackend(files: {
        'goodreader/a.json': doc(200, 'remote'),
      });
      final report = await service.run(
        backend: backend,
        local: [SyncDocument(path: 'a.json', payload: doc(100, 'local'))],
        apply: (_) {},
      );
      expect(report.conflicts, 1);
    });

    test('内容一致不计冲突也不传输', () async {
      final backend = FakeBackend(files: {'goodreader/a.json': doc(1, 'same')});
      final report = await service.run(
        backend: backend,
        local: [SyncDocument(path: 'a.json', payload: doc(1, 'same'))],
        apply: (_) {},
      );
      expect(report.conflicts, 0);
      expect(report.uploaded, 0);
      expect(report.downloaded, 0);
      expect(report.isEmpty, isTrue);
    });

    test('时间戳读不出来时两边都不动', () async {
      final backend = FakeBackend(files: {'goodreader/a.json': '{"v":1}'});
      final local = [SyncDocument(path: 'a.json', payload: '{"v":2}')];
      final applied = <SyncDocument>[];

      final report = await service.run(
        backend: backend,
        local: local,
        apply: applied.add,
      );

      expect(report.uploaded, 0);
      expect(report.downloaded, 0);
      expect(applied, isEmpty);
      expect(backend.files['goodreader/a.json'], '{"v":1}');
    });

    test('云端多出来的文档被下载', () async {
      final backend = FakeBackend(files: {
        'goodreader/stats.json': doc(9, 's'),
      });
      final applied = <SyncDocument>[];
      final report = await service.run(
        backend: backend,
        local: const [],
        apply: applied.add,
      );
      expect(report.downloaded, 1);
      expect(applied.single.path, 'stats.json');
    });

    test('目录固定带前缀，不会把丛书根目录的文件当成自己的', () async {
      final backend = FakeBackend(files: {
        'goodreader/a.json': doc(9, 's'),
        'other/b.json': doc(9, 's'),
      });
      final applied = <SyncDocument>[];
      await service.run(backend: backend, local: const [], apply: applied.add);
      expect(applied.map((d) => d.path), ['a.json']);
    });

    test('后端异常直接冒出去，由界面提示', () async {
      final backend = _BrokenBackend();
      await expectLater(
        service.run(
          backend: backend,
          local: [SyncDocument(path: 'a.json', payload: doc(1, 'a'))],
          apply: (_) {},
        ),
        throwsA(isA<SyncException>()),
      );
    });
  });

  group('document 构造', () {
    test('自动带 updatedAt 且可解析', () {
      final d = SyncService.document('x.json', {'value': 1});
      expect(SyncService.stampOf(d.payload), isNotNull);
      expect(jsonDecode(d.payload)['value'], 1);
    });

    test('非 Map 入参也能构造', () {
      final d = SyncService.document('x.json', 'plain');
      expect(SyncService.stampOf(d.payload), isNotNull);
    });
  });
}

class _BrokenBackend extends SyncBackend {
  @override
  Future<void> ensureDirectory(String path) async =>
      throw const SyncException('目录不可写');

  @override
  Future<List<RemoteEntry>> list(String path) async => const [];

  @override
  Future<void> put(String path, String content) async {}

  @override
  Future<String?> get(String path) async => null;

  @override
  Future<void> delete(String path) async {}
}
