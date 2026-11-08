import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../loan_engine.dart';
import 'glass.dart';

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

    return GlassCard(
      radius: 26,
      padding: const EdgeInsets.fromLTRB(8, 16, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 10),
            child: Text('Outstanding principal over time',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          ),
          Padding(
            padding: EdgeInsets.only(left: 10, top: 2),
            child: Text('₹ in lakhs',
                style: TextStyle(fontSize: 11, color: Palette.inkSoft)),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 200,
            child: LineChart(
              LineChartData(
                minY: 0,
                maxY: niceMax == 0 ? 1 : niceMax,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (v) => FlLine(
                      color: Palette.ink.withValues(alpha: 0.07),
                      strokeWidth: 1,
                      dashArray: [4, 4]),
                ),
                borderData: FlBorderData(show: false),
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) => const Color(0xE62D3A6B),
                    getTooltipItems: (spots) => spots.map((s) {
                      final r = rows[s.x.round().clamp(0, rows.length - 1)];
                      return LineTooltipItem(
                        '${r.date}\n₹${s.y.toStringAsFixed(2)} L',
                        const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600),
                      );
                    }).toList(),
                  ),
                ),
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
                        style: TextStyle(
                            fontSize: 10, color: Palette.inkSoft),
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
                              style: TextStyle(
                                  fontSize: 10, color: Palette.inkSoft)),
                        );
                      },
                    ),
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: false,
                    gradient: const LinearGradient(
                        colors: [Palette.indigo, Palette.violet]),
                    barWidth: 3,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Palette.indigo.withValues(alpha: 0.28),
                          Palette.violet.withValues(alpha: 0.02),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
