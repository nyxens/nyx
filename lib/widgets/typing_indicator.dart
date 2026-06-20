import 'package:flutter/material.dart';

class TypingIndicator extends StatelessWidget {
  const TypingIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(
        left: 24,
        top: 10,
        bottom: 15,
      ),
      child: Row(
        children: [
          Icon(
            Icons.auto_awesome,
            size: 12,
            color: Color(0xffB388FF),
          ),
          SizedBox(width: 8),
          Text(
            "Nyx is thinking",
            style: TextStyle(
              fontSize: 13,
              color: Colors.white54,
            ),
          ),
        ],
      ),
    );
  }
}