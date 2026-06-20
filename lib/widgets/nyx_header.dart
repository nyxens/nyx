import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

class NyxHeader extends StatefulWidget {
  final bool active;

  const NyxHeader({
    super.key,
    this.active = false,
  });

  @override
  State<NyxHeader> createState() => _NyxHeaderState();
}

class _NyxHeaderState extends State<NyxHeader>
    with TickerProviderStateMixin {
  late final AnimationController inner;
  late final AnimationController middle;
  late final AnimationController outer;

  @override
  void initState() {
    super.initState();

    inner = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();

    middle = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 16),
    )..repeat();

    outer = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 24),
    )..repeat();
  }

  @override
  void dispose() {
    inner.dispose();
    middle.dispose();
    outer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        top: 8,
        bottom: 18,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(100),
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: 18,
            sigmaY: 18,
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 12,
            ),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(.025),
              borderRadius: BorderRadius.circular(100),
              border: Border.all(
                color: Colors.white.withOpacity(.05),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 42,
                  height: 42,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      AnimatedBuilder(
                        animation: outer,
                        builder: (_, __) {
                          return Transform(
                            alignment: Alignment.center,
                            transform: Matrix4.identity()
                              ..rotateZ(
                                  outer.value * 2 * math.pi)
                              ..rotateX(.95),
                            child: _ring(
                              const Color(0xff6A4CFF),
                              38,
                              1.4,
                            ),
                          );
                        },
                      ),
                      AnimatedBuilder(
                        animation: middle,
                        builder: (_, __) {
                          return Transform(
                            alignment: Alignment.center,
                            transform: Matrix4.identity()
                              ..rotateZ(
                                  -middle.value *
                                      2 *
                                      math.pi)
                              ..rotateX(.45),
                            child: _ring(
                              const Color(0xff8D6CFF),
                              34,
                              1.7,
                            ),
                          );
                        },
                      ),
                      AnimatedBuilder(
                        animation: inner,
                        builder: (_, __) {
                          return Transform(
                            alignment: Alignment.center,
                            transform: Matrix4.identity()
                              ..rotateZ(
                                  inner.value * 2 * math.pi)
                              ..rotateX(-.65),
                            child: _ring(
                              const Color(0xffB388FF),
                              30,
                              2,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 14),

                ShaderMask(
                  shaderCallback: (bounds) {
                    return const LinearGradient(
                      colors: [
                        Color(0xffEAE4FF),
                        Color(0xffB388FF),
                      ],
                    ).createShader(bounds);
                  },
                  child: const Text(
                    "Nyx",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      letterSpacing: .3,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _ring(
    Color color,
    double size,
    double width,
  ) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: color.withOpacity(.95),
          width: width,
        ),
      ),
    );
  }
}