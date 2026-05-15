import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

class ApiService {
  // Use 10.0.2.2 for Android emulator to access localhost
  // Or localhost for web/iOS simulator
  static const String baseUrl = 'http://10.0.2.2:3000/api';
  static String sessionId = const Uuid().v4();

  static Future<Map<String, dynamic>> sendMessage(String message) async {
    final response = await http.post(
      Uri.parse('$baseUrl/chat'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'message': message, 'session_id': sessionId}),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
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
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to discover providers: ${response.body}');
    }
  }

  static Future<Map<String, dynamic>> getPricing(Map<String, dynamic> provider, Map<String, dynamic> intent, bool isReturningUser) async {
    final response = await http.post(
      Uri.parse('$baseUrl/pricing'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'provider': provider,
        'intent': intent,
        'is_returning_user': isReturningUser
      }),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to get pricing: ${response.body}');
    }
  }

  static Future<Map<String, dynamic>> createBooking(Map<String, dynamic> request) async {
    final response = await http.post(
      Uri.parse('$baseUrl/booking'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(request),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
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
}
