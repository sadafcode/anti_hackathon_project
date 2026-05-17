import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class AgentTraceStep {
  final String agentName;
  final String emoji;
  final String decision;
  final String reasoning;
  final String timestamp;
  final String status; // 'success', 'warning', 'running'
  final List<MapEntry<String, String>> details;
  bool isExpanded;

  AgentTraceStep({
    required this.agentName,
    required this.emoji,
    required this.decision,
    required this.reasoning,
    required this.timestamp,
    required this.status,
    required this.details,
    this.isExpanded = false,
  });
}

class AgentTraceScreen extends StatefulWidget {
  final String userMessage;
  // Live traces collected from the backend during the chat pipeline
  final List<Map<String, dynamic>>? liveTraces;

  const AgentTraceScreen({
    super.key,
    required this.userMessage,
    this.liveTraces,
  });

  @override
  State<AgentTraceScreen> createState() => _AgentTraceScreenState();
}

class _AgentTraceScreenState extends State<AgentTraceScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late List<AgentTraceStep> _steps;
  bool _allExpanded = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _steps = _buildSteps();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  // ── Build steps: live data if available, else hardcoded demo ──────────
  List<AgentTraceStep> _buildSteps() {
    final live = widget.liveTraces;
    if (live != null && live.isNotEmpty) {
      final steps = <AgentTraceStep>[_orchestratorStep()];
      for (final trace in live) {
        steps.add(_fromBackendTrace(trace));
      }
      return steps;
    }
    return _hardcodedSteps();
  }

  // Converts a backend AgentTrace JSON map → AgentTraceStep
  AgentTraceStep _fromBackendTrace(Map<String, dynamic> trace) {
    final rawStatus = trace['status'] as String? ?? 'success';
    // Map backend statuses to Flutter display statuses
    final String status;
    if (rawStatus == 'incomplete' || rawStatus == 'conflict') {
      status = 'warning';
    } else {
      status = rawStatus; // 'success' | 'warning'
    }

    final detailsMap = trace['details'] as Map<String, dynamic>? ?? {};
    final details = detailsMap.entries
        .map((e) => MapEntry(e.key, e.value.toString()))
        .toList();

    return AgentTraceStep(
      agentName: trace['agent'] as String? ?? 'Agent',
      emoji: trace['emoji'] as String? ?? '🤖',
      decision: trace['decision'] as String? ?? '',
      reasoning: trace['reasoning'] as String? ?? '',
      timestamp: _parseTimestamp(trace['timestamp'] as String? ?? ''),
      status: status,
      details: details,
    );
  }

  String _parseTimestamp(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';
    } catch (_) {
      return iso;
    }
  }

  AgentTraceStep _orchestratorStep() => AgentTraceStep(
        agentName: 'Orchestrator Agent',
        emoji: '🎯',
        decision: 'Request received — pipeline started',
        reasoning:
            'User request parsed. Routing to NLU Agent for language detection and entity extraction, '
            'then Intent Agent for field confirmation, then Discovery for provider ranking.',
        timestamp: _ts(0),
        status: 'success',
        details: [
          MapEntry('Input', '"${widget.userMessage}"'),
          const MapEntry(
              'Action', 'NLU → Intent → Discovery → Pricing → Booking'),
          const MapEntry('Mode', 'Agentic pipeline — live backend'),
        ],
      );

  // ── Hardcoded demo steps (shown when no live data yet) ───────────────
  List<AgentTraceStep> _hardcodedSteps() {
    return [
      AgentTraceStep(
        agentName: 'Orchestrator Agent',
        emoji: '🎯',
        decision: 'Request received — pipeline started',
        reasoning:
            'User request parsed. Routing to NLU Agent for language understanding.',
        timestamp: _ts(0),
        status: 'success',
        details: [
          const MapEntry('Input', '"AC bilkul kaam nahi kar raha..."'),
          const MapEntry(
              'Action', 'Triggered NLU → Intent → Discovery → Pricing → Booking'),
          const MapEntry('Session ID', 'SES-AG-2026'),
        ],
      ),
      AgentTraceStep(
        agentName: 'NLU Agent  (Gemini 2.5 Flash)',
        emoji: '🧠',
        decision: 'Language: Roman Urdu — Confidence: 88%',
        reasoning:
            'Detected Roman Urdu with mixed slang. Extracted service=ac_repair, '
            'location=G-13, urgency=high, time=tomorrow morning, budget_sensitive=true. '
            'Gemini used few-shot examples to handle misspellings and informal input.',
        timestamp: _ts(1),
        status: 'success',
        details: const [
          MapEntry('Language', 'roman_urdu'),
          MapEntry('Confidence', '88%'),
          MapEntry('Service Type', 'ac_repair'),
          MapEntry('Location', 'G-13'),
          MapEntry('Urgency', 'high'),
          MapEntry('Budget Sensitive', 'true'),
          MapEntry('Clarification Needed', 'false'),
          MapEntry('LLM Used', 'Gemini 2.5 Flash'),
        ],
      ),
      AgentTraceStep(
        agentName: 'Intent Agent',
        emoji: '📋',
        decision: 'All fields confirmed — intent complete',
        reasoning:
            'All 3 required fields present: service_type, location.area, preferred_time. '
            'No follow-up questions needed. Session cleared. ConfirmedIntent passed to Discovery.',
        timestamp: _ts(2),
        status: 'success',
        details: const [
          MapEntry('Service', 'ac_repair'),
          MapEntry('Area', 'G-13, Islamabad'),
          MapEntry('Date/Time', 'Tomorrow 09:00 AM'),
          MapEntry('Job Complexity', 'intermediate'),
          MapEntry('Missing Fields', 'None'),
          MapEntry('Follow-up Sent', 'No'),
        ],
      ),
      AgentTraceStep(
        agentName: 'Discovery & Ranking Agent  (Gemini)',
        emoji: '🔍',
        decision: '3 providers ranked — #1: Ali Hassan (88/100)',
        reasoning:
            'Gemini analyzed 13 weighted factors: availability, distance, rating, reliability, '
            'specialization, review_sentiment, review_recency, price_vs_budget, capacity, '
            'cancellation_rate, user_preference, risk_score, NADRA trust. '
            'Ali Hassan ranked #1 — NADRA verified, G-11 (neighbor area), 6yr AC exp, 92% on-time.',
        timestamp: _ts(4),
        status: 'success',
        details: const [
          MapEntry('Providers Scanned', '8'),
          MapEntry('Area Filter', 'G-13 + neighbors (G-11, I-8)'),
          MapEntry('#1 Ali Hassan', 'Score 88 — G-11, NADRA ✓, 6yr exp'),
          MapEntry('#2 Shahid Iqbal', 'Score 73 — G-11, no NADRA'),
          MapEntry('Ranking Engine', 'Gemini 2.5 Flash — 13 factors'),
          MapEntry('High-risk Filtered', '0 providers removed'),
        ],
      ),
      AgentTraceStep(
        agentName: 'Pricing Agent  (Gemini)',
        emoji: '💰',
        decision: 'Total: Rs. 1,473 — Provider earns 90%',
        reasoning:
            'Gemini calculated dynamic price: base Rs.800 + complexity ×1.2 (intermediate) '
            '+ urgency +30% (high) + distance Rs.120. No surge (morning slot). '
            'Budget alternative offered at Rs.600. Platform fee 10% — provider gets 90%.',
        timestamp: _ts(6),
        status: 'success',
        details: const [
          MapEntry('Base Rate', 'Rs. 800'),
          MapEntry('Complexity (×1.2)', 'Rs. 160'),
          MapEntry('Urgency (+30%)', 'Rs. 288'),
          MapEntry('Distance', 'Rs. 120'),
          MapEntry('Surge', 'Not applied'),
          MapEntry('Platform Fee (10%)', 'Rs. 147'),
          MapEntry('Total', 'Rs. 1,473'),
          MapEntry('Provider Earns', 'Rs. 1,326 (90%)'),
          MapEntry('Budget Option', 'Rs. 600 — basic checkup only'),
        ],
      ),
      AgentTraceStep(
        agentName: 'Booking & Scheduling Agent',
        emoji: '📅',
        decision: 'Booking BK-C9B651DC created — status: pending',
        reasoning:
            'Double-booking check passed (no conflict within 75-min buffer). '
            'Booking created in PENDING state — waiting for provider to accept. '
            'FCM notification sent. WhatsApp simulation triggered. Calendar slot blocked.',
        timestamp: _ts(8),
        status: 'success',
        details: const [
          MapEntry('Booking ID', 'BK-C9B651DC'),
          MapEntry('Provider', 'Ali Hassan'),
          MapEntry('Slot', 'Tomorrow 09:00 AM'),
          MapEntry('Conflict Check', 'PASSED — no overlap'),
          MapEntry('Status', 'Pending (awaiting provider accept)'),
          MapEntry('FCM Notification', 'Sent to provider ✓'),
          MapEntry('WhatsApp', 'Simulation triggered ✓'),
          MapEntry('Receipt', 'Sent to customer ✓'),
        ],
      ),
    ];
  }

  // Builds a fake timestamp offset from now (used only for hardcoded steps)
  String _ts(int offsetSeconds) {
    final t =
        DateTime.now().subtract(Duration(seconds: 60 - offsetSeconds * 10));
    return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:${t.second.toString().padLeft(2, '0')}';
  }

  // ── Extract top score from discovery step for stats bar ──────────────
  String _topScore() {
    for (final step in _steps) {
      if (step.emoji == '🔍') {
        // Try to find a detail key starting with '#1'
        for (final e in step.details) {
          if (e.key.startsWith('#1')) {
            final match = RegExp(r'Score (\d+)').firstMatch(e.value);
            if (match != null) return '${match.group(1)}/100';
          }
        }
        // Fallback: try parsing decision string
        final match = RegExp(r'(\d+)/100').firstMatch(step.decision);
        if (match != null) return match.group(0)!;
      }
    }
    return '—';
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'success':
        return AppTheme.primary;
      case 'warning':
        return const Color(0xFFF59E0B);
      case 'running':
        return const Color(0xFF3B82F6);
      default:
        return Colors.grey;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'success':
        return Icons.check_circle_rounded;
      case 'warning':
        return Icons.warning_amber_rounded;
      case 'running':
        return Icons.radio_button_checked;
      default:
        return Icons.circle_outlined;
    }
  }

  void _toggleAll() {
    setState(() {
      _allExpanded = !_allExpanded;
      for (final s in _steps) {
        s.isExpanded = _allExpanded;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isLive = widget.liveTraces != null && widget.liveTraces!.isNotEmpty;
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0E1A),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: (isLive ? AppTheme.primary : Colors.grey)
                    .withValues(alpha:0.2),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                    color: (isLive ? AppTheme.primary : Colors.grey)
                        .withValues(alpha:0.5)),
              ),
              child: Row(
                children: [
                  AnimatedBuilder(
                    animation: _pulseController,
                    builder: (_, _) => Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: (isLive ? AppTheme.primary : Colors.grey)
                            .withValues(alpha:0.4 + 0.6 * _pulseController.value),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isLive ? 'LIVE TRACE' : 'DEMO TRACE',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isLive ? AppTheme.primary : Colors.grey,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'Agent Reasoning',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: _toggleAll,
            child: Text(
              _allExpanded ? 'Collapse All' : 'Expand All',
              style: const TextStyle(color: AppTheme.primary, fontSize: 13),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── User query banner ────────────────────────────────────────
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF1A2035),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white12),
            ),
            child: Row(
              children: [
                const Text('🗣️', style: TextStyle(fontSize: 16)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    widget.userMessage,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Pipeline summary bar ─────────────────────────────────────
          Container(
            margin: const EdgeInsets.fromLTRB(16, 10, 16, 4),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha:0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _pipelineStat('${_steps.length}', 'Agents'),
                _divider(),
                _pipelineStat(
                    '${_steps.where((s) => s.status == 'success').length}',
                    'Passed'),
                _divider(),
                _pipelineStat('Gemini', 'LLM'),
                _divider(),
                _pipelineStat(_topScore(), 'Top Score'),
              ],
            ),
          ),

          // ── Trace list ───────────────────────────────────────────────
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              itemCount: _steps.length,
              itemBuilder: (_, i) => _buildTraceCard(_steps[i], i),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pipelineStat(String value, String label) => Column(
        children: [
          Text(value,
              style: const TextStyle(
                  color: AppTheme.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 15)),
          Text(label,
              style: const TextStyle(color: Colors.white38, fontSize: 11)),
        ],
      );

  Widget _divider() =>
      Container(width: 1, height: 28, color: Colors.white12);

  Widget _buildTraceCard(AgentTraceStep step, int index) {
    final color = _statusColor(step.status);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF131929),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: step.isExpanded ? color.withValues(alpha:0.5) : Colors.white10,
        ),
      ),
      child: Column(
        children: [
          // ── Header (always visible) ────────────────────────────────
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => setState(() => step.isExpanded = !step.isExpanded),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  // Step number
                  Container(
                    width: 26,
                    height: 26,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: color.withValues(alpha:0.15),
                      border: Border.all(color: color.withValues(alpha:0.4)),
                    ),
                    child: Text(
                      '${index + 1}',
                      style: TextStyle(
                          color: color,
                          fontSize: 11,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(step.emoji, style: const TextStyle(fontSize: 18)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          step.agentName,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 13),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          step.decision,
                          style: TextStyle(color: color, fontSize: 11),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Icon(_statusIcon(step.status), color: color, size: 16),
                      const SizedBox(height: 2),
                      Text(
                        step.timestamp,
                        style: const TextStyle(
                            color: Colors.white30, fontSize: 10),
                      ),
                    ],
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    step.isExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: Colors.white30,
                    size: 18,
                  ),
                ],
              ),
            ),
          ),

          // ── Expanded body ──────────────────────────────────────────
          if (step.isExpanded) ...[
            Container(height: 1, color: Colors.white10),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Reasoning block
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D1522),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.psychology_outlined,
                                color: AppTheme.primary, size: 14),
                            SizedBox(width: 6),
                            Text('Reasoning',
                                style: TextStyle(
                                    color: AppTheme.primary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.8)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          step.reasoning,
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 12, height: 1.5),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Decision log
                  const Text(
                    'DECISION LOG',
                    style: TextStyle(
                        color: Colors.white38,
                        fontSize: 10,
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  ...step.details.map((e) => Padding(
                        padding: const EdgeInsets.only(bottom: 5),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 130,
                              child: Text(
                                e.key,
                                style: const TextStyle(
                                    color: Colors.white38, fontSize: 11),
                              ),
                            ),
                            const Text('→ ',
                                style: TextStyle(
                                    color: Colors.white24, fontSize: 11)),
                            Expanded(
                              child: Text(
                                e.value,
                                style: const TextStyle(
                                    color: Colors.white70, fontSize: 11),
                              ),
                            ),
                          ],
                        ),
                      )),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
