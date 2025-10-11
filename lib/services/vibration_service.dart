import 'package:vibration/vibration.dart';
import 'package:gamepadvirtual/services/storage_service.dart';

class VibrationService {
  final StorageService _storageService = StorageService();
  bool _isVibrating = false;

  static const int _lightVibration = 50;

  // Vibração de feedback ao tocar nos botões virtuais
  Future<void> vibrateForButton() async {
    if (_isVibrating) return;
    
    final isEnabled = await _storageService.isHapticFeedbackEnabled();
    if (!isEnabled) return;

    _isVibrating = true;
    
    try {
      if (await Vibration.hasVibrator() ?? false) {
        await Vibration.vibrate(duration: _lightVibration);
      }
    } catch (e) {
      print('Vibration error: $e');
    } finally {
      // Delay para evitar vibrações muito rápidas
      await Future.delayed(const Duration(milliseconds: 50));
      _isVibrating = false;
    }
  }

  // Vibração que vem do jogo (rumble)
  Future<void> vibratePattern(List<int> pattern) async {
    final isEnabled = await _storageService.isRumbleEnabled();
    if (!isEnabled) return;

    try {
      if (await Vibration.hasCustomVibrationsSupport() ?? false) {
        await Vibration.vibrate(pattern: pattern);
      } else if (await Vibration.hasVibrator() ?? false) {
        await Vibration.vibrate(duration: 100);
      }
    } catch (e) {
      print('Rumble vibration error: $e');
    }
  }
}