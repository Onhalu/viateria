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
            if (call.method != "shareInstagramStory") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            val bytes = call.argument<ByteArray>("bytes")
            val appId = call.argument<String>("appId")
            if (bytes == null || appId.isNullOrBlank()) {
                result.success(false)
                return@setMethodCallHandler
            }
            result.success(shareInstagramStory(bytes, appId))
        }
    }

    private fun shareInstagramStory(bytes: ByteArray, appId: String): Boolean {
        return try {
            val dir = File(cacheDir, "diploma-share").apply { mkdirs() }
            val file = File(dir, "diploma.png")
            file.writeBytes(bytes)
            val uri = FileProvider.getUriForFile(
                this,
                "$packageName.diploma",
                file,
            )
            val intent = Intent("com.instagram.share.ADD_TO_STORY").apply {
                setDataAndType(uri, "image/png")
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                putExtra("source_application", appId)
                setPackage("com.instagram.android")
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
