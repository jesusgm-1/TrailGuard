import 'package:geolocator/geolocator.dart';

class GpsService {
  // Solicita permisos y retorna la posición actual
  static Future<Position?> getCurrentPosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return null;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return null;
    }
    if (permission == LocationPermission.deniedForever) return null;

    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }

  // Stream continuo de posición cada 3 segundos
  static Stream<Position> positionStream() {
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 0,
        timeLimit: Duration(seconds: 3),
      ),
    );
  }

  // Coordenadas simuladas para pruebas en aula
  // Simula movimiento de 4 personas durante varios minutos
  static List<Map<String, dynamic>> simulatedCoordinates = [
    {'device_id': 'DEV001', 'name': 'Ana',    'lat': -12.0464, 'lon': -77.0428},
    {'device_id': 'DEV001', 'name': 'Ana',    'lat': -12.0467, 'lon': -77.0431},
    {'device_id': 'DEV001', 'name': 'Ana',    'lat': -12.0470, 'lon': -77.0435},
    {'device_id': 'DEV002', 'name': 'Bruno',  'lat': -12.0460, 'lon': -77.0420},
    {'device_id': 'DEV002', 'name': 'Bruno',  'lat': -12.0463, 'lon': -77.0424},
    {'device_id': 'DEV002', 'name': 'Bruno',  'lat': -12.0466, 'lon': -77.0427},
    {'device_id': 'DEV003', 'name': 'Carlos', 'lat': -12.0455, 'lon': -77.0415},
    {'device_id': 'DEV003', 'name': 'Carlos', 'lat': -12.0458, 'lon': -77.0418},
    {'device_id': 'DEV003', 'name': 'Carlos', 'lat': -12.0461, 'lon': -77.0422},
    {'device_id': 'DEV004', 'name': 'Diana',  'lat': -12.0450, 'lon': -77.0410},
    {'device_id': 'DEV004', 'name': 'Diana',  'lat': -12.0453, 'lon': -77.0413},
    {'device_id': 'DEV004', 'name': 'Diana',  'lat': -12.0456, 'lon': -77.0416},
  ];
}