import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'loan_engine.dart';
import 'utils.dart';

String _esc(Object? v) {
  final s = '$v';
  if (s.contains(',') || s.contains('"') || s.contains('\n')) {
    return '"${s.replaceAll('"', '""')}"';
  }
  return s;
}

/// Builds a CSV of the timeline and opens the share sheet (save / email / etc.).
Future<void> exportTimelineCsv(String loanName, TimelineView view) async {
  final rows = <String>[
    'Date,Event,Amount,Days,Interest,Principal,Outstanding,Total Owed',
  ];
  for (final r in view.timeline) {
    final interest =
        r.eventType == 'EMI_PAYMENT' ? r.interestPaid : r.periodInterest;
    rows.add([
      r.date,
      eventLabel(r.eventType),
      r.amount == 0 ? '' : r.amount.round(),
      r.days,
      interest.round(),
      r.principalPaid == 0 ? '' : r.principalPaid.round(),
      r.outstandingPrincipal.round(),
      r.totalOutstanding.round(),
    ].map(_esc).join(','));
  }
  // summary footer
  rows.add('');
  rows.add('Summary,,,,,,,');
  rows.add('Sanctioned,${view.sanctionedAmount.round()}');
  rows.add('Total Disbursed,${view.totalDisbursed.round()}');
  rows.add('Outstanding Principal,${view.outstandingPrincipal.round()}');
  rows.add('Accrued Interest,${view.accruedInterest.round()}');
  rows.add('Total Outstanding,${view.totalOutstanding.round()}');
  rows.add('Total Interest Paid,${view.totalInterestPaid.round()}');
  rows.add('Total Prepayments,${view.totalPrepayments.round()}');
  rows.add('Interest Saved,${view.interestSaved.round()}');
  rows.add('Months Saved,${view.monthsSaved}');

  final csv = rows.join('\n');
  final safe = loanName.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/${safe}_timeline.csv');
  await file.writeAsString(csv);

  await Share.shareXFiles(
    [XFile(file.path, mimeType: 'text/csv')],
    subject: '$loanName — loan timeline',
    text: 'Loan timeline export from Loan Manager',
  );
}
