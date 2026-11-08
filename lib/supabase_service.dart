import 'package:supabase_flutter/supabase_flutter.dart';

import 'config.dart';
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

  /// Accepts a real e-mail or an older-style username (mapped to a synthetic
  /// e-mail internally).
  static String identifierToEmail(String id) {
    final v = id.trim();
    return v.contains('@') ? v.toLowerCase() : usernameToEmail(v);
  }

  static Future<void> signIn(String identifier, String password) async {
    await _c.auth.signInWithPassword(
        email: identifierToEmail(identifier), password: password);
  }

  /// True when the signed-in account still uses a username-style address and
  /// has no real, verified e-mail yet.
  static bool get needsRealEmail =>
      (currentUser?.email ?? '').endsWith('@${AppConfig.authEmailDomain}');

  /// Step 1 of registration: creates the account and e-mails a 6-digit code.
  /// (Supabase e-mail template must contain {{ .Token }} — see README steps.)
  static Future<void> signUp(String email, String password,
      {String? displayName}) async {
    await _c.auth.signUp(
      email: email.trim().toLowerCase(),
      password: password,
      data: {
        if (displayName != null && displayName.trim().isNotEmpty)
          'display_name': displayName.trim(),
      },
    );
  }

  /// Name shown in the app: chosen display name, else the old username, else
  /// the part of the email before the @.
  static String get displayName {
    final u = currentUser;
    final meta = u?.userMetadata;
    final n = (meta?['display_name'] ?? meta?['username'])?.toString().trim();
    if (n != null && n.isNotEmpty) return n;
    final email = u?.email ?? '';
    return email.contains('@') ? email.split('@').first : email;
  }

  static Future<void> updateDisplayName(String name) async {
    await _c.auth.updateUser(UserAttributes(data: {'display_name': name.trim()}));
  }

  /// Step 2: confirm the code -> signed in.
  static Future<void> verifySignUpOtp(String email, String code) async {
    await _c.auth.verifyOTP(
        email: email.trim().toLowerCase(), token: code.trim(), type: OtpType.signup);
  }

  static Future<void> resendSignUpOtp(String email) async {
    await _c.auth.resend(type: OtpType.signup, email: email.trim().toLowerCase());
  }

  /// Forgot password: e-mails a 6-digit recovery code.
  static Future<void> sendResetOtp(String email) async {
    await _c.auth.resetPasswordForEmail(email.trim().toLowerCase());
  }

  /// Verifies the recovery code and sets the new password.
  static Future<void> resetPasswordWithOtp(
      String email, String code, String newPassword) async {
    await _c.auth.verifyOTP(
        email: email.trim().toLowerCase(), token: code.trim(), type: OtpType.recovery);
    await _c.auth.updateUser(UserAttributes(password: newPassword));
  }

  /// Signed-in change password: re-checks the current password first.
  static Future<void> changePassword(String current, String next) async {
    final email = currentUser?.email;
    if (email == null) throw const AuthException('Not signed in.');
    await _c.auth.signInWithPassword(email: email, password: current);
    await _c.auth.updateUser(UserAttributes(password: next));
  }

  /// Older username-style account -> attach the real e-mail (sends a code).
  static Future<void> startEmailLink(String email) async {
    await _c.auth.updateUser(UserAttributes(email: email.trim().toLowerCase()));
  }

  static Future<void> confirmEmailLink(String email, String code) async {
    await _c.auth.verifyOTP(
        email: email.trim().toLowerCase(),
        token: code.trim(),
        type: OtpType.emailChange);
  }

  static Future<void> signOut() => _c.auth.signOut();

  // ---- loans ---------------------------------------------------------------
  /// Tables added after the first release. Each is fetched on its own so a
  /// missing table (its SQL not run yet) never breaks the rest of the app.
  static const _optionalTables = ['charges', 'rate_changes', 'penalties'];

  static Future<void> _attachOptional(
      List<Map<String, dynamic>> loans, String? onlyLoanId) async {
    for (final t in _optionalTables) {
      List rows = const [];
      try {
        final q = _c.from(t).select();
        rows = await (onlyLoanId == null ? q : q.eq('loan_id', onlyLoanId));
      } on PostgrestException {
        rows = const []; // table not created yet
      }
      final byLoan = <String, List<dynamic>>{};
      for (final r in rows) {
        (byLoan[r['loan_id'].toString()] ??= []).add(r);
      }
      for (final l in loans) {
        l[t] = byLoan[l['id'].toString()] ?? [];
      }
    }
  }

  static Future<List<Loan>> fetchLoans() async {
    final rows = await _c
        .from('loans')
        .select('*, disbursements(*), payments(*)')
        .order('created_at', ascending: false);
    final loans = (rows as List).map((r) => Map<String, dynamic>.from(r)).toList();
    await _attachOptional(loans, null);
    return loans.map(Loan.fromJson).toList();
  }

  static Future<Loan> fetchLoan(String id) async {
    final row = await _c
        .from('loans')
        .select('*, disbursements(*), payments(*)')
        .eq('id', id)
        .single();
    final loan = Map<String, dynamic>.from(row);
    await _attachOptional([loan], id);
    return Loan.fromJson(loan);
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

  /// Records a floating-rate change that is effective from [effectiveDate].
  ///
  /// Interest before that date stays at the old rate; from that date on it
  /// accrues at the new rate (the timeline engine re-prices every period from
  /// the stored history, so the whole ledger updates). Outstanding principal is
  /// measured AS OF the effective date to recompute EMI / tenure.
  ///
  /// [previousRate] is only used for the FIRST change on a loan: the rate that
  /// applied before the effective date (defaults to the loan's current rate).
  static Future<RateChangeResult> updateRate({
    required Loan loan,
    required double newRate,
    required String effectiveDate,
    required String adjustmentType, // 'KEEP_EMI' | 'KEEP_TENURE'
    double? previousRate,
  }) async {
    if (effectiveDate.compareTo(loan.earliestDate) < 0) {
      throw RateChangeException(
          'Effective date cannot be before the loan start (${loan.earliestDate}).');
    }
    if (loan.rateChanges.isNotEmpty &&
        effectiveDate.compareTo(loan.rateChanges.last.effectiveDate) < 0) {
      throw RateChangeException(
          'Effective date must be on/after the last rate change '
          '(${loan.rateChanges.last.effectiveDate}). Delete that change first '
          'to back-date.');
    }
    final hasHistory = loan.rateChanges.isNotEmpty;
    final oldRate = hasHistory ? loan.rate : (previousRate ?? loan.rate);

    // Outstanding principal on the effective date, under the OLD rate.
    final asOfInput = loan
        .toEngineInput()
        .asOf(effectiveDate, rateOverride: hasHistory ? null : oldRate);
    final tl = buildTimeline(asOfInput, untilDate: parseDate(effectiveDate));
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
    try {
      await _c.from('rate_changes').insert({
        'loan_id': loan.id,
        'effective_date': effectiveDate,
        'old_rate': oldRate,
        'new_rate': result.newRate,
        'old_emi': loan.monthlyEmi,
        'new_emi': result.newMonthlyEmi,
        'old_years': loan.years,
        'new_years': result.newYears,
        'adjustment_type': adjustmentType,
      });
    } on PostgrestException catch (e) {
      if (e.message.contains('rate_changes')) {
        throw RateChangeException(
            'Rate history table missing. Run supabase/add_rate_history.sql in the Supabase SQL Editor first.');
      }
      rethrow;
    }
    await _c.from('loans').update({
      'rate': result.newRate,
      'years': result.newYears,
      'monthly_emi': result.newMonthlyEmi,
    }).eq('id', loan.id);
    return result;
  }

  /// Undo the LATEST rate change: restores the loan's rate / EMI / tenure.
  static Future<void> deleteLatestRateChange(Loan loan) async {
    final rc = loan.rateChanges.last;
    await _c.from('rate_changes').delete().eq('id', rc.id);
    await _c.from('loans').update({
      'rate': rc.oldRate,
      'years': rc.oldYears,
      'monthly_emi': rc.oldEmi,
    }).eq('id', loan.id);
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

  /// A bank charge/fee: capitalised into the outstanding principal.
  static Future<void> addCharge({
    required String loanId,
    required double amount,
    required String date,
    String description = '',
  }) async {
    await _c.from('charges').insert({
      'loan_id': loanId,
      'amount': round2(amount),
      'date': date,
      'description': description.trim(),
    });
  }

  /// Records a penal charge for a delayed EMI (see [PenaltyInput]).
  static Future<void> addPenalty({
    required String loanId,
    required String delayStart,
    required String delayEnd,
    required String leviedDate,
    required double overdueAmount,
    required double ratePct,
    required double gstPct,
    required double amount,
    required bool disputed,
    String note = '',
  }) async {
    try {
      await _c.from('penalties').insert({
        'loan_id': loanId,
        'delay_start': delayStart,
        'delay_end': delayEnd,
        'levied_date': leviedDate,
        'overdue_amount': overdueAmount,
        'rate': ratePct,
        'gst_rate': gstPct,
        'amount': amount,
        'disputed': disputed,
        'note': note.trim(),
      });
    } on PostgrestException catch (e) {
      if (e.message.contains('penalties')) {
        throw Exception(
            'Penalties table missing. Run supabase/add_penalties.sql in the Supabase SQL Editor first.');
      }
      rethrow;
    }
  }

  static Future<void> deletePenalty(String id) async {
    await _c.from('penalties').delete().eq('id', id);
  }

  static Future<void> deleteCharge(String id) async {
    await _c.from('charges').delete().eq('id', id);
  }

  static Future<void> deleteDisbursement(String id) async {
    await _c.from('disbursements').delete().eq('id', id);
  }

  static Future<void> deletePayment(String id) async {
    await _c.from('payments').delete().eq('id', id);
  }
}
