import 'package:flutter/foundation.dart';

import 'loan_engine.dart';
import 'models.dart';
import 'supabase_service.dart';

/// One loan with everything the dashboard needs, computed once per refresh.
class LoanSnap {
  final Loan loan;
  final TimelineView view;
  final List<UpcomingRow> upcoming;
  LoanSnap(this.loan, this.view, this.upcoming);

  bool get closed => view.totalDisbursed > 0 && view.totalOutstanding <= 0.5;
  bool get active => !closed;

  double get repaidFraction => view.totalDisbursed <= 0
      ? 0
      : (view.totalPrincipalPaid / view.totalDisbursed).clamp(0.0, 1.0);

  DateTime? get nextDue => active ? parseDate(view.nextDueDate) : null;

  /// Whole days from today until the next EMI (negative = overdue).
  int? get daysToDue {
    final d = nextDue;
    if (d == null) return null;
    final n = DateTime.now();
    return dayDiff(DateTime.utc(n.year, n.month, n.day), d);
  }

  /// Date of the final projected EMI.
  DateTime? get lastDue =>
      upcoming.isEmpty ? null : parseDate(upcoming.last.dueDate);
}

/// What a lump-sum prepayment would save on one loan.
class PrepayTip {
  final LoanSnap snap;
  final double amount;
  final double interestSaved;
  final int monthsSaved;
  PrepayTip(this.snap, this.amount, this.interestSaved, this.monthsSaved);
}

class LoanStore extends ChangeNotifier {
  List<LoanSnap> snaps = const [];
  bool loading = true;
  String? error;

  Future<void> refresh() async {
    if (snaps.isEmpty) {
      loading = true;
      notifyListeners();
    }
    try {
      final loans = await SupabaseService.fetchLoans();
      snaps = loans.map(_snap).toList();
      error = null;
    } catch (e) {
      error = e.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  LoanSnap _snap(Loan l) {
    final v = l.timeline();
    final up = projectUpcoming(
      outstanding: v.outstandingPrincipal,
      annualRate: l.rate,
      emi: l.monthlyEmi,
      firstDueDate: v.nextDueDate ?? v.asOfDate,
    );
    return LoanSnap(l, v, up);
  }

  List<LoanSnap> get active => snaps.where((s) => s.active).toList();
  List<LoanSnap> get closed => snaps.where((s) => s.closed).toList();

  double _sum(double Function(TimelineView) f) =>
      snaps.fold(0.0, (a, s) => a + f(s.view));

  double get totalBorrowed => _sum((v) => v.totalDisbursed);
  double get totalOutstanding => _sum((v) => v.totalOutstanding);
  double get totalPrincipalPaid => _sum((v) => v.totalPrincipalPaid);
  double get totalInterestPaid => _sum((v) => v.totalInterestPaid);
  double get totalCharges => _sum((v) => v.totalCharges);
  double get totalPenalties => _sum((v) => v.totalPenalties);
  double get totalMonthlyEmi =>
      active.fold(0.0, (a, s) => a + s.view.monthlyEmi);
  double get interestSaved => _sum((v) => v.interestSaved);
  double get paidTillDate =>
      totalPrincipalPaid + totalInterestPaid + _sum((v) => v.totalPenaltyPaid);

  double get repaidFraction =>
      totalBorrowed <= 0 ? 0 : (totalPrincipalPaid / totalBorrowed).clamp(0.0, 1.0);

  /// Share of everything paid so far that went to interest.
  double get interestShare =>
      paidTillDate <= 0 ? 0 : (totalInterestPaid / paidTillDate).clamp(0.0, 1.0);

  /// Active loans ordered by the soonest EMI.
  List<LoanSnap> get upcomingDue {
    final a = active.where((s) => s.nextDue != null).toList()
      ..sort((x, y) => x.nextDue!.compareTo(y.nextDue!));
    return a;
  }

  /// When every active loan is projected to be cleared.
  DateTime? get debtFreeDate {
    DateTime? d;
    for (final s in active) {
      final x = s.lastDue;
      if (x != null && (d == null || x.isAfter(d))) d = x;
    }
    return d;
  }

  /// Prepaying on the costliest active loan is the best use of spare cash.
  PrepayTip? get prepayTip {
    final a = active.where((s) => s.view.outstandingPrincipal > 50000).toList()
      ..sort((x, y) => y.loan.rate.compareTo(x.loan.rate));
    if (a.isEmpty) return null;
    final s = a.first;
    final extra = s.view.outstandingPrincipal >= 300000 ? 100000.0 : 25000.0;
    final n = DateTime.now();
    final today =
        '${n.year.toString().padLeft(4, '0')}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
    final base = s.loan.toEngineInput();
    final payments = List<PaymentInput>.from(base.payments)
      ..add(PaymentInput(
          id: 'tip', amount: extra, date: today, paymentType: 'PREPAYMENT'));
    final projected = buildTimeline(base.copyWith(payments: payments));
    final saved = projected.interestSaved - s.view.interestSaved;
    if (saved <= 0) return null;
    return PrepayTip(s, extra, saved, projected.monthsSaved - s.view.monthsSaved);
  }
}
