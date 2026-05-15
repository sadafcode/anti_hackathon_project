import 'dart:async';

import 'package:flutter/material.dart';
import '../models/provider_model.dart';
import '../models/pricing_model.dart';
import '../theme/app_theme.dart';
import '../widgets/provider_avatar.dart';
import 'provider_notification_screen.dart';

class BookingConfirmationScreen extends StatefulWidget {
  final ProviderModel provider;
  final PricingModel pricing;
  final bool isBudgetOption;
  final String? providerId;
  final String bookingId;

  const BookingConfirmationScreen({
    super.key,
    required this.provider,
    required this.pricing,
    required this.bookingId,
    this.isBudgetOption = false,
    this.providerId,
  });

  @override
  State<BookingConfirmationScreen> createState() =>
      _BookingConfirmationScreenState();
}

class _BookingConfirmationScreenState
    extends State<BookingConfirmationScreen>
    with SingleTickerProviderStateMixin {
  late final DateTime _appointmentTime;
  late Duration _remaining;
  Timer? _timer;
  late AnimationController _checkController;
  late Animation<double> _checkScale;

  @override
  void initState() {
    super.initState();

    // Mock: tomorrow at 10:00 AM
    final now = DateTime.now();
    _appointmentTime =
        DateTime(now.year, now.month, now.day + 1, 10, 0, 0);
    _remaining = _appointmentTime.difference(DateTime.now());

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      final r = _appointmentTime.difference(DateTime.now());
      if (mounted) setState(() => _remaining = r.isNegative ? Duration.zero : r);
    });

    _checkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _checkScale = CurvedAnimation(
      parent: _checkController,
      curve: Curves.elasticOut,
    );
    _checkController.forward();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _checkController.dispose();
    super.dispose();
  }

  String get _countdownText {
    final h = _remaining.inHours;
    final m = _remaining.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = _remaining.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  String get _appointmentDateText {
    const months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return 'Kal, ${_appointmentTime.day} ${months[_appointmentTime.month]} ${_appointmentTime.year}';
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.provider;
    final pr = widget.pricing;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Booking Confirmed'),
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildSuccessBadge(),
            const SizedBox(height: 16),
            _buildReceiptCard(p, pr),
            const SizedBox(height: 12),
            _buildCountdownCard(),
            const SizedBox(height: 12),
            _buildNotificationsCard(),
            const SizedBox(height: 28),
            _buildHomeButton(context),
            const SizedBox(height: 12),
            if (widget.providerId != null) _buildProviderDemoButton(context),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildSuccessBadge() {
    return ScaleTransition(
      scale: _checkScale,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: AppTheme.primary,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Column(
          children: [
            Icon(Icons.check_circle, color: Colors.white, size: 56),
            SizedBox(height: 10),
            Text(
              'Booking Ho Gayi!',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Provider ko notification bhej di gayi hai',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReceiptCard(ProviderModel p, PricingModel pr) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          // Receipt header — provider
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.primaryLight,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                ProviderAvatar(provider: p, radius: 26),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            p.name,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textDark,
                            ),
                          ),
                          if (p.blueTick) ...[
                            const SizedBox(width: 5),
                            const Icon(Icons.verified,
                                color: Colors.blue, size: 17),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        p.serviceTypes
                            .map((s) => s.replaceAll('_', ' '))
                            .join(', '),
                        style: const TextStyle(
                            fontSize: 12, color: AppTheme.textGrey),
                      ),
                    ],
                  ),
                ),
                _buildRatingBadge(p.rating),
              ],
            ),
          ),

          // Booking ID banner
          Container(
            width: double.infinity,
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: AppTheme.textDark,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Booking ID',
                  style: TextStyle(color: Colors.white60, fontSize: 12),
                ),
                Text(
                  widget.bookingId,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),

          // Receipt details
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _receiptRow(
                  Icons.build_outlined,
                  'Service',
                  p.serviceTypes.first
                      .replaceAll('_', ' ')
                      .split(' ')
                      .map((w) => w.isNotEmpty
                          ? '${w[0].toUpperCase()}${w.substring(1)}'
                          : w)
                      .join(' '),
                ),
                _dottedDivider(),
                _receiptRow(
                  Icons.calendar_today_outlined,
                  'Date',
                  _appointmentDateText,
                ),
                _dottedDivider(),
                _receiptRow(
                  Icons.access_time_outlined,
                  'Time',
                  '10:00 AM',
                ),
                _dottedDivider(),
                _receiptRow(
                  Icons.location_on_outlined,
                  'Location',
                  'G-13, Islamabad',
                ),
                _dottedDivider(),
                _receiptRow(
                  Icons.payments_outlined,
                  'Amount Paid',
                  'Rs. ${pr.total}',
                  valueStyle: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.primary,
                  ),
                ),
                if (widget.isBudgetOption) ...[
                  _dottedDivider(),
                  _receiptRow(
                    Icons.savings_outlined,
                    'Option',
                    'Budget Option',
                    valueStyle: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.amber.shade800,
                    ),
                  ),
                ],
                _dottedDivider(),
                _receiptRow(
                  Icons.pending_actions,
                  'Status',
                  'Pending — Waiting for provider',
                  valueStyle: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.orange.shade800,
                  ),
                  iconColor: Colors.orange.shade800,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCountdownCard() {
    final totalSecs = const Duration(hours: 20).inSeconds;
    final remainSecs = _remaining.inSeconds.clamp(0, totalSecs);
    final progress = remainSecs / totalSecs;

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
          Row(
            children: [
              const Icon(Icons.timer_outlined,
                  size: 16, color: AppTheme.primary),
              const SizedBox(width: 6),
              const Text(
                'Appointment mein baki',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              _countdownText,
              style: const TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.w900,
                color: AppTheme.primary,
                letterSpacing: 3,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: AppTheme.primaryLight,
              valueColor:
                  const AlwaysStoppedAnimation(AppTheme.primary),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Appointment: Kal, 10:00 AM',
            style: const TextStyle(fontSize: 11, color: AppTheme.textGrey),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationsCard() {
    return Container(
      padding: const EdgeInsets.all(14),
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
          const Text(
            'Notifications Bhej Di Gayi Hain',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppTheme.textDark,
            ),
          ),
          const SizedBox(height: 10),
          _notifRow(
            Icons.chat_outlined,
            'WhatsApp',
            'Provider aur aapko message bhej diya',
            Colors.green.shade600,
          ),
          const SizedBox(height: 8),
          _notifRow(
            Icons.notifications_outlined,
            'Push Notification',
            'Provider ka phone buzz ho raha hai',
            Colors.blue.shade600,
          ),
          const SizedBox(height: 8),
          _notifRow(
            Icons.receipt_outlined,
            'Receipt',
            'Aapke WhatsApp par receipt aa gayi',
            Colors.purple.shade600,
          ),
        ],
      ),
    );
  }

  Widget _buildHomeButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () => Navigator.popUntil(context, (r) => r.isFirst),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primary,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          padding: const EdgeInsets.symmetric(vertical: 16),
          elevation: 0,
        ),
        child: const Text(
          'Home Jao',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _buildProviderDemoButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ProviderNotificationScreen(
                providerId: widget.providerId!,
              ),
            ),
          );
        },
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: AppTheme.primary),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
        child: const Text(
          'Provider Screen Dekhein (Demo)',
          style: TextStyle(
            color: AppTheme.primary,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _receiptRow(
    IconData icon,
    String label,
    String value, {
    TextStyle? valueStyle,
    Color iconColor = AppTheme.textGrey,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 15, color: iconColor),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(fontSize: 13, color: AppTheme.textGrey),
          ),
          const Spacer(),
          Text(
            value,
            style: valueStyle ??
                const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textDark,
                ),
          ),
        ],
      ),
    );
  }

  Widget _dottedDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: List.generate(
          40,
          (i) => Expanded(
            child: Container(
              height: 1,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              color: i.isEven ? Colors.grey.shade200 : Colors.transparent,
            ),
          ),
        ),
      ),
    );
  }

  Widget _notifRow(
      IconData icon, String channel, String desc, Color color) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                channel,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textDark,
                ),
              ),
              Text(
                desc,
                style: const TextStyle(
                    fontSize: 11, color: AppTheme.textGrey),
              ),
            ],
          ),
        ),
        Icon(Icons.check_circle, size: 16, color: color),
      ],
    );
  }

  Widget _buildRatingBadge(double rating) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.amber.shade200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.star, size: 13, color: Colors.amber.shade700),
          const SizedBox(width: 3),
          Text(
            rating.toStringAsFixed(1),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Colors.amber.shade800,
            ),
          ),
        ],
      ),
    );
  }
}
