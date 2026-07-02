import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' as fbp;
import 'package:ble_peripheral/ble_peripheral.dart' as peripheral;
import '../models/member.dart';
import 'database_service.dart';
import 'package:flutter/foundation.dart';

class TrailBleService {
  static const String serviceUuid = '0000AAAA-0000-1000-8000-00805F9B34FB';
  static const String characteristicUuid =
      '0000BBBB-0000-1000-8000-00805F9B34FB';

  static String _myDeviceId = '';
  static String _myName = '';
  static String _myStatus = 'OK';
  static Timer? _broadcastTimer;
  static StreamSubscription? _scanSubscription;

  static void init(String deviceId, String name) {
    _myDeviceId = deviceId;
    _myName = name;
  }

  static void setStatus(String status) {
    _myStatus = status;
  }

  // Inicializar peripheral
  static Future<void> initPeripheral() async {
    await peripheral.BlePeripheral.initialize();
    await peripheral.BlePeripheral.addService(
      peripheral.BleService(
        uuid: serviceUuid,
        primary: true,
        characteristics: [
          peripheral.BleCharacteristic(
            uuid: characteristicUuid,
            properties: [
              peripheral.CharacteristicProperties.read.index,
              peripheral.CharacteristicProperties.notify.index,
              peripheral.CharacteristicProperties.write.index,
            ],
            permissions: [
              peripheral.AttributePermissions.readable.index,
              peripheral.AttributePermissions.writeable.index,
            ],
            descriptors: [],
          ),
        ],
      ),
    );
  }

  // Broadcast BLE cada 3 segundos
  static Future<void> startBroadcast(
    double lat,
    double lon,
    int battery,
  ) async {
    await initPeripheral();
    // Verificar estado del advertising
    peripheral.BlePeripheral.setAdvertisingStatusUpdateCallback((
      bool advertising,
      String? error,
    ) {
      if (error != null) {
        debugPrint('BLE advertising error: $error');
      } else {
        debugPrint('BLE advertising activo: $advertising');
      }
    });
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
        await peripheral.BlePeripheral.startAdvertising(
          services: [serviceUuid],
          localName: payload,
        );
      } catch (e) {
        print('BLE broadcast error: $e');
      }
    });
  }

  static void stopBroadcast() {
    _broadcastTimer?.cancel();
    peripheral.BlePeripheral.stopAdvertising();
  }

  // Escanear dispositivos BLE cercanos
  static void startScan(Function(Member) onDetected) async {
    await fbp.FlutterBluePlus.startScan(timeout: const Duration(seconds: 30));

    _scanSubscription = fbp.FlutterBluePlus.scanResults.listen((results) {
      for (fbp.ScanResult r in results) {
        final raw = r.advertisementData.localName;
        if (raw.isEmpty) continue;

        try {
          final data = jsonDecode(raw);
          if (data['id'] == null || data['name'] == null) continue;

          final member = Member(
            deviceId: data['id'],
            name: data['name'],
            status: data['status'] ?? 'OK',
            latitude: data['lat'] ?? 0.0,
            longitude: data['lon'] ?? 0.0,
            battery: data['battery'] ?? 0,
            timestamp: DateTime.now().millisecondsSinceEpoch,
          );

          DatabaseService.insertDetection(member);
          onDetected(member);

          if (member.status == 'SOS') {
            handleSosAlert(member);
          }
        } catch (e) {
          // Paquete no es TrailGuard, ignorar
        }
      }
    });
  }

  static void stopScan() {
    _scanSubscription?.cancel();
    fbp.FlutterBluePlus.stopScan();
  }

  static void startContinuousScan(Function(Member) onDetected) {
    startScan(onDetected);
    Timer.periodic(const Duration(seconds: 30), (_) {
      stopScan();
      startScan(onDetected);
    });
  }

  static Future<void> handleSosAlert(Member member) async {
    if (member.status != 'SOS') return;
    HapticFeedback.heavyImpact();
  }
}
