import 'package:flutter/material.dart';

import '../loan_engine.dart';
import '../models.dart';
import '../utils.dart';
import '../widgets/glass.dart';

/// Two views of the schedule:
///  * Upcoming  — projected from TODAY's real outstanding principal at the
///                CURRENT rate and EMI (so it reflects every rate change,
///                charge and prepayment recorded so far).
///  * Original  — the day-one plan: sanctioned amount, one rate, full tenure.
class ScheduleScreen extends StatefulWidget {
  final Loan loan;
  const ScheduleScreen({super.key, required this.loan});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  bool _upcoming = true;

  @override
  Widget build(BuildContext context) {
    final loan = widget.loan;
    final view = loan.timeline();
    final upcoming = projectUpcoming(
      outstanding: view.outstandingPrincipal,
      annualRate: loan.rate,
      emi: loan.monthlyEmi,
      firstDueDate: view.nextDueDate ?? view.asOfDate,
    );
    final startRate =
        loan.rateChanges.isEmpty ? loan.rate : loan.rateChanges.first.oldRate;
    final startYears =
        loan.rateChanges.isEmpty ? loan.years : loan.rateChanges.first.oldYears;
    final original = getEmiSchedule(loan.sanctionedAmount, startRate, startYears);

    final totalUpInterest = upcoming.fold<double>(0, (s, r) => s + r.interest);
    final totalOrigInterest = original.fold<double>(0, (s, r) => s + r.interest);

    return GlassScaffold(
      title: '${loan.loanName} — Schedule',
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
            child: SizedBox(
              width: double.infinity,
              child: SegmentedButton<bool>(
                style: SegmentedButton.styleFrom(
                  backgroundColor: Palette.glass(0.5),
                  selectedBackgroundColor: Palette.indigo,
                  selectedForegroundColor: Colors.white,
                  side: BorderSide(color: Palette.glass(0.9)),
                ),
                segments: const [
                  ButtonSegment(value: true, label: Text('Upcoming')),
                  ButtonSegment(value: false, label: Text('Original plan')),
                ],
                selected: {_upcoming},
                onSelectionChanged: (s) => setState(() => _upcoming = s.first),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: GlassCard(
              blur: 12,
              radius: 24,
              padding: const EdgeInsets.all(14),
              child: _upcoming
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 22,
                          runSpacing: 8,
                          children: [
                            _meta('Starting principal',
                                inr(view.outstandingPrincipal)),
                            _meta('Rate', '${loan.rate}% p.a.'),
                            _meta('EMI', inr(loan.monthlyEmi)),
                            _meta('Remaining EMIs', '${upcoming.length}'),
                            _meta('Projected interest', inr(totalUpInterest)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                            'Each month: interest = opening balance × ${loan.rate}% ÷ 12; '
                            'principal = EMI − interest. Accrued interest to date '
                            '(${inr(view.accruedInterest)}) is collected with the next EMI.',
                            style: TextStyle(
                                fontSize: 12, color: Palette.inkSoft)),
                        if (upcoming.isEmpty)
                          const Padding(
                            padding: EdgeInsets.only(top: 6),
                            child: Text(
                                'Nothing to project (loan cleared, or EMI does not cover the interest).',
                                style: TextStyle(color: Palette.rose)),
                          ),
                      ],
                    )
                  : Wrap(
                      spacing: 22,
                      runSpacing: 8,
                      children: [
                        _meta('Months', '${original.length}'),
                        _meta('Monthly EMI',
                            inr(original.isEmpty ? 0 : original.first.emi)),
                        _meta('Total interest (projected)',
                            inr(totalOrigInterest)),
                        _meta('Rate', '$startRate% p.a. (at start)'),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: GlassCard(
                radius: 26,
                padding: EdgeInsets.zero,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(26),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SingleChildScrollView(
                      child: _upcoming
                          ? DataTable(
                              columnSpacing: 20,
                              headingRowColor: WidgetStateProperty.all(
                                  Palette.indigo.withValues(alpha: 0.08)),
                              columns: const [
                                DataColumn(label: Text('#')),
                                DataColumn(label: Text('Due')),
                                DataColumn(label: Text('Opening')),
                                DataColumn(label: Text('Interest')),
                                DataColumn(label: Text('Principal')),
                                DataColumn(label: Text('EMI')),
                                DataColumn(label: Text('Closing')),
                              ],
                              rows: upcoming
                                  .map((r) => DataRow(cells: [
                                        DataCell(Text('${r.n}')),
                                        DataCell(Text(r.dueDate)),
                                        DataCell(Text(inr(r.openingBalance))),
                                        DataCell(Text(inr(r.interest))),
                                        DataCell(Text(inr(r.principal))),
                                        DataCell(Text(inr(r.emi))),
                                        DataCell(Text(inr(r.closingBalance),
                                            style: const TextStyle(
                                                fontWeight: FontWeight.w700))),
                                      ]))
                                  .toList(),
                            )
                          : DataTable(
                              columnSpacing: 20,
                              headingRowColor: WidgetStateProperty.all(
                                  Palette.indigo.withValues(alpha: 0.08)),
                              columns: const [
                                DataColumn(label: Text('Month')),
                                DataColumn(label: Text('EMI')),
                                DataColumn(label: Text('Principal')),
                                DataColumn(label: Text('Interest')),
                                DataColumn(label: Text('Balance')),
                              ],
                              rows: original
                                  .map((r) => DataRow(cells: [
                                        DataCell(Text('${r.month}')),
                                        DataCell(Text(inr(r.emi))),
                                        DataCell(Text(inr(r.principal))),
                                        DataCell(Text(inr(r.interest))),
                                        DataCell(Text(inr(r.balance),
                                            style: const TextStyle(
                                                fontWeight: FontWeight.w700))),
                                      ]))
                                  .toList(),
                            ),
                    ),
                  ),
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
        Text(label,
            style: TextStyle(fontSize: 11.5, color: Palette.inkSoft)),
        const SizedBox(height: 2),
        Text(value,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5)),
      ],
    );
  }
}
