import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'glass.dart';

/// Circular progress ring with a centred label.
class RingProgress extends StatelessWidget {
  final double value; // 0..1
  final double size;
  final double stroke;
  final String label;
  final Color track;
  final Color color;
  final TextStyle? labelStyle;
  const RingProgress({
    super.key,
    required this.value,
    this.size = 72,
    this.stroke = 8,
    required this.label,
    this.track = const Color(0x33FFFFFF),
    this.color = const Color(0xFF6EE7B7),
    this.labelStyle,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size.square(size),
            painter: _RingPainter(value.clamp(0.0, 1.0), stroke, track, color),
          ),
          Text(label,
              style: labelStyle ??
                  const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 15)),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double v;
  final double stroke;
  final Color track;
  final Color color;
  _RingPainter(this.v, this.stroke, this.track, this.color);

  @override
  void paint(Canvas canvas, Size s) {
    final rect = Rect.fromLTWH(stroke / 2, stroke / 2, s.width - stroke, s.height - stroke);
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = track;
    canvas.drawArc(rect, 0, math.pi * 2, false, base);
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = color;
    canvas.drawArc(rect, -math.pi / 2, math.pi * 2 * v, false, arc);
  }

  @override
  bool shouldRepaint(_RingPainter o) =>
      o.v != v || o.stroke != stroke || o.color != color || o.track != track;
}

/// Deep-blue gradient card with soft decorative circles (the "hero").
class HeroCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final List<Color> colors;
  const HeroCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.colors = const [Color(0xFF0B1B4D), Color(0xFF1D4ED8), Color(0xFF6D28D9)],
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight, colors: colors),
        boxShadow: [
          BoxShadow(
              color: colors[1].withValues(alpha: 0.38),
              blurRadius: 30,
              offset: const Offset(0, 16)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: Stack(
          children: [
            Positioned(
              right: -40,
              top: -50,
              child: _circle(170, 0.10),
            ),
            Positioned(
              left: -60,
              bottom: -90,
              child: _circle(210, 0.07),
            ),
            Padding(padding: padding, child: child),
          ],
        ),
      ),
    );
  }

  Widget _circle(double d, double a) => Container(
        width: d,
        height: d,
        decoration: BoxDecoration(
            shape: BoxShape.circle, color: Colors.white.withValues(alpha: a)),
      );
}

class SectionHeader extends StatelessWidget {
  final String title;
  final String? action;
  final VoidCallback? onAction;
  const SectionHeader(this.title, {super.key, this.action, this.onAction});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 18, 4, 10),
      child: Row(
        children: [
          Expanded(
            child: Text(title,
                style: const TextStyle(
                    fontSize: 17, fontWeight: FontWeight.w900, letterSpacing: -0.2)),
          ),
          if (action != null)
            GestureDetector(
              onTap: onAction,
              child: Text('$action →',
                  style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: Palette.accent)),
            ),
        ],
      ),
    );
  }
}

/// Small coloured status pill ("Due in 5 days", "Active").
class StatusChip extends StatelessWidget {
  final String text;
  final Color color;
  const StatusChip(this.text, {super.key, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(text,
          style: TextStyle(
              fontSize: 11.5, fontWeight: FontWeight.w800, color: color)),
    );
  }
}

/// Round avatar with initials, deterministic colour per name.
class InitialsAvatar extends StatelessWidget {
  final String name;
  final double radius;
  const InitialsAvatar(this.name, {super.key, this.radius = 22});

  static const _palette = [
    Palette.indigo,
    Palette.violet,
    Palette.sky,
    Palette.teal,
    Palette.orange,
    Palette.rose,
  ];

  @override
  Widget build(BuildContext context) {
    final words = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    final initials = words.isEmpty
        ? '?'
        : words.length == 1
            ? words.first.characters.first.toUpperCase()
            : (words.first.characters.first + words.last.characters.first)
                .toUpperCase();
    final c = _palette[name.codeUnits.fold<int>(0, (a, b) => a + b) % _palette.length];
    return CircleAvatar(
      radius: radius,
      backgroundColor: c.withValues(alpha: 0.16),
      child: Text(initials,
          style: TextStyle(
              color: c, fontWeight: FontWeight.w900, fontSize: radius * 0.72)),
    );
  }
}

