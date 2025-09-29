import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gamepadvirtual/models/gamepad_layout.dart';
import 'package:gamepadvirtual/models/custom_layout.dart';

class StorageService {
  static const String _selectedLayoutKey = 'selected_layout';
  static const String _customLayoutsKey = 'custom_layouts';
  // MODIFICADO: Renomeado para clareza
  static const String _hapticFeedbackEnabledKey = 'haptic_feedback_enabled';
  // ADICIONADO: Nova chave para a vibração do jogo (rumble)
  static const String _rumbleEnabledKey = 'rumble_enabled';
  static const String _gyroscopeEnabledKey = 'gyroscope_enabled';
  static const String _accelerometerEnabledKey = 'accelerometer_enabled';

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

  Future<List<CustomLayout>> getCustomLayouts() async {
    final prefs = await SharedPreferences.getInstance();
    final layoutsString = prefs.getStringList(_customLayoutsKey);
    if (layoutsString != null) {
      return layoutsString
          .map((layoutString) => CustomLayout.fromJson(jsonDecode(layoutString)))
          .toList();
    }
    return [];
  }

  Future<void> saveCustomLayout(CustomLayout layout) async {
    final prefs = await SharedPreferences.getInstance();
    final layouts = await getCustomLayouts();
    layouts.removeWhere((existing) => existing.name == layout.name);
    layouts.add(layout);
    final layoutStrings = layouts.map((l) => jsonEncode(l.toJson())).toList();
    await prefs.setStringList(_customLayoutsKey, layoutStrings);
  }
  
  Future<void> deleteCustomLayout(String name) async {
    final prefs = await SharedPreferences.getInstance();
    final layouts = await getCustomLayouts();
    layouts.removeWhere((layout) => layout.name == name);
    
    final layoutStrings = layouts.map((l) => jsonEncode(l.toJson())).toList();
    await prefs.setStringList(_customLayoutsKey, layoutStrings);
  }

  // MODIFICADO: Renomeado para clareza
  Future<bool> isHapticFeedbackEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_hapticFeedbackEnabledKey) ?? true;
  }

  Future<void> setHapticFeedbackEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_hapticFeedbackEnabledKey, enabled);
  }

  // ADICIONADO: Métodos para a vibração do jogo
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
}