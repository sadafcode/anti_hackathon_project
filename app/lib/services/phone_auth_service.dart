import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class PhoneAuthService {
  static final _auth = FirebaseAuth.instance;
  static String? _verificationId;
  static bool _webDemoMode = false;

  // Test numbers for Chrome/web demo
  static const _testNumbers = ['03492083169', '03100017745', '+923492083169', '+923100017745'];
  static const _testOtp = '123456';

  static String _normalize(String phone) {
    phone = phone.replaceAll(RegExp(r'[\s\-()+]'), '');
    if (phone.startsWith('92')) return '+$phone';
    if (phone.startsWith('0')) return '+92${phone.substring(1)}';
    if (!phone.startsWith('+')) return '+92$phone';
    return phone;
  }

  static Future<String?> sendOtp(String rawPhone) async {
    // Chrome/web: Firebase verifyPhoneNumber not supported — use demo bypass
    if (kIsWeb) {
      final clean = rawPhone.replaceAll(RegExp(r'[\s\-()+]'), '');
      final isTest = _testNumbers.any((t) => t.replaceAll(RegExp(r'[\s\-()+]'), '') == clean);
      if (isTest) {
        _webDemoMode = true;
        return null; // success — OTP "sent"
      }
      return 'On Chrome, only test numbers work: 03492083169 or 03100017745';
    }

    final phone = _normalize(rawPhone);
    final completer = Completer<String?>();

    // ignore: unawaited_futures
    _auth
        .verifyPhoneNumber(
      phoneNumber: phone,
      timeout: const Duration(seconds: 60),
      verificationCompleted: (_) {
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
        if (!completer.isCompleted) completer.complete(null);
      },
    )
        .catchError((e) {
      if (!completer.isCompleted) {
        completer.complete(e.toString());
      }
    });

    return completer.future.timeout(
      const Duration(seconds: 30),
      onTimeout: () {
        if (_verificationId != null) return null;
        return 'OTP timeout. Internet ya number check karein.';
      },
    );
  }

  static Future<bool> verifyOtp(String otp) async {
    // Chrome/web demo bypass
    if (kIsWeb && _webDemoMode) {
      return otp == _testOtp;
    }

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
