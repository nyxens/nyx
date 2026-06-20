import 'package:flutter/material.dart';
import 'breathing_orb.dart';

class EmptyState extends StatelessWidget {
  const EmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          BreathingOrb(
            size: 42,
          ),

          SizedBox(height: 30),

          Text(
            "How can I help?",
            style: TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w600,
              letterSpacing: -.7,
            ),
          ),

          SizedBox(height: 12),

          Text(
            "Ask anything",
            style: TextStyle(
              fontSize: 15,
              color: Colors.white54,
            ),
          ),
        ],
      ),
    );
  }
}