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
}
