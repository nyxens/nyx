import 'dart:math';
import 'package:flutter/material.dart';

class IntelligenceOrb extends StatefulWidget {
  final double size;
  final bool active;

  const IntelligenceOrb({
    super.key,
    this.size = 54,
    this.active = false,
  });

  @override
  State<IntelligenceOrb> createState() =>
      _IntelligenceOrbState();
}

class _IntelligenceOrbState extends State<IntelligenceOrb>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller;

  @override
  void initState() {
    super.initState();

    controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) {
        final t = controller.value * 2 * pi;

        final pulse = widget.active
            ? 1 + .07 * sin(t * 2)
            : 1 + .03 * sin(t);

        return Transform.scale(
          scale: pulse,
          child: SizedBox(
            width: widget.size,
            height: widget.size,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // outer glow
                Container(
                  width: widget.size,
                  height: widget.size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(
                          0xff8D6CFF,
                        ).withOpacity(
                          widget.active ? .45 : .25,
                        ),
                        blurRadius:
                            widget.active ? 40 : 25,
                      ),
                    ],
                  ),
                ),

                // middle layer
                Container(
                  width: widget.size * .7,
                  height: widget.size * .7,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        Colors.white.withOpacity(.95),
                        const Color(
                          0xffBBA8FF,
                        ),
                        const Color(
                          0xff7A5BFF,
                        ),
                      ],
                    ),
                  ),
                ),

                // core
                Container(
                  width: widget.size * .25,
                  height: widget.size * .25,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.white
                            .withOpacity(.9),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                ),

                // orbiting particles
                ...List.generate(3, (i) {
                  final angle =
                      t + i * (2 * pi / 3);

                  return Transform.translate(
                    offset: Offset(
                      cos(angle) *
                          widget.size *
                          .45,
                      sin(angle) *
                          widget.size *
                          .45,
                    ),
                    child: Container(
                      width: 4,
                      height: 4,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white
                            .withOpacity(.8),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }
}