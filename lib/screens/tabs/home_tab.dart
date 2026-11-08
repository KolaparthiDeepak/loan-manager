import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../loan_store.dart';
import '../../supabase_service.dart';
import '../../theme_controller.dart';
import '../../utils.dart';
import '../../widgets/glass.dart';
import '../../widgets/premium.dart';
import '../auth_flow.dart';
import '../whatif_screen.dart';

String _greeting() {
  final h = DateTime.now().hour;
  if (h < 12) return 'Good morning';
  if (h < 17) return 'Good afternoon';
  return 'Good evening';
}

String dueText(int? d) {
  if (d == null) return '';
  if (d < 0) return 'Overdue ${-d}d';
  if (d == 0) return 'Due today';
  if (d == 1) return 'Due tomorrow';
  return 'Due in $d days';
}

Color dueColor(int? d) {
  if (d == null) return Palette.inkSoft;
  if (d < 0) return Palette.rose;
  if (d <= 5) return Palette.amber;
  return Palette.green;
}

class HomeTab extends StatelessWidget {
  final LoanStore store;
  final void Function(LoanSnap) onOpen;
  final VoidCallback onAdd;
  final ValueChanged<int> goTab;
  const HomeTab({
    super.key,
    required this.store,
    required this.onOpen,
    required this.onAdd,
    required this.goTab,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([store, ThemeController.hideAmounts]),
      builder: (context, _) => RefreshIndicator(
        onRefresh: store.refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 120),
          children: [
            _header(context),
            const SizedBox(height: 18),
            if (store.loading && store.snaps.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 120),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (store.error != null && store.snaps.isEmpty)
              _ErrorCard(message: store.error!, onRetry: store.refresh)
            else if (store.snaps.isEmpty)
              _EmptyCard(onAdd: onAdd)
            else
              ..._content(context),
          ],
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    final name = SupabaseService.displayName;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${_greeting()},',
                  style: TextStyle(
                      fontSize: 14,
                      color: Palette.inkSoft,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text('$name 👋',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: -0.6)),
            ],
          ),
        ),
        InkWell(
          borderRadius: BorderRadius.circular(30),
          onTap: () => showAccountSheet(context),
          child: Container(
            padding: const EdgeInsets.all(2.5),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(colors: [Palette.indigo, Palette.violet]),
            ),
            child: CircleAvatar(
              radius: 22,
              backgroundColor: Palette.glass(1),
              child: InitialsAvatar(name, radius: 20),
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _content(BuildContext context) {
    final due = store.upcomingDue;
    final next = due.isEmpty ? null : due.first;
    final tip = store.prepayTip;
    final free = store.debtFreeDate;
    final fmt = DateFormat('d MMM y');
    final months = store.active.isEmpty
        ? 0
        : store.active.map((s) => s.upcoming.length).reduce((a, b) => a > b ? a : b);

    return [
      HeroCard(
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text('Total borrowed',
                          style: TextStyle(color: Colors.white70, fontSize: 13)),
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: () => ThemeController.setHideAmounts(
                            !ThemeController.hideAmounts.value),
                        child: Icon(
                          ThemeController.hideAmounts.value
                              ? Icons.visibility_off_rounded
                              : Icons.visibility_rounded,
                          size: 18,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(hideAmt(inr(store.totalBorrowed)),
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -1)),
                  ),
                  const SizedBox(height: 14),
                  const Text('Outstanding',
                      style: TextStyle(color: Colors.white70, fontSize: 12.5)),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(hideAmt(inr(store.totalOutstanding)),
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 21,
                            fontWeight: FontWeight.w800)),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              children: [
                RingProgress(
                  value: store.repaidFraction,
                  size: 84,
                  stroke: 9,
                  label: '${(store.repaidFraction * 100).toStringAsFixed(0)}%',
                  labelStyle: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w900, fontSize: 17),
                ),
                const SizedBox(height: 4),
                const Text('repaid',
                    style: TextStyle(color: Colors.white70, fontSize: 11.5)),
              ],
            ),
          ],
        ),
      ),
      const SizedBox(height: 14),
      if (next != null)
        GlassCard(
          onTap: () => onOpen(next),
          blur: 12,
          radius: 24,
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: Palette.indigo.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Icon(Icons.event_available_rounded,
                    color: Palette.indigo, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Next due',
                        style: TextStyle(fontSize: 12, color: Palette.inkSoft)),
                    const SizedBox(height: 2),
                    Text('${hideAmt(inr(next.view.monthlyEmi))} • ${fmt.format(next.nextDue!)}',
                        style: const TextStyle(
                            fontSize: 16.5, fontWeight: FontWeight.w900)),
                    Text(next.loan.loanName,
                        style: TextStyle(fontSize: 12, color: Palette.inkSoft)),
                  ],
                ),
              ),
              StatusChip(dueText(next.daysToDue), color: dueColor(next.daysToDue)),
            ],
          ),
        ),
      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(
            child: _MiniStat(
              icon: Icons.percent_rounded,
              color: Palette.violet,
              label: 'Total interest paid',
              value: hideAmt(inr(store.totalInterestPaid)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _MiniStat(
              icon: Icons.check_circle_rounded,
              color: Palette.green,
              label: 'Paid till date',
              value: hideAmt(inr(store.paidTillDate)),
            ),
          ),
        ],
      ),
      if (tip != null) ...[
        const SizedBox(height: 14),
        _TipCard(
          tip: tip,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => WhatIfScreen(loan: tip.snap.loan)),
          ),
        ),
      ],
      if (due.isNotEmpty) ...[
        SectionHeader('Upcoming payments',
            action: 'All loans', onAction: () => goTab(1)),
        ...due.take(4).map((s) => _UpcomingRow(snap: s, onTap: () => onOpen(s))),
      ],
      if (free != null) ...[
        const SizedBox(height: 14),
        GlassCard(
          radius: 24,
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Text('🎯', style: TextStyle(fontSize: 30)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Debt-free by',
                        style: TextStyle(fontSize: 12, color: Palette.inkSoft)),
                    Text(DateFormat('MMMM y').format(free),
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w900)),
                    Text('$months EMIs to go at today\'s rate',
                        style: TextStyle(fontSize: 12, color: Palette.inkSoft)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
      if (store.paidTillDate > 0) ...[
        const SizedBox(height: 12),
        GlassCard(
          radius: 24,
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              RingProgress(
                value: store.interestShare,
                size: 54,
                stroke: 7,
                track: Palette.indigo.withValues(alpha: 0.12),
                color: Palette.violet,
                label: '${(store.interestShare * 100).toStringAsFixed(0)}%',
                labelStyle: TextStyle(
                    fontSize: 12.5, fontWeight: FontWeight.w900, color: Palette.ink),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  'Of every ₹100 you have paid so far, '
                  '₹${(store.interestShare * 100).toStringAsFixed(0)} went to interest. '
                  'Prepaying early shrinks this.',
                  style: const TextStyle(fontSize: 13, height: 1.4),
                ),
              ),
            ],
          ),
        ),
      ],
    ];
  }
}

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;
  const _MiniStat(
      {required this.icon,
      required this.color,
      required this.label,
      required this.value});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      radius: 24,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(height: 10),
          Text(label, style: TextStyle(fontSize: 12, color: Palette.inkSoft)),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value,
                style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }
}

class _TipCard extends StatelessWidget {
  final PrepayTip tip;
  final VoidCallback onTap;
  const _TipCard({required this.tip, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: Palette.isDark
                ? [const Color(0xFF3B2F14), const Color(0xFF3B1A2B)]
                : [const Color(0xFFFFF3D6), const Color(0xFFFFE4EC)],
          ),
          border: Border.all(color: Palette.glass(0.95), width: 1.2),
          boxShadow: [
            BoxShadow(
                color: Palette.amber.withValues(alpha: 0.18),
                blurRadius: 20,
                offset: const Offset(0, 8)),
          ],
        ),
        child: Row(
          children: [
            const Text('💡', style: TextStyle(fontSize: 30)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Smart tip',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: Palette.orange)),
                  const SizedBox(height: 2),
                  Text(
                    'Prepay ${inr(tip.amount)} on ${tip.snap.loan.loanName} '
                    'and save ${inr(tip.interestSaved)} in interest'
                    '${tip.monthsSaved > 0 ? ' and ${tip.monthsSaved} months' : ''}.',
                    style: const TextStyle(
                        fontSize: 13.5, fontWeight: FontWeight.w700, height: 1.35),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: Palette.inkSoft),
          ],
        ),
      ),
    );
  }
}

class _UpcomingRow extends StatelessWidget {
  final LoanSnap snap;
  final VoidCallback onTap;
  const _UpcomingRow({required this.snap, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final d = snap.nextDue!;
    final days = snap.daysToDue;
    return GlassCard(
      onTap: onTap,
      radius: 22,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Container(
            width: 52,
            padding: const EdgeInsets.symmetric(vertical: 7),
            decoration: BoxDecoration(
              color: dueColor(days).withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Column(
              children: [
                Text(DateFormat('MMM').format(d).toUpperCase(),
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: dueColor(days))),
                Text('${d.day}',
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w900, height: 1.1)),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(snap.loan.loanName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w800)),
                Text(hideAmt(inr(snap.view.monthlyEmi)),
                    style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: Palette.inkSoft)),
              ],
            ),
          ),
          StatusChip(dueText(days), color: dueColor(days)),
        ],
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyCard({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 40),
      child: GlassCard(
        blur: 16,
        radius: 32,
        padding: const EdgeInsets.all(28),
        child: Column(
          children: [
            const Text('🏦', style: TextStyle(fontSize: 52)),
            const SizedBox(height: 12),
            const Text('Add your first loan',
                style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            Text(
                'Track every EMI, rate change and charge — with the maths shown.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Palette.inkSoft, height: 1.4)),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded),
              label: const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('Add loan'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorCard({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 40),
      child: GlassCard(
        blur: 16,
        radius: 28,
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Icon(Icons.cloud_off_rounded, color: Palette.rose, size: 46),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 14),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

