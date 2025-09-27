import 'package:vibration/vibration.dart';
import 'package:gamepadvirtual/services/storage_service.dart';

class VibrationService {
  final StorageService _storageService = StorageService();

  // Vibration patterns
  static const int _lightVibration = 50;
  static const int _mediumVibration = 100;
  static const int _heavyVibration = 200;

  // Button feedback vibration
  Future<void> vibrateForButton() async {
    final isEnabled = await _storageService.isVibrationEnabled();
    if (!isEnabled) return;

    final hasVibrator = await Vibration.hasVibrator();
    if (hasVibrator == true) {
      await Vibration.vibrate(duration: _lightVibration);
    }
  }

  // Custom vibration with intensity
  Future<void> vibrateWithIntensity(VibrationIntensity intensity) async {
    final isEnabled = await _storageService.isVibrationEnabled();
    if (!isEnabled) return;

    final hasVibrator = await Vibration.hasVibrator();
    if (hasVibrator == true) {
      int duration;
      switch (intensity) {
        case VibrationIntensity.light:
          duration = _lightVibration;
          break;
        case VibrationIntensity.medium:
          duration = _mediumVibration;
          break;
        case VibrationIntensity.heavy:
          duration = _heavyVibration;
          break;
      }
      await Vibration.vibrate(duration: duration);
    }
  }

  // Pattern vibration (for external device feedback)
  Future<void> vibratePattern(List<int> pattern) async {
    final isEnabled = await _storageService.isVibrationEnabled();
    if (!isEnabled) return;

    final hasCustomVibrations = await Vibration.hasCustomVibrationsSupport();
    if (hasCustomVibrations == true) {
      await Vibration.vibrate(pattern: pattern);
    } else {
      // Fallback to simple vibration
      await vibrateWithIntensity(VibrationIntensity.medium);
    }
  }

  // Stop all vibrations
  Future<void> stopVibration() async {
    await Vibration.cancel();
  }

  // Check if vibration is supported
  Future<bool> isVibrationSupported() async {
    return await Vibration.hasVibrator() ?? false;
  }

  // Check if custom vibrations are supported
  Future<bool> isCustomVibrationSupported() async {
    return await Vibration.hasCustomVibrationsSupport() ?? false;
  }
}

enum VibrationIntensity {
  light,
  medium,
  heavy,
}