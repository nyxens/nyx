import 'package:flutter/material.dart';

class MessageAppear extends StatefulWidget {
  final Widget child;

  const MessageAppear({
    super.key,
    required this.child,
  });

  @override
  State<MessageAppear> createState() =>
      _MessageAppearState();
}

class _MessageAppearState
    extends State<MessageAppear>
    with SingleTickerProviderStateMixin {
  late AnimationController controller;

  late Animation<double> opacity;

  late Animation<Offset> slide;

  @override
  void initState() {
    super.initState();

    controller = AnimationController(
      vsync: this,
      duration: const Duration(
        milliseconds: 350,
      ),
    );

    opacity = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(
      CurvedAnimation(
        parent: controller,
        curve: Curves.easeOut,
      ),
    );

    slide = Tween<Offset>(
      begin: const Offset(
        0,
        .15,
      ),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: controller,
        curve: Curves.easeOutCubic,
      ),
    );

    controller.forward();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: opacity,
      child: SlideTransition(
        position: slide,
        child: widget.child,
      ),
    );
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }
}