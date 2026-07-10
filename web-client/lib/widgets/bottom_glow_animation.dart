import 'package:flutter/material.dart';

class BottomGlowAnimation extends StatefulWidget {
  const BottomGlowAnimation({Key? key}) : super(key: key);

  @override
  _BottomGlowAnimationState createState() => _BottomGlowAnimationState();
}

class _BottomGlowAnimationState extends State<BottomGlowAnimation> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Container(
            height: 200,
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0, 1.5),
                radius: 1.5,
                colors: [
                  const Color(0xFF6B8AFF).withOpacity(0.3 + (_controller.value * 0.2)),
                  const Color(0xFFA259FF).withOpacity(0.2 + (_controller.value * 0.15)),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
            ),
          );
        },
      ),
    );
  }
}
