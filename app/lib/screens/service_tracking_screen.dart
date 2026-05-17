import 'dart:async';
import 'package:flutter/material.dart';
import '../models/provider_model.dart';
import '../theme/app_theme.dart';
import '../widgets/provider_avatar.dart';
import 'feedback_screen.dart';

class ServiceTrackingScreen extends StatefulWidget {
  final ProviderModel provider;

  const ServiceTrackingScreen({super.key, required this.provider});

  @override
  State<ServiceTrackingScreen> createState() => _ServiceTrackingScreenState();
}

class _ServiceTrackingScreenState extends State<ServiceTrackingScreen>
    with TickerProviderStateMixin {
  // Tracking phases: 0=confirmed, 1=en_route, 2=arrived, 3=in_progress, 4=complete
  int _phase = 0;
  int _etaSeconds = 720; // 12 minutes
  Timer? _etaTimer;
  Timer? _phaseTimer;

  // Checklist
  final List<_CheckItem> _checklist = [
    _CheckItem('Waqt par pohoncha'),
    _CheckItem('Kaam shuru ho gaya'),
    _CheckItem('Area saaf rakhi'),
    _CheckItem('Customer satisfied'),
  ];

  late AnimationController _pulseController;
  late Animation<double> _pulse;
  late AnimationController _slideController;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOut));
    _slideController.forward();

    // Simulate provider moving through phases
    _phaseTimer = Timer.periodic(const Duration(seconds: 6), (t) {
      if (!mounted) return;
      setState(() {
        if (_phase < 4) _phase++;
        if (_phase == 1) {
          // En-route — start ETA countdown
          _startEtaCountdown();
        }
        if (_phase == 2) {
          // Arrived — cancel ETA timer
          _etaTimer?.cancel();
          _etaSeconds = 0;
        }
      });
      if (_phase >= 4) t.cancel();
    });
  }

  void _startEtaCountdown() {
    _etaTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() {
        if (_etaSeconds > 0) {
          _etaSeconds--;
        } else {
          t.cancel();
        }
      });
    });
  }

  @override
  void dispose() {
    _phaseTimer?.cancel();
    _etaTimer?.cancel();
    _pulseController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  String get _etaText {
    if (_etaSeconds <= 0) return 'Pohonch gaya!';
    final m = _etaSeconds ~/ 60;
    final s = (_etaSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: const Text('Service Tracking')),
      body: SlideTransition(
        position: _slideAnim,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _buildStatusCard(),
              const SizedBox(height: 14),
              _buildProgressStepper(),
              const SizedBox(height: 14),
              if (_phase >= 2) _buildChecklist(),
              if (_phase >= 2) const SizedBox(height: 14),
              if (_phase >= 4) _buildCompleteButton(context),
              if (_phase >= 4) const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    final p = widget.provider;
    final (statusText, statusColor, statusIcon) = _currentStatus();

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
          // Provider strip
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.primaryLight,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                ProviderAvatar(provider: p, radius: 24),
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
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textDark,
                            ),
                          ),
                          if (p.blueTick) ...[
                            const SizedBox(width: 4),
                            const Icon(Icons.verified,
                                color: Colors.blue, size: 15),
                          ],
                        ],
                      ),
                      Text(
                        p.serviceTypes.first.replaceAll('_', ' '),
                        style: const TextStyle(
                            fontSize: 12, color: AppTheme.textGrey),
                      ),
                    ],
                  ),
                ),
                // Rating badge
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 7, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.star,
                          size: 12, color: Colors.amber.shade700),
                      const SizedBox(width: 3),
                      Text(
                        p.rating.toStringAsFixed(1),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.amber.shade800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Status area
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                ScaleTransition(
                  scale: _phase < 4 ? _pulse : const AlwaysStoppedAnimation(1.0),
                  child: Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(statusIcon, size: 34, color: statusColor),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  statusText,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textDark,
                  ),
                ),
                if (_phase == 1) ...[
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.timer_outlined,
                          size: 14, color: AppTheme.textGrey),
                      const SizedBox(width: 5),
                      const Text(
                        'ETA: ',
                        style:
                            TextStyle(fontSize: 13, color: AppTheme.textGrey),
                      ),
                      Text(
                        _etaText,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.primary,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ],
                if (_phase == 0 || _phase >= 2) ...[
                  const SizedBox(height: 6),
                  Text(
                    _subText(),
                    style: const TextStyle(
                        fontSize: 12, color: AppTheme.textGrey),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  (String, Color, IconData) _currentStatus() {
    return switch (_phase) {
      0 => (
          'Booking Confirmed — Intezaar Karein',
          AppTheme.primary,
          Icons.hourglass_empty_outlined
        ),
      1 => (
          '${widget.provider.name} raaste mein hai',
          Colors.orange.shade700,
          Icons.directions_car_outlined
        ),
      2 => (
          '${widget.provider.name} pohonch gaya!',
          AppTheme.primary,
          Icons.where_to_vote_outlined
        ),
      3 => ('Kaam chal raha hai...', Colors.blue.shade600, Icons.build_outlined),
      _ => ('Kaam Complete Ho Gaya!', AppTheme.primary, Icons.check_circle_outline),
    };
  }

  String _subText() {
    return switch (_phase) {
      0 => 'Provider ko notification bhej di gayi hai',
      2 => 'Door ki ghanti bajao',
      3 => 'Provider kaam mein laga hua hai',
      _ => 'Feedback zaroor den — provider ki rating par asar hoga',
    };
  }

  Widget _buildProgressStepper() {
    final steps = [
      (Icons.check_circle_outline, 'Confirmed'),
      (Icons.directions_car_outlined, 'En-Route'),
      (Icons.where_to_vote_outlined, 'Pohoncha'),
      (Icons.build_outlined, 'Kaam Chal Raha'),
      (Icons.star_outline, 'Complete'),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
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
      child: Row(
        children: List.generate(steps.length * 2 - 1, (i) {
          if (i.isOdd) {
            // Connector line
            final stepIndex = i ~/ 2;
            final done = _phase > stepIndex;
            return Expanded(
              child: Container(
                height: 2,
                color: done ? AppTheme.primary : Colors.grey.shade200,
              ),
            );
          }
          final stepIndex = i ~/ 2;
          final done = _phase > stepIndex;
          final active = _phase == stepIndex;
          final (icon, label) = steps[stepIndex];

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: done
                      ? AppTheme.primary
                      : active
                          ? AppTheme.primaryLight
                          : Colors.grey.shade100,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: done || active
                        ? AppTheme.primary
                        : Colors.grey.shade300,
                    width: active ? 2 : 1,
                  ),
                ),
                child: Icon(
                  done ? Icons.check : icon,
                  size: 16,
                  color: done
                      ? Colors.white
                      : active
                          ? AppTheme.primary
                          : Colors.grey.shade400,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight:
                      active ? FontWeight.w700 : FontWeight.w400,
                  color: done || active
                      ? AppTheme.textDark
                      : AppTheme.textGrey,
                ),
              ),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildChecklist() {
    return Container(
      padding: const EdgeInsets.all(14),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.checklist_outlined,
                  size: 16, color: AppTheme.primary),
              const SizedBox(width: 6),
              const Text(
                'Completion Checklist',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textDark,
                ),
              ),
              const Spacer(),
              Text(
                '${_checklist.where((c) => c.checked).length}/${_checklist.length}',
                style: const TextStyle(
                    fontSize: 12, color: AppTheme.textGrey),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...List.generate(_checklist.length, (i) {
            final item = _checklist[i];
            return InkWell(
              onTap: _phase >= 2 && _phase < 4
                  ? () => setState(() => item.checked = !item.checked)
                  : null,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    vertical: 8, horizontal: 4),
                child: Row(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: item.checked
                            ? AppTheme.primary
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: item.checked
                              ? AppTheme.primary
                              : Colors.grey.shade400,
                          width: 1.5,
                        ),
                      ),
                      child: item.checked
                          ? const Icon(Icons.check,
                              size: 14, color: Colors.white)
                          : null,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      item.label,
                      style: TextStyle(
                        fontSize: 13,
                        color: item.checked
                            ? AppTheme.textGrey
                            : AppTheme.textDark,
                        decoration: item.checked
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildCompleteButton(BuildContext context) {
    final allChecked = _checklist.every((c) => c.checked);

    return Column(
      children: [
        if (!allChecked)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              'Saari cheezein check karein pehle',
              style: TextStyle(
                  fontSize: 12, color: Colors.orange.shade700),
            ),
          ),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: allChecked
                ? () => Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            FeedbackScreen(provider: widget.provider),
                      ),
                    )
                : null,
            icon: const Icon(Icons.star_outline, color: Colors.white),
            label: const Text(
              'Kaam Complete — Feedback Do',
              style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              disabledBackgroundColor: Colors.grey.shade300,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              padding: const EdgeInsets.symmetric(vertical: 16),
              elevation: 0,
            ),
          ),
        ),
      ],
    );
  }
}

class _CheckItem {
  final String label;
  bool checked = false;
  _CheckItem(this.label);
}
