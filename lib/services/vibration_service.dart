import 'package:vibration/vibration.dart';
import 'package:gamepadvirtual/services/storage_service.dart';

class VibrationService {
  final StorageService _storageService = StorageService();

  static const int _lightVibration = 50;

  // Vibração de feedback ao tocar nos botões virtuais
  Future<void> vibrateForButton() async {
    final isEnabled = await _storageService.isHapticFeedbackEnabled();
    if (!isEnabled) return;

    if (await Vibration.hasVibrator() ?? false) {
      Vibration.vibrate(duration: _lightVibration);
    }
  }

  // Vibração que vem do jogo (rumble)
  Future<void> vibratePattern(List<int> pattern) async {
    final isEnabled = await _storageService.isRumbleEnabled();
    if (!isEnabled) return;

    if (await Vibration.hasCustomVibrationsSupport() ?? false) {
      Vibration.vibrate(pattern: pattern);
    } else if (await Vibration.hasVibrator() ?? false) {
      Vibration.vibrate(duration: 100); // Fallback
    }
  }
}