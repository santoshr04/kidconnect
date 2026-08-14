package com.example.kidconnect

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat

object NotificationHelper {
    private const val TAG_CHANNEL_ID = "tagging_channel"
    private const val TAG_NOTIF_ID = 2001

    fun ensureChannel(context: Context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            val chan = NotificationChannel(TAG_CHANNEL_ID, "Tagging", NotificationManager.IMPORTANCE_LOW)
            nm.createNotificationChannel(chan)
        }
    }

    fun showProgress(context: Context, title: String, text: String, progress: Int, max: Int = 100) {
        ensureChannel(context)
        val notif = NotificationCompat.Builder(context, TAG_CHANNEL_ID)
            .setContentTitle(title)
            .setContentText(text)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setOngoing(true)
            .setProgress(max, progress, false)
            .build()
        with(NotificationManagerCompat.from(context)) { notify(TAG_NOTIF_ID, notif) }
    }

    fun cancel(context: Context) {
        with(NotificationManagerCompat.from(context)) { cancel(TAG_NOTIF_ID) }
    }
}
