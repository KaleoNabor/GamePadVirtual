// lib/models/button_layout_config.dart
import 'package:gamepadvirtual/models/gamepad_layout.dart';

// Mapeia todos os widgets controláveis na tela
enum ConfigurableElement {
  analogLeft,
  analogRight,
  dpad,
  actionButtons,
  bumperLeft,
  bumperRight,
  triggerLeft,
  triggerRight,
  stickButtonLeft,
  stickButtonRight,
  select,
  start,
  floatingSettingsButton, // +++ ADICIONE ESTA LINHA +++
}

class ButtonLayoutConfig {
  final ConfigurableElement element;
  final double x;
  final double y;
  final double width;
  final double height;
  final bool isVisible;

  ButtonLayoutConfig({
    required this.element,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    this.isVisible = true,
  });

  // Converte um objeto JSON (do SharedPreferences) em um objeto ButtonLayoutConfig
  factory ButtonLayoutConfig.fromJson(Map<String, dynamic> json) {
    return ButtonLayoutConfig(
      element: ConfigurableElement.values
          .firstWhere((e) => e.toString() == json['element']),
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
      width: (json['width'] as num).toDouble(),
      height: (json['height'] as num).toDouble(),
      isVisible: json['isVisible'] as bool? ?? true,
    );
  }

  // Converte este objeto em um JSON para salvar no SharedPreferences
  Map<String, dynamic> toJson() {
    return {
      'element': element.toString(),
      'x': x,
      'y': y,
      'width': width,
      'height': height,
      'isVisible': isVisible,
    };
  }

  // Helper para facilitar a atualização de posição na tela de edição
  ButtonLayoutConfig copyWith({
    double? x,
    double? y,
    double? width,
    double? height,
    bool? isVisible,
  }) {
    return ButtonLayoutConfig(
      element: element,
      x: x ?? this.x,
      y: y ?? this.y,
      width: width ?? this.width,
      height: height ?? this.height,
      isVisible: isVisible ?? this.isVisible,
    );
  }
}