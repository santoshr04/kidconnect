package com.example.kidconnect.upload

import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.EventChannel

object UploadEventBus {
    private var sink: EventChannel.EventSink? = null
    private val main = Handler(Looper.getMainLooper())

    fun setSink(s: EventChannel.EventSink?) {
        sink = s
    }

    fun send(event: Map<String, Any>) {
        main.post {
            sink?.success(event)
        }
    }
}
