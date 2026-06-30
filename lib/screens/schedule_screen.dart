import 'package:flutter/material.dart';

import '../loan_engine.dart';
import '../models.dart';
import '../utils.dart';

/// Full amortization schedule for a loan — the projected month-by-month EMI
/// breakdown (principal / interest / closing balance), computed exactly like
/// the web app's getEmiSchedule(sanctionedAmount, rate, years).
class ScheduleScreen extends StatelessWidget {
  final Loan loan;
  const ScheduleScreen({super.key, required this.loan});

  @override
  Widget build(BuildContext context) {
    final schedule =
        getEmiSchedule(loan.sanctionedAmount, loan.rate, loan.years);
    final totalInterest =
        schedule.fold<double>(0, (s, r) => s + r.interest);

    return Scaffold(
      appBar: AppBar(
        title: Text('${loan.loanName} — Schedule'),
        backgroundColor: const Color(0xFF1976d2),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            color: const Color(0xFFE3F2FD),
            child: Wrap(
              spacing: 20,
              runSpacing: 6,
              children: [
                _meta('Months', '${schedule.length}'),
                _meta('Monthly EMI',
                    inr(schedule.isEmpty ? 0 : schedule.first.emi)),
                _meta('Total interest (projected)', inr(totalInterest)),
                _meta('Rate', '${loan.rate}% p.a.'),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SingleChildScrollView(
                child: DataTable(
                  columnSpacing: 20,
                  headingRowColor:
                      WidgetStateProperty.all(const Color(0xFFF5F5F5)),
                  columns: const [
                    DataColumn(label: Text('Month')),
                    DataColumn(label: Text('EMI')),
                    DataColumn(label: Text('Principal')),
                    DataColumn(label: Text('Interest')),
                    DataColumn(label: Text('Balance')),
                  ],
                  rows: schedule
                      .map((r) => DataRow(cells: [
                            DataCell(Text('${r.month}')),
                            DataCell(Text(inr(r.emi))),
                            DataCell(Text(inr(r.principal))),
                            DataCell(Text(inr(r.interest))),
                            DataCell(Text(inr(r.balance))),
                          ]))
                      .toList(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _meta(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.black54)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    );
  }
}
