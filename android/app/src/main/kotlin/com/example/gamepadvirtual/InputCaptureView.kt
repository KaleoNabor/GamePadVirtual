package com.example.gamepadvirtual

import android.content.Context
import android.util.Log
import android.view.KeyEvent
import android.view.MotionEvent
import android.view.View

class InputCaptureView(context: Context) : View(context) {
    var onInputEventListener: ((event: Any) -> Boolean)? = null

    override fun onAttachedToWindow() {
        super.onAttachedToWindow()
        isFocusableInTouchMode = true
        requestFocus()
    }

    // MODIFICADO: Garante que o evento seja consumido (retorna true)
    override fun onKeyDown(keyCode: Int, event: KeyEvent): Boolean {
        // Se o evento for de um gamepad, nós o processamos e consumimos.
        if ((event.source and android.view.InputDevice.SOURCE_GAMEPAD) == android.view.InputDevice.SOURCE_GAMEPAD) {
            onInputEventListener?.invoke(event)
            return true // Retorna 'true' para consumir o evento e impedir que o sistema o utilize.
        }
        return super.onKeyDown(keyCode, event)
    }

    // MODIFICADO: Garante que o evento seja consumido (retorna true)
    override fun onKeyUp(keyCode: Int, event: KeyEvent): Boolean {
        if ((event.source and android.view.InputDevice.SOURCE_GAMEPAD) == android.view.InputDevice.SOURCE_GAMEPAD) {
            onInputEventListener?.invoke(event)
            return true // Consome o evento.
        }
        return super.onKeyUp(keyCode, event)
    }

    // MODIFICADO: Garante que o evento seja consumido (retorna true)
    override fun onGenericMotionEvent(event: MotionEvent): Boolean {
        if ((event.source and android.view.InputDevice.SOURCE_JOYSTICK) == android.view.InputDevice.SOURCE_JOYSTICK) {
            onInputEventListener?.invoke(event)
            return true // Consome o evento.
        }
        return super.onGenericMotionEvent(event)
    }
}