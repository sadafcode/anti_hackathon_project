import 'package:flutter/material.dart';
import '../models/message.dart';
import '../services/firestore_service.dart';
import '../models/provider_model.dart';
import '../theme/app_theme.dart';
import '../widgets/chat_bubble.dart';
import '../widgets/provider_card_bubble.dart';
import '../widgets/reasoning_panel.dart';
import '../widgets/typing_indicator.dart';
import 'map_picker_screen.dart';
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
  List<ProviderModel> _cachedProviders = [];

  @override
  void initState() {
    super.initState();
    _addWelcomeMessage();
    _preloadProviders();
  }

  Future<void> _preloadProviders() async {
    try {
      final all = await FirestoreService.fetchProviders();
      if (mounted) setState(() => _cachedProviders = all);
    } catch (_) {}
  }

  void _addWelcomeMessage() {
    setState(() {
      _messages.add(Message.agent(
        'Assalam o Alaikum! Main aapka service assistant hoon.\n\nBatayein kya kaam hai? Plumber, electrician, AC technician, tutor — jo bhi chahiye, main dhundh kar deta hoon.',
      ));
    });
  }

  String? _detectServiceType(String text) {
    final lower = text.toLowerCase();
    if (lower.contains('ac') || lower.contains('technician')) return 'ac_repair';
    if (lower.contains('plumber') || lower.contains('plumbing')) return 'plumber';
    if (lower.contains('electrician') || lower.contains('bijli')) return 'electrician';
    if (lower.contains('carpenter') || lower.contains('carpent')) return 'carpenter';
    if (lower.contains('tutor') || lower.contains('teacher') || lower.contains('teacher')) return 'tutor';
    if (lower.contains('driver')) return 'driver';
    if (lower.contains('mechanic')) return 'mechanic';
    return null;
  }

  String _detectLocation(String text) {
    final lower = text.toLowerCase();
    final patterns = {
      'G-17': ['g-17', 'g17'],
      'G-13': ['g-13', 'g13'],
      'G-11': ['g-11', 'g11'],
      'F-10': ['f-10', 'f10'],
      'F-8': ['f-8', 'f8'],
      'I-8': ['i-8', 'i8'],
      'Gulshan': ['gulshan'],
      'Islamabad': ['islamabad'],
    };
    for (final entry in patterns.entries) {
      if (entry.value.any((p) => lower.contains(p))) return entry.key;
    }
    return 'aapke area';
  }

  bool _isCompleteRequest(String text) {
    if (_detectServiceType(text) == null) return false;
    final lower = text.toLowerCase();
    return lower.contains('g-') ||
        lower.contains('f-') ||
        lower.contains('h-') ||
        lower.contains('i-') ||
        lower.contains('gulshan') ||
        lower.contains('islamabad') ||
        lower.contains('kal') ||
        lower.contains('aaj') ||
        lower.contains('subah') ||
        lower.contains('sham') ||
        lower.contains('block') ||
        lower.contains('sector') ||
        lower.contains('mein') ||
        lower.contains('may') ||
        lower.contains('me ');
  }

  String _getMockReply(String text) {
    final serviceType = _detectServiceType(text);
    if (serviceType != null) {
      return 'Samajh gaya. Kaunse area mein chahiye aur kab? Area aur time batayein.';
    }
    final lower = text.toLowerCase();
    if (lower.contains('kal') || lower.contains('aaj')) {
      return 'Theek hai. Kaunsi service chahiye? (AC, plumber, electrician, etc.)';
    }
    if (lower.contains('budget') || lower.contains('sasta') || lower.contains('kam')) {
      return 'Budget ka khayal rakhunga. Kaunsi service chahiye aur kahan?';
    }
    return 'Samajh gaya. Aur thodi detail batayein — kya kaam hai aur kahan?';
  }

  void _sendMessage() async {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add(Message.user(text));
      _inputController.clear();
      _isTyping = true;
    });
    _scrollToBottom();

    try {
      final response = await ApiService.sendMessage(text);
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
        
        setState(() {
          _isTyping = false;
          _messages.add(Message.agent('Samajh gaya. Searching for the best providers...'));
          _isTyping = true;
        });
        _scrollToBottom();

        // Trigger discovery
        final discoveryResp = await ApiService.discoverProviders(confirmedIntent);
        
        if (discoveryResp['status'] == 'no_providers') {
           setState(() {
              _isTyping = false;
              _messages.add(Message.agent(discoveryResp['message'] ?? 'Is area mein abhi koi provider available nahi.'));
           });
           _scrollToBottom();
        } else {
           // Parse providers
           final providersJson = discoveryResp['ranked_providers'] as List;
           final providers = providersJson.map((p) => ProviderModel.fromJson(p)).toList();
           
           setState(() {
              _isTyping = false;
              _messages.add(Message.reasoning(
                serviceType: confirmedIntent['service_type'],
                locationHint: confirmedIntent['location']['area'],
                topProvider: providers.first,
              ));
              _messages.add(Message.providerCard(providers.first));
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
      _messages.add(Message.providerCard(next));
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
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onPressed: () {},
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
