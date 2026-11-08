import 'package:flutter_test/flutter_test.dart';
import 'package:loan_emi_mobile/loan_engine.dart';

// Verifies the Dart port reproduces the EXACT numbers from the web app's JS
// engine for the real "Home Loan", evaluated as of 2026-06-30.
void main() {
  test('buildTimeline matches golden numbers (Home Loan @ 2026-06-30)', () {
    final loan = LoanInput(
      loanName: 'Home Loan',
      sanctionedAmount: 9000000,
      rate: 7.3,
      years: 15,
      startDate: '2026-04-11',
      emiDay: 5,
      monthlyEmi: 82411.53,
      disbursements: [
        DisbursementInput(id: '1', amount: 7548677, date: '2026-03-20'),
        DisbursementInput(id: '2', amount: 754295, date: '2026-05-15'),
      ],
      payments: [
        PaymentInput(id: '3', amount: 82411.53, date: '2026-04-05', paymentType: 'EMI_PAYMENT'),
        PaymentInput(id: '4', amount: 1562, date: '2026-04-05', paymentType: 'PREPAYMENT'),
        PaymentInput(id: '5', amount: 100000, date: '2026-04-09', paymentType: 'PREPAYMENT'),
        PaymentInput(id: '6', amount: 18000, date: '2026-04-13', paymentType: 'PREPAYMENT'),
        PaymentInput(id: '7', amount: 5000, date: '2026-04-15', paymentType: 'PREPAYMENT'),
        PaymentInput(id: '8', amount: 82412, date: '2026-05-05', paymentType: 'EMI_PAYMENT'),
        PaymentInput(id: '9', amount: 587, date: '2026-05-05', paymentType: 'PREPAYMENT'),
        PaymentInput(id: '10', amount: 16000, date: '2026-06-03', paymentType: 'PREPAYMENT'),
        PaymentInput(id: '11', amount: 82412, date: '2026-06-05', paymentType: 'EMI_PAYMENT'),
        PaymentInput(id: '12', amount: 587, date: '2026-06-05', paymentType: 'PREPAYMENT'),
      ],
    );

    final v = buildTimeline(loan, untilDate: DateTime.utc(2026, 6, 30));

    expect(v.totalDisbursed, 8302972);
    expect(v.undisbursedAmount, 697028);
    expect(v.outstandingPrincipal, 8031059);
    expect(v.accruedInterest, 40155);
    expect(v.totalOutstanding, 8071214);
    expect(v.totalInterestPaid, 117059);
    expect(v.totalPrincipalPaid, 271913);
    expect(v.totalPrepayments, 141736);
    expect(v.interestSaved, 270087);
    expect(v.originalTotalInterest, 5834006);
    expect(v.monthsSaved, 4);
    expect(v.monthlyEmi, 82412); // round2(82411.53)
    expect(v.nextDueDate, '2026-07-05');
  });

  // Golden values from the web app's rate formulas (outstanding 8031059,
  // oldEmi 82412, sanctioned 9000000, years 15).
  group('applyRateChange parity', () {
    RateChangeResult run(double rate, String mode) => applyRateChange(
          outstandingPrincipal: 8031059,
          oldEmi: 82412,
          sanctionedAmount: 9000000,
          currentYears: 15,
          newRateInput: rate,
          adjustmentType: mode,
        );

    test('rate 8% KEEP_TENURE -> EMI 86009', () {
      final r = run(8.0, 'KEEP_TENURE');
      expect(r.newRate, 8.0);
      expect(r.newYears, 15);
      expect(r.newMonthlyEmi, 86009);
    });
    test('rate 8% KEEP_EMI -> 13.2 yr', () {
      final r = run(8.0, 'KEEP_EMI');
      expect(r.newMonthlyEmi, 82412);
      expect(r.newYears, 13.2);
    });
    test('rate 6.5% KEEP_TENURE -> EMI 78400', () {
      expect(run(6.5, 'KEEP_TENURE').newMonthlyEmi, 78400);
    });
    test('rate 6.5% KEEP_EMI -> 11.6 yr', () {
      expect(run(6.5, 'KEEP_EMI').newYears, 11.6);
    });
  });

  // getEmiSchedule with the CURRENT engine (round2 = whole rupees).
  test('getEmiSchedule parity (9000000 @ 7.3% / 15 yr)', () {
    final s = getEmiSchedule(9000000, 7.3, 15);
    expect(s.length, 180);
    expect(s.first.emi, 82412);
    expect(s.first.principal, 27662);
    expect(s.first.interest, 54750);
    expect(s.first.balance, 8972338);
    expect(s.last.balance, 0);
    expect(s.last.interest, 497);
  });

  group('bank charges', () {
    LoanInput mk(List<ChargeInput> charges) => LoanInput(
          loanName: 't',
          sanctionedAmount: 1000000,
          rate: 12,
          years: 10,
          startDate: '2025-01-01',
          emiDay: 5,
          monthlyEmi: 14347,
          disbursements: [
            DisbursementInput(id: 'd1', amount: 1000000, date: '2025-01-01')
          ],
          payments: [],
          charges: charges,
        );

    test('charge is added to outstanding principal and accrues interest', () {
      final base = buildTimeline(mk([]), untilDate: DateTime.utc(2025, 1, 31));
      final v = buildTimeline(
          mk([ChargeInput(id: 'c1', amount: 5000, date: '2025-01-11', description: 'Fee')]),
          untilDate: DateTime.utc(2025, 1, 31));
      expect(v.totalCharges, 5000);
      expect(v.outstandingPrincipal, 1005000);
      expect(v.timeline.any((r) => r.eventType == 'CHARGE'), isTrue);
      // 20 extra days of interest on 5000 @12%
      expect(v.accruedInterest - base.accruedInterest, closeTo(33, 1));
    });

    test('no charges leaves results unchanged', () {
      final v = buildTimeline(mk([]), untilDate: DateTime.utc(2025, 1, 31));
      expect(v.totalCharges, 0);
      expect(v.outstandingPrincipal, 1000000);
    });
  });

  group('rate change with effective date', () {
    LoanInput mk(List<RateChangeInput> rcs) => LoanInput(
          loanName: 't',
          sanctionedAmount: 1000000,
          rate: rcs.isEmpty ? 12 : 10,
          years: 10,
          startDate: '2025-01-01',
          emiDay: 5,
          monthlyEmi: 14347,
          disbursements: [
            DisbursementInput(id: 'd1', amount: 1000000, date: '2025-01-01')
          ],
          payments: [],
          rateChanges: rcs,
        );
    final rc = RateChangeInput(
        id: 'r1',
        effectiveDate: '2025-01-11',
        oldRate: 12,
        newRate: 10,
        oldEmi: 14347,
        newEmi: 13215,
        oldYears: 10,
        newYears: 10,
        adjustmentType: 'KEEP_TENURE');

    test('interest is split: old rate before the date, new rate from it', () {
      final v = buildTimeline(mk([rc]), untilDate: DateTime.utc(2025, 1, 31));
      // 10 days @12% = 3287.67 ; 20 days @10% = 5479.45 ; total 8767.12
      expect(v.accruedInterest, 8767);
      final last = v.timeline.last;
      expect(last.segments.length, 1); // only the post-change slice
      expect(last.segments.first.rate, 10);
      expect(last.segments.first.days, 20);
      final marker = v.timeline.firstWhere((r) => r.eventType == 'RATE_CHANGE');
      expect(marker.days, 10);
      expect(marker.periodInterest, 3288);
      expect(marker.segments.single.rate, 12);
    });

    test('each period is priced at the rate in force', () {
      final v = buildTimeline(mk([rc]), untilDate: DateTime.utc(2025, 1, 31));
      expect(v.accruedInterest, isNot(9863)); // flat 12% would be 9863
      final pay = mk([rc]).copyWith(payments: [
        PaymentInput(
            id: 'p', amount: 14347, date: '2025-01-20', paymentType: 'EMI_PAYMENT')
      ]);
      final v2 = buildTimeline(pay, untilDate: DateTime.utc(2025, 1, 20));
      final emiRow = v2.timeline.firstWhere((r) => r.eventType == 'EMI_PAYMENT');
      // RATE_CHANGE row already booked 10 days; EMI row covers Jan 11->20 @10%
      expect(emiRow.segments.single.rate, 10);
      expect(emiRow.segments.single.days, 9);
    });

    test('asOf drops later events', () {
      final in2 = mk([rc]).asOf('2025-01-05');
      expect(in2.rateChanges, isEmpty);
    });

    test('projectUpcoming amortises to zero at the given rate', () {
      final rows = projectUpcoming(
          outstanding: 1000000,
          annualRate: 12,
          emi: 14347,
          firstDueDate: '2025-02-05');
      expect(rows.first.interest, 10000);
      expect(rows.first.dueDate, '2025-02-05');
      expect(rows.last.closingBalance, 0);
      expect(rows.length, inInclusiveRange(119, 121));
    });
  });

  group('penal charge for a delayed EMI', () {
    test('Union Bank case: 2% p.a. + 18% GST on a 2-day delay of Rs 82,412', () {
      final c = computePenalty(
        overdueAmount: 82412,
        ratePct: 2,
        gstPct: 18,
        delayStart: DateTime.utc(2026, 7, 5),
        delayEnd: DateTime.utc(2026, 7, 7),
      );
      expect(c.days, 2);
      expect(c.penalty, 9.03);
      expect(c.gst, 1.63);
      expect(c.total, 10.66);
      expect(c.booked, 11);
    });

    LoanInput mk(List<PenaltyInput> pens, {double emi = 14347, bool withEmi = true}) => LoanInput(
          loanName: 't',
          sanctionedAmount: 1000000,
          rate: 12,
          years: 10,
          startDate: '2025-01-01',
          emiDay: 5,
          monthlyEmi: 14347,
          disbursements: [
            DisbursementInput(id: 'd1', amount: 1000000, date: '2025-01-01')
          ],
          payments: withEmi
              ? [
                  PaymentInput(
                      id: 'p1',
                      amount: emi,
                      date: '2025-02-05',
                      paymentType: 'EMI_PAYMENT')
                ]
              : [],
          penalties: pens,
        );
    PenaltyInput pen({bool disputed = false}) => PenaltyInput(
        id: 'x',
        delayStart: '2025-01-30',
        delayEnd: '2025-02-01',
        leviedDate: '2025-02-01',
        overdueAmount: 14347,
        ratePct: 2,
        gstPct: 18,
        amount: 11,
        disputed: disputed);

    test('is not capitalised: principal is untouched, total owed includes it', () {
      final v = buildTimeline(mk([pen()], withEmi: false),
          untilDate: DateTime.utc(2025, 2, 1));
      expect(v.totalPenalties, 11);
      expect(v.penaltyDue, 11);
      expect(v.outstandingPrincipal, 1000000);
      expect(v.totalOutstanding,
          v.outstandingPrincipal + v.accruedInterest + 11);
    });

    test('the next EMI clears interest, then the penalty, then principal', () {
      final base = buildTimeline(mk([]), untilDate: DateTime.utc(2025, 2, 5));
      final v = buildTimeline(mk([pen()]), untilDate: DateTime.utc(2025, 2, 5));
      final emi = v.timeline.firstWhere((r) => r.eventType == 'EMI_PAYMENT');
      final emi0 = base.timeline.firstWhere((r) => r.eventType == 'EMI_PAYMENT');
      expect(emi.penaltyPaid, 11);
      expect(emi.interestPaid, emi0.interestPaid);
      expect(emi.principalPaid, emi0.principalPaid - 11);
      expect(v.penaltyDue, 0);
      expect(v.totalPenaltyPaid, 11);
    });

    test('a disputed penalty is listed but changes nothing', () {
      final base = buildTimeline(mk([]), untilDate: DateTime.utc(2025, 2, 5));
      final v = buildTimeline(mk([pen(disputed: true)]),
          untilDate: DateTime.utc(2025, 2, 5));
      expect(v.timeline.any((r) => r.eventType == 'PENALTY'), isTrue);
      expect(v.totalPenalties, 0);
      expect(v.penaltyDue, 0);
      expect(v.outstandingPrincipal, base.outstandingPrincipal);
    });
  });
}
