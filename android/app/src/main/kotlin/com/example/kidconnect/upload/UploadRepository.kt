package com.example.kidconnect.upload

import android.content.Context

class UploadRepository private constructor(context: Context) {
    private val db = UploadDatabase.getInstance(context)
    private val dao = db.uploadDao()

    suspend fun enqueue(batchId: String, filePath: String, mimeType: String?, remoteUrl: String?, totalBytes: Long = 0): Long {
        val job = UploadJob(batchId = batchId, filePath = filePath, mimeType = mimeType, remoteUrl = remoteUrl, totalBytes = totalBytes)
        return dao.insert(job)
    }

    suspend fun pauseJob(id: Long) {
        val job = dao.getById(id) ?: return
        dao.update(job.copy(isPaused = true, status = "PAUSED"))
    }

    suspend fun resumeJob(id: Long) {
        val job = dao.getById(id) ?: return
        dao.update(job.copy(isPaused = false, status = "PENDING"))
    }

    suspend fun cancelJob(id: Long) {
        val job = dao.getById(id) ?: return
        dao.update(job.copy(isCancelled = true, status = "CANCELLED"))
    }

    suspend fun getPending(): List<UploadJob> = dao.getPendingJobs()

    suspend fun getRunnable(): List<UploadJob> = dao.getRunnableJobs()

    suspend fun getById(id: Long): UploadJob? = dao.getById(id)

    suspend fun update(job: UploadJob) = dao.update(job)

    suspend fun getAll(): List<UploadJob> = dao.getAllJobs()

    companion object {
        @Volatile
        private var INSTANCE: UploadRepository? = null

        fun getInstance(context: Context): UploadRepository {
            return INSTANCE ?: synchronized(this) {
                val r = UploadRepository(context.applicationContext)
                INSTANCE = r
                r
            }
        }
    }
}
