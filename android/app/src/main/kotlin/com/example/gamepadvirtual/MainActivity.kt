package com.example.gamepadvirtual

import android.annotation.SuppressLint
import android.content.Context
import android.content.Intent
import android.hardware.input.InputManager
import android.os.Build
import android.view.InputDevice
import android.view.KeyEvent
import android.view.MotionEvent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import kotlin.math.abs
import android.Manifest
import android.content.pm.PackageManager
import androidx.core.content.ContextCompat

class MainActivity: FlutterActivity() {
    private val CHANNEL = "gamepad_input_channel"
    private var inputManager: InputManager? = null
    private var currentGamepadDevice: InputDevice? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)
    
    MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
        when (call.method) {
            "initializeGamepadDetection" -> {
                initializeGamepadDetection()
                result.success(null)
            }
            // ADICIONADO: Novo método para verificar o estado inicial
            "getInitialGamepadState" -> {
                if (currentGamepadDevice != null) {
                    result.success(mapOf(
                        "deviceName" to currentGamepadDevice!!.name, 
                        "deviceId" to currentGamepadDevice!!.id
                    ))
                } else {
                    result.success(null)
                }
            }
            else -> result.notImplemented()
        }
    }
}

    
    @SuppressLint("NewApi")
    private fun initializeGamepadDetection() {
        inputManager = getSystemService(Context.INPUT_SERVICE) as InputManager
        
        inputManager?.registerInputDeviceListener(object : InputManager.InputDeviceListener {
            override fun onInputDeviceAdded(deviceId: Int) {
                val device = InputDevice.getDevice(deviceId)
                if (device != null && isGamepad(device)) {
                    currentGamepadDevice = device
                    sendGamepadConnected(device)
                }
            }
            
            override fun onInputDeviceRemoved(deviceId: Int) {
                if (currentGamepadDevice?.id == deviceId) {
                    currentGamepadDevice = null
                    sendGamepadDisconnected()
                }
            }
            
            override fun onInputDeviceChanged(deviceId: Int) {
                val device = InputDevice.getDevice(deviceId)
                if (device != null && isGamepad(device)) {
                    currentGamepadDevice = device
                }
            }
        }, null)
        
        checkConnectedGamepads()
    }
    
    private fun checkConnectedGamepads() {
        val deviceIds = InputDevice.getDeviceIds()
        for (deviceId in deviceIds) {
            val device = InputDevice.getDevice(deviceId)
            if (device != null && isGamepad(device)) {
                currentGamepadDevice = device
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
    
    private fun startBackgroundService() {
        val serviceIntent = Intent(this, GamepadBackgroundService::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            if (ContextCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
                // Se a permissão não foi concedida, não inicie o serviço para evitar o crash.
                // Opcional: Enviar uma mensagem de volta ao Flutter para informar sobre a falha.
                println("Permissão de notificação negada. Não é possível iniciar o serviço em segundo plano.")
                return 
            }
        }
    }

    private fun stopBackgroundService() {
        val serviceIntent = Intent(this, GamepadBackgroundService::class.java)
        stopService(serviceIntent)
    }

    private fun sendGamepadConnected(device: InputDevice) {
        startBackgroundService() // Inicia o serviço
        flutterEngine?.dartExecutor?.binaryMessenger?.let {
            MethodChannel(it, CHANNEL).invokeMethod(
                "onGamepadConnected", 
                mapOf("deviceName" to device.name, "deviceId" to device.id)
            )
        }
    }
    
    private fun sendGamepadDisconnected() {
        stopBackgroundService() // Para o serviço
        flutterEngine?.dartExecutor?.binaryMessenger?.let {
            MethodChannel(it, CHANNEL).invokeMethod("onGamepadDisconnected", null)
        }
    }
    
    override fun onGenericMotionEvent(event: MotionEvent): Boolean {
        if (isGamepadEvent(event)) {
            handleGamepadMotion(event)
            return true
        }
        return super.onGenericMotionEvent(event)
    }
    
    override fun onKeyDown(keyCode: Int, event: KeyEvent): Boolean {
        if (isGamepadEvent(event) && isGamepadKey(keyCode)) {
            handleGamepadButton(keyCode, true)
            return true
        }
        return super.onKeyDown(keyCode, event)
    }
    
    override fun onKeyUp(keyCode: Int, event: KeyEvent): Boolean {
        if (isGamepadEvent(event) && isGamepadKey(keyCode)) {
            handleGamepadButton(keyCode, false)
            return true
        }
        return super.onKeyUp(keyCode, event)
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
    
    @SuppressLint("InlinedApi")
    private fun handleGamepadMotion(event: MotionEvent) {
        val analogData = mutableMapOf<String, Double>()
        analogData["leftX"] = getCenteredAxisValue(event, MotionEvent.AXIS_X)
        analogData["leftY"] = getCenteredAxisValue(event, MotionEvent.AXIS_Y)
        analogData["rightX"] = getCenteredAxisValue(event, MotionEvent.AXIS_Z)
        analogData["rightY"] = getCenteredAxisValue(event, MotionEvent.AXIS_RZ)
        analogData["leftTrigger"] = event.getAxisValue(MotionEvent.AXIS_LTRIGGER).toDouble()
        analogData["rightTrigger"] = event.getAxisValue(MotionEvent.AXIS_RTRIGGER).toDouble()
        analogData["dpadX"] = getCenteredAxisValue(event, MotionEvent.AXIS_HAT_X)
        analogData["dpadY"] = getCenteredAxisValue(event, MotionEvent.AXIS_HAT_Y)
        
        flutterEngine?.dartExecutor?.binaryMessenger?.let {
            MethodChannel(it, CHANNEL).invokeMethod(
                "onGamepadInput",
                mapOf("analog" to analogData)
            )
        }
    }
    
    private fun getCenteredAxisValue(event: MotionEvent, axis: Int): Double {
        val value = event.getAxisValue(axis)
        return if (abs(value) > 0.1f) value.toDouble() else 0.0
    }
    
    private fun handleGamepadButton(keyCode: Int, isPressed: Boolean) {
        val buttonName = when (keyCode) {
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
            flutterEngine?.dartExecutor?.binaryMessenger?.let {
                MethodChannel(it, CHANNEL).invokeMethod(
                    "onGamepadInput",
                    mapOf("buttons" to mapOf(buttonName to isPressed))
                )
            }
        }
    }
    
    override fun onResume() {
        super.onResume()
        checkConnectedGamepads()
    }
}