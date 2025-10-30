// lib/models/gamepad_layout.dart

enum GamepadLayoutType {
  xbox,
  playstation,
  nintendo,
  custom, // +++ ADICIONE ESTA LINHA +++
}

enum ButtonType {
  a, b, x, y,
  square, triangle, circle, cross,
  dpadUp, dpadDown, dpadLeft, dpadRight,
  leftBumper, rightBumper,
  leftTrigger, rightTrigger,
  leftStick, rightStick,
  leftStickButton, rightStickButton,
  select, start,
}

class GamepadButton {
  final ButtonType type;
  final String label;
  final int color;
  final bool hasVibration;

  const GamepadButton({
    required this.type,
    required this.label,
    required this.color,
    this.hasVibration = true,
  });
}

class GamepadLayout {
  final GamepadLayoutType type;
  final String name;
  final List<GamepadButton> buttons;
  final bool hasAnalogSticks;
  final bool hasDpad;
  final bool hasShoulderButtons;

  const GamepadLayout({
    required this.type,
    required this.name,
    required this.buttons,
    this.hasAnalogSticks = true,
    this.hasDpad = true,
    this.hasShoulderButtons = true,
  });

  static const GamepadLayout xbox = GamepadLayout(
    type: GamepadLayoutType.xbox,
    name: 'Xbox',
    buttons: [
      GamepadButton(type: ButtonType.y, label: 'Y', color: 0xFFFFEB3B), // top
      GamepadButton(type: ButtonType.b, label: 'B', color: 0xFFF44336), // right
      GamepadButton(type: ButtonType.a, label: 'A', color: 0xFF4CAF50), // bottom
      GamepadButton(type: ButtonType.x, label: 'X', color: 0xFF2196F3), // left
    ],
  );

  static const GamepadLayout playstation = GamepadLayout(
    type: GamepadLayoutType.playstation,
    name: 'PlayStation',
    buttons: [
      GamepadButton(type: ButtonType.triangle, label: '△', color: 0xFF4CAF50),
      GamepadButton(type: ButtonType.circle, label: '○', color: 0xFFF44336),
      GamepadButton(type: ButtonType.cross, label: '✕', color: 0xFF2196F3),
      GamepadButton(type: ButtonType.square, label: '□', color: 0xFF9C27B0),
    ],
  );

  static const GamepadLayout nintendo = GamepadLayout(
    type: GamepadLayoutType.nintendo,
    name: 'Nintendo',
    buttons: [
      GamepadButton(type: ButtonType.x, label: 'X', color: 0xFFFFFFFF),
      GamepadButton(type: ButtonType.a, label: 'A', color: 0xFF424242),
      GamepadButton(type: ButtonType.b, label: 'B', color: 0xFF424242),
      GamepadButton(type: ButtonType.y, label: 'Y', color: 0xFFFFFFFF),
    ],
  );

  static List<GamepadLayout> get predefinedLayouts => [xbox, playstation, nintendo];
}