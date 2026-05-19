import 'package:flutter/material.dart';
import '../models/provider_model.dart';
import '../theme/app_theme.dart';
import '../widgets/provider_avatar.dart';
import '../services/api_service.dart';
import '../services/booking_firestore_service.dart';
import 'agent_trace_screen.dart';

class FeedbackScreen extends StatefulWidget {
  final ProviderModel provider;
  final String? bookingId;
  final String clientName;

  const FeedbackScreen({
    super.key,
    required this.provider,
    this.bookingId,
    this.clientName = 'Client',
  });

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen>
    with SingleTickerProviderStateMixin {
  int _selectedStars = 0;
  int _hoveredStar = 0;
  final TextEditingController _commentController = TextEditingController();
  bool _submitted = false;

  late AnimationController _successController;
  late Animation<double> _successScale;

  final List<String> _quickTags = [
    'Arrived on time',
    'Excellent work',
    'Kept it clean',
    'Communicated clearly',
    'Affordable',
  ];
  final Set<String> _selectedTags = {};

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
  }

  @override
  void dispose() {
    _commentController.dispose();
    _successController.dispose();
    super.dispose();
  }

  String get _ratingLabel {
    return switch (_selectedStars) {
      1 => 'Very poor',
      2 => 'Not great',
      3 => 'Okay',
      4 => 'Good',
      5 => 'Excellent!',
      _ => 'Select a rating',
    };
  }

  Color get _ratingColor {
    return switch (_selectedStars) {
      1 || 2 => Colors.red.shade600,
      3 => Colors.orange.shade600,
      4 => Colors.lightGreen.shade700,
      5 => AppTheme.primary,
      _ => AppTheme.textGrey,
    };
  }

  bool _isSubmitting = false;
  double _newRating = 0;
  int _newTotalReviews = 0;

  void _submit() async {
    if (_selectedStars == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please rate first'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );

    final reviewText = [
      _commentController.text.trim(),
      if (_selectedTags.isNotEmpty) _selectedTags.join(', '),
    ].where((s) => s.isNotEmpty).join(' | ');

    try {
      // 1. Update providers.json via backend (recalculates rolling average)
      final rateResp = await ApiService.rateProvider(
        providerId: widget.provider.id,
        bookingId: widget.bookingId ?? 'unknown',
        stars: _selectedStars,
        reviewText: reviewText,
        clientName: widget.clientName,
      );

      // 2. Save review to Firestore reviews collection (real-time, shown on profile)
      await BookingFirestoreService.submitReview(
        providerId: widget.provider.id,
        bookingId: widget.bookingId ?? 'unknown',
        stars: _selectedStars,
        reviewText: reviewText.isEmpty ? _ratingLabel : reviewText,
        clientName: widget.clientName,
      );

      // 3. Also send full feedback to backend agent (for dispute/quality logic)
      await ApiService.submitFeedback({
        'provider': widget.provider.toJson(),
        'mock_action': 'on_time',
        'feedback': {
          'stars': _selectedStars,
          'comment': _commentController.text.trim(),
          'tags': _selectedTags.toList(),
        },
      });

      if (mounted) {
        Navigator.pop(context);
        setState(() {
          _isSubmitting = false;
          _submitted = true;
          _newRating = (rateResp['new_rating'] as num?)?.toDouble() ??
              widget.provider.rating;
          _newTotalReviews =
              (rateResp['total_reviews'] as int?) ?? widget.provider.totalReviews + 1;
        });
        _successController.forward();
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Feedback'),
        automaticallyImplyLeading: !_submitted,
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
      body: _submitted ? _buildSuccessView(context) : _buildFormView(),
    );
  }

  Widget _buildFormView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildProviderCard(),
          const SizedBox(height: 16),
          _buildStarRating(),
          const SizedBox(height: 14),
          _buildQuickTags(),
          const SizedBox(height: 14),
          _buildCommentBox(),
          const SizedBox(height: 24),
          _buildSubmitButton(),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildProviderCard() {
    final p = widget.provider;
    return Container(
      padding: const EdgeInsets.all(16),
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
      child: Row(
        children: [
          ProviderAvatar(provider: p, radius: 30),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      p.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textDark,
                      ),
                    ),
                    if (p.blueTick) ...[
                      const SizedBox(width: 5),
                      const Icon(Icons.verified,
                          color: Colors.blue, size: 16),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  p.serviceTypes.first.replaceAll('_', ' '),
                  style: const TextStyle(
                      fontSize: 12, color: AppTheme.textGrey),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.star,
                        size: 13, color: Colors.amber.shade600),
                    const SizedBox(width: 3),
                    Text(
                      '${p.rating.toStringAsFixed(1)} (${p.totalReviews} reviews)',
                      style: const TextStyle(
                          fontSize: 12, color: AppTheme.textGrey),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.primaryLight,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'Job Done',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppTheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStarRating() {
    return Container(
      padding: const EdgeInsets.all(16),
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
        children: [
          const Text(
            'Rate the Provider',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppTheme.textDark,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) {
              final starNum = i + 1;
              final filled = starNum <= (_hoveredStar > 0
                  ? _hoveredStar
                  : _selectedStars);
              return GestureDetector(
                onTap: () =>
                    setState(() => _selectedStars = starNum),
                onLongPressStart: (_) =>
                    setState(() => _hoveredStar = starNum),
                onLongPressEnd: (_) =>
                    setState(() => _hoveredStar = 0),
                child: AnimatedScale(
                  scale: filled ? 1.15 : 1.0,
                  duration: const Duration(milliseconds: 150),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6),
                    child: Icon(
                      filled ? Icons.star : Icons.star_outline,
                      size: 40,
                      color: filled
                          ? Colors.amber.shade500
                          : Colors.grey.shade300,
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 12),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Text(
              _ratingLabel,
              key: ValueKey(_selectedStars),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: _ratingColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickTags() {
    return Container(
      width: double.infinity,
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
          const Text(
            'What did you like? (optional)',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppTheme.textDark,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _quickTags.map((tag) {
              final selected = _selectedTags.contains(tag);
              return GestureDetector(
                onTap: () => setState(() {
                  selected
                      ? _selectedTags.remove(tag)
                      : _selectedTags.add(tag);
                }),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: selected
                        ? AppTheme.primary
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: selected
                          ? AppTheme.primary
                          : Colors.grey.shade300,
                    ),
                  ),
                  child: Text(
                    tag,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: selected
                          ? Colors.white
                          : AppTheme.textDark,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentBox() {
    return Container(
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
      child: TextField(
        controller: _commentController,
        maxLines: 4,
        maxLength: 300,
        style: const TextStyle(fontSize: 14, color: AppTheme.textDark),
        decoration: InputDecoration(
          hintText:
              'Anything to add? (optional)\ne.g. "Finished quickly, kept the area clean"',
          hintStyle:
              const TextStyle(fontSize: 13, color: AppTheme.textGrey),
          contentPadding: const EdgeInsets.all(14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.white,
          counterStyle:
              const TextStyle(fontSize: 11, color: AppTheme.textGrey),
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _submit,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primary,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
          padding: const EdgeInsets.symmetric(vertical: 16),
          elevation: 0,
        ),
        child: const Text(
          'Submit Feedback',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _buildSuccessView(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: ScaleTransition(
          scale: _successScale,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.favorite,
                    size: 48, color: AppTheme.primary),
              ),
              const SizedBox(height: 24),
              const Text(
                'Thank You!',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.textDark,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Your review has been added to ${widget.provider.name}\'s profile!',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, color: AppTheme.textGrey),
              ),
              const SizedBox(height: 16),

              // Stars given
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  5,
                  (i) => Icon(
                    i < _selectedStars ? Icons.star : Icons.star_outline,
                    color: Colors.amber.shade500,
                    size: 28,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Updated provider rating card
              if (_newRating > 0)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.star, color: Colors.amber.shade600, size: 20),
                      const SizedBox(width: 6),
                      Text(
                        '${widget.provider.name}\'s new rating: ',
                        style: const TextStyle(
                            fontSize: 13, color: AppTheme.textDark),
                      ),
                      Text(
                        _newRating.toStringAsFixed(2),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: AppTheme.primary,
                        ),
                      ),
                      Text(
                        ' ($_newTotalReviews reviews)',
                        style: const TextStyle(
                            fontSize: 12, color: AppTheme.textGrey),
                      ),
                    ],
                  ),
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
                        borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Go Home',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
