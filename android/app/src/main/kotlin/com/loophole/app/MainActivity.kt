package com.loophole.app

import android.media.MediaScannerConnection
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import androidx.activity.enableEdgeToEdge
import android.content.Intent
import android.net.Uri
import android.provider.DocumentsContract
import androidx.documentfile.provider.DocumentFile
import java.io.File
import java.io.FileOutputStream
import android.util.Log
import android.content.ContentValues
import android.provider.MediaStore

class MainActivity : FlutterFragmentActivity() {
    private val CHANNEL = "com.loophole.app/media"
    private var pendingResult: MethodChannel.Result? = null
    private var pendingPermissionType: String? = null
    private val REQUEST_CODE_SAF = 4444

    private fun addDebugLog(msg: String) {
        Log.d("LoopHoleSAF", msg)
    }

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        enableEdgeToEdge()
        super.onCreate(savedInstanceState)
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == REQUEST_CODE_SAF) {
            val pending = pendingResult
            pendingResult = null
            if (resultCode == RESULT_OK && data != null) {
                val treeUri = data.data
                if (treeUri != null) {
                    addDebugLog("onActivityResult: User selected tree URI: $treeUri")
                    try {
                        contentResolver.takePersistableUriPermission(
                            treeUri,
                            Intent.FLAG_GRANT_READ_URI_PERMISSION
                        )
                        addDebugLog("onActivityResult: Persistable URI permission granted successfully.")
                        val prefs = getSharedPreferences("LoopHolePrefs", MODE_PRIVATE)
                        val key = if (pendingPermissionType == "whatsapp_business") "saf_whatsapp_business_uri" else "saf_whatsapp_uri"
                        prefs.edit().putString(key, treeUri.toString()).apply()
                        addDebugLog("onActivityResult: Stored URI in preferences under key: $key")
                        pending?.success(true)
                        return
                    } catch (e: Exception) {
                        addDebugLog("onActivityResult error: Failed to take persistable URI permission: ${e.message}")
                        pending?.error("PERMISSION_ERROR", e.message, null)
                        return
                    }
                } else {
                    addDebugLog("onActivityResult: data.getData() returned null tree URI.")
                }
            } else {
                addDebugLog("onActivityResult: Result code was not OK (resultCode=$resultCode) or data is null.")
            }
            pending?.success(false)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {

                "hasFolderPermission" -> {
                    val type = call.argument<String>("type") ?: "whatsapp"
                    result.success(hasFolderPermission(type))
                }
                "requestFolderPermission" -> {
                    val type = call.argument<String>("type") ?: "whatsapp"
                    pendingResult = result
                    pendingPermissionType = type
                    requestFolderPermission(type)
                }
                "syncStatuses" -> {
                    val type = call.argument<String>("type") ?: "whatsapp"
                    Thread {
                        try {
                            val success = syncStatuses(type)
                            runOnUiThread {
                                result.success(success)
                            }
                        } catch (e: Exception) {
                            runOnUiThread {
                                result.error("SYNC_ERROR", e.message, null)
                            }
                        }
                    }.start()
                }
                "useSAF" -> {
                    result.success(android.os.Build.VERSION.SDK_INT >= 30)
                }
                "scanFile" -> {
                    val path = call.argument<String>("path")
                    if (path != null) {
                        val mimeType = when {
                            path.endsWith(".jpg", true) || path.endsWith(".jpeg", true) -> "image/jpeg"
                            path.endsWith(".png", true) -> "image/png"
                            path.endsWith(".mp3", true) -> "audio/mpeg"
                            path.endsWith(".m4a", true) -> "audio/mp4"
                            path.endsWith(".mp4", true) -> "video/mp4"
                            path.endsWith(".mkv", true) -> "video/x-matroska"
                            else -> null
                        }
                        MediaScannerConnection.scanFile(this, arrayOf(path), mimeType?.let { arrayOf(it) }, null)
                        result.success(true)
                    } else {
                        result.error("INVALID_PATH", "Path was null", null)
                    }
                }
                "openVideo" -> {
                    val path = call.argument<String>("path") ?: ""
                    val file = java.io.File(path)
                    if (file.exists()) {
                        val uri = androidx.core.content.FileProvider.getUriForFile(
                            this,
                            "com.loophole.app.fileprovider",
                            file
                        )
                        val mimeType = when {
                            path.endsWith(".jpg", true) || path.endsWith(".jpeg", true) || path.endsWith(".png", true) -> "image/*"
                            path.endsWith(".mp3", true) || path.endsWith(".m4a", true) || path.endsWith(".wav", true) -> "audio/*"
                            else -> "video/*"
                        }
                        val intent = android.content.Intent(
                            android.content.Intent.ACTION_VIEW
                        ).apply {
                            setDataAndType(uri, mimeType)
                            addFlags(android.content.Intent.FLAG_GRANT_READ_URI_PERMISSION)
                            addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        try {
                            startActivity(intent)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("LAUNCH_FAILED", "No app available to open this file format: ${e.message}", null)
                        }
                    } else {
                        result.error("FILE_NOT_FOUND", "File does not exist: $path", null)
                    }
                }
                "launchEmail" -> {
                    val email = call.argument<String>("email") ?: "support.loophole@gmail.com"
                    val subject = call.argument<String>("subject") ?: "LoopHole Support"
                    try {
                        val intent = android.content.Intent(android.content.Intent.ACTION_SENDTO).apply {
                            data = android.net.Uri.parse("mailto:")
                            putExtra(android.content.Intent.EXTRA_EMAIL, arrayOf(email))
                            putExtra(android.content.Intent.EXTRA_SUBJECT, subject)
                            addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("LAUNCH_EMAIL_FAILED", e.message, null)
                    }
                }
                "mergeVideoAndAudio" -> {
                    val videoPath = call.argument<String>("videoPath")
                    val audioPath = call.argument<String>("audioPath")
                    val outputPath = call.argument<String>("outputPath")
                    if (videoPath != null && audioPath != null && outputPath != null) {
                        Thread {
                            try {
                                val success = mergeMedia(videoPath, audioPath, outputPath)
                                runOnUiThread {
                                    if (success) {
                                        result.success(true)
                                    } else {
                                        result.error("MERGE_FAILED", "Muxer failed", null)
                                    }
                                }
                            } catch (e: Exception) {
                                runOnUiThread {
                                    result.error("MERGE_EXCEPTION", e.message, null)
                                }
                            }
                        }.start()
                    } else {
                        result.error("INVALID_ARGS", "Missing arguments", null)
                    }
                }
                "getVideoThumbnail" -> {
                    val path = call.argument<String>("path")
                    if (path != null) {
                        Thread {
                            try {
                                val retriever = android.media.MediaMetadataRetriever()
                                try {
                                    retriever.setDataSource(path)
                                    val bitmap = retriever.getFrameAtTime(0, android.media.MediaMetadataRetriever.OPTION_CLOSEST_SYNC)
                                    if (bitmap != null) {
                                        val width = bitmap.width
                                        val height = bitmap.height
                                        if (width > 0 && height > 0) {
                                            val stream = java.io.ByteArrayOutputStream()
                                            val scaledHeight = (300.toFloat() / width * height).toInt()
                                            val finalHeight = if (scaledHeight > 0) scaledHeight else 1
                                            val scaledBitmap = android.graphics.Bitmap.createScaledBitmap(
                                                bitmap, 
                                                300, 
                                                finalHeight, 
                                                true
                                            )
                                            scaledBitmap.compress(android.graphics.Bitmap.CompressFormat.JPEG, 70, stream)
                                            val byteArray = stream.toByteArray()
                                            runOnUiThread {
                                                result.success(byteArray)
                                            }
                                            bitmap.recycle()
                                            scaledBitmap.recycle()
                                        } else {
                                            runOnUiThread {
                                                result.error("INVALID_DIMENSIONS", "Bitmap dimensions are invalid", null)
                                            }
                                            bitmap.recycle()
                                        }
                                    } else {
                                        runOnUiThread {
                                            result.error("NO_FRAME", "Could not extract frame", null)
                                        }
                                    }
                                } finally {
                                    retriever.release()
                                }
                            } catch (e: Exception) {
                                runOnUiThread {
                                    result.error("THUMBNAIL_FAILED", e.message, null)
                                }
                            }
                        }.start()
                    } else {
                        result.error("INVALID_ARGS", "Missing path argument", null)
                    }
                }
                "saveMediaToGallery" -> {
                    val srcPath = call.argument<String>("srcPath")
                    val name = call.argument<String>("name")
                    if (srcPath != null && name != null) {
                        saveMediaToGallery(srcPath, name, result)
                    } else {
                        result.error("INVALID_ARGS", "Missing srcPath or name argument", null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun mergeMedia(videoPath: String, audioPath: String, outputPath: String): Boolean {
        var videoExtractor: android.media.MediaExtractor? = null
        var audioExtractor: android.media.MediaExtractor? = null
        var muxer: android.media.MediaMuxer? = null
        try {
            videoExtractor = android.media.MediaExtractor()
            videoExtractor.setDataSource(videoPath)
            
            audioExtractor = android.media.MediaExtractor()
            audioExtractor.setDataSource(audioPath)
            
            muxer = android.media.MediaMuxer(outputPath, android.media.MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
            
            // Get video track index and format
            var videoTrackIndex = -1
            var videoFormat: android.media.MediaFormat? = null
            for (i in 0 until videoExtractor.trackCount) {
                val format = videoExtractor.getTrackFormat(i)
                val mime = format.getString(android.media.MediaFormat.KEY_MIME) ?: ""
                if (mime.startsWith("video/")) {
                    videoTrackIndex = i
                    videoFormat = format
                    break
                }
            }
            
            // Get audio track index and format
            var audioTrackIndex = -1
            var audioFormat: android.media.MediaFormat? = null
            for (i in 0 until audioExtractor.trackCount) {
                val format = audioExtractor.getTrackFormat(i)
                val mime = format.getString(android.media.MediaFormat.KEY_MIME) ?: ""
                if (mime.startsWith("audio/")) {
                    audioTrackIndex = i
                    audioFormat = format
                    break
                }
            }
            
            if (videoTrackIndex == -1 || videoFormat == null) {
                throw Exception("No video track found in $videoPath")
            }
            if (audioTrackIndex == -1 || audioFormat == null) {
                throw Exception("No audio track found in $audioPath")
            }
            
            videoExtractor.selectTrack(videoTrackIndex)
            val muxerVideoTrackIndex = muxer.addTrack(videoFormat)
            
            audioExtractor.selectTrack(audioTrackIndex)
            val muxerAudioTrackIndex = muxer.addTrack(audioFormat)
            
            muxer.start()
            
            // Interleave Video and Audio Tracks by timestamp
            val buffer = java.nio.ByteBuffer.allocate(1024 * 1024)
            val bufferInfo = android.media.MediaCodec.BufferInfo()
            
            var videoDone = false
            var audioDone = false
            
            while (!videoDone || !audioDone) {
                var selectVideo = false
                if (!videoDone && !audioDone) {
                    val videoTime = videoExtractor.sampleTime
                    val audioTime = audioExtractor.sampleTime
                    if (videoTime <= audioTime) {
                        selectVideo = true
                    }
                } else if (!videoDone) {
                    selectVideo = true
                }
                
                if (selectVideo) {
                    bufferInfo.offset = 0
                    bufferInfo.size = videoExtractor.readSampleData(buffer, 0)
                    if (bufferInfo.size < 0) {
                        videoDone = true
                    } else {
                        bufferInfo.presentationTimeUs = videoExtractor.sampleTime
                        bufferInfo.flags = videoExtractor.sampleFlags
                        muxer.writeSampleData(muxerVideoTrackIndex, buffer, bufferInfo)
                        videoExtractor.advance()
                    }
                } else {
                    bufferInfo.offset = 0
                    bufferInfo.size = audioExtractor.readSampleData(buffer, 0)
                    if (bufferInfo.size < 0) {
                        audioDone = true
                    } else {
                        bufferInfo.presentationTimeUs = audioExtractor.sampleTime
                        bufferInfo.flags = audioExtractor.sampleFlags
                        muxer.writeSampleData(muxerAudioTrackIndex, buffer, bufferInfo)
                        audioExtractor.advance()
                    }
                }
            }
            
            muxer.stop()
            return true
        } finally {
            try { videoExtractor?.release() } catch (e: Exception) {}
            try { audioExtractor?.release() } catch (e: Exception) {}
            try { muxer?.release() } catch (e: Exception) {}
        }
    }

    private fun isSameTreeUri(uri1: Uri, uri2: Uri): Boolean {
        if (uri1 == uri2) return true
        if (uri1.authority != uri2.authority) return false
        try {
            val id1 = DocumentsContract.getTreeDocumentId(uri1)
            val id2 = DocumentsContract.getTreeDocumentId(uri2)
            return id1 == id2
        } catch (e: Exception) {
            val p1 = uri1.path
            val p2 = uri2.path
            return p1 != null && p2 != null && p1.replace(Regex("/$"), "") == p2.replace(Regex("/$"), "")
        }
    }

    private fun hasFolderPermission(type: String): Boolean {
        val prefs = getSharedPreferences("LoopHolePrefs", MODE_PRIVATE)
        val key = if (type == "whatsapp_business") "saf_whatsapp_business_uri" else "saf_whatsapp_uri"
        val uriStr = prefs.getString(key, null)
        if (uriStr == null) {
            addDebugLog("hasFolderPermission($type): No URI stored in SharedPreferences.")
            return false
        }
        val targetUri = Uri.parse(uriStr)
        
        val persisted = contentResolver.persistedUriPermissions
        addDebugLog("hasFolderPermission($type): Checking target URI: $uriStr across ${persisted.size} persisted permissions.")
        for (perm in persisted) {
            addDebugLog("Persisted permission: ${perm.uri}, read=${perm.isReadPermission}")
            if (perm.isReadPermission && isSameTreeUri(perm.uri, targetUri)) {
                addDebugLog("hasFolderPermission($type): Match found!")
                return true
            }
        }
        addDebugLog("hasFolderPermission($type): No matching persisted permission found.")
        return false
    }

    private fun requestFolderPermission(type: String) {
        addDebugLog("requestFolderPermission($type): Initiating picker dialog.")
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE)
        
        val docId = if (type == "whatsapp_business") {
            "primary:Android/media/com.whatsapp.w4b/WhatsApp Business/Media"
        } else {
            "primary:Android/media/com.whatsapp/WhatsApp/Media"
        }
        
        val authority = "com.android.externalstorage.documents"
        val documentUri = DocumentsContract.buildDocumentUri(authority, docId)
        addDebugLog("requestFolderPermission($type): Target documentUri: $documentUri")
        
        intent.putExtra("android.provider.extra.INITIAL_URI", documentUri)
        intent.putExtra(Intent.EXTRA_LOCAL_ONLY, true)
        
        try {
            startActivityForResult(intent, REQUEST_CODE_SAF)
        } catch (e: Exception) {
            addDebugLog("requestFolderPermission($type): Direct launch failed, trying fallback. Error: ${e.message}")
            try {
                val fallbackIntent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE)
                startActivityForResult(fallbackIntent, REQUEST_CODE_SAF)
            } catch (ex: Exception) {
                addDebugLog("requestFolderPermission($type): Fallback launch failed: ${ex.message}")
                pendingResult?.error("SAF_LAUNCH_FAILED", ex.message, null)
                pendingResult = null
            }
        }
    }

    private fun syncStatuses(type: String): Boolean {
        addDebugLog("syncStatuses($type): Started sync process.")
        val prefs = getSharedPreferences("LoopHolePrefs", MODE_PRIVATE)
        val flutterPrefs = getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE)
        val key = if (type == "whatsapp_business") "saf_whatsapp_business_uri" else "saf_whatsapp_uri"
        val uriStr = prefs.getString(key, null)
        if (uriStr == null) {
            addDebugLog("syncStatuses($type): Stored URI string is null.")
            return false
        }
        val treeUri = Uri.parse(uriStr)
        addDebugLog("syncStatuses($type): Parsed treeUri: $treeUri")
        
        try {
            val statusesDoc = getStatusesDocumentFile(treeUri, type == "whatsapp_business")
            if (statusesDoc == null) {
                addDebugLog("syncStatuses($type): Could not resolve statuses directory.")
                return false
            }
            addDebugLog("syncStatuses($type): Resolved statuses directory: ${statusesDoc.name}, URI: ${statusesDoc.uri}")

            // Sync inside app's own cache folder
            val cacheDir = File(cacheDir, "StatusSaver")
            if (!cacheDir.exists()) {
                cacheDir.mkdirs()
            }
            
            val files = try { statusesDoc.listFiles() } catch (e: Exception) {
                addDebugLog("syncStatuses($type): Failed to list files: ${e.message}")
                emptyArray()
            }
            addDebugLog("syncStatuses($type): Found ${files.size} raw files/directories in status directory.")
            val copiedFiles = mutableSetOf<String>()
            
            for (docFile in files) {
                if (docFile.isFile && docFile.name != null) {
                    val name = docFile.name!!
                    if (name.startsWith(".")) continue
                    
                    val lower = name.lowercase()
                    val isPhoto = lower.endsWith(".jpg") || lower.endsWith(".jpeg") || lower.endsWith(".png")
                    val isVideo = lower.endsWith(".mp4") || lower.endsWith(".mkv")
                    if (!isPhoto && !isVideo) continue
                    
                    copiedFiles.add(name)
                    
                    val destFile = File(cacheDir, name)
                    
                    // Check if deleted via Flutter prefs (uses "flutter." prefix and "FlutterSharedPreferences" file)
                    val isDeleted = flutterPrefs.getBoolean("flutter.status_deleted_$name", false)
                    if (isDeleted) continue
                    
                    if (!destFile.exists()) {
                        addDebugLog("syncStatuses($type): Copying new status file: $name")
                        try {
                            contentResolver.openInputStream(docFile.uri)?.use { input ->
                                FileOutputStream(destFile).use { output ->
                                    input.copyTo(output)
                                }
                            }
                            // Save cache timestamp in Flutter preferences
                            flutterPrefs.edit().putLong("flutter.status_cache_time_$name", System.currentTimeMillis()).apply()
                        } catch (copyEx: Exception) {
                            addDebugLog("syncStatuses($type): Error copying file $name: ${copyEx.message}")
                        }
                    }
                }
            }
            
            // Cleanup expired/not present files
            val cachedFiles = cacheDir.listFiles()
            if (cachedFiles != null) {
                val editor = flutterPrefs.edit()
                for (f in cachedFiles) {
                    if (!copiedFiles.contains(f.name)) {
                        addDebugLog("syncStatuses($type): Deleting expired/removed status from cache: ${f.name}")
                        f.delete()
                        editor.remove("flutter.status_cache_time_${f.name}")
                        editor.remove("flutter.status_deleted_${f.name}")
                    }
                }
                editor.apply()
            }
            
            addDebugLog("syncStatuses($type): Completed successfully. Total synced: ${copiedFiles.size}")
            return true
        } catch (e: Exception) {
            addDebugLog("syncStatuses($type): Sync failed with exception: ${e.message}")
            return false
        }
    }

    private fun getStatusesDocumentFile(treeUri: Uri, isBusiness: Boolean): DocumentFile? {
        val rootDocId = try {
            DocumentsContract.getTreeDocumentId(treeUri)
        } catch (e: Exception) {
            addDebugLog("getStatusesDocumentFile: Failed to get tree document ID: ${e.message}")
            return null
        }
        
        addDebugLog("getStatusesDocumentFile: rootDocId = $rootDocId")
        
        val colonIndex = rootDocId.indexOf(':')
        val prefix = if (colonIndex != -1) rootDocId.substring(0, colonIndex + 1) else "primary:"
        
        val suffixList = if (isBusiness) {
            listOf(
                "Android/media/com.whatsapp.w4b/WhatsApp Business/Media/.Statuses",
                "WhatsApp Business/Media/.Statuses"
            )
        } else {
            listOf(
                "Android/media/com.whatsapp/WhatsApp/Media/.Statuses",
                "WhatsApp/Media/.Statuses"
            )
        }
        val possibleDocIds = suffixList.map { prefix + it }
        addDebugLog("getStatusesDocumentFile: Generated target possible docIds: $possibleDocIds")
        
        for (docId in possibleDocIds) {
            try {
                if (docId.startsWith(rootDocId, ignoreCase = true) || rootDocId.startsWith(docId, ignoreCase = true)) {
                    val childUri = DocumentsContract.buildDocumentUriUsingTree(treeUri, docId)
                    addDebugLog("getStatusesDocumentFile: Checking childUri: $childUri for docId: $docId")
                    val docFile = DocumentFile.fromTreeUri(this, childUri)
                    if (docFile != null && docFile.exists() && docFile.isDirectory) {
                        addDebugLog("getStatusesDocumentFile: Found direct match: $docId")
                        return docFile
                    } else {
                        addDebugLog("getStatusesDocumentFile: Path exists=false or not dir for docId: $docId")
                    }
                }
            } catch (e: Exception) {
                addDebugLog("getStatusesDocumentFile: Failed to verify docId $docId: ${e.message}")
            }
        }
        
        val rootDoc = DocumentFile.fromTreeUri(this, treeUri)
        if (rootDoc == null) {
            addDebugLog("getStatusesDocumentFile: Root DocumentFile is null.")
            return null
        }
        if (!rootDoc.exists() || !rootDoc.isDirectory) {
            addDebugLog("getStatusesDocumentFile: Root Doc exists=${rootDoc.exists()} isDirectory=${rootDoc.isDirectory}")
            return null
        }
        
        addDebugLog("getStatusesDocumentFile: Running recursive findStatusesFolder on rootDoc: ${rootDoc.name}")
        val searchedDoc = findStatusesFolder(rootDoc)
        if (searchedDoc != null) {
            addDebugLog("getStatusesDocumentFile: Found statuses directory via search: ${searchedDoc.name}")
            return searchedDoc
        }
        
        addDebugLog("getStatusesDocumentFile: Falling back directly to rootDoc: ${rootDoc.name}")
        return rootDoc
    }

    private fun findStatusesFolder(dir: DocumentFile, depth: Int = 0): DocumentFile? {
        if (depth > 4) return null
        val name = dir.name
        if (name != null && (name.equals(".statuses", ignoreCase = true) || name.equals("statuses", ignoreCase = true))) {
            return dir
        }
        val files = try { dir.listFiles() } catch (e: Exception) {
            addDebugLog("findStatusesFolder depth=$depth: listFiles failed: ${e.message}")
            null
        } ?: return null
        
        for (file in files) {
            if (file.isDirectory) {
                val fName = file.name
                if (fName != null && (fName.equals(".statuses", ignoreCase = true) || fName.equals("statuses", ignoreCase = true))) {
                    return file
                }
            }
        }
        for (file in files) {
            if (file.isDirectory) {
                val found = findStatusesFolder(file, depth + 1)
                if (found != null) {
                    return found
                }
            }
        }
        return null
    }

    private fun saveMediaToGallery(srcPath: String, name: String, result: MethodChannel.Result) {
        Thread {
            try {
                val srcFile = File(srcPath)
                if (!srcFile.exists()) {
                    runOnUiThread {
                        result.error("FILE_NOT_FOUND", "Source file does not exist", null)
                    }
                    return@Thread
                }

                val isPhoto = name.endsWith(".jpg", true) || name.endsWith(".jpeg", true) || name.endsWith(".png", true)
                val isVideo = name.endsWith(".mp4", true) || name.endsWith(".mkv", true)
                if (!isPhoto && !isVideo) {
                    runOnUiThread {
                        result.error("INVALID_FILE_TYPE", "File is neither photo nor video", null)
                    }
                    return@Thread
                }

                val relativePath = if (isPhoto) "Pictures/LoopHole" else "DCIM/LoopHole"
                val mimeType = when {
                    name.endsWith(".jpg", true) || name.endsWith(".jpeg", true) -> "image/jpeg"
                    name.endsWith(".png", true) -> "image/png"
                    name.endsWith(".mp4", true) -> "video/mp4"
                    name.endsWith(".mkv", true) -> "video/x-matroska"
                    else -> if (isPhoto) "image/*" else "video/*"
                }

                val resolver = contentResolver
                var uri: Uri? = null
                
                if (android.os.Build.VERSION.SDK_INT >= 29) {
                    val contentUri = if (isPhoto) {
                        MediaStore.Images.Media.EXTERNAL_CONTENT_URI
                    } else {
                        MediaStore.Video.Media.EXTERNAL_CONTENT_URI
                    }

                    val values = ContentValues().apply {
                        put(MediaStore.MediaColumns.DISPLAY_NAME, name)
                        put(MediaStore.MediaColumns.MIME_TYPE, mimeType)
                        put(MediaStore.MediaColumns.RELATIVE_PATH, relativePath)
                        put(MediaStore.MediaColumns.IS_PENDING, 1)
                    }

                    uri = resolver.insert(contentUri, values)
                    if (uri != null) {
                        resolver.openOutputStream(uri)?.use { outputStream ->
                            srcFile.inputStream().use { inputStream ->
                                inputStream.copyTo(outputStream)
                            }
                        }
                        values.clear()
                        values.put(MediaStore.MediaColumns.IS_PENDING, 0)
                        resolver.update(uri, values, null, null)
                    }
                } else {
                    val galleryDirName = if (isPhoto) "Pictures" else "DCIM"
                    val targetDir = File(android.os.Environment.getExternalStorageDirectory(), "$galleryDirName/LoopHole")
                    if (!targetDir.exists()) {
                        targetDir.mkdirs()
                    }
                    val targetFile = File(targetDir, name)
                    srcFile.inputStream().use { inputStream ->
                        FileOutputStream(targetFile).use { outputStream ->
                            inputStream.copyTo(outputStream)
                        }
                    }
                    MediaScannerConnection.scanFile(this, arrayOf(targetFile.absolutePath), arrayOf(mimeType), null)
                    uri = Uri.fromFile(targetFile)
                }

                var finalPath: String? = null
                if (uri != null) {
                    if (android.os.Build.VERSION.SDK_INT >= 29) {
                        val projection = arrayOf(MediaStore.MediaColumns.DATA)
                        contentResolver.query(uri, projection, null, null, null)?.use { cursor ->
                            if (cursor.moveToFirst()) {
                                val dataIndex = cursor.getColumnIndexOrThrow(MediaStore.MediaColumns.DATA)
                                finalPath = cursor.getString(dataIndex)
                            }
                        }
                        if (finalPath == null) {
                            finalPath = "/storage/emulated/0/$relativePath/$name"
                        }
                    } else {
                        val galleryDirName = if (isPhoto) "Pictures" else "DCIM"
                        finalPath = File(android.os.Environment.getExternalStorageDirectory(), "$galleryDirName/LoopHole/$name").absolutePath
                    }
                    val resultPath = finalPath
                    runOnUiThread {
                        if (resultPath != null) {
                            result.success(resultPath)
                        } else {
                            result.error("SAVE_FAILED", "Failed to resolve final path", null)
                        }
                    }
                } else {
                    runOnUiThread {
                        result.error("SAVE_FAILED", "Failed to insert into MediaStore", null)
                    }
                }
            } catch (e: Exception) {
                runOnUiThread {
                    result.error("SAVE_EXCEPTION", e.message, null)
                }
            }
        }.start()
    }
}
