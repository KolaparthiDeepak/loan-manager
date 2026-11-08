import 'package:flutter/material.dart';

import '../loan_engine.dart';
import '../models.dart';
import '../utils.dart';
import '../widgets/glass.dart';

/// "What if I prepay ₹X today?" — recomputes the loan with a hypothetical extra
/// prepayment using the SAME engine (buildTimeline) and shows the additional
/// interest and tenure saved versus the current plan. No new math.
class WhatIfScreen extends StatefulWidget {
  final Loan loan;
  const WhatIfScreen({super.key, required this.loan});

  @override
  State<WhatIfScreen> createState() => _WhatIfScreenState();
}

class _WhatIfScreenState extends State<WhatIfScreen> {
  final _amount = TextEditingController();
  double _amountVal = 0;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  String _today() {
    final n = DateTime.now();
    return '${n.year.toString().padLeft(4, '0')}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
  }

  TimelineView _withExtra(double extra) {
    final base = widget.loan.toEngineInput();
    final payments = List<PaymentInput>.from(base.payments)
      ..add(PaymentInput(
        id: 'whatif',
        amount: extra,
        date: _today(),
        paymentType: 'PREPAYMENT',
      ));
    final modified = base.copyWith(payments: payments);
    return buildTimeline(modified);
  }

  @override
  Widget build(BuildContext context) {
    final current = widget.loan.timeline();
    final extra = _amountVal;
    final projected = extra > 0 ? _withExtra(extra) : current;

    final addlInterest = projected.interestSaved - current.interestSaved;
    final addlMonths = projected.monthsSaved - current.monthsSaved;
    final newOutstanding = projected.totalOutstanding;

    return GlassScaffold(
      title: 'Prepayment What-If',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 40),
        children: [
          GlassCard(
            blur: 14,
            radius: 28,
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('If you prepay this amount today (${widget.loan.loanName}):',
                    style: TextStyle(color: Palette.inkSoft)),
                const SizedBox(height: 12),
                TextField(
                  controller: _amount,
                  keyboardType: TextInputType.number,
                  autofocus: true,
                  onChanged: (v) =>
                      setState(() => _amountVal = double.tryParse(v) ?? 0),
                  decoration: const InputDecoration(
                    labelText: 'Prepayment amount (₹)',
                    prefixIcon: Icon(Icons.bolt_rounded),
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [50000, 100000, 200000, 500000]
                      .map((v) => GlassPill(
                            icon: Icons.add_rounded,
                            label: inr(v),
                            color: Palette.amber,
                            onTap: () {
                              _amount.text = v.toString();
                              setState(() => _amountVal = v.toDouble());
                            },
                          ))
                      .toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          if (extra > 0) ...[
            Row(
              children: [
                Expanded(
                  child: GradientKpi(
                    label: 'Extra interest saved',
                    value: inr(addlInterest),
                    icon: Icons.savings_rounded,
                    colors: const [Color(0xFF34D399), Color(0xFF059669)],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GradientKpi(
                    label: 'Extra tenure cut',
                    value: '$addlMonths mo',
                    icon: Icons.timelapse_rounded,
                    colors: const [Color(0xFF60A5FA), Color(0xFF4F46E5)],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            GlassCard(
              radius: 26,
              child: Column(
                children: [
                  _row('Total interest saved (after this prepay)',
                      inr(projected.interestSaved)),
                  const Divider(),
                  _row('Total tenure cut', '${projected.monthsSaved} months'),
                  const Divider(),
                  _row('Outstanding right after prepay', inr(newOutstanding)),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                'Computed with the same interest engine as the rest of the app '
                '(daily accrual, floating rate). Prepayment goes 100% to principal.',
                style: TextStyle(fontSize: 12, color: Palette.inkSoft),
              ),
            ),
          ] else
            Padding(
              padding: EdgeInsets.only(top: 24),
              child: Text('Enter an amount to see your savings.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Palette.inkSoft)),
            ),
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(child: Text(label)),
          const SizedBox(width: 12),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}
