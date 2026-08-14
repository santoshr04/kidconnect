package com.example.kidconnect.upload

import android.content.Context
import androidx.work.CoroutineWorker
import androidx.work.ForegroundInfo
import androidx.work.WorkerParameters
import androidx.core.app.NotificationCompat
import androidx.work.workDataOf
import com.example.kidconnect.UploadForegroundService
import kotlinx.coroutines.delay
import okhttp3.MediaType.Companion.toMediaTypeOrNull
import okhttp3.MultipartBody
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody
import java.io.File

class UploadWorker(appContext: Context, workerParams: WorkerParameters) : CoroutineWorker(appContext, workerParams) {

    private val repo = UploadRepository.getInstance(appContext)
    private val client = OkHttpClient()

    override suspend fun getForegroundInfo(): ForegroundInfo {
        val notification = NotificationCompat.Builder(applicationContext, UploadForegroundService.CHANNEL_ID)
            .setContentTitle("Uploading files")
            .setContentText("Starting...")
            .setSmallIcon(com.example.kidconnect.R.mipmap.ic_launcher)
            .build()
        return ForegroundInfo(UploadForegroundService.NOTIF_ID, notification)
    }

    override suspend fun doWork(): Result {
        // Ensure we're running in foreground so OS treats this as important
        setForeground(getForegroundInfo())

        val pending = repo.getRunnable()
        if (pending.isEmpty()) return Result.success()

        for (job in pending) {
            try {
                // check flags
                val fresh = repo.getById(job.id) ?: job
                if (fresh.isCancelled) {
                    repo.update(fresh.copy(status = "CANCELLED"))
                    continue
                }
                if (fresh.isPaused) {
                    // skip paused jobs; they'll be resumed later
                    continue
                }

                val updating = fresh.copy(status = "UPLOADING", attempts = fresh.attempts + 1)
                repo.update(updating)

                val success = uploadFileChunked(updating)

                if (success) {
                    val done = updating.copy(status = "COMPLETED", progress = 100, uploadedBytes = updating.totalBytes)
                    repo.update(done)
                } else {
                    val retry = updating.copy(status = "RETRYING")
                    repo.update(retry)
                    // notify worker to retry later
                    return Result.retry()
                }

                // small yield
                delay(200)
            } catch (e: Exception) {
                val retry = job.copy(status = "RETRYING")
                repo.update(retry)
                return Result.retry()
            }
        }

        return Result.success()
    }

    private suspend fun uploadFileChunked(job: UploadJob): Boolean {
        val url = job.remoteUrl ?: return false
        val file = File(job.filePath)
        if (!file.exists()) return false

        val chunkSize = 5 * 1024 * 1024 // 5MB
        val total = job.totalBytes.takeIf { it > 0 } ?: file.length()
        var uploaded = job.uploadedBytes
        val totalChunks = ((total + chunkSize - 1) / chunkSize).toInt()
        var chunkIndex = (uploaded / chunkSize).toInt()

        while (uploaded < total) {
            // re-check flags
            val fresh = repo.getById(job.id) ?: return false
            if (fresh.isCancelled) return false
            if (fresh.isPaused) return false

            val start = chunkIndex.toLong() * chunkSize
            val end = kotlin.math.min(start + chunkSize, total) - 1
            val len = (end - start + 1).toInt()

            val raf = java.io.RandomAccessFile(file, "r")
            val buf = ByteArray(len)
            raf.seek(start)
            raf.readFully(buf)
            raf.close()

            val reqBody = RequestBody.create("application/octet-stream".toMediaTypeOrNull(), buf)
            val request = Request.Builder()
                .url(url)
                .addHeader("X-Chunk-Index", chunkIndex.toString())
                .addHeader("X-Total-Chunks", totalChunks.toString())
                .addHeader("Content-Range", "bytes $start-$end/$total")
                .post(reqBody)
                .build()

            client.newCall(request).execute().use { resp ->
                if (!resp.isSuccessful) {
                    return false
                }
            }

            uploaded += len
            chunkIndex += 1

            val progress = ((uploaded * 100) / total).toInt()
            repo.update(job.copy(uploadedBytes = uploaded, progress = progress))

            // broadcast progress
            UploadEventBus.send(mapOf(
                "id" to job.id,
                "filePath" to job.filePath,
                "uploadedBytes" to uploaded,
                "totalBytes" to total,
                "progress" to progress
            ))

            // small throttle
            delay(100)
        }

        return true
    }
}
