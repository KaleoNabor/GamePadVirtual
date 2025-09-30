package com.example.gamepadvirtual

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.*
// ADICIONADO: Import necessário para o NotificationCompat.Builder
import androidx.core.app.NotificationCompat

class GamepadInputForegroundService : Service() {
    
    private var wakeLock: PowerManager.WakeLock? = null

    companion object {
        const val NOTIFICATION_ID = 1001
        const val CHANNEL_ID = "gamepad_input_service"
        const val ACTION_START_SERVICE = "START_GAMEPAD_INPUT_SERVICE"
        const val ACTION_STOP_SERVICE = "STOP_GAMEPAD_INPUT_SERVICE"
    }
    
    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        acquireWakeLock()
    }
    
    private fun acquireWakeLock() {
        try {
            val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
            wakeLock = powerManager.newWakeLock(
                PowerManager.PARTIAL_WAKE_LOCK,
                "GamePadVirtual::InputWakeLock"
            )
            wakeLock?.acquire()
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }
    
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_START_SERVICE -> {
                val notification = createGamepadNotification()
                startForeground(NOTIFICATION_ID, notification)
            }
            ACTION_STOP_SERVICE -> {
                stopSelf() // Para o serviço
            }
        }
        return START_STICKY
    }
    
    override fun onBind(intent: Intent?): IBinder? = null
    
    override fun onDestroy() {
        super.onDestroy()
        wakeLock?.let {
            if (it.isHeld) {
                it.release()
            }
        }
        stopForeground(true)
    }
    
    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Gamepad Input Service",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Captura inputs do gamepad mesmo com tela bloqueada"
                setShowBadge(false)
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC
            }
            
            // CORREÇÃO: Usar ::class.java em vez de .class.java para a sintaxe do Kotlin
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
        }
    }
    
    private fun createGamepadNotification(): Notification {
        val notificationIntent = Intent(this, MainActivity::class.java)
        val pendingIntent = PendingIntent.getActivity(
            this, 0, notificationIntent,
            PendingIntent.FLAG_IMMUTABLE
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("🎮 GamePadVirtual Ativo")
            .setContentText("O controle está funcionando em segundo plano.")
            .setSmallIcon(android.R.drawable.ic_media_play)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()
    }
}