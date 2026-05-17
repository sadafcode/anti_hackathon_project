import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';

class PhoneAuthService {
  static final _auth = FirebaseAuth.instance;
  static String? _verificationId;

  static String _normalize(String phone) {
    phone = phone.replaceAll(RegExp(r'[\s\-()+]'), '');
    if (phone.startsWith('92')) return '+$phone';
    if (phone.startsWith('0')) return '+92${phone.substring(1)}';
    if (!phone.startsWith('+')) return '+92$phone';
    return phone;
  }

  // Returns null on success, error string on failure.
  // Uses a real Completer so we wait for codeSent/verificationFailed callbacks
  // before returning — the old code used Future<void>.value() which was
  // already complete and returned before any callback fired.
  static Future<String?> sendOtp(String rawPhone) async {
    final phone = _normalize(rawPhone);
    final completer = Completer<String?>();

    // Fire-and-forget — don't await; the callbacks below complete the future.
    // ignore: unawaited_futures
    _auth
        .verifyPhoneNumber(
      phoneNumber: phone,
      timeout: const Duration(seconds: 60),
      verificationCompleted: (_) {
        // Auto-verified on Android (rare) — treat as success
        if (!completer.isCompleted) completer.complete(null);
      },
      verificationFailed: (e) {
        if (!completer.isCompleted) {
          completer.complete(
            e.message ?? 'OTP send nahi hua. Number check karein.',
          );
        }
      },
      codeSent: (verificationId, _) {
        _verificationId = verificationId;
        if (!completer.isCompleted) completer.complete(null);
      },
      codeAutoRetrievalTimeout: (verificationId) {
        _verificationId = verificationId;
        // This fires after timeout — only complete if nothing else did yet
        if (!completer.isCompleted) completer.complete(null);
      },
    )
        .catchError((e) {
      if (!completer.isCompleted) {
        completer.complete(e.toString());
      }
    });

    // Wait up to 30 s for a callback (safety net so UI never hangs forever)
    return completer.future.timeout(
      const Duration(seconds: 30),
      onTimeout: () {
        if (_verificationId != null) return null; // codeSent already fired
        return 'OTP timeout. Internet ya number check karein.';
      },
    );
  }

  // Returns true if OTP is correct
  static Future<bool> verifyOtp(String otp) async {
    if (_verificationId == null) return false;
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: otp,
      );
      await _auth.signInWithCredential(credential);
      return true;
    } catch (_) {
      return false;
    }
  }
}
