package com.example.kidconnect

import android.content.Intent
import android.os.Bundle
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.EventChannel
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.ExistingWorkPolicy
import com.example.kidconnect.upload.UploadRepository
import com.example.kidconnect.upload.UploadWorker
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch

class MainActivity : FlutterActivity() {

	private val CHANNEL = "com.example.kidconnect/upload"
	private val EVENT_CHANNEL = "com.example.kidconnect/upload_events"

	override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
		super.configureFlutterEngine(flutterEngine)

		MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
			when (call.method) {
				"enqueueFiles" -> {
					val args = call.arguments as? Map<*, *>
					val files = (args?.get("files") as? List<*>)?.mapNotNull { it as? String } ?: emptyList()
					val batchId = args?.get("batchId") as? String ?: java.util.UUID.randomUUID().toString()
					val remoteUrl = args?.get("remoteUrl") as? String
					enqueueFiles(batchId, files, remoteUrl)
					result.success(true)
				}
				"pauseJob" -> {
					val id = (call.arguments as? Map<*, *>)?.get("id") as? Int ?: -1
					if (id >= 0) {
						CoroutineScope(Dispatchers.IO).launch {
							UploadRepository.getInstance(applicationContext).pauseJob(id.toLong())
						}
					}
					result.success(true)
				}
				"resumeJob" -> {
					val id = (call.arguments as? Map<*, *>)?.get("id") as? Int ?: -1
					if (id >= 0) {
						CoroutineScope(Dispatchers.IO).launch {
							UploadRepository.getInstance(applicationContext).resumeJob(id.toLong())
							val work = OneTimeWorkRequestBuilder<UploadWorker>().build()
							WorkManager.getInstance(applicationContext).enqueueUniqueWork("upload_queue", ExistingWorkPolicy.KEEP, work)
						}
					}
					result.success(true)
				}
				"cancelJob" -> {
					val id = (call.arguments as? Map<*, *>)?.get("id") as? Int ?: -1
					if (id >= 0) {
						CoroutineScope(Dispatchers.IO).launch {
							UploadRepository.getInstance(applicationContext).cancelJob(id.toLong())
						}
					}
					result.success(true)
				}
				"startForegroundService" -> {
					val intent = Intent(this, UploadForegroundService::class.java)
					startForegroundService(intent)
					result.success(true)
				}
				"getJobs" -> {
					// return basic job list from DB
					CoroutineScope(Dispatchers.IO).launch {
						val repo = UploadRepository.getInstance(applicationContext)
						val all = repo.getAll()
						val list = all.map {
							mapOf("id" to it.id, "filePath" to it.filePath, "status" to it.status, "progress" to it.progress, "batchId" to it.batchId)
						}
						result.success(list)
					}
				}
				"startTaggingNotification" -> {
					val title = (call.arguments as? Map<*, *>)?.get("title") as? String ?: "Tagging photos"
					val text = (call.arguments as? Map<*, *>)?.get("text") as? String ?: "Working..."
					NotificationHelper.showProgress(applicationContext, title, text, 0, 100)
					result.success(true)
				}
				"updateTaggingNotification" -> {
					val args = call.arguments as? Map<*, *>
					val progress = (args?.get("progress") as? Int) ?: 0
					val title = (args?.get("title") as? String) ?: "Tagging photos"
					val text = (args?.get("text") as? String) ?: "Working..."
					NotificationHelper.showProgress(applicationContext, title, text, progress, 100)
					result.success(true)
				}
				"stopTaggingNotification" -> {
					NotificationHelper.cancel(applicationContext)
					result.success(true)
				}
				else -> result.notImplemented()
			}
		}

		EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL).setStreamHandler(object : EventChannel.StreamHandler {
			override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
				com.example.kidconnect.upload.UploadEventBus.setSink(events)
			}

			override fun onCancel(arguments: Any?) {
				com.example.kidconnect.upload.UploadEventBus.setSink(null)
			}
		})
	}

	private fun enqueueFiles(batchId: String, files: List<String>, remoteUrl: String?) {
		val context = applicationContext
		CoroutineScope(Dispatchers.IO).launch {
			val repo = UploadRepository.getInstance(context)
			for (f in files) {
				repo.enqueue(batchId, f, null, remoteUrl)
			}

			// enqueue a unique WorkManager job to process the queue
			val work = OneTimeWorkRequestBuilder<UploadWorker>().build()
			WorkManager.getInstance(context).enqueueUniqueWork("upload_queue", ExistingWorkPolicy.KEEP, work)
		}
	}
}
