package com.rahala.geography

import android.media.AudioManager
import android.media.ToneGenerator
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var tone: ToneGenerator? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.rahala.geography/feedback")
            .setMethodCallHandler { call, result ->
                if (call.method != "answer") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }

                try {
                    val player = tone ?: ToneGenerator(AudioManager.STREAM_MUSIC, 32).also {
                        tone = it
                    }
                    val correct = call.arguments == true
                    player.startTone(
                        if (correct) ToneGenerator.TONE_PROP_ACK else ToneGenerator.TONE_PROP_BEEP,
                        if (correct) 135 else 70,
                    )
                } catch (_: RuntimeException) {
                    // A device without an available audio output can still play.
                }
                result.success(null)
            }
    }

    override fun onDestroy() {
        tone?.release()
        tone = null
        super.onDestroy()
    }
}
