package com.example.kidconnect.upload

import androidx.room.*

@Dao
interface UploadDao {
    @Insert(onConflict = OnConflictStrategy.IGNORE)
    fun insert(job: UploadJob): Long

    @Update
    fun update(job: UploadJob)

    @Query("SELECT * FROM upload_jobs WHERE status IN ('PENDING','RETRYING') ORDER BY id")
    fun getPendingJobs(): List<UploadJob>

    @Query("SELECT * FROM upload_jobs WHERE isPaused = 0 AND isCancelled = 0 AND status IN ('PENDING','RETRYING') ORDER BY id")
    fun getRunnableJobs(): List<UploadJob>

    @Query("SELECT * FROM upload_jobs ORDER BY id DESC")
    fun getAllJobs(): List<UploadJob>

    @Query("SELECT * FROM upload_jobs WHERE id = :id")
    fun getById(id: Long): UploadJob?
}
