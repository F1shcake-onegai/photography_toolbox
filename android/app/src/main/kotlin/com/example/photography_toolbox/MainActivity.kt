package com.example.photography_toolbox

import android.content.Intent
import android.net.Uri
import android.provider.OpenableColumns
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val channelName = "photography_toolbox/file_intent"
    private var eventSink: EventChannel.EventSink? = null
    private var initialFilePath: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Process initial launch intent
        handleIntent(intent)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getInitialFile" -> {
                        result.success(initialFilePath)
                        initialFilePath = null
                    }
                    else -> result.notImplemented()
                }
            }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, "$channelName/events")
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventSink = events
                }
                override fun onCancel(arguments: Any?) {
                    eventSink = null
                }
            })
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleIntent(intent)?.let { path ->
            eventSink?.success(path)
        }
    }

    private fun handleIntent(intent: Intent?): String? {
        if (intent?.action != Intent.ACTION_VIEW) return null
        val uri = intent.data ?: return null

        return try {
            val path = copyToTemp(uri)
            if (path != null && eventSink == null) {
                // Cold start — store for later retrieval via MethodChannel
                initialFilePath = path
            }
            path
        } catch (e: Exception) {
            null
        }
    }

    private fun copyToTemp(uri: Uri): String? {
        val displayName = getDisplayName(uri) ?: "import_file"
        val extension = displayName.substringAfterLast('.', "").lowercase()

        // Only accept our custom file types
        if (extension !in listOf("ptrecipe", "ptroll", "json", "zip")) {
            return null
        }

        val inputStream = contentResolver.openInputStream(uri) ?: return null
        val tempFile = File(cacheDir, "intent_import_${System.currentTimeMillis()}.$extension")
        tempFile.outputStream().use { output ->
            inputStream.copyTo(output)
        }
        inputStream.close()
        return tempFile.absolutePath
    }

    private fun getDisplayName(uri: Uri): String? {
        // Try ContentResolver query for display name
        try {
            contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)
                ?.use { cursor ->
                    if (cursor.moveToFirst()) {
                        val idx = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                        if (idx >= 0) return cursor.getString(idx)
                    }
                }
        } catch (_: Exception) {}
        // Fallback to last path segment
        return uri.lastPathSegment
    }
}
