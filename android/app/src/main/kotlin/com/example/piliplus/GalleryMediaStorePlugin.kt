package com.aritxonly.hyperpiliplus

import android.content.ContentValues
import android.content.Context
import android.net.Uri
import android.os.Build
import android.provider.MediaStore
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.concurrent.Executors

/** Publishes completed recorder output to Android's shared Movies collection. */
class GalleryMediaStorePlugin : FlutterPlugin, MethodChannel.MethodCallHandler {
    companion object {
        private const val CHANNEL = "pure_live/gallery"
        private const val RELATIVE_DIRECTORY = "Movies/PiliPlus"
    }

    private val executor = Executors.newSingleThreadExecutor()
    private var context: Context? = null
    private var channel: MethodChannel? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, CHANNEL).also {
            it.setMethodCallHandler(this)
        }
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.method != "publishVideo") return result.notImplemented()
        val path = call.argument<String>("path")?.trim().orEmpty()
        if (path.isEmpty()) return result.error("invalid_path", "Missing video path", null)
        val source = File(path)
        if (!source.isFile || source.length() <= 0L) {
            return result.error("invalid_video", "Recording file is missing or empty", null)
        }
        val appContext = context ?: return result.error("unavailable", "Plugin is detached", null)
        executor.execute {
            try {
                val uri = publish(appContext, source)
                result.success(uri.toString())
            } catch (error: Exception) {
                result.error("publish_failed", error.message ?: "Unable to publish recording", null)
            }
        }
    }

    private fun publish(context: Context, source: File): Uri {
        val resolver = context.contentResolver
        val collection = MediaStore.Video.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
        val baseName = source.nameWithoutExtension
        var displayName = source.name
        var suffix = 1
        while (true) {
            val existing = resolver.query(
                collection,
                arrayOf(MediaStore.Video.Media._ID, MediaStore.Video.Media.SIZE),
                "${MediaStore.Video.Media.DISPLAY_NAME} = ? AND ${MediaStore.Video.Media.RELATIVE_PATH} = ?",
                arrayOf(displayName, "$RELATIVE_DIRECTORY/"),
                null,
            )?.use { cursor ->
                if (!cursor.moveToFirst()) null else {
                    val id = cursor.getLong(cursor.getColumnIndexOrThrow(MediaStore.Video.Media._ID))
                    val size = cursor.getLong(cursor.getColumnIndexOrThrow(MediaStore.Video.Media.SIZE))
                    collection to (id to size)
                }
            }
            if (existing == null) break
            if (existing.second.second == source.length()) {
                return Uri.withAppendedPath(existing.first, existing.second.first.toString())
            }
            displayName = "$baseName-$suffix.mp4"
            suffix++
        }
        val values = ContentValues().apply {
            put(MediaStore.Video.Media.DISPLAY_NAME, displayName)
            put(MediaStore.Video.Media.MIME_TYPE, "video/mp4")
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                put(MediaStore.Video.Media.RELATIVE_PATH, RELATIVE_DIRECTORY)
                put(MediaStore.Video.Media.IS_PENDING, 1)
            }
        }
        val uri = resolver.insert(collection, values)
            ?: error("MediaStore did not create a video entry")
        try {
            resolver.openOutputStream(uri, "w")?.use { output ->
                source.inputStream().buffered().use { input -> input.copyTo(output) }
            } ?: error("MediaStore output stream is unavailable")
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                resolver.update(uri, ContentValues().apply {
                    put(MediaStore.Video.Media.IS_PENDING, 0)
                }, null, null)
            }
            return uri
        } catch (error: Exception) {
            resolver.delete(uri, null, null)
            throw error
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel?.setMethodCallHandler(null)
        channel = null
        context = null
        executor.shutdown()
    }
}
