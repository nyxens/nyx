import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';

class NyxHeader extends StatefulWidget {
  final bool active;
  final VoidCallback? onMenuTap;
  final VoidCallback? onNewChat;

  const NyxHeader({
    super.key,
    this.active = false,
    this.onMenuTap,
    this.onNewChat,
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
    inner = AnimationController(vsync: this,
        duration: const Duration(seconds: 10))
      ..repeat();
    middle = AnimationController(vsync: this,
        duration: const Duration(seconds: 16))
      ..repeat();
    outer = AnimationController(vsync: this,
        duration: const Duration(seconds: 24))
      ..repeat();
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
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // ── Menu button (left) ──────────────────────────────────────────
          _GlassIconButton(
            icon: Icons.menu_rounded,
            onTap: widget.onMenuTap,
          ),

          // ── Orb + name pill (centre) ────────────────────────────────────
          ClipRRect(
            borderRadius: BorderRadius.circular(100),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(.025),
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(
                      color: Colors.white.withOpacity(.05)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 36,
                      height: 36,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          AnimatedBuilder(
                            animation: outer,
                            builder: (_, __) => Transform(
                              alignment: Alignment.center,
                              transform: Matrix4.identity()
                                ..rotateZ(outer.value * 2 * math.pi)
                                ..rotateX(.95),
                              child:
                                  _ring(const Color(0xff6A4CFF), 32, 1.3),
                            ),
                          ),
                          AnimatedBuilder(
                            animation: middle,
                            builder: (_, __) => Transform(
                              alignment: Alignment.center,
                              transform: Matrix4.identity()
                                ..rotateZ(-middle.value * 2 * math.pi)
                                ..rotateX(.45),
                              child:
                                  _ring(const Color(0xff8D6CFF), 28, 1.5),
                            ),
                          ),
                          AnimatedBuilder(
                            animation: inner,
                            builder: (_, __) => Transform(
                              alignment: Alignment.center,
                              transform: Matrix4.identity()
                                ..rotateZ(inner.value * 2 * math.pi)
                                ..rotateX(-.65),
                              child:
                                  _ring(const Color(0xffB388FF), 24, 1.8),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    ShaderMask(
                      shaderCallback: (bounds) =>
                          const LinearGradient(colors: [
                        Color(0xffEAE4FF),
                        Color(0xffB388FF),
                      ]).createShader(bounds),
                      child: const Text(
                        'Nyx',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
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

          // ── New chat button (right) ─────────────────────────────────────
          _GlassIconButton(
            icon: Icons.edit_outlined,
            onTap: widget.onNewChat,
          ),
        ],
      ),
    );
  }

  Widget _ring(Color color, double size, double width) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
            color: color.withOpacity(.95), width: width),
      ),
    );
  }
}

class _GlassIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _GlassIconButton({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(.04),
            borderRadius: BorderRadius.circular(14),
            border:
                Border.all(color: Colors.white.withOpacity(.07)),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: onTap,
              child: Center(
                child: Icon(icon, size: 20, color: Colors.white60),
              ),
            ),
          ),
        ),
      ),
    );
  }
}