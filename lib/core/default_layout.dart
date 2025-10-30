// lib/core/default_layout.dart
import 'package:gamepadvirtual/models/button_layout_config.dart';

// LAYOUT PADRÃO ATUALIZADO
// x, y agora são percentuais (0.0 = 0%, 1.0 = 100% da tela)
// width, height continuam sendo pixels (para facilitar a edição)
final List<ButtonLayoutConfig> defaultGamepadLayout = [
  // Lado Esquerdo
  ButtonLayoutConfig(
    element: ConfigurableElement.analogLeft,
    x: 0.05, y: 0.35, width: 120, height: 120
  ),
  ButtonLayoutConfig(
    element: ConfigurableElement.dpad,
    x: 0.22, y: 0.35, width: 120, height: 120
  ),
  ButtonLayoutConfig(
    element: ConfigurableElement.triggerLeft,
    x: 0.07, y: 0.05, width: 90, height: 30
  ),
  ButtonLayoutConfig(
    element: ConfigurableElement.bumperLeft,
    x: 0.07, y: 0.20, width: 100, height: 40
  ),
  ButtonLayoutConfig(
    element: ConfigurableElement.stickButtonLeft,
    x: 0.15, y: 0.75, width: 40, height: 40
  ),

  // Lado Direito (Valores de 'x' são da borda esquerda)
  ButtonLayoutConfig(
    element: ConfigurableElement.analogRight,
    x: 0.80, y: 0.35, width: 120, height: 120
  ),
  ButtonLayoutConfig(
    element: ConfigurableElement.actionButtons,
    x: 0.63, y: 0.35, width: 120, height: 120
  ),
  ButtonLayoutConfig(
    element: ConfigurableElement.triggerRight,
    x: 0.80, y: 0.05, width: 90, height: 30
  ),
  ButtonLayoutConfig(
    element: ConfigurableElement.bumperRight,
    x: 0.80, y: 0.20, width: 100, height: 40
  ),
  ButtonLayoutConfig(
    element: ConfigurableElement.stickButtonRight,
    x: 0.72, y: 0.75, width: 40, height: 40
  ),

  // Centro
  ButtonLayoutConfig(
    element: ConfigurableElement.select,
    x: 0.40, y: 0.05, width: 80, height: 25
  ),
  ButtonLayoutConfig(
    element: ConfigurableElement.start,
    x: 0.50, y: 0.05, width: 80, height: 25
  ),

  // Botão de Configurações
  ButtonLayoutConfig(
    element: ConfigurableElement.floatingSettingsButton,
    x: 0.90, y: 0.75, width: 56, height: 56
  ),
];