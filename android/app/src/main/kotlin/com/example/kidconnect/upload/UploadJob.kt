package com.example.kidconnect.upload

import androidx.room.Entity
import androidx.room.PrimaryKey

@Entity(tableName = "upload_jobs")
data class UploadJob(
    @PrimaryKey(autoGenerate = true) val id: Long = 0,
    val batchId: String,
    val filePath: String,
    val mimeType: String?,
    val remoteUrl: String?,
    val status: String = "PENDING",
    val progress: Int = 0,
    val attempts: Int = 0,
    val totalBytes: Long = 0,
    val uploadedBytes: Long = 0,
    val isPaused: Boolean = false,
    val isCancelled: Boolean = false
)
