import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';

class TestModeService {
  static bool isEnabled = false;

  // Mock booking shown in provider notification screen when no real booking exists
  static Map<String, dynamic> get mockBooking => {
        'id': 'BK-DEMO-TEST01',
        'area': 'G-13',
        'fullAddress': 'House 42, Street 5, G-13/2, Islamabad',
        'serviceType': 'ac_repair',
        'serviceDetails': 'AC not cooling, needs gas refill and deep cleaning',
        'datetime':
            DateTime.now().add(const Duration(days: 1)).toIso8601String(),
        'amount': 1498,
      };

  // Pre-filled booking ID for dispute demo
  static const String mockDisputeBookingId = 'BK-DEMO-TEST01';

  // Mock dispute description
  static const String mockDisputeDescription =
      'Provider overcharged me Rs. 200 more than the agreed price of Rs. 1498. '
      'The quoted price was Rs. 1498 but I was charged Rs. 1698 at the end.';

  // Quick chat queries for judges — all required fields included to avoid follow-ups
  static const List<Map<String, String>> quickQueries = [
    {
      'label': '❄️ AC Repair',
      'text':
          'AC gas khatam ho gayi hai aur cooling bilkul nahi ho rahi, kal subah 10 baje G-13 mein House 42, Street 5 par AC technician chahiye, gas refill aur cleaning karwani hai, budget 1500 rupees se zyada nahi',
    },
    {
      'label': '🔧 Plumber',
      'text':
          'Bathroom mein main pipe leak ho rahi hai aur pani bahar aa raha hai, aaj shaam 5 baje F-10 mein House 12, Street 3 par plumber chahiye, pipe repair karni hai, urgent',
    },
    {
      'label': '📚 Tutor',
      'text':
          'Bachay ko English aur Math ki tuition chahiye, kal subah 9 baje I-8 mein House 7, Street 2 par aake padhaye, class 10 ka student hai, Math aur English weak hain',
    },
  ];

  // Mock provider registration data
  static Map<String, dynamic> get mockProviderData => {
        'name': 'Zafar Khan',
        'phone': '03001234567',
        'nic': '3520198765432',
        'experience': '5',
        'rateBasic': '700',
        'rateIntermediate': '900',
        'rateComplex': '1200',
        'certifications': 'AC Technician Diploma, Electrical Wiring Certificate',
        'area': 'G-13',
        'services': ['ac_repair', 'electrician'],
        'tools': ['multimeter', 'drill', 'gas kit'],
      };

  // Auto-accept mock booking in Firestore so BookingWaitingScreen advances
  static Future<void> simulateProviderAccept(String bookingId) async {
    await Future.delayed(const Duration(seconds: 3));
    try {
      await FirebaseFirestore.instance
          .collection('bookings')
          .doc(bookingId)
          .set({'status': 'confirmed'}, SetOptions(merge: true));
    } catch (_) {}
  }
}
