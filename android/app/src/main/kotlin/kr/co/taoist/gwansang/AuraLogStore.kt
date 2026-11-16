package kr.co.taoist.gwansang

import android.content.ContentUris
import android.content.ContentValues
import android.content.Context
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import android.system.Os
import java.io.File
import java.io.FileOutputStream

/**
 * 공용 다운로드 폴더의 aura-log.txt 에 한 줄씩 덧붙인다.
 * 프로세스 강제 종료 직전에도 디스크에 남도록 매 기록마다 fsync 한다.
 */
object AuraLogStore {
    const val fileName = "aura-log.txt"

    fun pathHint(): String = "${Environment.DIRECTORY_DOWNLOADS}/$fileName"

    fun append(context: Context, text: String) {
        if (text.isEmpty()) return
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            appendMediaStore(context, text)
        } else {
            appendLegacy(text)
        }
    }

    private fun appendMediaStore(context: Context, text: String) {
        val resolver = context.contentResolver
        val collection =
            MediaStore.Downloads.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
        val uri = findExisting(context) ?: resolver.insert(
            collection,
            ContentValues().apply {
                put(MediaStore.Downloads.DISPLAY_NAME, fileName)
                put(MediaStore.Downloads.MIME_TYPE, "text/plain")
                put(
                    MediaStore.Downloads.RELATIVE_PATH,
                    Environment.DIRECTORY_DOWNLOADS,
                )
                put(MediaStore.Downloads.IS_PENDING, 0)
            },
        ) ?: error("MediaStore insert failed for $fileName")

        resolver.openFileDescriptor(uri, "wa")?.use { pfd ->
            FileOutputStream(pfd.fileDescriptor).use { out ->
                out.write(text.toByteArray(Charsets.UTF_8))
                out.flush()
            }
            try {
                Os.fsync(pfd.fileDescriptor)
            } catch (_: Exception) {
            }
        } ?: error("openFileDescriptor failed for $fileName")
    }

    private fun findExisting(context: Context): android.net.Uri? {
        val collection =
            MediaStore.Downloads.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
        val projection = arrayOf(MediaStore.Downloads._ID)
        context.contentResolver.query(
            collection,
            projection,
            "${MediaStore.Downloads.DISPLAY_NAME}=?",
            arrayOf(fileName),
            null,
        )?.use { cursor ->
            if (!cursor.moveToFirst()) return null
            val id = cursor.getLong(0)
            return ContentUris.withAppendedId(collection, id)
        }
        return null
    }

    private fun appendLegacy(text: String) {
        val dir = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)
        if (!dir.exists()) dir.mkdirs()
        val file = File(dir, fileName)
        FileOutputStream(file, true).use { out ->
            out.write(text.toByteArray(Charsets.UTF_8))
            out.flush()
            out.fd.sync()
        }
    }
}
