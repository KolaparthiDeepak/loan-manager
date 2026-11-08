import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Colour tokens for the glass look.
class Palette {
  /// Set by ThemeController; every screen reads colours through these getters
  /// so a theme switch only needs a rebuild.
  static bool isDark = false;

  static Color get ink => isDark ? const Color(0xFFE8EDFF) : const Color(0xFF14213D);
  static Color get inkSoft =>
      isDark ? const Color(0xFF9CA8C9) : const Color(0xFF5B6784);

  /// Frosted surface colour: white in light mode, a lifted navy in dark mode.
  static Color glass(double alpha) =>
      (isDark ? const Color(0xFF26335F) : Colors.white).withValues(alpha: alpha);

  /// Indigo that stays readable on the dark background.
  static Color get accent => isDark ? const Color(0xFF9D98FF) : const Color(0xFF4F46E5);

  static const indigo = Color(0xFF4F46E5);
  static const violet = Color(0xFF7C3AED);
  static const sky = Color(0xFF0EA5E9);
  static const teal = Color(0xFF14B8A6);
  static const green = Color(0xFF10B981);
  static const amber = Color(0xFFF59E0B);
  static const rose = Color(0xFFF43F5E);
  static const orange = Color(0xFFF97316);
  static const navy = Color(0xFF0B1B4D);
  static const blue = Color(0xFF2563EB);

  static Color get bgTop => isDark ? const Color(0xFF0A1128) : const Color(0xFFE4E9FF);
  static Color get bgMid => isDark ? const Color(0xFF111A3A) : const Color(0xFFF1ECFF);
  static Color get bgBottom =>
      isDark ? const Color(0xFF08202F) : const Color(0xFFD9F5F6);
}

ThemeData buildGlassTheme() {
  final dark = Palette.isDark;
  final scheme = ColorScheme.fromSeed(
    seedColor: Palette.indigo,
    brightness: dark ? Brightness.dark : Brightness.light,
  ).copyWith(primary: Palette.indigo, secondary: Palette.violet);
  final radius = BorderRadius.circular(16);
  OutlineInputBorder border(Color c, [double w = 1]) =>
      OutlineInputBorder(borderRadius: radius, borderSide: BorderSide(color: c, width: w));
  final base = dark ? Typography.whiteMountainView : Typography.blackMountainView;
  return ThemeData(
    useMaterial3: true,
    brightness: dark ? Brightness.dark : Brightness.light,
    colorScheme: scheme,
    scaffoldBackgroundColor: Colors.transparent,
    textTheme: base.apply(bodyColor: Palette.ink, displayColor: Palette.ink),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Palette.glass(dark ? 0.6 : 0.55),
      border: border(Palette.glass(dark ? 0.7 : 0.8)),
      enabledBorder: border(Palette.glass(dark ? 0.7 : 0.8)),
      focusedBorder: border(dark ? const Color(0xFF8B85FF) : Palette.indigo, 1.6),
      errorBorder: border(Palette.rose),
      focusedErrorBorder: border(Palette.rose, 1.6),
      labelStyle: TextStyle(color: Palette.inkSoft),
      hintStyle: TextStyle(color: Palette.inkSoft),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: Palette.indigo,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: Palette.ink,
        side: BorderSide(color: Palette.glass(dark ? 0.9 : 0.9)),
        backgroundColor: Palette.glass(0.45),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
          foregroundColor: dark ? const Color(0xFF9D98FF) : Palette.indigo),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: dark ? const Color(0xF21A2448) : Palette.glass(0.94),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: dark ? const Color(0xFF1A2448) : Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: dark ? const Color(0xFF2D3A6B) : const Color(0xFF14213D),
      contentTextStyle: const TextStyle(color: Colors.white),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    dividerTheme: DividerThemeData(color: Palette.glass(dark ? 0.5 : 0.7)),
    dataTableTheme: DataTableThemeData(
      headingTextStyle:
          TextStyle(fontWeight: FontWeight.w700, color: Palette.ink, fontSize: 13),
      dataTextStyle: TextStyle(color: Palette.ink, fontSize: 13),
    ),
  );
}
/// Soft gradient with a few blurred colour orbs; sits behind every screen.
class GlassBackground extends StatelessWidget {
  final Widget child;
  const GlassBackground({super.key, required this.child});

  Widget _orb(Color c, double size) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
              colors: [c.withValues(alpha: 0.55), c.withValues(alpha: 0)]),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Palette.bgTop, Palette.bgMid, Palette.bgBottom],
            ),
          ),
        ),
        Positioned(top: -90, left: -80, child: _orb(Palette.indigo, 320)),
        Positioned(top: 260, right: -140, child: _orb(Palette.violet, 340)),
        Positioned(bottom: -120, left: -60, child: _orb(Palette.teal, 360)),
        child,
      ],
    );
  }
}

/// Frosted-glass surface. [blur] > 0 uses a real backdrop blur (use it for hero
/// surfaces); blur 0 keeps the same look without the GPU cost, which suits
/// lists and big tables.
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final double radius;
  final double blur;
  final Color? tint;
  final Gradient? gradient;
  final VoidCallback? onTap;

  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin = EdgeInsets.zero,
    this.radius = 24,
    this.blur = 0,
    this.tint,
    this.gradient,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(radius);
    Widget body = Container(
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: r,
        gradient: gradient ??
            LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                tint?.withValues(alpha: 0.72) ?? Palette.glass(0.72),
                tint?.withValues(alpha: 0.42) ?? Palette.glass(0.42),
              ],
            ),
        border: Border.all(color: Palette.glass(0.85), width: 1.2),
      ),
      child: child,
    );
    if (blur > 0) {
      body = ClipRRect(
        borderRadius: r,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: body,
        ),
      );
    }
    body = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: r,
        boxShadow: [
          BoxShadow(
            color: Palette.indigo.withValues(alpha: 0.10),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: body,
    );
    if (onTap != null) {
      body = Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: r,
          onTap: onTap,
          child: body,
        ),
      );
    }
    return Padding(padding: margin, child: body);
  }
}

/// Screen scaffold: gradient backdrop, translucent app bar, dark status icons.
class GlassScaffold extends StatelessWidget {
  final String? title;
  final Widget? titleWidget;
  final List<Widget> actions;
  final Widget body;
  final Widget? floatingActionButton;
  final bool showBack;

  const GlassScaffold({
    super.key,
    this.title,
    this.titleWidget,
    this.actions = const [],
    required this.body,
    this.floatingActionButton,
    this.showBack = true,
  });

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop() && showBack;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: (Palette.isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark)
          .copyWith(statusBarColor: Colors.transparent),
      child: Scaffold(
        extendBodyBehindAppBar: true,
        backgroundColor: Colors.transparent,
        floatingActionButton: floatingActionButton,
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(kToolbarHeight),
          child: ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: AppBar(
                backgroundColor: Palette.glass(0.35),
                elevation: 0,
                scrolledUnderElevation: 0,
                surfaceTintColor: Colors.transparent,
                foregroundColor: Palette.ink,
                automaticallyImplyLeading: false,
                leading: canPop
                    ? IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                        onPressed: () => Navigator.maybePop(context),
                      )
                    : null,
                titleSpacing: canPop ? 0 : 20,
                title: titleWidget ??
                    Text(title ?? '',
                        style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 20,
                            letterSpacing: -0.2)),
                actions: actions,
              ),
            ),
          ),
        ),
        body: GlassBackground(
          child: SafeArea(
            bottom: false,
            // The Scaffold already pads MediaQuery by the app bar's height
            // (extendBodyBehindAppBar), so SafeArea alone clears it.
            child: body,
          ),
        ),
      ),
    );
  }
}

/// A small label + value tile with an accent bar.
class StatTile extends StatelessWidget {
  final String label;
  final String value;
  final Color accent;
  final IconData? icon;
  const StatTile({
    super.key,
    required this.label,
    required this.value,
    this.accent = Palette.indigo,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      radius: 20,
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 34,
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11.5, color: Palette.inkSoft)),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(value,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w800)),
                ),
              ],
            ),
          ),
          if (icon != null) Icon(icon, size: 18, color: accent.withValues(alpha: 0.8)),
        ],
      ),
    );
  }
}

/// Translucent pill used for the action row.
class GlassPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;
  const GlassPill({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.color = Palette.indigo,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(30),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            color: Palette.glass(0.6),
            border: Border.all(color: Palette.glass(0.9)),
            boxShadow: [
              BoxShadow(
                  color: color.withValues(alpha: 0.12),
                  blurRadius: 12,
                  offset: const Offset(0, 5)),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 6),
              Text(label,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 13.5)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Gradient KPI card (used for the headline numbers).
class GradientKpi extends StatelessWidget {
  final String label;
  final String value;
  final List<Color> colors;
  final IconData icon;
  const GradientKpi({
    super.key,
    required this.label,
    required this.value,
    required this.colors,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight, colors: colors),
        boxShadow: [
          BoxShadow(
              color: colors.last.withValues(alpha: 0.35),
              blurRadius: 22,
              offset: const Offset(0, 10)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(color: Colors.white70, fontSize: 12)),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(value,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 21,
                          fontWeight: FontWeight.w800)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Bottom sheet with a frosted, rounded surface.
Future<T?> showGlassSheet<T>(BuildContext context,
    {required WidgetBuilder builder}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Palette.ink.withValues(alpha: 0.28),
    builder: (ctx) => ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 26, sigmaY: 26),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Palette.glass(0.92),
                (Palette.isDark ? const Color(0xFF141C3C) : const Color(0xFFEFF1FF))
                    .withValues(alpha: 0.94),
              ],
            ),
            border: Border(
                top: BorderSide(color: Palette.glass(0.95), width: 1.5)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Palette.ink.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                Flexible(child: builder(ctx)),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

