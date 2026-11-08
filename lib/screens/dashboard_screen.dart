import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../loan_store.dart';
import '../widgets/glass.dart';
import 'loan_timeline_screen.dart';
import 'new_loan_screen.dart';
import 'tabs/home_tab.dart';
import 'tabs/loans_tab.dart';
import 'tabs/more_tab.dart';
import 'tabs/reports_tab.dart';

/// App shell: four tabs behind a floating glass navigation bar with a
/// centre "+" button to add a loan.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _store = LoanStore();
  int _tab = 0;
  StreamSubscription<AuthState>? _authSub;

  @override
  void initState() {
    super.initState();
    _store.refresh();
    // Re-draw greeting/avatars when the name or email is updated.
    _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _store.dispose();
    super.dispose();
  }

  Future<void> _addLoan() async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const NewLoanScreen()),
    );
    if (created == true) {
      await _store.refresh();
      if (mounted) setState(() => _tab = 1);
    }
  }

  Future<void> _open(LoanSnap s) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => LoanTimelineScreen(loanId: s.loan.id)),
    );
    _store.refresh(); // transactions may have changed
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: (Palette.isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark)
          .copyWith(statusBarColor: Colors.transparent),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBody: true,
        body: GlassBackground(
          child: SafeArea(
            bottom: false,
            child: IndexedStack(
              index: _tab,
              children: [
                HomeTab(
                    store: _store,
                    onOpen: _open,
                    onAdd: _addLoan,
                    goTab: (i) => setState(() => _tab = i)),
                LoansTab(store: _store, onOpen: _open, onAdd: _addLoan),
                ReportsTab(store: _store),
                MoreTab(store: _store),
              ],
            ),
          ),
        ),
        bottomNavigationBar: _NavBar(
          index: _tab,
          onTap: (i) => setState(() => _tab = i),
          onAdd: _addLoan,
        ),
      ),
    );
  }
}

class _NavBar extends StatelessWidget {
  final int index;
  final ValueChanged<int> onTap;
  final VoidCallback onAdd;
  const _NavBar({required this.index, required this.onTap, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(
                  color: Palette.navy.withValues(alpha: 0.16),
                  blurRadius: 28,
                  offset: const Offset(0, 10)),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(32),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
              child: Container(
                height: 70,
                decoration: BoxDecoration(
                  color: Palette.glass(0.78),
                  borderRadius: BorderRadius.circular(32),
                  border: Border.all(color: Palette.glass(0.95), width: 1.2),
                ),
                child: Row(
                  children: [
                    _item(0, Icons.home_rounded, 'Home'),
                    _item(1, Icons.account_balance_rounded, 'Loans'),
                    Expanded(
                      child: Center(
                        child: GestureDetector(
                          onTap: onAdd,
                          child: Container(
                            width: 54,
                            height: 54,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [Palette.blue, Palette.violet],
                              ),
                              boxShadow: [
                                BoxShadow(
                                    color: Palette.blue.withValues(alpha: 0.45),
                                    blurRadius: 16,
                                    offset: const Offset(0, 7)),
                              ],
                            ),
                            child: const Icon(Icons.add_rounded,
                                color: Colors.white, size: 30),
                          ),
                        ),
                      ),
                    ),
                    _item(2, Icons.bar_chart_rounded, 'Reports'),
                    _item(3, Icons.grid_view_rounded, 'More'),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _item(int i, IconData icon, String label) {
    final sel = index == i;
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () => onTap(i),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 25, color: sel ? Palette.accent : Palette.inkSoft),
            const SizedBox(height: 3),
            Text(label,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: sel ? FontWeight.w900 : FontWeight.w600,
                    color: sel ? Palette.accent : Palette.inkSoft)),
          ],
        ),
      ),
    );
  }
}

