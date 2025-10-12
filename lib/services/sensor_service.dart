import 'dart:async';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:gamepadvirtual/services/storage_service.dart';

class SensorData {
  final double x;
  final double y;
  final double z;
  final DateTime timestamp;

  const SensorData({
    required this.x,
    required this.y,
    required this.z,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() {
    return {
      'x': x,
      'y': y,
      'z': z,
      'timestamp': timestamp.millisecondsSinceEpoch,
    };
  }
}

class SensorService {
  final StorageService _storageService = StorageService();
  
  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;
  StreamSubscription<GyroscopeEvent>? _gyroscopeSubscription;
  
  final StreamController<SensorData> _accelerometerController = StreamController<SensorData>.broadcast();
  final StreamController<SensorData> _gyroscopeController = StreamController<SensorData>.broadcast();

  Stream<SensorData> get accelerometerStream => _accelerometerController.stream;
  Stream<SensorData> get gyroscopeStream => _gyroscopeController.stream;

  bool _isAccelerometerActive = false;
  bool _isGyroscopeActive = false;

  bool get isAccelerometerActive => _isAccelerometerActive;
  bool get isGyroscopeActive => _isGyroscopeActive;

  // Start accelerometer
  Future<void> startAccelerometer() async {
    final isEnabled = await _storageService.isAccelerometerEnabled();
    if (!isEnabled) return;

    if (_accelerometerSubscription != null) {
      await stopAccelerometer();
    }

    _accelerometerSubscription = accelerometerEventStream().listen(
      (AccelerometerEvent event) {
        _accelerometerController.add(SensorData(
          x: event.x,
          y: event.y,
          z: event.z,
          timestamp: DateTime.now(),
        ));
      },
      onError: (error) {
        print('Accelerometer error: \$error');
      },
    );

    _isAccelerometerActive = true;
  }

  // Stop accelerometer
  Future<void> stopAccelerometer() async {
    await _accelerometerSubscription?.cancel();
    _accelerometerSubscription = null;
    _isAccelerometerActive = false;
  }

  // Start gyroscope
  // DENTRO DE: lib/services/sensor_service.dart

Future<void> startGyroscope() async {
    final isEnabled = await _storageService.isGyroscopeEnabled();
    if (!isEnabled) return;

    if (_gyroscopeSubscription != null) {
      await stopGyroscope();
    }

    _gyroscopeSubscription = gyroscopeEventStream().listen(
      (GyroscopeEvent event) {
        // ... (código de troca de eixos)
        _gyroscopeController.add(SensorData(
          x: -event.y,
          y: event.x,
          z: event.z,
          timestamp: DateTime.now(),
        ));
      },
      // =========================================================================
      // CORREÇÃO: Modifique esta linha para imprimir o erro real
      // =========================================================================
      onError: (error) {
        // Antes: print('Gyroscope error: $error');
        // Agora, imprimimos o objeto de erro detalhado.
        print('Gyroscope stream failed with error: $error');
      },
      // =========================================================================
    );

    _isGyroscopeActive = true;
}

  // Stop gyroscope
  Future<void> stopGyroscope() async {
    await _gyroscopeSubscription?.cancel();
    _gyroscopeSubscription = null;
    _isGyroscopeActive = false;
  }

  // Start both sensors
  Future<void> startAllSensors() async {
    await Future.wait([
      startAccelerometer(),
      startGyroscope(),
    ]);
  }

  // Stop both sensors
  Future<void> stopAllSensors() async {
    await Future.wait([
      stopAccelerometer(),
      stopGyroscope(),
    ]);
  }

  // Get latest accelerometer data
  Future<SensorData?> getLatestAccelerometerData() async {
    try {
      final event = await accelerometerEventStream().first.timeout(
        const Duration(milliseconds: 100),
      );
      return SensorData(
        x: event.x,
        y: event.y,
        z: event.z,
        timestamp: DateTime.now(),
      );
    } catch (e) {
      return null;
    }
  }

  // Get latest gyroscope data
  Future<SensorData?> getLatestGyroscopeData() async {
    try {
      final event = await gyroscopeEventStream().first.timeout(
        const Duration(milliseconds: 100),
      );
      return SensorData(
        x: event.x,
        y: event.y,
        z: event.z,
        timestamp: DateTime.now(),
      );
    } catch (e) {
      return null;
    }
  }

  // Dispose resources
  void dispose() {
    stopAllSensors();
    _accelerometerController.close();
    _gyroscopeController.close();
  }
}