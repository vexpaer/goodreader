import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:goodreader/services/http_transport.dart';

/// 识别失败。界面直接显示 [message]。
class OcrException implements Exception {
  const OcrException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// 把图片交给用户自己配的识别服务，拿回文字。
///
/// 接口约定只有一条：POST 一段 JSON `{"image": base64, "language": ...}`，
/// 回一段 JSON，文字放在 `text`、`result` 或 `words_result` 里。这三种形状覆盖了
/// 自建服务和常见云服务把结果直接转发出来的情况，其余的需要用户自己加一层转发。
///
/// 不在端上跑模型：那要带几十兆的原生库和模型文件，而用户往往已经有自己的识别
/// 服务。端上后端留给后续，接口是同一个 [recognize]。
class OcrService {
  OcrService({
    required this.baseUrl,
    this.apiKey = '',
    this.language = 'chi_sim',
    HttpTransport? transport,
  }) : _transport = transport ?? const IoHttpTransport();

  final String baseUrl;
  final String apiKey;
  final String language;
  final HttpTransport _transport;

  /// 超过这个边长的图片先缩一缩。识别服务对超大图要么慢，要么直接 413。
  static const maxEdge = 1600;

  Future<String> recognize(Uint8List imageBytes) async {
    if (baseUrl.trim().isEmpty) {
      throw const OcrException('这个识别服务还没填地址');
    }

    final payload = {
      'image': base64Encode(imageBytes),
      'language': language,
    };

    final TransportResponse response;
    try {
      response = await _transport.post(
        Uri.parse(baseUrl),
        headers: {
          'content-type': 'application/json',
          if (apiKey.isNotEmpty) 'authorization': 'Bearer $apiKey',
        },
        body: jsonEncode(payload),
      );
    } on TransportException catch (e) {
      throw OcrException('连不上识别服务：${e.message}');
    }

    if (response.statusCode == 401 || response.statusCode == 403) {
      throw const OcrException('密钥被拒绝，检查服务设置里的密钥');
    }
    if (response.statusCode == 413) {
      throw const OcrException('图片太大，服务端拒绝接收');
    }
    if (response.statusCode == 429) {
      throw const OcrException('请求太频繁，稍后再试');
    }
    if (!response.isSuccess) {
      throw OcrException('识别失败，HTTP ${response.statusCode}');
    }

    final text = parseText(response.json);
    if (text == null) {
      throw const OcrException('服务返回的数据里找不到文字，检查接口格式');
    }
    if (text.trim().isEmpty) {
      throw const OcrException('没有识别出文字');
    }
    return text.trim();
  }

  /// 从响应里取文字。认三种形状：
  ///
  /// * `{"text": "..."}`
  /// * `{"result": "..."}`
  /// * `{"words_result": [{"words": "..."}, ...]}`
  ///
  /// 认不出返回 null，由调用方决定怎么报。
  static String? parseText(Map<String, dynamic>? json) {
    if (json == null) return null;

    final direct = json['text'] ?? json['result'];
    if (direct is String) return direct;

    final words = json['words_result'];
    if (words is List) {
      final lines = <String>[];
      for (final item in words) {
        if (item is String) {
          lines.add(item);
        } else if (item is Map && item['words'] is String) {
          lines.add(item['words'] as String);
        }
      }
      if (lines.isNotEmpty) return lines.join('\n');
    }

    return null;
  }

  /// 把长边压到 [maxEdge] 以内再发。
  ///
  /// 缩放在 Canvas 上做，不逐像素处理：识别服务在乎的是分辨率，不是色彩。
  /// 灰度化省下的那点体积换不来识别率的提升，不做。
  static Future<Uint8List> downscale(
    Uint8List bytes, {
    int edge = maxEdge,
  }) async {
    final ui.Codec codec;
    try {
      codec = await ui.instantiateImageCodec(bytes);
    } catch (_) {
      throw const OcrException('这张图打不开，换一张试试');
    }

    final frame = await codec.getNextFrame();
    final image = frame.image;
    final longest = math.max(image.width, image.height);
    if (longest <= edge) {
      image.dispose();
      return bytes;
    }

    final scale = edge / longest;
    final width = math.max(1, (image.width * scale).round());
    final height = math.max(1, (image.height * scale).round());

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    canvas.drawImageRect(
      image,
      ui.Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
      ui.Paint()..filterQuality = ui.FilterQuality.medium,
    );
    final picture = recorder.endRecording();
    final scaled = await picture.toImage(width, height);
    final data = await scaled.toByteData(format: ui.ImageByteFormat.png);

    image.dispose();
    picture.dispose();
    scaled.dispose();

    if (data == null) throw const OcrException('图片缩放失败');
    return data.buffer.asUint8List();
  }
}
