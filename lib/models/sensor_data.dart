// Representa os dados de um sensor, como acelerômetro ou giroscópio.
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