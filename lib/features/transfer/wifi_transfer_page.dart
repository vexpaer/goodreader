import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../services/wifi_transfer_server.dart';
import '../../state/providers.dart';

/// 局域网传书。本机起一个 HTTP 服务，另一台设备用浏览器把文件传过来。
///
/// 服务只在本页存活期间运行，离开页面立刻关掉：一个常驻的上传端口在公共 Wi-Fi
/// 上是风险，而不是便利。
class WifiTransferPage extends ConsumerStatefulWidget {
  const WifiTransferPage({super.key});

  @override
  ConsumerState<WifiTransferPage> createState() => _WifiTransferPageState();
}

class _ReceivedItem {
  _ReceivedItem({required this.name, required this.size});

  final String name;
  final int size;
  String status = '正在入库';
  bool failed = false;
}

class _WifiTransferPageState extends ConsumerState<WifiTransferPage> {
  WifiTransferServer? _server;
  String _pin = '';
  String? _host;
  int _port = 0;
  String? _error;
  bool _starting = true;

  final _received = <_ReceivedItem>[];

  @override
  void initState() {
    super.initState();
    unawaited(_start());
  }

  @override
  void dispose() {
    unawaited(_server?.stop());
    _server = null;
    super.dispose();
  }

  Future<void> _start() async {
    try {
      final docs = await getApplicationDocumentsDirectory();
      final dir = Directory('${docs.path}/incoming');
      if (!dir.existsSync()) dir.createSync(recursive: true);

      final server = WifiTransferServer(
        pin: _generatePin(),
        directory: dir.path,
      );
      server.onFile = (file) => unawaited(_ingest(file));

      final port = await server.start();
      final host = await _localAddress();
      if (!mounted) {
        await server.stop();
        return;
      }
      setState(() {
        _server = server;
        _pin = server.pin;
        _port = port;
        _host = host;
        _starting = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _starting = false;
      });
    }
  }

  /// 入库成功后删掉收件目录里的副本。ImportService 会把文件复制进书库，
  /// 留一份只会白占空间，而且下次同名上传会撞上。
  Future<void> _ingest(ReceivedFile file) async {
    final item = _ReceivedItem(name: file.name, size: file.size);
    if (mounted) setState(() => _received.insert(0, item));

    try {
      final book = await ref.read(importServiceProvider).importFile(file.path);
      if (mounted) {
        setState(() {
          item.status = '已入库：${book.title}';
        });
      }
      final copy = File(file.path);
      if (copy.existsSync()) {
        try {
          await copy.delete();
        } catch (_) {
          // 删不掉不影响入库结果，下次启动会被覆盖。
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          item.status = '入库失败：$e';
          item.failed = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Wi-Fi 传书')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          if (_starting)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            _ErrorCard(message: _error!)
          else ...[
            _AddressCard(
              host: _host,
              port: _port,
              pin: _pin,
            ),
            const SizedBox(height: 20),
            Text('收到 ${_received.length} 个文件', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            if (_received.isEmpty)
              Text(
                '还没有收到文件。用同一 Wi-Fi 下的手机或电脑打开上面的地址即可。',
                style: theme.textTheme.bodySmall,
              )
            else
              for (final item in _received)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    item.failed ? Icons.error_outline : Icons.book_outlined,
                    color: item.failed ? theme.colorScheme.error : null,
                  ),
                  title: Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text('${_humanSize(item.size)} · ${item.status}'),
                ),
            const SizedBox(height: 16),
            Text(
              '上传端口只在本页打开期间监听，离开页面就会关闭。'
              '收到的文件会直接入库，收件目录里的副本随即删除。',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ],
        ],
      ),
    );
  }

  static String _generatePin() =>
      (Random.secure().nextInt(900000) + 100000).toString();

  static Future<String?> _localAddress() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
      );
      for (final interface in interfaces) {
        for (final address in interface.addresses) {
          if (address.isLoopback) continue;
          return address.address;
        }
      }
    } catch (_) {
      // 拿不到网卡列表时退回本机回环，至少能自测。
    }
    return null;
  }

  static String _humanSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

class _AddressCard extends StatelessWidget {
  const _AddressCard({required this.host, required this.port, required this.pin});

  final String? host;
  final int port;
  final String pin;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final url = host == null ? null : 'http://$host:$port';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('在浏览器里打开', style: theme.textTheme.titleSmall),
          const SizedBox(height: 10),
          if (url == null)
            Text('没能读到本机 IP。确认已连接 Wi-Fi。',
                style: theme.textTheme.bodyMedium)
          else
            Row(
              children: [
                Expanded(
                  child: SelectableText(
                    url,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
                IconButton(
                  tooltip: '复制地址',
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: url));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('地址已复制')),
                      );
                    }
                  },
                  icon: const Icon(Icons.copy_outlined),
                ),
              ],
            ),
          const SizedBox(height: 18),
          Text('连接码', style: theme.textTheme.titleSmall),
          const SizedBox(height: 6),
          Text(
            pin,
            style: theme.textTheme.headlineMedium?.copyWith(
              letterSpacing: 8,
              fontWeight: FontWeight.w600,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '网页上要填这个六位数才能上传，防止同一网络里的其他人往书架塞东西。',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.error.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('服务没能启动', style: theme.textTheme.titleSmall),
          const SizedBox(height: 6),
          Text(message, style: theme.textTheme.bodySmall),
          const SizedBox(height: 8),
          Text(
            '常见原因：没有连接 Wi-Fi，或者系统不允许应用监听端口。',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }
}
