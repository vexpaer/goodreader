import 'dart:async';

import 'package:flutter_tts/flutter_tts.dart';

/// Wraps the platform TTS engine with a chapter queue so listening can continue
/// across chapter boundaries.
class TtsService {
  TtsService() {
    _tts.setCompletionHandler(() => _onCompleted?.call());
    _tts.setCancelHandler(() => _onCancelled?.call());
    _tts.setErrorHandler((msg) => _onError?.call(msg));
    _tts.setProgressHandler((text, start, end, word) {
      _onProgress?.call(text, start, end, word);
    });
  }

  final FlutterTts _tts = FlutterTts();

  void Function()? _onCompleted;
  void Function()? _onCancelled;
  void Function(String)? _onError;
  void Function(String, int, int, String)? _onProgress;

  set onCompleted(void Function()? cb) => _onCompleted = cb;
  set onCancelled(void Function()? cb) => _onCancelled = cb;
  set onError(void Function(String)? cb) => _onError = cb;
  set onProgress(void Function(String, int, int, String)? cb) => _onProgress = cb;

  bool _speaking = false;
  bool get isSpeaking => _speaking;

  Future<void> configure({
    double rate = 0.5,
    double pitch = 1.0,
    String language = 'zh-CN',
  }) async {
    await _tts.setSpeechRate(rate);
    await _tts.setPitch(pitch);
    await _tts.setVolume(1.0);
    await _tts.awaitSpeakCompletion(false);
    try {
      await _tts.setLanguage(language);
    } catch (_) {
      // Device may not carry the requested voice; keep the default.
    }
  }

  Future<List<String>> languages() async {
    try {
      final result = await _tts.getLanguages;
      if (result is List) return result.cast<String>();
    } catch (_) {}
    return const [];
  }

  Future<void> speak(String text) async {
    if (text.trim().isEmpty) return;
    _speaking = true;
    await _tts.speak(text);
  }

  Future<void> pause() async {
    await _tts.pause();
    _speaking = false;
  }

  Future<void> stop() async {
    await _tts.stop();
    _speaking = false;
  }

  void dispose() {
    _tts.stop();
  }
}
