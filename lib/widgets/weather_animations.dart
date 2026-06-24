import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/weather_condition.dart';
import '../theme/weather_theme.dart';

/// A full-screen animated background that renders a gradient sky plus a
/// particle/effect layer matched to the current [condition].
///
/// Everything is drawn with [CustomPainter]s (no image or Lottie assets) so it
/// stays lightweight and scales to any screen size.
class AnimatedWeatherBackground extends StatefulWidget {
  const AnimatedWeatherBackground({
    super.key,
    required this.condition,
    required this.child,
    this.enabled = true,
    this.reducedMotion = false,
  });

  final WeatherCondition condition;
  final Widget child;
  final bool enabled;
  final bool reducedMotion;

  @override
  State<AnimatedWeatherBackground> createState() =>
      _AnimatedWeatherBackgroundState();
}

class _AnimatedWeatherBackgroundState extends State<AnimatedWeatherBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = WeatherTheme.gradientFor(widget.condition);
    final speed = widget.reducedMotion ? 0.25 : 1.0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 800),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: colors,
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (widget.enabled)
            RepaintBoundary(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) => CustomPaint(
                  painter: _WeatherEffectPainter(
                    condition: widget.condition,
                    t: _controller.value,
                    speed: speed,
                  ),
                ),
              ),
            ),
          widget.child,
        ],
      ),
    );
  }
}

/// Dispatches to the right effect based on the weather category.
class _WeatherEffectPainter extends CustomPainter {
  _WeatherEffectPainter({
    required this.condition,
    required this.t,
    required this.speed,
  });

  final WeatherCondition condition;
  final double t;
  final double speed;

  // Deterministic particle fields generated once per painter instance is not
  // possible (painter is recreated each frame), so we seed from indices to keep
  // particle layouts stable across frames.
  @override
  void paint(Canvas canvas, Size size) {
    switch (condition.category) {
      case WeatherCategory.clear:
        if (condition.isDay) {
          _paintSun(canvas, size);
        } else {
          _paintStars(canvas, size);
          _paintMoon(canvas, size);
        }
        break;
      case WeatherCategory.partlyCloudy:
        if (condition.isDay) {
          _paintSun(canvas, size, small: true);
        } else {
          _paintStars(canvas, size, count: 40);
        }
        _paintClouds(canvas, size, count: 3, opacity: 0.7);
        break;
      case WeatherCategory.cloudy:
        _paintClouds(canvas, size, count: 6, opacity: 0.85);
        break;
      case WeatherCategory.fog:
        _paintFog(canvas, size);
        break;
      case WeatherCategory.drizzle:
        _paintClouds(canvas, size, count: 4, opacity: 0.6);
        _paintRain(canvas, size, count: 60, length: 8, drizzle: true);
        break;
      case WeatherCategory.rain:
        _paintClouds(canvas, size, count: 4, opacity: 0.7);
        _paintRain(canvas, size, count: 140, length: 16);
        break;
      case WeatherCategory.snow:
        _paintClouds(canvas, size, count: 3, opacity: 0.5);
        _paintSnow(canvas, size, count: 90);
        break;
      case WeatherCategory.thunderstorm:
        _paintClouds(canvas, size, count: 5, opacity: 0.8);
        _paintRain(canvas, size, count: 120, length: 18);
        _paintLightning(canvas, size);
        break;
      case WeatherCategory.unknown:
        _paintClouds(canvas, size, count: 3, opacity: 0.5);
        break;
    }
  }

  // --- Sun ---
  void _paintSun(Canvas canvas, Size size, {bool small = false}) {
    final center = Offset(size.width * 0.78, size.height * 0.18);
    final radius = small ? 34.0 : 48.0;
    final glow = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFFFFF59D).withValues(alpha: 0.9),
          const Color(0xFFFFF176).withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius * 3));
    canvas.drawCircle(center, radius * 3, glow);

    // Rotating rays.
    final rayPaint = Paint()
      ..color = const Color(0xFFFFF176).withValues(alpha: 0.55)
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    final rotation = t * 2 * math.pi * speed * 0.15;
    for (var i = 0; i < 12; i++) {
      final angle = rotation + i * (math.pi / 6);
      final inner = center + Offset(math.cos(angle), math.sin(angle)) * (radius + 10);
      final outer = center + Offset(math.cos(angle), math.sin(angle)) * (radius + 28);
      canvas.drawLine(inner, outer, rayPaint);
    }

    final disc = Paint()..color = const Color(0xFFFFEB3B);
    canvas.drawCircle(center, radius, disc);
  }

  void _paintMoon(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.78, size.height * 0.18);
    const radius = 40.0;
    final glow = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.white.withValues(alpha: 0.4),
          Colors.white.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius * 2.5));
    canvas.drawCircle(center, radius * 2.5, glow);

    final moon = Paint()..color = const Color(0xFFECEFF1);
    canvas.drawCircle(center, radius, moon);
    // Carve a crescent shadow.
    final shadow = Paint()..color = const Color(0xFF1A237E).withValues(alpha: 0.55);
    canvas.drawCircle(center + const Offset(16, -6), radius * 0.95, shadow);
  }

  // --- Stars ---
  void _paintStars(Canvas canvas, Size size, {int count = 70}) {
    final paint = Paint()..color = Colors.white;
    for (var i = 0; i < count; i++) {
      final rnd = math.Random(i * 7919);
      final x = rnd.nextDouble() * size.width;
      final y = rnd.nextDouble() * size.height * 0.7;
      final phase = rnd.nextDouble();
      final twinkle = 0.4 + 0.6 * (0.5 + 0.5 * math.sin((t + phase) * 2 * math.pi));
      paint.color = Colors.white.withValues(alpha: 0.3 + 0.6 * twinkle);
      canvas.drawCircle(Offset(x, y), rnd.nextDouble() * 1.4 + 0.6, paint);
    }
  }

  // --- Clouds ---
  void _paintClouds(Canvas canvas, Size size,
      {required int count, required double opacity}) {
    for (var i = 0; i < count; i++) {
      final rnd = math.Random(i * 104729 + 13);
      final baseY = rnd.nextDouble() * size.height * 0.45 + 20;
      final scale = rnd.nextDouble() * 0.6 + 0.7;
      final driftSpeed = (rnd.nextDouble() * 0.4 + 0.2) * speed;
      final dir = i.isEven ? 1 : -1;
      var x = (rnd.nextDouble() + t * driftSpeed * dir) % 1.2;
      if (x < 0) x += 1.2;
      final cx = x * size.width - size.width * 0.1;
      _drawCloud(canvas, Offset(cx, baseY), 60 * scale, opacity);
    }
  }

  void _drawCloud(Canvas canvas, Offset center, double r, double opacity) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: opacity * 0.85)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawCircle(center, r * 0.6, paint);
    canvas.drawCircle(center + Offset(r * 0.5, r * 0.1), r * 0.5, paint);
    canvas.drawCircle(center + Offset(-r * 0.5, r * 0.12), r * 0.45, paint);
    canvas.drawCircle(center + Offset(r * 0.1, -r * 0.2), r * 0.5, paint);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
            center: center + Offset(0, r * 0.25),
            width: r * 2,
            height: r * 0.6),
        Radius.circular(r * 0.3),
      ),
      paint,
    );
  }

  // --- Rain ---
  void _paintRain(Canvas canvas, Size size,
      {required int count, required double length, bool drizzle = false}) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: drizzle ? 0.35 : 0.5)
      ..strokeWidth = drizzle ? 1.0 : 1.8
      ..strokeCap = StrokeCap.round;
    final fallSpeed = (drizzle ? 0.6 : 1.0) * speed;
    for (var i = 0; i < count; i++) {
      final rnd = math.Random(i * 49297 + 5);
      final x = rnd.nextDouble() * size.width;
      final phase = rnd.nextDouble();
      var y = ((phase + t * (1.2 + rnd.nextDouble()) * fallSpeed) % 1.0) *
          (size.height + length);
      y -= length;
      const slant = 3.0;
      canvas.drawLine(Offset(x, y), Offset(x - slant, y + length), paint);
    }
  }

  // --- Snow ---
  void _paintSnow(Canvas canvas, Size size, {required int count}) {
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.9);
    for (var i = 0; i < count; i++) {
      final rnd = math.Random(i * 33391 + 9);
      final baseX = rnd.nextDouble() * size.width;
      final phase = rnd.nextDouble();
      final fall = (phase + t * (0.3 + rnd.nextDouble() * 0.4) * speed) % 1.0;
      final y = fall * (size.height + 20) - 10;
      final sway = math.sin((t * 2 * math.pi + phase * 6)) * 12;
      final radius = rnd.nextDouble() * 2.2 + 1.2;
      paint.color = Colors.white.withValues(alpha: 0.6 + rnd.nextDouble() * 0.4);
      canvas.drawCircle(Offset(baseX + sway, y), radius, paint);
    }
  }

  // --- Fog ---
  void _paintFog(Canvas canvas, Size size) {
    for (var i = 0; i < 5; i++) {
      final rnd = math.Random(i * 71 + 3);
      final y = size.height * (0.2 + i * 0.16);
      final driftSpeed = (rnd.nextDouble() * 0.3 + 0.1) * speed;
      final dir = i.isEven ? 1 : -1;
      var x = (rnd.nextDouble() + t * driftSpeed * dir) % 1.4 - 0.2;
      final paint = Paint()
        ..color = Colors.white.withValues(alpha: 0.12)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 30);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(x * size.width, y),
            width: size.width * 0.9,
            height: 60,
          ),
          const Radius.circular(40),
        ),
        paint,
      );
    }
  }

  // --- Lightning ---
  void _paintLightning(Canvas canvas, Size size) {
    // Flash on a periodic schedule derived from t.
    final cycle = (t * 6) % 1.0;
    if (cycle > 0.06) return; // brief flash
    final flash = Paint()
      ..color = Colors.white.withValues(alpha: 0.25 * (1 - cycle / 0.06));
    canvas.drawRect(Offset.zero & size, flash);

    final boltPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.9)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final rnd = math.Random((t * 10).floor());
    final startX = size.width * (0.3 + rnd.nextDouble() * 0.4);
    final path = Path()..moveTo(startX, 0);
    var x = startX;
    var y = 0.0;
    while (y < size.height * 0.6) {
      x += (rnd.nextDouble() - 0.5) * 40;
      y += size.height * 0.12;
      path.lineTo(x, y);
    }
    canvas.drawPath(path, boltPaint);
  }

  @override
  bool shouldRepaint(covariant _WeatherEffectPainter old) =>
      old.t != t ||
      old.condition.category != condition.category ||
      old.condition.isDay != condition.isDay;
}
