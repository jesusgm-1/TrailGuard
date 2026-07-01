import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/database_service.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

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

  // Convierte lat/lon a puntos cartesianos relativos
  List<ScatterSpot> _toSpots(
    List<Map<String, dynamic>> members,
    int colorIndex,
  ) {
    return members.map((m) {
      return ScatterSpot(
        (m['longitude'] as double) * 1000 % 10,
        (m['latitude'] as double) * 1000 % 10,
        dotPainter: FlDotCirclePainter(
          radius: 8,
          color: _colors[colorIndex % _colors.length],
        ),
      );
    }).toList();
  }

  Widget _buildChart(int bucket) {
    final members = _dataPerBucket[bucket] ?? [];
    if (members.isEmpty) {
      return const Center(child: Text('Sin datos para este minuto'));
    }

    final spots = <ScatterSpot>[];
    for (int i = 0; i < members.length; i++) {
      spots.add(
        ScatterSpot(
          (members[i]['longitude'] as double) * 1000 % 10,
          (members[i]['latitude'] as double) * 1000 % 10,
          dotPainter: FlDotCirclePainter(
            radius: 8,
            color: _colors[i % _colors.length],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Wrap(
            spacing: 12,
            children: List.generate(members.length, (i) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: 6,
                    backgroundColor: _colors[i % _colors.length],
                  ),
                  const SizedBox(width: 4),
                  Text(members[i]['name']),
                ],
              );
            }),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ScatterChart(
              ScatterChartData(
                scatterSpots: spots,
                minX: 0,
                maxX: 10,
                minY: 0,
                maxY: 10,
                borderData: FlBorderData(show: true),
                gridData: const FlGridData(show: true),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    axisNameWidget: const Text('Latitud'),
                    sideTitles: SideTitles(showTitles: true, reservedSize: 40),
                  ),
                  bottomTitles: AxisTitles(
                    axisNameWidget: const Text('Longitud'),
                    sideTitles: SideTitles(showTitles: true, reservedSize: 30),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                scatterTouchData: ScatterTouchData(
                  touchTooltipData: ScatterTouchTooltipData(
                    getTooltipItems: (spot) {
                      final idx = spots.indexOf(spot);
                      if (idx >= 0 && idx < members.length) {
                        return ScatterTooltipItem(
                          members[idx]['name'],
                          textStyle: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        );
                      }
                      return null;
                    },
                  ),
                ),
              ),
            ),
          ),
          // Nombres debajo del plot
          const SizedBox(height: 8),
          Wrap(
            spacing: 16,
            children: List.generate(members.length, (i) {
              return Chip(
                avatar: CircleAvatar(
                  backgroundColor: _colors[i % _colors.length],
                  child: Text(
                    members[i]['name'][0],
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
                label: Text(
                  '${members[i]['name']} '
                  '(${(members[i]['latitude'] as double).toStringAsFixed(4)}, '
                  '${(members[i]['longitude'] as double).toStringAsFixed(4)})',
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
        body: const Center(child: Text('Sin datos aún. Inicia la simulación.')),
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
