import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'firebase_options.dart';
import 'services/firestore_service.dart';
import 'theme/app_theme.dart';
import 'screens/chat_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const KhidmatBotApp());
  // Seed in background — don't block UI
  FirestoreService.seedProviders().catchError((e) {
    // ignore seed errors silently
  });
}

class KhidmatBotApp extends StatelessWidget {
  const KhidmatBotApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KhidmatBot',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      home: const ChatScreen(),
    );
  }
}
