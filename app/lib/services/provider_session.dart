import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';

// Holds the logged-in provider's ID for the current session.
// Persists across app restarts via Firestore (keyed on Firebase Auth UID,
// which survives because OTP sign-in keeps the session alive).
class ProviderSession {
  static String? _providerId;
  static String? _providerName;

  static String? get providerId => _providerId;
  static String? get providerName => _providerName;

  // Called after successful provider registration.
  static Future<void> save(String id, String name) async {
    _providerId = id;
    _providerName = name;

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('provider_sessions')
          .doc(uid)
          .set({
        'provider_id': id,
        'name': name,
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  // Called on "Provider Hoon" tap — checks memory then Firestore.
  // Returns the provider ID if found, null if not logged in.
  static Future<String?> load() async {
    if (_providerId != null) return _providerId;

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('provider_sessions')
          .doc(uid)
          .get();
      if (doc.exists) {
        _providerId = doc.data()?['provider_id'] as String?;
        _providerName = doc.data()?['name'] as String?;
        return _providerId;
      }
    } catch (_) {}
    return null;
  }

  static void clear() {
    _providerId = null;
    _providerName = null;
  }

  static Future<void> copyIdToClipboard(String id) async {
    await Clipboard.setData(ClipboardData(text: id));
  }
}
