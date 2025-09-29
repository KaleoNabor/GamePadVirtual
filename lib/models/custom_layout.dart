import 'package:gamepadvirtual/models/gamepad_layout.dart';

class ButtonPosition {
  final double x; // Posição X proporcional (0.0 a 1.0)
  final double y; // Posição Y proporcional (0.0 a 1.0)
  final double size; // Tamanho (altura) proporcional à altura da área
  final double? width; // Largura opcional, proporcional à altura da área

  const ButtonPosition({
    required this.x,
    required this.y,
    this.size = 0.1,
    this.width,
  });

  ButtonPosition copyWith({
    double? x,
    double? y,
    double? size,
    double? width,
  }) {
    return ButtonPosition(
      x: x ?? this.x,
      y: y ?? this.y,
      size: size ?? this.size,
      width: width ?? this.width,
    );
  }

  Map<String, dynamic> toJson() =>
      {'x': x, 'y': y, 'size': size, 'width': width};

  factory ButtonPosition.fromJson(Map<String, dynamic> json) {
    return ButtonPosition(
      x: json['x']?.toDouble() ?? 0.0,
      y: json['y']?.toDouble() ?? 0.0,
      size: json['size']?.toDouble() ?? 0.1,
      width: json['width']?.toDouble(),
    );
  }
}

class CustomLayoutButton {
  final ButtonType type;
  final String label;
  final int color;
  final ButtonPosition position;
  final bool hasVibration;
  final bool isVisible;

  const CustomLayoutButton({
    required this.type,
    required this.label,
    required this.color,
    required this.position,
    this.hasVibration = true,
    this.isVisible = true,
  });

  CustomLayoutButton copyWith({
    ButtonType? type,
    String? label,
    int? color,
    ButtonPosition? position,
    bool? hasVibration,
    bool? isVisible,
  }) {
    return CustomLayoutButton(
      type: type ?? this.type,
      label: label ?? this.label,
      color: color ?? this.color,
      position: position ?? this.position,
      hasVibration: hasVibration ?? this.hasVibration,
      isVisible: isVisible ?? this.isVisible,
    );
  }

  Map<String, dynamic> toJson() => {
        'type': type.toString(),
        'label': label,
        'color': color,
        'position': position.toJson(),
        'hasVibration': hasVibration,
        'isVisible': isVisible
      };

  factory CustomLayoutButton.fromJson(Map<String, dynamic> json) {
    return CustomLayoutButton(
      type: ButtonType.values
          .firstWhere((e) => e.toString() == json['type'], orElse: () => ButtonType.a),
      label: json['label'] ?? '',
      color: json['color'] ?? 0xFF2196F3,
      position: ButtonPosition.fromJson(json['position']),
      hasVibration: json['hasVibration'] ?? true,
      isVisible: json['isVisible'] ?? true,
    );
  }
}

class CustomLayout {
  final String name;
  final List<CustomLayoutButton> buttons;
  final bool enableVibration;
  final bool enableGyroscope;
  final bool enableAccelerometer;
  final DateTime createdAt;
  final DateTime updatedAt;

  final bool hasLeftStick;
  final ButtonPosition leftStickPosition;
  final bool hasRightStick;
  final ButtonPosition rightStickPosition;

  const CustomLayout({
    required this.name,
    required this.buttons,
    this.enableVibration = true,
    this.enableGyroscope = true,
    this.enableAccelerometer = true,
    required this.createdAt,
    required this.updatedAt,
    this.hasLeftStick = true,
    this.leftStickPosition = const ButtonPosition(x: 0.1, y: 0.4, size: 0.4),
    this.hasRightStick = true,
    this.rightStickPosition = const ButtonPosition(x: 0.75, y: 0.4, size: 0.4),
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'buttons': buttons.map((button) => button.toJson()).toList(),
        'enableVibration': enableVibration,
        'enableGyroscope': enableGyroscope,
        'enableAccelerometer': enableAccelerometer,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'hasLeftStick': hasLeftStick,
        'leftStickPosition': leftStickPosition.toJson(),
        'hasRightStick': hasRightStick,
        'rightStickPosition': rightStickPosition.toJson(),
      };

  factory CustomLayout.fromJson(Map<String, dynamic> json) {
    return CustomLayout(
      name: json['name'] ?? 'Custom Layout',
      buttons: (json['buttons'] as List<dynamic>?)
              ?.map((buttonJson) => CustomLayoutButton.fromJson(buttonJson))
              .toList() ??
          [],
      enableVibration: json['enableVibration'] ?? true,
      enableGyroscope: json['enableGyroscope'] ?? true,
      enableAccelerometer: json['enableAccelerometer'] ?? true,
      createdAt: DateTime.tryParse(json['createdAt']) ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt']) ?? DateTime.now(),
      hasLeftStick: json['hasLeftStick'] ?? true,
      leftStickPosition: json['leftStickPosition'] != null
          ? ButtonPosition.fromJson(json['leftStickPosition'])
          : const ButtonPosition(x: 0.1, y: 0.4, size: 0.4),
      hasRightStick: json['hasRightStick'] ?? true,
      rightStickPosition: json['rightStickPosition'] != null
          ? ButtonPosition.fromJson(json['rightStickPosition'])
          : const ButtonPosition(x: 0.75, y: 0.4, size: 0.4),
    );
  }
}
