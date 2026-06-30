import 'package:flutter/material.dart';

import '../models.dart';
import '../supabase_service.dart';
import '../utils.dart';
import 'loan_timeline_screen.dart';
import 'new_loan_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late Future<List<Loan>> _future;

  @override
  void initState() {
    super.initState();
    _future = SupabaseService.fetchLoans();
  }

  void _refresh() {
    setState(() => _future = SupabaseService.fetchLoans());
  }

  Future<void> _openNewLoan() async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const NewLoanScreen()),
    );
    if (created == true) _refresh();
  }

  Future<void> _openTimeline(Loan loan) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => LoanTimelineScreen(loanId: loan.id)),
    );
    _refresh(); // re-fetch in case transactions changed
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Loans'),
        backgroundColor: const Color(0xFF1976d2),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout),
            onPressed: () => SupabaseService.signOut(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openNewLoan,
        icon: const Icon(Icons.add),
        label: const Text('Add Loan'),
      ),
      body: RefreshIndicator(
        onRefresh: () async => _refresh(),
        child: FutureBuilder<List<Loan>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return _ErrorView(message: '${snap.error}', onRetry: _refresh);
            }
            final loans = snap.data ?? [];
            if (loans.isEmpty) {
              return ListView(
                children: const [
                  SizedBox(height: 160),
                  Icon(Icons.account_balance_wallet_outlined,
                      size: 72, color: Colors.grey),
                  SizedBox(height: 12),
                  Center(child: Text('No loans yet. Tap "Add Loan".')),
                ],
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: loans.length,
              itemBuilder: (context, i) => _LoanCard(
                loan: loans[i],
                onTap: () => _openTimeline(loans[i]),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _LoanCard extends StatelessWidget {
  final Loan loan;
  final VoidCallback onTap;
  const _LoanCard({required this.loan, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = loan.timeline();
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(loan.loanName,
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                  Text('${loan.rate}%  •  ${loan.years.toStringAsFixed(0)} yr',
                      style: const TextStyle(color: Colors.black54)),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 16,
                runSpacing: 8,
                children: [
                  _stat('Sanctioned', inr(loan.sanctionedAmount)),
                  _stat('Outstanding', inr(t.totalOutstanding)),
                  _stat('Monthly EMI', inr(t.monthlyEmi)),
                  if (t.interestSaved > 0)
                    _stat('Interest Saved', inr(t.interestSaved),
                        color: const Color(0xFF2e7d32)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stat(String label, String value, {Color? color}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.black54)),
        Text(value,
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.w600, color: color)),
      ],
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
