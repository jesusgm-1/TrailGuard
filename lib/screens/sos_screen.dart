import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/ble_service.dart';

class SosScreen extends StatefulWidget {
  const SosScreen({super.key});

  @override
  State<SosScreen> createState() => _SosScreenState();
}

class _SosScreenState extends State<SosScreen> {
  bool _sosActive = false;

  void _toggleSos() {
    HapticFeedback.heavyImpact();
    setState(() => _sosActive = !_sosActive);
    BleService.setStatus(_sosActive ? 'SOS' : 'OK');

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_sosActive ? '🆘 SOS activado' : '✅ SOS desactivado'),
        backgroundColor: _sosActive ? Colors.red : Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SOS'),
        backgroundColor: Colors.green[800],
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _sosActive ? 'SOS ACTIVO' : 'Presiona si necesitas ayuda',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: _sosActive ? Colors.red : Colors.grey[700],
              ),
            ),
            const SizedBox(height: 40),
            GestureDetector(
              onTap: _toggleSos,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _sosActive ? Colors.red : Colors.red[100],
                  boxShadow: _sosActive
                      ? [
                          BoxShadow(
                            color: Colors.red.withOpacity(0.6),
                            blurRadius: 30,
                            spreadRadius: 10,
                          )
                        ]
                      : [],
                ),
                child: const Center(
                  child: Text(
                    'SOS',
                    style: TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 40),
            if (_sosActive)
              const Text(
                'Tu grupo ha sido alertado',
                style: TextStyle(color: Colors.red, fontSize: 16),
              ),
          ],
        ),
      ),
    );
  }
}