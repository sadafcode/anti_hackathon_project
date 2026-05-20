import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../services/booking_firestore_service.dart';
import '../services/test_mode_service.dart';

class ProviderNotificationScreen extends StatefulWidget {
  final String providerId;
  const ProviderNotificationScreen({super.key, required this.providerId});

  @override
  State<ProviderNotificationScreen> createState() =>
      _ProviderNotificationScreenState();
}

enum _Phase { pending, declining, accepted, cancelling, cancelled, autoDenied }

class _ProviderNotificationScreenState
    extends State<ProviderNotificationScreen>
    with TickerProviderStateMixin {
  _Phase _phase = _Phase.pending;

  final Map<String, TextEditingController> _responseControllers = {};
  final Map<String, bool> _submittingDisputes = {};
  final Map<String, List<XFile>> _disputeEvidence = {};
  final ImagePicker _picker = ImagePicker();

  static const int _normalTotalSeconds = 300;
  static const int _demoTotalSeconds = 30;
  int get _totalSeconds => TestModeService.isEnabled ? _demoTotalSeconds : _normalTotalSeconds;
  int _remainingSeconds = _normalTotalSeconds;
  Timer? _countdownTimer;

  String? _declineReason;

  late AnimationController _successController;
  late Animation<double> _successScale;
  late AnimationController _shakeController;
  late Animation<double> _shake;

  bool _isLoading = true;
  Map<String, dynamic>? _realBooking;

  static const List<String> _declineReasons = [
    'Already busy',
    'Too far away',
    'Not feeling well',
    'Other reason',
  ];

  @override
  void initState() {
    super.initState();

    _successController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _successScale = CurvedAnimation(
      parent: _successController,
      curve: Curves.elasticOut,
    );

    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _shake = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.elasticOut),
    );

    _remainingSeconds = _totalSeconds;
    _fetchPendingBooking();
  }

  Future<void> _fetchPendingBooking() async {
    try {
      final bookings = await ApiService.getPendingBookings(widget.providerId);
      if (mounted) {
        if (bookings.isNotEmpty) {
          setState(() {
            _realBooking = Map<String, dynamic>.from(bookings.last as Map);
            _isLoading = false;
          });
          _startCountdown();
        } else if (TestModeService.isEnabled) {
          // Demo mode: show mock booking even if no real booking exists
          setState(() {
            _realBooking = TestModeService.mockBooking;
            _isLoading = false;
          });
          _startCountdown();
        } else {
          setState(() => _isLoading = false);
        }
      }
    } catch (e) {
      if (TestModeService.isEnabled && mounted) {
        // Demo mode: ignore API errors, show mock booking
        setState(() {
          _realBooking = TestModeService.mockBooking;
          _isLoading = false;
        });
        _startCountdown();
      } else if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error fetching bookings: $e')));
      }
    }
  }

  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() {
        if (_remainingSeconds > 0) {
          _remainingSeconds--;
        } else {
          t.cancel();
          if (_phase == _Phase.pending) {
            _phase = _Phase.autoDenied;
          }
        }
      });
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _successController.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  void _accept() async {
    _countdownTimer?.cancel();
    if (_realBooking == null) return;
    final bookingId = _realBooking!['id'] as String;

    if (TestModeService.isEnabled) {
      // Demo mode: skip API call, simulate accept immediately
      setState(() => _phase = _Phase.accepted);
      _successController.forward();
      // Also update Firestore so customer BookingWaitingScreen advances
      try {
        await BookingFirestoreService.acceptBooking(bookingId);
      } catch (_) {}
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      await ApiService.respondToBooking(bookingId, widget.providerId, 'accept');
      // Update Firestore so customer's waiting screen gets real-time notification
      try {
        await BookingFirestoreService.acceptBooking(bookingId);
      } catch (_) {}

      if (mounted) {
        Navigator.pop(context);
        setState(() => _phase = _Phase.accepted);
        _successController.forward();
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')));
      }
    }
  }

  void _showDeclinePanel() {
    setState(() {
      _phase = _Phase.declining;
      _declineReason = null;
    });
  }

  void _confirmDecline() async {
    if (_declineReason == null) {
      _shakeController.forward(from: 0);
      return;
    }
    _countdownTimer?.cancel();
    if (_realBooking == null) return;
    final bookingId = _realBooking!['id'] as String;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      await ApiService.respondToBooking(bookingId, widget.providerId, 'decline',
          reason: _declineReason);
      // Update Firestore so customer's waiting screen gets real-time notification
      try {
        await BookingFirestoreService.declineBooking(bookingId, _declineReason ?? '');
      } catch (_) {}

      if (mounted) {
        Navigator.pop(context);
        setState(() => _phase = _Phase.autoDenied);
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')));
      }
    }
  }

  void _showCancelWarning() {
    setState(() => _phase = _Phase.cancelling);
  }

  void _confirmCancel() async {
    if (_realBooking == null) return;
    final bookingId = _realBooking!['id'] as String;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // 1. Update Firestore booking status
      await BookingFirestoreService.cancelBooking(bookingId);
      // 2. Track cancellation in provider_stats (always works, no memory dependency)
      await BookingFirestoreService.incrementProviderCancellations(widget.providerId);
      // 3. Apply penalty to providers.json via direct providerId endpoint (reliable)
      try {
        await ApiService.applyPenalty(widget.providerId);
      } catch (_) {}

      if (mounted) {
        Navigator.pop(context);
        setState(() => _phase = _Phase.cancelled);
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')));
      }
    }
  }

  String get _countdownText {
    if (_remainingSeconds >= 3600) {
      final h = _remainingSeconds ~/ 3600;
      final m = (_remainingSeconds % 3600) ~/ 60;
      return '${h}h ${m.toString().padLeft(2, '0')}m';
    }
    final m = _remainingSeconds ~/ 60;
    final s = (_remainingSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Color get _timerColor {
    final ratio = _remainingSeconds / _totalSeconds;
    if (ratio > 0.5) return AppTheme.primary;
    if (ratio > 0.2) return Colors.orange.shade700;
    return Colors.red.shade600;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Booking Request'),
        automaticallyImplyLeading: _phase == _Phase.accepted ||
            _phase == _Phase.cancelled ||
            _phase == _Phase.autoDenied,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_realBooking == null) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Card(
              margin: EdgeInsets.only(bottom: 24),
              color: Colors.white,
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Center(
                  child: Text(
                    'No new booking requests at the moment.',
                    style: TextStyle(fontSize: 14, color: AppTheme.textGrey, fontWeight: FontWeight.w500),
                  ),
                ),
              ),
            ),
            _buildDisputesSection(),
          ],
        ),
      );
    }

    return switch (_phase) {
      _Phase.pending => _buildPendingView(),
      _Phase.declining => _buildDecliningView(),
      _Phase.accepted => _buildAcceptedView(),
      _Phase.cancelling => _buildCancellingView(),
      _Phase.cancelled => _buildCancelledView(),
      _Phase.autoDenied => _buildAutoDeniedView(),
    };
  }

  // ─── PENDING ────────────────────────────────────────────────────────────────

  Widget _buildPendingView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          if (TestModeService.isEnabled)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.amber.shade300),
              ),
              child: Row(
                children: [
                  Icon(Icons.science_rounded, size: 14, color: Colors.amber.shade800),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Judge Demo Mode — Mock booking shown. Timer: 30s. Tap Accept to simulate.',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.amber.shade900),
                    ),
                  ),
                ],
              ),
            ),
          _buildCountdownCard(),
          const SizedBox(height: 14),
          _buildBookingCard(),
          const SizedBox(height: 24),
          _buildAcceptButton(),
          const SizedBox(height: 10),
          _buildDeclineButton(),
          const SizedBox(height: 24),
          _buildDisputesSection(),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildCountdownCard() {
    final progress = _remainingSeconds / _totalSeconds;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.timer_outlined, size: 15, color: _timerColor),
              const SizedBox(width: 6),
              const Text(
                'Time to respond',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textDark,
                ),
              ),
              const Spacer(),
              Text(
                _countdownText,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: _timerColor,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.grey.shade100,
              valueColor: AlwaysStoppedAnimation(_timerColor),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'The request will auto-decline when the timer expires',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _buildBookingCard() {
    final area = _realBooking?['area'] as String? ?? 'Unknown Area';
    final fullAddress = _realBooking?['fullAddress'] as String?;
    final serviceType = (_realBooking?['serviceType'] as String? ?? 'Service').replaceAll('_', ' ');
    final serviceDetails = _realBooking?['serviceDetails'] as String?;
    final datetime = _realBooking?['datetime'] as String? ?? '';
    final amount = _realBooking?['amount'] ?? 0;
    final bookingId = _realBooking?['id'] as String? ?? 'N/A';

    return Column(
      children: [
        Container(
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
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.primaryLight,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                        color: AppTheme.primary,
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: Text(
                          'C',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Customer',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textDark,
                            ),
                          ),
                          Text(
                            area,
                            style: const TextStyle(
                                fontSize: 12, color: AppTheme.textGrey),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: AppTheme.primary.withValues(alpha: 0.3)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.near_me_outlined,
                              size: 12, color: AppTheme.primary),
                          SizedBox(width: 3),
                          Text(
                            'Nearby',
                            style: TextStyle(
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
              ),
              // Highlighted address block
              Container(
                margin: const EdgeInsets.fromLTRB(12, 0, 12, 0),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.amber.shade300),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.location_on, color: Colors.amber.shade800, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          'Location to Visit:',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: Colors.amber.shade900,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      fullAddress ?? area,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.amber.shade900,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _detailRow(Icons.build_outlined, 'Service', serviceType),
                    if (serviceDetails != null && serviceDetails.isNotEmpty) ...[
                      _divider(),
                      _detailRow(Icons.description_outlined, 'Work', serviceDetails),
                    ],
                    _divider(),
                    _detailRow(
                        Icons.calendar_today_outlined, 'Date/Time', datetime),
                    _divider(),
                    _detailRow(
                      Icons.payments_outlined,
                      'Offered Price',
                      'Rs. $amount',
                      valueColor: AppTheme.primary,
                      valueBold: true,
                    ),
                    _divider(),
                    _detailRow(Icons.confirmation_number_outlined, 'Booking ID',
                        bookingId),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // RED warning: scope limitation
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.red.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.red.shade400, width: 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.warning_rounded, color: Colors.red.shade700, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    'IMPORTANT — Agreed Scope Only',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: Colors.red.shade800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                serviceDetails != null && serviceDetails.isNotEmpty
                    ? 'This booking covers only: "$serviceDetails"\n\nIf you do any extra work beyond this, the client is not obligated to pay for it — that will be your own responsibility.'
                    : 'This booking covers "$serviceType" only.\n\nIf you do any extra work beyond this scope, the client is not obligated to pay for it — that will be your own responsibility.',
                style: TextStyle(fontSize: 12, color: Colors.red.shade700, height: 1.5),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // RED warning: dispute consequences
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.red.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.red.shade400, width: 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.gavel_rounded, color: Colors.red.shade700, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    'IMPORTANT — Dispute Consequences',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: Colors.red.shade800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'If a client files a dispute and you lose after review:\n• Your profile may be suspended or deleted\n• Your rating and cancellation rate will be affected\n• You may be removed from the platform',
                style: TextStyle(fontSize: 12, color: Colors.red.shade700, height: 1.4),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAcceptButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _accept,
        icon: const Icon(Icons.check_circle_outline,
            color: Colors.white, size: 20),
        label: const Text(
          'Accept',
          style: TextStyle(
              color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primary,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          padding: const EdgeInsets.symmetric(vertical: 16),
          elevation: 0,
        ),
      ),
    );
  }

  Widget _buildDeclineButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _showDeclinePanel,
        icon: Icon(Icons.cancel_outlined, color: Colors.red.shade600, size: 20),
        label: Text(
          'Decline',
          style: TextStyle(
              color: Colors.red.shade600,
              fontSize: 16,
              fontWeight: FontWeight.w700),
        ),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: Colors.red.shade400),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }

  // ─── DECLINING ──────────────────────────────────────────────────────────────

  Widget _buildDecliningView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCountdownCard(),
          const SizedBox(height: 16),
          const Text(
            'Reason for declining',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppTheme.textDark,
            ),
          ),
          const SizedBox(height: 10),
          AnimatedBuilder(
            animation: _shake,
            builder: (_, child) => Transform.translate(
              offset: Offset(
                _shake.value *
                    6 *
                    ((_shakeController.value * 10).round().isEven ? 1 : -1),
                0,
              ),
              child: child,
            ),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: _declineReasons.map((reason) {
                  final selected = _declineReason == reason;
                  return InkWell(
                    onTap: () => setState(() => _declineReason = reason),
                    borderRadius: BorderRadius.circular(14),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 14),
                      child: Row(
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: selected
                                  ? Colors.red.shade600
                                  : Colors.transparent,
                              border: Border.all(
                                color: selected
                                    ? Colors.red.shade600
                                    : Colors.grey.shade400,
                                width: 1.5,
                              ),
                            ),
                            child: selected
                                ? const Icon(Icons.check,
                                    size: 12, color: Colors.white)
                                : null,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            reason,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: selected
                                  ? FontWeight.w700
                                  : FontWeight.w400,
                              color: selected
                                  ? Colors.red.shade700
                                  : AppTheme.textDark,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => setState(() => _phase = _Phase.pending),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.grey.shade300),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Go Back',
                      style: TextStyle(color: AppTheme.textGrey)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _confirmDecline,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade600,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Confirm Decline',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── ACCEPTED ───────────────────────────────────────────────────────────────

  Widget _buildAcceptedView() {
    final area = _realBooking?['area'] as String? ?? 'Unknown Area';
    final fullAddress = _realBooking?['fullAddress'] as String?;
    final serviceType = (_realBooking?['serviceType'] as String? ?? 'Service').replaceAll('_', ' ');
    final serviceDetails = _realBooking?['serviceDetails'] as String?;
    final datetime = _realBooking?['datetime'] as String? ?? '';
    final amount = _realBooking?['amount'] as int? ?? 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: ScaleTransition(
        scale: _successScale,
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 20),
              decoration: BoxDecoration(
                color: AppTheme.primary,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Column(
                children: [
                  Icon(Icons.check_circle, color: Colors.white, size: 52),
                  SizedBox(height: 8),
                  Text(
                    'Booking Accepted!',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Notification sent to customer',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  _detailRow(Icons.person_outline, 'Customer', 'Customer'),
                  _divider(),
                  _detailRow(Icons.location_on_outlined, 'Location', fullAddress ?? area),
                  _divider(),
                  _detailRow(Icons.build_outlined, 'Service', serviceType),
                  if (serviceDetails != null && serviceDetails.isNotEmpty) ...[
                    _divider(),
                    _detailRow(Icons.description_outlined, 'Kaam', serviceDetails),
                  ],
                  _divider(),
                  _detailRow(Icons.calendar_today_outlined, 'Date & Time', datetime),
                  _divider(),
                  _detailRow(
                    Icons.payments_outlined,
                    'Your Earnings',
                    'Rs. ${(amount * 0.9).round()} (90%)',
                    valueColor: AppTheme.primary,
                    valueBold: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _showCancelWarning,
                icon: Icon(Icons.cancel_outlined,
                    color: Colors.red.shade600, size: 18),
                label: Text(
                  'Cancel Booking',
                  style: TextStyle(
                      color: Colors.red.shade600,
                      fontWeight: FontWeight.w700),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.red.shade300),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            const SizedBox(height: 24),
            _buildDisputesSection(),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // ─── CANCELLING ─────────────────────────────────────────────────────────────

  Widget _buildCancellingView() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.warning_amber_outlined,
                size: 40, color: Colors.red.shade600),
          ),
          const SizedBox(height: 20),
          const Text(
            'Are you sure?',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppTheme.textDark,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Cancelling after acceptance will:',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.red.shade700),
                ),
                const SizedBox(height: 8),
                ...[
                  'Cancellation rate will increase by +1',
                  'Reliability score will decrease by -10',
                  'Risk level will move toward High',
                  'Your ranking will drop significantly',
                  '3 occurrences may result in platform removal',
                ].map((t) => Padding(
                      padding: const EdgeInsets.only(bottom: 5),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.close, size: 14, color: Colors.red.shade600),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              t,
                              style: TextStyle(
                                  fontSize: 12, color: Colors.red.shade800),
                            ),
                          ),
                        ],
                      ),
                    )),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () => setState(() => _phase = _Phase.accepted),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    elevation: 0,
                  ),
                  child: const Text(
                    'No, Keep It',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: _confirmCancel,
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.red.shade400),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Text(
                    'Yes, Cancel',
                    style: TextStyle(
                        color: Colors.red.shade600,
                        fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── CANCELLED ──────────────────────────────────────────────────────────────

  Widget _buildCancelledView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                shape: BoxShape.circle,
              ),
              child:
                  Icon(Icons.cancel, size: 44, color: Colors.red.shade600),
            ),
            const SizedBox(height: 20),
            const Text(
              'Booking Cancelled',
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textDark),
            ),
            const SizedBox(height: 10),
            const Text(
              'Finding another provider for the customer.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppTheme.textGrey),
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.orange.shade300),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline,
                      size: 15, color: Colors.orange.shade800),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Your profile has been updated — cancellation rate and reliability score are affected',
                      style: TextStyle(
                          fontSize: 12, color: Colors.orange.shade900),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () =>
                    Navigator.popUntil(context, (r) => r.isFirst),
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

  // ─── AUTO DENIED ────────────────────────────────────────────────────────────

  Widget _buildAutoDeniedView() {
    return Center(
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
              child: Icon(Icons.timer_off_outlined,
                  size: 44, color: Colors.grey.shade500),
            ),
            const SizedBox(height: 20),
            const Text(
              'Time Expired',
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textDark),
            ),
            const SizedBox(height: 10),
            const Text(
              'The request was auto-declined.\nFinding another provider for the customer.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppTheme.textGrey),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () =>
                    Navigator.popUntil(context, (r) => r.isFirst),
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

  // ─── HELPERS ────────────────────────────────────────────────────────────────

  Widget _detailRow(
    IconData icon,
    String label,
    String value, {
    Color? valueColor,
    bool valueBold = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Icon(icon, size: 15, color: AppTheme.textGrey),
          const SizedBox(width: 8),
          Text(label,
              style: const TextStyle(fontSize: 13, color: AppTheme.textGrey)),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: valueBold ? FontWeight.w700 : FontWeight.w600,
              color: valueColor ?? AppTheme.textDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider() => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Divider(color: Colors.grey.shade100, height: 1),
      );

  Widget _buildDisputesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.gavel_outlined, color: AppTheme.primary, size: 20),
            const SizedBox(width: 8),
            const Text(
              'Your Disputes',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppTheme.textDark,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('disputes')
              .where('provider_id', isEqualTo: widget.providerId)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Text('Error: ${snapshot.error}', style: const TextStyle(fontSize: 12, color: Colors.red));
            }
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(strokeWidth: 2));
            }
            final docs = snapshot.data?.docs ?? [];
            if (docs.isEmpty) {
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade100),
                ),
                child: const Center(
                  child: Text(
                    'No open disputes.',
                    style: TextStyle(fontSize: 13, color: AppTheme.textGrey),
                  ),
                ),
              );
            }

            // Sort in memory by createdAt descending
            final sortedDocs = List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(docs);
            sortedDocs.sort((a, b) {
              final aTime = a.data()['createdAt'] as Timestamp?;
              final bTime = b.data()['createdAt'] as Timestamp?;
              if (aTime == null && bTime == null) return 0;
              if (aTime == null) return 1;
              if (bTime == null) return -1;
              return bTime.compareTo(aTime);
            });

            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: sortedDocs.length,
              itemBuilder: (context, index) {
                final doc = sortedDocs[index];
                return _buildDisputeItemCard(doc.id, doc.data());
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildDisputeItemCard(String disputeId, Map<String, dynamic> dispute) {
    final status = dispute['status'] ?? 'pending_provider_response';
    final issue = dispute['issue_type'] ?? 'other';
    final description = dispute['description'] ?? '';
    final bookingId = dispute['booking_id'] ?? 'N/A';
    final providerResponse = dispute['provider_response'] ?? '';
    final resolution = dispute['resolution'] ?? '';
    final refund = dispute['refund_amount'] ?? 0;

    Color badgeColor;
    String statusText;
    switch (status) {
      case 'pending_provider_response':
        badgeColor = Colors.orange.shade700;
        statusText = 'Response Required';
        break;
      case 'pending_review':
        badgeColor = Colors.blue.shade700;
        statusText = 'Under Review';
        break;
      case 'resolved':
        badgeColor = Colors.green.shade700;
        statusText = 'Resolved';
        break;
      default:
        badgeColor = Colors.grey.shade700;
        statusText = status.toString();
    }

    if (!_responseControllers.containsKey(disputeId)) {
      _responseControllers[disputeId] = TextEditingController();
    }

    final isSubmitting = _submittingDisputes[disputeId] ?? false;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 0,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'ID: $bookingId',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textDark,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: badgeColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: badgeColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _detailRow(Icons.report_problem_outlined, 'Customer Complaint:', issue.toString().replaceAll('_', ' ')),
            Padding(
              padding: const EdgeInsets.only(left: 24, top: 4, bottom: 8),
              child: Text(
                description,
                style: const TextStyle(fontSize: 13, color: AppTheme.textDark),
              ),
            ),
            if (status == 'pending_provider_response') ...[
              const Divider(),
              const SizedBox(height: 8),
              const Text(
                'Your Response / Statement:',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textDark,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _responseControllers[disputeId],
                maxLines: 3,
                style: const TextStyle(fontSize: 13, color: AppTheme.textDark),
                decoration: InputDecoration(
                  hintText: 'Write your response (e.g. I completed the work correctly...)',
                  hintStyle: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  contentPadding: const EdgeInsets.all(10),
                ),
              ),
              const SizedBox(height: 10),
              // Evidence photos
              _buildEvidenceUpload(disputeId),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: isSubmitting
                      ? null
                      : () => _submitProviderResponse(disputeId),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: isSubmitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(Colors.white),
                          ),
                        )
                      : const Text(
                          'Submit Response',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
            ],
            if (status == 'pending_review') ...[
              const Divider(),
              const SizedBox(height: 8),
              _detailRow(Icons.reply_outlined, 'Your Response:', ''),
              Padding(
                padding: const EdgeInsets.only(left: 24, top: 4),
                child: Text(
                  providerResponse,
                  style: const TextStyle(fontSize: 13, color: AppTheme.textGrey, fontStyle: FontStyle.italic),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.hourglass_empty, size: 14, color: Colors.blue.shade800),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Gemini AI is reviewing the dispute...',
                        style: TextStyle(fontSize: 12, color: Colors.blue.shade800, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (status == 'resolved') ...[
              const Divider(),
              const SizedBox(height: 8),
              if (providerResponse.isNotEmpty) ...[
                _detailRow(Icons.reply_outlined, 'Your Response:', ''),
                Padding(
                  padding: const EdgeInsets.only(left: 24, top: 4, bottom: 8),
                  child: Text(
                    providerResponse,
                    style: const TextStyle(fontSize: 13, color: AppTheme.textGrey, fontStyle: FontStyle.italic),
                  ),
                ),
              ],
              _detailRow(Icons.gavel, 'Resolution:', ''),
              Padding(
                padding: const EdgeInsets.only(left: 24, top: 4, bottom: 8),
                child: Text(
                  resolution,
                  style: const TextStyle(fontSize: 13, color: AppTheme.textDark, fontWeight: FontWeight.w600),
                ),
              ),
              if (refund > 0)
                _detailRow(Icons.money_off, 'Refunded amount:', 'Rs. $refund', valueColor: Colors.red.shade700),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEvidenceUpload(String disputeId) {
    _disputeEvidence.putIfAbsent(disputeId, () => []);
    final photos = _disputeEvidence[disputeId]!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Evidence Photos (Optional)',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
        ),
        const SizedBox(height: 6),
        if (photos.isNotEmpty) ...[
          SizedBox(
            height: 70,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: photos.length,
              separatorBuilder: (context, idx) => const SizedBox(width: 6),
              itemBuilder: (_, i) => Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: kIsWeb
                        ? Image.network(photos[i].path, width: 70, height: 70, fit: BoxFit.cover)
                        : Image.file(File(photos[i].path), width: 70, height: 70, fit: BoxFit.cover),
                  ),
                  Positioned(
                    top: 2, right: 2,
                    child: GestureDetector(
                      onTap: () => setState(() => photos.removeAt(i)),
                      child: Container(
                        decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                        child: const Icon(Icons.close, size: 14, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
        ],
        OutlinedButton.icon(
          onPressed: () async {
            final img = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 75);
            if (img != null) setState(() => _disputeEvidence[disputeId]!.add(img));
          },
          icon: const Icon(Icons.add_photo_alternate_outlined, size: 16),
          label: const Text('Add Photo', style: TextStyle(fontSize: 12)),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppTheme.primary,
            side: const BorderSide(color: AppTheme.primary),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ],
    );
  }

  Future<String> _uploadProviderEvidence(XFile xFile) async {
    try {
      final ref = FirebaseStorage.instance
          .ref()
          .child('disputes/provider_evidence/${DateTime.now().millisecondsSinceEpoch}_${xFile.name}');
      if (kIsWeb) {
        final bytes = await xFile.readAsBytes();
        await ref.putData(bytes);
      } else {
        await ref.putFile(File(xFile.path));
      }
      return await ref.getDownloadURL();
    } catch (_) {
      return '';
    }
  }

  Future<void> _submitProviderResponse(String disputeId) async {
    final responseText = _responseControllers[disputeId]?.text.trim() ?? '';
    if (responseText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please write your response before submitting')),
      );
      return;
    }

    setState(() => _submittingDisputes[disputeId] = true);

    try {
      // Upload provider evidence photos
      final photos = _disputeEvidence[disputeId] ?? [];
      final List<String> photoUrls = [];
      for (final img in photos) {
        final url = await _uploadProviderEvidence(img);
        if (url.isNotEmpty) photoUrls.add(url);
      }

      final updateData = <String, dynamic>{
        'provider_response': responseText,
        'status': 'pending_review',
      };
      if (photoUrls.isNotEmpty) {
        updateData['provider_evidence_photos'] = photoUrls;
      }

      await FirebaseFirestore.instance.collection('disputes').doc(disputeId).update(updateData);

      // Neutral AI report — email will be sent automatically by backend
      await ApiService.analyzeDispute(disputeId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Response submitted! AI report is being sent to the team.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Submit error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _submittingDisputes[disputeId] = false);
    }
  }
}
