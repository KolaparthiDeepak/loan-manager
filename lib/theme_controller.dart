import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'widgets/glass.dart';

/// App-wide appearance settings: Light / Dark / System, and "hide amounts".
/// Colours are read through [Palette] getters, so switching the theme only
/// needs a rebuild of the widget tree (state such as the open tab is kept).
class ThemeController with WidgetsBindingObserver {
  ThemeController._();
  static final _self = ThemeController._();

  static final mode = ValueNotifier<ThemeMode>(ThemeMode.system);
  static final hideAmounts = ValueNotifier<bool>(false);

  /// Bumped on every theme change; MaterialApp listens to it.
  static final version = ValueNotifier<int>(0);

  static SharedPreferences? _prefs;

  static Future<void> init() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      final m = _prefs?.getString('theme_mode');
      mode.value = ThemeMode.values.firstWhere(
        (e) => e.name == m,
        orElse: () => ThemeMode.system,
      );
      hideAmounts.value = _prefs?.getBool('hide_amounts') ?? false;
    } catch (_) {
      // Preferences unavailable: fall back to defaults.
    }
    _apply();
    WidgetsBinding.instance.addObserver(_self);
  }

  static void _apply() {
    final platformDark =
        WidgetsBinding.instance.platformDispatcher.platformBrightness ==
            Brightness.dark;
    Palette.isDark =
        mode.value == ThemeMode.dark || (mode.value == ThemeMode.system && platformDark);
  }

  static Future<void> setMode(ThemeMode m) async {
    mode.value = m;
    try {
      await _prefs?.setString('theme_mode', m.name);
    } catch (_) {}
    _refresh();
  }

  static Future<void> setHideAmounts(bool v) async {
    hideAmounts.value = v;
    try {
      await _prefs?.setBool('hide_amounts', v);
    } catch (_) {}
  }

  static void _refresh() {
    _apply();
    version.value++;
    _rebuild(WidgetsBinding.instance.rootElement);
  }

  static void _rebuild(Element? e) {
    if (e == null) return;
    e.markNeedsBuild();
    e.visitChildren(_rebuild);
  }

  @override
  void didChangePlatformBrightness() {
    if (mode.value == ThemeMode.system) _refresh();
  }
}

/// Masks an amount when "hide amounts" is on. Screens that call this must
/// listen to [ThemeController.hideAmounts] so they redraw when it changes.
String hideAmt(String value) =>
    ThemeController.hideAmounts.value ? '₹ ••••••' : value;
