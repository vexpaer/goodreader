package com.goodreader.app

import android.speech.tts.TextToSpeech
import android.speech.tts.UtteranceProgressListener
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.Locale
import java.util.UUID

/**
 * Hosts the platform text-to-speech engine behind the `goodreader/tts` channel.
 *
 * Keeping this in the app avoids depending on a plugin whose Gradle and Kotlin
 * requirements would otherwise constrain the whole build.
 */
class MainActivity : FlutterActivity() {

    private var tts: TextToSpeech? = null
    private var ready = false
    private var pendingText: String? = null
    private lateinit var channel: MethodChannel

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        channel.setMethodCallHandler { call, result -> handle(call, result) }
        createEngine()
    }

    private fun createEngine() {
        if (tts != null) return
        tts = TextToSpeech(applicationContext) { status ->
            ready = status == TextToSpeech.SUCCESS
            if (ready) {
                attachProgressListener()
                val queued = pendingText
                pendingText = null
                if (queued != null) speakNow(queued)
            } else {
                emit("onError", "TTS 引擎初始化失败")
            }
        }
    }

    private fun attachProgressListener() {
        tts?.setOnUtteranceProgressListener(object : UtteranceProgressListener() {
            override fun onStart(utteranceId: String?) = Unit

            override fun onDone(utteranceId: String?) {
                emit("onComplete", null)
            }

            @Deprecated("Superseded by onError(String, Int)")
            override fun onError(utteranceId: String?) {
                emit("onError", "朗读失败")
            }

            override fun onError(utteranceId: String?, errorCode: Int) {
                emit("onError", "朗读失败（$errorCode）")
            }

            override fun onRangeStart(
                utteranceId: String?,
                start: Int,
                end: Int,
                frame: Int,
            ) {
                emit("onProgress", mapOf("start" to start, "end" to end))
            }
        })
    }

    private fun handle(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "init" -> {
                createEngine()
                result.success(true)
            }

            "configure" -> {
                val rate = call.argument<Double>("rate")?.toFloat() ?: 0.5f
                val pitch = call.argument<Double>("pitch")?.toFloat() ?: 1.0f
                val language = call.argument<String>("language")
                tts?.setSpeechRate(rate)
                tts?.setPitch(pitch)
                if (!language.isNullOrBlank()) {
                    val locale = Locale.forLanguageTag(language)
                    val availability = tts?.isLanguageAvailable(locale)
                    if (availability != null &&
                        availability >= TextToSpeech.LANG_AVAILABLE
                    ) {
                        tts?.language = locale
                    }
                }
                result.success(true)
            }

            "speak" -> {
                val text = call.argument<String>("text").orEmpty()
                if (text.isBlank()) {
                    result.success(false)
                } else if (!ready) {
                    pendingText = text
                    createEngine()
                    result.success(true)
                } else {
                    speakNow(text)
                    result.success(true)
                }
            }

            "stop" -> {
                pendingText = null
                tts?.stop()
                emit("onCancelled", null)
                result.success(true)
            }

            "languages" -> {
                val locales = tts?.availableLanguages?.map { it.toLanguageTag() }
                result.success(locales ?: emptyList<String>())
            }

            else -> result.notImplemented()
        }
    }

    private fun speakNow(text: String) {
        val utteranceId = UUID.randomUUID().toString()
        tts?.speak(text, TextToSpeech.QUEUE_FLUSH, null, utteranceId)
    }

    private fun emit(method: String, payload: Any?) {
        runOnUiThread {
            if (::channel.isInitialized) {
                channel.invokeMethod(method, payload)
            }
        }
    }

    override fun onDestroy() {
        tts?.stop()
        tts?.shutdown()
        tts = null
        super.onDestroy()
    }

    private companion object {
        const val CHANNEL = "goodreader/tts"
    }
}
