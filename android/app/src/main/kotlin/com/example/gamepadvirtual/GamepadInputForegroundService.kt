package com.example.gamepadvirtual

// Imports necessários. Note que SharedPreferences NÃO está aqui.
import android.os.VibrationEffect
import android.os.Vibrator
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.graphics.PixelFormat
import android.os.*
import android.provider.Settings
import android.view.Gravity
import android.view.InputDevice
import android.view.KeyEvent
import android.view.MotionEvent
import android.view.WindowManager
import androidx.core.app.NotificationCompat
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel

class GamepadInputForegroundService : Service() {
    
    private var wakeLock: PowerManager.WakeLock? = null
    private val CHANNEL = "gamepad_input_channel" 
    private var methodChannel: MethodChannel? = null
    private var windowManager: WindowManager? = null
    private var inputCaptureView: InputCaptureView? = null

    private var vibrator: Vibrator? = null
    // Esta variável é preenchida pela Intent, não mais pelo SharedPreferences
    private var isHapticFeedbackEnabled = true 

    companion object {
        const val NOTIFICATION_ID = 1001
        const val CHANNEL_ID = "gamepad_input_service"
        const val ACTION_START_SERVICE = "START_GAMEPAD_INPUT_SERVICE"
        const val ACTION_STOP_SERVICE = "STOP_GAMEPAD_INPUT_SERVICE" 
        var isServiceRunning = false
    }
    
    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        acquireWakeLock()
        initializeFlutterChannel()
        // Apenas inicializamos o Vibrator
        vibrator = getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_START_SERVICE -> {
                if (!isServiceRunning) {
                    // Lemos a configuração diretamente da Intent que iniciou o serviço
                    isHapticFeedbackEnabled = intent?.getBooleanExtra("HAPTICS_ENABLED", true) ?: true

                    val notification = createGamepadNotification()
                    startForeground(NOTIFICATION_ID, notification)
                    startInputCapture()
                    isServiceRunning = true
                }
            }
            ACTION_STOP_SERVICE -> {
                stopSelf()
            }
        }
        return START_STICKY
    }

    private fun handleGamepadButton(event: KeyEvent): Boolean {
        if (!isGamepadEvent(event) || !isGamepadKey(event.keyCode)) return false
        
        val isPressed = event.action == KeyEvent.ACTION_DOWN
        val buttonName = getButtonName(event.keyCode) // Corrigido para getButtonName
        
        if (buttonName != null) {
            if (isPressed) {
                triggerHapticFeedback()
            }
            methodChannel?.invokeMethod("onGamepadInput", mapOf("buttons" to mapOf(buttonName to isPressed)))
            return true
        }
        return false
    }

    private fun triggerHapticFeedback() {
        if (!isHapticFeedbackEnabled) return

        val duration = 50L
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            vibrator?.vibrate(VibrationEffect.createOneShot(duration, VibrationEffect.DEFAULT_AMPLITUDE))
        } else {
            @Suppress("DEPRECATION")
            vibrator?.vibrate(duration)
        }
    }

    // O resto do código (nenhuma alteração necessária)
    private fun initializeFlutterChannel() {
        val flutterEngine = FlutterEngine(this)
        flutterEngine.dartExecutor.executeDartEntrypoint(DartExecutor.DartEntrypoint.createDefault())
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
    }

    private fun acquireWakeLock() {
        val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
        wakeLock = powerManager.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "GamePadVirtual::InputWakeLock")
        wakeLock?.acquire(3600*1000L /* 1 hour */)
    }
    
    private fun startInputCapture() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && !Settings.canDrawOverlays(this)) {
            return
        }
        windowManager = getSystemService(Context.WINDOW_SERVICE) as WindowManager
        inputCaptureView = InputCaptureView(this)
        val params = WindowManager.LayoutParams(
            1, 1,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            else WindowManager.LayoutParams.TYPE_PHONE,
            WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE,
            PixelFormat.TRANSPARENT
        ).apply {
            gravity = Gravity.TOP or Gravity.START
            x = 0
            y = 0
        }
        windowManager?.addView(inputCaptureView, params)
        inputCaptureView?.requestFocus()
        inputCaptureView?.onInputEventListener = { event -> handleInputEvent(event) }
    }
    
    private fun handleInputEvent(event: Any): Boolean {
        return when (event) {
            is MotionEvent -> handleGamepadMotion(event)
            is KeyEvent -> handleGamepadButton(event)
            else -> false
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        sendServiceStatusToFlutter("STOPPED") 
        releaseWakeLock()
        if (inputCaptureView != null) {
            windowManager?.removeView(inputCaptureView)
        }
        inputCaptureView = null
        isServiceRunning = false
        stopForeground(true)
    }
    
    private fun releaseWakeLock() {
        wakeLock?.let { if (it.isHeld) it.release() }
        wakeLock = null
    }

    private fun sendServiceStatusToFlutter(status: String) {
        methodChannel?.invokeMethod("onServiceStatus", mapOf("status" to status))
    }
    
    private fun createGamepadNotification(): Notification {
        val notificationIntent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
        val pendingIntent = PendingIntent.getActivity(this, 0, notificationIntent, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
        val stopIntent = Intent(this, GamepadInputForegroundService::class.java).apply { action = ACTION_STOP_SERVICE }
        val stopPendingIntent = PendingIntent.getService(this, 1, stopIntent, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_CANCEL_CURRENT)

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("🎮 GamePadVirtual Ativo")
            .setContentText("Controle externo funcionando em segundo plano.")
            .setSmallIcon(android.R.drawable.stat_sys_data_bluetooth)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .addAction(android.R.drawable.ic_menu_close_clear_cancel, "Encerrar", stopPendingIntent)
            .build()
    }

    private fun handleGamepadMotion(event: MotionEvent): Boolean {
        if (!isGamepadEvent(event)) return false
        val analogData = mutableMapOf<String, Double>()
        analogData["leftX"] = getCenteredAxisValue(event, MotionEvent.AXIS_X)
        analogData["leftY"] = getCenteredAxisValue(event, MotionEvent.AXIS_Y)
        analogData["rightX"] = getCenteredAxisValue(event, MotionEvent.AXIS_Z)
        analogData["rightY"] = getCenteredAxisValue(event, MotionEvent.AXIS_RZ)
        analogData["leftTrigger"] = event.getAxisValue(MotionEvent.AXIS_LTRIGGER).toDouble()
        analogData["rightTrigger"] = event.getAxisValue(MotionEvent.AXIS_RTRIGGER).toDouble()
        analogData["dpadX"] = getCenteredAxisValue(event, MotionEvent.AXIS_HAT_X)
        analogData["dpadY"] = getCenteredAxisValue(event, MotionEvent.AXIS_HAT_Y)
        methodChannel?.invokeMethod("onGamepadInput", mapOf("analog" to analogData))
        return true
    }
    
    private fun getButtonName(keyCode: Int): String? {
        return when (keyCode) {
            KeyEvent.KEYCODE_BUTTON_A -> "BUTTON_A"; KeyEvent.KEYCODE_BUTTON_B -> "BUTTON_B"
            KeyEvent.KEYCODE_BUTTON_X -> "BUTTON_X"; KeyEvent.KEYCODE_BUTTON_Y -> "BUTTON_Y"
            KeyEvent.KEYCODE_BUTTON_L1 -> "BUTTON_L1"; KeyEvent.KEYCODE_BUTTON_R1 -> "BUTTON_R1"
            KeyEvent.KEYCODE_BUTTON_L2 -> "BUTTON_L2"; KeyEvent.KEYCODE_BUTTON_R2 -> "BUTTON_R2"
            KeyEvent.KEYCODE_BUTTON_THUMBL -> "BUTTON_LEFT_STICK"; KeyEvent.KEYCODE_BUTTON_THUMBR -> "BUTTON_RIGHT_STICK"
            KeyEvent.KEYCODE_BUTTON_START -> "BUTTON_START"; KeyEvent.KEYCODE_BUTTON_SELECT -> "BUTTON_SELECT"
            KeyEvent.KEYCODE_DPAD_UP -> "DPAD_UP"; KeyEvent.KEYCODE_DPAD_DOWN -> "DPAD_DOWN"
            KeyEvent.KEYCODE_DPAD_LEFT -> "DPAD_LEFT"; KeyEvent.KEYCODE_DPAD_RIGHT -> "DPAD_RIGHT"
            else -> null
        }
    }
    
    private fun isGamepadEvent(event: MotionEvent): Boolean = (event.source and InputDevice.SOURCE_GAMEPAD) != 0
    private fun isGamepadEvent(event: KeyEvent): Boolean = (event.source and InputDevice.SOURCE_GAMEPAD) != 0
    private fun isGamepadKey(keyCode: Int): Boolean = KeyEvent.isGamepadButton(keyCode) ||
            keyCode in listOf(KeyEvent.KEYCODE_DPAD_UP, KeyEvent.KEYCODE_DPAD_DOWN, KeyEvent.KEYCODE_DPAD_LEFT, KeyEvent.KEYCODE_DPAD_RIGHT)
    private fun getCenteredAxisValue(event: MotionEvent, axis: Int): Double {
        val value = event.getAxisValue(axis)
        return if (kotlin.math.abs(value) > 0.1f) value.toDouble() else 0.0
    }
    override fun onBind(intent: Intent?): IBinder? = null
    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(CHANNEL_ID, "Gamepad Input Service", NotificationManager.IMPORTANCE_LOW).apply {
                description = "Captura inputs do gamepad em segundo plano."
                setShowBadge(false)
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC
            }
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
        }
    }
}