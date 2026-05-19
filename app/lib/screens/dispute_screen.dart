import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/provider_model.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';

class DisputeScreen extends StatefulWidget {
  final ProviderModel? provider;
  final String? bookingId;
  final String? providerId;

  const DisputeScreen({
    super.key,
    this.provider,
    this.bookingId,
    this.providerId,
  });

  @override
  State<DisputeScreen> createState() => _DisputeScreenState();
}

class _DisputeScreenState extends State<DisputeScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _commentCtrl = TextEditingController();
  final TextEditingController _bookingIdCtrl = TextEditingController();

  final List<XFile> _screenshots = [];
  final ImagePicker _picker = ImagePicker();

  bool _isSubmitting = false;
  bool _submitted = false;
  String _disputeId = '';

  // Auto-loaded booking card
  Map<String, dynamic>? _bookingData;
  bool _loadingBooking = false;

  late AnimationController _successController;
  late Animation<double> _successScale;

  @override
  void initState() {
    super.initState();
    if (widget.bookingId != null) {
      _bookingIdCtrl.text = widget.bookingId!;
      _loadBookingCard(widget.bookingId!);
    }
    _successController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _successScale = CurvedAnimation(
      parent: _successController,
      curve: Curves.elasticOut,
    );
  }

  Future<void> _loadBookingCard(String bookingId) async {
    if (bookingId.isEmpty) return;
    setState(() { _loadingBooking = true; _bookingData = null; });
    try {
      final doc = await FirebaseFirestore.instance.collection('bookings').doc(bookingId).get();
      if (doc.exists && mounted) {
        setState(() { _bookingData = doc.data(); _loadingBooking = false; });
      } else if (mounted) {
        setState(() => _loadingBooking = false);
      }
    } catch (_) {
      if (mounted) setState(() => _loadingBooking = false);
    }
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    _bookingIdCtrl.dispose();
    _successController.dispose();
    super.dispose();
  }

  Future<void> _pickScreenshot() async {
    if (kIsWeb) {
      final img = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
      if (img != null) setState(() => _screenshots.add(img));
      return;
    }
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined, color: AppTheme.primary),
              title: const Text('Choose from Gallery'),
              onTap: () async {
                Navigator.pop(context);
                final img = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
                if (img != null) setState(() => _screenshots.add(img));
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined, color: AppTheme.primary),
              title: const Text('Take a Photo'),
              onTap: () async {
                Navigator.pop(context);
                final img = await _picker.pickImage(source: ImageSource.camera, imageQuality: 80);
                if (img != null) setState(() => _screenshots.add(img));
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<String> _uploadImage(XFile xFile) async {
    try {
      final ref = FirebaseStorage.instance
          .ref()
          .child('disputes/evidence/${DateTime.now().millisecondsSinceEpoch}_${xFile.name}');
      if (kIsWeb) {
        final bytes = await xFile.readAsBytes();
        await ref.putData(bytes);
      } else {
        await ref.putFile(File(xFile.path));
      }
      return await ref.getDownloadURL();
    } catch (_) {
      return '';
    }
  }

  Future<void> _submit() async {
    final bookingId = _bookingIdCtrl.text.trim();
    final comment = _commentCtrl.text.trim();

    // Ya Booking ID ho ya Screenshot — dono mein se koi ek zaroor
    if (bookingId.isEmpty && _screenshots.isEmpty) {
      _snack('Booking ID ya kam az kam ek screenshot zaroor dein');
      return;
    }
    if (comment.isEmpty) {
      _snack('Masle ka zikar karein comment mein');
      return;
    }
    setState(() => _isSubmitting = true);
    _showLoader();

    try {
      final res = await ApiService.submitDispute({
        'booking_id': bookingId,
        'provider_id': widget.providerId ?? '',
        'user_id': ApiService.sessionId,
        'issue_type': 'other',
        'description': comment,
        'dispute_type': 'general',
        'original_price': 0,
        'overcharged_amount': 0,
        'provider': widget.provider?.toJson(),
      });

      final disputeId = res['dispute_id'] as String? ?? 'DT-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';

      // Upload screenshots
      final List<String> photoUrls = [];
      for (final img in _screenshots) {
        final url = await _uploadImage(img);
        if (url.isNotEmpty) photoUrls.add(url);
      }

      if (photoUrls.isNotEmpty) {
        try {
          await FirebaseFirestore.instance.collection('disputes').doc(disputeId).update({
            'evidence_photos': photoUrls,
            'client_screenshots': photoUrls,
          });
        } catch (_) {}
      }

      if (mounted) {
        Navigator.pop(context); // close loader
        setState(() {
          _isSubmitting = false;
          _disputeId = disputeId;
          _submitted = true;
        });
        _successController.forward();
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        setState(() => _isSubmitting = false);
        _snack('Error: $e');
      }
    }
  }

  void _showLoader() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('File a Dispute'),
        automaticallyImplyLeading: !_submitted,
      ),
      body: _submitted ? _buildSuccess() : _buildForm(),
    );
  }

  // ─── SUCCESS VIEW ──────────────────────────────────────────────────────────

  Widget _buildSuccess() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: ScaleTransition(
        scale: _successScale,
        child: Column(
          mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.check_circle_rounded,
                    color: Colors.green.shade600, size: 48),
              ),
              const SizedBox(height: 20),
              const Text(
                'Dispute Filed Successfully!',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textDark,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Provider has been notified.\nThey will submit their response and evidence.\nAn AI report will be generated and sent to the team.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600, height: 1.6),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.tag, size: 16, color: AppTheme.primary),
                    const SizedBox(width: 6),
                    Text(
                      'Dispute ID: $_disputeId',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              // Timeline
              _buildTimeline(),
              const SizedBox(height: 28),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('OK', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ),
      );
  }

  Widget _buildTimeline() {
    final steps = [
      ('Dispute Filed', 'Your complaint has been registered', true),
      ('Provider Notified', 'Provider ko notification mili', true),
      ('Provider Response', 'They will submit a response and evidence', false),
      ('AI Report', 'Antigravity AI dono sides analyze karega', false),
      ('Team Decision', 'Hamari team final faisla karegi', false),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: steps.asMap().entries.map((entry) {
        final i = entry.key;
        final (title, subtitle, done) = entry.value;
        final isLast = i == steps.length - 1;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: done ? Colors.green.shade500 : Colors.grey.shade200,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    done ? Icons.check : Icons.radio_button_unchecked,
                    size: 16,
                    color: done ? Colors.white : Colors.grey.shade400,
                  ),
                ),
                if (!isLast)
                  Container(
                    width: 2,
                    height: 36,
                    color: done ? Colors.green.shade300 : Colors.grey.shade200,
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: done ? AppTheme.textDark : Colors.grey.shade500)),
                  Text(subtitle,
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                ],
              ),
            ),
          ],
        );
      }).toList(),
    );
  }

  // ─── FORM VIEW ─────────────────────────────────────────────────────────────

  Widget _buildForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Info banner
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.amber.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.amber.shade700, size: 18),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Enter your Booking ID (card will load automatically) — or upload a screenshot. Then describe the issue and submit.',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Booking ID
          _buildBookingIdSection(),
          const SizedBox(height: 16),

          // Screenshot upload
          _buildScreenshotSection(),
          const SizedBox(height: 16),

          // Comment
          _buildCommentSection(),
          const SizedBox(height: 24),

          // Submit button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _isSubmitting ? null : _submit,
              icon: const Icon(Icons.send_rounded),
              label: const Text(
                'Submit Dispute',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              'Provider will be given 24 hours to respond',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildBookingIdSection() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Label(text: 'Booking ID'),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _bookingIdCtrl,
                  readOnly: widget.bookingId != null,
                  onSubmitted: _loadBookingCard,
                  decoration: InputDecoration(
                    hintText: 'e.g. BK-A1B2C3D4',
                    prefixIcon: const Icon(Icons.receipt_long_outlined, size: 18),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
              ),
              if (widget.bookingId == null) ...[
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _loadingBooking
                      ? null
                      : () => _loadBookingCard(_bookingIdCtrl.text.trim()),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                  child: _loadingBooking
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Check', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Booking ID can be found on the card or confirmation screen',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
          ),
          // Auto-loaded booking card
          if (_loadingBooking)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),
          if (_bookingData != null) ...[
            const SizedBox(height: 12),
            _buildBookingCard(),
          ],
        ],
      ),
    );
  }

  Widget _buildBookingCard() {
    final d = _bookingData!;
    final provider = d['providerName'] ?? d['provider_name'] ?? 'Provider';
    final service = (d['serviceType'] ?? d['service_type'] ?? 'Service').toString().replaceAll('_', ' ');
    final amount = d['amount'] ?? 0;
    final status = d['status'] ?? 'N/A';
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.green.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green.shade600, size: 16),
              const SizedBox(width: 6),
              Text('Booking found', style: TextStyle(fontSize: 12, color: Colors.green.shade700, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 8),
          _bookingRow(Icons.person_outline, 'Provider', provider),
          _bookingRow(Icons.build_outlined, 'Service', service),
          _bookingRow(Icons.payments_outlined, 'Amount', 'Rs. $amount'),
          _bookingRow(Icons.info_outline, 'Status', status),
        ],
      ),
    );
  }

  Widget _bookingRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(icon, size: 14, color: Colors.grey.shade600),
          const SizedBox(width: 6),
          Text('$label: ', style: const TextStyle(fontSize: 12, color: AppTheme.textGrey)),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textDark))),
        ],
      ),
    );
  }

  Widget _buildScreenshotSection() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Label(text: 'Screenshot ya Evidence (Optional)'),
          const SizedBox(height: 10),
          if (_screenshots.isNotEmpty) ...[
            SizedBox(
              height: 100,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _screenshots.length,
                separatorBuilder: (context, idx) => const SizedBox(width: 8),
                itemBuilder: (_, i) => Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: kIsWeb
                          ? Image.network(_screenshots[i].path, width: 90, height: 90, fit: BoxFit.cover)
                          : Image.file(File(_screenshots[i].path), width: 90, height: 90, fit: BoxFit.cover),
                    ),
                    Positioned(
                      top: 2,
                      right: 2,
                      child: GestureDetector(
                        onTap: () => setState(() => _screenshots.removeAt(i)),
                        child: Container(
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close, size: 16, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
          GestureDetector(
            onTap: _pickScreenshot,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppTheme.primary.withValues(alpha: 0.3),
                  style: BorderStyle.solid,
                ),
              ),
              child: Column(
                children: [
                  Icon(Icons.add_photo_alternate_outlined,
                      color: AppTheme.primary, size: 28),
                  const SizedBox(height: 6),
                  Text(
                    _screenshots.isEmpty ? 'Add Screenshot' : 'Add More',
                    style: const TextStyle(
                      color: AppTheme.primary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentSection() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Label(text: 'Describe the Issue'),
          const SizedBox(height: 8),
          TextField(
            controller: _commentCtrl,
            maxLines: 5,
            decoration: InputDecoration(
              hintText: 'What happened? Describe in detail...\n\nExample: Provider overcharged / work was not done properly...',
              hintStyle: TextStyle(fontSize: 12, color: Colors.grey.shade400),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              contentPadding: const EdgeInsets.all(12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _card({required Widget child}) {
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
      child: child,
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label({required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: AppTheme.textDark,
      ),
    );
  }
}

