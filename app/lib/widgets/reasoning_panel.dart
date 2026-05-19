import 'package:flutter/material.dart';
import '../models/provider_model.dart';
import '../theme/app_theme.dart';

class ReasoningPanel extends StatefulWidget {
  final String serviceType;
  final String locationHint;
  final ProviderModel topProvider;

  const ReasoningPanel({
    super.key,
    required this.serviceType,
    required this.locationHint,
    required this.topProvider,
  });

  @override
  State<ReasoningPanel> createState() => _ReasoningPanelState();
}

class _ReasoningPanelState extends State<ReasoningPanel> {
  final List<bool> _shown = List.filled(6, false);
  bool _complete = false;

  @override
  void initState() {
    super.initState();
    _animateSteps();
  }

  Future<void> _animateSteps() async {
    final delays = [400, 900, 1400, 1900, 2400, 2900];
    for (int i = 0; i < delays.length; i++) {
      await Future.delayed(Duration(milliseconds: delays[i]));
      if (mounted) setState(() => _shown[i] = true);
    }
    await Future.delayed(const Duration(milliseconds: 300));
    if (mounted) setState(() => _complete = true);
  }

  String get _serviceLabel {
    switch (widget.serviceType) {
      case 'ac_repair':
        return 'AC repair';
      case 'plumber':
        return 'plumber';
      case 'electrician':
        return 'electrician';
      case 'carpenter':
        return 'carpenter';
      case 'tutor':
        return 'tutor';
      default:
        return 'service';
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.topProvider;
    final steps = [
      '✓  Understood: $_serviceLabel, ${widget.locationHint}, tomorrow morning',
      '✓  Found 3 providers in your area',
      '✓  Checking 13 ranking factors...',
      '    → ${p.name}: Score ${p.rankScore}/100\n'
          '       Available ✓  ·  ${p.displayDistance} ✓  ·  Rating ${p.rating} ✓\n'
          '       On-time ${p.onTimeScore}% ✓  ·  Specialist ✓',
      '    → 2nd provider: Score 71/100\n'
          '       Available ✓  ·  2.4km  ·  Rating 4.3',
      '✓  Decision: ${p.name} is the best match',
    ];

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(left: 8, right: 50, bottom: 6),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF0FAF6),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(4),
            topRight: Radius.circular(14),
            bottomLeft: Radius.circular(14),
            bottomRight: Radius.circular(14),
          ),
          border: Border.all(color: AppTheme.primary.withValues(alpha: 0.25)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!_complete)
                  SizedBox(
                    width: 13,
                    height: 13,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppTheme.primary,
                    ),
                  )
                else
                  const Icon(Icons.check_circle, color: AppTheme.primary, size: 15),
                const SizedBox(width: 8),
                Text(
                  _complete ? 'Best match found!' : 'Analyzing...',
                  style: const TextStyle(
                    color: AppTheme.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ...List.generate(steps.length, (i) {
              return AnimatedOpacity(
                opacity: _shown[i] ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 400),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 5),
                  child: Text(
                    steps[i],
                    style: TextStyle(
                      fontSize: 12,
                      color: steps[i].startsWith('✓')
                          ? AppTheme.textDark
                          : AppTheme.textGrey,
                      height: 1.5,
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
