class Review {
  final String reviewer;
  final String text;
  final double rating;
  final String sentiment;
  final String date;

  const Review({
    required this.reviewer,
    required this.text,
    required this.rating,
    required this.sentiment,
    required this.date,
  });
}

class ProviderModel {
  final String id;
  final String name;
  final List<String> serviceTypes;
  final bool blueTick;
  final double rating;
  final int totalReviews;
  final String reviewSentiment;
  final int experienceYears;
  final List<String> certifications;
  final List<String> toolsAvailable;
  final String area;
  final double hourlyRate;
  final int onTimeScore;
  final int cancellationRate;
  final int capacityToday;
  final String riskScore;
  final int strikes;
  final bool isMock;
  final double distanceKm;
  final int rankScore;
  final String rankReason;
  final List<Review> recentReviews;
  final int colorIndex;
  final String? photoUrl;
  final String gender;
  final Map<String, List<String>> availability;
  final Map<String, dynamic> coordinates;

  const ProviderModel({
    required this.id,
    required this.name,
    required this.serviceTypes,
    required this.blueTick,
    required this.rating,
    required this.totalReviews,
    required this.reviewSentiment,
    required this.experienceYears,
    required this.certifications,
    required this.toolsAvailable,
    required this.area,
    required this.hourlyRate,
    required this.onTimeScore,
    required this.cancellationRate,
    required this.capacityToday,
    required this.riskScore,
    required this.strikes,
    required this.isMock,
    required this.distanceKm,
    required this.rankScore,
    required this.rankReason,
    required this.recentReviews,
    required this.colorIndex,
    required this.coordinates,
    this.photoUrl,
    this.gender = 'male',
    this.availability = const {},
  });

  factory ProviderModel.fromJson(Map<String, dynamic> json) {
    return ProviderModel(
      id: json['id'] ?? '',
      name: json['name'] ?? 'Unknown',
      serviceTypes: List<String>.from(json['service_types'] ?? []),
      blueTick: json['blue_tick'] ?? false,
      rating: (json['rating'] ?? 0).toDouble(),
      totalReviews: json['total_reviews'] ?? 0,
      reviewSentiment: json['review_sentiment'] ?? 'neutral',
      experienceYears: json['experience_years'] ?? 0,
      certifications: [],
      toolsAvailable: [],
      area: json['area'] ?? '',
      hourlyRate: (json['hourly_rate'] ?? 0).toDouble(),
      onTimeScore: json['on_time_score'] ?? 0,
      cancellationRate: json['cancellation_rate'] ?? 0,
      capacityToday: json['capacity_today'] ?? 0,
      riskScore: json['risk_score'] ?? 'low',
      strikes: json['strikes'] ?? 0,
      isMock: false,
      distanceKm: 2.0, // Mock distance
      rankScore: json['calculated_score'] ?? 0,
      rankReason: json['ranking_reason'] ?? '',
      recentReviews: [],
      colorIndex: 0,
      coordinates: json['coordinates'] ?? {'lat': 33.7215, 'lng': 73.0433},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'service_types': serviceTypes,
      'blue_tick': blueTick,
      'rating': rating,
      'total_reviews': totalReviews,
      'review_sentiment': reviewSentiment,
      'experience_years': experienceYears,
      'area': area,
      'hourly_rate': hourlyRate,
      'on_time_score': onTimeScore,
      'cancellation_rate': cancellationRate,
      'capacity_today': capacityToday,
      'risk_score': riskScore,
      'strikes': strikes,
      'calculated_score': rankScore,
      'ranking_reason': rankReason,
      'coordinates': coordinates,
    };
  }

  String get initials => name.split(' ').map((w) => w[0]).take(2).join();
  String get displayPrice => 'Rs. ${hourlyRate.toInt()} - ${(hourlyRate * 1.5).toInt()}';
  String get displayDistance => '${distanceKm.toStringAsFixed(1)} km';
  bool get hasStrike => strikes > 0;
  String get experienceText => '$experienceYears saal ka tajurba';
  String get onTimeText => '$onTimeScore% waqt par aate hain';
  String get cancellationText => '$cancellationRate% cancellation';
}
