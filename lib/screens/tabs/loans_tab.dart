import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../loan_store.dart';
import '../../theme_controller.dart';
import '../../utils.dart';
import '../../widgets/glass.dart';
import '../../widgets/premium.dart';
import 'home_tab.dart' show dueColor, dueText;

enum _Filter { all, active, closed }

class LoansTab extends StatefulWidget {
  final LoanStore store;
  final void Function(LoanSnap) onOpen;
  final VoidCallback onAdd;
  const LoansTab(
      {super.key, required this.store, required this.onOpen, required this.onAdd});

  @override
  State<LoansTab> createState() => _LoansTabState();
}

class _LoansTabState extends State<LoansTab> {
  _Filter _filter = _Filter.all;
  String _q = '';

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([widget.store, ThemeController.hideAmounts]),
      builder: (context, _) {
        final all = widget.store.snaps;
        final shown = all.where((s) {
          if (_filter == _Filter.active && !s.active) return false;
          if (_filter == _Filter.closed && !s.closed) return false;
          if (_q.isNotEmpty &&
              !s.loan.loanName.toLowerCase().contains(_q.toLowerCase())) {
            return false;
          }
          return true;
        }).toList();
        return RefreshIndicator(
          onRefresh: widget.store.refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 120),
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text('My Loans',
                        style: TextStyle(
                            fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: -0.7)),
                  ),
                  IconButton.filled(
                    style: IconButton.styleFrom(backgroundColor: Palette.indigo),
                    onPressed: widget.onAdd,
                    icon: const Icon(Icons.add_rounded),
                    tooltip: 'Add loan',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                onChanged: (v) => setState(() => _q = v.trim()),
                decoration: const InputDecoration(
                  hintText: 'Search loans',
                  prefixIcon: Icon(Icons.search_rounded),
                  contentPadding: EdgeInsets.symmetric(vertical: 12),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _chip('All', all.length, _Filter.all),
                  const SizedBox(width: 8),
                  _chip('Active', widget.store.active.length, _Filter.active),
                  const SizedBox(width: 8),
                  _chip('Closed', widget.store.closed.length, _Filter.closed),
                ],
              ),
              const SizedBox(height: 14),
              if (widget.store.loading && all.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 100),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (shown.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 60),
                  child: Column(
                    children: [
                      const Text('🗂️', style: TextStyle(fontSize: 44)),
                      const SizedBox(height: 8),
                      Text(all.isEmpty ? 'No loans yet' : 'No loans match',
                          style: const TextStyle(
                              fontSize: 17, fontWeight: FontWeight.w800)),
                    ],
                  ),
                )
              else
                ...shown.map((s) => _LoanCard(snap: s, onTap: () => widget.onOpen(s))),
            ],
          ),
        );
      },
    );
  }

  Widget _chip(String label, int n, _Filter f) {
    final sel = _filter == f;
    return GestureDetector(
      onTap: () => setState(() => _filter = f),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          gradient: sel
              ? const LinearGradient(colors: [Palette.blue, Palette.indigo])
              : null,
          color: sel ? null : Palette.glass(0.6),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: Palette.glass(0.9)),
        ),
        child: Text('$label ($n)',
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: sel ? Colors.white : Palette.ink)),
      ),
    );
  }
}

class _LoanCard extends StatelessWidget {
  final LoanSnap snap;
  final VoidCallback onTap;
  const _LoanCard({required this.snap, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final loan = snap.loan;
    final v = snap.view;
    final repaid = snap.repaidFraction;
    final days = snap.daysToDue;
    return GlassCard(
      onTap: onTap,
      blur: 12,
      radius: 28,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              InitialsAvatar(loan.loanName, radius: 23),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(loan.loanName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w900)),
                    Text(
                        '${loan.rate}% p.a. • ${loan.years.toStringAsFixed(loan.years == loan.years.roundToDouble() ? 0 : 1)} yr',
                        style: TextStyle(fontSize: 12, color: Palette.inkSoft)),
                  ],
                ),
              ),
              snap.closed
                  ? StatusChip('Closed', color: Palette.inkSoft)
                  : const StatusChip('Active', color: Palette.green),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Outstanding',
                        style: TextStyle(fontSize: 12, color: Palette.inkSoft)),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(hideAmt(inr(v.totalOutstanding)),
                          style: const TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.6)),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('EMI',
                      style: TextStyle(fontSize: 12, color: Palette.inkSoft)),
                  Text(hideAmt(inr(v.monthlyEmi)),
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w800)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: repaid,
              minHeight: 8,
              backgroundColor: Palette.indigo.withValues(alpha: 0.1),
              valueColor: const AlwaysStoppedAnimation(Palette.green),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Paid ${inr(v.totalPrincipalPaid)}',
                  style: TextStyle(fontSize: 12, color: Palette.inkSoft)),
              Text('${(repaid * 100).toStringAsFixed(1)}% repaid',
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: Palette.green)),
            ],
          ),
          if (snap.nextDue != null || v.penaltyDue > 0) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                if (snap.nextDue != null)
                  StatusChip(
                      '${dueText(days)} • ${DateFormat('d MMM').format(snap.nextDue!)}',
                      color: dueColor(days)),
                if (v.penaltyDue > 0)
                  StatusChip('Penalty due ${inr(v.penaltyDue)}', color: Palette.rose),
                if (v.interestSaved > 0)
                  StatusChip('Saved ${inr(v.interestSaved)}', color: Palette.teal),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

