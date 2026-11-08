import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../loan_engine.dart';
import '../models.dart';
import '../supabase_service.dart';
import '../utils.dart';
import '../export_csv.dart';
import '../widgets/balance_chart.dart';
import '../widgets/glass.dart';
import '../widgets/premium.dart';
import '../theme_controller.dart';
import 'schedule_screen.dart';
import 'whatif_screen.dart';

class LoanTimelineScreen extends StatefulWidget {
  final String loanId;
  const LoanTimelineScreen({super.key, required this.loanId});

  @override
  State<LoanTimelineScreen> createState() => _LoanTimelineScreenState();
}

class _LoanTimelineScreenState extends State<LoanTimelineScreen> {
  Loan? _loan;
  TimelineView? _view;
  bool _loading = true;
  String? _error;
  final _tick = ValueNotifier<int>(0);

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() => _loading = true);
    try {
      final loan = await SupabaseService.fetchLoan(widget.loanId);
      setState(() {
        _loan = loan;
        _view = loan.timeline();
        _loading = false;
      });
      _tick.value++;
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _addTransaction(String kind) async {
    final result = await showGlassSheet<_TxInput>(
      context,
      builder: (_) => _AddTransactionSheet(kind: kind),
    );
    if (result == null) return;
    try {
      switch (kind) {
        case 'disbursement':
          await SupabaseService.addDisbursement(
              loanId: widget.loanId, amount: result.amount, date: result.date);
          break;
        case 'emi':
          await SupabaseService.addEmiPayment(
              loanId: widget.loanId, amount: result.amount, date: result.date);
          break;
        case 'prepayment':
          await SupabaseService.addPrepayment(
              loanId: widget.loanId, amount: result.amount, date: result.date);
          break;
        case 'charge':
          await SupabaseService.addCharge(
              loanId: widget.loanId,
              amount: result.amount,
              date: result.date,
              description: result.description);
          break;
      }
      await _fetch();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    }
  }

  Future<void> _addPenalty() async {
    final loan = _loan!;
    final res = await showGlassSheet<_PenaltyResult>(
      context,
      builder: (_) => _PenaltySheet(
        defaultAmount: loan.monthlyEmi,
        minDate: loan.earliestDate,
      ),
    );
    if (res == null) return;
    try {
      await SupabaseService.addPenalty(
        loanId: widget.loanId,
        delayStart: res.delayStart,
        delayEnd: res.delayEnd,
        leviedDate: res.leviedDate,
        overdueAmount: res.overdue,
        ratePct: res.ratePct,
        gstPct: res.gstPct,
        amount: res.booked,
        disputed: res.disputed,
        note: res.note,
      );
      await _fetch();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(res.disputed
                ? 'Penalty recorded as disputed; balances unchanged.'
                : 'Penal charge of ${inr(res.booked)} booked on ${res.leviedDate}. Ledger updated.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _changeRate() async {
    final loan = _loan!;
    final result = await showDialog<_RateChoice>(
      context: context,
      builder: (_) => _RateChangeDialog(
        currentRate: loan.rate,
        hasHistory: loan.rateChanges.isNotEmpty,
        minDate: loan.rateChanges.isNotEmpty
            ? loan.rateChanges.last.effectiveDate
            : loan.earliestDate,
      ),
    );
    if (result == null) return;
    try {
      final r = await SupabaseService.updateRate(
        loan: loan,
        newRate: result.newRate,
        effectiveDate: result.date,
        adjustmentType: result.adjustmentType,
        previousRate: result.previousRate,
      );
      await _fetch();
      if (mounted) {
        final what = result.adjustmentType == 'KEEP_EMI'
            ? 'EMI kept, tenure → ${r.newYears} yr'
            : 'Tenure kept, EMI → ${inr(r.newMonthlyEmi)}';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                'Rate ${r.newRate}% effective ${result.date}. $what. Ledger re-priced.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _deleteRow(TimelineRow row) async {
    final isRate = row.transactionKind == 'rate_change';
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(isRate ? 'Undo rate change?' : 'Delete transaction?'),
        content: Text(isRate
            ? 'Removes the rate change effective ${row.date} and restores the previous rate, EMI and tenure. All interest is re-priced.'
            : '${eventLabel(row.eventType)} of ${inr(row.amount)} on ${row.date}'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      if (row.transactionKind == 'disbursement') {
        await SupabaseService.deleteDisbursement(row.transactionId!);
      } else if (row.transactionKind == 'charge') {
        await SupabaseService.deleteCharge(row.transactionId!);
      } else if (isRate) {
        await SupabaseService.deleteLatestRateChange(_loan!);
      } else if (row.transactionKind == 'penalty') {
        await SupabaseService.deletePenalty(row.transactionId!);
      } else {
        await SupabaseService.deletePayment(row.transactionId!);
      }
      await _fetch();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    }
  }

  Future<void> _confirmDeleteLoan() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete loan?'),
        content: const Text('This removes the loan and all its transactions.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (ok == true) {
      await SupabaseService.deleteLoan(widget.loanId);
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _tick.dispose();
    super.dispose();
  }

  // ---- layout ---------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final ready = !_loading && _error == null && _loan != null && _view != null;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: (Palette.isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark)
          .copyWith(statusBarColor: Colors.transparent),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        floatingActionButton: ready
            ? FloatingActionButton.extended(
                onPressed: _openAddSheet,
                backgroundColor: Palette.indigo,
                foregroundColor: Colors.white,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add',
                    style: TextStyle(fontWeight: FontWeight.w800)),
              )
            : null,
        body: GlassBackground(
          child: SafeArea(
            bottom: false,
            child: _loading && _loan == null
                ? const Center(child: CircularProgressIndicator())
                : _error != null && _loan == null
                    ? Center(
                        child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(_error!, textAlign: TextAlign.center)))
                    : DefaultTabController(
                        length: 3,
                        child: Column(
                          children: [
                            _topBar(),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                              child: _heroCompact(_view!),
                            ),
                            _tabBar(),
                            Expanded(
                              child: TabBarView(
                                children: [
                                  _overviewTab(),
                                  _activityTab(),
                                  _ratesTab(),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
          ),
        ),
      ),
    );
  }

  Widget _topBar() {
    final loan = _loan!;
    final years = loan.years;
    final yrs = years.toStringAsFixed(years == years.roundToDouble() ? 0 : 1);
    final closed = _view!.totalDisbursed > 0 && _view!.totalOutstanding <= 0.5;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 6, 4, 6),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
            onPressed: () => Navigator.maybePop(context),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(loan.loanName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 21, fontWeight: FontWeight.w900, letterSpacing: -0.4)),
                Row(
                  children: [
                    Flexible(
                      child: Text('${loan.rate}% p.a. • $yrs yr',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12.5, color: Palette.inkSoft)),
                    ),
                    const SizedBox(width: 8),
                    closed
                        ? StatusChip('Closed', color: Palette.inkSoft)
                        : const StatusChip('Active', color: Palette.green),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.calendar_month_rounded),
            tooltip: 'EMI schedule',
            onPressed: _openSchedule,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded),
            onSelected: (v) {
              switch (v) {
                case 'rate':
                  _changeRate();
                  break;
                case 'whatif':
                  _openWhatIf();
                  break;
                case 'csv':
                  exportTimelineCsv(_loan!.loanName, _view!);
                  break;
                case 'delete':
                  _confirmDeleteLoan();
                  break;
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                  value: 'rate',
                  child: ListTile(
                      leading: Icon(Icons.percent_rounded),
                      title: Text('Change interest rate'))),
              PopupMenuItem(
                  value: 'whatif',
                  child: ListTile(
                      leading: Icon(Icons.insights_rounded),
                      title: Text('Prepayment what-if'))),
              PopupMenuItem(
                  value: 'csv',
                  child: ListTile(
                      leading: Icon(Icons.ios_share_rounded),
                      title: Text('Export CSV'))),
              PopupMenuItem(
                  value: 'delete',
                  child: ListTile(
                      leading: Icon(Icons.delete_outline_rounded),
                      title: Text('Delete loan'))),
            ],
          ),
        ],
      ),
    );
  }

  void _openSchedule() => Navigator.push(
      context, MaterialPageRoute(builder: (_) => ScheduleScreen(loan: _loan!)));

  void _openWhatIf() => Navigator.push(
      context, MaterialPageRoute(builder: (_) => WhatIfScreen(loan: _loan!)));

  Widget _heroStat(String label, String value, {Color? color}) => Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(color: Colors.white70, fontSize: 11.5)),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(value,
                  style: TextStyle(
                      color: color ?? Colors.white,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      );

  Widget _heroCompact(TimelineView v) {
    final repaid = v.totalDisbursed <= 0
        ? 0.0
        : (v.totalPrincipalPaid / v.totalDisbursed).clamp(0.0, 1.0);
    String due = '-';
    final d = parseDate(v.nextDueDate);
    if (d != null) due = DateFormat('d MMM').format(d);
    return HeroCard(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Outstanding',
                        style: TextStyle(color: Colors.white70, fontSize: 12.5)),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(hideAmt(inr(v.totalOutstanding)),
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 31,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.8)),
                    ),
                  ],
                ),
              ),
              RingProgress(
                value: repaid,
                size: 62,
                stroke: 7,
                label: '${(repaid * 100).toStringAsFixed(0)}%',
                labelStyle: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _heroStat('EMI', hideAmt(inr(v.monthlyEmi))),
              _heroStat('Next due', due),
              _heroStat('Interest due', hideAmt(inr(v.accruedInterest))),
              if (v.penaltyDue > 0)
                _heroStat('Penalty', inr(v.penaltyDue), color: const Color(0xFFFFB4C0)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _tabBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Container(
        height: 46,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Palette.glass(Palette.isDark ? 0.5 : 0.55),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Palette.glass(0.9)),
        ),
        child: TabBar(
          dividerColor: Colors.transparent,
          indicatorSize: TabBarIndicatorSize.tab,
          indicator: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: const LinearGradient(colors: [Palette.blue, Palette.violet]),
          ),
          labelColor: Colors.white,
          unselectedLabelColor: Palette.inkSoft,
          labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
          unselectedLabelStyle:
              const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
          overlayColor: WidgetStateProperty.all(Colors.transparent),
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Activity'),
            Tab(text: 'Rates & fees'),
          ],
        ),
      ),
    );
  }

  // ---- Overview -------------------------------------------------------------
  Widget _overviewTab() {
    final v = _view!;
    return RefreshIndicator(
      onRefresh: _fetch,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 110),
        children: [
          _nextEmiCard(v),
          if (v.interestSaved > 0) ...[
            const SizedBox(height: 12),
            _savingsCards(v),
          ],
          const SectionHeader('Loan snapshot'),
          _statsGrid(v),
          const SizedBox(height: 14),
          BalanceChart(view: v),
        ],
      ),
    );
  }

  Widget _nextEmiCard(TimelineView v) {
    final loan = _loan!;
    final up = projectUpcoming(
      outstanding: v.outstandingPrincipal,
      annualRate: loan.rate,
      emi: loan.monthlyEmi,
      firstDueDate: v.nextDueDate ?? v.asOfDate,
    );
    if (v.nextDueDate == null || up.isEmpty) return const SizedBox.shrink();
    final r = up.first;
    final d = parseDate(r.dueDate);
    final total = r.interest + r.principal;
    final pFlex = total <= 0 ? 1 : (r.principal / total * 1000).round().clamp(1, 999);
    return GlassCard(
      blur: 12,
      radius: 26,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.event_available_rounded, color: Palette.indigo),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('Next EMI',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
              ),
              Text(d == null ? r.dueDate : DateFormat('d MMM y').format(d),
                  style: TextStyle(fontSize: 12.5, color: Palette.inkSoft)),
            ],
          ),
          const SizedBox(height: 8),
          Text(inr(r.emi),
              style: const TextStyle(
                  fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: -0.6)),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 9,
              child: Row(
                children: [
                  Expanded(flex: pFlex, child: Container(color: Palette.green)),
                  Expanded(flex: 1000 - pFlex, child: Container(color: Palette.violet)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                  width: 9,
                  height: 9,
                  decoration: const BoxDecoration(
                      color: Palette.green, shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Text('Principal ${inr(r.principal)}',
                  style: TextStyle(fontSize: 12, color: Palette.inkSoft)),
              const SizedBox(width: 16),
              Container(
                  width: 9,
                  height: 9,
                  decoration: const BoxDecoration(
                      color: Palette.violet, shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Text('Interest ${inr(r.interest)}',
                  style: TextStyle(fontSize: 12, color: Palette.inkSoft)),
            ],
          ),
        ],
      ),
    );
  }

  // ---- Activity -------------------------------------------------------------
  Widget _activityTab() {
    final v = _view!;
    final rows = v.timeline.reversed.toList();
    return RefreshIndicator(
      onRefresh: _fetch,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 110),
        children: [
          Row(
            children: [
              Expanded(
                child: Text('${rows.length} entries • tap one to see the working',
                    style: TextStyle(fontSize: 12.5, color: Palette.inkSoft)),
              ),
              TextButton.icon(
                onPressed: _openLedger,
                icon: const Icon(Icons.table_chart_rounded, size: 18),
                label: const Text('Full table'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          for (final r in rows) _eventCard(r),
        ],
      ),
    );
  }

  void _openLedger() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GlassScaffold(
          title: 'Full ledger',
          body: ListenableBuilder(
            listenable: _tick,
            builder: (context, _) => ListView(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 40),
              children: [_timelineTable(_view!)],
            ),
          ),
        ),
      ),
    );
  }

  (IconData, Color) _eventStyle(String type) {
    switch (type) {
      case 'DISBURSEMENT':
        return (Icons.account_balance_wallet_rounded, Palette.sky);
      case 'EMI_PAYMENT':
        return (Icons.payments_rounded, Palette.green);
      case 'PREPAYMENT':
        return (Icons.bolt_rounded, Palette.amber);
      case 'CHARGE':
        return (Icons.receipt_long_rounded, Palette.orange);
      case 'PENALTY':
        return (Icons.gavel_rounded, Palette.rose);
      case 'RATE_CHANGE':
        return (Icons.percent_rounded, Palette.violet);
      default:
        return (Icons.schedule_rounded, Palette.inkSoft);
    }
  }

  String _eventSub(TimelineRow r) {
    switch (r.eventType) {
      case 'EMI_PAYMENT':
        final parts = <String>[
          'Interest ${inr(r.interestPaid)}',
          if (r.penaltyPaid > 0) 'Penalty ${inr(r.penaltyPaid)}',
          'Principal ${inr(r.principalPaid)}',
        ];
        return parts.join(' • ');
      case 'PREPAYMENT':
        return 'Principal reduced by ${inr(r.principalPaid)}';
      case 'RATE_CHANGE':
        return 'New rate ${r.rate}%';
      case 'ACCRUAL':
        return '${r.days} ${r.days == 1 ? 'day' : 'days'} at ${r.rate}% • interest ${inr(r.periodInterest)}';
      default:
        return (r.note ?? '').isNotEmpty ? r.note!.split(' — ').first : '';
    }
  }

  Widget _eventCard(TimelineRow r) {
    final (icon, color) = _eventStyle(r.eventType);
    final d = parseDate(r.date);
    final canDelete = r.transactionId != null &&
        !(r.transactionKind == 'rate_change' &&
            r.transactionId != _loan!.rateChanges.last.id);
    final sub = _eventSub(r);
    return GlassCard(
      onTap: () => _showBreakdown(r),
      radius: 20,
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(eventLabel(r.eventType),
                    style: const TextStyle(
                        fontSize: 14.5, fontWeight: FontWeight.w800)),
                Text(d == null ? r.date : DateFormat('d MMM y').format(d),
                    style: TextStyle(fontSize: 11.5, color: Palette.inkSoft)),
                if (sub.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(sub,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11.5, color: Palette.inkSoft)),
                  ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (r.amount != 0)
                Text(inr(r.amount),
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w900)),
              Text('Owed ${inr(r.totalOutstanding)}',
                  style: TextStyle(fontSize: 11, color: Palette.inkSoft)),
            ],
          ),
          if (canDelete)
            IconButton(
              visualDensity: VisualDensity.compact,
              icon: Icon(Icons.delete_outline_rounded,
                  size: 19, color: Palette.inkSoft),
              tooltip: 'Delete',
              onPressed: () => _deleteRow(r),
            )
          else
            const SizedBox(width: 10),
        ],
      ),
    );
  }

  // ---- Rates & fees ---------------------------------------------------------
  Widget _ratesTab() {
    final loan = _loan!;
    final fmt = DateFormat('d MMM y');
    String when(String s) {
      final d = parseDate(s);
      return d == null ? s : fmt.format(d);
    }

    return RefreshIndicator(
      onRefresh: _fetch,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 110),
        children: [
          _rateHistoryCard(),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _changeRate,
            icon: const Icon(Icons.percent_rounded),
            label: const Padding(
              padding: EdgeInsets.symmetric(vertical: 11),
              child: Text('Change interest rate'),
            ),
          ),
          const SectionHeader('Bank charges'),
          if (loan.charges.isEmpty)
            _emptyNote('No bank charges recorded.')
          else
            GlassCard(
              radius: 24,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              child: Column(
                children: [
                  for (final c in loan.charges)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      leading: const Icon(Icons.receipt_long_rounded,
                          color: Palette.orange),
                      title: Text(
                          c.description.isEmpty ? 'Bank charge' : c.description,
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text(when(c.date)),
                      trailing: Text(inr(c.amount),
                          style: const TextStyle(fontWeight: FontWeight.w900)),
                    ),
                ],
              ),
            ),
          const SectionHeader('Penal charges'),
          if (loan.penalties.isEmpty)
            _emptyNote('No penal charges recorded.')
          else
            GlassCard(
              radius: 24,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              child: Column(
                children: [
                  for (final p in loan.penalties)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      leading: const Icon(Icons.gavel_rounded, color: Palette.rose),
                      title: Text(
                          'Delay ${when(p.delayStart)} → ${when(p.delayEnd)}',
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text(
                          '${p.ratePct}% + ${p.gstPct}% GST on ${inr(p.overdueAmount)}'
                          '${p.disputed ? '  •  DISPUTED' : ''}'),
                      trailing: Text(inr(p.amount),
                          style: const TextStyle(fontWeight: FontWeight.w900)),
                    ),
                ],
              ),
            ),
          const SectionHeader('Tools'),
          GlassCard(
            radius: 24,
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                _tool(Icons.calendar_month_rounded, Palette.indigo, 'EMI schedule',
                    'Upcoming and original plan', _openSchedule),
                const Divider(height: 1, indent: 60),
                _tool(Icons.insights_rounded, Palette.teal, 'Prepayment what-if',
                    'See what a lump sum saves', _openWhatIf),
                const Divider(height: 1, indent: 60),
                _tool(Icons.ios_share_rounded, Palette.sky, 'Export CSV',
                    'Share the full ledger',
                    () => exportTimelineCsv(loan.loanName, _view!)),
                const Divider(height: 1, indent: 60),
                _tool(Icons.delete_outline_rounded, Palette.rose, 'Delete loan',
                    'Removes the loan and all entries', _confirmDeleteLoan),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyNote(String t) => GlassCard(
        radius: 22,
        padding: const EdgeInsets.all(16),
        child: Text(t, style: TextStyle(color: Palette.inkSoft)),
      );

  Widget _tool(IconData i, Color c, String t, String sub, VoidCallback onTap) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: c.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(i, color: c, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t,
                      style: const TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 14.5)),
                  Text(sub, style: TextStyle(fontSize: 12, color: Palette.inkSoft)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: Palette.inkSoft),
          ],
        ),
      ),
    );
  }

  // ---- add menu -------------------------------------------------------------
  void _openAddSheet() {
    showGlassSheet<void>(
      context,
      builder: (ctx) {
        Widget item(IconData i, Color c, String t, String sub, VoidCallback go) {
          return ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
            leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: c.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(i, color: c),
            ),
            title: Text(t, style: const TextStyle(fontWeight: FontWeight.w800)),
            subtitle: Text(sub, style: TextStyle(color: Palette.inkSoft, fontSize: 12)),
            onTap: () {
              Navigator.pop(ctx);
              go();
            },
          );
        }

        return Padding(
          padding: const EdgeInsets.only(top: 6, bottom: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 8, 20, 6),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Add to this loan',
                      style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
                ),
              ),
              item(Icons.payments_rounded, Palette.green, 'EMI payment',
                  'Record an instalment', () => _addTransaction('emi')),
              item(Icons.bolt_rounded, Palette.amber, 'Prepayment',
                  'Extra money towards principal', () => _addTransaction('prepayment')),
              item(Icons.account_balance_wallet_rounded, Palette.sky, 'Disbursement',
                  'Bank released more money', () => _addTransaction('disbursement')),
              item(Icons.receipt_long_rounded, Palette.orange, 'Bank charge',
                  'Fees added to the principal', () => _addTransaction('charge')),
              item(Icons.gavel_rounded, Palette.rose, 'Penal charge',
                  'Delayed-EMI penalty with GST', _addPenalty),
            ],
          ),
        );
      },
    );
  }

  Widget _statsGrid(TimelineView v) {
    final items = <List<Object>>[
      ['Sanctioned', inr(v.sanctionedAmount), Palette.indigo],
      ['Disbursed', inr(v.totalDisbursed), Palette.sky],
      ['Undisbursed', inr(v.undisbursedAmount), Palette.teal],
      ['Interest Paid', inr(v.totalInterestPaid), Palette.violet],
      ['Principal Paid', inr(v.totalPrincipalPaid), Palette.green],
      ['Prepayments', inr(v.totalPrepayments), Palette.amber],
      if (v.totalCharges > 0)
        ['Charges Added', inr(v.totalCharges), Palette.orange],
      if (v.totalPenalties > 0)
        ['Penal Charges', inr(v.totalPenalties), Palette.rose],
      ['Next Due', v.nextDueDate ?? '-', Palette.indigo],
      ['As of', v.asOfDate, Palette.inkSoft],
    ];
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 2.5,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      children: items
          .map((e) => StatTile(
              label: e[0] as String, value: e[1] as String, accent: e[2] as Color))
          .toList(),
    );
  }

  Widget _savingsCards(TimelineView v) {
    return Row(
      children: [
        Expanded(
          child: GradientKpi(
            label: 'Interest saved',
            value: inr(v.interestSaved),
            icon: Icons.savings_rounded,
            colors: const [Color(0xFF34D399), Color(0xFF059669)],
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: GradientKpi(
            label: 'Tenure reduced',
            value: '${v.monthsSaved} mo',
            icon: Icons.timelapse_rounded,
            colors: const [Color(0xFF60A5FA), Color(0xFF4F46E5)],
          ),
        ),
      ],
    );
  }

  Widget _rateHistoryCard() {
    final loan = _loan!;
    final changes = loan.rateChanges;
    final initial = changes.isEmpty ? loan.rate : changes.first.oldRate;
    String yr(double v) => v == v.roundToDouble() ? '${v.toInt()}' : '$v';
    return GlassCard(
      radius: 26,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Interest rate history',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 6),
          Text(
              'Initial rate: $initial% p.a.'
              '${changes.isEmpty ? '  (no changes recorded)' : ''}',
              style: TextStyle(fontSize: 13, color: Palette.inkSoft)),
          for (var i = 0; i < changes.length; i++) ...[
            const Divider(height: 18),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          'From ${changes[i].effectiveDate}: ${changes[i].oldRate}% → ${changes[i].newRate}%',
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 13)),
                      Text(
                          'EMI ${inr(changes[i].oldEmi)} → ${inr(changes[i].newEmi)}  •  '
                          'tenure ${yr(changes[i].oldYears)} → ${yr(changes[i].newYears)} yr  •  '
                          '${changes[i].adjustmentType == 'KEEP_EMI' ? 'EMI kept' : 'tenure kept'}',
                          style: TextStyle(
                              fontSize: 12, color: Palette.inkSoft)),
                    ],
                  ),
                ),
                if (i == changes.length - 1)
                  IconButton(
                    icon: const Icon(Icons.undo_rounded, size: 18),
                    tooltip: 'Undo this rate change',
                    onPressed: () {
                      final row = _view!.timeline
                          .lastWhere((t) => t.transactionId == changes[i].id);
                      _deleteRow(row);
                    },
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// Shows the exact arithmetic behind a timeline row.
  void _showBreakdown(TimelineRow r) {
    String two(double v) => '₹${v.toStringAsFixed(2)}';
    final lines = <Widget>[];
    for (final s in r.segments) {
      if (s.days == 0) continue;
      lines.add(Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
            '${s.from} → ${s.to}  (${s.days} days)\n'
            '${inr(s.principal)} × ${s.rate}% × ${s.days}/365 = ${two(s.interest)}',
            style: const TextStyle(fontSize: 13)),
      ));
    }
    final rawTotal = r.segments.fold<double>(0, (t, s) => t + s.interest);

    PenaltyInput? pen;
    if (r.eventType == 'PENALTY') {
      for (final p in _loan!.penalties) {
        if (p.id == r.transactionId) pen = p;
      }
    }

    final penF = pen;
    showGlassSheet<void>(
      context,
      builder: (_) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${eventLabel(r.eventType)} — ${r.date}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            if (penF != null) ...[
              Builder(builder: (_) {
                final pen = penF;
                final c = computePenalty(
                  overdueAmount: pen.overdueAmount,
                  ratePct: pen.ratePct,
                  gstPct: pen.gstPct,
                  delayStart: parseDate(pen.delayStart) ?? DateTime.now(),
                  delayEnd: parseDate(pen.delayEnd) ?? DateTime.now(),
                );
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        'Delay: ${pen.delayStart} → ${pen.delayEnd}  (${c.days} days)\n'
                        'Overdue amount ${inr(pen.overdueAmount)} × ${pen.ratePct}% × ${c.days}/365 = ${two(c.penalty)}\n'
                        'GST ${pen.gstPct}% on ${two(c.penalty)} = ${two(c.gst)}\n'
                        'Total ${two(c.total)}, booked as ${inr(pen.amount)}',
                        style: const TextStyle(fontSize: 13)),
                    const SizedBox(height: 8),
                    Text(
                        pen.disputed
                            ? 'DISPUTED: listed for the record, but it changes no balance.'
                            : 'Not capitalised: no interest is charged on it. The next EMI clears interest first, then this penalty, then principal.',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: pen.disputed ? Palette.amber : Palette.inkSoft)),
                    if (pen.note.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text('Note: ${pen.note}',
                          style: const TextStyle(fontSize: 13)),
                    ],
                    const SizedBox(height: 10),
                  ],
                );
              }),
            ] else if (r.note != null && r.note!.isNotEmpty) ...[
              Text(r.note!, style: const TextStyle(fontSize: 13)),
              const SizedBox(height: 10),
            ],
            if (lines.isNotEmpty) ...[
              const Text('Interest accrued since the previous event',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              ...lines,
              Text('Total ${two(rawTotal)}  →  rounded ${inr(r.periodInterest)}',
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
            ] else if (r.eventType != 'PREPAYMENT' && r.eventType != 'PENALTY')
              const Text('No interest accrued in this period (0 days).',
                  style: TextStyle(fontSize: 13)),
            if (r.eventType == 'EMI_PAYMENT') ...[
              const Divider(),
              Text(
                  r.penaltyPaid > 0
                      ? 'EMI ${inr(r.amount)} = interest ${inr(r.interestPaid)} + penalty ${inr(r.penaltyPaid)} + principal ${inr(r.principalPaid)}\n'
                          '(interest first, then penal charges, then principal)'
                      : 'EMI ${inr(r.amount)} = interest ${inr(r.interestPaid)} + principal ${inr(r.principalPaid)}\n'
                          '(interest is cleared first, the rest reduces principal)',
                  style: const TextStyle(fontSize: 13)),
            ],
            if (r.eventType == 'PREPAYMENT')
              Text(
                  'Prepayment ${inr(r.amount)} → ${inr(r.principalPaid)} reduces principal (no interest/penalty).',
                  style: const TextStyle(fontSize: 13)),
            const Divider(),
            Text(
                'After this event: principal ${inr(r.outstandingPrincipal)} + accrued interest ${inr(r.accruedInterest)}'
                '${r.totalOutstanding - r.outstandingPrincipal - r.accruedInterest > 0 ? ' + penalty due ${inr(r.totalOutstanding - r.outstandingPrincipal - r.accruedInterest)}' : ''}'
                ' = ${inr(r.totalOutstanding)}',
                style: const TextStyle(fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Color _rowTint(String type) {
    switch (type) {
      case 'DISBURSEMENT':
        return Palette.sky.withValues(alpha: 0.14);
      case 'EMI_PAYMENT':
        return Palette.green.withValues(alpha: 0.14);
      case 'PREPAYMENT':
        return Palette.amber.withValues(alpha: 0.16);
      case 'ACCRUAL':
        return Palette.rose.withValues(alpha: 0.07);
      case 'CHARGE':
        return Palette.orange.withValues(alpha: 0.16);
      case 'PENALTY':
        return Palette.rose.withValues(alpha: 0.2);
      case 'RATE_CHANGE':
        return Palette.violet.withValues(alpha: 0.16);
      default:
        return Colors.transparent;
    }
  }

  Widget _timelineTable(TimelineView v) {
    return GlassCard(
      radius: 26,
      padding: const EdgeInsets.only(top: 4, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(18, 14, 18, 2),
            child: Text('Timeline',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(18, 0, 18, 8),
            child: Text('Tap any row to see the working',
                style: TextStyle(fontSize: 12, color: Palette.inkSoft)),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              showCheckboxColumn: false,
              columnSpacing: 18,
              dividerThickness: 0.4,
              columns: const [
                DataColumn(label: Text('Date')),
                DataColumn(label: Text('Event')),
                DataColumn(label: Text('Amount')),
                DataColumn(label: Text('Days')),
                DataColumn(label: Text('Rate')),
                DataColumn(label: Text('Interest')),
                DataColumn(label: Text('Penalty')),
                DataColumn(label: Text('Principal')),
                DataColumn(label: Text('Outstanding')),
                DataColumn(label: Text('Total Owed')),
                DataColumn(label: Text('')),
              ],
              rows: v.timeline.map((r) {
                return DataRow(
                  onSelectChanged: (_) => _showBreakdown(r),
                  color: WidgetStateProperty.all(_rowTint(r.eventType)),
                  cells: [
                    DataCell(Text(r.date)),
                    DataCell(Text(
                        r.eventType == 'CHARGE' && (r.note ?? '').isNotEmpty
                            ? '${eventLabel(r.eventType)}\n${r.note!.split(' — ').first}'
                            : eventLabel(r.eventType),
                        style: const TextStyle(fontWeight: FontWeight.w600))),
                    DataCell(Text(r.amount == 0 ? '-' : inr(r.amount))),
                    DataCell(Text('${r.days}')),
                    DataCell(Text(r.rate == 0 ? '-' : '${r.rate}%')),
                    DataCell(Text(r.eventType == 'EMI_PAYMENT'
                        ? inr(r.interestPaid)
                        : inr(r.periodInterest))),
                    DataCell(Text(r.penaltyPaid > 0 ? inr(r.penaltyPaid) : '-')),
                    DataCell(Text(
                        r.principalPaid == 0 ? '-' : inr(r.principalPaid))),
                    DataCell(Text(inr(r.outstandingPrincipal))),
                    DataCell(Text(inr(r.totalOutstanding),
                        style: const TextStyle(fontWeight: FontWeight.w700))),
                    DataCell(r.transactionId == null ||
                            (r.transactionKind == 'rate_change' &&
                                r.transactionId != _loan!.rateChanges.last.id)
                        ? const SizedBox.shrink()
                        : IconButton(
                            icon: const Icon(Icons.delete_outline_rounded,
                                size: 18),
                            tooltip: 'Delete',
                            onPressed: () => _deleteRow(r),
                          )),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _PenaltyResult {
  final double overdue;
  final double ratePct;
  final double gstPct;
  final String delayStart;
  final String delayEnd;
  final String leviedDate;
  final double booked;
  final bool disputed;
  final String note;
  _PenaltyResult(this.overdue, this.ratePct, this.gstPct, this.delayStart,
      this.delayEnd, this.leviedDate, this.booked, this.disputed, this.note);
}

/// Records a penal charge. Union Bank's published policy (effective 01-04-2024)
/// is 2% p.a. on a delayed instalment plus GST, never capitalised: both values
/// are pre-filled but editable.
class _PenaltySheet extends StatefulWidget {
  final double defaultAmount;
  final String minDate;
  const _PenaltySheet({required this.defaultAmount, required this.minDate});

  @override
  State<_PenaltySheet> createState() => _PenaltySheetState();
}

class _PenaltySheetState extends State<_PenaltySheet> {
  late final TextEditingController _overdue =
      TextEditingController(text: widget.defaultAmount.round().toString());
  final _rate = TextEditingController(text: '2');
  final _gst = TextEditingController(text: '18');
  final _note = TextEditingController();
  DateTime _start = DateTime.now();
  DateTime _end = DateTime.now();
  DateTime? _levied;
  bool _disputed = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_overdue, _rate, _gst, _note]) {
      c.dispose();
    }
    super.dispose();
  }

  String _fmt(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  DateTime get _leviedEff => _levied ?? _end;

  PenaltyCalc? get _calc {
    final o = double.tryParse(_overdue.text);
    final r = double.tryParse(_rate.text);
    final g = double.tryParse(_gst.text);
    if (o == null || r == null || g == null || o <= 0 || r < 0 || g < 0) {
      return null;
    }
    return computePenalty(
      overdueAmount: o,
      ratePct: r,
      gstPct: g,
      delayStart: DateTime.utc(_start.year, _start.month, _start.day),
      delayEnd: DateTime.utc(_end.year, _end.month, _end.day),
    );
  }

  Future<DateTime?> _pick(DateTime initial) => showDatePicker(
        context: context,
        initialDate: initial,
        firstDate: DateTime.parse(widget.minDate),
        lastDate: DateTime(2100),
      );

  Widget _dateTile(String label, DateTime d, void Function(DateTime) set) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () async {
          final p = await _pick(d);
          if (p != null) setState(() => set(p));
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Palette.glass(0.6),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Palette.glass(0.95)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(fontSize: 11, color: Palette.inkSoft)),
              const SizedBox(height: 2),
              Row(
                children: [
                  Expanded(
                      child: Text(_fmt(d),
                          style: const TextStyle(fontWeight: FontWeight.w700))),
                  const Icon(Icons.calendar_today_rounded, size: 16),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = _calc;
    String two(double v) => '₹${v.toStringAsFixed(2)}';
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
          20, 12, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Add Penal Charge',
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(
              'Union Bank: 2% p.a. on the delayed instalment, plus GST, never capitalised.',
              style: TextStyle(fontSize: 12, color: Palette.inkSoft)),
          const SizedBox(height: 14),
          TextField(
            controller: _overdue,
            keyboardType: TextInputType.number,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
                labelText: 'Overdue EMI amount (₹)',
                prefixIcon: Icon(Icons.account_balance_wallet_outlined)),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _rate,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                      labelText: 'Penal rate (% p.a.)'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _gst,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(labelText: 'GST (%)'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _dateTile('Delay starts (due date)', _start, (d) {
                _start = d;
                if (_end.isBefore(d)) _end = d;
              }),
              const SizedBox(width: 10),
              _dateTile('Delay ends (paid on)', _end, (d) => _end = d),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _dateTile('Charged on the ledger', _leviedEff, (d) => _levied = d),
            ],
          ),
          const SizedBox(height: 12),
          GlassCard(
            radius: 18,
            padding: const EdgeInsets.all(14),
            tint: Palette.indigo,
            child: c == null
                ? const Text('Enter the amount, rate and GST to see the maths.',
                    style: TextStyle(fontSize: 13))
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${c.days} day${c.days == 1 ? '' : 's'} of delay',
                          style: const TextStyle(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 4),
                      Text(
                          '₹${_overdue.text} × ${_rate.text}% × ${c.days}/365 = ${two(c.penalty)}\n'
                          'GST ${_gst.text}% = ${two(c.gst)}\n'
                          'Total ${two(c.total)}  →  booked ${inr(c.booked)}',
                          style: const TextStyle(fontSize: 13, height: 1.45)),
                    ],
                  ),
          ),
          const SizedBox(height: 6),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _disputed,
            onChanged: (v) => setState(() => _disputed = v),
            title: const Text('Mark as disputed'),
            subtitle: const Text(
                'Kept on the ledger for the record, but changes no balance'),
          ),
          TextField(
            controller: _note,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
                labelText: 'Note (optional)',
                hintText: 'e.g. NACH debit delayed by bank'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(color: Palette.rose)),
          ],
          const SizedBox(height: 14),
          FilledButton(
            onPressed: () {
              final c = _calc;
              if (c == null || c.days <= 0 || c.booked <= 0) {
                setState(() => _error =
                    'Pick delay dates with at least 1 day and a valid amount.');
                return;
              }
              Navigator.pop(
                context,
                _PenaltyResult(
                  double.parse(_overdue.text),
                  double.parse(_rate.text),
                  double.parse(_gst.text),
                  _fmt(_start),
                  _fmt(_end),
                  _fmt(_leviedEff),
                  c.booked,
                  _disputed,
                  _note.text,
                ),
              );
            },
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('Save penalty'),
            ),
          ),
        ],
      ),
    );
  }
}

class _TxInput {
  final double amount;
  final String date;
  final String description;
  _TxInput(this.amount, this.date, [this.description = '']);
}

class _AddTransactionSheet extends StatefulWidget {
  final String kind;
  const _AddTransactionSheet({required this.kind});

  @override
  State<_AddTransactionSheet> createState() => _AddTransactionSheetState();
}

class _AddTransactionSheetState extends State<_AddTransactionSheet> {
  final _amount = TextEditingController();
  final _desc = TextEditingController();
  DateTime _date = DateTime.now();

  String get _title {
    switch (widget.kind) {
      case 'disbursement':
        return 'Add Disbursement';
      case 'emi':
        return 'Record EMI Payment';
      case 'prepayment':
        return 'Add Prepayment';
      case 'charge':
        return 'Add Bank Charge';
      default:
        return 'Add';
    }
  }

  String _fmt(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  void dispose() {
    _amount.dispose();
    _desc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(_title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          TextField(
            controller: _amount,
            keyboardType: TextInputType.number,
            autofocus: true,
            decoration: const InputDecoration(
                labelText: 'Amount (₹)', border: OutlineInputBorder()),
          ),
          if (widget.kind == 'charge') ...[
            const SizedBox(height: 8),
            TextField(
              controller: _desc,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                  labelText: 'Description (e.g. Processing fee, GST)',
                  helperText: 'Added to your outstanding principal',
                  border: OutlineInputBorder()),
            ),
          ],
          const SizedBox(height: 8),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Date'),
            subtitle: Text(_fmt(_date)),
            trailing: const Icon(Icons.calendar_today),
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _date,
                firstDate: DateTime(2000),
                lastDate: DateTime(2100),
              );
              if (picked != null) setState(() => _date = picked);
            },
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: () {
              final amt = double.tryParse(_amount.text);
              if (amt == null || amt <= 0) return;
              Navigator.pop(context, _TxInput(amt, _fmt(_date), _desc.text));
            },
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('Save'),
            ),
          ),
        ],
      ),
    );
  }
}

class _RateChoice {
  final double newRate;
  final String adjustmentType; // KEEP_EMI | KEEP_TENURE
  final String date; // effective date YYYY-MM-DD
  final double? previousRate; // only for the first change on a loan
  _RateChoice(this.newRate, this.adjustmentType, this.date, this.previousRate);
}

class _RateChangeDialog extends StatefulWidget {
  final double currentRate;
  final bool hasHistory;
  final String minDate;
  const _RateChangeDialog({
    required this.currentRate,
    required this.hasHistory,
    required this.minDate,
  });

  @override
  State<_RateChangeDialog> createState() => _RateChangeDialogState();
}

class _RateChangeDialogState extends State<_RateChangeDialog> {
  late final TextEditingController _rate =
      TextEditingController(text: widget.currentRate.toString());
  late final TextEditingController _prev =
      TextEditingController(text: widget.currentRate.toString());
  DateTime _date = DateTime.now();
  String _mode = 'KEEP_TENURE';
  String? _error;

  String _fmt(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  void dispose() {
    _rate.dispose();
    _prev.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Change interest rate'),
      content: SingleChildScrollView(
        child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _rate,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
                labelText: 'New rate (% p.a.)', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 8),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Effective from'),
            subtitle: Text(_fmt(_date)),
            trailing: const Icon(Icons.calendar_today),
            onTap: () async {
              final min = DateTime.parse(widget.minDate);
              final picked = await showDatePicker(
                context: context,
                initialDate: _date.isBefore(min) ? min : _date,
                firstDate: min,
                lastDate: DateTime(2100),
              );
              if (picked != null) setState(() => _date = picked);
            },
          ),
          if (!widget.hasHistory) ...[
            TextField(
              controller: _prev,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                  labelText: 'Rate before this date (% p.a.)',
                  helperText:
                      'Interest before the effective date is charged at this rate',
                  border: OutlineInputBorder()),
            ),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 4),
          RadioListTile<String>(
            contentPadding: EdgeInsets.zero,
            value: 'KEEP_TENURE',
            groupValue: _mode,
            onChanged: (v) => setState(() => _mode = v!),
            title: const Text('Keep tenure (recalculate EMI)'),
          ),
          RadioListTile<String>(
            contentPadding: EdgeInsets.zero,
            value: 'KEEP_EMI',
            groupValue: _mode,
            onChanged: (v) => setState(() => _mode = v!),
            title: const Text('Keep EMI (recalculate tenure)'),
          ),
          if (_error != null)
            Text(_error!, style: const TextStyle(color: Colors.red)),
        ],
      ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            final r = double.tryParse(_rate.text);
            if (r == null || r <= 0 || r > 50) {
              setState(() => _error = 'Enter a rate between 0 and 50');
              return;
            }
            double? prev;
            if (!widget.hasHistory) {
              prev = double.tryParse(_prev.text);
              if (prev == null || prev <= 0 || prev > 50) {
                setState(() => _error = 'Enter the previous rate (0–50)');
                return;
              }
            }
            Navigator.pop(context, _RateChoice(r, _mode, _fmt(_date), prev));
          },
          child: const Text('Apply'),
        ),
      ],
    );
  }
}


