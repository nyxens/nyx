import 'dart:math';
import 'package:flutter/material.dart';

class LiquidBackground extends StatefulWidget {
  final Widget child;

  const LiquidBackground({
    super.key,
    required this.child,
  });

  @override
  State<LiquidBackground> createState() => _LiquidBackgroundState();
}

class _LiquidBackgroundState extends State<LiquidBackground>
    with SingleTickerProviderStateMixin {
  // Using AnimationController instead of Timer.periodic means the animation
  // is vsync-aligned (no wasted frames, no battery drain when off-screen).
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      // A longer duration feels organic; value goes 0→1 and we wrap it in sin/cos.
      duration: const Duration(seconds: 30),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Stack(
        children: [
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (_, __) => CustomPaint(
                // phase goes 0 → 2π continuously.
                painter: MeshPainter(_controller.value * 2 * pi),
              ),
            ),
          ),

          // Subtle dark overlay to keep text readable.
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                color: const Color(0xff090B10).withOpacity(.14),
              ),
            ),
          ),

          // Vignette gradient — heavier at the bottom where UI lives.
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      const Color(0xff090B10).withOpacity(.05),
                      Colors.transparent,
                      const Color(0xff090B10).withOpacity(.15),
                      const Color(0xff090B10).withOpacity(.55),
                      const Color(0xff090B10),
                    ],
                    stops: const [0, .15, .6, .85, 1],
                  ),
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

class MeshPainter extends CustomPainter {
  final double p; // phase in radians (0 → 2π)

  MeshPainter(this.p);

  @override
  void paint(Canvas canvas, Size size) {
    _drawGlow(
      canvas,
      Offset(
        size.width * (.22 + .05 * sin(p * .7)),
        size.height * (.15 + .04 * cos(p * .9)),
      ),
      240,
      const Color(0xff8D6CFF).withOpacity(.18),
    );

    _drawGlow(
      canvas,
      Offset(
        size.width * (.82 + .04 * cos(p * .55)),
        size.height * (.24 + .06 * sin(p * .8)),
      ),
      210,
      Colors.indigo.withOpacity(.14),
    );

    _drawGlow(
      canvas,
      Offset(
        size.width * (.30 + .07 * sin(p * .45)),
        size.height * (.72 + .04 * cos(p * .65)),
      ),
      190,
      Colors.blue.withOpacity(.12),
    );

    _drawGlow(
      canvas,
      Offset(
        size.width * (.76 + .05 * cos(p * .6)),
        size.height * (.62 + .05 * sin(p * .7)),
      ),
      170,
      Colors.deepPurpleAccent.withOpacity(.10),
    );
  }

  void _drawGlow(Canvas canvas, Offset center, double radius, Color color) {
    final rect = Rect.fromCircle(center: center, radius: radius);
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [color, color.withOpacity(.35), Colors.transparent],
      ).createShader(rect);
    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(covariant MeshPainter oldDelegate) =>
      oldDelegate.p != p;
}