import 'package:gamepadvirtual/models/gamepad_layout.dart';

class ButtonPosition {
  final double x;
  final double y;
  final double size;

  const ButtonPosition({
    required this.x,
    required this.y,
    this.size = 60.0,
  });

  ButtonPosition copyWith({
    double? x,
    double? y,
    double? size,
  }) {
    return ButtonPosition(
      x: x ?? this.x,
      y: y ?? this.y,
      size: size ?? this.size,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'x': x,
      'y': y,
      'size': size,
    };
  }

  factory ButtonPosition.fromJson(Map<String, dynamic> json) {
    return ButtonPosition(
      x: json['x']?.toDouble() ?? 0.0,
      y: json['y']?.toDouble() ?? 0.0,
      size: json['size']?.toDouble() ?? 60.0,
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

  Map<String, dynamic> toJson() {
    return {
      'type': type.toString(),
      'label': label,
      'color': color,
      'position': position.toJson(),
      'hasVibration': hasVibration,
      'isVisible': isVisible,
    };
  }

  factory CustomLayoutButton.fromJson(Map<String, dynamic> json) {
    return CustomLayoutButton(
      type: ButtonType.values.firstWhere(
        (e) => e.toString() == json['type'],
        orElse: () => ButtonType.a,
      ),
      label: json['label'] ?? '',
      color: json['color'] ?? 0xFF2196F3,
      position: ButtonPosition.fromJson(json['position']),
      hasVibration: json['hasVibration'] ?? true,
      isVisible: json['isVisible'] ?? true,
    );
  }
}

// Em lib/models/custom_layout.dart

// ... (as classes ButtonPosition e CustomLayoutButton permanecem as mesmas) ...

class CustomLayout {
  final String name;
  final List<CustomLayoutButton> buttons;
  final bool enableVibration;
  final bool enableGyroscope;
  final bool enableAccelerometer;
  final DateTime createdAt;
  final DateTime updatedAt;

  // ADICIONADO: Propriedades para os analógicos
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
    // ADICIONADO: Parâmetros no construtor
    this.hasLeftStick = true,
    this.leftStickPosition = const ButtonPosition(x: 40, y: 120, size: 120),
    this.hasRightStick = true,
    this.rightStickPosition = const ButtonPosition(x: 600, y: 120, size: 120),
  });

  // ... (o método copyWith também precisa ser atualizado, mas podemos omitir por simplicidade agora) ...

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'buttons': buttons.map((button) => button.toJson()).toList(),
      'enableVibration': enableVibration,
      'enableGyroscope': enableGyroscope,
      'enableAccelerometer': enableAccelerometer,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      // ADICIONADO: Salvar dados dos analógicos
      'hasLeftStick': hasLeftStick,
      'leftStickPosition': leftStickPosition.toJson(),
      'hasRightStick': hasRightStick,
      'rightStickPosition': rightStickPosition.toJson(),
    };
  }

  factory CustomLayout.fromJson(Map<String, dynamic> json) {
    return CustomLayout(
      name: json['name'] ?? 'Custom Layout',
      buttons: (json['buttons'] as List<dynamic>?)
          ?.map((buttonJson) => CustomLayoutButton.fromJson(buttonJson))
          .toList() ?? [],
      enableVibration: json['enableVibration'] ?? true,
      enableGyroscope: json['enableGyroscope'] ?? true,
      enableAccelerometer: json['enableAccelerometer'] ?? true,
      createdAt: DateTime.tryParse(json['createdAt']) ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt']) ?? DateTime.now(),
      // ADICIONADO: Carregar dados dos analógicos
      hasLeftStick: json['hasLeftStick'] ?? true,
      leftStickPosition: json['leftStickPosition'] != null
          ? ButtonPosition.fromJson(json['leftStickPosition'])
          : const ButtonPosition(x: 40, y: 120, size: 120),
      hasRightStick: json['hasRightStick'] ?? true,
      rightStickPosition: json['rightStickPosition'] != null
          ? ButtonPosition.fromJson(json['rightStickPosition'])
          : const ButtonPosition(x: 600, y: 120, size: 120),
    );
  }
}