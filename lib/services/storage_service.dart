// lib/services/storage_service.dart

import 'dart:convert';
import 'package:gamepadvirtual/core/default_layout.dart';
import 'package:gamepadvirtual/models/button_layout_config.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gamepadvirtual/models/gamepad_layout.dart';

class StorageService {
  static const String _selectedLayoutKey = 'selected_layout';
  static const String _hapticFeedbackEnabledKey = 'haptic_feedback_enabled';
  static const String _rumbleEnabledKey = 'rumble_enabled';
  static const String _gyroscopeEnabledKey = 'gyroscope_enabled';
  static const String _accelerometerEnabledKey = 'accelerometer_enabled';

  // +++ NOVA CHAVE PARA O LAYOUT CUSTOMIZADO +++
  static const String _customLayoutKey = 'custom_layout_config';
  
  // +++ ADICIONE ESTA NOVA CHAVE +++
  static const String _customLayoutBaseKey = 'custom_layout_base';

  // --- Métodos de Layout (GamepadType) ---
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
  
  // +++ ADICIONE ESTES DOIS NOVOS MÉTODOS +++

  /// Salva qual é o layout base (Xbox, PS) para a personalização
  Future<void> setCustomLayoutBase(GamepadLayoutType layout) async {
    final prefs = await SharedPreferences.getInstance();
    // Garante que não salvemos 'custom' como base
    if (layout == GamepadLayoutType.custom) return;
    await prefs.setString(_customLayoutBaseKey, layout.toString());
  }

  /// Carrega o layout base da personalização
  Future<GamepadLayoutType> getCustomLayoutBase() async {
    final prefs = await SharedPreferences.getInstance();
    final layoutString = prefs.getString(_customLayoutBaseKey);
    if (layoutString != null) {
      return GamepadLayoutType.values.firstWhere(
        (e) => e.toString() == layoutString,
        orElse: () => GamepadLayoutType.xbox,
      );
    }
    // Retorna Xbox como padrão se nenhum foi salvo
    return GamepadLayoutType.xbox;
  }

  // --- Métodos de Configurações (bool) ---

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

  // +++ NOVOS MÉTODOS PARA O LAYOUT CUSTOMIZADO +++

  /// Salva a lista de configurações de layout como uma string JSON.
  Future<void> saveCustomLayout(List<ButtonLayoutConfig> layout) async {
    final prefs = await SharedPreferences.getInstance();
    // 1. Converte a List<ButtonLayoutConfig> em List<Map<String, dynamic>>
    final List<Map<String, dynamic>> jsonList =
        layout.map((config) => config.toJson()).toList();
    // 2. Codifica a lista em uma única string JSON
    final String jsonString = jsonEncode(jsonList);
    // 3. Salva a string
    await prefs.setString(_customLayoutKey, jsonString);
  }

  /// Carrega e decodifica o layout customizado do SharedPreferences.
  /// Se nenhum layout salvo for encontrado, retorna o layout padrão.
  Future<List<ButtonLayoutConfig>> loadCustomLayout() async {
    final prefs = await SharedPreferences.getInstance();
    final String? jsonString = prefs.getString(_customLayoutKey);

    if (jsonString == null) {
      // Nenhum layout salvo, retorna o padrão
      return defaultGamepadLayout;
    }

    try {
      // 1. Decodifica a string em uma List<dynamic>
      final List<dynamic> jsonList = jsonDecode(jsonString);
      // 2. Converte cada item da lista de volta para um ButtonLayoutConfig
      final List<ButtonLayoutConfig> layout = jsonList
          .map((jsonItem) =>
              ButtonLayoutConfig.fromJson(jsonItem as Map<String, dynamic>))
          .toList();
      return layout;
    } catch (e) {
      print('Erro ao carregar layout customizado: $e');
      // Em caso de erro (ex: dados corrompidos), retorna o padrão
      return defaultGamepadLayout;
    }
  }

  /// Reseta o layout para o padrão de fábrica
  Future<void> resetLayoutToDefault() async {
     final prefs = await SharedPreferences.getInstance();
     await prefs.remove(_customLayoutKey);
  }
}