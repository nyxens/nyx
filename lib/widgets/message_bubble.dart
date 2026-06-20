import 'package:flutter/material.dart';
import '../models/chat_message.dart';

class MessageBubble extends StatelessWidget {
  final ChatMessage message;

  const MessageBubble({
    super.key,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    const textStyle = TextStyle(
      fontSize: 16,
      height: 1.55,
      color: Colors.white,
      leadingDistribution: TextLeadingDistribution.even,
    );

    if (message.isUser) {
      final radius =
          message.text.length < 40 ? 999.0 : 28.0;

      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          constraints: const BoxConstraints(
            maxWidth: 300,
          ),
          margin: const EdgeInsets.fromLTRB(
            80,
            8,
            15,
            8,
          ),
          padding: const EdgeInsets.fromLTRB(
            18,
            15,
            18,
            13,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            gradient: const LinearGradient(
              colors: [
                Color(0xff9A7CFF),
                Color(0xff6E53FF),
              ],
            ),
          ),
          child: Text(
            message.text,
            style: textStyle,
          ),
        ),
      );
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: AnimatedContainer(
        duration: const Duration(
          milliseconds: 400,
        ),
        curve: Curves.easeOutCubic,
        constraints: const BoxConstraints(
          maxWidth: 340,
        ),
        margin: const EdgeInsets.fromLTRB(
          15,
          8,
          50,
          8,
        ),

        // Top slightly larger than bottom for visual centering
        padding: const EdgeInsets.fromLTRB(
          18,
          15,
          18,
          13,
        ),

        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          color: Colors.white.withOpacity(
            message.streaming ? 0 : .03,
          ),
          border: Border.all(
            color: const Color(
              0xff8D6CFF,
            ).withOpacity(
              message.streaming ? 0 : .08,
            ),
          ),
        ),

        child: RichText(
          text: TextSpan(
            style: textStyle,
            children: [
              TextSpan(
                text: message.text,
              ),

              if (message.streaming)
                WidgetSpan(
                  alignment:
                      PlaceholderAlignment.baseline,
                  baseline: TextBaseline.alphabetic,
                  child: _BlinkingCursor(),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BlinkingCursor extends StatefulWidget {
  const _BlinkingCursor();

  @override
  State<_BlinkingCursor> createState() =>
      _BlinkingCursorState();
}

class _BlinkingCursorState
    extends State<_BlinkingCursor>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller;

  @override
  void initState() {
    super.initState();

    controller = AnimationController(
      vsync: this,
      duration: const Duration(
        milliseconds: 700,
      ),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: controller,
      child: const Text(
        "|",
        style: TextStyle(
          fontSize: 16,
          height: 1.55,
          color: Colors.white70,
          fontWeight: FontWeight.w300,
        ),
      ),
    );
  }
}