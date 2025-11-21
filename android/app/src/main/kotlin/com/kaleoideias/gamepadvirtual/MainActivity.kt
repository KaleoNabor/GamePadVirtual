package com.kaleoideias.gamepadvirtual

import android.annotation.SuppressLint
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.hardware.input.InputManager
import android.os.Build
import android.os.Vibrator
import android.os.VibrationEffect
import android.view.InputDevice
import android.view.KeyEvent
import android.view.MotionEvent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    // --- Canais de Comunicação com o Flutter ---
    private val GAMEPAD_CHANNEL = "gamepad_input_channel"
    private val DISCOVERY_CHANNEL = "com.example.gamepadvirtual/discovery"

    private var gamepadInputChannel: MethodChannel? = null
    private var discoveryChannel: MethodChannel? = null

    // --- Variáveis para Detecção de Gamepad Externo ---
    private var inputManager: InputManager? = null
    private var currentGamepadDevice: InputDevice? = null

    // Variável para o Vibrator
    private var vibrator: Vibrator? = null

    // --- Receptor para o Serviço de Descoberta ---
    private val serverFoundReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            val serverName = intent.getStringExtra(DiscoveryService.EXTRA_SERVER_NAME)
            val serverIp = intent.getStringExtra(DiscoveryService.EXTRA_SERVER_IP)
            // Envia o servidor encontrado de volta para o Flutter através do canal de descoberta
            discoveryChannel?.invokeMethod("serverFound", mapOf("name" to serverName, "ip" to serverIp))
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Inicialize o Vibrator
        vibrator = getSystemService(Context.VIBRATOR_SERVICE) as Vibrator

        // --- Configuração do Canal de Gamepad Externo ---
        gamepadInputChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, GAMEPAD_CHANNEL)
        gamepadInputChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "initializeGamepadDetection" -> {
                    initializeGamepadDetection()
                    result.success(null)
                }
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
                // Os casos "startGamepadService" e "stopGamepadService" foram removidos
                else -> result.notImplemented()
            }
        }

        // --- Configuração do Canal de Descoberta de Rede ---
        discoveryChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, DISCOVERY_CHANNEL)
        discoveryChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "startDiscovery" -> {
                    startDiscoveryService()
                    result.success(null)
                }
                "stopDiscovery" -> {
                    stopDiscoveryService()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    // --- Ciclo de Vida da Activity para o Receptor de Descoberta ---
    override fun onResume() {
        super.onResume()
        // Verifica gamepads conectados ao resumir a activity
        checkConnectedGamepads()
        // Registra o receptor para ouvir por servidores encontrados pelo DiscoveryService
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(serverFoundReceiver, IntentFilter(DiscoveryService.SERVER_FOUND_ACTION), RECEIVER_EXPORTED)
        } else {
            registerReceiver(serverFoundReceiver, IntentFilter(DiscoveryService.SERVER_FOUND_ACTION))
        }
    }

    override fun onPause() {
        super.onPause()
        // Desregistra o receptor para evitar vazamentos de memória
        unregisterReceiver(serverFoundReceiver)
    }

    // --- Funções para controlar o Serviço de Descoberta ---
    private fun startDiscoveryService() {
        val intent = Intent(this, DiscoveryService::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(intent)
        } else {
            startService(intent)
        }
    }

    private fun stopDiscoveryService() {
        val intent = Intent(this, DiscoveryService::class.java)
        stopService(intent)
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

    private fun sendGamepadConnected(device: InputDevice) {
        flutterEngine?.dartExecutor?.binaryMessenger?.let {
            MethodChannel(it, GAMEPAD_CHANNEL).invokeMethod(
                "onGamepadConnected",
                mapOf("deviceName" to device.name, "deviceId" to device.id)
            )
        }
    }

    private fun sendGamepadDisconnected() {
        flutterEngine?.dartExecutor?.binaryMessenger?.let {
            MethodChannel(it, GAMEPAD_CHANNEL).invokeMethod("onGamepadDisconnected", null)
        }
    }

    // Handlers de input SEM as verificações do serviço
    override fun onGenericMotionEvent(event: MotionEvent): Boolean {
        // A verificação do serviço foi removida
        if (isGamepadEvent(event)) {
            handleGamepadMotion(event)
            return true
        }
        return super.onGenericMotionEvent(event)
    }

    override fun onKeyDown(keyCode: Int, event: KeyEvent): Boolean {
        // A verificação do serviço foi removida
        if (isGamepadEvent(event) && isGamepadKey(keyCode)) {
            handleGamepadButton(keyCode, true)
            return true
        }
        return super.onKeyDown(keyCode, event)
    }

    override fun onKeyUp(keyCode: Int, event: KeyEvent): Boolean {
        // A verificação do serviço foi removida
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
            MethodChannel(it, GAMEPAD_CHANNEL).invokeMethod(
                "onGamepadInput",
                mapOf("analog" to analogData)
            )
        }
    }

    private fun getCenteredAxisValue(event: MotionEvent, axis: Int): Double {
        val value = event.getAxisValue(axis)
        return if (kotlin.math.abs(value) > 0.1f) value.toDouble() else 0.0
    }

    // --- FUNÇÃO REMOVIDA (OU ESVAZIADA) ---
    private fun triggerHapticFeedback() {
        // (Vazio) - A vibração não é mais disparada aqui
    }

    private fun handleGamepadButton(keyCode: Int, isPressed: Boolean) {
        // --- CHAMADA REMOVIDA ---
        // if (isPressed) {
        //     triggerHapticFeedback()
        // }

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
                MethodChannel(it, GAMEPAD_CHANNEL).invokeMethod(
                    "onGamepadInput",
                    mapOf("buttons" to mapOf(buttonName to isPressed))
                )
            }
        }
    }
}