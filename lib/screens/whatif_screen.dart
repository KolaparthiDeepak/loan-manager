import 'package:flutter/material.dart';

import '../loan_engine.dart';
import '../models.dart';
import '../utils.dart';

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
    final modified = LoanInput(
      loanName: base.loanName,
      sanctionedAmount: base.sanctionedAmount,
      rate: base.rate,
      years: base.years,
      startDate: base.startDate,
      emiDay: base.emiDay,
      monthlyEmi: base.monthlyEmi,
      disbursements: base.disbursements,
      payments: payments,
    );
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Prepayment What-If'),
        backgroundColor: const Color(0xFF1976d2),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('If you prepay this amount today (${widget.loan.loanName}):',
              style: const TextStyle(color: Colors.black54)),
          const SizedBox(height: 12),
          TextField(
            controller: _amount,
            keyboardType: TextInputType.number,
            autofocus: true,
            onChanged: (v) =>
                setState(() => _amountVal = double.tryParse(v) ?? 0),
            decoration: const InputDecoration(
              labelText: 'Prepayment amount (₹)',
              prefixIcon: Icon(Icons.bolt),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [50000, 100000, 200000, 500000]
                .map((v) => ActionChip(
                      label: Text(inr(v)),
                      onPressed: () {
                        _amount.text = v.toString();
                        setState(() => _amountVal = v.toDouble());
                      },
                    ))
                .toList(),
          ),
          const SizedBox(height: 20),
          if (extra > 0) ...[
            Row(
              children: [
                Expanded(
                  child: _resultCard(
                    '💰 Extra Interest Saved',
                    inr(addlInterest),
                    const [Color(0xFF43A047), Color(0xFF1B5E20)],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _resultCard(
                    '⏱️ Extra Tenure Cut',
                    '$addlMonths mo',
                    const [Color(0xFF1E88E5), Color(0xFF0D47A1)],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
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
            ),
            const SizedBox(height: 8),
            const Text(
              'Computed with the same interest engine as the rest of the app '
              '(daily accrual, floating rate). Prepayment goes 100% to principal.',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ] else
            const Padding(
              padding: EdgeInsets.only(top: 24),
              child: Text('Enter an amount to see your savings.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.black54)),
            ),
        ],
      ),
    );
  }

  Widget _resultCard(String label, String value, List<Color> colors) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: colors),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 6),
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold)),
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
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
