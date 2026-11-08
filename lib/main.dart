import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config.dart';
import 'screens/dashboard_screen.dart';
import 'screens/login_screen.dart';
import 'theme_controller.dart';
import 'widgets/glass.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ThemeController.init();
  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    anonKey: AppConfig.supabaseAnonKey,
  );
  runApp(const LoanApp());
}

class LoanApp extends StatelessWidget {
  const LoanApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: ThemeController.version,
      builder: (context, _, __) {
        SystemChrome.setSystemUIOverlayStyle(
          (Palette.isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark)
              .copyWith(statusBarColor: Colors.transparent),
        );
        return MaterialApp(
          title: 'Loan Manager',
          debugShowCheckedModeBanner: false,
          theme: buildGlassTheme(),
          home: const AuthGate(),
        );
      },
    );
  }
}

/// Shows Login when signed out, Dashboard when signed in. Reacts to auth changes.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final session = Supabase.instance.client.auth.currentSession;
        if (session == null) return const LoginScreen();
        return const DashboardScreen();
      },
    );
  }
}
