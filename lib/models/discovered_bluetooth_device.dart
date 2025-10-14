import 'package:flutter_blue_plus/flutter_blue_plus.dart' as ble;
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart' as classic;

enum BluetoothDeviceType { ble, classic }

class DiscoveredBluetoothDevice {
  final String address;
  final String name;
  final BluetoothDeviceType type;
  final dynamic underlyingDevice; // Guarda o objeto original (ble.BluetoothDevice ou classic.BluetoothDevice)

  DiscoveredBluetoothDevice({
    required this.address,
    required this.name,
    required this.type,
    required this.underlyingDevice,
  });

  // Construtor para BLE
  factory DiscoveredBluetoothDevice.fromBle(ble.BluetoothDevice device) {
    return DiscoveredBluetoothDevice(
      address: device.remoteId.toString(),
      name: device.platformName,
      type: BluetoothDeviceType.ble,
      underlyingDevice: device,
    );
  }

  // Construtor para Clássico
  factory DiscoveredBluetoothDevice.fromClassic(classic.BluetoothDevice device) {
    return DiscoveredBluetoothDevice(
      address: device.address,
      name: device.name ?? "Dispositivo Pareado",
      type: BluetoothDeviceType.classic,
      underlyingDevice: device,
    );
  }
}