import 'package:flutter/material.dart';

import '../loan_engine.dart';
import '../models.dart';
import '../supabase_service.dart';
import '../utils.dart';

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
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _addTransaction(String kind) async {
    final result = await showModalBottomSheet<_TxInput>(
      context: context,
      isScrollControlled: true,
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
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_loan?.loanName ?? 'Loan'),
        backgroundColor: const Color(0xFF1976d2),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Delete loan',
            onPressed: _loan == null ? null : _confirmDeleteLoan,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : RefreshIndicator(
                  onRefresh: _fetch,
                  child: ListView(
                    padding: const EdgeInsets.all(12),
                    children: [
                      _statsGrid(_view!),
                      const SizedBox(height: 8),
                      if (_view!.interestSaved > 0) _savingsCards(_view!),
                      const SizedBox(height: 8),
                      _actionButtons(),
                      const SizedBox(height: 8),
                      _timelineTable(_view!),
                    ],
                  ),
                ),
    );
  }

  Widget _statsGrid(TimelineView v) {
    final items = <List<String>>[
      ['Sanctioned', inr(v.sanctionedAmount)],
      ['Disbursed', inr(v.totalDisbursed)],
      ['Undisbursed', inr(v.undisbursedAmount)],
      ['Monthly EMI', inr(v.monthlyEmi)],
      ['Outstanding Principal', inr(v.outstandingPrincipal)],
      ['Accrued Interest', inr(v.accruedInterest)],
      ['Total Outstanding', inr(v.totalOutstanding)],
      ['Total Prepayments', inr(v.totalPrepayments)],
      ['Interest Paid', inr(v.totalInterestPaid)],
      ['Principal Paid', inr(v.totalPrincipalPaid)],
      ['Next Due', v.nextDueDate ?? '-'],
      ['As of', v.asOfDate],
    ];
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 2.4,
      crossAxisSpacing: 8,
      mainAxisSpacing: 8,
      children: items
          .map((e) => Card(
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(e[0],
                          style: const TextStyle(
                              fontSize: 11, color: Colors.black54)),
                      const SizedBox(height: 2),
                      Text(e[1],
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ))
          .toList(),
    );
  }

  Widget _savingsCards(TimelineView v) {
    return Row(
      children: [
        Expanded(
          child: _gradientCard('💰 Interest Saved', inr(v.interestSaved),
              const [Color(0xFF4caf50), Color(0xFF2e7d32)]),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _gradientCard('⏱️ Tenure Reduced', '${v.monthsSaved} mo',
              const [Color(0xFF2196f3), Color(0xFF1565c0)]),
        ),
      ],
    );
  }

  Widget _gradientCard(String label, String value, List<Color> colors) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: colors),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 6),
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _actionButtons() {
    return Wrap(
      spacing: 8,
      children: [
        OutlinedButton.icon(
          onPressed: () => _addTransaction('disbursement'),
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Disbursement'),
        ),
        OutlinedButton.icon(
          onPressed: () => _addTransaction('emi'),
          icon: const Icon(Icons.payments, size: 18),
          label: const Text('EMI'),
        ),
        OutlinedButton.icon(
          onPressed: () => _addTransaction('prepayment'),
          icon: const Icon(Icons.bolt, size: 18),
          label: const Text('Prepayment'),
        ),
      ],
    );
  }

  Color _rowBg(String type) {
    switch (type) {
      case 'DISBURSEMENT':
        return const Color(0xFFE3F2FD);
      case 'EMI_PAYMENT':
        return const Color(0xFFE8F5E9);
      case 'PREPAYMENT':
        return const Color(0xFFFFF8E1);
      case 'ACCRUAL':
        return const Color(0xFFFBE9E7);
      default:
        return Colors.white;
    }
  }

  Widget _timelineTable(TimelineView v) {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(12),
            child: Text('Timeline',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columnSpacing: 18,
              columns: const [
                DataColumn(label: Text('Date')),
                DataColumn(label: Text('Event')),
                DataColumn(label: Text('Amount')),
                DataColumn(label: Text('Days')),
                DataColumn(label: Text('Interest')),
                DataColumn(label: Text('Principal')),
                DataColumn(label: Text('Outstanding')),
                DataColumn(label: Text('Total Owed')),
              ],
              rows: v.timeline.map((r) {
                return DataRow(
                  color: WidgetStateProperty.all(_rowBg(r.eventType)),
                  cells: [
                    DataCell(Text(r.date)),
                    DataCell(Text(eventLabel(r.eventType))),
                    DataCell(Text(r.amount == 0 ? '-' : inr(r.amount))),
                    DataCell(Text('${r.days}')),
                    DataCell(Text(r.eventType == 'EMI_PAYMENT'
                        ? inr(r.interestPaid)
                        : inr(r.periodInterest))),
                    DataCell(Text(r.principalPaid == 0
                        ? '-'
                        : inr(r.principalPaid))),
                    DataCell(Text(inr(r.outstandingPrincipal))),
                    DataCell(Text(inr(r.totalOutstanding))),
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

class _TxInput {
  final double amount;
  final String date;
  _TxInput(this.amount, this.date);
}

class _AddTransactionSheet extends StatefulWidget {
  final String kind;
  const _AddTransactionSheet({required this.kind});

  @override
  State<_AddTransactionSheet> createState() => _AddTransactionSheetState();
}

class _AddTransactionSheetState extends State<_AddTransactionSheet> {
  final _amount = TextEditingController();
  DateTime _date = DateTime.now();

  String get _title {
    switch (widget.kind) {
      case 'disbursement':
        return 'Add Disbursement';
      case 'emi':
        return 'Record EMI Payment';
      case 'prepayment':
        return 'Add Prepayment';
      default:
        return 'Add';
    }
  }

  String _fmt(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  void dispose() {
    _amount.dispose();
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
              Navigator.pop(context, _TxInput(amt, _fmt(_date)));
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
