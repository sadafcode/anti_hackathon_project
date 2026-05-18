import 'package:flutter/material.dart';
import '../services/api_service.dart';

class AgentTraceScreen extends StatelessWidget {
  const AgentTraceScreen({super.key});

  Map<String, dynamic>? _getTraceForSection(String sectionName) {
    try {
      return ApiService.globalAgentTraces.firstWhere((t) => t['agent'] == sectionName);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final sections = [
      'Language Parsing',
      'Provider Ranking',
      'Scheduling',
      'Price Logic',
      'Action Execution',
      'Fallback Behavior',
    ];

    int triggeredCount = 0;
    int notTriggeredCount = 0;
    for (var s in sections) {
      if (_getTraceForSection(s) != null) triggeredCount++;
      else notTriggeredCount++;
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0E1A),
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Agent Trace', style: TextStyle(color: Colors.white)),
      ),
      body: Column(
        children: [
          // Summary Bar
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            color: const Color(0xFF131929),
            child: Text(
              '$triggeredCount triggered | $notTriggeredCount not triggered',
              style: const TextStyle(
                color: Color(0xFF1D9E75),
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              children: sections.map((section) {
                final trace = _getTraceForSection(section);
                return Card(
                  color: const Color(0xFF131929),
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: Colors.white10),
                  ),
                  child: Theme(
                    data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      initiallyExpanded: trace != null,
                      iconColor: Colors.white54,
                      collapsedIconColor: Colors.white54,
                      title: Text(
                        section,
                        style: const TextStyle(
                          color: Color(0xFF1D9E75),
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          width: double.infinity,
                          decoration: const BoxDecoration(
                            border: Border(top: BorderSide(color: Colors.white10)),
                          ),
                          child: trace == null
                              ? const Text(
                                  'Not triggered',
                                  style: TextStyle(color: Colors.white54, fontStyle: FontStyle.italic),
                                )
                              : _buildTraceDetails(trace),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTraceDetails(Map<String, dynamic> trace) {
    final inputs = trace['key_inputs'] as Map<String, dynamic>? ?? {};
    final outputs = trace['key_outputs'] as Map<String, dynamic>? ?? {};
    final decision = trace['decision']?.toString() ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (decision.isNotEmpty) ...[
          const Text('Decision:', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 12)),
          const SizedBox(height: 4),
          Text(decision, style: const TextStyle(color: Colors.white, fontSize: 13)),
          const SizedBox(height: 12),
        ],
        if (inputs.isNotEmpty) ...[
          const Text('Key Inputs:', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 12)),
          const SizedBox(height: 4),
          ...inputs.entries.map((e) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text('• ${e.key}: ${e.value}', style: const TextStyle(color: Colors.white54, fontSize: 12)),
          )),
          const SizedBox(height: 12),
        ],
        if (outputs.isNotEmpty) ...[
          const Text('Key Outputs:', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 12)),
          const SizedBox(height: 4),
          ...outputs.entries.map((e) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text('• ${e.key}: ${e.value}', style: const TextStyle(color: Colors.white54, fontSize: 12)),
          )),
        ],
      ],
    );
  }
}
