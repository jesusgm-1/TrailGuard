import 'dart:async';
import 'dart:convert';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../models/member.dart';
import 'database_service.dart';

class BleService {
  static const String serviceUuid = '0000AAAA-0000-1000-8000-00805F9B34FB';
  static const String characteristicUuid = '0000BBBB-0000-1000-8000-00805F9B34FB';

  static String _myDeviceId = '';
  static String _myName = '';
  static String _myStatus = 'OK';
  static Timer? _broadcastTimer;
  static StreamSubscription? _scanSubscription;

  // Inicializar con datos del usuario
  static void init(String deviceId, String name) {
    _myDeviceId = deviceId;
    _myName = name;
  }

  // Cambiar estado (OK / SOS)
  static void setStatus(String status) {
    _myStatus = status;
  }

  // Iniciar broadcast BLE cada 3 segundos
  static Future<void> startBroadcast(double lat, double lon, int battery) async {
    _broadcastTimer?.cancel();
    _broadcastTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      final payload = jsonEncode({
        'id': _myDeviceId,
        'name': _myName,
        'status': _myStatus,
        'lat': lat,
        'lon': lon,
        'battery': battery,
      });

      try {
        await FlutterBluePlus.startAdvertising(
          localName: payload,
          serviceUuids: [Guid(serviceUuid)],
        );
      } catch (e) {
        print('BLE broadcast error: $e');
      }
    });
  }

  static void stopBroadcast() {
    _broadcastTimer?.cancel();
    FlutterBluePlus.stopAdvertising();
  }

  // Escanear y guardar detecciones en SQLite
  static void startScan(Function(Member) onDetected) {
    FlutterBluePlus.startScan(timeout: const Duration(seconds: 30));

    _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
      for (ScanResult r in results) {
        final raw = r.advertisementData.localName;
        if (raw.isEmpty) continue;

        try {
          final data = jsonDecode(raw);
          final member = Member(
            deviceId: data['id'],
            name: data['name'],
            status: data['status'],
            latitude: data['lat'],
            longitude: data['lon'],
            battery: data['battery'],
            timestamp: DateTime.now().millisecondsSinceEpoch,
          );

          DatabaseService.insertDetection(member);
          onDetected(member);

          // Alerta inmediata si es SOS
          if (member.status == 'SOS') {
            onDetected(member);
          }
        } catch (e) {
          // Paquete BLE no es nuestro, ignorar
        }
      }
    });
  }

  static void stopScan() {
    _scanSubscription?.cancel();
    FlutterBluePlus.stopScan();
  }

  // Reiniciar scan cada 30 segundos continuamente
  static void startContinuousScan(Function(Member) onDetected) {
    startScan(onDetected);
    Timer.periodic(const Duration(seconds: 30), (_) {
      stopScan();
      startScan(onDetected);
    });
  }
}