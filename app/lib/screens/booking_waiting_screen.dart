import 'dart:async';
import 'package:flutter/services.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/provider_model.dart';
import 'agent_trace_screen.dart';
import '../models/pricing_model.dart';
import '../services/api_service.dart';
import '../services/booking_firestore_service.dart';
import '../theme/app_theme.dart';
import '../widgets/provider_avatar.dart';
enum _Phase { waiting, confirmed, declined, rescheduling, rescheduled, noProvider }

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
  String? _newBookingId;
  ProviderModel? _newProvider;
  PricingModel? _newPricing;

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

    Future.delayed(const Duration(seconds: 5), () {
      if (mounted && _phase == _Phase.waiting) {
        // Mock: provider accepted after 5 seconds
        _pulseController.stop();
        _successController.forward();
        setState(() => _phase = _Phase.confirmed);
      }
    });
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
        // Auto-find next provider after 1.5 seconds
        Future.delayed(const Duration(milliseconds: 1500), _autoReschedule);
      }
    });
  }

  Future<void> _autoReschedule() async {
    if (!mounted) return;
    setState(() => _phase = _Phase.rescheduling);

    final allProviders = ApiService.lastDiscoveredProviders;
    final intent = ApiService.lastConfirmedIntent;

    // Find next provider (skip the one that declined)
    final nextProviderJson = allProviders.firstWhere(
      (p) => p['id'] != widget.provider.id,
      orElse: () => {},
    );

    if (nextProviderJson.isEmpty || intent == null) {
      if (mounted) setState(() => _phase = _Phase.noProvider);
      return;
    }

    try {
      final nextProvider = ProviderModel.fromJson(nextProviderJson);

      // Get pricing for new provider
      final pricingJson =
          await ApiService.getPricing(nextProviderJson, intent, false);
      final newPricing = PricingModel.fromJson(pricingJson);

      // Create booking for new provider
      final req = {
        'provider': nextProviderJson,
        'intent': intent,
        'pricing': {'base_rate': newPricing.baseRate, 'total': newPricing.total},
        'mock_action': 'accept',
      };
      final bookingResp = await ApiService.createBooking(req);
      final newBookingId = bookingResp['booking_id'] as String? ?? '';
      final newProviderId = bookingResp['provider_id'] as String? ?? '';

      if (newBookingId.isNotEmpty && newProviderId.isNotEmpty) {
        await BookingFirestoreService.createBooking(
          bookingId: newBookingId,
          providerId: newProviderId,
          providerName: nextProvider.name,
          serviceType: nextProvider.serviceTypes.isNotEmpty
              ? nextProvider.serviceTypes.first
              : 'service',
          area: nextProvider.area,
          amount: newPricing.total,
          datetime: DateTime.now()
              .add(const Duration(days: 1))
              .toIso8601String(),
        );
      }

      if (mounted) {
        setState(() {
          _newProvider = nextProvider;
          _newPricing = newPricing;
          _newBookingId = newBookingId;
          _phase = _Phase.rescheduled;
        });
      }
    } catch (e) {
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
      canPop: _phase == _Phase.confirmed ||
          _phase == _Phase.rescheduled ||
          _phase == _Phase.noProvider,
      child: Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(
          title: Text(_appBarTitle),
          automaticallyImplyLeading: _phase != _Phase.waiting &&
              _phase != _Phase.rescheduling,
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

  String get _appBarTitle {
    switch (_phase) {
      case _Phase.waiting:
      case _Phase.rescheduling:
        return 'Request Bheji Ja Rahi Hai';
      case _Phase.confirmed:
        return 'Booking Confirm!';
      case _Phase.declined:
        return 'Provider Busy';
      case _Phase.rescheduled:
        return 'Naya Provider Mila!';
      case _Phase.noProvider:
        return 'Koi Provider Nahi';
    }
  }

  Widget _buildBody() {
    switch (_phase) {
      case _Phase.waiting:
        return _buildWaiting();
      case _Phase.confirmed:
        return _buildConfirmed();
      case _Phase.declined:
        return _buildDeclined();
      case _Phase.rescheduling:
        return _buildRescheduling();
      case _Phase.rescheduled:
        return _buildRescheduled();
      case _Phase.noProvider:
        return _buildNoProvider();
    }
  }

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
              'Ko request bheji ja rahi hai...',
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
              'Request provider ko bhej di gayi hai. Agar unka app khula hai to foran dekhenge.',
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
              'Agar provider respond na kare to apne aap next best provider select ho jayega.',
              Colors.purple.shade600,
              Colors.purple.shade50,
            ),
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
      return 'Urgent booking — provider ko 30 minute mein jawab dena hoga.';
    }
    return 'Provider ko 1 ghante mein jawab dena hoga. Agar response na aye tu apne aap next provider select ho jayega.';
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
                    'Booking Confirm Ho Gayi!',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Provider ne accept kar liya',
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
              onPressed: () => Navigator.popUntil(context, (r) => r.isFirst),
              icon: const Icon(Icons.home_outlined, color: Colors.white),
              label: const Text('Home Jao',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(vertical: 16),
                elevation: 0,
              ),
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
              '${widget.provider.name} Busy Hai',
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
              'Doosra provider dhundh raha hun...',
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
            ScaleTransition(
              scale: _pulse,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppTheme.primaryLight,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.search, size: 40, color: AppTheme.primary),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Doosra Provider Dhundh Raha Hun',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textDark),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            const Text(
              'Apki rating aur area ke hisaab se best available provider select kar raha hun...',
              style: TextStyle(fontSize: 13, color: AppTheme.textGrey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            const SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────── RESCHEDULED ───────────────────────────
  Widget _buildRescheduled() {
    final np = _newProvider!;
    final np2 = _newPricing!;
    return SingleChildScrollView(
      key: const ValueKey('rescheduled'),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 20),
            decoration: BoxDecoration(
              color: Colors.blue.shade600,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Column(
              children: [
                Icon(Icons.auto_awesome, color: Colors.white, size: 48),
                SizedBox(height: 10),
                Text(
                  'Naya Provider Mila!',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Apke request par automatically naya provider assign kiya gaya',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _bookingDetailsCard(
            provider: np,
            bookingId: _newBookingId ?? '',
            pricing: np2,
          ),
          const SizedBox(height: 16),
          _infoTile(
            Icons.info_outline,
            'Pehle provider (${widget.provider.name}) ne apni majboori ki wajah se decline kiya. Yeh naya assignment automatic tha — koi extra cost nahi.',
            Colors.blue.shade600,
            Colors.blue.shade50,
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () =>
                      Navigator.popUntil(context, (r) => r.isFirst),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.grey.shade300),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Home',
                      style: TextStyle(color: AppTheme.textGrey)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => BookingWaitingScreen(
                          bookingId: _newBookingId!,
                          providerId: np.id,
                          provider: np,
                          pricing: np2,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.live_tv_outlined,
                      color: Colors.white, size: 16),
                  label: const Text('New Booking Track Karo',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w700)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─────────────────────────── NO PROVIDER ───────────────────────────
  Widget _buildNoProvider() {
    return Center(
      key: const ValueKey('noprovider'),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 20),
            const Text(
              'Is Waqt Koi Provider Nahi',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textDark),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            const Text(
              'Sab providers is waqt busy hain. Thodi der baad dobara try karein ya alag waqt ka slot chunein.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: AppTheme.textGrey),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () =>
                    Navigator.popUntil(context, (r) => r.isFirst),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('Wapas Chat Mein Jayen',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w700)),
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
                              content: Text('Booking ID copy ho gaya!'),
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
                _row(Icons.access_time_outlined, 'Waqt',
                    'Kal 10:00 AM (confirm)'),
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
