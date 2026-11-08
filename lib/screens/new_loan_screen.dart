import 'package:flutter/material.dart';

import '../loan_engine.dart';
import '../supabase_service.dart';
import '../utils.dart';
import '../widgets/glass.dart';

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
    return GlassScaffold(
      title: 'New Loan',
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 40),
          children: [
            GlassCard(
              blur: 14,
              radius: 28,
              padding: const EdgeInsets.fromLTRB(18, 20, 18, 8),
              child: Column(
                children: [
                  _field(_name, 'Loan name', TextInputType.text,
                      icon: Icons.label_outline_rounded),
                  _field(_sanctioned, 'Sanctioned amount (₹)', TextInputType.number,
                      icon: Icons.currency_rupee_rounded,
                      onChanged: (_) => setState(() {})),
                  _field(_rate, 'Interest rate (% p.a.)', TextInputType.number,
                      icon: Icons.percent_rounded,
                      onChanged: (_) => setState(() {})),
                  _field(_years, 'Tenure (years)', TextInputType.number,
                      icon: Icons.timelapse_rounded,
                      helper: 'Enter tenure in years',
                      onChanged: (_) => setState(() {})),
                  _field(_emiDay, 'EMI due day (1-28)', TextInputType.number,
                      icon: Icons.event_repeat_rounded),
                  _field(_firstDisb, 'First disbursement (₹, optional)',
                      TextInputType.number,
                      icon: Icons.account_balance_wallet_outlined,
                      required: false,
                      helper: 'Defaults to full sanctioned amount'),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _startDate,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) setState(() => _startDate = picked);
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Start date',
                          prefixIcon: Icon(Icons.calendar_today_rounded),
                        ),
                        child: Text(_fmt(_startDate),
                            style: const TextStyle(fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (emi != null) ...[
              const SizedBox(height: 14),
              GradientKpi(
                label: 'Calculated monthly EMI',
                value: inr(emi),
                icon: Icons.calculate_rounded,
                colors: const [Palette.indigo, Palette.violet],
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: Palette.rose)),
            ],
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _busy ? null : _save,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: _busy
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
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
      IconData? icon,
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
          prefixIcon: icon == null ? null : Icon(icon),
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
