import 'package:flutter/material.dart';
import '../models/message.dart';
import '../models/provider_model.dart';
import '../theme/app_theme.dart';
import '../widgets/chat_bubble.dart';
import '../widgets/provider_card_bubble.dart';
import '../widgets/reasoning_panel.dart';
import '../widgets/typing_indicator.dart';
import 'map_picker_screen.dart';
import 'agent_trace_screen.dart';
import 'baseline_comparison_screen.dart';
import '../services/api_service.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<Message> _messages = [];
  bool _isTyping = false;
  bool _isListening = false;

  List<ProviderModel>? _currentProviders;
  int _currentProviderIndex = 0;

  // Traces collected from backend during the last full pipeline run
  final List<Map<String, dynamic>> _collectedTraces = [];
  String _lastUserMessage = '';

  @override
  void initState() {
    super.initState();
    _addWelcomeMessage();
  }

  void _addWelcomeMessage() {
    setState(() {
      _messages.add(Message.agent(
        'Assalam o Alaikum! Main aapka service assistant hoon.\n\nBatayein kya kaam hai? Plumber, electrician, AC technician, tutor — jo bhi chahiye, main dhundh kar deta hoon.',
      ));
    });
  }

  void _sendMessage() async {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add(Message.user(text));
      _inputController.clear();
      _isTyping = true;
      _lastUserMessage = text;
      _collectedTraces.clear();
    });
    _scrollToBottom();

    try {
      final response = await ApiService.sendMessage(text);

      // Collect NLU + Intent traces
      final traces = response['_traces'] as Map<String, dynamic>?;
      if (traces != null) {
        if (traces['nlu'] != null) {
          _collectedTraces.add(Map<String, dynamic>.from(traces['nlu'] as Map));
        }
        if (traces['intent'] != null) {
          _collectedTraces
              .add(Map<String, dynamic>.from(traces['intent'] as Map));
        }
      }

      final intentStatus = response['intent']['status'];
      
      if (intentStatus == 'incomplete') {
        final followUp = response['intent']['follow_up_question'];
        setState(() {
          _isTyping = false;
          _messages.add(Message.agent(followUp));
        });
        _scrollToBottom();
      } else if (intentStatus == 'complete') {
        final confirmedIntent = response['intent']['confirmed_intent'];
        final lang = response['nlu']?['language_detected'] ?? 'roman_urdu';
        String searchMsg;
        if (lang == 'english') {
          searchMsg = 'Got it! Searching for the best providers for you...';
        } else if (lang == 'urdu') {
          searchMsg = 'سمجھ گیا۔ آپ کے لیے بہترین providers تلاش کر رہا ہوں...';
        } else {
          searchMsg = 'Samajh gaya. Aap ke liye best providers dhundh raha hoon...';
        }

        setState(() {
          _isTyping = false;
          _messages.add(Message.agent(searchMsg));
          _isTyping = true;
        });
        _scrollToBottom();

        // Trigger discovery
        final discoveryResp = await ApiService.discoverProviders(confirmedIntent);

        // Collect discovery trace
        final discTrace = discoveryResp['_trace'] as Map<String, dynamic>?;
        if (discTrace != null) {
          _collectedTraces.add(Map<String, dynamic>.from(discTrace));
        }

        if (discoveryResp['status'] == 'no_providers') {
           setState(() {
              _isTyping = false;
              _messages.add(Message.agent(discoveryResp['message'] ?? 'Is area mein abhi koi provider available nahi.'));
           });
           _scrollToBottom();

           // If backend suggests an alternative provider, show their card directly
           if (discoveryResp['suggested_provider'] != null) {
             final suggested = ProviderModel.fromJson(
               Map<String, dynamic>.from(discoveryResp['suggested_provider'])
             );
             setState(() {
               _currentProviders = [suggested];
               _currentProviderIndex = 0;
               _messages.add(Message.providerCard(suggested, requestedDatetime: confirmedIntent['datetime'] as String?));
             });
             _scrollToBottom();
           }
        } else {
           // Parse providers — also cache raw JSON for auto-reschedule
           final providersJson = discoveryResp['ranked_providers'] as List;
           final providers = providersJson.map((p) => ProviderModel.fromJson(p)).toList();
           ApiService.lastDiscoveredProviders = providersJson
               .map((p) => Map<String, dynamic>.from(p as Map))
               .toList();
           ApiService.lastConfirmedIntent =
               Map<String, dynamic>.from(confirmedIntent as Map);
           
           setState(() {
              _isTyping = false;
              _messages.add(Message.reasoning(
                serviceType: confirmedIntent['service_type'],
                locationHint: confirmedIntent['location']['area'],
                topProvider: providers.first,
              ));
              _messages.add(Message.providerCard(providers.first, requestedDatetime: confirmedIntent['datetime'] as String?));
           });
           _scrollToBottom();

           _currentProviders = providers;
           _currentProviderIndex = 0;
           
           // We need to pass confirmedIntent globally or to the next screen. Let's save it.
           // Actually ProviderProfileScreen accepts ProviderModel, we might need intent too.
           // For now, let's just keep it here.
        }
      }
    } catch (e) {
      setState(() {
        _isTyping = false;
        _messages.add(Message.agent('Oops! Network error: $e'));
      });
      _scrollToBottom();
    }
  }

  void _showNextProvider() {
    if (_currentProviders == null ||
        _currentProviderIndex >= _currentProviders!.length - 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Is area mein aur koi provider available nahi.'),
          backgroundColor: Colors.grey.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }
    _currentProviderIndex++;
    final next = _currentProviders![_currentProviderIndex];
    setState(() {
      _messages.add(Message.agent('Dosra option:'));
      _messages.add(Message.providerCard(next, requestedDatetime: ApiService.lastConfirmedIntent?['datetime'] as String?));
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _openMapPicker() async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const MapPickerScreen()),
    );
    if (result != null && mounted) {
      setState(() => _inputController.text = result);
    }
  }

  void _toggleMic() {
    setState(() => _isListening = !_isListening);
    if (_isListening) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Sun raha hoon... (Voice input — coming soon)'),
          backgroundColor: AppTheme.primary,
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) setState(() => _isListening = false);
      });
    }
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.support_agent, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('KhidmatBot',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                Text('Service Assistant • Online',
                    style: TextStyle(fontSize: 11, color: Colors.white70)),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Agent Trace',
            icon: const Icon(Icons.account_tree_outlined, color: Colors.white),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AgentTraceScreen(
                  userMessage: _lastUserMessage.isNotEmpty
                      ? _lastUserMessage
                      : (_messages.isNotEmpty
                          ? (_messages.firstWhere(
                              (m) => m.type == MessageType.user,
                              orElse: () => _messages.first,
                            ).text)
                          : 'AC bilkul kaam nahi kar raha, kal subah G-13 mein technician chahiye'),
                  liveTraces:
                      _collectedTraces.isNotEmpty ? List.from(_collectedTraces) : null,
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Baseline Comparison',
            icon: const Icon(Icons.compare_arrows_rounded, color: Colors.white),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const BaselineComparisonScreen(),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.only(top: 12, bottom: 8),
              itemCount: _messages.length + (_isTyping ? 1 : 0),
              itemBuilder: (context, index) {
                if (_isTyping && index == _messages.length) {
                  return const TypingIndicator();
                }
                final msg = _messages[index];
                switch (msg.type) {
                  case MessageType.user:
                  case MessageType.agent:
                    return ChatBubble(message: msg);
                  case MessageType.reasoning:
                    return ReasoningPanel(
                      serviceType: msg.serviceType!,
                      locationHint: msg.locationHint!,
                      topProvider: msg.provider!,
                    );
                  case MessageType.providerCard:
                    return ProviderCardBubble(
                      provider: msg.provider!,
                      onShowAlternative: _showNextProvider,
                      requestedDatetime: msg.requestedDatetime,
                    );
                }
              },
            ),
          ),
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.inputBg,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            _LocationButton(onTap: _openMapPicker),
            const SizedBox(width: 6),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: AppTheme.background,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextField(
                        controller: _inputController,
                        decoration: const InputDecoration(
                          hintText: 'Kya kaam chahiye? (Roman Urdu/English)',
                          hintStyle:
                              TextStyle(color: Color(0xFFAAAAAA), fontSize: 14),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(vertical: 10),
                        ),
                        style: const TextStyle(fontSize: 15),
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _sendMessage(),
                        maxLines: null,
                      ),
                    ),
                    const SizedBox(width: 4),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            _MicButton(isListening: _isListening, onTap: _toggleMic),
            const SizedBox(width: 6),
            _SendButton(onTap: _sendMessage),
          ],
        ),
      ),
    );
  }
}

class _MicButton extends StatelessWidget {
  final bool isListening;
  final VoidCallback onTap;

  const _MicButton({required this.isListening, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: isListening ? Colors.red : Colors.grey.shade100,
          shape: BoxShape.circle,
          border: Border.all(
            color: isListening ? Colors.red.shade300 : Colors.grey.shade300,
          ),
        ),
        child: Icon(
          isListening ? Icons.mic : Icons.mic_none,
          color: isListening ? Colors.white : AppTheme.textGrey,
          size: 20,
        ),
      ),
    );
  }
}

class _LocationButton extends StatelessWidget {
  final VoidCallback onTap;

  const _LocationButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: AppTheme.primaryLight,
          shape: BoxShape.circle,
          border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
        ),
        child: const Icon(Icons.location_on_outlined,
            color: AppTheme.primary, size: 20),
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  final VoidCallback onTap;

  const _SendButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: const BoxDecoration(
          color: AppTheme.primary,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
      ),
    );
  }
}
