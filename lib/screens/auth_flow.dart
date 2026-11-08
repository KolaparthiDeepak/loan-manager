import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../supabase_service.dart';
import '../widgets/glass.dart';

/// Turns raw Supabase / network errors into plain sentences.
String authError(Object e) {
  final raw = e is AuthException ? e.message : e.toString();
  final m = raw.toLowerCase();
  if (m.contains('already') && m.contains('registered')) {
    return 'This email is already registered. Sign in or use "Forgot password".';
  }
  if (m.contains('invalid login credentials')) {
    return 'Incorrect email/username or password.';
  }
  if (m.contains('email not confirmed')) {
    return 'Email not verified yet. Use "Create account" to get a new code.';
  }
  if (m.contains('expired') || m.contains('invalid') && m.contains('token')) {
    return 'That code is incorrect or has expired. Request a new one.';
  }
  if (m.contains('same') && m.contains('password')) {
    return 'The new password must be different from the old one.';
  }
  if (m.contains('rate limit') || m.contains('too many') || m.contains('seconds')) {
    return 'Too many attempts. Please wait a minute and try again.';
  }
  if (m.contains('signup') && m.contains('disabled')) {
    return 'New sign-ups are disabled for this app.';
  }
  if (m.contains('weak') || (m.contains('password') && m.contains('should'))) {
    return 'Choose a stronger password (8+ characters with letters and numbers).';
  }
  if (m.contains('socket') || m.contains('failed host lookup') || m.contains('network')) {
    return 'No internet connection. Check your network and retry.';
  }
  return raw.replaceFirst('AuthException(message: ', '').replaceAll(RegExp(r'[,)]\s*statusCode.*'), '');
}

/// Returns null when OK, else a message.
String? passwordProblem(String p) {
  if (p.length < 8) return 'Use at least 8 characters.';
  if (!RegExp(r'[A-Za-z]').hasMatch(p) || !RegExp(r'\d').hasMatch(p)) {
    return 'Include both letters and numbers.';
  }
  return null;
}

/// Full-screen glass layout shared by every sign-in related page.
class AuthShell extends StatelessWidget {
  final Widget child;
  final bool showBack;
  const AuthShell({super.key, required this.child, this.showBack = false});

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: (Palette.isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark)
          .copyWith(statusBarColor: Colors.transparent),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: GlassBackground(
          child: SafeArea(
            child: Stack(
              children: [
                Center(
                  child: SingleChildScrollView(
                    keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.fromLTRB(22, 56, 22, 28),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 440),
                      child: child,
                    ),
                  ),
                ),
                if (showBack)
                  Positioned(
                    top: 6,
                    left: 8,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                      onPressed: () => Navigator.maybePop(context),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AuthBadge extends StatelessWidget {
  final IconData icon;
  const AuthBadge({super.key, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Palette.indigo, Palette.violet],
          ),
          boxShadow: [
            BoxShadow(
                color: Palette.indigo.withValues(alpha: 0.35),
                blurRadius: 28,
                offset: const Offset(0, 12)),
          ],
        ),
        child: Icon(icon, color: Colors.white, size: 38),
      ),
    );
  }
}

/// Password input with show/hide and an optional strength bar.
class PasswordField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final bool showStrength;
  final TextInputAction action;
  final VoidCallback? onSubmitted;
  final ValueChanged<String>? onChanged;
  const PasswordField({
    super.key,
    required this.controller,
    this.label = 'Password',
    this.showStrength = false,
    this.action = TextInputAction.next,
    this.onSubmitted,
    this.onChanged,
  });

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _show = false;

  double _score(String p) {
    var s = 0.0;
    if (p.length >= 8) s += 0.34;
    if (RegExp(r'[A-Za-z]').hasMatch(p) && RegExp(r'\d').hasMatch(p)) s += 0.33;
    if (p.length >= 12 || RegExp(r'[^A-Za-z0-9]').hasMatch(p)) s += 0.33;
    return s;
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.controller.text;
    final score = _score(p);
    final color = score < 0.4
        ? Palette.rose
        : score < 0.7
            ? Palette.amber
            : Palette.green;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: widget.controller,
          obscureText: !_show,
          textInputAction: widget.action,
          autocorrect: false,
          enableSuggestions: false,
          onChanged: (v) {
            setState(() {});
            widget.onChanged?.call(v);
          },
          onSubmitted: (_) => widget.onSubmitted?.call(),
          decoration: InputDecoration(
            labelText: widget.label,
            prefixIcon: const Icon(Icons.lock_outline_rounded),
            suffixIcon: IconButton(
              icon: Icon(_show
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined),
              onPressed: () => setState(() => _show = !_show),
            ),
          ),
        ),
        if (widget.showStrength && p.isNotEmpty) ...[
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: score.clamp(0.08, 1.0),
              minHeight: 5,
              backgroundColor: Palette.ink.withValues(alpha: 0.08),
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
          const SizedBox(height: 4),
          Text(
              score < 0.4
                  ? 'Weak'
                  : score < 0.7
                      ? 'Okay'
                      : 'Strong',
              style: TextStyle(fontSize: 11.5, color: color, fontWeight: FontWeight.w700)),
        ],
      ],
    );
  }
}

class BusyButton extends StatelessWidget {
  final bool busy;
  final String label;
  final VoidCallback? onPressed;
  const BusyButton(
      {super.key, required this.busy, required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: busy ? null : onPressed,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: busy
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : Text(label),
      ),
    );
  }
}

class MessageLine extends StatelessWidget {
  final String? error;
  final String? info;
  const MessageLine({super.key, this.error, this.info});

  @override
  Widget build(BuildContext context) {
    if (error == null && info == null) return const SizedBox.shrink();
    final isErr = error != null;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: (isErr ? Palette.rose : Palette.green).withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(isErr ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
                size: 18, color: isErr ? Palette.rose : Palette.green),
            const SizedBox(width: 8),
            Expanded(
              child: Text(error ?? info!,
                  style: TextStyle(
                      fontSize: 13,
                      color: isErr ? Palette.rose : const Color(0xFF047857))),
            ),
          ],
        ),
      ),
    );
  }
}

enum OtpMode { signup, recovery, emailLink }

/// Enter the 6-digit code e-mailed by Supabase.
/// recovery mode also collects the new password on the same page.
class OtpScreen extends StatefulWidget {
  final String email;
  final OtpMode mode;
  const OtpScreen({super.key, required this.email, required this.mode});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final _code = TextEditingController();
  final _pass = TextEditingController();
  final _pass2 = TextEditingController();
  bool _busy = false;
  String? _error;
  String? _info;
  int _cool = 30;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startCooldown();
  }

  void _startCooldown() {
    _timer?.cancel();
    setState(() => _cool = 30);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_cool <= 1) {
        t.cancel();
      }
      if (mounted) setState(() => _cool = _cool > 0 ? _cool - 1 : 0);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _code.dispose();
    _pass.dispose();
    _pass2.dispose();
    super.dispose();
  }

  String get _title => switch (widget.mode) {
        OtpMode.signup => 'Verify your email',
        OtpMode.recovery => 'Reset password',
        OtpMode.emailLink => 'Confirm your email',
      };

  Future<void> _submit() async {
    final code = _code.text.trim();
    if (code.length < 6) {
      setState(() => _error = 'Enter the 6-digit code from your email.');
      return;
    }
    if (widget.mode == OtpMode.recovery) {
      final p = passwordProblem(_pass.text);
      if (p != null) {
        setState(() => _error = p);
        return;
      }
      if (_pass.text != _pass2.text) {
        setState(() => _error = 'The two passwords do not match.');
        return;
      }
    }
    setState(() {
      _busy = true;
      _error = null;
      _info = null;
    });
    try {
      switch (widget.mode) {
        case OtpMode.signup:
          await SupabaseService.verifySignUpOtp(widget.email, code);
        case OtpMode.recovery:
          await SupabaseService.resetPasswordWithOtp(widget.email, code, _pass.text);
        case OtpMode.emailLink:
          await SupabaseService.confirmEmailLink(widget.email, code);
      }
      if (!mounted) return;
      final nav = Navigator.of(context);
      final msg = widget.mode == OtpMode.recovery
          ? 'Password updated. You are signed in.'
          : widget.mode == OtpMode.signup
              ? 'Email verified. Welcome!'
              : 'Email verified and linked to your account.';
      nav.popUntil((r) => r.isFirst);
      ScaffoldMessenger.maybeOf(nav.context)
          ?.showSnackBar(SnackBar(content: Text(msg)));
    } catch (e) {
      if (mounted) setState(() => _error = authError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resend() async {
    setState(() {
      _error = null;
      _info = null;
    });
    try {
      switch (widget.mode) {
        case OtpMode.signup:
          await SupabaseService.resendSignUpOtp(widget.email);
        case OtpMode.recovery:
          await SupabaseService.sendResetOtp(widget.email);
        case OtpMode.emailLink:
          await SupabaseService.startEmailLink(widget.email);
      }
      if (mounted) {
        setState(() => _info = 'A new code is on its way.');
        _startCooldown();
      }
    } catch (e) {
      if (mounted) setState(() => _error = authError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthShell(
      showBack: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AuthBadge(icon: Icons.mark_email_read_rounded),
          const SizedBox(height: 18),
          Text(_title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
          const SizedBox(height: 6),
          Text('We sent a code to\n${widget.email}',
              textAlign: TextAlign.center,
              style: TextStyle(color: Palette.inkSoft, height: 1.4)),
          const SizedBox(height: 22),
          GlassCard(
            blur: 20,
            radius: 30,
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _code,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  maxLength: 8,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: const TextStyle(
                      fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: 10),
                  decoration: const InputDecoration(
                      counterText: '', hintText: '••••••'),
                  onSubmitted: (_) =>
                      widget.mode == OtpMode.recovery ? null : _submit(),
                ),
                if (widget.mode == OtpMode.recovery) ...[
                  const SizedBox(height: 14),
                  PasswordField(
                      controller: _pass, label: 'New password', showStrength: true),
                  const SizedBox(height: 12),
                  PasswordField(
                    controller: _pass2,
                    label: 'Confirm new password',
                    action: TextInputAction.done,
                    onSubmitted: _busy ? null : _submit,
                  ),
                ],
                MessageLine(error: _error, info: _info),
                const SizedBox(height: 18),
                BusyButton(
                    busy: _busy,
                    label: widget.mode == OtpMode.recovery
                        ? 'Update password'
                        : 'Verify',
                    onPressed: _submit),
                const SizedBox(height: 6),
                TextButton(
                  onPressed: _cool > 0 ? null : _resend,
                  child: Text(_cool > 0 ? 'Resend code in ${_cool}s' : 'Resend code'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Check your spam folder if it does not arrive within a minute.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Palette.inkSoft),
          ),
        ],
      ),
    );
  }
}

/// Step 1 of "Forgot password": ask for the email, send the code.
class ForgotPasswordScreen extends StatefulWidget {
  final String initialEmail;
  const ForgotPasswordScreen({super.key, this.initialEmail = ''});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  late final _email = TextEditingController(text: widget.initialEmail);
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final email = _email.text.trim().toLowerCase();
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      setState(() => _error = 'Enter the email address of your account.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await SupabaseService.sendResetOtp(email);
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => OtpScreen(email: email, mode: OtpMode.recovery)),
      );
    } catch (e) {
      if (mounted) setState(() => _error = authError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthShell(
      showBack: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AuthBadge(icon: Icons.lock_reset_rounded),
          const SizedBox(height: 18),
          const Text('Forgot password?',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
          const SizedBox(height: 6),
          Text('We will email you a code to set a new one.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Palette.inkSoft)),
          const SizedBox(height: 22),
          GlassCard(
            blur: 20,
            radius: 30,
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _busy ? null : _send(),
                  decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.alternate_email_rounded)),
                ),
                MessageLine(error: _error),
                const SizedBox(height: 18),
                BusyButton(busy: _busy, label: 'Send code', onPressed: _send),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> showDisplayNameSheet(BuildContext c) =>
    showGlassSheet<void>(c, builder: (_) => const _DisplayNameSheet());
Future<void> showChangePasswordSheet(BuildContext c) =>
    showGlassSheet<void>(c, builder: (_) => const _ChangePasswordSheet());
Future<void> showLinkEmailSheet(BuildContext c) =>
    showGlassSheet<void>(c, builder: (_) => const _LinkEmailSheet());

/// Opens the "Account" sheet: who is signed in, verify email, change password.
Future<void> showAccountSheet(BuildContext context) {
  return showGlassSheet<void>(
    context,
    builder: (ctx) => const _AccountSheet(),
  );
}

class _AccountSheet extends StatelessWidget {
  const _AccountSheet();

  @override
  Widget build(BuildContext context) {
    final user = SupabaseService.currentUser;
    final needsEmail = SupabaseService.needsRealEmail;
    final shown = SupabaseService.displayName;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: Palette.indigo,
                child: Text(
                    shown.isEmpty ? '?' : shown.characters.first.toUpperCase(),
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(shown,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w800)),
                    if (!needsEmail)
                      Text(user?.email ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 12.5, color: Palette.inkSoft)),
                    const SizedBox(height: 2),
                    Text(needsEmail ? 'Email not verified' : 'Email verified',
                        style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: needsEmail ? Palette.amber : Palette.green)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (needsEmail)
            _tile(context, Icons.mark_email_unread_rounded, 'Verify your email',
                'Needed for password reset codes', Palette.amber, () {
              Navigator.pop(context);
              showGlassSheet<void>(context,
                  builder: (_) => const _LinkEmailSheet());
            }),
          _tile(context, Icons.badge_rounded, 'Display name',
              'Currently: $shown', Palette.violet, () {
            Navigator.pop(context);
            showGlassSheet<void>(context,
                builder: (_) => const _DisplayNameSheet());
          }),
          _tile(context, Icons.key_rounded, 'Change password',
              'Update your sign-in password', Palette.indigo, () {
            Navigator.pop(context);
            showGlassSheet<void>(context,
                builder: (_) => const _ChangePasswordSheet());
          }),
          _tile(context, Icons.logout_rounded, 'Sign out', 'Leave this device',
              Palette.rose, () {
            Navigator.pop(context);
            SupabaseService.signOut();
          }),
        ],
      ),
    );
  }

  Widget _tile(BuildContext context, IconData icon, String title, String sub,
      Color color, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassCard(
        radius: 20,
        onTap: onTap,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 15)),
                  Text(sub,
                      style: TextStyle(fontSize: 12, color: Palette.inkSoft)),
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

class _DisplayNameSheet extends StatefulWidget {
  const _DisplayNameSheet();

  @override
  State<_DisplayNameSheet> createState() => _DisplayNameSheetState();
}

class _DisplayNameSheetState extends State<_DisplayNameSheet> {
  late final _name = TextEditingController(text: SupabaseService.displayName);
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final v = _name.text.trim();
    if (v.length < 2) {
      setState(() => _error = 'Enter at least 2 characters.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await SupabaseService.updateDisplayName(v);
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context);
      messenger.showSnackBar(const SnackBar(content: Text('Display name updated.')));
    } catch (e) {
      if (mounted) setState(() => _error = authError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 14, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Display name',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
            const SizedBox(height: 14),
            TextField(
              controller: _name,
              autofocus: true,
              maxLength: 40,
              textCapitalization: TextCapitalization.words,
              onSubmitted: (_) => _busy ? null : _save(),
              decoration: const InputDecoration(
                  labelText: 'Your name',
                  counterText: '',
                  prefixIcon: Icon(Icons.badge_outlined)),
            ),
            MessageLine(error: _error),
            const SizedBox(height: 16),
            BusyButton(busy: _busy, label: 'Save', onPressed: _save),
          ],
        ),
      ),
    );
  }
}

class _ChangePasswordSheet extends StatefulWidget {
  const _ChangePasswordSheet();

  @override
  State<_ChangePasswordSheet> createState() => _ChangePasswordSheetState();
}

class _ChangePasswordSheetState extends State<_ChangePasswordSheet> {
  final _cur = TextEditingController();
  final _new = TextEditingController();
  final _new2 = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _cur.dispose();
    _new.dispose();
    _new2.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_cur.text.isEmpty) {
      setState(() => _error = 'Enter your current password.');
      return;
    }
    final p = passwordProblem(_new.text);
    if (p != null) {
      setState(() => _error = p);
      return;
    }
    if (_new.text != _new2.text) {
      setState(() => _error = 'The two new passwords do not match.');
      return;
    }
    if (_new.text == _cur.text) {
      setState(() => _error = 'The new password must be different.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await SupabaseService.changePassword(_cur.text, _new.text);
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context);
      messenger.showSnackBar(const SnackBar(content: Text('Password changed.')));
    } catch (e) {
      if (mounted) setState(() => _error = authError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 14, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Change password',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
            const SizedBox(height: 14),
            PasswordField(controller: _cur, label: 'Current password'),
            const SizedBox(height: 12),
            PasswordField(
                controller: _new, label: 'New password', showStrength: true),
            const SizedBox(height: 12),
            PasswordField(
              controller: _new2,
              label: 'Confirm new password',
              action: TextInputAction.done,
              onSubmitted: _busy ? null : _save,
            ),
            MessageLine(error: _error),
            const SizedBox(height: 16),
            BusyButton(busy: _busy, label: 'Update password', onPressed: _save),
          ],
        ),
      ),
    );
  }
}

class _LinkEmailSheet extends StatefulWidget {
  const _LinkEmailSheet();

  @override
  State<_LinkEmailSheet> createState() => _LinkEmailSheetState();
}

class _LinkEmailSheetState extends State<_LinkEmailSheet> {
  final _email = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final email = _email.text.trim().toLowerCase();
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      setState(() => _error = 'Enter a valid email address.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await SupabaseService.startEmailLink(email);
      if (!mounted) return;
      final nav = Navigator.of(context);
      nav.pop();
      nav.push(MaterialPageRoute(
          builder: (_) => OtpScreen(email: email, mode: OtpMode.emailLink)));
    } catch (e) {
      if (mounted) setState(() => _error = authError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 14, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Verify your email',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            Text(
                'Your account was created with a username. Add your email so '
                'you can reset your password and sign in with it. Your loans '
                'stay exactly as they are.',
                style: TextStyle(color: Palette.inkSoft, height: 1.4)),
            const SizedBox(height: 14),
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.alternate_email_rounded)),
            ),
            MessageLine(error: _error),
            const SizedBox(height: 16),
            BusyButton(busy: _busy, label: 'Send code', onPressed: _send),
          ],
        ),
      ),
    );
  }
}
