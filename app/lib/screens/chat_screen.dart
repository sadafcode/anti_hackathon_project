import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';
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
import '../utils/location_helper.dart';

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
  
  final SpeechToText _speech = SpeechToText();
  bool _speechEnabled = false;
  String _selectedLocale = 'ur-PK';

  List<ProviderModel>? _currentProviders;
  int _currentProviderIndex = 0;

  String _lastUserMessage = '';
  bool _clearTracesOnNextMessage = false;

  @override
  void initState() {
    super.initState();
    _initSpeech();
    _addWelcomeMessage();
    ApiService.registerReturnToChat(_handleDeclineReturn);
  }

  void _handleDeclineReturn() {
    final action = ApiService.pendingPostDeclineAction;
    if (action == null) return;
    ApiService.pendingPostDeclineAction = null;

    final declinedName = action['declined_name'] as String? ?? 'Provider';

    if (action['type'] == 'show_next') {
      final nextJson = Map<String, dynamic>.from(action['next_provider_json'] as Map);
      final nextProvider = ProviderModel.fromJson(nextJson);
      final nextIdx = _currentProviders?.indexWhere((p) => p.id == nextProvider.id) ?? -1;
      if (nextIdx >= 0) {
        _currentProviderIndex = nextIdx;
      } else {
        _currentProviders = [nextProvider, ...?_currentProviders];
        _currentProviderIndex = 0;
      }
      setState(() {
        _messages.add(Message.agent('$declinedName ne request decline kar di. Yeh raha agla best provider:'));
        _messages.add(Message.providerCard(
          nextProvider,
          requestedDatetime: ApiService.lastConfirmedIntent?['datetime'] as String?,
          serviceDetails: ApiService.lastConfirmedIntent?['service_details'] as String?,
        ));
      });
    } else {
      setState(() {
        _messages.add(Message.agent(
          '$declinedName ne aapki request decline kar di.\n\nMaafi chahte hain — is waqt aapke area mein koi doosra provider available nahi hai. Thodi der baad dobara try karein.',
        ));
      });
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  void _addWelcomeMessage() {
    setState(() {
      _messages.add(Message.agent(
        'Assalam o Alaikum! Main aapka service assistant hoon.\n\nBatayein kya kaam hai? Plumber, electrician, AC technician, tutor — jo bhi chahiye, main dhundh kar deta hoon.',
      ));
    });
  }

  void _sendMessage([String? overrideText]) async {
    final text = (overrideText ?? _inputController.text).trim();
    if (text.isEmpty) return;

    if (_isListening) {
      _speech.stop();
      setState(() {
        _isListening = false;
      });
    }

    if (_clearTracesOnNextMessage) {
      ApiService.globalAgentTraces.clear();
      _clearTracesOnNextMessage = false;
    }

    setState(() {
      _messages.add(Message.user(text));
      _inputController.clear();
      _isTyping = true;
      _lastUserMessage = text;
    });
    _scrollToBottom();

    try {
      final response = await ApiService.sendMessage(text);

      // Agent Traces are now accumulated globally in ApiService

      final intentStatus = response['intent']['status'];
      
      if (intentStatus == 'incomplete') {
        final followUp = response['intent']['follow_up_question'];
        setState(() {
          _isTyping = false;
          _messages.add(Message.agent(followUp));
        });
        _scrollToBottom();
      } else if (intentStatus == 'complete') {
        _clearTracesOnNextMessage = true;
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

        // Attach GPS coordinates to intent before discovery
        final gpsLocation = await getUserWebLocation();
        final intentWithCoords = Map<String, dynamic>.from(confirmedIntent);
        if (gpsLocation != null) {
          intentWithCoords['customer_lat'] = gpsLocation.latitude;
          intentWithCoords['customer_lng'] = gpsLocation.longitude;
        }

        // Trigger discovery
        final discoveryResp = await ApiService.discoverProviders(intentWithCoords);

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
               _messages.add(Message.providerCard(suggested, requestedDatetime: confirmedIntent['datetime'] as String?, serviceDetails: confirmedIntent['service_details'] as String?));
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
              _messages.add(Message.providerCard(providers.first, requestedDatetime: confirmedIntent['datetime'] as String?, serviceDetails: confirmedIntent['service_details'] as String?));
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
      _messages.add(Message.providerCard(next, requestedDatetime: ApiService.lastConfirmedIntent?['datetime'] as String?, serviceDetails: ApiService.lastConfirmedIntent?['service_details'] as String?));
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

  void _initSpeech() async {
    try {
      final available = await _speech.initialize(
        onError: (val) {
          debugPrint('Speech error: $val');
          if (mounted) {
            setState(() => _isListening = false);
          }
        },
        onStatus: (val) {
          debugPrint('Speech status: $val');
          if (val == 'done' || val == 'notListening') {
            if (mounted && _isListening) {
              setState(() => _isListening = false);
              final text = _inputController.text.trim();
              _speech.cancel();
              _inputController.clear();
              if (text.isNotEmpty) {
                _sendMessage(text);
              }
            }
          }
        },
      );
      if (mounted) {
        setState(() {
          _speechEnabled = available;
        });
      }
    } catch (e) {
      debugPrint('Speech initialize catch error: $e');
    }
  }

  void _toggleLocale() {
    setState(() {
      _selectedLocale = _selectedLocale == 'ur-PK' ? 'en-US' : 'ur-PK';
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _selectedLocale == 'ur-PK'
              ? 'Urdu (اردو) selected for voice input.'
              : 'English / Roman Urdu selected for voice input.',
        ),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _toggleMic() async {
    if (!_speechEnabled) {
      _initSpeech();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Initializing speech recognition...'),
          backgroundColor: AppTheme.primary,
          duration: const Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    if (_isListening) {
      await _speech.stop();
      // The onStatus callback will handle setting _isListening = false and calling _sendMessage()
    } else {
      setState(() {
        _isListening = true;
        // Do NOT clear _inputController.text as per user request
      });
      try {
        await _speech.listen(
          onResult: (result) {
            if (!mounted || !_isListening) return;
            setState(() {
              _inputController.text = result.recognizedWords;
            });
          },
          listenFor: const Duration(seconds: 10),
          pauseFor: const Duration(seconds: 2),
          localeId: _selectedLocale,
        );
      } catch (e) {
        debugPrint('Speech listen failed: $e');
        if (mounted) {
          setState(() {
            _isListening = false;
          });
        }
      }
    }
  }

  @override
  void dispose() {
    _speech.stop();
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
              MaterialPageRoute(builder: (_) => const AgentTraceScreen()),
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
              physics: const AlwaysScrollableScrollPhysics(),
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
                      serviceDetails: msg.serviceDetails,
                      onContractCreated: (p, c) {}, // handled inside PricingScreen
                    );
                  case MessageType.contract:
                    return const SizedBox.shrink(); // no longer shown in chat
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
                    GestureDetector(
                      onTap: _toggleLocale,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryLight,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
                        ),
                        child: Text(
                          _selectedLocale == 'ur-PK' ? 'اردو' : 'EN',
                          style: const TextStyle(
                            color: AppTheme.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
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

class _MicButton extends StatefulWidget {
  final bool isListening;
  final VoidCallback onTap;

  const _MicButton({required this.isListening, required this.onTap});

  @override
  State<_MicButton> createState() => _MicButtonState();
}

class _MicButtonState extends State<_MicButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    );
    _pulse = Tween<double>(begin: 1.0, end: 1.35).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    if (widget.isListening) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant _MicButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isListening != oldWidget.isListening) {
      if (widget.isListening) {
        _controller.repeat();
      } else {
        _controller.stop();
        _controller.reset();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (context, child) {
          return Stack(
            alignment: Alignment.center,
            children: [
              if (widget.isListening)
                Container(
                  width: 44 * _pulse.value,
                  height: 44 * _pulse.value,
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.4 * (1.0 - (_pulse.value - 1.0) / 0.35)),
                    shape: BoxShape.circle,
                  ),
                ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: widget.isListening ? Colors.red : Colors.grey.shade100,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: widget.isListening ? Colors.red.shade300 : Colors.grey.shade300,
                  ),
                  boxShadow: widget.isListening
                      ? [
                          BoxShadow(
                            color: Colors.red.withValues(alpha: 0.4),
                            blurRadius: 8,
                            spreadRadius: 2,
                          )
                        ]
                      : [],
                ),
                child: Icon(
                  widget.isListening ? Icons.mic : Icons.mic_none,
                  color: widget.isListening ? Colors.white : AppTheme.primary,
                  size: 20,
                ),
              ),
            ],
          );
        },
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
