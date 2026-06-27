class Member {
  final String deviceId;
  final String name;
  final String status; // 'OK' o 'SOS'
  final double latitude;
  final double longitude;
  final int battery;
  final int timestamp; // milliseconds epoch

  Member({
    required this.deviceId,
    required this.name,
    required this.status,
    required this.latitude,
    required this.longitude,
    required this.battery,
    required this.timestamp,
  });

  // Para guardar en SQLite
  Map<String, dynamic> toMap() {
    return {
      'device_id': deviceId,
      'name': name,
      'status': status,
      'latitude': latitude,
      'longitude': longitude,
      'battery': battery,
      'timestamp': timestamp,
    };
  }

  // Para leer desde SQLite
  factory Member.fromMap(Map<String, dynamic> map) {
    return Member(
      deviceId: map['device_id'],
      name: map['name'],
      status: map['status'],
      latitude: map['latitude'],
      longitude: map['longitude'],
      battery: map['battery'],
      timestamp: map['timestamp'],
    );
  }

  // Calcula a qué minuto pertenece este registro
  int get minuteBucket => timestamp ~/ 60000;
}