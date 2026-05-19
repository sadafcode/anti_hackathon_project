import 'package:cloud_firestore/cloud_firestore.dart';

class BookingFirestoreService {
  static final _db = FirebaseFirestore.instance;
  static const _bookingsCol = 'bookings';
  static const _reviewsCol = 'reviews';
  static const _providerStatsCol = 'provider_stats';

  // ─────────────────────────────────────────────
  // BOOKING CREATION (atomic — prevents double booking)
  // ─────────────────────────────────────────────

  /// Creates a booking only if no confirmed/pending booking exists for this
  /// provider within a 75-minute window. Returns null if conflict detected.
  static Future<String?> createBookingAtomically({
    required String bookingId,
    required String providerId,
    required String providerName,
    required String serviceType,
    required String area,
    required int amount,
    required String datetime,
    String? serviceDetails,
    String? fullAddress,
    String? houseNumber,
    String? street,
  }) async {
    final docRef = _db.collection(_bookingsCol).doc(bookingId);

    try {
      await _db.runTransaction((tx) async {
        // Check for existing confirmed/pending bookings for this provider
        final existing = await _db
            .collection(_bookingsCol)
            .where('providerId', isEqualTo: providerId)
            .where('status', whereIn: ['pending', 'confirmed'])
            .get();

        final requestedTime = DateTime.parse(datetime);
        for (final doc in existing.docs) {
          final data = doc.data();
          final existingDatetimeStr = data['datetimeIso'] as String?;
          if (existingDatetimeStr == null) continue;
          final existingTime = DateTime.tryParse(existingDatetimeStr);
          if (existingTime == null) continue;
          final diffMins = requestedTime.difference(existingTime).inMinutes.abs();
          if (diffMins < 75) {
            // CONFLICT — abort transaction
            throw Exception('SLOT_CONFLICT:${doc.id}');
          }
        }

        // No conflict — create the booking
        tx.set(docRef, {
          'id': bookingId,
          'providerId': providerId,
          'providerName': providerName,
          'serviceType': serviceType,
          'area': area,
          'amount': amount,
          'datetime': datetime,
          'datetimeIso': datetime,
          'serviceDetails': serviceDetails,
          'fullAddress': fullAddress,
          'houseNumber': houseNumber,
          'street': street,
          'status': 'pending',
          'declineReason': null,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });
      return bookingId;
    } on FirebaseException catch (e) {
      if (e.message?.contains('SLOT_CONFLICT') == true) return null;
      rethrow;
    } catch (e) {
      if (e.toString().contains('SLOT_CONFLICT')) return null;
      rethrow;
    }
  }

  /// Non-atomic create (fallback, used when providerId is missing)
  static Future<void> createBooking({
    required String bookingId,
    required String providerId,
    required String providerName,
    required String serviceType,
    required String area,
    required int amount,
    required String datetime,
  }) async {
    await _db.collection(_bookingsCol).doc(bookingId).set({
      'id': bookingId,
      'providerId': providerId,
      'providerName': providerName,
      'serviceType': serviceType,
      'area': area,
      'amount': amount,
      'datetime': datetime,
      'datetimeIso': datetime,
      'status': 'pending',
      'declineReason': null,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ─────────────────────────────────────────────
  // BOOKING STATUS STREAMS
  // ─────────────────────────────────────────────

  static Stream<DocumentSnapshot<Map<String, dynamic>>> bookingStatusStream(
      String bookingId) {
    return _db.collection(_bookingsCol).doc(bookingId).snapshots();
  }

  static Stream<QuerySnapshot<Map<String, dynamic>>> providerBookingsStream(
      String providerId) {
    return _db
        .collection(_bookingsCol)
        .where('providerId', isEqualTo: providerId)
        .where('status', isEqualTo: 'pending')
        .snapshots();
  }

  /// Stream of ALL non-cancelled bookings for a provider (to show booked slots in UI)
  static Stream<QuerySnapshot<Map<String, dynamic>>> providerActiveBookingsStream(
      String providerId) {
    return _db
        .collection(_bookingsCol)
        .where('providerId', isEqualTo: providerId)
        .where('status', whereIn: ['pending', 'confirmed'])
        .snapshots();
  }

  // ─────────────────────────────────────────────
  // BOOKING ACTIONS
  // ─────────────────────────────────────────────

  static Future<void> acceptBooking(String bookingId) async {
    await _db.collection(_bookingsCol).doc(bookingId).update({
      'status': 'confirmed',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> declineBooking(String bookingId, String reason) async {
    await _db.collection(_bookingsCol).doc(bookingId).update({
      'status': 'declined',
      'declineReason': reason,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> cancelBooking(String bookingId) async {
    await _db.collection(_bookingsCol).doc(bookingId).update({
      'status': 'cancelled',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> markCompleted(String bookingId) async {
    await _db.collection(_bookingsCol).doc(bookingId).update({
      'status': 'completed',
      'completedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ─────────────────────────────────────────────
  // PROVIDER STATS
  // ─────────────────────────────────────────────

  static Future<void> incrementProviderCancellations(String providerId) async {
    await _db.collection(_providerStatsCol).doc(providerId).set({
      'cancellations': FieldValue.increment(1),
      'lastCancellation': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static Stream<DocumentSnapshot<Map<String, dynamic>>> providerStatsStream(
      String providerId) {
    return _db.collection(_providerStatsCol).doc(providerId).snapshots();
  }

  // ─────────────────────────────────────────────
  // REVIEWS — real reviews from clients
  // ─────────────────────────────────────────────

  /// Submit a review after service completion.
  /// Also updates the aggregate rating in provider_stats.
  static Future<void> submitReview({
    required String providerId,
    required String bookingId,
    required int stars,
    required String reviewText,
    required String clientName,
  }) async {
    final reviewRef = _db.collection(_reviewsCol).doc();
    final statsRef = _db.collection(_providerStatsCol).doc(providerId);

    await _db.runTransaction((tx) async {
      final statsSnap = await tx.get(statsRef);
      final existing = statsSnap.data();

      final oldTotal = (existing?['totalReviews'] as int?) ?? 0;
      final oldSum = ((existing?['ratingSum'] as num?) ?? 0).toDouble();
      final newTotal = oldTotal + 1;
      final newSum = oldSum + stars;
      final newAvg = double.parse((newSum / newTotal).toStringAsFixed(2));

      // Save review document
      tx.set(reviewRef, {
        'providerId': providerId,
        'bookingId': bookingId,
        'stars': stars,
        'reviewText': reviewText,
        'clientName': clientName,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Update aggregate stats
      tx.set(statsRef, {
        'totalReviews': newTotal,
        'ratingSum': newSum,
        'averageRating': newAvg,
        'lastReviewAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }

  /// Stream of reviews for a provider (newest first via createdAt desc)
  static Stream<QuerySnapshot<Map<String, dynamic>>> reviewsStream(
      String providerId) {
    return _db
        .collection(_reviewsCol)
        .where('providerId', isEqualTo: providerId)
        .snapshots();
  }

  /// One-time fetch of latest N reviews
  static Future<List<Map<String, dynamic>>> getLatestReviews(
      String providerId, {int limit = 5}) async {
    final snap = await _db
        .collection(_reviewsCol)
        .where('providerId', isEqualTo: providerId)
        .limit(limit)
        .get();
    return snap.docs.map((d) => d.data()).toList();
  }

  /// Check if a provider is booked at a given time (75-min buffer).
  /// Returns the conflicting booking ID if conflict exists, null otherwise.
  static Future<String?> checkSlotConflict(
      String providerId, DateTime requestedTime) async {
    final snap = await _db
        .collection(_bookingsCol)
        .where('providerId', isEqualTo: providerId)
        .where('status', whereIn: ['pending', 'confirmed'])
        .get();

    for (final doc in snap.docs) {
      final data = doc.data();
      final isoStr = data['datetimeIso'] as String?;
      if (isoStr == null) continue;
      final booked = DateTime.tryParse(isoStr);
      if (booked == null) continue;
      final diffMins = requestedTime.difference(booked).inMinutes.abs();
      if (diffMins < 75) return doc.id;
    }
    return null;
  }
}
