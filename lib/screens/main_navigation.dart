import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' as fbp;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'home_screen.dart';
import 'map_screen.dart';
import 'sos_screen.dart';
import '../services/database_service.dart';
import '../services/gps_service.dart';
import '../services/ble_service.dart';
import '../models/member.dart';

class MainNavigation extends StatefulWidget {
  final String userName;
  const MainNavigation({super.key, required this.userName});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;
  bool _simulated = false;

  final List<Widget> _screens = [
    const HomeScreen(),
    const MapScreen(),
    const SosScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _requestPermissions();
    _startMissingCheck();
    _checkBle();
    _startBle();
  }

  Future<void> _requestPermissions() async {
    await [
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothAdvertise,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ].request();
  }

  Future<void> _checkBle() async {
    final isSupported = await fbp.FlutterBluePlus.isSupported;
    final adapterState = await fbp.FlutterBluePlus.adapterState.first;
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('BLE: $isSupported | Estado: $adapterState'),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _startBle() async {
    final deviceId = 'DEV_${DateTime.now().millisecondsSinceEpoch}';
    TrailBleService.init(deviceId, widget.userName);

    final position = await GpsService.getCurrentPosition();
    await DatabaseService.insertDetection(
      Member(
        deviceId: deviceId,
        name: widget.userName,
        status: 'OK',
        latitude: position?.latitude ?? 0.0,
        longitude: position?.longitude ?? 0.0,
        battery: 100,
        timestamp: DateTime.now().millisecondsSinceEpoch,
      ),
    );

    await TrailBleService.startBroadcast(
      position?.latitude ?? 0.0,
      position?.longitude ?? 0.0,
      100,
      onStatus: (active, error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                error != null
                    ? '❌ BLE error: $error'
                    : '✅ BLE advertising: $active',
              ),
              backgroundColor: error != null ? Colors.red : Colors.green,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      },
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('📡 Broadcast BLE iniciado'),
          duration: Duration(seconds: 3),
        ),
      );
    }

    GpsService.positionStream().listen((pos) async {
      await TrailBleService.startBroadcast(pos.latitude, pos.longitude, 100);
    });

    TrailBleService.startContinuousScan(
      (member) {
        if (mounted) {
          setState(() {});
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('📶 TrailGuard: ${member.name} | ${member.status}'),
              backgroundColor: Colors.blue,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      },
      onRawDetected: (info) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('🔵 BLE cercano: $info'),
              backgroundColor: Colors.grey[700],
              duration: const Duration(seconds: 2),
            ),
          );
        }
      },
    );
  }

  void _startMissingCheck() {
    Stream.periodic(const Duration(minutes: 1)).listen((_) async {
      final missing = await DatabaseService.getMissingDevices();
      if (missing.isNotEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('⚠️ Sin señal: ${missing.join(', ')}'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    });
  }

  Future<void> _runSimulation() async {
    if (_simulated) return;
    _simulated = true;

    final coords = GpsService.simulatedCoordinates;
    final now = DateTime.now().millisecondsSinceEpoch;

    for (int i = 0; i < coords.length; i++) {
      final c = coords[i];
      final minuteOffset = (i ~/ 4) * 60000;
      await DatabaseService.insertDetection(
        Member(
          deviceId: c['device_id'],
          name: c['name'],
          status: 'OK',
          latitude: c['lat'],
          longitude: c['lon'],
          battery: 80 - i * 2,
          timestamp: now - minuteOffset,
        ),
      );
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Simulación cargada'),
          backgroundColor: Colors.green,
        ),
      );
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
        selectedItemColor: Colors.green[800],
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Grupo'),
          BottomNavigationBarItem(icon: Icon(Icons.map), label: 'Mapa'),
          BottomNavigationBarItem(icon: Icon(Icons.sos), label: 'SOS'),
        ],
      ),
    );
  }
}
