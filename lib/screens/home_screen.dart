import 'package:flutter/material.dart';
import '../services/database_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Map<String, dynamic>> _members = [];
  List<String> _missing = [];

  @override
  void initState() {
    super.initState();
    _load();
    // Refresca cada 5 segundos
    Stream.periodic(const Duration(seconds: 5)).listen((_) => _load());
  }

  Future<void> _load() async {
    final members = await DatabaseService.getLatestPerDevice();
    final missing = await DatabaseService.getMissingDevices();
    setState(() {
      _members = members;
      _missing = missing;
    });
  }

  Color _statusColor(String status) =>
      status == 'SOS' ? Colors.red : Colors.green;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('TrailGuard — Grupo'),
        backgroundColor: Colors.green[800],
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          if (_missing.isNotEmpty)
            Container(
              color: Colors.orange[100],
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  const Icon(Icons.warning, color: Colors.orange),
                  const SizedBox(width: 8),
                  Text(
                    'Sin señal: ${_missing.join(', ')}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          Expanded(
            child: _members.isEmpty
                ? const Center(child: Text('Sin miembros detectados aún'))
                : ListView.builder(
                    itemCount: _members.length,
                    itemBuilder: (context, i) {
                      final m = _members[i];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: _statusColor(m['status']),
                          child: Text(
                            m['name'][0],
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                        title: Text(m['name']),
                        subtitle: Text(
                          'Lat: ${m['latitude'].toStringAsFixed(5)}  '
                          'Lon: ${m['longitude'].toStringAsFixed(5)}',
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              m['status'],
                              style: TextStyle(
                                color: _statusColor(m['status']),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text('🔋 ${m['battery']}%'),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}