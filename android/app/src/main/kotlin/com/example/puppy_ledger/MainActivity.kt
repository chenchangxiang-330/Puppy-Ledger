package com.example.puppy_ledger

import android.app.Activity
import android.content.ClipData
import android.content.Intent
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.io.File

/** System document UI only: no network or broad storage permission. */
class MainActivity : FlutterActivity() {
    private var widgetChannel: MethodChannel? = null
    private val launches = java.util.ArrayDeque<Map<String, String>>()

    private fun takeWidgetIntent(value: Intent?) {
        if (value?.action != LedgerWidgets.OPEN) return
        val uri = value.data ?: return
        if (uri.scheme != "puppyledger-widget" || uri.host !in listOf("expense", "day")) return
        launches.addLast(
            mapOf("type" to uri.host!!, "value" to (uri.getQueryParameter("value") ?: ""))
        )
        value.action = null
        value.data = null
    }

    override fun onCreate(saved: android.os.Bundle?) {
        takeWidgetIntent(intent)
        super.onCreate(saved)
    }

    override fun onNewIntent(intent: Intent) {
        takeWidgetIntent(intent)
        super.onNewIntent(intent)
        setIntent(intent)
        widgetChannel?.invokeMethod("intentAvailable", null)
    }

    override fun onResume() {
        super.onResume()
        LedgerWidgets.refresh(this)
    }

    private var pending: MethodChannel.Result? = null
    private var operation: String? = null
    private var pendingBytes: ByteArray? = null
    private var pendingImage: File? = null
    private val receiptDir
        get() = File(cacheDir, "receipts")

    private fun receiptFile(path: String?): File? {
        val file = path?.let { File(it).canonicalFile } ?: return null
        return file.takeIf {
            it.parentFile == receiptDir.canonicalFile &&
                it.isFile &&
                it.name.startsWith("receipt-") &&
                it.name.endsWith(".png")
        }
    }

    private val requestCode = 4101

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        widgetChannel =
            MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "puppy_ledger/widgets")
                .also { channel ->
                    channel.setMethodCallHandler { call, result ->
                        when (call.method) {
                            "takeLaunch" -> result.success(launches.pollFirst())
                            "dataChanged" -> {
                                LedgerWidgets.refresh(this)
                                result.success(null)
                            }
                            else -> result.notImplemented()
                        }
                    }
                }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "puppy_ledger/files")
            .setMethodCallHandler { call, result ->
                if (pending != null) {
                    result.error("BUSY", "请先完成当前文件选择", null)
                    return@setMethodCallHandler
                }
                val intent =
                    when (call.method) {
                        "receiptDirectory" -> {
                            if (!receiptDir.isDirectory && !receiptDir.mkdirs()) {
                                result.error("FILE_IO", "无法创建小票目录", null)
                                return@setMethodCallHandler
                            }
                            val cutoff = System.currentTimeMillis() - 2L * 86400000
                            receiptDir
                                .listFiles()
                                ?.filter { it.lastModified() < cutoff }
                                ?.forEach { it.delete() }
                            result.success(receiptDir.absolutePath)
                            return@setMethodCallHandler
                        }
                        "shareReceipt",
                        "writeReceipt" -> {
                            val file = receiptFile(call.argument<String>("path"))
                            if (file == null) {
                                result.error("FILE_IO", "小票图片不存在", null)
                                return@setMethodCallHandler
                            }
                            if (call.method == "shareReceipt") {
                                try {
                                    val uri =
                                        FileProvider.getUriForFile(
                                            this,
                                            "$packageName.receipts",
                                            file,
                                        )
                                    val share =
                                        Intent(Intent.ACTION_SEND).apply {
                                            type = "image/png"
                                            putExtra(Intent.EXTRA_STREAM, uri)
                                            clipData = ClipData.newRawUri("收支小票", uri)
                                            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                                        }
                                    startActivity(Intent.createChooser(share, "分享每日收支小票"))
                                    result.success(true)
                                } catch (e: Exception) {
                                    result.error("SHARE", "无法打开系统分享", null)
                                }
                                return@setMethodCallHandler
                            }
                            pendingImage = file
                            Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                                addCategory(Intent.CATEGORY_OPENABLE)
                                type = "image/png"
                                putExtra(
                                    Intent.EXTRA_TITLE,
                                    call.argument<String>("name") ?: "每日收支小票.png",
                                )
                            }
                        }
                        "pickImage" ->
                            Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                                addCategory(Intent.CATEGORY_OPENABLE)
                                type = "image/*"
                            }
                        "readBackup" ->
                            Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                                addCategory(Intent.CATEGORY_OPENABLE)
                                type = "*/*"
                            }
                        "writeBackup" -> {
                            val bytes = call.argument<ByteArray>("bytes")
                            if (bytes == null || bytes.size > 64 * 1024 * 1024) {
                                result.error("INVALID_DATA", "备份文件大小无效", null)
                                return@setMethodCallHandler
                            }
                            pendingBytes = bytes
                            Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                                addCategory(Intent.CATEGORY_OPENABLE)
                                type = "application/zip"
                                putExtra(
                                    Intent.EXTRA_TITLE,
                                    call.argument<String>("name") ?: "puppy_ledger_backup.zip",
                                )
                            }
                        }
                        else -> {
                            result.notImplemented()
                            return@setMethodCallHandler
                        }
                    }
                pending = result
                operation = call.method
                try {
                    startActivityForResult(intent, requestCode)
                } catch (e: Exception) {
                    clearPending()?.error("DOCUMENT_UI", "无法打开系统文件选择器，请检查手机文件应用", null)
                }
            }
    }

    private fun clearPending(): MethodChannel.Result? {
        val result = pending
        pending = null
        operation = null
        pendingBytes = null
        pendingImage = null
        return result
    }

    @Deprecated("Required for system document results")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != this.requestCode) return
        val result = pending ?: return
        val currentOperation = operation
        val bytesToWrite = pendingBytes
        val fileToWrite = pendingImage
        if (resultCode != Activity.RESULT_OK || data?.data == null) {
            clearPending()
            result.success(
                if (currentOperation == "writeBackup" || currentOperation == "writeReceipt") false
                else null
            )
            return
        }
        val uri = data.data!!
        // Document providers may be slow. Keep all actual IO off the UI thread.
        Thread {
                try {
                    val value: Any =
                        if (currentOperation == "writeReceipt") {
                            val file = fileToWrite ?: throw IllegalStateException("Missing receipt")
                            contentResolver.openOutputStream(uri, "wt")?.use { out ->
                                file.inputStream().use { it.copyTo(out) }
                                out.flush()
                            } ?: throw IllegalStateException("Cannot open output")
                            true
                        } else if (currentOperation == "writeBackup") {
                            contentResolver.openOutputStream(uri, "wt")?.use { stream ->
                                stream.write(
                                    bytesToWrite ?: throw IllegalStateException("Missing backup")
                                )
                                stream.flush()
                            } ?: throw IllegalStateException("Cannot open output")
                            true
                        } else {
                            val limit =
                                if (currentOperation == "pickImage") 12 * 1024 * 1024
                                else 64 * 1024 * 1024
                            contentResolver.openInputStream(uri)?.use { stream ->
                                val output = ByteArrayOutputStream()
                                val buffer = ByteArray(16384)
                                while (true) {
                                    val count = stream.read(buffer)
                                    if (count < 0) break
                                    if (output.size() + count > limit)
                                        throw IllegalArgumentException("文件过大，图片需小于12MB，备份需小于64MB")
                                    output.write(buffer, 0, count)
                                }
                                output.toByteArray()
                            } ?: throw IllegalStateException("Cannot open input")
                        }
                    runOnUiThread {
                        clearPending()
                        result.success(value)
                    }
                } catch (e: Exception) {
                    runOnUiThread {
                        clearPending()
                        result.error("FILE_IO", e.message ?: "文件读写失败，请重试", null)
                    }
                }
            }
            .start()
    }
}
