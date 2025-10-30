import 'package:flutter/foundation.dart';
import 'package:gamepadvirtual/models/gamepad_input_data.dart';
import 'package:gamepadvirtual/models/gamepad_layout.dart';
import 'package:gamepadvirtual/services/sensor_service.dart';

class GamepadStateService with ChangeNotifier {
  
  final Map<ButtonType, bool> buttonStates = {};
  double leftStickX = 0, leftStickY = 0;
  double rightStickX = 0, rightStickY = 0;
  double leftTriggerValue = 0.0, rightTriggerValue = 0.0;
  
  double gyroX = 0.0, gyroY = 0.0, gyroZ = 0.0;
  double accelX = 0.0, accelY = 0.0, accelZ = 0.0;

  bool _hasNewInput = false;
  bool get hasNewInput => _hasNewInput;

  void initialize() {
    for (final type in ButtonType.values) {
      buttonStates[type] = false;
    }
  }

  void onButtonPressed(ButtonType buttonType) {
    if (buttonType == ButtonType.leftTrigger) {
      leftTriggerValue = 1.0;
    } else if (buttonType == ButtonType.rightTrigger) {
      rightTriggerValue = 1.0;
    } else {
      buttonStates[buttonType] = true;
    }
    _hasNewInput = true;
    notifyListeners();
  }

  void onButtonReleased(ButtonType buttonType) {
    if (buttonType == ButtonType.leftTrigger) {
      leftTriggerValue = 0.0;
    } else if (buttonType == ButtonType.rightTrigger) {
      rightTriggerValue = 0.0;
    } else {
      buttonStates[buttonType] = false;
    }
    _hasNewInput = true;
    notifyListeners();
  }
  
  void onAnalogStickChanged(bool isLeft, double x, double y) {
    if (isLeft) {
      leftStickX = x; 
      leftStickY = y;
    } else {
      rightStickX = x; 
      rightStickY = y;
    }
    _hasNewInput = true;
    notifyListeners();
  }

  void updateGyroState(SensorData gyroData, bool isEnabled) {
    if (isEnabled) {
      gyroX = gyroData.x; 
      gyroY = gyroData.y; 
      gyroZ = gyroData.z;
    } else {
      gyroX = 0.0; gyroY = 0.0; gyroZ = 0.0;
    }
    _hasNewInput = true; 
  }

  void updateAccelState(SensorData accelData, bool isEnabled) {
     if (isEnabled) {
      accelX = accelData.x; 
      accelY = accelData.y; 
      accelZ = accelData.z;
    } else {
      accelX = 0.0; accelY = 0.0; accelZ = 0.0;
    }
    _hasNewInput = true;
  }
  
  void updateButtonsFromExternal(Map<String, bool> externalButtons, Map<String, ButtonType> mapping) {
    externalButtons.forEach((key, isPressed) {
      final buttonType = mapping[key];
      if (buttonType != null) {
        if (buttonType == ButtonType.leftTrigger) {
          leftTriggerValue = isPressed ? 1.0 : 0.0;
        } else if (buttonType == ButtonType.rightTrigger) {
          rightTriggerValue = isPressed ? 1.0 : 0.0;
        } else {
          buttonStates[buttonType] = isPressed;
        }
      }
    });
    _hasNewInput = true;
    notifyListeners();
  }

  void updateAnalogsFromExternal(Map<String, double> analogData) {
    leftStickX = analogData['leftX'] ?? leftStickX;
    leftStickY = analogData['leftY'] ?? leftStickY;
    rightStickX = analogData['rightX'] ?? rightStickX;
    rightStickY = analogData['rightY'] ?? rightStickY;
    leftTriggerValue = analogData['leftTrigger'] ?? leftTriggerValue;
    rightTriggerValue = analogData['rightTrigger'] ?? rightTriggerValue;
    
    final dpadX = analogData['dpadX'] ?? 0.0;
    final dpadY = analogData['dpadY'] ?? 0.0;
    buttonStates[ButtonType.dpadUp] = dpadY < -0.5;
    buttonStates[ButtonType.dpadDown] = dpadY > 0.5;
    buttonStates[ButtonType.dpadLeft] = dpadX < -0.5;
    buttonStates[ButtonType.dpadRight] = dpadX > 0.5;
    
    _hasNewInput = true;
    notifyListeners();
  }

  void clearInputFlag() {
    _hasNewInput = false;
  }

  GamepadInputData getGamepadInputData() {
    return GamepadInputData(
      buttons: buttonStates,
      analogSticks: {
        'leftX': leftStickX, 'leftY': leftStickY,
        'rightX': rightStickX, 'rightY': rightStickY,
        'leftTrigger': leftTriggerValue, 'rightTrigger': rightTriggerValue,
      },
      sensors: {
        'gyroX': gyroX, 'gyroY': gyroY, 'gyroZ': gyroZ,
        'accelX': accelX, 'accelY': accelY, 'accelZ': accelZ,
      },
      timestamp: DateTime.now(),
    );
  }
}