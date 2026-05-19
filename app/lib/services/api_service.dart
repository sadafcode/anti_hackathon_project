import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

class ApiService {
  // kIsWeb = Chrome/web uses localhost; Android emulator uses 10.0.2.2
  static String get baseUrl =>
      kIsWeb ? 'http://localhost:3000/api' : 'http://10.0.2.2:3000/api';
  static String sessionId = const Uuid().v4();

  // Accumulate Agent Traces globally across the entire UI flow
  static List<Map<String, dynamic>> globalAgentTraces = [];

  // Last discovered providers from discovery API — used for auto-reschedule on decline
  static List<Map<String, dynamic>> lastDiscoveredProviders = [];
  static Map<String, dynamic>? lastConfirmedIntent;

  // Decline-return mechanism: BookingWaitingScreen signals ChatScreen to show next provider
  static Map<String, dynamic>? pendingPostDeclineAction;
  static void Function()? _returnToChatCallback;
  static void registerReturnToChat(void Function() fn) { _returnToChatCallback = fn; }
  static void triggerReturnToChat() { _returnToChatCallback?.call(); }

  static void _extractTraces(Map<String, dynamic> json) {
    if (json.containsKey('agent_traces') && json['agent_traces'] is List) {
      for (var t in json['agent_traces'] as List) {
        globalAgentTraces.add(Map<String, dynamic>.from(t as Map));
      }
    }
  }

  static Future<Map<String, dynamic>> sendMessage(String message) async {
    final response = await http.post(
      Uri.parse('$baseUrl/chat'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'message': message, 'session_id': sessionId}),
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      _extractTraces(json);
      return json;
    } else {
      throw Exception('Failed to send message: ${response.body}');
    }
  }

  static Future<Map<String, dynamic>> discoverProviders(Map<String, dynamic> intent) async {
    final response = await http.post(
      Uri.parse('$baseUrl/discovery'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'intent': intent}),
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      _extractTraces(json);
      return json;
    } else {
      throw Exception('Failed to discover providers: ${response.body}');
    }
  }

  static Future<Map<String, dynamic>> getPricing(Map<String, dynamic> provider, Map<String, dynamic> intent, bool isReturningUser, {String? userId}) async {
    final response = await http.post(
      Uri.parse('$baseUrl/pricing'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'provider': provider,
        'intent': intent,
        'is_returning_user': isReturningUser,
        'user_id': userId,
      }),
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      _extractTraces(json);
      return json;
    } else {
      throw Exception('Failed to get pricing: ${response.body}');
    }
  }

  static Future<Map<String, dynamic>> acceptContract(
    String contractId,
    String party, {
    String? providerId,
    String? serviceType,
    int? amount,
    String? datetime,
    Map<String, dynamic>? intent,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/contract/accept'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'contract_id': contractId,
        'party': party,
        if (providerId != null) 'provider_id': providerId,
        if (serviceType != null) 'service_type': serviceType,
        if (amount != null) 'amount': amount,
        if (datetime != null) 'datetime': datetime,
        if (intent != null) 'intent': intent,
        'session_id': sessionId,
      }),
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      _extractTraces(json);
      return json;
    } else {
      throw Exception('Failed to accept contract: ${response.body}');
    }
  }

  static Future<Map<String, dynamic>> createBooking(Map<String, dynamic> request) async {
    final response = await http.post(
      Uri.parse('$baseUrl/booking'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(request),
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      _extractTraces(json);
      return json;
    } else {
      throw Exception('Failed to create booking: ${response.body}');
    }
  }

  static Future<Map<String, dynamic>> submitFeedback(Map<String, dynamic> request) async {
    final response = await http.post(
      Uri.parse('$baseUrl/feedback'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(request),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to submit feedback: ${response.body}');
    }
  }

  static Future<Map<String, dynamic>> submitDispute(Map<String, dynamic> request) async {
    final response = await http.post(
      Uri.parse('$baseUrl/dispute'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(request),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to submit dispute: ${response.body}');
    }
  }

  static Future<Map<String, dynamic>> resolveDispute(String disputeId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/dispute/resolve'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'dispute_id': disputeId}),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to resolve dispute: ${response.body}');
    }
  }

  static Future<Map<String, dynamic>> analyzeDispute(String disputeId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/dispute/analyze'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'dispute_id': disputeId}),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to analyze dispute: ${response.body}');
    }
  }

  static Future<Map<String, dynamic>> registerProvider(Map<String, dynamic> providerData) async {
    final response = await http.post(
      Uri.parse('$baseUrl/provider/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(providerData),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to register provider: ${response.body}');
    }
  }

  static Future<List<dynamic>> getPendingBookings(String providerId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/provider/$providerId/pending-bookings'),
      headers: {'Content-Type': 'application/json'},
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to fetch pending bookings: ${response.body}');
    }
  }

  static Future<Map<String, dynamic>> respondToBooking(String bookingId, String providerId, String action, {String? reason}) async {
    final response = await http.post(
      Uri.parse('$baseUrl/booking/respond'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'booking_id': bookingId,
        'provider_id': providerId,
        'action': action,
        'reason': reason,
      }),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to respond to booking: ${response.body}');
    }
  }

  static Future<Map<String, dynamic>> rescheduleBooking({
    required String declinedBookingId,
    required Map<String, dynamic> nextProvider,
    required Map<String, dynamic> intent,
    required Map<String, dynamic> pricing,
    required List<Map<String, dynamic>> allRankedProviders,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/booking/reschedule'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'declined_booking_id': declinedBookingId,
        'next_provider': nextProvider,
        'intent': intent,
        'pricing': pricing,
        'all_ranked_providers': allRankedProviders,
        'client_session_id': sessionId,
      }),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to reschedule: ${response.body}');
    }
  }

  static Future<void> applyPenalty(String providerId) async {
    await http.post(
      Uri.parse('$baseUrl/providers/$providerId/apply-penalty'),
      headers: {'Content-Type': 'application/json'},
    );
  }

  static Future<Map<String, dynamic>> cancelAfterAccept(String bookingId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/booking/cancel-after-accept'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'booking_id': bookingId}),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to cancel booking: ${response.body}');
    }
  }

  /// Submit a star rating + review for a provider after service completion.
  /// This updates the provider's rating in providers.json on the backend.
  static Future<Map<String, dynamic>> rateProvider({
    required String providerId,
    required String bookingId,
    required int stars,
    String reviewText = '',
    String clientName = 'Anonymous',
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/providers/$providerId/rate'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'stars': stars,
        'review_text': reviewText,
        'client_name': clientName,
        'booking_id': bookingId,
      }),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to submit rating: ${response.body}');
    }
  }

  /// Save FCM token to backend (so backend can send push notifications)
  static Future<void> saveNotificationToken({
    required String token,
    required String role,
    required String id,
  }) async {
    try {
      await http.post(
        Uri.parse('$baseUrl/fcm/save-token'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'token': token, 'role': role, 'id': id}),
      );
    } catch (_) {}
  }

  /// Get booked time slots for a provider (to show availability in UI)
  static Future<List<String>> getProviderBookedSlots(String providerId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/providers/$providerId/booked-slots'),
      headers: {'Content-Type': 'application/json'},
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return List<String>.from(data['booked_slots'] ?? []);
    } else {
      throw Exception('Failed to get booked slots: ${response.body}');
    }
  }
}
