import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class ComparisonPoint {
  final String category;
  final String traditional;
  final String khidmatBot;
  final bool khidmatBotWins;

  const ComparisonPoint({
    required this.category,
    required this.traditional,
    required this.khidmatBot,
    required this.khidmatBotWins,
  });
}

class BaselineComparisonScreen extends StatelessWidget {
  const BaselineComparisonScreen({super.key});

  static const _points = [
    ComparisonPoint(
      category: '🌐 Language Support',
      traditional: 'Urdu/local only\nNo slang/misspelling handling\nNo confidence scoring',
      khidmatBot: 'English + Urdu script + Roman Urdu\nSlang & misspellings handled\nAI confidence score per request',
      khidmatBotWins: true,
    ),
    ComparisonPoint(
      category: '🔍 Provider Discovery',
      traditional: 'Manual WhatsApp/phone search\nPersonal referrals only\nNo availability check',
      khidmatBot: '13-factor AI ranking (Gemini)\nNearby + neighbor area search\nReal-time availability check',
      khidmatBotWins: true,
    ),
    ComparisonPoint(
      category: '🏅 Trust Verification',
      traditional: 'No verification\nUnknown background\nNo reliability history',
      khidmatBot: 'NADRA NIC verification + Blue Tick\nRisk score (low/medium/high)\nCancellation rate tracked',
      khidmatBotWins: true,
    ),
    ComparisonPoint(
      category: '💰 Pricing',
      traditional: 'Negotiated informally\nNo breakdown\nOften unfair to provider',
      khidmatBot: 'Dynamic AI pricing with full breakdown\nUrgency + complexity + surge\nProvider earns ~90% (transparent)',
      khidmatBotWins: true,
    ),
    ComparisonPoint(
      category: '📅 Scheduling',
      traditional: 'Manual coordination\nDouble bookings common\nNo conflict resolution',
      khidmatBot: '75-min buffer prevents double booking\nAuto-reschedule on cancellation\nWaitlist management',
      khidmatBotWins: true,
    ),
    ComparisonPoint(
      category: '⚖️ Dispute Handling',
      traditional: 'No formal process\nNo refunds\nWord against word',
      khidmatBot: 'AI-reasoned resolution (Gemini)\n5 dispute types handled\n3-strike blacklist system',
      khidmatBotWins: true,
    ),
    ComparisonPoint(
      category: '📊 Provider Accountability',
      traditional: 'No rating system\nNo penalty for no-show\nNo performance tracking',
      khidmatBot: 'Star rating + review sentiment\nPenalty for cancel-after-accept\nProfile updated in real-time',
      khidmatBotWins: true,
    ),
    ComparisonPoint(
      category: '⚡ Response Time',
      traditional: 'Hours — multiple calls/messages\nHuman coordination required',
      khidmatBot: 'Seconds — full AI pipeline\nNLU → Match → Price → Book automated',
      khidmatBotWins: true,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0E1A),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Baseline Comparison',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      body: Column(
        children: [
          // ── Header banner ─────────────────────────────────────────
          Container(
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.primary.withValues(alpha:0.2),
                  const Color(0xFF1A2035),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.primary.withValues(alpha:0.3)),
            ),
            child: const Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Traditional vs KhidmatBot',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Pakistan ki informal economy mein agentic AI ka impact',
                        style:
                            TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Text('🤖', style: TextStyle(fontSize: 36)),
              ],
            ),
          ),

          // ── Column headers ────────────────────────────────────────
          Container(
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: [
                const SizedBox(width: 0),
                // Traditional header
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        vertical: 8, horizontal: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2D1B1B),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(8),
                        bottomLeft: Radius.circular(8),
                      ),
                    ),
                    child: const Column(
                      children: [
                        Text('❌', style: TextStyle(fontSize: 18)),
                        SizedBox(height: 4),
                        Text(
                          'Traditional\n(WhatsApp/Phone)',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: Color(0xFFFF6B6B),
                              fontWeight: FontWeight.bold,
                              fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 2),
                // KhidmatBot header
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        vertical: 8, horizontal: 10),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha:0.2),
                      borderRadius: const BorderRadius.only(
                        topRight: Radius.circular(8),
                        bottomRight: Radius.circular(8),
                      ),
                    ),
                    child: const Column(
                      children: [
                        Text('✅', style: TextStyle(fontSize: 18)),
                        SizedBox(height: 4),
                        Text(
                          'KhidmatBot\n(AI Orchestrated)',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: AppTheme.primary,
                              fontWeight: FontWeight.bold,
                              fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Comparison rows ───────────────────────────────────────
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              itemCount: _points.length,
              itemBuilder: (_, i) => _buildRow(_points[i]),
            ),
          ),

          // ── Summary score bar ─────────────────────────────────────
          Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF131929),
              borderRadius: BorderRadius.circular(12),
              border:
                  Border.all(color: AppTheme.primary.withValues(alpha:0.3)),
            ),
            child: Column(
              children: [
                const Text(
                  'OVERALL SCORE',
                  style: TextStyle(
                      color: Colors.white38,
                      fontSize: 11,
                      letterSpacing: 1.4,
                      fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          const Text(
                            '0 / 8',
                            style: TextStyle(
                                color: Color(0xFFFF6B6B),
                                fontSize: 28,
                                fontWeight: FontWeight.bold),
                          ),
                          const Text('Traditional',
                              style: TextStyle(
                                  color: Colors.white38, fontSize: 12)),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: 0,
                              backgroundColor: Colors.white10,
                              color: const Color(0xFFFF6B6B),
                              minHeight: 6,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text('vs',
                          style: TextStyle(
                              color: Colors.white38,
                              fontWeight: FontWeight.bold)),
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          const Text(
                            '8 / 8',
                            style: TextStyle(
                                color: AppTheme.primary,
                                fontSize: 28,
                                fontWeight: FontWeight.bold),
                          ),
                          const Text('KhidmatBot',
                              style: TextStyle(
                                  color: Colors.white38, fontSize: 12)),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: const LinearProgressIndicator(
                              value: 1,
                              backgroundColor: Colors.white10,
                              color: AppTheme.primary,
                              minHeight: 6,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRow(ComparisonPoint point) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF131929),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Category label
          Container(
            width: double.infinity,
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: const BoxDecoration(
              color: Color(0xFF1A2035),
              borderRadius:
                  BorderRadius.vertical(top: Radius.circular(10)),
            ),
            child: Text(
              point.category,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 13),
            ),
          ),
          // Two columns
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Traditional
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: const BoxDecoration(
                      color: Color(0xFF1C1212),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('❌ ',
                            style: TextStyle(fontSize: 12)),
                        Expanded(
                          child: Text(
                            point.traditional,
                            style: const TextStyle(
                                color: Color(0xFFFF8A8A),
                                fontSize: 11,
                                height: 1.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Container(width: 1, color: Colors.white10),
                // KhidmatBot
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha:0.05),
                      borderRadius: const BorderRadius.only(
                        bottomRight: Radius.circular(10),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('✅ ',
                            style: TextStyle(fontSize: 12)),
                        Expanded(
                          child: Text(
                            point.khidmatBot,
                            style: const TextStyle(
                                color: Color(0xFF86EFAC),
                                fontSize: 11,
                                height: 1.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
