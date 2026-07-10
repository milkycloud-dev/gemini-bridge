import 'dart:math';
import 'package:flutter/material.dart';

class GeminiHeroAnimation extends StatefulWidget {
  final double size;
  const GeminiHeroAnimation({Key? key, this.size = 120}) : super(key: key);

  @override
  _GeminiHeroAnimationState createState() => _GeminiHeroAnimationState();
}

class _GeminiHeroAnimationState extends State<GeminiHeroAnimation> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<Particle> particles = [];
  final Random random = Random();
  final List<Color> googleColors = [
    const Color(0xFF4285F4), // Blue
    const Color(0xFFEA4335), // Red
    const Color(0xFFFBBC05), // Yellow
    const Color(0xFF34A853), // Green
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 10))..repeat();
    for (int i = 0; i < 40; i++) {
      particles.add(Particle(
        angle: random.nextDouble() * 2 * pi,
        distance: random.nextDouble() * widget.size,
        speed: 0.2 + random.nextDouble() * 0.8,
        color: googleColors[random.nextInt(googleColors.length)],
        size: 2 + random.nextDouble() * 4,
      ));
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        for (var p in particles) {
          p.angle += p.speed * 0.02;
        }
        return CustomPaint(
          size: Size(widget.size * 2, widget.size * 2),
          painter: _HeroPainter(particles, _controller.value),
        );
      },
    );
  }
}

class Particle {
  double angle;
  double distance;
  double speed;
  Color color;
  double size;

  Particle({required this.angle, required this.distance, required this.speed, required this.color, required this.size});
}

class _HeroPainter extends CustomPainter {
  final List<Particle> particles;
  final double progress;

  _HeroPainter(this.particles, this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    
    for (var p in particles) {
      final x = center.dx + cos(p.angle) * p.distance;
      final y = center.dy + sin(p.angle) * p.distance;
      final paint = Paint()
        ..color = p.color.withOpacity(0.6 + 0.4 * sin(progress * 2 * pi + p.distance))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
      canvas.drawCircle(Offset(x, y), p.size, paint);
    }

    final starPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF6B8AFF), Color(0xFFA259FF)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Rect.fromCenter(center: center, width: size.width / 2, height: size.height / 2))
      ..style = PaintingStyle.fill;

    final path = Path();
    final boxSize = min(size.width, size.height);
    final w = boxSize / 2.5;
    final h = boxSize / 2.5;
    final sx = center.dx - w / 2;
    final sy = center.dy - h / 2;

    path.moveTo(sx + w / 2, sy);
    path.quadraticBezierTo(sx + w / 2, sy + h / 2, sx + w, sy + h / 2);
    path.quadraticBezierTo(sx + w / 2, sy + h / 2, sx + w / 2, sy + h);
    path.quadraticBezierTo(sx + w / 2, sy + h / 2, sx, sy + h / 2);
    path.quadraticBezierTo(sx + w / 2, sy + h / 2, sx + w / 2, sy);
    path.close();

    canvas.drawPath(path, starPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
