import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'screens/chat_screen.dart';
import 'services/llm_service.dart';
import 'services/storage_service.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock to portrait — chat UIs don't benefit from landscape.
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  // Initialise local database before the first frame.
  final storage = StorageService();
  await storage.init();

  final llm = LLMService();

  runApp(Nyx(storage: storage, llm: llm));
}

class Nyx extends StatelessWidget {
  final StorageService storage;
  final LLMService llm;

  const Nyx({super.key, required this.storage, required this.llm});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: ChatScreen(storage: storage, llm: llm),
    );
  }
}