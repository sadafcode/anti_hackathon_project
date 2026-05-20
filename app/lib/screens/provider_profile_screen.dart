import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/provider_model.dart';
import '../models/pricing_model.dart';
import '../services/booking_firestore_service.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/provider_avatar.dart';
import 'pricing_screen.dart';

class ProviderProfileScreen extends StatefulWidget {
  final ProviderModel provider;
  final void Function(PricingModel pricing, String contractId)? onContractCreated;

  const ProviderProfileScreen({
    super.key,
    required this.provider,
    this.onContractCreated,
  });

  @override
  State<ProviderProfileScreen> createState() => _ProviderProfileScreenState();
}

class _ProviderProfileScreenState extends State<ProviderProfileScreen> {
  // Live aggregate rating from Firestore provider_stats
  double? _liveRating;
  int? _liveTotalReviews;

  @override
  void initState() {
    super.initState();
    // Listen to aggregate stats for live rating update
    BookingFirestoreService.providerStatsStream(widget.provider.id)
        .listen((snap) {
      if (!mounted) return;
      final data = snap.data();
      if (data == null) return;
      final avg = (data['averageRating'] as num?)?.toDouble();
      final total = data['totalReviews'] as int?;
      if (avg != null || total != null) {
        setState(() {
          _liveRating = avg;
          _liveTotalReviews = total;
        });
      }
    });
  }

  double get _displayRating => _liveRating ?? widget.provider.rating;
  int get _displayTotalReviews =>
      _liveTotalReviews ?? widget.provider.totalReviews;

  @override
  Widget build(BuildContext context) {
    final p = widget.provider;
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Provider Profile'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeroSection(p),
                  if (p.hasStrike) _buildStrikeBanner(p),
                  _buildStatsRow(p),
                  _buildSection('Service Types', _buildServiceChips(p)),
                  _buildSection('Service Rates', _buildTieredRatesCard(p)),
                  if (p.certifications.isNotEmpty)
                    _buildSection(
                        'Certifications', _buildTextList(p.certifications)),
                  if (p.toolsAvailable.isNotEmpty)
                    _buildSection(
                        'Tools Available', _buildTextList(p.toolsAvailable)),
                  _buildSection('Area Coverage', _buildAreaInfo(p)),
                  // Reviews section — live from Firestore
                  _buildLiveReviewsSection(p),
                  _buildSection('Availability', _buildAvailability(p)),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
          _buildBottomBar(context, p),
        ],
      ),
    );
  }

  // ─────────────────────────── HERO ───────────────────────────
  Widget _buildHeroSection(ProviderModel p) {
    final isUnrated =
        _displayRating == 0 || p.reviewSentiment == 'unrated';

    return Container(
      width: double.infinity,
      color: AppTheme.primary,
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
      child: Column(
        children: [
          ProviderAvatar(provider: p, radius: 50),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                p.name,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              if (p.blueTick) ...[
                const SizedBox(width: 6),
                const Icon(Icons.verified,
                    color: Color(0xFF64B5F6), size: 22),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: p.blueTick
                  ? Colors.white.withValues(alpha: 0.2)
                  : Colors.orange.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              p.blueTick
                  ? 'NADRA Verified ✓'
                  : 'Unverified — proceed with caution',
              style:
                  const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
          const SizedBox(height: 14),
          if (isUnrated)
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.star_border, color: Colors.white70, size: 16),
                  SizedBox(width: 6),
                  Text(
                    'New registration — no reviews yet',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            )
          else
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ..._buildStars(_displayRating),
                const SizedBox(width: 6),
                Text(
                  '${_displayRating.toStringAsFixed(2)}  ($_displayTotalReviews reviews)',
                  style: const TextStyle(
                      color: Colors.white, fontSize: 14),
                ),
              ],
            ),
        ],
      ),
    );
  }

  // ─────────────────────────── LIVE REVIEWS SECTION ───────────────────────────
  Widget _buildLiveReviewsSection(ProviderModel p) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Reviews',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textDark,
                ),
              ),
              const Spacer(),
              if (_displayTotalReviews > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.star,
                          size: 12, color: Colors.amber.shade600),
                      const SizedBox(width: 4),
                      Text(
                        '${_displayRating.toStringAsFixed(2)} / 5',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: BookingFirestoreService.reviewsStream(p.id),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                );
              }

              final docs = snapshot.data?.docs ?? [];

              if (docs.isEmpty) {
                return _buildEmptyReviews();
              }

              // Sort by createdAt descending (newest first) client-side
              final sorted = [...docs];
              sorted.sort((a, b) {
                final aTs = a.data()['createdAt'] as Timestamp?;
                final bTs = b.data()['createdAt'] as Timestamp?;
                if (aTs == null || bTs == null) return 0;
                return bTs.compareTo(aTs);
              });

              // Map Firestore docs → existing Review model
              final reviews = sorted.take(10).map((doc) {
                final d = doc.data();
                final stars = (d['stars'] as int?) ?? 0;
                final ts = d['createdAt'] as Timestamp?;
                final date = ts != null
                    ? _formatDate(ts.toDate())
                    : 'Just now';
                final sentiment = stars >= 4
                    ? 'positive'
                    : stars >= 3
                        ? 'mostly_positive'
                        : 'negative';
                return Review(
                  reviewer: d['clientName'] as String? ?? 'Client',
                  text: (d['reviewText'] as String?)?.isNotEmpty == true
                      ? d['reviewText'] as String
                      : _defaultReviewText(stars),
                  rating: stars.toDouble(),
                  sentiment: sentiment,
                  date: date,
                );
              }).toList();

              // Use the EXISTING _buildReviews() with the loaded list
              return _buildReviews(reviews);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyReviews() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        children: [
          Icon(Icons.rate_review_outlined,
              size: 40, color: Colors.grey.shade300),
          const SizedBox(height: 10),
          const Text(
            'No reviews yet',
            style: TextStyle(fontSize: 13, color: AppTheme.textGrey),
          ),
          const SizedBox(height: 4),
          const Text(
            'Reviews will appear after the first booking',
            style: TextStyle(fontSize: 11, color: AppTheme.textGrey),
          ),
        ],
      ),
    );
  }

  // Existing _buildReviews — now takes a list parameter instead of p.recentReviews
  Widget _buildReviews(List<Review> reviews) {
    return Column(
      children: reviews.map((r) {
        final isPositive =
            r.sentiment == 'positive' || r.sentiment == 'mostly_positive';
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isPositive
                ? Colors.green.shade50
                : Colors.red.shade50,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isPositive
                  ? Colors.green.shade100
                  : Colors.red.shade100,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: isPositive
                        ? Colors.green.shade100
                        : Colors.red.shade100,
                    child: Text(
                      r.reviewer.isNotEmpty
                          ? r.reviewer[0].toUpperCase()
                          : 'C',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isPositive
                            ? Colors.green.shade700
                            : Colors.red.shade700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      r.reviewer,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isPositive
                            ? Colors.green.shade800
                            : Colors.red.shade800,
                      ),
                    ),
                  ),
                  ..._buildStars(r.rating, size: 13),
                  const SizedBox(width: 6),
                  Text(
                    r.date,
                    style: const TextStyle(
                        fontSize: 10, color: AppTheme.textGrey),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                r.text,
                style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textDark,
                    height: 1.4),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // ─────────────────────────── HELPERS ───────────────────────────
  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    if (diff.inDays < 30) return '${(diff.inDays / 7).floor()} weeks ago';
    return '${(diff.inDays / 30).floor()} months ago';
  }

  String _defaultReviewText(int stars) {
    return switch (stars) {
      5 => 'Excellent work, very satisfied!',
      4 => 'Good work, arrived on time.',
      3 => 'Decent, some things could have been better.',
      2 => 'Not very happy with the work, needs improvement.',
      _ => 'Not satisfied with the work.',
    };
  }

  // ─────────────────────────── REST OF WIDGETS (unchanged) ───────────────────────────
  Widget _buildStrikeBanner(ProviderModel p) {
    return Container(
      width: double.infinity,
      color: Colors.orange.shade100,
      padding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded,
              color: Colors.orange.shade800, size: 18),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              'This provider has cancelled ${p.strikes} confirmed booking(s)',
              style: TextStyle(
                  color: Colors.orange.shade900, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow(ProviderModel p) {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.symmetric(vertical: 16),
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
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _statItem('${p.experienceYears} yrs', 'Experience'),
          _statDivider(),
          _statItem('${p.onTimeScore}%', 'On-Time'),
          _statDivider(),
          _statItem('${p.cancellationRate}%', 'Cancellation'),
          _statDivider(),
          _statItem(
            p.riskScore.toUpperCase(),
            'Risk',
            color: p.riskScore == 'low'
                ? Colors.green
                : p.riskScore == 'medium'
                    ? Colors.orange
                    : Colors.red,
          ),
        ],
      ),
    );
  }

  Widget _statItem(String value, String label, {Color? color}) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color ?? AppTheme.textDark,
          ),
        ),
        const SizedBox(height: 2),
        Text(label,
            style: const TextStyle(
                fontSize: 11, color: AppTheme.textGrey)),
      ],
    );
  }

  Widget _statDivider() =>
      Container(width: 1, height: 32, color: Colors.grey.shade200);

  Widget _buildSection(String title, Widget child) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppTheme.textDark,
              )),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  Widget _buildTieredRatesCard(ProviderModel p) {
    return Column(
      children: [
        _buildTierRow(
          'Basic Service',
          'Simple work (e.g. minor checkups, quick fixes, cleaning)',
          'Rs. ${p.rateBasic.toInt()}',
          const Color(0xFFE2F0D9),
          const Color(0xFF385723),
        ),
        const SizedBox(height: 8),
        _buildTierRow(
          'Intermediate Service',
          'Moderate work (e.g. repairs, component replacement)',
          'Rs. ${p.rateIntermediate.toInt()}',
          const Color(0xFFFFF2CC),
          const Color(0xFF7F6000),
        ),
        const SizedBox(height: 8),
        _buildTierRow(
          'Complex Service',
          'Complex work (e.g. master installation, major overhauls)',
          'Rs. ${p.rateComplex.toInt()}',
          const Color(0xFFFCE4D6),
          const Color(0xFFC65911),
        ),
      ],
    );
  }

  Widget _buildTierRow(
      String title, String description, String price, Color bgColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textDark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppTheme.textGrey,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              price,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServiceChips(ProviderModel p) {
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: p.serviceTypes.map((s) {
        final label = s
            .replaceAll('_', ' ')
            .split(' ')
            .map((w) => w.isNotEmpty
                ? '${w[0].toUpperCase()}${w.substring(1)}'
                : w)
            .join(' ');
        return Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppTheme.primaryLight,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(label,
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.primary,
                fontWeight: FontWeight.w500,
              )),
        );
      }).toList(),
    );
  }

  Widget _buildTextList(List<String> items) {
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: items.map((item) {
        return Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: AppTheme.background,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Text(item,
              style: const TextStyle(
                  fontSize: 12, color: AppTheme.textDark)),
        );
      }).toList(),
    );
  }

  Widget _buildAreaInfo(ProviderModel p) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.location_on,
                color: AppTheme.primary, size: 16),
            const SizedBox(width: 6),
            Text('Base Area: ${p.area}',
                style: const TextStyle(
                    fontSize: 13, color: AppTheme.textDark)),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            const Icon(Icons.payments_outlined,
                color: AppTheme.primary, size: 16),
            const SizedBox(width: 6),
            Text('Rate: ${p.displayPrice}/hr',
                style: const TextStyle(
                    fontSize: 13, color: AppTheme.textDark)),
          ],
        ),
      ],
    );
  }

  Widget _buildAvailability(ProviderModel p) {
    const dayKeys = [
      'monday', 'tuesday', 'wednesday', 'thursday',
      'friday', 'saturday', 'sunday'
    ];
    const dayLabels = [
      'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'
    ];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: List.generate(7, (i) {
        final slots = p.availability[dayKeys[i]] ?? [];
        final isAvailable = slots.isNotEmpty;
        return Column(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isAvailable
                    ? AppTheme.primaryLight
                    : Colors.grey.shade100,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isAvailable
                      ? AppTheme.primary
                      : Colors.grey.shade300,
                ),
              ),
              child: Center(
                child: Text(
                  dayLabels[i],
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: isAvailable
                        ? AppTheme.primary
                        : Colors.grey.shade400,
                  ),
                ),
              ),
            ),
            if (isAvailable) ...[
              const SizedBox(height: 4),
              Text('${slots.length}',
                  style: TextStyle(
                      fontSize: 9, color: AppTheme.primary)),
            ],
          ],
        );
      }),
    );
  }

  Widget _buildBottomBar(BuildContext context, ProviderModel p) {
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
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.grey.shade300),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('Go Back',
                    style: TextStyle(
                        color: AppTheme.textGrey, fontSize: 15)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: ElevatedButton(
                onPressed: () async {
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (ctx) => const Center(child: CircularProgressIndicator()),
                  );

                  try {
                    final mockIntent = {
                      'service_type': p.serviceTypes.isNotEmpty ? p.serviceTypes.first : 'other',
                      'location': {'area': p.area, 'city': 'Islamabad'},
                      'datetime': DateTime.now().add(const Duration(days: 1)).toIso8601String(),
                      'urgency': 'medium',
                      'budget_sensitive': false,
                      'job_complexity': 'basic'
                    };

                    final pricingJson = await ApiService.getPricing(
                      p.toJson(), 
                      mockIntent, 
                      false, 
                      userId: ApiService.sessionId,
                    );
                    final pricingModel = PricingModel.fromJson(pricingJson);
                    final contractId = pricingJson['contract_id'] as String? ?? '';

                    if (context.mounted) {
                      Navigator.pop(context); // Close loading
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PricingScreen(
                            provider: p,
                            pricing: pricingModel,
                            contractId: contractId,
                          ),
                        ),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      Navigator.pop(context); // Close loading
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error loading pricing: $e')),
                      );
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  elevation: 0,
                ),
                child: const Text('Book Now',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    )),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildStars(double rating, {double size = 14}) {
    return List.generate(5, (i) {
      if (i < rating.floor()) {
        return Icon(Icons.star, color: Colors.amber, size: size);
      } else if (i < rating) {
        return Icon(Icons.star_half, color: Colors.amber, size: size);
      }
      return Icon(Icons.star_border, color: Colors.amber, size: size);
    });
  }
}
