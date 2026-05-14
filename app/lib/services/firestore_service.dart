import 'package:cloud_firestore/cloud_firestore.dart';
import '../data/mock_providers.dart';
import '../models/provider_model.dart';

class FirestoreService {
  static final _db = FirebaseFirestore.instance;
  static final _providers = _db.collection('providers');
  static final _bookings = _db.collection('bookings');

  // Seed mock providers into Firestore
  static Future<void> seedProviders() async {
    final batch = _db.batch();
    for (final p in mockProviders) {
      final ref = _providers.doc(p.id);
      batch.set(ref, _providerToMap(p), SetOptions(merge: true));
    }
    await batch.commit();
  }

  // Fetch all providers from Firestore
  static Future<List<ProviderModel>> fetchProviders() async {
    final snap = await _providers.get();
    return snap.docs.map((doc) => _mapToProvider(doc)).toList();
  }

  // Fetch providers by service type
  static Future<List<ProviderModel>> fetchProvidersByService(String serviceType) async {
    final snap = await _providers
        .where('serviceTypes', arrayContains: serviceType)
        .get();
    final list = snap.docs.map((doc) => _mapToProvider(doc)).toList();
    list.sort((a, b) => b.rankScore.compareTo(a.rankScore));
    return list;
  }

  // Save a new booking
  static Future<String> createBooking(Map<String, dynamic> bookingData) async {
    final ref = await _bookings.add({
      ...bookingData,
      'createdAt': FieldValue.serverTimestamp(),
      'status': 'pending',
    });
    return ref.id;
  }

  // Update provider after booking (capacity, etc.)
  static Future<void> updateProviderCapacity(String providerId) async {
    await _providers.doc(providerId).update({
      'capacityToday': FieldValue.increment(-1),
    });
  }

  static Map<String, dynamic> _providerToMap(ProviderModel p) {
    return {
      'id': p.id,
      'name': p.name,
      'serviceTypes': p.serviceTypes,
      'blueTick': p.blueTick,
      'rating': p.rating,
      'totalReviews': p.totalReviews,
      'reviewSentiment': p.reviewSentiment,
      'experienceYears': p.experienceYears,
      'certifications': p.certifications,
      'toolsAvailable': p.toolsAvailable,
      'area': p.area,
      'hourlyRate': p.hourlyRate,
      'onTimeScore': p.onTimeScore,
      'cancellationRate': p.cancellationRate,
      'capacityToday': p.capacityToday,
      'riskScore': p.riskScore,
      'strikes': p.strikes,
      'isMock': p.isMock,
      'distanceKm': p.distanceKm,
      'rankScore': p.rankScore,
      'rankReason': p.rankReason,
      'colorIndex': p.colorIndex,
      'gender': p.gender,
      'photoUrl': p.photoUrl ?? '',
      'recentReviews': p.recentReviews.map((r) => {
        'reviewer': r.reviewer,
        'text': r.text,
        'rating': r.rating,
        'sentiment': r.sentiment,
        'date': r.date,
      }).toList(),
    };
  }

  static ProviderModel _mapToProvider(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return ProviderModel(
      id: d['id'] ?? doc.id,
      name: d['name'] ?? '',
      serviceTypes: List<String>.from(d['serviceTypes'] ?? []),
      blueTick: d['blueTick'] ?? false,
      rating: (d['rating'] ?? 0).toDouble(),
      totalReviews: d['totalReviews'] ?? 0,
      reviewSentiment: d['reviewSentiment'] ?? 'positive',
      experienceYears: d['experienceYears'] ?? 0,
      certifications: List<String>.from(d['certifications'] ?? []),
      toolsAvailable: List<String>.from(d['toolsAvailable'] ?? []),
      area: d['area'] ?? '',
      hourlyRate: (d['hourlyRate'] ?? 0).toDouble(),
      onTimeScore: d['onTimeScore'] ?? 0,
      cancellationRate: d['cancellationRate'] ?? 0,
      capacityToday: d['capacityToday'] ?? 0,
      riskScore: d['riskScore'] ?? 'low',
      strikes: d['strikes'] ?? 0,
      isMock: d['isMock'] ?? true,
      distanceKm: (d['distanceKm'] ?? 0).toDouble(),
      rankScore: d['rankScore'] ?? 0,
      rankReason: d['rankReason'] ?? '',
      colorIndex: d['colorIndex'] ?? 0,
      gender: d['gender'] ?? 'male',
      photoUrl: d['photoUrl'],
      recentReviews: ((d['recentReviews'] ?? []) as List).map((r) => Review(
        reviewer: r['reviewer'] ?? '',
        text: r['text'] ?? '',
        rating: (r['rating'] ?? 0).toDouble(),
        sentiment: r['sentiment'] ?? 'positive',
        date: r['date'] ?? '',
      )).toList(),
    );
  }
}
