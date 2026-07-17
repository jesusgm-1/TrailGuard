import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/database_service.dart';

class MapScreen extends StatefulWidget {
  final String myDeviceId;
  const MapScreen({super.key, required this.myDeviceId});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  List<int> _buckets = [];
  Map<int, List<Map<String, dynamic>>> _dataPerBucket = {};
  bool _loading = true;

  final List<Color> _colors = [
    Colors.blue,
    Colors.red,
    Colors.green,
    Colors.orange,
    Colors.purple,
  ];

  @override
  void initState() {
    super.initState();
    _load();
    Stream.periodic(const Duration(seconds: 5)).listen((_) => _load());
  }

  Future<void> _load() async {
    final buckets = await DatabaseService.getMinuteBuckets();
    final Map<int, List<Map<String, dynamic>>> data = {};
    for (final b in buckets) {
      data[b] = await DatabaseService.getAveragePositions(b);
    }
    setState(() {
      _buckets = buckets;
      _dataPerBucket = data;
      _loading = false;
    });
  }

  // Encuentra mi posición en el bucket actual
  Map<String, dynamic>? _findMe(List<Map<String, dynamic>> members) {
    try {
      return members.firstWhere((m) => m['device_id'] == widget.myDeviceId);
    } catch (_) {
      return members.isNotEmpty ? members.first : null;
    }
  }

  // Convierte lat/lon a coordenadas relativas respecto a "mí"
  // 1 grado lat/lon ≈ 111km → multiplicamos para que se vea bien en pantalla
  List<ScatterSpot> _toRadarSpots(
    List<Map<String, dynamic>> members,
    double myLat,
    double myLon,
  ) {
    final spots = <ScatterSpot>[];
    for (int i = 0; i < members.length; i++) {
      final m = members[i];
      final dLon = ((m['longitude'] as double) - myLon) * 111000; // metros aprox
      final dLat = ((m['latitude'] as double) - myLat) * 111000;
      spots.add(ScatterSpot(
        dLon,
        dLat,
        dotPainter: FlDotCirclePainter(
          radius: m['device_id'] == widget.myDeviceId ? 10 : 8,
          color: m['device_id'] == widget.myDeviceId
              ? Colors.black
              : _colors[i % _colors.length],
          strokeWidth: m['device_id'] == widget.myDeviceId ? 3 : 0,
          strokeColor: Colors.white,
        ),
      ));
    }
    return spots;
  }

  Widget _buildChart(int bucket) {
    final members = _dataPerBucket[bucket] ?? [];
    if (members.isEmpty) {
      return const Center(child: Text('Sin datos para este minuto'));
    }

    final me = _findMe(members);
    final myLat = me?['latitude'] as double? ?? 0.0;
    final myLon = me?['longitude'] as double? ?? 0.0;

    final spots = _toRadarSpots(members, myLat, myLon);

    // Calcular rango dinámico para que todos los puntos quepan
    double maxDist = 50; // mínimo 50 metros de rango
    for (final s in spots) {
      if (s.x.abs() > maxDist) maxDist = s.x.abs();
      if (s.y.abs() > maxDist) maxDist = s.y.abs();
    }
    maxDist = maxDist * 1.3; // margen extra

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Leyenda
          Wrap(
            spacing: 12,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(radius: 6, backgroundColor: Colors.black),
                  const SizedBox(width: 4),
                  const Text('Tú', style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
              ...List.generate(members.length, (i) {
                final m = members[i];
                if (m['device_id'] == widget.myDeviceId) return const SizedBox();
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(radius: 6, backgroundColor: _colors[i % _colors.length]),
                    const SizedBox(width: 4),
                    Text(m['name']),
                  ],
                );
              }),
            ],
          ),
          const SizedBox(height: 8),
          // Indicador de escala
          Text(
            'Radio: ${maxDist.toStringAsFixed(0)} metros',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ScatterChart(
              ScatterChartData(
                scatterSpots: spots,
                minX: -maxDist,
                maxX: maxDist,
                minY: -maxDist,
                maxY: maxDist,
                borderData: FlBorderData(show: true),
                gridData: FlGridData(
                  show: true,
                  drawHorizontalLine: true,
                  drawVerticalLine: true,
                  horizontalInterval: maxDist / 2,
                  verticalInterval: maxDist / 2,
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    axisNameWidget: const Text('Norte ↑', style: TextStyle(fontSize: 11)),
                    sideTitles: SideTitles(showTitles: true, reservedSize: 40),
                  ),
                  bottomTitles: AxisTitles(
                    axisNameWidget: const Text('Este →', style: TextStyle(fontSize: 11)),
                    sideTitles: SideTitles(showTitles: true, reservedSize: 30),
                  ),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                scatterTouchData: ScatterTouchData(
                  touchTooltipData: ScatterTouchTooltipData(
                    getTooltipItems: (spot) {
                      final idx = spots.indexOf(spot);
                      if (idx >= 0 && idx < members.length) {
                        final m = members[idx];
                        final dist = (spot.x * spot.x + spot.y * spot.y);
                        final distM = dist == 0 ? 0 : (dist).toStringAsFixed(0);
                        return ScatterTooltipItem(
                          m['device_id'] == widget.myDeviceId
                              ? 'Tú'
                              : '${m['name']}\n~${distM}m',
                          textStyle: const TextStyle(color: Colors.white),
                        );
                      }
                      return null;
                    },
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            children: List.generate(members.length, (i) {
              final m = members[i];
              final isMe = m['device_id'] == widget.myDeviceId;
              return Chip(
                avatar: CircleAvatar(
                  backgroundColor: isMe ? Colors.black : _colors[i % _colors.length],
                  child: Text(
                    isMe ? 'Yo' : m['name'][0],
                    style: const TextStyle(color: Colors.white, fontSize: 10),
                  ),
                ),
                label: Text(
                  isMe
                      ? '${m['name']} (tú)'
                      : '${m['name']} | ${(m['latitude'] as double).toStringAsFixed(4)}, ${(m['longitude'] as double).toStringAsFixed(4)}',
                  style: const TextStyle(fontSize: 11),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_buckets.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Movilidad'),
          backgroundColor: Colors.green[800],
          foregroundColor: Colors.white,
        ),
        body: const Center(child: Text('Sin datos aún. Esperando detecciones BLE...')),
      );
    }

    return DefaultTabController(
      length: _buckets.length,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Movilidad por Minuto'),
          backgroundColor: Colors.green[800],
          foregroundColor: Colors.white,
          bottom: TabBar(
            isScrollable: true,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white60,
            tabs: _buckets
                .asMap()
                .entries
                .map((e) => Tab(text: 'Min ${e.key + 1}'))
                .toList(),
          ),
        ),
        body: TabBarView(
          children: _buckets.map((b) => _buildChart(b)).toList(),
        ),
      ),
    );
  }
}