import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../supabase_service.dart';
import '../widgets/glass.dart';
import 'auth_flow.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _id = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _name = TextEditingController();
  bool _register = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _id.dispose();
    _password.dispose();
    _confirm.dispose();
    _name.dispose();
    super.dispose();
  }

  void _switch(bool register) => setState(() {
        _register = register;
        _error = null;
      });

  Future<void> _submit() async {
    final id = _id.text.trim();
    final pass = _password.text;
    if (id.isEmpty) {
      setState(() => _error =
          _register ? 'Enter your email address.' : 'Enter your email or username.');
      return;
    }
    if (_register) {
      if (_name.text.trim().length < 2) {
        setState(() => _error = 'Enter your name (at least 2 characters).');
        return;
      }
      if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(id)) {
        setState(() => _error = 'Enter a valid email address.');
        return;
      }
      final p = passwordProblem(pass);
      if (p != null) {
        setState(() => _error = p);
        return;
      }
      if (pass != _confirm.text) {
        setState(() => _error = 'The two passwords do not match.');
        return;
      }
    } else if (pass.isEmpty) {
      setState(() => _error = 'Enter your password.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_register) {
        await SupabaseService.signUp(id, pass, displayName: _name.text);
        if (!mounted) return;
        await Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) =>
                  OtpScreen(email: id.toLowerCase(), mode: OtpMode.signup)),
        );
      } else {
        await SupabaseService.signIn(id, pass);
      }
    } on AuthException catch (e) {
      setState(() => _error = authError(e));
    } catch (e) {
      setState(() => _error = authError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _feature(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Palette.glass(0.55),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Palette.glass(0.9)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: Palette.indigo),
          const SizedBox(width: 6),
          Text(text,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AuthShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: Palette.indigo.withValues(alpha: 0.4),
                    blurRadius: 34,
                    offset: const Offset(0, 16),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(30),
                child: Image.asset('assets/logo.png',
                    width: 96, height: 96, fit: BoxFit.cover),
              ),
            ),
          ),
          const SizedBox(height: 22),
          ShaderMask(
            shaderCallback: (r) => const LinearGradient(
                colors: [Palette.indigo, Palette.violet]).createShader(r),
            child: const Text('Loan Manager',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1)),
          ),
          const SizedBox(height: 6),
          Text('See exactly where every rupee goes.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Palette.inkSoft, fontSize: 14.5)),
          const SizedBox(height: 14),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              _feature(Icons.calculate_rounded, 'Daily interest'),
              _feature(Icons.trending_up_rounded, 'Rate changes'),
              _feature(Icons.lock_rounded, 'Secure'),
            ],
          ),
          const SizedBox(height: 24),
          GlassCard(
            blur: 22,
            radius: 32,
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Palette.ink.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      _tab('Sign in', !_register, () => _switch(false)),
                      _tab('Create account', _register, () => _switch(true)),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                if (_register) ...[
                  TextField(
                    controller: _name,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    maxLength: 40,
                    decoration: const InputDecoration(
                        labelText: 'Your name',
                        counterText: '',
                        prefixIcon: Icon(Icons.badge_outlined)),
                  ),
                  const SizedBox(height: 12),
                ],
                TextField(
                  controller: _id,
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  enableSuggestions: false,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: _register ? 'Email' : 'Email or username',
                    prefixIcon: Icon(_register
                        ? Icons.alternate_email_rounded
                        : Icons.person_outline_rounded),
                  ),
                ),
                const SizedBox(height: 12),
                PasswordField(
                  controller: _password,
                  showStrength: _register,
                  action: _register ? TextInputAction.next : TextInputAction.done,
                  onSubmitted: _register || _busy ? null : _submit,
                ),
                if (_register) ...[
                  const SizedBox(height: 12),
                  PasswordField(
                    controller: _confirm,
                    label: 'Confirm password',
                    action: TextInputAction.done,
                    onSubmitted: _busy ? null : _submit,
                  ),
                ],
                MessageLine(error: _error),
                const SizedBox(height: 18),
                BusyButton(
                    busy: _busy,
                    label: _register ? 'Send verification code' : 'Sign in',
                    onPressed: _submit),
                if (!_register)
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => ForgotPasswordScreen(
                                      initialEmail: _id.text.contains('@')
                                          ? _id.text.trim()
                                          : '')),
                            ),
                    child: const Text('Forgot password?'),
                  )
                else
                  Padding(
                    padding: EdgeInsets.only(top: 10),
                    child: Text(
                      'We will email you a 6-digit code to verify your address.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: Palette.inkSoft),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tab(String label, bool selected, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: _busy ? null : onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            gradient: selected
                ? const LinearGradient(colors: [Palette.indigo, Palette.violet])
                : null,
            borderRadius: BorderRadius.circular(13),
            boxShadow: selected
                ? [
                    BoxShadow(
                        color: Palette.indigo.withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 5))
                  ]
                : null,
          ),
          child: Text(label,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  color: selected ? Colors.white : Palette.inkSoft)),
        ),
      ),
    );
  }
}
