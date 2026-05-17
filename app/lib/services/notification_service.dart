import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'api_service.dart';

// ─────────────────────────────────────────────
// Background handler — must be top-level function
// Called when app is TERMINATED or in BACKGROUND
// ─────────────────────────────────────────────
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Firebase is already initialized by main() before this fires.
  // FCM automatically shows the notification in the system tray.
  // We only need this handler if we want extra logic (e.g., Firestore write).
  debugPrint('[FCM Background] ${message.notification?.title} — ${message.data}');
}

class NotificationService {
  static final _messaging = FirebaseMessaging.instance;
  static final _db = FirebaseFirestore.instance;

  // Stores the navigation key so background-tap can navigate
  static GlobalKey<NavigatorState>? navigatorKey;

  /// Call once in main() BEFORE runApp()
  static Future<void> initialize() async {
    // Register background handler (must be before anything else)
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // Request permission (Android 13+ and iOS require this)
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      debugPrint('[FCM] Permission granted');
    } else {
      debugPrint('[FCM] Permission denied — notifications will not show');
      return;
    }

    // Get + save token
    await _saveToken();

    // Token refresh listener
    _messaging.onTokenRefresh.listen(_onTokenRefresh);

    // Foreground message handler — app is OPEN
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Notification tap when app was in BACKGROUND (not terminated)
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

    // Notification tap when app was TERMINATED
    final initial = await _messaging.getInitialMessage();
    if (initial != null) _handleNotificationTap(initial);
  }

  /// Call when a provider logs in — saves provider-specific token
  static Future<void> saveProviderToken(String providerId) async {
    final token = await _messaging.getToken();
    if (token == null) return;
    await _saveTokenToFirestore(token, role: 'provider', id: providerId);
    // Also inform backend
    _saveTokenToBackend(token, role: 'provider', id: providerId);
  }

  /// Call when client session starts — saves client token
  static Future<void> saveClientToken(String sessionId) async {
    final token = await _messaging.getToken();
    if (token == null) return;
    await _saveTokenToFirestore(token, role: 'client', id: sessionId);
    _saveTokenToBackend(token, role: 'client', id: sessionId);
  }

  // Web Push VAPID key — get from:
  // Firebase Console → Project Settings → Cloud Messaging →
  // Web Push certificates → Generate key pair → copy the key string
  static const _webVapidKey =
      'YOUR_VAPID_KEY_HERE'; // <-- replace this

  static Future<void> _saveToken() async {
    try {
      // On web: pass vapidKey so the browser can subscribe to push
      final token = await _messaging.getToken(
        vapidKey: kIsWeb ? _webVapidKey : null,
      );
      if (token != null) {
        debugPrint('[FCM] Token: ${token.substring(0, 20)}...');
        await _saveTokenToFirestore(token, role: 'client', id: ApiService.sessionId);
        _saveTokenToBackend(token, role: 'client', id: ApiService.sessionId);
      }
    } catch (e) {
      debugPrint('[FCM] Token fetch failed: $e');
    }
  }

  static Future<void> _onTokenRefresh(String token) async {
    debugPrint('[FCM] Token refreshed');
    await _saveTokenToFirestore(token, role: 'client', id: ApiService.sessionId);
    _saveTokenToBackend(token, role: 'client', id: ApiService.sessionId);
  }

  static Future<void> _saveTokenToFirestore(String token,
      {required String role, required String id}) async {
    try {
      await _db.collection('fcm_tokens').doc('${role}_$id').set({
        'token': token,
        'role': role,
        'id': id,
        'platform': defaultTargetPlatform.name,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('[FCM] Firestore token save failed: $e');
    }
  }

  static void _saveTokenToBackend(String token,
      {required String role, required String id}) {
    postTokenToBackend(token: token, role: role, id: id);
  }

  // Foreground message — app is open, show banner manually
  static void _handleForegroundMessage(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return;

    debugPrint('[FCM Foreground] ${notification.title}');

    // Show a SnackBar / banner using the global navigator key
    final ctx = navigatorKey?.currentContext;
    if (ctx == null) return;

    ScaffoldMessenger.of(ctx).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.notifications_active, color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notification.title ?? '',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, color: Colors.white),
                  ),
                  if ((notification.body ?? '').isNotEmpty)
                    Text(
                      notification.body!,
                      style: const TextStyle(
                          fontSize: 12, color: Colors.white70),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF1B5E20),
        duration: const Duration(seconds: 5),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(12),
        action: SnackBarAction(
          label: 'Dekho',
          textColor: Colors.white,
          onPressed: () => _handleNotificationTap(message),
        ),
      ),
    );
  }

  // User tapped a notification — navigate to correct screen
  static void _handleNotificationTap(RemoteMessage message) {
    final data = message.data;
    final type = data['type'] as String?;
    final bookingId = data['booking_id'] as String?;

    debugPrint('[FCM Tap] type=$type bookingId=$bookingId');

    final nav = navigatorKey?.currentState;
    if (nav == null) return;

    switch (type) {
      case 'new_booking':
        // Provider tapped — go to provider notification screen
        final providerId = data['provider_id'] as String?;
        if (providerId != null) {
          nav.pushNamed('/provider-notification', arguments: providerId);
        }
        break;
      case 'booking_confirmed':
      case 'booking_declined':
      case 'booking_pending':
        // Client tapped — go to booking status screen
        if (bookingId != null) {
          nav.pushNamed('/booking-status', arguments: {
            'bookingId': bookingId,
            'providerName': data['provider_name'] ?? 'Provider',
            'serviceType': data['service_type'] ?? 'service',
          });
        }
        break;
    }
  }
}

// Helper to avoid circular import — calls ApiService backend
void postTokenToBackend(
    {required String token, required String role, required String id}) {
  // Fire-and-forget, ignore errors
  ApiService.saveNotificationToken(token: token, role: role, id: id)
      .catchError((_) {});
}
