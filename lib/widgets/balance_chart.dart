import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../loan_engine.dart';

/// Line chart of outstanding principal over the loan timeline. X = event order
/// (with first/last dates labelled), Y = ₹ in lakhs.
class BalanceChart extends StatelessWidget {
  final TimelineView view;
  const BalanceChart({super.key, required this.view});

  @override
  Widget build(BuildContext context) {
    final rows = view.timeline;
    if (rows.length < 2) {
      return const SizedBox.shrink();
    }
    final spots = <FlSpot>[];
    for (var i = 0; i < rows.length; i++) {
      spots.add(FlSpot(i.toDouble(), rows[i].outstandingPrincipal / 100000.0));
    }
    final maxY = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);
    final niceMax = (maxY * 1.15).ceilToDouble();

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 16, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Outstanding principal over time',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 4),
            const Text('₹ in lakhs',
                style: TextStyle(fontSize: 11, color: Colors.black54)),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  minY: 0,
                  maxY: niceMax == 0 ? 1 : niceMax,
                  gridData: FlGridData(show: true, drawVerticalLine: false),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 34,
                        getTitlesWidget: (v, meta) => Text(
                          v.toStringAsFixed(0),
                          style: const TextStyle(fontSize: 10),
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 28,
                        interval: (rows.length - 1).toDouble(),
                        getTitlesWidget: (v, meta) {
                          final i = v.round();
                          if (i < 0 || i >= rows.length) {
                            return const SizedBox.shrink();
                          }
                          final d = rows[i].date;
                          // show MM-DD to keep it short
                          final label = d.length >= 10 ? d.substring(5) : d;
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(label,
                                style: const TextStyle(fontSize: 10)),
                          );
                        },
                      ),
                    ),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: false,
                      color: const Color(0xFF1976d2),
                      barWidth: 2.5,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: const Color(0xFF1976d2).withValues(alpha: 0.12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
