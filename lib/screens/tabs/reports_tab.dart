import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../loan_store.dart';
import '../../utils.dart';
import '../../widgets/glass.dart';
import '../../widgets/premium.dart';

const _slice = [
  Palette.indigo,
  Palette.violet,
  Palette.sky,
  Palette.teal,
  Palette.orange,
  Palette.rose,
];

class ReportsTab extends StatelessWidget {
  final LoanStore store;
  const ReportsTab({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final snaps = store.snaps;
        return RefreshIndicator(
          onRefresh: store.refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 120),
            children: [
              const Text('Reports & Analytics',
                  style: TextStyle(
                      fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: -0.6)),
              const SizedBox(height: 14),
              if (snaps.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 80),
                  child: Column(
                    children: [
                      Text('📊', style: TextStyle(fontSize: 46)),
                      SizedBox(height: 8),
                      Text('Add a loan to see your reports',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w800)),
                    ],
                  ),
                )
              else
                ..._body(),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _body() {
    final snaps = store.snaps;
    final withBalance = snaps.where((s) => s.view.totalOutstanding > 0.5).toList();
    final totalOut = store.totalOutstanding;
    return [
      HeroCard(
        colors: const [Color(0xFF0F2A6B), Color(0xFF2563EB), Color(0xFF0EA5E9)],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Total interest paid',
                style: TextStyle(color: Colors.white70, fontSize: 13)),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(inr(store.totalInterestPaid),
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1)),
            ),
            const SizedBox(height: 16),
            _splitBar(store.totalPrincipalPaid, store.totalInterestPaid),
            const SizedBox(height: 8),
            Row(
              children: [
                _legend(const Color(0xFF6EE7B7), 'Principal ${inr(store.totalPrincipalPaid)}'),
                const SizedBox(width: 16),
                _legend(Colors.white, 'Interest ${inr(store.totalInterestPaid)}'),
              ],
            ),
          ],
        ),
      ),
      const SectionHeader('Outstanding by loan'),
      GlassCard(
        blur: 12,
        radius: 28,
        padding: const EdgeInsets.all(16),
        child: totalOut <= 0
            ? const Padding(
                padding: EdgeInsets.all(20),
                child: Center(child: Text('Nothing outstanding 🎉')),
              )
            : Row(
                children: [
                  SizedBox(
                    width: 150,
                    height: 150,
                    child: PieChart(
                      PieChartData(
                        sectionsSpace: 3,
                        centerSpaceRadius: 42,
                        sections: [
                          for (var i = 0; i < withBalance.length; i++)
                            PieChartSectionData(
                              value: withBalance[i].view.totalOutstanding,
                              color: _slice[i % _slice.length],
                              radius: 26,
                              showTitle: false,
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      children: [
                        for (var i = 0; i < withBalance.length; i++)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 5),
                            child: Row(
                              children: [
                                Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                      color: _slice[i % _slice.length],
                                      shape: BoxShape.circle),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(withBalance[i].loan.loanName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          fontSize: 13, fontWeight: FontWeight.w700)),
                                ),
                                Text(
                                    '${(withBalance[i].view.totalOutstanding / totalOut * 100).toStringAsFixed(0)}%',
                                    style: const TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w900)),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
      const SectionHeader('Paid so far, per loan'),
      ...snaps.map((s) {
        final p = s.view.totalPrincipalPaid;
        final i = s.view.totalInterestPaid;
        return GlassCard(
          radius: 24,
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(s.loan.loanName,
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w900)),
                  ),
                  Text(inr(p + i + s.view.totalPenaltyPaid),
                      style: const TextStyle(
                          fontSize: 14.5, fontWeight: FontWeight.w800)),
                ],
              ),
              const SizedBox(height: 10),
              _splitBar(p, i,
                  principalColor: Palette.green,
                  interestColor: Palette.violet,
                  track: Palette.indigo.withValues(alpha: 0.08)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 16,
                runSpacing: 4,
                children: [
                  _legend(Palette.green, 'Principal ${inr(p)}', dark: true),
                  _legend(Palette.violet, 'Interest ${inr(i)}', dark: true),
                  if (s.view.totalPenaltyPaid > 0)
                    _legend(Palette.rose, 'Penalty ${inr(s.view.totalPenaltyPaid)}',
                        dark: true),
                ],
              ),
            ],
          ),
        );
      }),
      const SectionHeader('Extra costs & savings'),
      GlassCard(
        radius: 26,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          children: [
            _row('Bank charges added', inr(store.totalCharges), Palette.amber),
            const Divider(height: 1),
            _row('Penal charges', inr(store.totalPenalties), Palette.rose),
            const Divider(height: 1),
            _row('Interest saved by prepaying', inr(store.interestSaved),
                Palette.green),
            const Divider(height: 1),
            _row('Monthly EMI (active loans)', inr(store.totalMonthlyEmi),
                Palette.indigo),
          ],
        ),
      ),
    ];
  }

  /// Horizontal two-part bar: principal vs interest.
  Widget _splitBar(double principal, double interest,
      {Color principalColor = const Color(0xFF6EE7B7),
      Color interestColor = Colors.white,
      Color track = const Color(0x33FFFFFF)}) {
    final total = principal + interest;
    final pFlex = total <= 0 ? 1 : (principal / total * 1000).round().clamp(0, 1000);
    final iFlex = total <= 0 ? 0 : 1000 - pFlex;
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 10,
        color: track,
        child: total <= 0
            ? null
            : Row(
                children: [
                  if (pFlex > 0)
                    Expanded(flex: pFlex, child: Container(color: principalColor)),
                  if (iFlex > 0)
                    Expanded(flex: iFlex, child: Container(color: interestColor)),
                ],
              ),
      ),
    );
  }

  Widget _legend(Color c, String t, {bool dark = false}) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(t,
              style: TextStyle(
                  fontSize: 12,
                  color: dark ? Palette.inkSoft : Colors.white,
                  fontWeight: FontWeight.w600)),
        ],
      );

  Widget _row(String label, String value, Color c) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
            const SizedBox(width: 10),
            Expanded(child: Text(label, style: const TextStyle(fontSize: 14))),
            Text(value,
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14.5)),
          ],
        ),
      );
}
