// lib/core/default_layout.dart
import 'package:gamepadvirtual/models/button_layout_config.dart';

// Esta é a configuração de layout padrão, com todas as posições
// (x, y) medidas a partir do canto superior esquerdo.
//
// Os valores de 'x' e 'y' são PERCENTUAIS (0.05 = 5% da tela)
// Os valores de 'width' e 'height' são PIXELS (tamanho fixo)
//
// Estas posições são calculadas para recriar o layout do seu arquivo antigo.

final List<ButtonLayoutConfig> defaultGamepadLayout = [
  // --- Lado Esquerdo ---
  ButtonLayoutConfig(
    element: ConfigurableElement.analogLeft,
    x: 0.05, y: 0.55, width: 120, height: 120 // left: 40, bottom: 40
  ),
  ButtonLayoutConfig(
    element: ConfigurableElement.dpad,
    x: 0.225, y: 0.50, width: 120, height: 120 // left: 180, bottom: 60
  ),
  ButtonLayoutConfig(
    element: ConfigurableElement.triggerLeft,
    x: 0.075, y: 0.16, width: 90, height: 30 // left: 60, top: 60
  ),
  ButtonLayoutConfig(
    element: ConfigurableElement.bumperLeft,
    x: 0.075, y: 0.26, width: 100, height: 40 // left: 60, top: 95
  ),
  ButtonLayoutConfig(
    element: ConfigurableElement.stickButtonLeft,
    x: 0.1625, y: 0.83, width: 40, height: 40 // left: 130, bottom: 20
  ),

  // --- Lado Direito ---
  ButtonLayoutConfig(
    element: ConfigurableElement.analogRight,
    x: 0.8, y: 0.55, width: 120, height: 120 // right: 40, bottom: 40
  ),
  ButtonLayoutConfig(
    element: ConfigurableElement.actionButtons,
    x: 0.625, y: 0.50, width: 120, height: 120 // right: 180, bottom: 60
  ),
  ButtonLayoutConfig(
    element: ConfigurableElement.triggerRight,
    x: 0.8125, y: 0.16, width: 90, height: 30 // right: 60, top: 60
  ),
  ButtonLayoutConfig(
    element: ConfigurableElement.bumperRight,
    x: 0.8, y: 0.26, width: 100, height: 40 // right: 60, top: 95
  ),
  ButtonLayoutConfig(
    element: ConfigurableElement.stickButtonRight,
    x: 0.7875, y: 0.83, width: 40, height: 40 // right: 130, bottom: 20
  ),

  // --- Centro ---
  ButtonLayoutConfig(
    element: ConfigurableElement.select,
    x: 0.3625, y: 0.19, width: 80, height: 25 // top: 70, center
  ),
  ButtonLayoutConfig(
    element: ConfigurableElement.start,
    x: 0.5375, y: 0.19, width: 80, height: 25 // top: 70, center
  ),

  // --- Botão de Configurações ---
  ButtonLayoutConfig(
    element: ConfigurableElement.floatingSettingsButton,
    x: 0.92, y: 0.85, width: 56, height: 56
  ),
];