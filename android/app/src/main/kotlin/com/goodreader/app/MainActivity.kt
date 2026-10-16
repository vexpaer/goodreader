package com.goodreader.app

import android.content.Intent
import android.content.IntentFilter
import android.media.AudioManager
import android.net.Uri
import android.os.BatteryManager
import android.speech.tts.TextToSpeech
import android.speech.tts.UtteranceProgressListener
import android.view.WindowManager
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.Locale
import java.util.UUID

/**
 * Hosts the platform integrations the reader needs: text-to-speech, screen
 * brightness, media volume and battery state.
 *
 * These live in the app rather than in plugins so the build is never pinned to
 * a third party's Gradle and Kotlin requirements.
 */
class MainActivity : FlutterActivity() {

    private var tts: TextToSpeech? = null
    private var ttsReady = false
    private var pendingSpeech: String? = null
    private lateinit var ttsChannel: MethodChannel
    private lateinit var nativeChannel: MethodChannel

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger

        ttsChannel = MethodChannel(messenger, TTS_CHANNEL)
        ttsChannel.setMethodCallHandler { call, result -> handleTts(call, result) }

        nativeChannel = MethodChannel(messenger, NATIVE_CHANNEL)
        nativeChannel.setMethodCallHandler { call, result -> handleNative(call, result) }

        createEngine()
    }

    // ---------------------------------------------------------------------
    // Text to speech
    // ---------------------------------------------------------------------

    private fun createEngine() {
        if (tts != null) return
        tts = TextToSpeech(applicationContext) { status ->
            ttsReady = status == TextToSpeech.SUCCESS
            if (ttsReady) {
                attachProgressListener()
                val queued = pendingSpeech
                pendingSpeech = null
                if (queued != null) speakNow(queued)
            } else {
                emit(ttsChannel, "onError", "TTS 引擎初始化失败")
            }
        }
    }

    private fun attachProgressListener() {
        tts?.setOnUtteranceProgressListener(object : UtteranceProgressListener() {
            override fun onStart(utteranceId: String?) = Unit

            override fun onDone(utteranceId: String?) = emit(ttsChannel, "onComplete", null)

            @Deprecated("Superseded by onError(String, Int)")
            override fun onError(utteranceId: String?) = emit(ttsChannel, "onError", "朗读失败")

            override fun onError(utteranceId: String?, errorCode: Int) =
                emit(ttsChannel, "onError", "朗读失败（$errorCode）")

            override fun onRangeStart(
                utteranceId: String?,
                start: Int,
                end: Int,
                frame: Int,
            ) = emit(ttsChannel, "onProgress", mapOf("start" to start, "end" to end))
        })
    }

    private fun handleTts(call: MethodCall, result: MethodChannel.Result) {
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
                    if (availability != null && availability >= TextToSpeech.LANG_AVAILABLE) {
                        tts?.language = locale
                    }
                }
                result.success(true)
            }

            "speak" -> {
                val text = call.argument<String>("text").orEmpty()
                when {
                    text.isBlank() -> result.success(false)
                    !ttsReady -> {
                        pendingSpeech = text
                        createEngine()
                        result.success(true)
                    }
                    else -> {
                        speakNow(text)
                        result.success(true)
                    }
                }
            }

            "stop" -> {
                pendingSpeech = null
                tts?.stop()
                emit(ttsChannel, "onCancelled", null)
                result.success(true)
            }

            "languages" -> result.success(
                tts?.availableLanguages?.map { it.toLanguageTag() } ?: emptyList<String>()
            )

            else -> result.notImplemented()
        }
    }

    private fun speakNow(text: String) {
        tts?.speak(text, TextToSpeech.QUEUE_FLUSH, null, UUID.randomUUID().toString())
    }

    // ---------------------------------------------------------------------
    // Brightness, volume, keep-screen-on, battery
    // ---------------------------------------------------------------------

    private fun audio(): AudioManager =
        getSystemService(AUDIO_SERVICE) as AudioManager

    private fun handleNative(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "brightness.get" -> result.success(currentBrightness().toDouble())

            "brightness.set" -> {
                val value = (call.argument<Double>("value") ?: 0.5).toFloat()
                val attributes = window.attributes
                attributes.screenBrightness = value.coerceIn(0.01f, 1f)
                window.attributes = attributes
                result.success(true)
            }

            "brightness.reset" -> {
                val attributes = window.attributes
                attributes.screenBrightness = WindowManager.LayoutParams.BRIGHTNESS_OVERRIDE_NONE
                window.attributes = attributes
                result.success(true)
            }

            "volume.get" -> {
                val manager = audio()
                val max = manager.getStreamMaxVolume(AudioManager.STREAM_MUSIC)
                val current = manager.getStreamVolume(AudioManager.STREAM_MUSIC)
                result.success(if (max == 0) 0.0 else current.toDouble() / max)
            }

            "volume.set" -> {
                val value = (call.argument<Double>("value") ?: 0.5).coerceIn(0.0, 1.0)
                val manager = audio()
                val max = manager.getStreamMaxVolume(AudioManager.STREAM_MUSIC)
                manager.setStreamVolume(
                    AudioManager.STREAM_MUSIC,
                    Math.round(value * max).toInt(),
                    0,
                )
                result.success(value)
            }

            "screen.keepOn" -> {
                val enabled = call.argument<Boolean>("enabled") ?: true
                if (enabled) {
                    window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                } else {
                    window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                }
                result.success(true)
            }

            "battery" -> result.success(batteryState())

            "install" -> {
                val path = call.argument<String>("path")
                if (path.isNullOrBlank()) {
                    result.success(false)
                } else {
                    result.success(installApk(path))
                }
            }

            "openUrl" -> {
                val url = call.argument<String>("url")
                result.success(if (url.isNullOrBlank()) false else openUrl(url))
            }

            else -> result.notImplemented()
        }
    }

    /** Hands an APK to the system package installer through a content URI. */
    private fun installApk(path: String): Boolean = try {
        val file = File(path)
        if (!file.exists()) {
            false
        } else {
            val uri = FileProvider.getUriForFile(
                this,
                "$packageName.fileprovider",
                file,
            )
            val intent = Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(uri, "application/vnd.android.package-archive")
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            startActivity(intent)
            true
        }
    } catch (_: Exception) {
        false
    }

    private fun openUrl(url: String): Boolean = try {
        startActivity(
            Intent(Intent.ACTION_VIEW, Uri.parse(url))
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
        )
        true
    } catch (_: Exception) {
        false
    }

    private fun currentBrightness(): Float {
        val attributes = window.attributes
        if (attributes.screenBrightness >= 0f) return attributes.screenBrightness
        return try {
            android.provider.Settings.System.getInt(
                contentResolver,
                android.provider.Settings.System.SCREEN_BRIGHTNESS,
            ) / 255f
        } catch (_: Exception) {
            0.5f
        }
    }

    private fun batteryState(): Map<String, Any> {
        val intent: Intent? = registerReceiver(
            null,
            IntentFilter(Intent.ACTION_BATTERY_CHANGED),
        )
        val level = intent?.getIntExtra(BatteryManager.EXTRA_LEVEL, -1) ?: -1
        val scale = intent?.getIntExtra(BatteryManager.EXTRA_SCALE, -1) ?: -1
        val status = intent?.getIntExtra(BatteryManager.EXTRA_STATUS, -1) ?: -1
        val charging = status == BatteryManager.BATTERY_STATUS_CHARGING ||
            status == BatteryManager.BATTERY_STATUS_FULL
        val percent = if (level >= 0 && scale > 0) level * 100 / scale else 0
        return mapOf("level" to percent, "charging" to charging)
    }

    // ---------------------------------------------------------------------

    private fun emit(channel: MethodChannel, method: String, payload: Any?) {
        runOnUiThread {
            if (::ttsChannel.isInitialized) channel.invokeMethod(method, payload)
        }
    }

    override fun onDestroy() {
        tts?.stop()
        tts?.shutdown()
        tts = null
        super.onDestroy()
    }

    private companion object {
        const val TTS_CHANNEL = "goodreader/tts"
        const val NATIVE_CHANNEL = "goodreader/native"
    }
}
