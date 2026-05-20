import 'dart:async';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/provider_model.dart';
import 'agent_trace_screen.dart';
import 'service_tracking_screen.dart';
import '../models/pricing_model.dart';
import '../services/api_service.dart';
import '../services/booking_firestore_service.dart';
import '../services/test_mode_service.dart';
import '../theme/app_theme.dart';
import '../widgets/provider_avatar.dart';
enum _Phase { waiting, confirmed, declined, rescheduling, noProvider }

class BookingWaitingScreen extends StatefulWidget {
  final String bookingId;
  final String providerId;
  final ProviderModel provider;
  final PricingModel pricing;
  final bool isBudgetOption;

  const BookingWaitingScreen({
    super.key,
    required this.bookingId,
    required this.providerId,
    required this.provider,
    required this.pricing,
    this.isBudgetOption = false,
  });

  @override
  State<BookingWaitingScreen> createState() => _BookingWaitingScreenState();
}

class _BookingWaitingScreenState extends State<BookingWaitingScreen>
    with TickerProviderStateMixin {
  _Phase _phase = _Phase.waiting;

  String? _declineReason;

  late AnimationController _pulseController;
  late Animation<double> _pulse;
  late AnimationController _successController;
  late Animation<double> _successScale;

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _sub;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.9, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _successController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _successScale = CurvedAnimation(
      parent: _successController,
      curve: Curves.elasticOut,
    );

    _listenToBooking();
    if (TestModeService.isEnabled) {
      TestModeService.simulateProviderAccept(widget.bookingId);
    }
  }

  void _listenToBooking() {
    _sub = BookingFirestoreService.bookingStatusStream(widget.bookingId)
        .listen((snap) {
      if (!mounted) return;
      final data = snap.data();
      if (data == null) return;
      final status = data['status'] as String? ?? 'pending';

      if (status == 'confirmed' && _phase == _Phase.waiting) {
        _pulseController.stop();
        _successController.forward();
        setState(() => _phase = _Phase.confirmed);
      } else if ((status == 'declined' || status == 'cancelled') &&
          _phase == _Phase.waiting) {
        _declineReason = data['declineReason'] as String?;
        setState(() => _phase = _Phase.declined);
        Future.delayed(const Duration(milliseconds: 1500), _handleDecline);
      }
    });
  }

  Future<void> _handleDecline() async {
    if (!mounted) return;

    // Step 1 — find next provider from cached ranked list (no API call needed)
    final allProviders = ApiService.lastDiscoveredProviders;
    final nextJson = allProviders.firstWhere(
      (p) => p['id'] != widget.provider.id,
      orElse: () => <String, dynamic>{},
    );

    if (nextJson.isEmpty) {
      if (mounted) setState(() => _phase = _Phase.noProvider);
      return;
    }

    setState(() => _phase = _Phase.rescheduling);

    try {
      final nextProvider = ProviderModel.fromJson(nextJson);
      final intent = ApiService.lastConfirmedIntent ?? {};

      // Step 2 — pricing: try API with timeout, fallback to local calc
      PricingModel pricing;
      try {
        final pr = await ApiService.getPricing(nextJson, intent, false)
            .timeout(const Duration(seconds: 8));
        pricing = PricingModel.fromJson(pr);
      } catch (_) {
        pricing = PricingModel.fromProvider(nextProvider);
      }

      if (!mounted) return;

      // Step 3 — create booking in backend store + send FCM to new provider
      final resp = await ApiService.rescheduleBooking(
        declinedBookingId: widget.bookingId,
        nextProvider: nextJson,
        intent: intent,
        pricing: {'total': pricing.total, 'base_rate': pricing.baseRate},
        allRankedProviders: allProviders,
      ).timeout(const Duration(seconds: 10));

      if (!mounted) return;

      final newBookingId = resp['booking_id'] as String? ??
          'BK-${const Uuid().v4().substring(0, 8).toUpperCase()}';

      // Step 4 — Firestore entry so real-time stream works on the new screen
      await BookingFirestoreService.createBookingAtomically(
        bookingId: newBookingId,
        providerId: nextProvider.id,
        providerName: nextProvider.name,
        serviceType: intent['service_type'] as String? ?? nextProvider.serviceTypes.first,
        area: nextProvider.area,
        amount: pricing.total,
        datetime: intent['datetime'] as String? ??
            DateTime.now().add(const Duration(days: 1)).toIso8601String(),
        serviceDetails: intent['service_details'] as String?,
      );

      if (!mounted) return;

      // Step 5 — navigate to new waiting screen (replaces current screen)
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => BookingWaitingScreen(
            bookingId: newBookingId,
            providerId: nextProvider.id,
            provider: nextProvider,
            pricing: pricing,
          ),
        ),
      );
    } catch (_) {
      if (mounted) setState(() => _phase = _Phase.noProvider);
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _pulseController.dispose();
    _successController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _phase == _Phase.confirmed,
      child: Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(
          title: Text(_appBarTitle),
          automaticallyImplyLeading: _phase != _Phase.waiting,
          actions: [
            IconButton(
              tooltip: 'Agent Trace',
              icon: const Icon(Icons.account_tree_outlined, color: Colors.white),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AgentTraceScreen()),
              ),
            ),
          ],
        ),
        body: AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          child: _buildBody(),
        ),
      ),
    );
  }

  String get _appBarTitle => switch (_phase) {
    _Phase.waiting      => 'Sending Request',
    _Phase.confirmed    => 'Booking Confirmed!',
    _Phase.declined     => 'Provider Busy',
    _Phase.rescheduling => 'Finding Another Provider',
    _Phase.noProvider   => 'No Provider Found',
  };

  Widget _buildBody() => switch (_phase) {
    _Phase.waiting      => _buildWaiting(),
    _Phase.confirmed    => _buildConfirmed(),
    _Phase.declined     => _buildDeclined(),
    _Phase.rescheduling => _buildRescheduling(),
    _Phase.noProvider   => _buildNoProvider(),
  };

  // ─────────────────────────── WAITING ───────────────────────────
  Widget _buildWaiting() {
    return Center(
      key: const ValueKey('waiting'),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ScaleTransition(
              scale: _pulse,
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: AppTheme.primaryLight,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primary.withValues(alpha: 0.3),
                      blurRadius: 20,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: Center(
                  child: ProviderAvatar(provider: widget.provider, radius: 38),
                ),
              ),
            ),
            const SizedBox(height: 28),
            Text(
              widget.provider.name,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppTheme.textDark,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Sending request to...',
              style: TextStyle(fontSize: 15, color: AppTheme.textGrey),
            ),
            const SizedBox(height: 4),
            Text(
              widget.provider.area,
              style: const TextStyle(fontSize: 13, color: AppTheme.textGrey),
            ),
            const SizedBox(height: 28),
            const SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
            const SizedBox(height: 20),
            _infoTile(
              Icons.send_outlined,
              'Request has been sent to the provider. They will see it immediately if their app is open.',
              Colors.blue.shade600,
              Colors.blue.shade50,
            ),
            const SizedBox(height: 10),
            _infoTile(
              Icons.timer_outlined,
              _timeoutMessage(),
              Colors.orange.shade700,
              Colors.orange.shade50,
            ),
            const SizedBox(height: 10),
            _infoTile(
              Icons.auto_awesome,
              'If the provider does not respond, the next best provider will be selected automatically.',
              Colors.purple.shade600,
              Colors.purple.shade50,
            ),
            if (TestModeService.isEnabled) ...[
              const SizedBox(height: 10),
              _infoTile(
                Icons.science_rounded,
                'Judge Demo Mode: Provider will auto-accept in ~3 seconds.',
                Colors.amber.shade800,
                Colors.amber.shade50,
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _timeoutMessage() {
    final now = DateTime.now();
    final bookingTime = now.add(const Duration(days: 1));
    final hoursUntil = bookingTime.difference(now).inHours;
    if (hoursUntil <= 3) {
      return 'Urgent booking — provider must respond within 30 minutes.';
    }
    return 'Provider must respond within 1 hour. If no response, the next provider will be selected automatically.';
  }

  // ─────────────────────────── CONFIRMED ───────────────────────────
  Widget _buildConfirmed() {
    return SingleChildScrollView(
      key: const ValueKey('confirmed'),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          ScaleTransition(
            scale: _successScale,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 28),
              decoration: BoxDecoration(
                color: AppTheme.primary,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Column(
                children: [
                  Icon(Icons.check_circle, color: Colors.white, size: 64),
                  SizedBox(height: 12),
                  Text(
                    'Booking Confirmed!',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Provider accepted your booking',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _bookingDetailsCard(
            provider: widget.provider,
            bookingId: widget.bookingId,
            pricing: widget.pricing,
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => ServiceTrackingScreen(
                    provider: widget.provider,
                    bookingId: widget.bookingId,
                  ),
                ),
              ),
              icon: const Icon(Icons.track_changes_outlined, color: Colors.white, size: 20),
              label: const Text(
                'Track Job',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(vertical: 16),
                elevation: 0,
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => Navigator.popUntil(context, (r) => r.isFirst),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.grey.shade300),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text('Go Home', style: TextStyle(color: AppTheme.textGrey)),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────── DECLINED ───────────────────────────
  Widget _buildDeclined() {
    return Center(
      key: const ValueKey('declined'),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                shape: BoxShape.circle,
              ),
              child:
                  Icon(Icons.person_off_outlined, size: 40, color: Colors.orange.shade600),
            ),
            const SizedBox(height: 20),
            Text(
              '${widget.provider.name} is Busy',
              style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textDark),
              textAlign: TextAlign.center,
            ),
            if (_declineReason != null && _declineReason!.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'Wajah: $_declineReason',
                  style: const TextStyle(fontSize: 13, color: AppTheme.textGrey),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
            const SizedBox(height: 20),
            _infoTile(
              Icons.autorenew,
              'Finding another provider...',
              Colors.blue.shade600,
              Colors.blue.shade50,
            ),
          ],
        ),
      ),
    );
  }


  // ─────────────────────────── RESCHEDULING ───────────────────────────
  Widget _buildRescheduling() {
    return Center(
      key: const ValueKey('rescheduling'),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: AppTheme.primaryLight,
                shape: BoxShape.circle,
              ),
              child: const Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(strokeWidth: 3),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Finding Another Provider',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppTheme.textDark,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'After ${widget.provider.name}, sending request to the next best provider...',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: AppTheme.textGrey),
            ),
            const SizedBox(height: 20),
            _infoTile(
              Icons.auto_awesome,
              'Agent is automatically selecting the next provider from the ranked list',
              Colors.purple.shade600,
              Colors.purple.shade50,
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────── NO PROVIDER ───────────────────────────
  Widget _buildNoProvider() {
    return Center(
      key: const ValueKey('noProvider'),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.sentiment_dissatisfied_outlined,
                  size: 44, color: Colors.grey.shade500),
            ),
            const SizedBox(height: 20),
            const Text(
              'No Other Provider Found',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppTheme.textDark,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            const Text(
              'No other provider is available in your area right now.\nPlease try again later.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppTheme.textGrey, height: 1.5),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.popUntil(context, (r) => r.isFirst),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  elevation: 0,
                ),
                child: const Text(
                  'Go Home',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────── SHARED WIDGETS ───────────────────────────
  Widget _bookingDetailsCard({
    required ProviderModel provider,
    required String bookingId,
    required PricingModel pricing,
  }) {
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
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.primaryLight,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                ProviderAvatar(provider: provider, radius: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(provider.name,
                              style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.textDark)),
                          if (provider.blueTick) ...[
                            const SizedBox(width: 4),
                            const Icon(Icons.verified,
                                color: Colors.blue, size: 16),
                          ],
                        ],
                      ),
                      Text(
                        provider.serviceTypes
                            .map((s) => s.replaceAll('_', ' '))
                            .join(', '),
                        style: const TextStyle(
                            fontSize: 12, color: AppTheme.textGrey),
                      ),
                    ],
                  ),
                ),
                if (provider.rating > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.amber.shade200),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.star,
                            size: 12, color: Colors.amber.shade700),
                        const SizedBox(width: 3),
                        Text(
                          provider.rating.toStringAsFixed(1),
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Colors.amber.shade800),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          if (bookingId.isNotEmpty)
            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: AppTheme.textDark,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Booking ID',
                      style: TextStyle(color: Colors.white60, fontSize: 11)),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(bookingId,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.2)),
                      const SizedBox(width: 6),
                      IconButton(
                        icon: const Icon(
                          Icons.copy_rounded,
                          color: Colors.white70,
                          size: 14,
                        ),
                        constraints: const BoxConstraints(),
                        padding: EdgeInsets.zero,
                        splashRadius: 16,
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: bookingId));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Booking ID copied!'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _row(Icons.build_outlined, 'Service',
                    provider.serviceTypes.first.replaceAll('_', ' ')),
                _divider(),
                _row(Icons.location_on_outlined, 'Area', provider.area),
                _divider(),
                _row(Icons.payments_outlined, 'Amount', 'Rs. ${pricing.total}',
                    valueColor: AppTheme.primary, bold: true),
                _divider(),
                _row(Icons.access_time_outlined, 'Time',
                    'Tomorrow 10:00 AM (confirm)'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(IconData icon, String label, String value,
      {Color? valueColor, bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 14, color: AppTheme.textGrey),
          const SizedBox(width: 8),
          Text(label,
              style:
                  const TextStyle(fontSize: 13, color: AppTheme.textGrey)),
          const Spacer(),
          Text(value,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
                  color: valueColor ?? AppTheme.textDark)),
        ],
      ),
    );
  }

  Widget _divider() => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: List.generate(
            40,
            (i) => Expanded(
              child: Container(
                height: 1,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                color:
                    i.isEven ? Colors.grey.shade200 : Colors.transparent,
              ),
            ),
          ),
        ),
      );

  Widget _infoTile(
      IconData icon, String text, Color iconColor, Color bgColor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: iconColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: TextStyle(fontSize: 12, color: iconColor, height: 1.4)),
          ),
        ],
      ),
    );
  }
}
