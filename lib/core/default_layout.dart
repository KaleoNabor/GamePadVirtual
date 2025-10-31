// lib/core/default_layout.dart
import 'package:gamepadvirtual/models/button_layout_config.dart';

/// Define a posição, tamanho e visibilidade padrão para cada elemento do gamepad virtual.
/// As coordenadas (x, y) são percentuais em relação ao tamanho da tela (0.0 a 1.0).
/// As dimensões (width, height) são em pixels lógicos.
final List<ButtonLayoutConfig> defaultGamepadLayout = [
  //region Elementos do Lado Esquerdo
  ButtonLayoutConfig(
    element: ConfigurableElement.analogLeft,
    x: 0.05, y: 0.55, width: 120, height: 120
  ),
  ButtonLayoutConfig(
    element: ConfigurableElement.dpad,
    x: 0.225, y: 0.50, width: 120, height: 120
  ),
  ButtonLayoutConfig(
    element: ConfigurableElement.triggerLeft,
    x: 0.075, y: 0.16, width: 90, height: 30
  ),
  ButtonLayoutConfig(
    element: ConfigurableElement.bumperLeft,
    x: 0.075, y: 0.26, width: 100, height: 40
  ),
  ButtonLayoutConfig(
    element: ConfigurableElement.stickButtonLeft,
    x: 0.1625, y: 0.83, width: 40, height: 40
  ),
  //endregion
  //region Elementos do Lado Direito
  ButtonLayoutConfig(
    element: ConfigurableElement.analogRight,
    x: 0.8, y: 0.55, width: 120, height: 120
  ),
  ButtonLayoutConfig(
    element: ConfigurableElement.actionButtons,
    x: 0.625, y: 0.50, width: 120, height: 120
  ),
  ButtonLayoutConfig(
    element: ConfigurableElement.triggerRight,
    x: 0.8125, y: 0.16, width: 90, height: 30
  ),
  ButtonLayoutConfig(
    element: ConfigurableElement.bumperRight,
    x: 0.8, y: 0.26, width: 100, height: 40
  ),
  ButtonLayoutConfig(
    element: ConfigurableElement.stickButtonRight,
    x: 0.7875, y: 0.83, width: 40, height: 40
  ),
  //endregion
  //region Elementos Centrais
  ButtonLayoutConfig(
    element: ConfigurableElement.select,
    x: 0.3625, y: 0.19, width: 80, height: 25
  ),
  ButtonLayoutConfig(
    element: ConfigurableElement.start,
    x: 0.5375, y: 0.19, width: 80, height: 25
  ),
  //endregion
  //region Botões Flutuantes
  ButtonLayoutConfig(
    element: ConfigurableElement.floatingSettingsButton,
    x: 0.92, y: 0.85, width: 56, height: 56
  ),
  //endregion
];