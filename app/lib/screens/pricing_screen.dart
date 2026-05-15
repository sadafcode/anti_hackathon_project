import 'package:flutter/material.dart';
import '../models/provider_model.dart';
import '../models/pricing_model.dart';
import '../theme/app_theme.dart';
import '../widgets/provider_avatar.dart';
import '../services/api_service.dart';
import 'booking_confirmation_screen.dart';

class PricingScreen extends StatelessWidget {
  final ProviderModel provider;
  final PricingModel pricing;

  PricingScreen({
    super.key,
    required this.provider,
    PricingModel? pricing,
  }) : pricing = pricing ?? PricingModel.fromProvider(provider);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Price Details'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildProviderHeader(),
                  const SizedBox(height: 16),
                  _buildBreakdownCard(),
                  const SizedBox(height: 12),
                  _buildFairnessCard(),
                  const SizedBox(height: 12),
                  _buildBudgetAlternativeCard(context),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
          _buildBottomBar(context),
        ],
      ),
    );
  }

  Widget _buildProviderHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          ProviderAvatar(provider: provider, radius: 26),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      provider.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textDark,
                      ),
                    ),
                    if (provider.blueTick) ...[
                      const SizedBox(width: 5),
                      const Icon(Icons.verified, color: Colors.blue, size: 17),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  provider.serviceTypes
                      .map((s) => s.replaceAll('_', ' '))
                      .join(', '),
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppTheme.textGrey,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppTheme.primaryLight,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${provider.rankScore}/100',
              style: const TextStyle(
                color: AppTheme.primary,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBreakdownCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Price Breakdown',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppTheme.textDark,
            ),
          ),
          const SizedBox(height: 14),
          _lineItem('Base Rate (1 hr)', pricing.baseRate),
          const SizedBox(height: 10),
          _lineItem(
            'Urgency Fee  (${pricing.urgencyLabel})',
            pricing.urgencyFee,
            prefix: '+',
          ),
          const SizedBox(height: 10),
          _lineItem(
            'Distance Cost  (${provider.displayDistance})',
            pricing.distanceCost,
            prefix: '+',
          ),
          const SizedBox(height: 10),
          _lineItem(
            'Complexity  (${pricing.complexityLabel})',
            pricing.complexityFee,
            prefix: '+',
          ),
          const SizedBox(height: 10),
          if (pricing.surgeApplied)
            _lineItem('Surge Pricing  (Peak hours)', pricing.surgeAmount,
                prefix: '+')
          else
            _lineItemNote('Surge Pricing', 'Lagu nahi'),
          const SizedBox(height: 10),
          _lineItem(
            'Loyalty Discount',
            pricing.loyaltyDiscount,
            prefix: '-',
            color: Colors.green.shade700,
          ),
          const SizedBox(height: 14),
          Divider(color: Colors.grey.shade200),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textDark,
                ),
              ),
              Text(
                'Rs. ${pricing.total}',
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFairnessCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.handshake_outlined,
                  size: 16, color: Colors.green.shade700),
              const SizedBox(width: 6),
              Text(
                'Fair Pricing — Provider Share',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.green.shade800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _fairnessRow(
            'Provider ko milega',
            'Rs. ${pricing.providerReceives}',
            Colors.green.shade700,
          ),
          const SizedBox(height: 6),
          _fairnessRow(
            'Platform fee',
            'Rs. ${pricing.platformFee}',
            AppTheme.textGrey,
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pricing.providerPercent / 100,
              backgroundColor: Colors.green.shade100,
              valueColor: AlwaysStoppedAnimation(Colors.green.shade600),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Provider ko ${pricing.providerPercent}% milta hai — fair share',
            style: TextStyle(fontSize: 11, color: Colors.green.shade700),
          ),
        ],
      ),
    );
  }

  Widget _buildBudgetAlternativeCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.savings_outlined,
                  size: 16, color: Colors.amber.shade800),
              const SizedBox(width: 6),
              Text(
                'Budget Option',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.amber.shade900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            pricing.budgetAlternativeDesc,
            style: TextStyle(
              fontSize: 13,
              color: Colors.amber.shade900,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Rs. ${pricing.budgetAlternativePrice}',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Colors.amber.shade900,
                ),
              ),
              OutlinedButton(
                onPressed: () => _confirmBudgetOption(context),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.amber.shade400),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                ),
                child: Text(
                  'Yeh Chahiye',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.amber.shade900,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total amount:',
                  style: TextStyle(fontSize: 13, color: AppTheme.textGrey),
                ),
                Text(
                  'Rs. ${pricing.total}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textDark,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _confirmBudgetOption(context),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.grey.shade300),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text(
                      'Budget Option\nChahiye',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textGrey,
                        height: 1.3,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: () => _acceptPrice(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Yeh Price Accept Karo',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _lineItem(String label, int amount,
      {String prefix = '', Color? color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Text(
            label,
            style: const TextStyle(fontSize: 13, color: AppTheme.textGrey),
          ),
        ),
        Text(
          '$prefix Rs. $amount',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: color ?? AppTheme.textDark,
          ),
        ),
      ],
    );
  }

  Widget _lineItemNote(String label, String note) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 13, color: AppTheme.textGrey),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            note,
            style: const TextStyle(fontSize: 11, color: AppTheme.textGrey),
          ),
        ),
      ],
    );
  }

  Widget _fairnessRow(String label, String value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 13, color: AppTheme.textGrey)),
        Text(
          value,
          style:
              TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: color),
        ),
      ],
    );
  }

  void _acceptPrice(BuildContext context) async {
    
    // Quick local state update trick for stateless widget: 
    // We can't setState, so we'll show a loading dialog instead
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );
    
    try {
      final mockIntent = {
        'service_type': provider.serviceTypes.isNotEmpty ? provider.serviceTypes.first : 'other',
        'location': {'area': provider.area, 'city': 'Islamabad'},
        'datetime': DateTime.now().add(const Duration(days: 1)).toIso8601String(),
        'urgency': 'medium',
        'budget_sensitive': false,
        'job_complexity': 'basic'
      };
      
      final req = {
        'provider': provider.toJson(),
        'intent': mockIntent,
        'pricing': {
           'base_rate': pricing.baseRate,
           'total': pricing.total,
        },
        'mock_action': 'accept'
      };
      
      final response = await ApiService.createBooking(req);
      final providerId = response['provider_id'];
      final bookingId = response['booking_id'];
      
      if (context.mounted) {
        Navigator.pop(context); // close dialog
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => BookingConfirmationScreen(
              provider: provider,
              pricing: pricing,
              providerId: providerId,
              bookingId: bookingId,
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  void _confirmBudgetOption(BuildContext context) async {
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );
    
    final budgetPricing = PricingModel(
      baseRate: pricing.budgetAlternativePrice,
      urgencyFee: 0,
      distanceCost: pricing.distanceCost,
      complexityFee: 0,
      surgeApplied: false,
      surgeAmount: 0,
      loyaltyDiscount: 0,
      total: pricing.budgetAlternativePrice + pricing.distanceCost,
      providerReceives:
          ((pricing.budgetAlternativePrice + pricing.distanceCost) * 0.90)
              .round(),
      platformFee:
          ((pricing.budgetAlternativePrice + pricing.distanceCost) * 0.10)
              .round(),
      budgetAlternativeDesc: pricing.budgetAlternativeDesc,
      budgetAlternativePrice: pricing.budgetAlternativePrice,
      urgencyLabel: 'N/A',
      complexityLabel: 'Basic (×1.0)',
    );
    
    try {
      final mockIntent = {
        'service_type': provider.serviceTypes.isNotEmpty ? provider.serviceTypes.first : 'other',
        'location': {'area': provider.area, 'city': 'Islamabad'},
        'datetime': DateTime.now().add(const Duration(days: 1)).toIso8601String(),
        'urgency': 'medium',
        'budget_sensitive': true,
        'job_complexity': 'basic'
      };
      
      final req = {
        'provider': provider.toJson(),
        'intent': mockIntent,
        'pricing': {
           'base_rate': budgetPricing.baseRate,
           'total': budgetPricing.total,
        },
        'mock_action': 'accept'
      };
      
      final response = await ApiService.createBooking(req);
      final providerId = response['provider_id'];
      final bookingId = response['booking_id'];
      
      if (context.mounted) {
        Navigator.pop(context); // close dialog
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => BookingConfirmationScreen(
              provider: provider,
              pricing: budgetPricing,
              isBudgetOption: true,
              providerId: providerId,
              bookingId: bookingId,
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }
}
