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
    this.photoUrl,
    this.gender = 'male',
    this.availability = const {},
  });

  String get initials => name.split(' ').map((w) => w[0]).take(2).join();
  String get displayPrice => 'Rs. ${hourlyRate.toInt()} - ${(hourlyRate * 1.5).toInt()}';
  String get displayDistance => '${distanceKm.toStringAsFixed(1)} km';
  bool get hasStrike => strikes > 0;
  String get experienceText => '$experienceYears saal ka tajurba';
  String get onTimeText => '$onTimeScore% waqt par aate hain';
  String get cancellationText => '$cancellationRate% cancellation';
}
