import 'package:flutter/material.dart';
import '../models/provider_model.dart';
import '../theme/app_theme.dart';
import '../widgets/provider_avatar.dart';

class ProviderProfileScreen extends StatelessWidget {
  final ProviderModel provider;

  const ProviderProfileScreen({super.key, required this.provider});


  @override
  Widget build(BuildContext context) {
    final p = provider;
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
                  _buildHeroSection(context, p),
                  if (p.hasStrike) _buildStrikeBanner(p),
                  _buildStatsRow(p),
                  _buildSection('Service Types', _buildServiceChips(p)),
                  if (p.certifications.isNotEmpty)
                    _buildSection('Certifications', _buildTextList(p.certifications)),
                  if (p.toolsAvailable.isNotEmpty)
                    _buildSection('Tools Available', _buildTextList(p.toolsAvailable)),
                  _buildSection('Area Coverage', _buildAreaInfo(p)),
                  _buildSection('Recent Reviews', _buildReviews(p)),
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

  Widget _buildHeroSection(BuildContext context, ProviderModel p) {
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
                const Icon(Icons.verified, color: Color(0xFF64B5F6), size: 22),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: p.blueTick
                  ? Colors.white.withValues(alpha: 0.2)
                  : Colors.orange.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              p.blueTick ? 'NADRA Verified ✓' : 'Unverified — proceed with caution',
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ..._buildStars(p.rating),
              const SizedBox(width: 6),
              Text(
                '${p.rating}  (${p.totalReviews} reviews)',
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStrikeBanner(ProviderModel p) {
    return Container(
      width: double.infinity,
      color: Colors.orange.shade100,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.orange.shade800, size: 18),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              'Is provider ne confirm booking ${p.strikes} baar cancel ki hai',
              style: TextStyle(color: Colors.orange.shade900, fontSize: 13),
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
          _statItem('${p.experienceYears} saal', 'Tajurba'),
          _divider(),
          _statItem('${p.onTimeScore}%', 'On-Time'),
          _divider(),
          _statItem('${p.cancellationRate}%', 'Cancellation'),
          _divider(),
          _statItem(
            p.riskScore.toUpperCase(),
            'Risk Level',
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
        Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.textGrey)),
      ],
    );
  }

  Widget _divider() => Container(width: 1, height: 32, color: Colors.grey.shade200);

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
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppTheme.textDark,
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  Widget _buildServiceChips(ProviderModel p) {
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: p.serviceTypes.map((s) {
        final label = s.replaceAll('_', ' ').split(' ').map((w) {
          return w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : w;
        }).join(' ');
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppTheme.primaryLight,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppTheme.primary,
              fontWeight: FontWeight.w500,
            ),
          ),
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
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: AppTheme.background,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Text(item, style: const TextStyle(fontSize: 12, color: AppTheme.textDark)),
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
            const Icon(Icons.location_on, color: AppTheme.primary, size: 16),
            const SizedBox(width: 6),
            Text('Base Area: ${p.area}',
                style: const TextStyle(fontSize: 13, color: AppTheme.textDark)),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            const Icon(Icons.payments_outlined, color: AppTheme.primary, size: 16),
            const SizedBox(width: 6),
            Text('Rate: ${p.displayPrice}/hr',
                style: const TextStyle(fontSize: 13, color: AppTheme.textDark)),
          ],
        ),
      ],
    );
  }

  Widget _buildReviews(ProviderModel p) {
    return Column(
      children: p.recentReviews.map((r) {
        final isPositive = r.sentiment == 'positive';
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isPositive
                ? Colors.green.shade50
                : Colors.red.shade50,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isPositive ? Colors.green.shade100 : Colors.red.shade100,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    r.reviewer,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isPositive ? Colors.green.shade800 : Colors.red.shade800,
                    ),
                  ),
                  const Spacer(),
                  ..._buildStars(r.rating, size: 13),
                  const SizedBox(width: 4),
                  Text(
                    r.date,
                    style: const TextStyle(fontSize: 11, color: AppTheme.textGrey),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                r.text,
                style: const TextStyle(fontSize: 12, color: AppTheme.textDark, height: 1.4),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildAvailability(ProviderModel p) {
    const dayKeys = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];
    const dayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
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
                color: isAvailable ? AppTheme.primaryLight : Colors.grey.shade100,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isAvailable ? AppTheme.primary : Colors.grey.shade300,
                ),
              ),
              child: Center(
                child: Text(
                  dayLabels[i],
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: isAvailable ? AppTheme.primary : Colors.grey.shade400,
                  ),
                ),
              ),
            ),
            if (isAvailable) ...[
              const SizedBox(height: 4),
              Text(
                '${slots.length}',
                style: TextStyle(fontSize: 9, color: AppTheme.primary),
              ),
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
                child: const Text(
                  'Wapas Jao',
                  style: TextStyle(color: AppTheme.textGrey, fontSize: 15),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: ElevatedButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${p.name} ke saath booking — jald aa raha hai!'),
                      backgroundColor: AppTheme.primary,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  elevation: 0,
                ),
                child: const Text(
                  'Book Karo',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
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
