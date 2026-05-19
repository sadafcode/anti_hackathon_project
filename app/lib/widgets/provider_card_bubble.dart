import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import '../models/provider_model.dart';
import '../theme/app_theme.dart';
import '../screens/provider_profile_screen.dart';
import '../screens/pricing_screen.dart';
import '../models/pricing_model.dart';
import '../services/api_service.dart';
import 'provider_avatar.dart';

class ProviderCardBubble extends StatefulWidget {
  final ProviderModel provider;
  final VoidCallback? onShowAlternative;
  final String? requestedDatetime; // ISO datetime to check day availability
  final String? serviceDetails;    // What client described — shown as scope
  final void Function(PricingModel pricing, String contractId) onContractCreated;

  const ProviderCardBubble({
    super.key,
    required this.provider,
    required this.onContractCreated,
    this.onShowAlternative,
    this.requestedDatetime,
    this.serviceDetails,
  });

  @override
  State<ProviderCardBubble> createState() => _ProviderCardBubbleState();
}

class _ProviderCardBubbleState extends State<ProviderCardBubble> {
  bool _reasoningExpanded = false;
  bool _isSavingCard = false;
  final GlobalKey _cardKey = GlobalKey();

  static const _dayNames = [
    'sunday', 'monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday'
  ];
  static const _dayLabels = [
    'Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'
  ];

  /// Returns the requested weekday name (lowercase) if the provider is NOT
  /// available that day, otherwise null.
  String? get _unavailableDay {
    final dt = widget.requestedDatetime;
    if (dt == null) return null;
    try {
      final parsed = DateTime.parse(dt);
      final dayName = _dayNames[parsed.weekday % 7]; // DateTime.weekday: 1=Mon..7=Sun
      final slots = widget.provider.availability[dayName];
      if (slots == null || slots.isEmpty) return _dayLabels[parsed.weekday % 7];
    } catch (_) {}
    return null;
  }

  Future<void> _saveCardAsImage() async {
    setState(() => _isSavingCard = true);
    try {
      final boundary = _cardKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;
      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;
      // Show success snackbar — actual file-save requires a plugin (gallery_saver / path_provider)
      // For now we capture the image in memory and confirm to the user.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Card capture ho gaya! Save karne ke liye gallery_saver plugin add karein.'),
            backgroundColor: AppTheme.primary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSavingCard = false);
    }
  }

  void _openProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProviderProfileScreen(
          provider: widget.provider,
          onContractCreated: widget.onContractCreated,
        ),
      ),
    );
  }

  bool _isBooking = false;

  void _openPricing() async {
    if (_isBooking) return;
    setState(() => _isBooking = true);
    
    try {
      final intent = ApiService.lastConfirmedIntent ?? {
        'service_type': widget.provider.serviceTypes.isNotEmpty ? widget.provider.serviceTypes.first : 'other',
        'location': {'area': widget.provider.area, 'city': 'Islamabad'},
        'datetime': DateTime.now().add(const Duration(days: 1)).toIso8601String(),
        'urgency': 'medium',
        'budget_sensitive': false,
        'job_complexity': 'basic',
      };

      final providerJson = widget.provider.toJson();
      final pricingJson = await ApiService.getPricing(
        providerJson,
        intent,
        false,
        userId: ApiService.sessionId,
      );
      final pricingModel = PricingModel.fromJson(pricingJson);
      final contractId = pricingJson['contract_id'] as String? ?? '';

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PricingScreen(
              provider: widget.provider,
              pricing: pricingModel,
              contractId: contractId,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading pricing: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isBooking = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.provider;
    return Align(
      alignment: Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          RepaintBoundary(
            key: _cardKey,
            child: Container(
              margin: const EdgeInsets.only(left: 8, right: 12, bottom: 0),
              constraints: const BoxConstraints(maxWidth: 400),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildHeader(p),
                  _buildInfoRow(p),
                  _buildReasoningTile(p),
                  if (widget.serviceDetails != null && widget.serviceDetails!.isNotEmpty)
                    _buildScopeBanner(widget.serviceDetails!),
                  if (_unavailableDay != null) _buildDayUnavailableBanner(_unavailableDay!),
                  if (p.hasStrike) _buildStrikeBanner(p),
                  _buildButtons(p),
                ],
              ),
            ),
          ),
          _buildSaveSection(),
        ],
      ),
    );
  }

  Widget _buildHeader(ProviderModel p) {
    return GestureDetector(
      onTap: _openProfile,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: _openProfile,
              child: ProviderAvatar(provider: p, radius: 28),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          p.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1A1A1A),
                          ),
                        ),
                      ),
                      if (p.blueTick) ...[
                        const SizedBox(width: 4),
                        const Icon(Icons.verified, color: Colors.blue, size: 18),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  _buildStarRow(p.rating, p.reviewSentiment),
                  const SizedBox(height: 2),
                  Text(
                    p.totalReviews == 0
                        ? '${p.experienceYears} saal ka tajurba'
                        : '${p.totalReviews} reviews  •  ${p.experienceYears} saal ka tajurba',
                    style: const TextStyle(fontSize: 11, color: Color(0xFF999999)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStarRow(double rating, String reviewSentiment) {
    if (rating == 0 || reviewSentiment == 'unrated') {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ...List.generate(5, (_) =>
              const Icon(Icons.star_border, color: Colors.grey, size: 15)),
          const SizedBox(width: 4),
          const Text(
            'Nayi registration',
            style: TextStyle(fontSize: 11, color: Color(0xFF999999)),
          ),
        ],
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ...List.generate(5, (i) {
          if (i < rating.floor()) {
            return const Icon(Icons.star, color: Colors.amber, size: 15);
          } else if (i < rating) {
            return const Icon(Icons.star_half, color: Colors.amber, size: 15);
          }
          return const Icon(Icons.star_border, color: Colors.amber, size: 15);
        }),
        const SizedBox(width: 4),
        Text(
          rating.toStringAsFixed(1),
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF444444),
          ),
        ),
      ],
    );
  }

  Widget _coloredChip(String tierLabel, String priceLabel, Color bgColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '$tierLabel: $priceLabel',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: textColor,
        ),
      ),
    );
  }

  Widget _buildInfoRow(ProviderModel p) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _chip(Icons.location_on_outlined, p.displayDistance),
          _coloredChip('B', 'Rs.${p.rateBasic.toInt()}', const Color(0xFFE2F0D9), const Color(0xFF385723)),
          _coloredChip('I', 'Rs.${p.rateIntermediate.toInt()}', const Color(0xFFFFF2CC), const Color(0xFF7F6000)),
          _coloredChip('C', 'Rs.${p.rateComplex.toInt()}', const Color(0xFFFCE4D6), const Color(0xFFC65911)),
          _chip(Icons.schedule, '${p.onTimeScore}% on-time'),
        ],
      ),
    );
  }

  Widget _chip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppTheme.textGrey),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.textGrey)),
        ],
      ),
    );
  }

  Widget _buildReasoningTile(ProviderModel p) {
    return Column(
      children: [
        Divider(height: 1, color: Colors.grey.shade100),
        InkWell(
          onTap: () => setState(() => _reasoningExpanded = !_reasoningExpanded),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                const Icon(Icons.psychology_outlined, size: 15, color: AppTheme.primary),
                const SizedBox(width: 6),
                const Text(
                  'Kyun select kiya?',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppTheme.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                Icon(
                  _reasoningExpanded
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  size: 16,
                  color: AppTheme.primary,
                ),
              ],
            ),
          ),
        ),
        if (_reasoningExpanded)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
            child: Text(
              p.rankReason,
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.textGrey,
                height: 1.5,
              ),
            ),
          ),
        Divider(height: 1, color: Colors.grey.shade100),
      ],
    );
  }

  Widget _buildScopeBanner(String details) {
    final serviceName = widget.provider.serviceTypes.isNotEmpty
        ? widget.provider.serviceTypes.first.replaceAll('_', ' ')
        : 'service';
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 8, 14, 0),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F7FF),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF2196F3).withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.receipt_long_outlined, color: Color(0xFF1565C0), size: 14),
              SizedBox(width: 5),
              Text(
                'Tey Shuda Booking Details',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1565C0),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          _scopeRow('Service', serviceName),
          const SizedBox(height: 3),
          _scopeRow('Kaam', details),
        ],
      ),
    );
  }

  Widget _scopeRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label: ',
          style: const TextStyle(
            fontSize: 11,
            color: Color(0xFF1565C0),
            fontWeight: FontWeight.w600,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 11, color: Color(0xFF1A1A1A), height: 1.4),
          ),
        ),
      ],
    );
  }

  Widget _buildSaveSection() {
    return Container(
      margin: const EdgeInsets.only(left: 8, right: 12, top: 6, bottom: 8),
      constraints: const BoxConstraints(maxWidth: 400),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 6),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 13, color: Colors.grey.shade600),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    'Is card ka screenshot lein — dispute file karte waqt yeh booking summary evidence ke tor par kaam aaye gi.',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade700, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _isSavingCard ? null : _saveCardAsImage,
              icon: _isSavingCard
                  ? SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary),
                    )
                  : const Icon(Icons.download_outlined, size: 16, color: AppTheme.primary),
              label: const Text(
                'Card Download Karein',
                style: TextStyle(fontSize: 13, color: AppTheme.primary, fontWeight: FontWeight.w600),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: AppTheme.primary.withValues(alpha: 0.6)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 9),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDayUnavailableBanner(String dayLabel) {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 8, 14, 0),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.amber.shade300),
      ),
      child: Row(
        children: [
          Icon(Icons.event_busy_outlined, color: Colors.amber.shade700, size: 15),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              '$dayLabel ko available nahi — koi aur din chunein',
              style: TextStyle(fontSize: 11, color: Colors.amber.shade800, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStrikeBanner(ProviderModel p) {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 8, 14, 0),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700, size: 14),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              'Is provider ne pehle ${p.strikes} baar cancel kiya hai',
              style: TextStyle(fontSize: 11, color: Colors.orange.shade700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildButtons(ProviderModel p) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: widget.onShowAlternative,
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.grey.shade300),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
              child: const Text(
                'Dosre Dekhein',
                style: TextStyle(fontSize: 13, color: AppTheme.textGrey),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: ElevatedButton(
              onPressed: _openPricing,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 10),
                elevation: 0,
              ),
              child: _isBooking
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text(
                      'Book Karo',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
