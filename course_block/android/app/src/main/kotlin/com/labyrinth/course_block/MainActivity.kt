package com.labyrinth.course_block

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.Intent
import android.net.Uri
import java.io.OutputStream

class MainActivity : FlutterActivity() {
    private var pendingResult: MethodChannel.Result? = null
    private var pendingBytes: ByteArray? = null
    private val REQUEST_SAVE = 1001

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "course_block/file").setMethodCallHandler { call, result ->
            if (call.method == "saveFile") {
                val name = call.argument<String>("name") ?: "output"
                val bytes = call.argument<ByteArray>("bytes")
                if (bytes == null) {
                    result.error("NO_BYTES", "No bytes provided", null)
                    return@setMethodCallHandler
                }
                pendingResult = result
                pendingBytes = bytes
                val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                    addCategory(Intent.CATEGORY_OPENABLE)
                    type = "*/*"
                    putExtra(Intent.EXTRA_TITLE, name)
                }
                startActivityForResult(intent, REQUEST_SAVE)
            } else {
                result.notImplemented()
            }
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        // handle our save first, then call super so other plugins receive it
        if (requestCode == REQUEST_SAVE) {
            if (resultCode == RESULT_OK && data != null && data.data != null) {
                val uri: Uri = data.data!!
                try {
                    val stream: OutputStream? = contentResolver.openOutputStream(uri)
                    stream?.write(pendingBytes)
                    stream?.close()
                    pendingResult?.success(uri.toString())
                } catch (e: Exception) {
                    pendingResult?.error("WRITE_ERROR", e.message, null)
                }
            } else {
                pendingResult?.success(null)
            }
            pendingResult = null
            pendingBytes = null
        }
        // let super handle other request codes (e.g. image_cropper)
        super.onActivityResult(requestCode, resultCode, data)
    }
}
