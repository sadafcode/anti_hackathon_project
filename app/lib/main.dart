import 'dart:ui';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'firebase_options.dart';
import 'services/firestore_service.dart';
import 'services/notification_service.dart';
import 'theme/app_theme.dart';
import 'screens/home_screen.dart';
import 'screens/booking_status_screen.dart';
import 'screens/provider_notification_screen.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Initialize push notifications
  NotificationService.navigatorKey = navigatorKey;
  await NotificationService.initialize();

  runApp(const KhidmatBotApp());

  // Seed providers in background
  FirestoreService.seedProviders().catchError((_) {});
}

class KhidmatBotApp extends StatelessWidget {
  const KhidmatBotApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KhidmatBot',
      debugShowCheckedModeBanner: false,
      scrollBehavior: AppScrollBehavior(),
      theme: AppTheme.theme,
      navigatorKey: navigatorKey,
      home: const HomeScreen(),
      // Named routes for notification tap navigation
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/provider-notification':
            final providerId = settings.arguments as String;
            return MaterialPageRoute(
              builder: (_) =>
                  ProviderNotificationScreen(providerId: providerId),
            );
          case '/booking-status':
            final args = settings.arguments as Map<String, dynamic>;
            return MaterialPageRoute(
              builder: (_) => BookingStatusScreen(
                bookingId: args['bookingId'] as String,
                providerName: args['providerName'] as String,
                serviceType: args['serviceType'] as String,
              ),
            );
          default:
            return null;
        }
      },
    );
  }
}

class AppScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
      };
}
