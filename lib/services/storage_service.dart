// lib/services/storage_service.dart

import 'dart:convert';
import 'package:gamepadvirtual/core/default_layout.dart';
import 'package:gamepadvirtual/models/button_layout_config.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gamepadvirtual/models/gamepad_layout.dart';

class StorageService {
  // Chaves para armazenamento de preferências
  static const String _selectedLayoutKey = 'selected_layout';
  static const String _hapticFeedbackEnabledKey = 'haptic_feedback_enabled';
  static const String _rumbleEnabledKey = 'rumble_enabled';
  static const String _gyroscopeEnabledKey = 'gyroscope_enabled';
  static const String _accelerometerEnabledKey = 'accelerometer_enabled';
  static const String _externalDigitalTriggersKey = 'external_digital_triggers';
  static const String _customLayoutBaseKey = 'custom_layout_base';

  // Chaves separadas para layouts customizados por tipo
  static const String _customLayoutKey_Xbox = 'custom_layout_config_xbox';
  static const String _customLayoutKey_PlayStation = 'custom_layout_config_playstation';
  static const String _customLayoutKey_Nintendo = 'custom_layout_config_nintendo';

  // Métodos para gerenciamento de layout selecionado
  Future<GamepadLayoutType> getSelectedLayout() async {
    final prefs = await SharedPreferences.getInstance();
    final layoutString = prefs.getString(_selectedLayoutKey);
    if (layoutString != null) {
      return GamepadLayoutType.values.firstWhere(
        (e) => e.toString() == layoutString,
        orElse: () => GamepadLayoutType.xbox,
      );
    }
    return GamepadLayoutType.xbox;
  }

  Future<void> setSelectedLayout(GamepadLayoutType layout) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_selectedLayoutKey, layout.toString());
  }

  // Métodos para gerenciamento do layout base da personalização
  Future<void> setCustomLayoutBase(GamepadLayoutType layout) async {
    final prefs = await SharedPreferences.getInstance();
    if (layout == GamepadLayoutType.custom) return;
    await prefs.setString(_customLayoutBaseKey, layout.toString());
  }

  Future<GamepadLayoutType> getCustomLayoutBase() async {
    final prefs = await SharedPreferences.getInstance();
    final layoutString = prefs.getString(_customLayoutBaseKey);
    if (layoutString != null) {
      return GamepadLayoutType.values.firstWhere(
        (e) => e.toString() == layoutString,
        orElse: () => GamepadLayoutType.xbox,
      );
    }
    return GamepadLayoutType.xbox;
  }

  // Métodos para configurações de funcionalidades
  Future<bool> isHapticFeedbackEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_hapticFeedbackEnabledKey) ?? true;
  }

  Future<void> setHapticFeedbackEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_hapticFeedbackEnabledKey, enabled);
  }

  Future<bool> isRumbleEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_rumbleEnabledKey) ?? true;
  }

  Future<void> setRumbleEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_rumbleEnabledKey, enabled);
  }

  Future<bool> isGyroscopeEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_gyroscopeEnabledKey) ?? true;
  }

  Future<void> setGyroscopeEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_gyroscopeEnabledKey, enabled);
  }

  Future<bool> isAccelerometerEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_accelerometerEnabledKey) ?? true;
  }

  Future<void> setAccelerometerEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_accelerometerEnabledKey, enabled);
  }

  Future<bool> isExternalDigitalTriggersEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_externalDigitalTriggersKey) ?? false;
  }

  Future<void> setExternalDigitalTriggersEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_externalDigitalTriggersKey, enabled);
  }

  // Método auxiliar para obter chave de armazenamento baseada no tipo de layout
  String _getStorageKeyForLayout(GamepadLayoutType baseType) {
    switch (baseType) {
      case GamepadLayoutType.playstation:
        return _customLayoutKey_PlayStation;
      case GamepadLayoutType.nintendo:
        return _customLayoutKey_Nintendo;
      case GamepadLayoutType.xbox:
      default:
        return _customLayoutKey_Xbox;
    }
  }

  // Métodos para gerenciamento de layouts customizados
  Future<void> saveCustomLayout(List<ButtonLayoutConfig> layout, GamepadLayoutType baseType) async {
    final prefs = await SharedPreferences.getInstance();
    final String key = _getStorageKeyForLayout(baseType);
    
    final List<Map<String, dynamic>> jsonList =
        layout.map((config) => config.toJson()).toList();
    final String jsonString = jsonEncode(jsonList);
    await prefs.setString(key, jsonString);
  }

  Future<List<ButtonLayoutConfig>> loadCustomLayout(GamepadLayoutType baseType) async {
    final prefs = await SharedPreferences.getInstance();
    final String key = _getStorageKeyForLayout(baseType);
    final String? jsonString = prefs.getString(key);

    if (jsonString == null) {
      return List.from(defaultGamepadLayout);
    }

    try {
      final List<dynamic> jsonList = jsonDecode(jsonString);
      final List<ButtonLayoutConfig> layout = jsonList
          .map((jsonItem) =>
              ButtonLayoutConfig.fromJson(jsonItem as Map<String, dynamic>))
          .toList();
      return layout;
    } catch (e) {
      print('Erro ao carregar layout customizado para $baseType: $e');
      return List.from(defaultGamepadLayout);
    }
  }

  Future<void> resetLayoutToDefault(GamepadLayoutType baseType) async {
     final prefs = await SharedPreferences.getInstance();
     final String key = _getStorageKeyForLayout(baseType);
     await prefs.remove(key);
  }
}