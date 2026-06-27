import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'screens/map_screen.dart';
import 'screens/sos_screen.dart';
import 'services/database_service.dart';
import 'services/gps_service.dart';
import 'models/member.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DatabaseService.database; // inicializa SQLite
  runApp(const TrailGuardApp());
}

class TrailGuardApp extends StatelessWidget {
  const TrailGuardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TrailGuard',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
      ),
      home: const MainNavigation(),
    );
  }
}

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

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

  // Carga las coordenadas simuladas en SQLite
  Future<void> _runSimulation() async {
    if (_simulated) return;
    _simulated = true;

    final coords = GpsService.simulatedCoordinates;
    final now = DateTime.now().millisecondsSinceEpoch;

    for (int i = 0; i < coords.length; i++) {
      final c = coords[i];
      // Cada 4 registros = un minuto distinto (4 personas x minuto)
      final minuteOffset = (i ~/ 4) * 60000;

      await DatabaseService.insertDetection(Member(
        deviceId: c['device_id'],
        name: c['name'],
        status: 'OK',
        latitude: c['lat'],
        longitude: c['lon'],
        battery: 80 - i * 2,
        timestamp: now - minuteOffset,
      ));
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Simulación cargada'),
          backgroundColor: Colors.green,
        ),
      );
      setState(() {}); // refresca
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _runSimulation,
        backgroundColor: Colors.green[800],
        foregroundColor: Colors.white,
        icon: const Icon(Icons.play_arrow),
        label: const Text('Simular'),
      ),
    );
  }
}