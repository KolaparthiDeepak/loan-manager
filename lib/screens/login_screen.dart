import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../supabase_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _isRegister = false;
  bool _busy = false;
  String? _error;
  String? _info;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  bool _looksLikeEmail(String s) {
    final r = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    return r.hasMatch(s);
  }

  String _friendly(AuthException e) {
    final m = e.message.toLowerCase();
    if (m.contains('email') && m.contains('invalid')) {
      return 'That email is not accepted. Use a real address like name@gmail.com.';
    }
    if (m.contains('already') && m.contains('registered')) {
      return 'An account with this email already exists — try signing in.';
    }
    if (m.contains('email not confirmed')) {
      return 'Email not confirmed yet. Check your inbox for the confirmation link.';
    }
    if (m.contains('invalid login credentials')) {
      return 'Incorrect email or password.';
    }
    if (m.contains('signup') && m.contains('disabled')) {
      return 'Sign-ups are disabled for this project.';
    }
    if (m.contains('password') && m.contains('6')) {
      return 'Password must be at least 6 characters.';
    }
    return e.message;
  }

  Future<void> _submit() async {
    final email = _email.text.trim();
    final pass = _password.text;
    if (!_looksLikeEmail(email)) {
      setState(() => _error = 'Enter a valid email address (e.g. name@gmail.com).');
      return;
    }
    if (pass.length < 6) {
      setState(() => _error = 'Password must be at least 6 characters.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _info = null;
    });
    try {
      if (_isRegister) {
        final res = await SupabaseService.signUp(email, pass);
        if (res.session == null && mounted) {
          // Email confirmation is enabled -> no session yet.
          setState(() {
            _isRegister = false;
            _info =
                'Account created. Check your email to confirm, then sign in.';
          });
        }
        // If a session exists, AuthGate switches to the dashboard automatically.
      } else {
        await SupabaseService.signIn(email, pass);
      }
    } on AuthException catch (e) {
      setState(() => _error = _friendly(e));
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(22),
                    child: Image.asset('assets/logo.png',
                        width: 96, height: 96, fit: BoxFit.cover),
                  ),
                ),
                const SizedBox(height: 16),
                Text('Loan Manager',
                    textAlign: TextAlign.center,
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(
                  _isRegister ? 'Create your account' : 'Welcome back',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.black54),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.email_outlined),
                      border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _password,
                  obscureText: true,
                  decoration: const InputDecoration(
                      labelText: 'Password',
                      prefixIcon: Icon(Icons.lock_outline),
                      border: OutlineInputBorder()),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!,
                      style: const TextStyle(color: Color(0xFFC62828))),
                ],
                if (_info != null) ...[
                  const SizedBox(height: 12),
                  Text(_info!,
                      style: const TextStyle(color: Color(0xFF2E7D32))),
                ],
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _busy ? null : _submit,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: _busy
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : Text(_isRegister ? 'Create account' : 'Sign in'),
                  ),
                ),
                TextButton(
                  onPressed: _busy
                      ? null
                      : () => setState(() {
                            _isRegister = !_isRegister;
                            _error = null;
                            _info = null;
                          }),
                  child: Text(_isRegister
                      ? 'Have an account? Sign in'
                      : 'New here? Create an account'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
