import 'dart:math';
import 'package:flutter/material.dart';
import '../widgets/gemini_hero_animation.dart';
import 'register_screen.dart';

class ConnectionErrorScreen extends StatefulWidget {
  final String? errorDetail;
  const ConnectionErrorScreen({Key? key, this.errorDetail}) : super(key: key);

  @override
  State<ConnectionErrorScreen> createState() => _ConnectionErrorScreenState();
}

class _ConnectionErrorScreenState extends State<ConnectionErrorScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF131314),
      body: Stack(
        children: [
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return CustomPaint(
                  painter: _WavePainter(animationValue: _controller.value),
                );
              },
            ),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const GeminiHeroAnimation(size: 100),
                  const SizedBox(height: 40),
                  ShaderMask(
                    shaderCallback: (bounds) => const LinearGradient(
                      colors: [
                        Color(0xFF4285F4),
                        Color(0xFFA259FF),
                        Color(0xFFEA4335)
                      ],
                    ).createShader(bounds),
                    child: const Text(
                      'Не удалось подключиться',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Похоже, ваш провайдер блокирует подключение к MilkyCloud.\n'
                    'Мы уже ищем альтернативные способы подключения.\n\n'
                    'Попробуйте использовать VPN или другую сеть.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white60,
                      fontSize: 16,
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 40),
                  Container(
                    height: 54,
                    width: 220,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(27),
                      gradient: const LinearGradient(
                        colors: [Color(0xFF4285F4), Color(0xFFA259FF)],
                      ),
                    ),
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const RegisterScreen()),
                        );
                      },
                      icon: const Icon(Icons.refresh, color: Colors.white),
                      label: const Text('Повторить',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(27)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WavePainter extends CustomPainter {
  final double animationValue;
  _WavePainter({required this.animationValue});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    final colors = [
      const Color(0xFF4285F4).withOpacity(0.05),
      const Color(0xFF9B72CB).withOpacity(0.05),
      const Color(0xFFD96570).withOpacity(0.05),
    ];

    for (int i = 0; i < 3; i++) {
      paint.color = colors[i];
      final path = Path();
      final waveHeight = 40.0 + i * 20.0;
      final yOffset = size.height * 0.5 + i * 60;
      path.moveTo(0, yOffset);

      for (double x = 0; x <= size.width; x++) {
        final y = yOffset +
            sin((x / size.width * 2 * pi) +
                    (animationValue * 2 * pi) +
                    (i * pi / 3)) *
                waveHeight;
        path.lineTo(x, y);
      }

      path.lineTo(size.width, size.height);
      path.lineTo(0, size.height);
      path.close();
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _WavePainter oldDelegate) =>
      oldDelegate.animationValue != animationValue;
}
