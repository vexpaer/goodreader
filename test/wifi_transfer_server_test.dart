import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:goodreader/services/wifi_transfer_server.dart';

void main() {
  late Directory temp;
  late WifiTransferServer server;
  late int port;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('goodreader-wifi');
    server = WifiTransferServer(pin: '123456', directory: temp.path);
    port = await server.start(address: InternetAddress.loopbackIPv4);
  });

  tearDown(() async {
    await server.stop();
    if (temp.existsSync()) await temp.delete(recursive: true);
  });

  String url(String path) => 'http://127.0.0.1:$port$path';

  group('启动与停止', () {
    test('绑到 loopback 并分到非零端口', () {
      expect(port, greaterThan(0));
      expect(server.isRunning, isTrue);
      expect(server.address, '127.0.0.1');
    });

    test('重复启动返回同一个端口，不会起两个服务', () async {
      final again = await server.start(address: InternetAddress.loopbackIPv4);
      expect(again, port);
    });

    test('停止后 isRunning 为 false', () async {
      await server.stop();
      expect(server.isRunning, isFalse);
      expect(server.port, 0);
    });
  });

  group('HTTP 面', () {
    test('根路径返回上传页面', () async {
      final client = HttpClient();
      final response = await client.getUrl(Uri.parse(url('/'))).then((r) => r.close());
      expect(response.statusCode, 200);
      final body = await response.transform(utf8.decoder).join();
      expect(body.contains('GoodReader'), isTrue);
      expect(body.contains('连接码'), isTrue);
      client.close(force: true);
    });

    test('/info 返回能力描述', () async {
      final client = HttpClient();
      final response =
          await client.getUrl(Uri.parse(url('/info'))).then((r) => r.close());
      final body = await response.transform(utf8.decoder).join();
      final json = jsonDecode(body) as Map<String, dynamic>;
      expect(json['name'], 'GoodReader');
      expect(json['pinRequired'], isTrue);
      client.close(force: true);
    });

    test('未知路径返回 404', () async {
      final client = HttpClient();
      final response =
          await client.getUrl(Uri.parse(url('/nope'))).then((r) => r.close());
      expect(response.statusCode, 404);
      client.close(force: true);
    });
  });

  group('上传', () {
    test('连接码正确时落盘并回调', () async {
      final received = <ReceivedFile>[];
      server.onFile = received.add;

      final client = HttpClient();
      final request = await client.postUrl(Uri.parse(
        url('/upload?pin=123456&name=${Uri.encodeQueryComponent('三体.txt')}'),
      ));
      // HttpClientRequest.write 只收 latin1，中文必须编码成字节再发。
      request.add(utf8.encode('第一段正文'));
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();

      expect(response.statusCode, 200);
      final json = jsonDecode(body) as Map<String, dynamic>;
      expect(json['ok'], isTrue);
      expect(json['name'], '三体.txt');

      final file = File('${temp.path}/三体.txt');
      expect(file.existsSync(), isTrue);
      expect(file.readAsStringSync(), '第一段正文');
      expect(received.length, 1);
      expect(received.single.size, '第一段正文'.length);
      client.close(force: true);
    });

    test('连接码不对时拒绝且不落盘', () async {
      final client = HttpClient();
      final request = await client.postUrl(
          Uri.parse(url('/upload?pin=000000&name=x.txt')));
      request.add(utf8.encode('secret'));
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      expect(response.statusCode, 400);
      expect(jsonDecode(body)['error'], '连接码不对');
      expect(File('${temp.path}/x.txt').existsSync(), isFalse);
      client.close(force: true);
    });

    test('空文件被拒绝', () async {
      final client = HttpClient();
      final request = await client.postUrl(
          Uri.parse(url('/upload?pin=123456&name=empty.txt')));
      final response = await request.close();
      expect(response.statusCode, 400);
      expect(jsonDecode(await response.transform(utf8.decoder).join())['error'],
          '文件是空的');
      client.close(force: true);
    });

    test('缺文件名被拒绝', () async {
      final client = HttpClient();
      final request =
          await client.postUrl(Uri.parse(url('/upload?pin=123456')));
      request.add(utf8.encode('data'));
      final response = await request.close();
      expect(response.statusCode, 400);
      client.close(force: true);
    });

    test('同名文件覆盖写', () async {
      final client = HttpClient();
      for (final content in ['旧内容', '新内容']) {
        final request = await client.postUrl(Uri.parse(
            url('/upload?pin=123456&name=${Uri.encodeQueryComponent('书.txt')}')));
        request.add(utf8.encode(content));
        await (await request.close()).drain<void>();
      }
      expect(File('${temp.path}/书.txt').readAsStringSync(), '新内容');
      client.close(force: true);
    });

    test('二进制内容原样落盘', () async {
      final bytes = Uint8List.fromList([0x00, 0xFF, 0x10, 0x7F, 0x80]);
      final client = HttpClient();
      final request = await client.postUrl(Uri.parse(
          url('/upload?pin=123456&name=${Uri.encodeQueryComponent('bin.dat')}')));
      request.add(bytes);
      await (await request.close()).drain<void>();
      expect(File('${temp.path}/bin.dat').readAsBytesSync(), bytes);
      client.close(force: true);
    });
  });

  group('sanitizeFileName 挡住路径穿越', () {
    test('正反斜杠与空字节被换成下划线', () {
      expect(WifiTransferServer.sanitizeFileName('../../etc/passwd'),
          '.._.._etc_passwd');
      expect(WifiTransferServer.sanitizeFileName(r'..\..\win'), '.._.._win');
      expect(WifiTransferServer.sanitizeFileName('a\u0000b'), 'ab');
    });

    test('控制字符被剥掉', () {
      expect(WifiTransferServer.sanitizeFileName('a\nb\tc'), 'abc');
      expect(WifiTransferServer.sanitizeFileName('a\u007Fb'), 'ab');
    });

    test('纯点与空名返回空串', () {
      expect(WifiTransferServer.sanitizeFileName('.'), '');
      expect(WifiTransferServer.sanitizeFileName('..'), '');
      expect(WifiTransferServer.sanitizeFileName('   '), '');
      expect(WifiTransferServer.sanitizeFileName(''), '');
    });

    test('超长名截到 120 字符，保留后缀部分', () {
      final long = 'a' * 200 + '.txt';
      final result = WifiTransferServer.sanitizeFileName(long);
      expect(result.length, 120);
      expect(result.endsWith('.txt'), isTrue);
    });

    test('正常文件名原样通过', () {
      expect(WifiTransferServer.sanitizeFileName('三体.epub'), '三体.epub');
      expect(WifiTransferServer.sanitizeFileName('My Book (2024).txt'),
          'My Book (2024).txt');
    });
  });
}
