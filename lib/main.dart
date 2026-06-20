import 'package:flutter/material.dart';
import 'screens/chat_screen.dart';
import 'theme/app_theme.dart';

void main() {

  runApp(const Nyx());

}

class Nyx extends StatelessWidget {

  const Nyx({super.key});

  @override
  Widget build(BuildContext context) {

    return MaterialApp(

      debugShowCheckedModeBanner: false,

      theme: AppTheme.dark,

      home: const ChatScreen(),

    );

  }

}