import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';

class ProviderNotificationScreen extends StatefulWidget {
  final String providerId;
  const ProviderNotificationScreen({super.key, required this.providerId});

  @override
  State<ProviderNotificationScreen> createState() =>
      _ProviderNotificationScreenState();
}

// Screen phases
enum _Phase { pending, declining, accepted, cancelling, cancelled, autoDenied }

class _ProviderNotificationScreenState
    extends State<ProviderNotificationScreen>
    with TickerProviderStateMixin {
  _Phase _phase = _Phase.pending;

  // 5-minute countdown
  static const int _totalSeconds = 300;
  int _remainingSeconds = _totalSeconds;
  Timer? _countdownTimer;

  // Decline reason
  String? _declineReason;

  // Animations
  late AnimationController _successController;
  late Animation<double> _successScale;
  late AnimationController _shakeController;
  late Animation<double> _shake;

  bool _isLoading = true;
  Map<String, dynamic>? _realBooking;

  static const List<String> _declineReasons = [
    'Already busy hoon',
    'Zyada door hai',
    'Tabiyat theek nahi',
    'Kuch aur wajah',
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

    _fetchPendingBooking();
  }

  Future<void> _fetchPendingBooking() async {
    try {
      final bookings = await ApiService.getPendingBookings(widget.providerId);
      if (mounted) {
        if (bookings.isNotEmpty) {
          setState(() {
            _realBooking = bookings.last;
            _isLoading = false;
          });
          _startCountdown();
        } else {
          setState(() => _isLoading = false);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error fetching bookings: $e')));
      }
    }
  }

  void _startCountdown() {
    _countdownTimer =
        Timer.periodic(const Duration(seconds: 1), (t) {
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
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );
    
    try {
      await ApiService.respondToBooking(_realBooking!['id'], widget.providerId, 'accept');
      if (mounted) {
        Navigator.pop(context); // loader
        setState(() => _phase = _Phase.accepted);
        _successController.forward();
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
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
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );
    
    try {
      await ApiService.respondToBooking(_realBooking!['id'], widget.providerId, 'decline', reason: _declineReason);
      if (mounted) {
        Navigator.pop(context);
        setState(() => _phase = _Phase.autoDenied); // or explicitly declined state
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  void _showCancelWarning() {
    setState(() => _phase = _Phase.cancelling);
  }

  void _confirmCancel() async {
    if (_realBooking == null) return;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );
    
    try {
      await ApiService.cancelAfterAccept(_realBooking!['id']);
      if (mounted) {
        Navigator.pop(context);
        setState(() => _phase = _Phase.cancelled);
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  String get _countdownText {
    final m = _remainingSeconds ~/ 60;
    final s = (_remainingSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Color get _timerColor {
    if (_remainingSeconds > 180) return AppTheme.primary;
    if (_remainingSeconds > 60) return Colors.orange.shade700;
    return Colors.red.shade600;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Booking Request'),
        automaticallyImplyLeading:
            _phase == _Phase.accepted || _phase == _Phase.cancelled ||
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
      return const Center(child: Text('No pending bookings.'));
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
          _buildCountdownCard(),
          const SizedBox(height: 14),
          _buildBookingCard(),
          const SizedBox(height: 24),
          _buildAcceptButton(),
          const SizedBox(height: 10),
          _buildDeclineButton(),
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
                'Jawab dene ka waqt',
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
            'Waqt khatam hone par request apne aap decline ho jaye gi',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _buildBookingCard() {
    final customerName = 'Customer';
    final customerArea = _realBooking?['request']?['intent']?['location']?['area'] ?? 'Unknown Area';
    final serviceType = _realBooking?['request']?['intent']?['service_type'] ?? 'Service';
    final datetimeStr = _realBooking?['datetime'] ?? '';
    final offeredPrice = _realBooking?['request']?['pricing']?['total'] ?? 0;
    final bookingId = _realBooking?['id'] ?? 'N/A';
    
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
          // Header
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
                  decoration: BoxDecoration(
                    color: AppTheme.primary,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      customerName[0].toUpperCase(),
                      style: const TextStyle(
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
                      Text(
                        customerName,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textDark,
                        ),
                      ),
                      Text(
                        customerArea,
                        style: const TextStyle(
                            fontSize: 12, color: AppTheme.textGrey),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border:
                        Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.near_me_outlined,
                          size: 12, color: AppTheme.primary),
                      const SizedBox(width: 3),
                      Text(
                        'Nearby',
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
          ),
          // Details
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _detailRow(Icons.build_outlined, 'Service',
                    serviceType),
                _divider(),
                _detailRow(
                    Icons.calendar_today_outlined, 'Date/Time', datetimeStr),
                _divider(),
                _detailRow(
                  Icons.payments_outlined,
                  'Offered Price',
                  'Rs. $offeredPrice',
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
          'Accept Karo',
          style: TextStyle(
              color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primary,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
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
        icon: Icon(Icons.cancel_outlined,
            color: Colors.red.shade600, size: 20),
        label: Text(
          'Decline Karo',
          style: TextStyle(
              color: Colors.red.shade600,
              fontSize: 16,
              fontWeight: FontWeight.w700),
        ),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: Colors.red.shade400),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
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
            'Decline karne ki wajah',
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
                _shake.value * 6 * ((_shakeController.value * 10).round().isEven ? 1 : -1),
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
                    onTap: () =>
                        setState(() => _declineReason = reason),
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
                  onPressed: () =>
                      setState(() => _phase = _Phase.pending),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.grey.shade300),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Wapas Jao',
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
                    'Decline Confirm',
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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: ScaleTransition(
        scale: _successScale,
        child: Column(
          children: [
            // Success banner
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
                    'Booking Accept Ho Gayi!',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Customer ko notification bhej di gayi',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            // Active booking card
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
                  _detailRow(Icons.person_outline, 'Customer',
                      'Customer'),
                  _divider(),
                  _detailRow(Icons.location_on_outlined, 'Location',
                      _realBooking?['request']?['intent']?['location']?['area'] ?? 'Unknown Area'),
                  _divider(),
                  _detailRow(Icons.build_outlined, 'Service',
                      _realBooking?['request']?['intent']?['service_type'] ?? 'Service'),
                  _divider(),
                  _detailRow(Icons.calendar_today_outlined, 'Date & Time',
                      _realBooking?['datetime'] ?? ''),
                  _divider(),
                  _detailRow(
                    Icons.payments_outlined,
                    'Aapki Kamai',
                    'Rs. ${((_realBooking?['request']?['pricing']?['total'] ?? 0) * 0.9).round()} (90%)',
                    valueColor: AppTheme.primary,
                    valueBold: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // Cancel button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _showCancelWarning,
                icon: Icon(Icons.cancel_outlined,
                    color: Colors.red.shade600, size: 18),
                label: Text(
                  'Booking Cancel Karo',
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
            child:
                Icon(Icons.warning_amber_outlined, size: 40, color: Colors.red.shade600),
          ),
          const SizedBox(height: 20),
          const Text(
            'Yaqeen karo?',
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
                  'Accept ke baad cancel karne se:',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.red.shade700),
                ),
                const SizedBox(height: 8),
                ...[
                  'Cancellation rate +1 ho jaye ga',
                  'Reliability score -10 ho jaye ga',
                  'Risk level "High" ki taraf badhega',
                  'Aapki ranking mein kaafi girawat aaye gi',
                  '3 baar karne par platform se remove ho saktay hain',
                ].map((t) => Padding(
                      padding: const EdgeInsets.only(bottom: 5),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.close,
                              size: 14, color: Colors.red.shade600),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              t,
                              style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.red.shade800),
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
                  onPressed: () =>
                      setState(() => _phase = _Phase.accepted),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Nahi, Rakho',
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
                    'Haan, Cancel',
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
              child: Icon(Icons.cancel, size: 44, color: Colors.red.shade600),
            ),
            const SizedBox(height: 20),
            const Text(
              'Booking Cancel Ho Gayi',
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textDark),
            ),
            const SizedBox(height: 10),
            const Text(
              'Customer ko doosra provider dhoondha ja raha hai.',
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
                      'Aapki profile update ho gayi — cancellation rate aur reliability score affect hua',
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
                  'Home Jao',
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
              'Waqt Khatam Ho Gaya',
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textDark),
            ),
            const SizedBox(height: 10),
            const Text(
              'Request apne aap decline ho gayi.\nCustomer ko doosra provider dhoondha ja raha hai.',
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
                  'Home Jao',
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
              style: const TextStyle(
                  fontSize: 13, color: AppTheme.textGrey)),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight:
                  valueBold ? FontWeight.w700 : FontWeight.w600,
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
}

class _MockBooking {
  final String customerName;
  final String customerArea;
  final String serviceType;
  final String date;
  final String time;
  final int offeredPrice;
  final String distance;
  final String bookingId;

  const _MockBooking({
    required this.customerName,
    required this.customerArea,
    required this.serviceType,
    required this.date,
    required this.time,
    required this.offeredPrice,
    required this.distance,
    required this.bookingId,
  });
}
