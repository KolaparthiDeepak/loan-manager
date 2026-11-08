// ============================================================================
// loan_engine.dart
// A FAITHFUL Dart port of server/routes/loans.js from the web app.
// Same algorithm, same rounding, same date math — no calculation logic changed.
//
// Verified against golden numbers (loan "Home Loan", untilDate 2026-06-30):
//   outstandingPrincipal 8031059, accruedInterest 40155, totalOutstanding 8071214,
//   totalInterestPaid 117059, totalPrincipalPaid 271913, totalPrepayments 141736,
//   interestSaved 270087, originalTotalInterest 5834006, monthsSaved 4.
// ============================================================================

import 'dart:math' as math;

const int _msPerDay = 24 * 60 * 60 * 1000;

/// Mirrors JS `round2 = (v) => Math.round(Number(v))` — rounds to whole rupees.
/// (For the positive money values used here, Dart's .round() matches Math.round.)
double round2(num value) => value.round().toDouble();

String _pad(int n, int w) => n.toString().padLeft(w, '0');

String toDateString(DateTime d) {
  final u = d.toUtc();
  return '${_pad(u.year, 4)}-${_pad(u.month, 2)}-${_pad(u.day, 2)}';
}

/// Mirrors `parseDate`: parses 'YYYY-MM-DD' as a UTC midnight instant.
DateTime? parseDate(String? value) {
  if (value == null || value.isEmpty) return null;
  try {
    return DateTime.parse('${value}T00:00:00.000Z');
  } catch (_) {
    return null;
  }
}

int dayDiff(DateTime from, DateTime to) {
  final diff =
      (to.millisecondsSinceEpoch - from.millisecondsSinceEpoch) ~/ _msPerDay;
  return diff < 0 ? 0 : diff;
}

/// EMI = P * r * (1+r)^n / ((1+r)^n - 1)  — identical to calculateEMI().
double calculateEmi(num principal, num rate, num years) {
  final p = principal.toDouble();
  final r = rate.toDouble();
  final tenure = (years * 12).toDouble();
  if (tenure <= 0) return 0;
  if (r == 0) return p / tenure;
  final monthlyRate = r / (12 * 100);
  final pow = math.pow(1 + monthlyRate, tenure).toDouble();
  return (p * monthlyRate * pow) / (pow - 1);
}

String? getNextDueDate(int emiDay, String fromDateInput) {
  final fromDate = DateTime.parse('${fromDateInput}T00:00:00.000Z');
  final year = fromDate.year;
  final month = fromDate.month; // 1..12 (JS used 0..11 then +month index)
  // JS: due = Date.UTC(year, month0, emiDay); if day>emiDay -> next month.
  var due = DateTime.utc(year, month, emiDay);
  if (fromDate.day > emiDay) {
    due = DateTime.utc(year, month + 1, emiDay);
  }
  return toDateString(due);
}

// ---- amortization schedule (for display + parity with getEmiSchedule) ------
class ScheduleRow {
  final int month;
  final double emi;
  final double principal;
  final double interest;
  final double balance;
  bool paid;
  ScheduleRow(this.month, this.emi, this.principal, this.interest, this.balance,
      {this.paid = false});
}

List<ScheduleRow> getEmiSchedule(num principal, num rate, num years) {
  final monthlyRate = rate / (12 * 100);
  final tenure = (years * 12).toInt();
  final emi = calculateEmi(principal, rate, years);
  final schedule = <ScheduleRow>[];
  var balance = principal.toDouble();
  for (var i = 0; i < tenure; i++) {
    final interest = round2(balance * monthlyRate);
    final principalPaid = round2(_min(balance, emi - interest));
    balance = round2(_max(0, balance - principalPaid));
    schedule.add(ScheduleRow(i + 1, round2(emi), principalPaid, interest, balance));
  }
  return schedule;
}

// ---- input model -----------------------------------------------------------
class DisbursementInput {
  final String id;
  final double amount;
  final String date;
  DisbursementInput({required this.id, required this.amount, required this.date});
}

class PaymentInput {
  final String id;
  final double amount;
  final String date;
  final int? sourceMonth;
  final String paymentType; // 'EMI_PAYMENT' | 'PREPAYMENT'
  PaymentInput({
    required this.id,
    required this.amount,
    required this.date,
    this.sourceMonth,
    required this.paymentType,
  });
}

/// A fee/charge levied by the bank during the tenure. It is capitalised, i.e.
/// added to the outstanding principal (and therefore accrues interest).
class ChargeInput {
  final String id;
  final double amount;
  final String date;
  final String description;
  ChargeInput({
    required this.id,
    required this.amount,
    required this.date,
    this.description = '',
  });
}

/// A floating-rate change that is effective from a specific date.
/// Interest before [effectiveDate] accrues at [oldRate], on/after it at [newRate].
class RateChangeInput {
  final String id;
  final String effectiveDate; // YYYY-MM-DD
  final double oldRate;
  final double newRate;
  final double oldEmi;
  final double newEmi;
  final double oldYears;
  final double newYears;
  final String adjustmentType; // 'KEEP_EMI' | 'KEEP_TENURE'
  RateChangeInput({
    required this.id,
    required this.effectiveDate,
    required this.oldRate,
    required this.newRate,
    required this.oldEmi,
    required this.newEmi,
    required this.oldYears,
    required this.newYears,
    required this.adjustmentType,
  });
}

/// One slice of an interest accrual period during which a single rate applied.
/// Exposed so the UI can show the exact working: principal x rate x days / 365.
class AccrualSegment {
  final String from;
  final String to;
  final int days;
  final double rate; // annual %
  final double principal;
  final double interest; // unrounded
  AccrualSegment(this.from, this.to, this.days, this.rate, this.principal,
      this.interest);
}

/// A penal charge for a delayed EMI: [overdueAmount] x [ratePct] p.a. for the
/// days between [delayStart] and [delayEnd], plus GST. It is NOT capitalised
/// (no interest is ever charged on it) and is recovered from the next EMI after
/// interest. [amount] is the booked figure in whole rupees. A [disputed] penalty
/// is listed on the ledger but has no effect on any balance.
class PenaltyInput {
  final String id;
  final String delayStart; // first day the EMI was overdue (the due date)
  final String delayEnd; // day the EMI was finally paid
  final String leviedDate; // day the bank posted the charge
  final double overdueAmount;
  final double ratePct;
  final double gstPct;
  final double amount; // booked, whole rupees (penalty + GST)
  final bool disputed;
  final String note;
  PenaltyInput({
    required this.id,
    required this.delayStart,
    required this.delayEnd,
    required this.leviedDate,
    required this.overdueAmount,
    required this.ratePct,
    required this.gstPct,
    required this.amount,
    this.disputed = false,
    this.note = '',
  });
}

/// The arithmetic of a penal charge, kept explicit so the UI can show it.
class PenaltyCalc {
  final int days;
  final double penalty; // overdue x rate x days / 365, to the paisa
  final double gst; // penalty x gst%, to the paisa
  final double total; // penalty + gst, to the paisa
  final double booked; // total rounded to whole rupees (what the ledger books)
  PenaltyCalc(this.days, this.penalty, this.gst, this.total, this.booked);
}

double _paise(double v) => (v * 100).round() / 100.0;

PenaltyCalc computePenalty({
  required double overdueAmount,
  required double ratePct,
  required double gstPct,
  required DateTime delayStart,
  required DateTime delayEnd,
}) {
  final days = dayDiff(delayStart, delayEnd);
  final penalty = _paise(overdueAmount * (ratePct / 100) * (days / 365));
  final gst = _paise(penalty * (gstPct / 100));
  final total = _paise(penalty + gst);
  return PenaltyCalc(days, penalty, gst, total, round2(total));
}

class LoanInput {
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
  LoanInput({
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

  LoanInput copyWith({
    double? rate,
    List<DisbursementInput>? disbursements,
    List<PaymentInput>? payments,
    List<ChargeInput>? charges,
    List<RateChangeInput>? rateChanges,
    List<PenaltyInput>? penalties,
  }) =>
      LoanInput(
        loanName: loanName,
        sanctionedAmount: sanctionedAmount,
        rate: rate ?? this.rate,
        years: years,
        startDate: startDate,
        emiDay: emiDay,
        monthlyEmi: monthlyEmi,
        disbursements: disbursements ?? this.disbursements,
        payments: payments ?? this.payments,
        charges: charges ?? this.charges,
        rateChanges: rateChanges ?? this.rateChanges,
        penalties: penalties ?? this.penalties,
      );

  /// The loan as it stood on [date]: only events dated on/before it.
  /// [rateOverride] sets the starting rate (used when no history exists yet).
  LoanInput asOf(String date, {double? rateOverride}) => copyWith(
        rate: rateOverride,
        disbursements:
            disbursements.where((e) => e.date.compareTo(date) <= 0).toList(),
        payments: payments.where((e) => e.date.compareTo(date) <= 0).toList(),
        charges: charges.where((e) => e.date.compareTo(date) <= 0).toList(),
        rateChanges:
            rateChanges.where((e) => e.effectiveDate.compareTo(date) <= 0).toList(),
        penalties:
            penalties.where((e) => e.leviedDate.compareTo(date) <= 0).toList(),
      );
}

// ---- output model ----------------------------------------------------------
class TimelineRow {
  final String date;
  final String eventType; // DISBURSEMENT | CHARGE | EMI_PAYMENT | PREPAYMENT | ACCRUAL
  final double amount;
  final int days;
  final double periodInterest;
  final double interestPaid;
  final double penaltyPaid; // part of an EMI that cleared penal charges
  final double principalPaid;
  final double outstandingPrincipal;
  final double accruedInterest;
  final double totalOutstanding;
  final int? sourceMonth;
  final String? note;
  // For delete support: the DB row this timeline entry came from.
  // null on ACCRUAL rows (synthetic, not deletable).
  final String? transactionId;
  final String? transactionKind; // 'disbursement' | 'payment' | 'charge' | 'rate_change' | 'penalty'
  // Transparency: the rate(s) used and the exact working for periodInterest.
  final double rate; // annual % in force at the end of this row's period
  final List<AccrualSegment> segments;
  TimelineRow({
    required this.date,
    required this.eventType,
    required this.amount,
    required this.days,
    required this.periodInterest,
    this.interestPaid = 0,
    this.penaltyPaid = 0,
    this.principalPaid = 0,
    required this.outstandingPrincipal,
    required this.accruedInterest,
    required this.totalOutstanding,
    this.sourceMonth,
    this.note,
    this.transactionId,
    this.transactionKind,
    this.rate = 0,
    this.segments = const [],
  });
}

class TimelineView {
  final String asOfDate;
  final double monthlyEmi;
  final String? nextDueDate;
  final double sanctionedAmount;
  final double totalDisbursed;
  final double undisbursedAmount;
  final double totalInterestPaid;
  final double totalPrincipalPaid;
  final double outstandingPrincipal;
  final double accruedInterest;
  final double totalOutstanding;
  final double totalPrepayments;
  final double totalCharges;
  final double totalPenalties; // booked, excluding disputed
  final double penaltyDue; // booked but not yet recovered by an EMI
  final double totalPenaltyPaid;
  final double interestSaved;
  final double originalTotalInterest;
  final int monthsSaved;
  final List<TimelineRow> timeline;
  TimelineView({
    required this.asOfDate,
    required this.monthlyEmi,
    required this.nextDueDate,
    required this.sanctionedAmount,
    required this.totalDisbursed,
    required this.undisbursedAmount,
    required this.totalInterestPaid,
    required this.totalPrincipalPaid,
    required this.outstandingPrincipal,
    required this.accruedInterest,
    required this.totalOutstanding,
    required this.totalPrepayments,
    this.totalCharges = 0,
    this.totalPenalties = 0,
    this.penaltyDue = 0,
    this.totalPenaltyPaid = 0,
    required this.interestSaved,
    required this.originalTotalInterest,
    required this.monthsSaved,
    required this.timeline,
  });
}

class _Event {
  final String type; // DISBURSEMENT | CHARGE | PREPAYMENT | EMI_PAYMENT
  final String date;
  final double amount;
  final int? sourceMonth;
  final int seq; // insertion order tiebreaker -> matches V8 stable sort
  final String txId;
  final String txKind; // 'disbursement' | 'payment' | 'charge'
  final String? note;
  final RateChangeInput? rc;
  final PenaltyInput? pen;
  _Event(this.type, this.date, this.amount, this.sourceMonth, this.seq,
      this.txId, this.txKind,
      {this.note, this.rc, this.pen});
}

int _rank(String type) {
  switch (type) {
    case 'RATE_CHANGE':
      return 0;
    case 'DISBURSEMENT':
      return 1;
    case 'CHARGE':
    case 'PENALTY':
      return 2;
    default:
      return 3;
  }
}

double _min(double a, double b) => a < b ? a : b;
double _max(double a, double b) => a > b ? a : b;

/// Faithful port of buildTimeline(loan, untilDateInput).
TimelineView buildTimeline(LoanInput loan, {DateTime? untilDate}) {
  final startDateStr = loan.startDate;
  final startDate = parseDate(startDateStr)!;

  var seq = 0;
  final events = <_Event>[];
  for (final d in loan.disbursements) {
    events.add(_Event(
        'DISBURSEMENT', d.date, d.amount, null, seq++, d.id, 'disbursement'));
  }
  for (final p in loan.payments) {
    final type = p.paymentType == 'PREPAYMENT' ? 'PREPAYMENT' : 'EMI_PAYMENT';
    events.add(
        _Event(type, p.date, p.amount, p.sourceMonth, seq++, p.id, 'payment'));
  }

  for (final c in loan.charges) {
    events.add(_Event('CHARGE', c.date, c.amount, null, seq++, c.id, 'charge',
        note: c.description));
  }
  for (final rc in loan.rateChanges) {
    events.add(_Event('RATE_CHANGE', rc.effectiveDate, 0, null, seq++, rc.id,
        'rate_change',
        rc: rc));
  }

  for (final pn in loan.penalties) {
    events.add(_Event('PENALTY', pn.leviedDate, pn.amount, null, seq++, pn.id,
        'penalty',
        pen: pn));
  }

  events.removeWhere(
      (e) => e.date.isEmpty || (e.type != 'RATE_CHANGE' && e.amount <= 0));
  events.sort((a, b) {
    if (a.date.compareTo(b.date) < 0) return -1;
    if (a.date.compareTo(b.date) > 0) return 1;
    if (a.type == b.type) return a.seq.compareTo(b.seq);
    return _rank(a.type).compareTo(_rank(b.type));
  });

  // ---- rate history: rate in force on any date -----------------------------
  final changes = List<RateChangeInput>.from(loan.rateChanges)
    ..sort((a, b) => a.effectiveDate.compareTo(b.effectiveDate));
  final initialRate = changes.isEmpty ? loan.rate : changes.first.oldRate;
  double rateAt(DateTime d) {
    var r = initialRate;
    for (final c in changes) {
      if (parseDate(c.effectiveDate)!.millisecondsSinceEpoch <=
          d.millisecondsSinceEpoch) {
        r = c.newRate;
      }
    }
    return r;
  }

  /// Splits [from, to) at every rate-change date and prices each slice with
  /// the rate that was in force: principal x (rate/100) x (days/365).
  List<AccrualSegment> accrue(double principal, DateTime from, DateTime to) {
    final segs = <AccrualSegment>[];
    final fromMs = from.millisecondsSinceEpoch;
    final toMs = to.millisecondsSinceEpoch;
    if (toMs <= fromMs) return segs;
    final cuts = <DateTime>[from];
    for (final c in changes) {
      final d = parseDate(c.effectiveDate)!;
      if (d.millisecondsSinceEpoch > fromMs && d.millisecondsSinceEpoch < toMs) {
        cuts.add(d);
      }
    }
    cuts.add(to);
    for (var i = 0; i < cuts.length - 1; i++) {
      final a = cuts[i];
      final b = cuts[i + 1];
      final days = dayDiff(a, b);
      final r = rateAt(a);
      segs.add(AccrualSegment(toDateString(a), toDateString(b), days, r,
          principal, principal * (r / 100) * (days / 365)));
    }
    return segs;
  }

  double sumInterest(List<AccrualSegment> segs) =>
      segs.fold<double>(0, (t, x) => t + x.interest);

  final timeline = <TimelineRow>[];
  var outstandingPrincipal = 0.0;
  var accruedInterest = 0.0;
  var totalDisbursed = 0.0;
  var totalCharges = 0.0;
  var penaltyDue = 0.0;
  var totalPenalties = 0.0;
  var totalPenaltyPaid = 0.0;
  var totalInterestPaid = 0.0;
  var totalPrincipalPaid = 0.0;
  var cursorDate = startDate;

  for (final event in events) {
    final eventDate = parseDate(event.date);
    if (eventDate == null) continue;
    final days = dayDiff(cursorDate, eventDate);
    final segs = accrue(outstandingPrincipal, cursorDate, eventDate);
    final periodInterest = round2(sumInterest(segs));
    final rate = rateAt(eventDate);
    accruedInterest = round2(accruedInterest + periodInterest);

    double interestPaid = 0;
    double principalPaid = 0;

    if (event.type == 'DISBURSEMENT') {
      outstandingPrincipal = round2(outstandingPrincipal + event.amount);
      totalDisbursed = round2(totalDisbursed + event.amount);
      timeline.add(TimelineRow(
        date: event.date,
        eventType: event.type,
        amount: round2(event.amount),
        days: days,
        periodInterest: periodInterest,
        segments: segs,
        rate: rate,
        outstandingPrincipal: outstandingPrincipal,
        accruedInterest: accruedInterest,
        totalOutstanding: round2(outstandingPrincipal + accruedInterest + penaltyDue),
        transactionId: event.txId,
        transactionKind: event.txKind,
      ));
    } else if (event.type == 'CHARGE') {
      // Bank charge: capitalised into the outstanding principal.
      outstandingPrincipal = round2(outstandingPrincipal + event.amount);
      totalCharges = round2(totalCharges + event.amount);
      timeline.add(TimelineRow(
        date: event.date,
        eventType: 'CHARGE',
        amount: round2(event.amount),
        days: days,
        periodInterest: periodInterest,
        segments: segs,
        rate: rate,
        outstandingPrincipal: outstandingPrincipal,
        accruedInterest: accruedInterest,
        totalOutstanding: round2(outstandingPrincipal + accruedInterest + penaltyDue),
        note: (event.note == null || event.note!.isEmpty)
            ? 'Bank charge — added to principal'
            : '${event.note} — added to principal',
        transactionId: event.txId,
        transactionKind: event.txKind,
      ));
    } else if (event.type == 'RATE_CHANGE') {
      final rc = event.rc!;
      String yr(double v) => v == v.roundToDouble() ? '${v.toInt()}' : '$v';
      final emiTxt = rc.newEmi.round() != rc.oldEmi.round()
          ? 'EMI ₹${rc.oldEmi.round()} → ₹${rc.newEmi.round()}'
          : 'EMI ₹${rc.newEmi.round()} (unchanged)';
      final yrTxt = rc.newYears != rc.oldYears
          ? 'tenure ${yr(rc.oldYears)} → ${yr(rc.newYears)} yr'
          : 'tenure ${yr(rc.newYears)} yr (unchanged)';
      timeline.add(TimelineRow(
        date: event.date,
        eventType: 'RATE_CHANGE',
        amount: 0,
        days: days,
        periodInterest: periodInterest,
        segments: segs,
        rate: rc.newRate,
        outstandingPrincipal: outstandingPrincipal,
        accruedInterest: accruedInterest,
        totalOutstanding: round2(outstandingPrincipal + accruedInterest + penaltyDue),
        note: 'Rate ${rc.oldRate}% → ${rc.newRate}% effective ${rc.effectiveDate}. '
            'Interest up to this date used ${rc.oldRate}%; from this date ${rc.newRate}%. '
            '$emiTxt, $yrTxt '
            '(${rc.adjustmentType == 'KEEP_EMI' ? 'EMI kept' : 'tenure kept'}).',
        transactionId: event.txId,
        transactionKind: event.txKind,
      ));
    } else if (event.type == 'PENALTY') {
      final pn = event.pen!;
      if (!pn.disputed) {
        penaltyDue = round2(penaltyDue + pn.amount);
        totalPenalties = round2(totalPenalties + pn.amount);
      }
      final c = computePenalty(
        overdueAmount: pn.overdueAmount,
        ratePct: pn.ratePct,
        gstPct: pn.gstPct,
        delayStart: parseDate(pn.delayStart) ?? eventDate,
        delayEnd: parseDate(pn.delayEnd) ?? eventDate,
      );
      final working = '\u20b9${pn.overdueAmount.round()} \u00d7 ${pn.ratePct}% \u00d7 ${c.days}/365 '
          '= \u20b9${c.penalty.toStringAsFixed(2)}, + GST ${pn.gstPct}% '
          '\u20b9${c.gst.toStringAsFixed(2)} = \u20b9${c.total.toStringAsFixed(2)}';
      timeline.add(TimelineRow(
        date: event.date,
        eventType: 'PENALTY',
        amount: round2(pn.amount),
        days: days,
        periodInterest: periodInterest,
        segments: segs,
        rate: rate,
        outstandingPrincipal: outstandingPrincipal,
        accruedInterest: accruedInterest,
        totalOutstanding: round2(outstandingPrincipal + accruedInterest + penaltyDue),
        note: pn.disputed
            ? 'DISPUTED penal charge, no effect on balances. Delay ${pn.delayStart} to ${pn.delayEnd}: $working.'
            : 'Penal charge for delay ${pn.delayStart} to ${pn.delayEnd}: $working. '
                'Not capitalised: no interest is charged on it; the next EMI clears it after interest.',
        transactionId: event.txId,
        transactionKind: event.txKind,
      ));
    } else if (event.type == 'PREPAYMENT') {
      if (periodInterest > 0) {
        timeline.add(TimelineRow(
          date: event.date,
          eventType: 'ACCRUAL',
          amount: 0,
          days: days,
          periodInterest: periodInterest,
          segments: segs,
          rate: rate,
          outstandingPrincipal: outstandingPrincipal,
          accruedInterest: accruedInterest,
          totalOutstanding: round2(outstandingPrincipal + accruedInterest + penaltyDue),
          note:
              'Interest accrued up to prepayment date — will be collected in next EMI',
        ));
      }
      principalPaid = round2(_min(outstandingPrincipal, event.amount));
      outstandingPrincipal = round2(_max(0, outstandingPrincipal - principalPaid));
      totalPrincipalPaid = round2(totalPrincipalPaid + principalPaid);
      timeline.add(TimelineRow(
        date: event.date,
        eventType: 'PREPAYMENT',
        amount: round2(event.amount),
        days: 0,
        periodInterest: 0,
        rate: rate,
        principalPaid: principalPaid,
        outstandingPrincipal: outstandingPrincipal,
        accruedInterest: accruedInterest,
        totalOutstanding: round2(outstandingPrincipal + accruedInterest + penaltyDue),
        sourceMonth: event.sourceMonth,
        note:
            'Floating-rate prepayment — 100% principal reduction, no interest/penalty',
        transactionId: event.txId,
        transactionKind: event.txKind,
      ));
    } else {
      interestPaid = round2(_min(event.amount, accruedInterest));
      // Order of recovery: interest first, then any penal charge, then principal.
      final penaltyPaid =
          round2(_min(penaltyDue, _max(0, event.amount - interestPaid)));
      principalPaid = round2(_min(outstandingPrincipal,
          _max(0, event.amount - interestPaid - penaltyPaid)));
      penaltyDue = round2(_max(0, penaltyDue - penaltyPaid));
      totalPenaltyPaid = round2(totalPenaltyPaid + penaltyPaid);
      accruedInterest = round2(_max(0, accruedInterest - interestPaid));
      outstandingPrincipal = round2(_max(0, outstandingPrincipal - principalPaid));
      totalInterestPaid = round2(totalInterestPaid + interestPaid);
      totalPrincipalPaid = round2(totalPrincipalPaid + principalPaid);
      timeline.add(TimelineRow(
        date: event.date,
        eventType: event.type,
        amount: round2(event.amount),
        days: days,
        periodInterest: periodInterest,
        segments: segs,
        rate: rate,
        interestPaid: interestPaid,
        penaltyPaid: penaltyPaid,
        principalPaid: principalPaid,
        outstandingPrincipal: outstandingPrincipal,
        accruedInterest: accruedInterest,
        totalOutstanding: round2(outstandingPrincipal + accruedInterest + penaltyDue),
        sourceMonth: event.sourceMonth,
        transactionId: event.txId,
        transactionKind: event.txKind,
      ));
    }
    cursorDate = eventDate;
  }

  final until = untilDate ?? DateTime.now();
  final untilDateStr = toDateString(until);
  final untilParsed = parseDate(untilDateStr);
  if (untilParsed != null &&
      untilParsed.millisecondsSinceEpoch > cursorDate.millisecondsSinceEpoch) {
    final days = dayDiff(cursorDate, untilParsed);
    final segs = accrue(outstandingPrincipal, cursorDate, untilParsed);
    final periodInterest = round2(sumInterest(segs));
    final rate = rateAt(untilParsed);
    accruedInterest = round2(accruedInterest + periodInterest);
    timeline.add(TimelineRow(
      date: untilDateStr,
      eventType: 'ACCRUAL',
      amount: 0,
      days: days,
      periodInterest: periodInterest,
      segments: segs,
      rate: rate,
      outstandingPrincipal: outstandingPrincipal,
      accruedInterest: accruedInterest,
      totalOutstanding: round2(outstandingPrincipal + accruedInterest + penaltyDue),
    ));
  }

  final sanctionedAmount = loan.sanctionedAmount;
  final undisbursedAmount = round2(_max(0, sanctionedAmount - totalDisbursed));
  final asOfDate = timeline.isNotEmpty ? timeline.last.date : startDateStr;

  final totalPrepayments = loan.payments
      .where((p) => p.paymentType == 'PREPAYMENT')
      .fold<double>(0, (s, p) => s + p.amount);

  // ---- interest-saved simulation (identical to web app) --------------------
  // With rate history, the plan STARTED at the first change's old rate/EMI/tenure.
  final tenure =
      ((changes.isEmpty ? loan.years : changes.first.oldYears) * 12).toInt();
  final monthlyEmi =
      round2(changes.isEmpty ? loan.monthlyEmi : changes.first.oldEmi);
  final monthlyRate = initialRate / (12 * 100);
  final loanPrincipal = sanctionedAmount;

  final prepaymentsByMonth = <int, double>{};
  var emiCount = 0;
  final chargesByMonth = <int, double>{};
  // Payments and charges walked in date order so each lands in the right month.
  final rateEmiByMonth = <int, List<double>>{}; // month -> [monthlyRate, emi]
  final simEvents = <List<dynamic>>[]; // [date, kind, amount, seq]
  var sq = 0;
  for (final p in loan.payments) {
    simEvents.add([p.date, p.paymentType, p.amount, sq++]);
  }
  for (final c in loan.charges) {
    if (c.amount > 0) simEvents.add([c.date, 'CHARGE', c.amount, sq++]);
  }
  for (final c in changes) {
    simEvents.add([c.effectiveDate, 'RATE', 0.0, sq++, c]);
  }
  simEvents.sort((a, b) {
    final d = parseDate(a[0] as String)!.compareTo(parseDate(b[0] as String)!);
    return d != 0 ? d : (a[3] as int).compareTo(b[3] as int);
  });
  for (final e in simEvents) {
    if (e[1] == 'RATE') {
      final c = e[4] as RateChangeInput;
      rateEmiByMonth[emiCount + 1] = [c.newRate / (12 * 100), c.newEmi];
      continue;
    }
    final kind = e[1] as String;
    final amt = e[2] as double;
    if (kind == 'EMI_PAYMENT') {
      emiCount++;
    } else if (kind == 'PREPAYMENT') {
      final month = emiCount + 1;
      prepaymentsByMonth[month] = (prepaymentsByMonth[month] ?? 0) + amt;
    } else if (kind == 'CHARGE') {
      final month = emiCount + 1;
      chargesByMonth[month] = (chargesByMonth[month] ?? 0) + amt;
    }
  }

  final withoutPrepay = _simulateLoan(
      loanPrincipal, monthlyEmi, monthlyRate, tenure, {}, chargesByMonth,
      rateEmiByMonth);
  final originalTotalInterest = withoutPrepay.totalInterest;
  final withPrepay = _simulateLoan(loanPrincipal, monthlyEmi, monthlyRate,
      tenure, prepaymentsByMonth, chargesByMonth, rateEmiByMonth);
  final interestSaved =
      round2(_max(0, originalTotalInterest - withPrepay.totalInterest));
  final monthsSaved = withoutPrepay.months - withPrepay.months;

  return TimelineView(
    asOfDate: asOfDate,
    monthlyEmi: monthlyEmi,
    nextDueDate: getNextDueDate(loan.emiDay, asOfDate),
    sanctionedAmount: sanctionedAmount,
    totalDisbursed: totalDisbursed,
    undisbursedAmount: undisbursedAmount,
    totalInterestPaid: totalInterestPaid,
    totalPrincipalPaid: totalPrincipalPaid,
    outstandingPrincipal: outstandingPrincipal,
    accruedInterest: accruedInterest,
    totalOutstanding: round2(outstandingPrincipal + accruedInterest + penaltyDue),
    totalPrepayments: round2(totalPrepayments),
    totalCharges: totalCharges,
    totalPenalties: totalPenalties,
    penaltyDue: penaltyDue,
    totalPenaltyPaid: totalPenaltyPaid,
    interestSaved: interestSaved,
    originalTotalInterest: originalTotalInterest,
    monthsSaved: monthsSaved,
    timeline: timeline,
  );
}

class _SimResult {
  final double totalInterest;
  final int months;
  _SimResult(this.totalInterest, this.months);
}

_SimResult _simulateLoan(double principal, double emi, double rate,
    int maxMonths, Map<int, double> prepayments,
    [Map<int, double> charges = const {},
    Map<int, List<double>> rateEmi = const {}]) {
  var balance = principal;
  var curRate = rate;
  var curEmi = emi;
  var totalInterest = 0.0;
  var month = 1;
  while (balance > 0.01 && month <= maxMonths + 100) {
    final change = rateEmi[month];
    if (change != null) {
      curRate = change[0];
      curEmi = change[1];
    }
    final interest = balance * curRate;
    var principalPaid = curEmi - interest;
    final prepay = prepayments[month] ?? 0;
    var closing = balance - principalPaid - prepay + (charges[month] ?? 0);
    if (closing < 0) {
      principalPaid += closing;
      closing = 0;
    }
    totalInterest += interest;
    balance = closing;
    month++;
  }
  return _SimResult(round2(totalInterest), month - 1);
}

// ---- floating-rate change (port of PATCH /:loanId/rate) --------------------
class RateChangeException implements Exception {
  final String message;
  RateChangeException(this.message);
  @override
  String toString() => message;
}

class RateChangeResult {
  final double newRate;
  final double newYears;
  final double newMonthlyEmi;
  RateChangeResult(this.newRate, this.newYears, this.newMonthlyEmi);
}

/// Faithful port of the rate-update logic.
///   KEEP_TENURE: keep years, recompute EMI.
///   KEEP_EMI:    keep EMI, recompute tenure (years).
/// [outstandingPrincipal] MUST be computed from the CURRENT (old) rate via
/// buildTimeline before calling — exactly as the web backend did.
RateChangeResult applyRateChange({
  required double outstandingPrincipal,
  required double oldEmi,
  required double sanctionedAmount,
  required double currentYears,
  required double newRateInput,
  required String adjustmentType, // 'KEEP_EMI' | 'KEEP_TENURE'
}) {
  if (newRateInput <= 0 || newRateInput > 50) {
    throw RateChangeException('Invalid interest rate. Must be between 0 and 50%');
  }
  if (adjustmentType != 'KEEP_EMI' && adjustmentType != 'KEEP_TENURE') {
    throw RateChangeException('Invalid adjustmentType');
  }
  final newRate = round2(newRateInput * 100) / 100; // 2-decimal precision
  final monthlyRate = newRate / (12 * 100);

  if (adjustmentType == 'KEEP_EMI') {
    final currentEmi = oldEmi;
    if (currentEmi <= outstandingPrincipal * monthlyRate) {
      throw RateChangeException(
          'EMI is too low to cover interest at new rate. Please choose "Increase EMI".');
    }
    final newTenureMonths = (-math.log(
                1 - (outstandingPrincipal * monthlyRate) / currentEmi) /
            math.log(1 + monthlyRate))
        .ceil();
    final newYears = (newTenureMonths / 12 * 10).ceil() / 10; // 1-decimal
    return RateChangeResult(newRate, newYears.toDouble(), currentEmi);
  } else {
    final newEmi = round2(calculateEmi(sanctionedAmount, newRate, currentYears));
    return RateChangeResult(newRate, currentYears, newEmi);
  }
}


// ---- upcoming schedule (projection from the loan's CURRENT position) --------
class UpcomingRow {
  final int n;
  final String dueDate;
  final double openingBalance;
  final double interest; // openingBalance x rate / 12
  final double principal;
  final double emi;
  final double closingBalance;
  UpcomingRow(this.n, this.dueDate, this.openingBalance, this.interest,
      this.principal, this.emi, this.closingBalance);
}

/// Projects the remaining EMIs from today's outstanding principal at the
/// CURRENT rate and EMI: interest = balance x annualRate / 12 each month.
/// Returns empty if the EMI cannot even cover the interest.
List<UpcomingRow> projectUpcoming({
  required double outstanding,
  required double annualRate,
  required double emi,
  required String firstDueDate,
  int maxMonths = 600,
}) {
  final rows = <UpcomingRow>[];
  final r = annualRate / (12 * 100);
  var balance = outstanding;
  if (balance <= 0 || emi <= balance * r) return rows;
  final first = parseDate(firstDueDate)!;
  var n = 0;
  while (balance > 0.5 && n < maxMonths) {
    final interest = round2(balance * r);
    final pay = _min(emi, balance + interest);
    final principal = round2(pay - interest);
    final closing = round2(_max(0, balance - principal));
    final due = DateTime.utc(first.year, first.month + n, first.day);
    rows.add(UpcomingRow(
        n + 1, toDateString(due), balance, interest, principal, round2(pay), closing));
    balance = closing;
    n++;
  }
  return rows;
}
