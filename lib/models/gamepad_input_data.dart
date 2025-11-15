// lib/models/gamepad_input_data.dart
// Define a estrutura de dados para o estado de entrada do gamepad.
import 'dart:typed_data';
import 'package:gamepadvirtual/models/gamepad_layout.dart';

//region Classe de Dados do Gamepad
/// Representa um "snapshot" completo do estado do gamepad em um determinado momento.
class GamepadInputData {
  final Map<ButtonType, bool> buttons;
  final Map<String, double> analogSticks;
  final Map<String, dynamic> sensors;
  final DateTime timestamp;

  GamepadInputData({
    required this.buttons,
    required this.analogSticks,
    required this.sensors,
    required this.timestamp,
  });
  //endregion

  //region Conversão para Pacote de Bytes
  /// Converte o estado atual do gamepad em um pacote de bytes (Uint8List) de 20 bytes,
  /// seguindo um formato específico para ser enviado ao servidor no PC.
  Uint8List toPacketBytes() {
    final byteData = ByteData(20);
    int buttonFlags = 0;

    // --- LÓGICA DE BOTÕES (SEM MUDANÇAS) ---
    if (buttons[ButtonType.dpadUp] == true) buttonFlags |= (1 << 0);
    if (buttons[ButtonType.dpadDown] == true) buttonFlags |= (1 << 1);
    if (buttons[ButtonType.dpadLeft] == true) buttonFlags |= (1 << 2);
    if (buttons[ButtonType.dpadRight] == true) buttonFlags |= (1 << 3);
    if (buttons[ButtonType.start] == true) buttonFlags |= (1 << 4);
    if (buttons[ButtonType.select] == true) buttonFlags |= (1 << 5);
    if (buttons[ButtonType.leftStickButton] == true) buttonFlags |= (1 << 6);
    if (buttons[ButtonType.rightStickButton] == true) buttonFlags |= (1 << 7);
    if (buttons[ButtonType.leftBumper] == true) buttonFlags |= (1 << 8);
    if (buttons[ButtonType.rightBumper] == true) buttonFlags |= (1 << 9);
    if (buttons[ButtonType.a] == true || buttons[ButtonType.cross] == true) buttonFlags |= (1 << 12);
    if (buttons[ButtonType.b] == true || buttons[ButtonType.circle] == true) buttonFlags |= (1 << 13);
    if (buttons[ButtonType.x] == true || buttons[ButtonType.square] == true) buttonFlags |= (1 << 14);
    if (buttons[ButtonType.y] == true || buttons[ButtonType.triangle] == true) buttonFlags |= (1 << 15);
    
    byteData.setUint16(0, buttonFlags, Endian.little);

    // --- LÓGICA DE ANALÓGICOS (SEM MUDANÇAS) ---
    byteData.setInt8(2, ((analogSticks['leftX'] ?? 0.0) * 127).round());
    byteData.setInt8(3, ((analogSticks['leftY'] ?? 0.0) * 127).round());
    byteData.setInt8(4, ((analogSticks['rightX'] ?? 0.0) * 127).round());
    byteData.setInt8(5, ((analogSticks['rightY'] ?? 0.0) * 127).round());
    byteData.setUint8(6, ((analogSticks['leftTrigger'] ?? 0.0) * 255).toInt());
    byteData.setUint8(7, ((analogSticks['rightTrigger'] ?? 0.0) * 255).toInt());

    // --- CORREÇÃO: Mapeamento preciso para Modo Paisagem (Landscape) ---
    // No Android, o eixo do sensor é relativo à tela padrão (Portrait).
    // Quando seguramos em Landscape (deitado):
    // - O eixo Y do celular vira o eixo X do "Gamepad".
    // - O eixo X do celular vira o eixo -Y do "Gamepad".
    
    // Recuperando dados brutos (assumindo que SensorService entrega dados brutos ou minimamente tratados)
    // Se o seu SensorService já faz a troca, verifique para não trocar duas vezes.
    // Vou assumir aqui que SensorService entrega os dados RAW do plugin sensors_plus.
    
    final rawGyroX = sensors['gyroX'] ?? 0.0;
    final rawGyroY = sensors['gyroY'] ?? 0.0;
    final rawGyroZ = sensors['gyroZ'] ?? 0.0;

    // Aplicando a rotação para Landscape
    final double gyroXGame = -rawGyroY; // Y vira X invertido ou direto dependendo do lado da rotação
    final double gyroYGame = rawGyroX;  // X vira Y
    final double gyroZGame = rawGyroZ;  // Z (rotação da tela) se mantém

    // Escala para envio (x100 para precisão em int16)
    byteData.setInt16(8, (gyroXGame * 100).round(), Endian.little);
    byteData.setInt16(10, (gyroYGame * 100).round(), Endian.little);
    byteData.setInt16(12, (gyroZGame * 100).round(), Endian.little);

    // --- Acelerômetro (lógica similar) ---
    const double gravity = 9.80665;
    const double accelScale = 4096.0;
    
    final rawAccelX = sensors['accelX'] ?? 0.0;
    final rawAccelY = sensors['accelY'] ?? 0.0;
    final rawAccelZ = sensors['accelZ'] ?? 0.0;

    final double accelXGame = -rawAccelY;
    final double accelYGame = -rawAccelZ;
    final double accelZGame = rawAccelX;

    byteData.setInt16(14, ((accelXGame / gravity) * accelScale).round(), Endian.little);
    byteData.setInt16(16, ((accelYGame / gravity) * accelScale).round(), Endian.little);
    byteData.setInt16(18, ((accelZGame / gravity) * accelScale).round(), Endian.little);

    return byteData.buffer.asUint8List();
  }
}
//endregion