import 'package:flutter/material.dart';

class GeminiStar extends StatelessWidget {
  final double size;
  final Color color;

  const GeminiStar({Key? key, this.size = 24.0, this.color = Colors.blueAccent}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _GeminiStarPainter(color),
    );
  }
}

class _GeminiStarPainter extends CustomPainter {
  final Color color;
  _GeminiStarPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();
    final w = size.width;
    final h = size.height;
    
    path.moveTo(w / 2, 0);
    path.quadraticBezierTo(w / 2, h / 2, w, h / 2);
    path.quadraticBezierTo(w / 2, h / 2, w / 2, h);
    path.quadraticBezierTo(w / 2, h / 2, 0, h / 2);
    path.quadraticBezierTo(w / 2, h / 2, w / 2, 0);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
