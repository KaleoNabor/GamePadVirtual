package com.example.gamepadvirtual

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.hardware.input.InputManager
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import android.view.InputDevice
import android.view.KeyEvent
import android.view.MotionEvent
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel

class GamepadForegroundService : Service() {
    
    private var wakeLock: PowerManager.WakeLock? = null
    private var inputManager: InputManager? = null
    private var methodChannel: MethodChannel? = null
    private var isServiceRunning = false

    companion object {
        const val NOTIFICATION_ID = 1001
        const val CHANNEL_ID = "gamepad_foreground_service"
        const val ACTION_START_SERVICE = "START_FOREGROUND_SERVICE"
        const val ACTION_STOP_SERVICE = "STOP_FOREGROUND_SERVICE"
    }
    
    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        initializeFlutterEngine()
        acquireWakeLock()
    }
    
    private fun initializeFlutterEngine() {
        val flutterEngine = FlutterEngine(this)
        flutterEngine.dartExecutor.executeDartEntrypoint(
            DartExecutor.DartEntrypoint.createDefault()
        )
        
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "gamepad_input_channel")
    }
    
    private fun acquireWakeLock() {
        try {
            val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
            wakeLock = powerManager.newWakeLock(
                PowerManager.PARTIAL_WAKE_LOCK or PowerManager.ACQUIRE_CAUSES_WAKEUP,
                "GamePadVirtual::ForegroundService"
            )
            wakeLock?.acquire()
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }
    
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_START_SERVICE -> {
                startForegroundService()
            }
            ACTION_STOP_SERVICE -> {
                stopForegroundService()
            }
        }
        return START_STICKY
    }
    
    private fun startForegroundService() {
        val notification = createNotification()
        startForeground(NOTIFICATION_ID, notification)
        isServiceRunning = true
        startInputMonitoring()
    }
    
    private fun stopForegroundService() {
        stopForeground(true)
        stopSelf()
        isServiceRunning = false
        stopInputMonitoring()
    }
    
    private fun startInputMonitoring() {
        inputManager = getSystemService(Context.INPUT_SERVICE) as InputManager
        
        // Monitora gamepads conectados
        inputManager?.registerInputDeviceListener(object : InputManager.InputDeviceListener {
            override fun onInputDeviceAdded(deviceId: Int) {
                val device = InputDevice.getDevice(deviceId)
                if (device != null && isGamepad(device)) {
                    sendGamepadConnected(device)
                }
            }
            
            override fun onInputDeviceRemoved(deviceId: Int) {
                sendGamepadDisconnected()
            }
            
            override fun onInputDeviceChanged(deviceId: Int) {
                // Dispositivo alterado
            }
        }, null)
        
        // Verifica gamepads já conectados
        checkConnectedGamepads()
    }
    
    private fun stopInputMonitoring() {
        inputManager?.unregisterInputDeviceListener(null)
    }
    
    private fun checkConnectedGamepads() {
        val deviceIds = InputDevice.getDeviceIds()
        for (deviceId in deviceIds) {
            val device = InputDevice.getDevice(deviceId)
            if (device != null && isGamepad(device)) {
                sendGamepadConnected(device)
                break
            }
        }
    }
    
    private fun isGamepad(device: InputDevice): Boolean {
        val sources = device.sources
        return (sources and InputDevice.SOURCE_GAMEPAD) == InputDevice.SOURCE_GAMEPAD ||
               (sources and InputDevice.SOURCE_JOYSTICK) == InputDevice.SOURCE_JOYSTICK
    }
    
    // Método público para receber eventos da MainActivity
    fun handleInputEvent(event: Any): Boolean {
        if (!isServiceRunning) return false
        
        return when (event) {
            is MotionEvent -> handleMotionEvent(event)
            is KeyEvent -> handleKeyEvent(event)
            else -> false
        }
    }
    
    private fun handleMotionEvent(event: MotionEvent): Boolean {
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
    
    private fun handleKeyEvent(event: KeyEvent): Boolean {
        if (!isGamepadEvent(event) || !isGamepadKey(event.keyCode)) return false
        
        val isPressed = event.action == KeyEvent.ACTION_DOWN
        val buttonName = when (event.keyCode) {
            KeyEvent.KEYCODE_BUTTON_A -> "BUTTON_A"
            KeyEvent.KEYCODE_BUTTON_B -> "BUTTON_B"
            KeyEvent.KEYCODE_BUTTON_X -> "BUTTON_X"
            KeyEvent.KEYCODE_BUTTON_Y -> "BUTTON_Y"
            KeyEvent.KEYCODE_BUTTON_L1 -> "BUTTON_L1"
            KeyEvent.KEYCODE_BUTTON_R1 -> "BUTTON_R1"
            KeyEvent.KEYCODE_BUTTON_L2 -> "BUTTON_L2"
            KeyEvent.KEYCODE_BUTTON_R2 -> "BUTTON_R2"
            KeyEvent.KEYCODE_BUTTON_THUMBL -> "BUTTON_LEFT_STICK"
            KeyEvent.KEYCODE_BUTTON_THUMBR -> "BUTTON_RIGHT_STICK"
            KeyEvent.KEYCODE_BUTTON_START -> "BUTTON_START"
            KeyEvent.KEYCODE_BUTTON_SELECT -> "BUTTON_SELECT"
            KeyEvent.KEYCODE_DPAD_UP -> "DPAD_UP"
            KeyEvent.KEYCODE_DPAD_DOWN -> "DPAD_DOWN"
            KeyEvent.KEYCODE_DPAD_LEFT -> "DPAD_LEFT"
            KeyEvent.KEYCODE_DPAD_RIGHT -> "DPAD_RIGHT"
            else -> null
        }
        
        if (buttonName != null) {
            methodChannel?.invokeMethod("onGamepadInput", mapOf("buttons" to mapOf(buttonName to isPressed)))
            return true
        }
        return false
    }
    
    private fun isGamepadEvent(event: MotionEvent): Boolean {
        return (event.source and InputDevice.SOURCE_JOYSTICK) == InputDevice.SOURCE_JOYSTICK ||
               (event.source and InputDevice.SOURCE_GAMEPAD) == InputDevice.SOURCE_GAMEPAD
    }
    
    private fun isGamepadEvent(event: KeyEvent): Boolean {
        return (event.source and InputDevice.SOURCE_DPAD) == InputDevice.SOURCE_DPAD ||
               (event.source and InputDevice.SOURCE_GAMEPAD) == InputDevice.SOURCE_GAMEPAD
    }

    private fun isGamepadKey(keyCode: Int): Boolean {
        return KeyEvent.isGamepadButton(keyCode) || when (keyCode) {
            KeyEvent.KEYCODE_DPAD_UP, KeyEvent.KEYCODE_DPAD_DOWN,
            KeyEvent.KEYCODE_DPAD_LEFT, KeyEvent.KEYCODE_DPAD_RIGHT,
            KeyEvent.KEYCODE_DPAD_CENTER -> true
            else -> false
        }
    }
    
    private fun getCenteredAxisValue(event: MotionEvent, axis: Int): Double {
        val value = event.getAxisValue(axis)
        return if (kotlin.math.abs(value) > 0.1f) value.toDouble() else 0.0
    }
    
    private fun sendGamepadConnected(device: InputDevice) {
        methodChannel?.invokeMethod(
            "onGamepadConnected", 
            mapOf("deviceName" to device.name, "deviceId" to device.id)
        )
    }
    
    private fun sendGamepadDisconnected() {
        methodChannel?.invokeMethod("onGamepadDisconnected", null)
    }
    
    override fun onBind(intent: Intent?): IBinder? = null
    
    override fun onDestroy() {
        super.onDestroy()
        wakeLock?.let {
            if (it.isHeld) {
                it.release()
            }
        }
        stopInputMonitoring()
    }
    
    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Gamepad Virtual Service",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Mantém o gamepad virtual funcionando com tela bloqueada"
                setShowBadge(false)
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC
            }
            
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
        }
    }
    
    private fun createNotification(): Notification {
        val intent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
        }
        
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
                .setContentTitle("GamePadVirtual Ativo")
                .setContentText("Gamepad funcionando - Toque para abrir")
                .setSmallIcon(android.R.drawable.ic_media_play)
                .setPriority(Notification.PRIORITY_LOW)
                .setOngoing(true)
                .build()
        } else {
            Notification.Builder(this)
                .setContentTitle("GamePadVirtual Ativo")
                .setContentText("Gamepad funcionando - Toque para abrir")
                .setSmallIcon(android.R.drawable.ic_media_play)
                .setPriority(Notification.PRIORITY_LOW)
                .setOngoing(true)
                .build()
        }
    }
}