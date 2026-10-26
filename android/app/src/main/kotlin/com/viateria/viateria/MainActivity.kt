package com.viateria.viateria

import android.content.Intent
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "viateria/diploma_share",
        ).setMethodCallHandler { call, result ->
            val bytes = call.argument<ByteArray>("bytes")
            val appId = call.argument<String>("appId")
            if (bytes == null || appId.isNullOrBlank()) {
                if (call.method == "shareInstagramStory" || call.method == "shareFacebookStory") {
                    result.success(false)
                } else {
                    result.notImplemented()
                }
                return@setMethodCallHandler
            }
            when (call.method) {
                "shareInstagramStory" -> result.success(
                    shareStory(
                        bytes = bytes,
                        action = "com.instagram.share.ADD_TO_STORY",
                        targetPackage = "com.instagram.android",
                        extras = mapOf("source_application" to appId),
                    ),
                )
                "shareFacebookStory" -> result.success(
                    shareStory(
                        bytes = bytes,
                        action = "com.facebook.stories.ADD_TO_STORY",
                        targetPackage = "com.facebook.katana",
                        extras = mapOf(
                            "source_application" to appId,
                            "com.facebook.platform.extra.APPLICATION_ID" to appId,
                        ),
                    ),
                )
                else -> result.notImplemented()
            }
        }
    }

    private fun shareStory(
        bytes: ByteArray,
        action: String,
        targetPackage: String,
        extras: Map<String, String>,
    ): Boolean {
        return try {
            val dir = File(cacheDir, "diploma-share").apply { mkdirs() }
            val file = File(dir, "story.png")
            file.writeBytes(bytes)
            val uri = FileProvider.getUriForFile(
                this,
                "$packageName.diploma",
                file,
            )
            val intent = Intent(action).apply {
                setDataAndType(uri, "image/png")
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                setPackage(targetPackage)
                for ((key, value) in extras) {
                    putExtra(key, value)
                }
            }
            if (intent.resolveActivity(packageManager) == null) {
                false
            } else {
                startActivity(intent)
                true
            }
        } catch (_: Exception) {
            false
        }
    }
}
