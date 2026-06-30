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
  });
}

// ---- output model ----------------------------------------------------------
class TimelineRow {
  final String date;
  final String eventType; // DISBURSEMENT | EMI_PAYMENT | PREPAYMENT | ACCRUAL
  final double amount;
  final int days;
  final double periodInterest;
  final double interestPaid;
  final double principalPaid;
  final double outstandingPrincipal;
  final double accruedInterest;
  final double totalOutstanding;
  final int? sourceMonth;
  final String? note;
  TimelineRow({
    required this.date,
    required this.eventType,
    required this.amount,
    required this.days,
    required this.periodInterest,
    this.interestPaid = 0,
    this.principalPaid = 0,
    required this.outstandingPrincipal,
    required this.accruedInterest,
    required this.totalOutstanding,
    this.sourceMonth,
    this.note,
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
    required this.interestSaved,
    required this.originalTotalInterest,
    required this.monthsSaved,
    required this.timeline,
  });
}

class _Event {
  final String type; // DISBURSEMENT | PREPAYMENT | EMI_PAYMENT
  final String date;
  final double amount;
  final int? sourceMonth;
  final int seq; // insertion order tiebreaker -> matches V8 stable sort
  _Event(this.type, this.date, this.amount, this.sourceMonth, this.seq);
}

double _min(double a, double b) => a < b ? a : b;
double _max(double a, double b) => a > b ? a : b;

/// Faithful port of buildTimeline(loan, untilDateInput).
TimelineView buildTimeline(LoanInput loan, {DateTime? untilDate}) {
  final startDateStr = loan.startDate;
  final startDate = parseDate(startDateStr)!;
  final annualRate = loan.rate / 100;

  var seq = 0;
  final events = <_Event>[];
  for (final d in loan.disbursements) {
    events.add(_Event('DISBURSEMENT', d.date, d.amount, null, seq++));
  }
  for (final p in loan.payments) {
    final type = p.paymentType == 'PREPAYMENT' ? 'PREPAYMENT' : 'EMI_PAYMENT';
    events.add(_Event(type, p.date, p.amount, p.sourceMonth, seq++));
  }

  events.removeWhere((e) => e.date.isEmpty || e.amount <= 0);
  events.sort((a, b) {
    if (a.date.compareTo(b.date) < 0) return -1;
    if (a.date.compareTo(b.date) > 0) return 1;
    if (a.type == b.type) return a.seq.compareTo(b.seq);
    return a.type == 'DISBURSEMENT' ? -1 : 1;
  });

  final timeline = <TimelineRow>[];
  var outstandingPrincipal = 0.0;
  var accruedInterest = 0.0;
  var totalDisbursed = 0.0;
  var totalInterestPaid = 0.0;
  var totalPrincipalPaid = 0.0;
  var cursorDate = startDate;

  for (final event in events) {
    final eventDate = parseDate(event.date);
    if (eventDate == null) continue;
    final days = dayDiff(cursorDate, eventDate);
    final periodInterest =
        round2(outstandingPrincipal * annualRate * (days / 365));
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
        outstandingPrincipal: outstandingPrincipal,
        accruedInterest: accruedInterest,
        totalOutstanding: round2(outstandingPrincipal + accruedInterest),
      ));
    } else if (event.type == 'PREPAYMENT') {
      if (periodInterest > 0) {
        timeline.add(TimelineRow(
          date: event.date,
          eventType: 'ACCRUAL',
          amount: 0,
          days: days,
          periodInterest: periodInterest,
          outstandingPrincipal: outstandingPrincipal,
          accruedInterest: accruedInterest,
          totalOutstanding: round2(outstandingPrincipal + accruedInterest),
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
        principalPaid: principalPaid,
        outstandingPrincipal: outstandingPrincipal,
        accruedInterest: accruedInterest,
        totalOutstanding: round2(outstandingPrincipal + accruedInterest),
        sourceMonth: event.sourceMonth,
        note:
            'Floating-rate prepayment — 100% principal reduction, no interest/penalty',
      ));
    } else {
      interestPaid = round2(_min(event.amount, accruedInterest));
      principalPaid = round2(
          _min(outstandingPrincipal, _max(0, event.amount - interestPaid)));
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
        interestPaid: interestPaid,
        principalPaid: principalPaid,
        outstandingPrincipal: outstandingPrincipal,
        accruedInterest: accruedInterest,
        totalOutstanding: round2(outstandingPrincipal + accruedInterest),
        sourceMonth: event.sourceMonth,
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
    final periodInterest =
        round2(outstandingPrincipal * annualRate * (days / 365));
    accruedInterest = round2(accruedInterest + periodInterest);
    timeline.add(TimelineRow(
      date: untilDateStr,
      eventType: 'ACCRUAL',
      amount: 0,
      days: days,
      periodInterest: periodInterest,
      outstandingPrincipal: outstandingPrincipal,
      accruedInterest: accruedInterest,
      totalOutstanding: round2(outstandingPrincipal + accruedInterest),
    ));
  }

  final sanctionedAmount = loan.sanctionedAmount;
  final undisbursedAmount = round2(_max(0, sanctionedAmount - totalDisbursed));
  final asOfDate = timeline.isNotEmpty ? timeline.last.date : startDateStr;

  final totalPrepayments = loan.payments
      .where((p) => p.paymentType == 'PREPAYMENT')
      .fold<double>(0, (s, p) => s + p.amount);

  // ---- interest-saved simulation (identical to web app) --------------------
  final tenure = (loan.years * 12).toInt();
  final monthlyEmi = round2(loan.monthlyEmi);
  final monthlyRate = loan.rate / (12 * 100);
  final loanPrincipal = sanctionedAmount;

  final prepaymentsByMonth = <int, double>{};
  var emiCount = 0;
  final allPayments = List<PaymentInput>.from(loan.payments)
    ..sort((a, b) =>
        parseDate(a.date)!.compareTo(parseDate(b.date)!));
  for (final p in allPayments) {
    if (p.paymentType == 'EMI_PAYMENT') {
      emiCount++;
    } else if (p.paymentType == 'PREPAYMENT') {
      final month = emiCount + 1;
      prepaymentsByMonth[month] = (prepaymentsByMonth[month] ?? 0) + p.amount;
    }
  }

  final withoutPrepay =
      _simulateLoan(loanPrincipal, monthlyEmi, monthlyRate, tenure, {});
  final originalTotalInterest = withoutPrepay.totalInterest;
  final withPrepay = _simulateLoan(
      loanPrincipal, monthlyEmi, monthlyRate, tenure, prepaymentsByMonth);
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
    totalOutstanding: round2(outstandingPrincipal + accruedInterest),
    totalPrepayments: round2(totalPrepayments),
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
    int maxMonths, Map<int, double> prepayments) {
  var balance = principal;
  var totalInterest = 0.0;
  var month = 1;
  while (balance > 0.01 && month <= maxMonths + 100) {
    final interest = balance * rate;
    var principalPaid = emi - interest;
    final prepay = prepayments[month] ?? 0;
    var closing = balance - principalPaid - prepay;
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
