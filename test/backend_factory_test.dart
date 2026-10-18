import 'package:flutter_test/flutter_test.dart';
import 'package:goodreader/data/models/service_endpoint.dart';
import 'package:goodreader/services/sync/backend_factory.dart';
import 'package:goodreader/services/sync/s3_backend.dart';
import 'package:goodreader/services/sync/sync_backend.dart';
import 'package:goodreader/services/sync/webdav_backend.dart';

ServiceEndpoint endpoint({
  String baseUrl = 'https://dav.example.com/dav',
  String model = '',
}) =>
    ServiceEndpoint(
      id: 'ep-1',
      kind: ServiceKind.sync,
      label: '我的网盘',
      baseUrl: baseUrl,
      model: model,
    );

void main() {
  group('凭据拆分', () {
    test('一个冒号时前半段是账号', () {
      final parsed = SyncCredentials.parse('alice:s3cret');
      expect(parsed.user, 'alice');
      expect(parsed.secret, 's3cret');
    });

    test('没有冒号时整串是密钥，账号留空', () {
      final parsed = SyncCredentials.parse('just-a-token');
      expect(parsed.user, '');
      expect(parsed.secret, 'just-a-token');
    });

    test('密码里带冒号时只按第一个冒号切', () {
      final parsed = SyncCredentials.parse('alice:a:b:c');
      expect(parsed.user, 'alice');
      expect(parsed.secret, 'a:b:c');
    });

    test('空串两边都空', () {
      final parsed = SyncCredentials.parse('');
      expect(parsed.user, '');
      expect(parsed.secret, '');
    });
  });

  group('后端选择', () {
    test('model 为空走 WebDAV', () {
      final backend = buildSyncBackend(endpoint(), secret: 'u:p');
      expect(backend, isA<WebDavBackend>());
    });

    test('model 是 s3 时走 S3，大小写与空格不影响', () {
      expect(
        buildSyncBackend(endpoint(model: 's3'), secret: 'k:s'),
        isA<S3Backend>(),
      );
      expect(
        buildSyncBackend(endpoint(model: ' S3 '), secret: 'k:s'),
        isA<S3Backend>(),
      );
    });

    test('S3 的账号密码拆成 Access Key 与 Secret', () {
      final backend = buildSyncBackend(
        endpoint(baseUrl: 'https://s3.eu-west-1.amazonaws.com/bucket', model: 's3'),
        secret: 'AKIA:shh',
      ) as S3Backend;
      expect(backend.accessKey, 'AKIA');
      expect(backend.secretKey, 'shh');
      expect(backend.region, 'eu-west-1');
    });

    test('WebDAV 的账号密码拆成用户名与密码', () {
      final backend =
          buildSyncBackend(endpoint(), secret: 'alice:pw') as WebDavBackend;
      expect(backend.username, 'alice');
      expect(backend.password, 'pw');
      expect(backend.baseUrl, 'https://dav.example.com/dav');
    });
  });

  group('配置不全', () {
    test('没填地址', () {
      expect(
        () => buildSyncBackend(endpoint(baseUrl: ''), secret: 'u:p'),
        throwsA(isA<SyncException>()),
      );
    });

    test('没填密钥', () {
      expect(
        () => buildSyncBackend(endpoint(), secret: ''),
        throwsA(isA<SyncException>()),
      );
    });
  });
}
