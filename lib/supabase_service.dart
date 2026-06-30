import 'package:supabase_flutter/supabase_flutter.dart';

import 'loan_engine.dart';
import 'models.dart';

/// All backend access. Replaces the old Node/Express API + JWT auth.
/// Supabase Auth handles sessions; RLS enforces per-user data isolation, so
/// every query below is automatically scoped to the logged-in user.
class SupabaseService {
  static SupabaseClient get _c => Supabase.instance.client;

  // ---- auth ----------------------------------------------------------------
  static Session? get session => _c.auth.currentSession;
  static User? get currentUser => _c.auth.currentUser;

  static Future<void> signIn(String email, String password) async {
    await _c.auth.signInWithPassword(email: email, password: password);
  }

  static Future<void> signUp(String email, String password) async {
    await _c.auth.signUp(email: email, password: password);
  }

  static Future<void> signOut() => _c.auth.signOut();

  // ---- loans ---------------------------------------------------------------
  static Future<List<Loan>> fetchLoans() async {
    final rows = await _c
        .from('loans')
        .select('*, disbursements(*), payments(*)')
        .order('created_at', ascending: false);
    return (rows as List)
        .map((r) => Loan.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  static Future<Loan> fetchLoan(String id) async {
    final row = await _c
        .from('loans')
        .select('*, disbursements(*), payments(*)')
        .eq('id', id)
        .single();
    return Loan.fromJson(row);
  }

  /// Mirrors POST /api/loans: computes monthlyEmi the same way (calculateEmi),
  /// then optionally records the first disbursement.
  static Future<String> createLoan({
    required String loanName,
    required double sanctionedAmount,
    required double rate,
    required double years,
    required String startDate,
    required int emiDay,
    double? firstDisbursementAmount,
    String? firstDisbursementDate,
  }) async {
    final monthlyEmi = round2(calculateEmi(sanctionedAmount, rate, years));
    final inserted = await _c
        .from('loans')
        .insert({
          'user_id': _c.auth.currentUser!.id,
          'loan_name': loanName,
          'sanctioned_amount': sanctionedAmount,
          'rate': rate,
          'years': years,
          'start_date': startDate,
          'emi_day': emiDay,
          'monthly_emi': monthlyEmi,
        })
        .select('id')
        .single();
    final loanId = inserted['id'].toString();

    final disb = firstDisbursementAmount ?? sanctionedAmount;
    if (disb > 0) {
      await addDisbursement(
        loanId: loanId,
        amount: disb,
        date: firstDisbursementDate ?? startDate,
      );
    }
    return loanId;
  }

  static Future<void> deleteLoan(String id) async {
    await _c.from('loans').delete().eq('id', id);
  }

  /// Mirrors PATCH /api/loans/:id/rate. Computes outstanding principal from the
  /// CURRENT (old) rate, then applies the new rate keeping EMI or tenure.
  static Future<RateChangeResult> updateRate({
    required Loan loan,
    required double newRate,
    required String adjustmentType, // 'KEEP_EMI' | 'KEEP_TENURE'
  }) async {
    final tl = loan.timeline(); // uses old rate
    final outstanding = tl.outstandingPrincipal != 0
        ? tl.outstandingPrincipal
        : loan.sanctionedAmount;
    final result = applyRateChange(
      outstandingPrincipal: outstanding,
      oldEmi: loan.monthlyEmi,
      sanctionedAmount: loan.sanctionedAmount,
      currentYears: loan.years,
      newRateInput: newRate,
      adjustmentType: adjustmentType,
    );
    await _c.from('loans').update({
      'rate': result.newRate,
      'years': result.newYears,
      'monthly_emi': result.newMonthlyEmi,
    }).eq('id', loan.id);
    return result;
  }

  // ---- transactions --------------------------------------------------------
  static Future<void> addDisbursement({
    required String loanId,
    required double amount,
    required String date,
  }) async {
    await _c.from('disbursements').insert({
      'loan_id': loanId,
      'amount': round2(amount),
      'date': date,
    });
  }

  static Future<void> addEmiPayment({
    required String loanId,
    required double amount,
    required String date,
  }) async {
    await _c.from('payments').insert({
      'loan_id': loanId,
      'amount': round2(amount),
      'date': date,
      'payment_type': 'EMI_PAYMENT',
    });
  }

  static Future<void> addPrepayment({
    required String loanId,
    required double amount,
    required String date,
  }) async {
    await _c.from('payments').insert({
      'loan_id': loanId,
      'amount': round2(amount),
      'date': date,
      'payment_type': 'PREPAYMENT',
    });
  }

  static Future<void> deleteDisbursement(String id) async {
    await _c.from('disbursements').delete().eq('id', id);
  }

  static Future<void> deletePayment(String id) async {
    await _c.from('payments').delete().eq('id', id);
  }
}
