import 'dart:typed_data';

import 'package:flutter/services.dart';

/// Screen brightness, media volume, keep-screen-on and battery state, backed by
/// the `goodreader/native` channel implemented in `MainActivity.kt`.
class NativeService {
  const NativeService();

  static const MethodChannel _channel = MethodChannel('goodreader/native');

  /// Returns the effective screen brightness in `0..1`, or `null` when the
  /// platform has no opinion (desktop, tests).
  Future<double?> brightness() async {
    final value = await _invoke<double>('brightness.get');
    return value;
  }

  Future<void> setBrightness(double value) async {
    await _invoke<void>('brightness.set', {'value': value.clamp(0.01, 1.0)});
  }

  Future<void> resetBrightness() async {
    await _invoke<void>('brightness.reset');
  }

  Future<double?> volume() => _invoke<double>('volume.get');

  Future<void> setVolume(double value) async {
    await _invoke<void>('volume.set', {'value': value.clamp(0.0, 1.0)});
  }

  Future<void> keepScreenOn(bool enabled) async {
    await _invoke<void>('screen.keepOn', {'enabled': enabled});
  }

  /// Hands a downloaded APK to the system package installer.
  Future<bool> installApk(String path) async {
    final ok = await _invoke<bool>('install', {'path': path});
    return ok ?? false;
  }

  /// Opens an external URL in the user's browser.
  Future<bool> openUrl(String url) async {
    final ok = await _invoke<bool>('openUrl', {'url': url});
    return ok ?? false;
  }

  /// 把一张 PNG 交给系统分享面板。
  ///
  /// 字节直接过通道：先写文件再让 Dart 传路径的话，Dart 侧还要知道缓存目录，
  /// 而缓存目录和 FileProvider 的 `<cache-path>` 必须对上，对不上就是一个只在
  /// 真机上才暴露的失败。
  Future<bool> shareImage(Uint8List bytes, String name) async {
    final ok = await _invoke<bool>('image.share', {
      'bytes': bytes,
      'name': name,
    });
    return ok ?? false;
  }

  /// 把一张 PNG 存到相册。返回可读的保存位置，失败返回 null。
  Future<String?> saveImage(Uint8List bytes, String name) =>
      _invoke<String>('image.save', {
        'bytes': bytes,
        'name': name,
      });

  Future<BatteryState?> battery() async {
    try {
      final raw = await _channel.invokeMethod<Map<dynamic, dynamic>>('battery');
      if (raw == null) return null;
      return BatteryState(
        level: (raw['level'] as num?)?.toInt() ?? 0,
        charging: raw['charging'] as bool? ?? false,
      );
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  Future<T?> _invoke<T>(String method, [Map<String, dynamic>? args]) async {
    try {
      return await _channel.invokeMethod<T>(method, args);
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }
}

class BatteryState {
  const BatteryState({required this.level, required this.charging});

  final int level;
  final bool charging;
}
