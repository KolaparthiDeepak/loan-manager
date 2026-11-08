import 'loan_engine.dart';

/// A loan plus its child rows, as stored in Supabase, with a helper to convert
/// into the engine's LoanInput.
class Loan {
  final String id;
  final String loanName;
  final double sanctionedAmount;
  final double rate;
  final double years;
  final String startDate;
  final int emiDay;
  final double monthlyEmi;
  final List<DisbursementInput> disbursements;
  final List<PaymentInput> payments;
  final List<ChargeInput> charges;
  final List<RateChangeInput> rateChanges;
  final List<PenaltyInput> penalties;

  Loan({
    required this.id,
    required this.loanName,
    required this.sanctionedAmount,
    required this.rate,
    required this.years,
    required this.startDate,
    required this.emiDay,
    required this.monthlyEmi,
    required this.disbursements,
    required this.payments,
    this.charges = const [],
    this.rateChanges = const [],
    this.penalties = const [],
  });

  // PostgREST serialises `numeric` columns as STRINGS to keep precision, while
  // int columns come back as numbers — handle both safely.
  static double _d(dynamic v) =>
      v is num ? v.toDouble() : double.parse(v.toString());
  static int _i(dynamic v) =>
      v is num ? v.toInt() : int.parse(v.toString());

  /// Build from the nested select:
  /// loans?select=*,disbursements(*),payments(*)
  factory Loan.fromJson(Map<String, dynamic> j) {
    final disb = ((j['disbursements'] as List?) ?? [])
        .map((d) => DisbursementInput(
              id: d['id'].toString(),
              amount: _d(d['amount']),
              date: d['date'].toString(),
            ))
        .toList();
    final pays = ((j['payments'] as List?) ?? [])
        .map((p) => PaymentInput(
              id: p['id'].toString(),
              amount: _d(p['amount']),
              date: p['date'].toString(),
              sourceMonth:
                  p['source_month'] == null ? null : _i(p['source_month']),
              paymentType: p['payment_type'].toString(),
            ))
        .toList();
    final chg = ((j['charges'] as List?) ?? [])
        .map((c) => ChargeInput(
              id: c['id'].toString(),
              amount: _d(c['amount']),
              date: c['date'].toString(),
              description: (c['description'] ?? '').toString(),
            ))
        .toList();
    final rcs = ((j['rate_changes'] as List?) ?? [])
        .map((r) => RateChangeInput(
              id: r['id'].toString(),
              effectiveDate: r['effective_date'].toString(),
              oldRate: _d(r['old_rate']),
              newRate: _d(r['new_rate']),
              oldEmi: _d(r['old_emi']),
              newEmi: _d(r['new_emi']),
              oldYears: _d(r['old_years']),
              newYears: _d(r['new_years']),
              adjustmentType: r['adjustment_type'].toString(),
            ))
        .toList()
      ..sort((a, b) => a.effectiveDate.compareTo(b.effectiveDate));
    final pens = ((j['penalties'] as List?) ?? [])
        .map((r) => PenaltyInput(
              id: r['id'].toString(),
              delayStart: r['delay_start'].toString(),
              delayEnd: r['delay_end'].toString(),
              leviedDate: r['levied_date'].toString(),
              overdueAmount: _d(r['overdue_amount']),
              ratePct: _d(r['rate']),
              gstPct: _d(r['gst_rate']),
              amount: _d(r['amount']),
              disputed: r['disputed'] == true,
              note: (r['note'] ?? '').toString(),
            ))
        .toList();
    return Loan(
      id: j['id'].toString(),
      loanName: j['loan_name'].toString(),
      sanctionedAmount: _d(j['sanctioned_amount']),
      rate: _d(j['rate']),
      years: _d(j['years']),
      startDate: j['start_date'].toString(),
      emiDay: _i(j['emi_day']),
      monthlyEmi: _d(j['monthly_emi']),
      disbursements: disb,
      payments: pays,
      charges: chg,
      rateChanges: rcs,
      penalties: pens,
    );
  }

  /// Earliest date anything happened on this loan (start date or first disbursement).
  String get earliestDate {
    var d = startDate;
    for (final x in disbursements) {
      if (x.date.compareTo(d) < 0) d = x.date;
    }
    return d;
  }

  LoanInput toEngineInput() => LoanInput(
        loanName: loanName,
        sanctionedAmount: sanctionedAmount,
        rate: rate,
        years: years,
        startDate: startDate,
        emiDay: emiDay,
        monthlyEmi: monthlyEmi,
        disbursements: disbursements,
        payments: payments,
        charges: charges,
        rateChanges: rateChanges,
        penalties: penalties,
      );

  TimelineView timeline({DateTime? untilDate}) =>
      buildTimeline(toEngineInput(), untilDate: untilDate);
}
