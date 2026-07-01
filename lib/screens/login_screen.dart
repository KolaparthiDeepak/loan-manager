import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../supabase_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _username = TextEditingController();
  final _password = TextEditingController();
  bool _isRegister = false;
  bool _busy = false;
  String? _error;
  String? _info;

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  bool _validUsername(String s) => RegExp(r'^[a-zA-Z0-9._]{3,30}$').hasMatch(s);

  String _friendly(AuthException e) {
    final m = e.message.toLowerCase();
    if (m.contains('already') && m.contains('registered')) {
      return 'That username is taken — try signing in instead.';
    }
    if (m.contains('invalid login credentials')) {
      return 'Incorrect username or password.';
    }
    if (m.contains('email not confirmed')) {
      return 'This account needs confirmation. Ask the admin to enable it.';
    }
    if (m.contains('signup') && m.contains('disabled')) {
      return 'New sign-ups are disabled for this app.';
    }
    if (m.contains('rate limit')) {
      return 'Too many attempts. Please wait a minute and try again.';
    }
    if (m.contains('password') && m.contains('6')) {
      return 'Password must be at least 6 characters.';
    }
    return e.message;
  }

  Future<void> _submit() async {
    final username = _username.text.trim();
    final pass = _password.text;
    if (!_validUsername(username)) {
      setState(() => _error =
          'Username must be 3–30 characters (letters, numbers, . or _).');
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
        final res = await SupabaseService.signUp(username, pass);
        if (res.session == null && mounted) {
          setState(() {
            _isRegister = false;
            _info = 'Account created. You can sign in now.';
          });
        }
        // If a session exists, AuthGate switches to the dashboard automatically.
      } else {
        await SupabaseService.signIn(username, pass);
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
                  controller: _username,
                  keyboardType: TextInputType.text,
                  autocorrect: false,
                  enableSuggestions: false,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                      labelText: 'Username',
                      prefixIcon: Icon(Icons.person_outline),
                      border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _password,
                  obscureText: true,
                  onSubmitted: (_) => _busy ? null : _submit(),
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
