import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' as fbp;
import 'package:ble_peripheral/ble_peripheral.dart' as peripheral;
import '../models/member.dart';
import 'database_service.dart';
import 'package:flutter/foundation.dart';
import 'dart:typed_data';

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
    int battery, {
    Function(bool, String?)? onStatus,
  }) async {
    await initPeripheral();

    _broadcastTimer?.cancel();
    _broadcastTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      final payload = jsonEncode({
        'i': _myDeviceId.substring(
          _myDeviceId.length - 4,
        ), // solo últimos 4 chars
        'n': _myName.length > 8
            ? _myName.substring(0, 8)
            : _myName, // max 8 chars
        's': _myStatus == 'SOS' ? 1 : 0, // 1 bit
        'la': double.parse(lat.toStringAsFixed(4)), // menos decimales
        'lo': double.parse(lon.toStringAsFixed(4)),
        'b': battery,
      });
      try {
        await peripheral.BlePeripheral.stopAdvertising();

        final latInt = (lat * 10000).toInt();
        final lonInt = (lon * 10000).toInt();
        final shortName = _myName.length > 6
            ? _myName.substring(0, 6)
            : _myName;

        await peripheral.BlePeripheral.startAdvertising(
          services: [serviceUuid],
          localName: shortName,
          manufacturerData: peripheral.ManufacturerData(
            manufacturerId: 0x1234,
            data: Uint8List.fromList([
              _myStatus == 'SOS' ? 1 : 0,
              (latInt >> 24) & 0xFF,
              (latInt >> 16) & 0xFF,
              (latInt >> 8) & 0xFF,
              latInt & 0xFF,
              (lonInt >> 24) & 0xFF,
              (lonInt >> 16) & 0xFF,
              (lonInt >> 8) & 0xFF,
              lonInt & 0xFF,
              battery,
            ]),
          ),
        );
      } catch (e) {
        debugPrint('BLE broadcast error: $e');
      }
    });
  }

  static void stopBroadcast() {
    _broadcastTimer?.cancel();
    peripheral.BlePeripheral.stopAdvertising();
  }

  // Escanear dispositivos BLE cercanos
  static void startScan(
    Function(Member) onDetected, {
    Function(String)? onRawDetected,
  }) async {
    await fbp.FlutterBluePlus.startScan(timeout: const Duration(seconds: 30));

    _scanSubscription = fbp.FlutterBluePlus.scanResults.listen((results) {
      for (fbp.ScanResult r in results) {
        debugPrint(
          'BLE detectado: ${r.device.remoteId.str} | name: ${r.advertisementData.localName} | mf: ${r.advertisementData.manufacturerData}',
        );

        final name = r.advertisementData.localName;
        final mfData = r.advertisementData.manufacturerData;

        // Reporta cualquier dispositivo BLE cercano
        onRawDetected?.call(
          '${name.isEmpty ? "sin nombre" : name} | mf: ${mfData.keys.toList()}',
        );

        if (name.isEmpty || mfData.isEmpty) continue;
        if (!mfData.containsKey(0x1234)) continue;

        try {
          final bytes = mfData[0x1234]!;
          if (bytes.length < 10) continue;

          final status = bytes[0] == 1 ? 'SOS' : 'OK';
          final latInt =
              (bytes[1] << 24) | (bytes[2] << 16) | (bytes[3] << 8) | bytes[4];
          final lonInt =
              (bytes[5] << 24) | (bytes[6] << 16) | (bytes[7] << 8) | bytes[8];
          final lat = latInt / 10000.0;
          final lon = lonInt / 10000.0;
          final battery = bytes[9];

          final member = Member(
            deviceId: r.device.remoteId.str,
            name: name,
            status: status,
            latitude: lat,
            longitude: lon,
            battery: battery,
            timestamp: DateTime.now().millisecondsSinceEpoch,
          );

          DatabaseService.insertDetection(member);
          onDetected(member);

          if (member.status == 'SOS') {
            handleSosAlert(member);
          }
        } catch (e) {
          debugPrint('Error parseando BLE: $e');
        }
      }
    });
    _scanSubscription = fbp.FlutterBluePlus.scanResults.listen((results) {
      for (fbp.ScanResult r in results) {
        final name = r.advertisementData.localName;
        final mfData = r.advertisementData.manufacturerData;

        if (name.isEmpty || mfData.isEmpty) continue;
        if (!mfData.containsKey(0x1234)) continue;

        try {
          final bytes = mfData[0x1234]!;
          if (bytes.length < 10) continue;

          final status = bytes[0] == 1 ? 'SOS' : 'OK';
          final latInt =
              (bytes[1] << 24) | (bytes[2] << 16) | (bytes[3] << 8) | bytes[4];
          final lonInt =
              (bytes[5] << 24) | (bytes[6] << 16) | (bytes[7] << 8) | bytes[8];
          final lat = latInt / 10000.0;
          final lon = lonInt / 10000.0;
          final battery = bytes[9];

          final member = Member(
            deviceId: r.device.remoteId.str,
            name: name,
            status: status,
            latitude: lat,
            longitude: lon,
            battery: battery,
            timestamp: DateTime.now().millisecondsSinceEpoch,
          );

          DatabaseService.insertDetection(member);
          onDetected(member);

          if (member.status == 'SOS') {
            handleSosAlert(member);
          }
        } catch (e) {
          debugPrint('Error parseando BLE: $e');
        }
      }
    });
  }

  static void stopScan() {
    _scanSubscription?.cancel();
    fbp.FlutterBluePlus.stopScan();
  }

  static void startContinuousScan(
    Function(Member) onDetected, {
    Function(String)? onRawDetected,
  }) {
    startScan(onDetected, onRawDetected: onRawDetected);
    Timer.periodic(const Duration(seconds: 30), (_) {
      stopScan();
      startScan(onDetected, onRawDetected: onRawDetected);
    });
  }

  static Future<void> handleSosAlert(Member member) async {
    if (member.status != 'SOS') return;
    HapticFeedback.heavyImpact();
  }
}
