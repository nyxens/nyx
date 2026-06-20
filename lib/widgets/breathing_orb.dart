import 'package:flutter/material.dart';

class BreathingOrb extends StatefulWidget {
  final double size;

  const BreathingOrb({
    super.key,
    this.size = 18,
  });

  @override
  State<BreathingOrb> createState() =>
      _BreathingOrbState();
}

class _BreathingOrbState
    extends State<BreathingOrb>
    with SingleTickerProviderStateMixin {
  late AnimationController controller;

  @override
  void initState() {
    super.initState();

    controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
      lowerBound: .85,
      upperBound: 1,
    )..repeat(reverse: true);
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: controller,
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            colors: [
              Color(0xff7C4DFF),
              Color(0xffB388FF),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(
                0xff9A7CFF,
              ).withOpacity(.6),
              blurRadius: 20,
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }
}