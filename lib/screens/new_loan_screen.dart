import 'package:flutter/material.dart';

import '../loan_engine.dart';
import '../supabase_service.dart';
import '../utils.dart';

class NewLoanScreen extends StatefulWidget {
  const NewLoanScreen({super.key});

  @override
  State<NewLoanScreen> createState() => _NewLoanScreenState();
}

class _NewLoanScreenState extends State<NewLoanScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _sanctioned = TextEditingController();
  final _rate = TextEditingController();
  final _years = TextEditingController();
  final _emiDay = TextEditingController(text: '5');
  final _firstDisb = TextEditingController();
  DateTime _startDate = DateTime.now();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_name, _sanctioned, _rate, _years, _emiDay, _firstDisb]) {
      c.dispose();
    }
    super.dispose();
  }

  String _fmt(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  double? get _previewEmi {
    final s = double.tryParse(_sanctioned.text);
    final r = double.tryParse(_rate.text);
    final y = double.tryParse(_years.text);
    if (s == null || r == null || y == null || y <= 0) return null;
    return round2(calculateEmi(s, r, y));
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final sanctioned = double.parse(_sanctioned.text);
      final firstDisb = _firstDisb.text.trim().isEmpty
          ? sanctioned
          : double.parse(_firstDisb.text);
      if (firstDisb < 0 || firstDisb > sanctioned) {
        throw 'First disbursement must be between 0 and the sanctioned amount.';
      }
      await SupabaseService.createLoan(
        loanName: _name.text.trim(),
        sanctionedAmount: sanctioned,
        rate: double.parse(_rate.text),
        years: double.parse(_years.text),
        startDate: _fmt(_startDate),
        emiDay: int.tryParse(_emiDay.text) ?? 5,
        firstDisbursementAmount: firstDisb,
        firstDisbursementDate: _fmt(_startDate),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final emi = _previewEmi;
    return Scaffold(
      appBar: AppBar(
        title: const Text('New Loan'),
        backgroundColor: const Color(0xFF1976d2),
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _field(_name, 'Loan name', TextInputType.text),
            _field(_sanctioned, 'Sanctioned amount (₹)', TextInputType.number,
                onChanged: (_) => setState(() {})),
            _field(_rate, 'Interest rate (% p.a.)', TextInputType.number,
                onChanged: (_) => setState(() {})),
            _field(_years, 'Tenure (years)', TextInputType.number,
                helper: 'Enter tenure in years',
                onChanged: (_) => setState(() {})),
            _field(_emiDay, 'EMI due day (1-28)', TextInputType.number),
            _field(_firstDisb, 'First disbursement (₹, optional)',
                TextInputType.number,
                required: false,
                helper: 'Defaults to full sanctioned amount'),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Start date'),
              subtitle: Text(_fmt(_startDate)),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _startDate,
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2100),
                );
                if (picked != null) setState(() => _startDate = picked);
              },
            ),
            if (emi != null)
              Card(
                color: const Color(0xFFE3F2FD),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Calculated monthly EMI'),
                      Text(inr(emi),
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 18)),
                    ],
                  ),
                ),
              ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _busy ? null : _save,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: _busy
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Create loan'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(TextEditingController c, String label, TextInputType type,
      {bool required = true,
      String? helper,
      void Function(String)? onChanged}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: c,
        keyboardType: type,
        onChanged: onChanged,
        decoration: InputDecoration(
          labelText: label,
          helperText: helper,
          border: const OutlineInputBorder(),
        ),
        validator: (v) {
          if (!required) return null;
          if (v == null || v.trim().isEmpty) return 'Required';
          if (type == TextInputType.number && double.tryParse(v) == null) {
            return 'Enter a number';
          }
          return null;
        },
      ),
    );
  }
}
