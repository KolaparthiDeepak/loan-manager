import 'package:intl/intl.dart';

final _inr = NumberFormat.decimalPattern('en_IN');

/// ₹ with Indian digit grouping, whole rupees (matches the app's round2 money).
String inr(num v) => '₹${_inr.format(v.round())}';

/// Short label for an event type used in the timeline.
String eventLabel(String type) {
  switch (type) {
    case 'DISBURSEMENT':
      return 'Disbursement';
    case 'EMI_PAYMENT':
      return 'EMI Payment';
    case 'PREPAYMENT':
      return 'Prepayment';
    case 'ACCRUAL':
      return 'Interest Accrual';
    default:
      return type;
  }
}
