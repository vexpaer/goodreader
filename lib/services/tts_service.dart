import 'package:flutter/services.dart';

/// Text-to-speech backed by the platform engine through a small method channel
/// implemented in `MainActivity.kt`.
///
/// Rolling our own channel keeps the app free of a plugin whose Gradle/Kotlin
/// requirements would otherwise pin the whole toolchain.
class TtsService {
  TtsService() {
    _channel.setMethodCallHandler(_handlePlatformCall);
  }

  static const MethodChannel _channel = MethodChannel('goodreader/tts');

  void Function()? _onCompleted;
  void Function()? _onCancelled;
  void Function(String)? _onError;
  void Function(int start, int end)? _onProgress;

  set onCompleted(void Function()? cb) => _onCompleted = cb;
  set onCancelled(void Function()? cb) => _onCancelled = cb;
  set onError(void Function(String)? cb) => _onError = cb;
  set onProgress(void Function(int start, int end)? cb) => _onProgress = cb;

  bool _speaking = false;
  bool get isSpeaking => _speaking;

  Future<dynamic> _handlePlatformCall(MethodCall call) async {
    switch (call.method) {
      case 'onComplete':
        _speaking = false;
        _onCompleted?.call();
      case 'onCancelled':
        _speaking = false;
        _onCancelled?.call();
      case 'onError':
        _speaking = false;
        _onError?.call(call.arguments?.toString() ?? 'TTS error');
      case 'onProgress':
        final args = call.arguments;
        if (args is Map) {
          final start = args['start'];
          final end = args['end'];
          if (start is int && end is int) _onProgress?.call(start, end);
        }
    }
    return null;
  }

  Future<void> init() => _invoke('init');

  Future<void> configure({
    double rate = 0.5,
    double pitch = 1.0,
    String language = 'zh-CN',
  }) =>
      _invoke('configure', {
        'rate': rate,
        'pitch': pitch,
        'language': language,
      });

  Future<List<String>> languages() async {
    try {
      final result = await _channel.invokeMethod<List<dynamic>>('languages');
      return result?.whereType<String>().toList() ?? const [];
    } on PlatformException {
      return const [];
    } on MissingPluginException {
      return const [];
    }
  }

  Future<void> speak(String text) async {
    if (text.trim().isEmpty) return;
    _speaking = true;
    await _invoke('speak', {'text': text});
  }

  /// The Android engine has no true pause; stopping is the closest behaviour.
  Future<void> pause() => stop();

  Future<void> stop() async {
    _speaking = false;
    await _invoke('stop');
  }

  Future<void> _invoke(String method, [Map<String, dynamic>? args]) async {
    try {
      await _channel.invokeMethod<dynamic>(method, args);
    } on MissingPluginException {
      // Running on a platform without the channel (tests, desktop).
    } on PlatformException {
      // Surface engine failures through the error callback instead of throwing.
      _onError?.call('TTS 引擎调用失败：$method');
    }
  }

  void dispose() {
    _channel.setMethodCallHandler(null);
    stop();
  }
}
