import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// 一次收到的文件。
class ReceivedFile {
  const ReceivedFile({required this.name, required this.path, required this.size});

  final String name;

  /// 落盘后的完整路径。
  final String path;
  final int size;
}

class WifiTransferException implements Exception {
  const WifiTransferException(this.message);

  final String message;

  @override
  String toString() => 'WifiTransferException: $message';
}

/// 局域网传书服务：本机起 HTTP 服务，另一台设备用浏览器上传文件。
///
/// 上传接口收**原始字节**，文件名走查询参数，不做 multipart 解析。
/// multipart 的解码器要写两百行还要处理各种边界，而客户端是我们自己的页面，
/// 用 fetch 就能发原始字节。少一套解析就少一处能出错的地方。
class WifiTransferServer {
  WifiTransferServer({
    required this.pin,
    required this.directory,
    this.maxFileBytes = 200 * 1024 * 1024,
  });

  /// 六位数字，页面和服务端都要带。
  final String pin;

  /// 文件落盘目录。
  final String directory;

  final int maxFileBytes;

  HttpServer? _server;

  bool get isRunning => _server != null;

  int get port => _server?.port ?? 0;

  String get address => _server?.address.address ?? '';

  /// 每收到一个文件的回调。只有入库成功的文件才会回调。
  void Function(ReceivedFile file)? onFile;

  /// 启动服务并返回监听端口。端口 0 让系统分配。
  ///
  /// [address] 可注入，测试绑 loopback，真机绑 anyIPv4。
  Future<int> start({InternetAddress? address}) async {
    if (_server != null) return port;
    final server = await HttpServer.bind(address ?? InternetAddress.anyIPv4, 0);
    _server = server;
    unawaited(_serve(server));
    return server.port;
  }

  Future<void> _serve(HttpServer server) async {
    await for (final request in server) {
      try {
        await _handle(request);
      } on WifiTransferException catch (e) {
        _json(request.response, 400, {'error': e.message});
      } catch (_) {
        _json(request.response, 500, const {'error': '服务端异常'});
      }
    }
  }

  Future<void> _handle(HttpRequest request) async {
    final path = request.uri.path;
    if (request.method == 'GET' && (path == '/' || path == '/index.html')) {
      _html(request.response);
      return;
    }
    if (request.method == 'GET' && path == '/info') {
      _json(request.response, 200, {
        'name': 'GoodReader',
        'pinRequired': true,
        'maxFileBytes': maxFileBytes,
      });
      return;
    }
    if (request.method == 'POST' && path == '/upload') {
      await _upload(request);
      return;
    }
    _json(request.response, 404, const {'error': 'not found'});
  }

  Future<void> _upload(HttpRequest request) async {
    if (request.uri.queryParameters['pin'] != pin) {
      throw const WifiTransferException('连接码不对');
    }
    final name = request.uri.queryParameters['name'];
    if (name == null || name.trim().isEmpty) {
      throw const WifiTransferException('缺少文件名');
    }
    final safeName = sanitizeFileName(name);
    if (safeName.isEmpty) {
      throw const WifiTransferException('文件名不可用');
    }

    final chunks = <int>[];
    var total = 0;
    await for (final chunk in request) {
      total += chunk.length;
      if (total > maxFileBytes) {
        throw WifiTransferException('文件超过 ${maxFileBytes ~/ (1024 * 1024)} MB 上限');
      }
      chunks.addAll(chunk);
    }
    if (chunks.isEmpty) throw const WifiTransferException('文件是空的');

    final dir = Directory(directory);
    if (!dir.existsSync()) dir.createSync(recursive: true);

    final target = File('$directory/$safeName');
    // 同名文件覆盖写。传书的语义就是「我要这份文件在这里」。
    await target.writeAsBytes(chunks, flush: true);

    onFile?.call(ReceivedFile(
      name: safeName,
      path: target.path,
      size: total,
    ));
    _json(request.response, 200, {'ok': true, 'name': safeName, 'size': total});
  }

  Future<void> stop() async {
    final server = _server;
    _server = null;
    await server?.close(force: true);
  }

  static void _json(HttpResponse response, int status, Map<String, dynamic> body) {
    response.statusCode = status;
    response.headers.contentType = ContentType.json;
    response.write(jsonEncode(body));
    response.close();
  }

  static void _html(HttpResponse response) {
    response.statusCode = 200;
    response.headers.contentType = ContentType.html;
    response.write(_page);
    response.close();
  }

  /// 去掉路径分隔符与控制字符，只留文件名。
  ///
  /// 这是安全边界：上传接口暴露在局域网上，`../../foo` 必须被挡掉。
  /// 路径分隔符换成下划线，其余控制字符（含 NUL）直接移除。
  static String sanitizeFileName(String raw) {
    final replaced = raw
        .replaceAll(RegExp(r'[\\/]'), '_')
        .replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '')
        .trim();
    if (replaced.isEmpty || replaced == '.' || replaced == '..') return '';
    return replaced.length > 120 ? replaced.substring(replaced.length - 120) : replaced;
  }
}

const _page = r'''<!DOCTYPE html>
<html lang="zh-CN">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>GoodReader 传书</title>
<style>
body{font-family:system-ui,sans-serif;margin:0;padding:24px;background:#faf9f7;color:#1c1b1a}
main{max-width:420px;margin:0 auto}
h1{font-size:20px;margin:0 0 4px}
p.sub{color:#6b6a68;font-size:13px;margin:0 0 20px}
.card{background:#fff;border:1px solid #e4e2de;border-radius:14px;padding:18px;margin-bottom:14px}
label{display:block;font-size:13px;color:#6b6a68;margin-bottom:6px}
input{width:100%;box-sizing:border-box;padding:11px 12px;font-size:15px;border:1px solid #d9d6d1;border-radius:9px;margin-bottom:14px}
button{width:100%;padding:13px;font-size:15px;border:0;border-radius:10px;background:#1f6feb;color:#fff}
button:disabled{background:#b9c6da}
.hint{font-size:12px;color:#8a8884;margin-top:10px;line-height:1.5}
.ok{color:#1a7f37;font-size:13px;margin-top:10px}
.err{color:#c0392b;font-size:13px;margin-top:10px}
</style>
</head>
<body>
<main>
<h1>传到 GoodReader</h1>
<p class="sub">选好文件后点上传。书籍会直接进入这台设备的书架。</p>
<div class="card">
<label for="pin">连接码</label>
<input id="pin" inputmode="numeric" pattern="[0-9]*" maxlength="6" placeholder="六位数字">
<label for="file">书籍文件</label>
<input id="file" type="file" accept=".txt,.epub,.pdf,.mobi,.azw,.azw3,.cbz,.cbr">
<button id="go" disabled>上传</button>
<div id="msg"></div>
<p class="hint">支持 TXT / EPUB / PDF / MOBI / AZW / AZW3 / CBZ / CBR。</p>
</div>
</main>
<script>
var pin = document.getElementById('pin');
var file = document.getElementById('file');
var go = document.getElementById('go');
var msg = document.getElementById('msg');
function refresh(){ go.disabled = !(pin.value.length === 6 && file.files.length); }
pin.oninput = refresh; file.onchange = refresh;
go.onclick = function(){
  var f = file.files[0];
  if(!f) return;
  go.disabled = true;
  msg.className = 'hint'; msg.textContent = '正在上传 ' + f.name + ' …';
  fetch('/upload?pin=' + encodeURIComponent(pin.value) + '&name=' + encodeURIComponent(f.name), {
    method: 'POST', body: f
  }).then(function(r){ return r.json(); }).then(function(j){
    if(j.ok){ msg.className = 'ok'; msg.textContent = f.name + ' 上传完成，去书架看看。'; }
    else { msg.className = 'err'; msg.textContent = j.error || '上传失败'; go.disabled = false; }
  }).catch(function(){
    msg.className = 'err'; msg.textContent = '网络错误，请重试'; go.disabled = false;
  });
};
</script>
</body>
</html>''';
