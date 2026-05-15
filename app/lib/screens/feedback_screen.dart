import 'package:flutter/material.dart';
import '../models/provider_model.dart';
import '../theme/app_theme.dart';
import '../widgets/provider_avatar.dart';
import '../services/api_service.dart';

class FeedbackScreen extends StatefulWidget {
  final ProviderModel provider;

  const FeedbackScreen({super.key, required this.provider});

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
    'Waqt par aya',
    'Zabardast kaam',
    'Saaf safai ki',
    'Seedha seedha baat ki',
    'Sasta tha',
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
      1 => 'Bilkul theek nahi',
      2 => 'Zyada acha nahi',
      3 => 'Theek thak tha',
      4 => 'Acha tha',
      5 => 'Zabardast!',
      _ => 'Rating dein',
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

  void _submit() async {
    if (_selectedStars == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pehle rating dein'),
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
    
    try {
      final req = {
        'provider': widget.provider.toJson(),
        'mock_action': 'on_time', // Mock action since we are simulating
        'feedback': {
           'stars': _selectedStars,
           'comment': _commentController.text,
           'tags': _selectedTags.toList()
        }
      };
      
      await ApiService.submitFeedback(req);
      
      if (mounted) {
        Navigator.pop(context); // Close loader
        setState(() {
          _isSubmitting = false;
          _submitted = true;
        });
        _successController.forward();
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loader
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
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
              'Kaam Hua',
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
            'Provider ko rate karein',
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
            'Kya acha laga? (optional)',
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
              'Koi baat likhni hai? (optional)\nmisaal: "Bahut jaldi kaam kiya, area saaf rakhi"',
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
          'Feedback Submit Karo',
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
                'Shukriya!',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.textDark,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Aapka feedback ${widget.provider.name} ki profile update kar dega.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 14, color: AppTheme.textGrey),
              ),
              const SizedBox(height: 8),
              // Show selected stars
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  5,
                  (i) => Icon(
                    i < _selectedStars ? Icons.star : Icons.star_outline,
                    color: Colors.amber.shade500,
                    size: 26,
                  ),
                ),
              ),
              const SizedBox(height: 36),
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
                    'Home Jao',
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
