// MODIFICADO: Adicionado 'wifiDirect' para futuras implementações.
enum ConnectionType {
  none,
  bluetooth,
  usb,
  wifiDirect, // ADICIONADO
  externalGamepad,
}

class ConnectionState {
  final ConnectionType type;
  final bool isConnected;
  final String? deviceName;
  final String? deviceAddress;
  final DateTime? connectedAt;
  final bool isExternalGamepad;

  const ConnectionState({
    required this.type,
    required this.isConnected,
    this.deviceName,
    this.deviceAddress,
    this.connectedAt,
    this.isExternalGamepad = false,
  });

  factory ConnectionState.disconnected() {
    return const ConnectionState(
      type: ConnectionType.none,
      isConnected: false,
      isExternalGamepad: false,
    );
  }

  // MODIFICADO: Factory para Bluetooth LE com prefixo
  factory ConnectionState.bluetoothLeConnected({
    required String deviceName,
    required String deviceAddress,
  }) {
    return ConnectionState(
      type: ConnectionType.bluetooth,
      isConnected: true,
      deviceName: "BLE: $deviceName", // <<< Adiciona o prefixo
      deviceAddress: deviceAddress,
      connectedAt: DateTime.now(),
      isExternalGamepad: false,
    );
  }

  // MODIFICADO: Factory para Bluetooth Clássico com prefixo (renomeado)
  factory ConnectionState.bluetoothClassicConnected({
    required String deviceName,
    required String deviceAddress,
  }) {
    return ConnectionState(
      type: ConnectionType.bluetooth,
      isConnected: true,
      deviceName: "Clássico: $deviceName", // <<< Adiciona o prefixo
      deviceAddress: deviceAddress,
      connectedAt: DateTime.now(),
      isExternalGamepad: false,
    );
  }

  // MANTIDO: Factory original para compatibilidade (pode ser removido posteriormente)
  factory ConnectionState.bluetoothConnected({
    required String deviceName,
    required String deviceAddress,
  }) {
    return ConnectionState(
      type: ConnectionType.bluetooth,
      isConnected: true,
      deviceName: deviceName,
      deviceAddress: deviceAddress,
      connectedAt: DateTime.now(),
      isExternalGamepad: false,
    );
  }

  factory ConnectionState.usbConnected({required String deviceName}) {
    return ConnectionState(
      type: ConnectionType.usb,
      isConnected: true,
      deviceName: deviceName,
      connectedAt: DateTime.now(),
      isExternalGamepad: false,
    );
  }
  
  // ADICIONADO: Factory para Wi-Fi Direct para consistência.
  factory ConnectionState.wifiDirectConnected({required String deviceName}) {
    return ConnectionState(
      type: ConnectionType.wifiDirect,
      isConnected: true,
      deviceName: deviceName,
      connectedAt: DateTime.now(),
      isExternalGamepad: false,
    );
  }

  factory ConnectionState.externalGamepadConnected({required String deviceName}) {
    return ConnectionState(
      type: ConnectionType.externalGamepad,
      isConnected: true,
      deviceName: deviceName,
      connectedAt: DateTime.now(),
      isExternalGamepad: true,
    );
  }

  // ADICIONADO: Getters para identificar o tipo de conexão
  bool get isWifi => type == ConnectionType.wifiDirect;
  bool get isBle => type == ConnectionType.bluetooth && deviceName?.startsWith("BLE:") == true;
  bool get isClassicBt => type == ConnectionType.bluetooth && deviceName?.startsWith("Clássico:") == true;

  String get statusText {
    if (!isConnected) return 'Desconectado';
    
    switch (type) {
      case ConnectionType.bluetooth:
        // MODIFICADO: Texto mais específico para Bluetooth
        if (isBle) {
          return 'Conectado via Bluetooth LE${deviceName != null ? ' - $deviceName' : ''}';
        } else if (isClassicBt) {
          return 'Conectado via Bluetooth Clássico${deviceName != null ? ' - $deviceName' : ''}';
        } else {
          return 'Conectado via Bluetooth${deviceName != null ? ' - $deviceName' : ''}';
        }
      case ConnectionType.usb:
        return 'Conectado via USB${deviceName != null ? ' - $deviceName' : ''}';
      // ADICIONADO: Texto de status para Wi-Fi Direct.
      case ConnectionType.wifiDirect:
        return 'Conectado via Wi-Fi Direct${deviceName != null ? ' - $deviceName' : ''}';
      case ConnectionType.externalGamepad:
        return 'Gamepad Externo${deviceName != null ? ' - $deviceName' : ''}';
      case ConnectionType.none:
        return 'Desconectado';
    }
  }

  ConnectionState copyWith({
    ConnectionType? type,
    bool? isConnected,
    String? deviceName,
    String? deviceAddress,
    DateTime? connectedAt,
    bool? isExternalGamepad,
  }) {
    return ConnectionState(
      type: type ?? this.type,
      isConnected: isConnected ?? this.isConnected,
      deviceName: deviceName ?? this.deviceName,
      deviceAddress: deviceAddress ?? this.deviceAddress,
      connectedAt: connectedAt ?? this.connectedAt,
      isExternalGamepad: isExternalGamepad ?? this.isExternalGamepad,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    
    return other is ConnectionState &&
        other.type == type &&
        other.isConnected == isConnected &&
        other.deviceName == deviceName &&
        other.deviceAddress == deviceAddress &&
        other.isExternalGamepad == isExternalGamepad;
  }

  @override
  int get hashCode {
    return Object.hash(
      type,
      isConnected,
      deviceName,
      deviceAddress,
      isExternalGamepad,
    );
  }
}