import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gamepadvirtual/models/gamepad_layout.dart';
import 'package:gamepadvirtual/models/custom_layout.dart';

class StorageService {
  static const String _selectedLayoutKey = 'selected_layout';
  static const String _customLayoutsKey = 'custom_layouts';
  static const String _vibrationEnabledKey = 'vibration_enabled';
  static const String _gyroscopeEnabledKey = 'gyroscope_enabled';
  static const String _accelerometerEnabledKey = 'accelerometer_enabled';

  // Layout Selection
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

  // Custom Layouts
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
    
    // Remove existing layout with the same name
    layouts.removeWhere((existing) => existing.name == layout.name);
    
    // Add the new/updated layout
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

  Future<CustomLayout?> getCustomLayout(String name) async {
    final layouts = await getCustomLayouts();
    try {
      return layouts.firstWhere((layout) => layout.name == name);
    } catch (e) {
      return null;
    }
  }

  // Settings
  Future<bool> isVibrationEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_vibrationEnabledKey) ?? true;
  }

  Future<void> setVibrationEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_vibrationEnabledKey, enabled);
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

  // Clear all data
  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}