import 'dart:async';
import 'dart:convert';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../models/member.dart';
import 'database_service.dart';

class BleService {
  static const String serviceUuid = '0000AAAA-0000-1000-8000-00805F9B34FB';
  static const String characteristicUuid =
      '0000BBBB-0000-1000-8000-00805F9B34FB';

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

  static Future<void> startBroadcast(
    double lat,
    double lon,
    int battery,
  ) async {
    // BLE advertising se implementará en dispositivo físico
    // Por ahora solo actualiza el estado interno
    print('Broadcasting: $_myDeviceId $_myName $_myStatus $lat $lon');
  }

  static void stopBroadcast() {
    _broadcastTimer?.cancel();
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
