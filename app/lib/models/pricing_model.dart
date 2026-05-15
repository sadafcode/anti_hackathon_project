import 'provider_model.dart';

class PricingModel {
  final int baseRate;
  final int urgencyFee;
  final int distanceCost;
  final int complexityFee;
  final bool surgeApplied;
  final int surgeAmount;
  final int loyaltyDiscount;
  final int total;
  final int providerReceives;
  final int platformFee;
  final String budgetAlternativeDesc;
  final int budgetAlternativePrice;
  final String urgencyLabel;
  final String complexityLabel;

  const PricingModel({
    required this.baseRate,
    required this.urgencyFee,
    required this.distanceCost,
    required this.complexityFee,
    required this.surgeApplied,
    required this.surgeAmount,
    required this.loyaltyDiscount,
    required this.total,
    required this.providerReceives,
    required this.platformFee,
    required this.budgetAlternativeDesc,
    required this.budgetAlternativePrice,
    required this.urgencyLabel,
    required this.complexityLabel,
  });

  int get providerPercent => (providerReceives / total * 100).round();

  factory PricingModel.fromProvider(ProviderModel provider) {
    final base = provider.hourlyRate.toInt();
    final urgency = (base * 0.30).round();
    final distance = (provider.distanceKm * 30).round();
    final complexity = ((base + urgency) * 0.20).round();
    const surge = false;
    const surgeAmt = 0;
    const loyalty = 50;

    final subtotal = base + urgency + distance + complexity + surgeAmt - loyalty;
    final platform = (subtotal * 0.10).round().clamp(100, 9999);
    final providerEarns = subtotal - platform;

    return PricingModel(
      baseRate: base,
      urgencyFee: urgency,
      distanceCost: distance,
      complexityFee: complexity,
      surgeApplied: surge,
      surgeAmount: surgeAmt,
      loyaltyDiscount: loyalty,
      total: subtotal,
      providerReceives: providerEarns,
      platformFee: platform,
      budgetAlternativeDesc: 'Basic diagnostic check sirf',
      budgetAlternativePrice: (base * 0.75).round(),
      urgencyLabel: 'High (+30%)',
      complexityLabel: 'Intermediate (×1.2)',
    );
  }

  factory PricingModel.fromJson(Map<String, dynamic> json) {
    return PricingModel(
      baseRate: json['base_rate'] ?? 0,
      urgencyFee: json['urgency_fee'] ?? 0,
      distanceCost: json['distance_cost'] ?? 0,
      complexityFee: ((json['base_rate'] ?? 0) * ((json['complexity_factor'] ?? 1.0) - 1.0)).round(),
      surgeApplied: json['surge_applied'] ?? false,
      surgeAmount: json['surge_fee'] ?? 0,
      loyaltyDiscount: json['loyalty_discount'] ?? 0,
      total: json['total'] ?? 0,
      providerReceives: json['provider_earning'] ?? 0,
      platformFee: json['platform_fee'] ?? 0,
      budgetAlternativeDesc: json['budget_alternative'] != null ? json['budget_alternative']['description'] : 'Basic diagnostic check sirf',
      budgetAlternativePrice: json['budget_alternative'] != null ? json['budget_alternative']['price'] : 0,
      urgencyLabel: 'Urgency',
      complexityLabel: 'Complexity x${json['complexity_factor'] ?? 1.0}',
    );
  }
}
