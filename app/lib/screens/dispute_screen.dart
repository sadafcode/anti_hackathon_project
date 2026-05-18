import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/provider_model.dart';
import '../theme/app_theme.dart';
import '../widgets/provider_avatar.dart';
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
  String? _selectedIssue;
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _bookingIdController = TextEditingController();
  bool _submitted = false;

  late AnimationController _successController;
  late Animation<double> _successScale;

  Map<String, dynamic>? _fetchedBooking;
  Map<String, dynamic>? _fetchedProvider;
  bool _isFetchingBooking = false;
  String? _fetchError;

  final List<_IssueType> _issues = [
    _IssueType(
      key: 'no_show',
      label: 'Provider nahi aya (No-show)',
      icon: Icons.person_off_outlined,
      color: Colors.red.shade600,
      hint: 'Provider agreed kiya tha lekin aya nahi...',
      resolution: 'Auto reschedule ya full refund milega',
    ),
    _IssueType(
      key: 'quality',
      label: 'Kaam theek nahi tha',
      icon: Icons.thumb_down_outlined,
      color: Colors.orange.shade700,
      hint: 'Kaam sahi se nahi hua, misaal ke taur par...',
      resolution: 'Evidence review ke baad compensation process hoga',
    ),
    _IssueType(
      key: 'price',
      label: 'Price se ikhtilaf',
      icon: Icons.payments_outlined,
      color: Colors.amber.shade700,
      hint: 'Quote aur charge mein farq tha...',
      resolution: 'Quote vs charge compare karke refund process hoga',
    ),
    _IssueType(
      key: 'other',
      label: 'Kuch aur masla',
      icon: Icons.report_problem_outlined,
      color: Colors.grey.shade600,
      hint: 'Masle ka tafseeli zikar karein...',
      resolution: '24 ghante mein team aap se raabta karegi',
    ),
  ];

  _IssueType? get _selected =>
      _selectedIssue == null
          ? null
          : _issues.firstWhere((i) => i.key == _selectedIssue);

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

    if (widget.bookingId != null) {
      _bookingIdController.text = widget.bookingId!;
      _fetchBookingDetails(widget.bookingId!);
    }
  }

  @override
  void dispose() {
    _descController.dispose();
    _bookingIdController.dispose();
    _successController.dispose();
    super.dispose();
  }

  Future<void> _fetchBookingDetails(String bookingId) async {
    if (bookingId.isEmpty) return;
    setState(() {
      _isFetchingBooking = true;
      _fetchError = null;
      _fetchedBooking = null;
      _fetchedProvider = null;
    });

    try {
      final doc = await FirebaseFirestore.instance
          .collection('bookings')
          .doc(bookingId)
          .get();

      if (!doc.exists) {
        setState(() {
          _isFetchingBooking = false;
          _fetchError = 'Yeh Booking ID nahi mili, check karein';
        });
        return;
      }

      final bookingData = doc.data();
      if (bookingData != null) {
        final providerId = bookingData['provider_id'] as String?;
        Map<String, dynamic>? providerData;

        if (providerId != null) {
          final pDoc = await FirebaseFirestore.instance
              .collection('providers')
              .doc(providerId)
              .get();
          if (pDoc.exists) {
            providerData = pDoc.data();
          }
        }

        setState(() {
          _fetchedBooking = bookingData;
          _fetchedProvider = providerData;
          _isFetchingBooking = false;
        });
      } else {
        setState(() {
          _isFetchingBooking = false;
          _fetchError = 'Booking details empty hain';
        });
      }
    } catch (e) {
      setState(() {
        _isFetchingBooking = false;
        _fetchError = 'Error fetching booking: $e';
      });
    }
  }

  bool _isSubmitting = false;
  String _resolutionFromServer = '';

  void _submit() async {
    if (_selectedIssue == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pehle masle ki qisam chunein'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    if (_descController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Masle ka tafseeli zikar karein'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final enteredBookingId = _bookingIdController.text.trim();
    if (widget.bookingId == null && enteredBookingId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Booking ID daalna lazmi hai'),
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
      String? finalBookingId = widget.bookingId ?? enteredBookingId;
      
      // If we haven't fetched the details yet, do a quick fetch
      if (_fetchedBooking == null) {
        await _fetchBookingDetails(finalBookingId);
      }

      if (_fetchedBooking == null) {
        if (mounted) {
          Navigator.pop(context); // Close loader
          setState(() => _isSubmitting = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_fetchError ?? 'Yeh Booking ID nahi mili, check karein'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }

      final finalProviderId = _fetchedBooking!['provider_id'] as String?;
      final resolvedService = _fetchedBooking!['service_type'] as String?;
      final resolvedCustomer = _fetchedBooking!['user_id'] as String?;
      final agreedAmount = _fetchedBooking!['amount'] ?? 1500;

      final providerObj = widget.provider?.toJson() ?? _fetchedProvider;
      final req = {
        'booking_id': finalBookingId,
        'provider_id': finalProviderId,
        'user_id': resolvedCustomer ?? ApiService.sessionId,
        'issue_type': _selectedIssue,
        'description': _descController.text,
        'service': resolvedService,
        'provider': providerObj,
        'dispute_type': _selectedIssue == 'quality' ? 'quality_complaint' : 
                        _selectedIssue == 'price' ? 'price_disagreement' : 
                        _selectedIssue,
        'original_price': agreedAmount,
        'overcharged_amount': 0, 
      };
      
      final res = await ApiService.submitDispute(req);
      
      if (mounted) {
        Navigator.pop(context); // Close loader
        setState(() {
          _isSubmitting = false;
          _submitted = true;
          _resolutionFromServer = res['resolution'] ?? 'Dispute filed. Awaiting provider response.';
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
        title: const Text('Dispute Darj Karein'),
        automaticallyImplyLeading: !_submitted,
      ),
      body: _submitted ? _buildSuccessView(context) : _buildFormView(),
    );
  }

  Widget _buildFormView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.provider != null) ...[
            _buildProviderCard(),
            const SizedBox(height: 16),
            _buildWarningBanner(),
            const SizedBox(height: 14),
          ],
          if (widget.bookingId == null) ...[
            _buildBookingIdField(),
            const SizedBox(height: 14),
          ],
          _buildIssueSelector(),
          const SizedBox(height: 14),
          if (_selected != null) _buildResolutionHint(),
          if (_selected != null) const SizedBox(height: 14),
          _buildDescriptionBox(),
          const SizedBox(height: 24),
          _buildSubmitButton(),
          const SizedBox(height: 8),
          _buildEscalationNote(),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildBookingIdField() {
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
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Booking ID daalein',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppTheme.textDark,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _bookingIdController,
                  decoration: InputDecoration(
                    hintText: 'e.g. BK-A1B2C3D4',
                    hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade400),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.grey.shade200),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppTheme.primary),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _isFetchingBooking
                    ? null
                    : () => _fetchBookingDetails(_bookingIdController.text.trim()),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 0,
                ),
                child: _isFetchingBooking
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(Colors.white),
                        ),
                      )
                    : const Text(
                        'Check',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Booking ID receipt ya confirmation screen par milti hai',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
          ),
          _buildFetchedBookingCard(),
        ],
      ),
    );
  }

  Widget _buildFetchedBookingCard() {
    if (_isFetchingBooking) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2.5)),
      );
    }
    if (_fetchError != null) {
      return Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.red.shade200),
        ),
        child: Text(
          _fetchError!,
          style: TextStyle(fontSize: 12, color: Colors.red.shade700),
        ),
      );
    }
    if (_fetchedBooking == null) return const SizedBox.shrink();

    final pName = _fetchedBooking!['provider_name'] ?? 'Provider';
    final service = (_fetchedBooking!['service_type'] ?? _fetchedBooking!['service'] ?? 'Service').toString().replaceAll('_', ' ');
    final amount = _fetchedBooking!['amount'] ?? 0;
    final date = _fetchedBooking!['datetime'] ?? 'Kal';

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.primaryLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.receipt_long_outlined, size: 16, color: AppTheme.primary),
              const SizedBox(width: 6),
              const Text(
                'Booking Details found!',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _fetchedRow('Provider:', pName),
          _fetchedRow('Service:', service),
          _fetchedRow('Price:', 'Rs. $amount'),
          _fetchedRow('Waqt:', date),
        ],
      ),
    );
  }

  Widget _fetchedRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.textGrey, fontWeight: FontWeight.w500)),
          const SizedBox(width: 4),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 12, color: AppTheme.textDark, fontWeight: FontWeight.w700))),
        ],
      ),
    );
  }

  Widget _buildProviderCard() {
    if (widget.provider == null) return const SizedBox.shrink();
    final p = widget.provider!;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          ProviderAvatar(provider: p, radius: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      p.name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textDark,
                      ),
                    ),
                    if (p.blueTick) ...[
                      const SizedBox(width: 4),
                      const Icon(Icons.verified,
                          color: Colors.blue, size: 14),
                    ],
                  ],
                ),
                Text(
                  p.serviceTypes.first.replaceAll('_', ' '),
                  style: const TextStyle(
                      fontSize: 12, color: AppTheme.textGrey),
                ),
              ],
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: Text(
              'Dispute',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Colors.red.shade700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWarningBanner() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.amber.shade300),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline,
              size: 16, color: Colors.amber.shade800),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Ghalat dispute submit karne par aapki account par asar par sakta hai. Sach baat likhein.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.amber.shade900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIssueSelector() {
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(14, 14, 14, 8),
            child: Text(
              'Masle ki qisam',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppTheme.textDark,
              ),
            ),
          ),
          ..._issues.map((issue) {
            final selected = _selectedIssue == issue.key;
            return InkWell(
              onTap: () => setState(() => _selectedIssue = issue.key),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 12),
                decoration: BoxDecoration(
                  color: selected
                      ? issue.color.withValues(alpha: 0.08)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: selected ? issue.color : Colors.grey.shade200,
                    width: selected ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: issue.color.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(issue.icon, size: 18, color: issue.color),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        issue.label,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: selected
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: selected ? issue.color : AppTheme.textDark,
                        ),
                      ),
                    ),
                    if (selected)
                      Icon(Icons.radio_button_checked,
                          size: 18, color: issue.color)
                    else
                      Icon(Icons.radio_button_unchecked,
                          size: 18, color: Colors.grey.shade300),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 6),
        ],
      ),
    );
  }

  Widget _buildResolutionHint() {
    final issue = _selected!;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: issue.color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: issue.color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.auto_fix_high_outlined, size: 15, color: issue.color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Resolution: ${issue.resolution}',
              style: TextStyle(
                fontSize: 12,
                color: issue.color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDescriptionBox() {
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
        controller: _descController,
        maxLines: 5,
        maxLength: 500,
        style: const TextStyle(fontSize: 14, color: AppTheme.textDark),
        decoration: InputDecoration(
          hintText: _selected?.hint ??
              'Masle ka tafseeli zikar karein...',
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
      child: ElevatedButton.icon(
        onPressed: _submit,
        icon: const Icon(Icons.send_outlined, color: Colors.white, size: 18),
        label: const Text(
          'Dispute Submit Karo',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red.shade600,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
          padding: const EdgeInsets.symmetric(vertical: 16),
          elevation: 0,
        ),
      ),
    );
  }

  Widget _buildEscalationNote() {
    return Center(
      child: Text(
        'Agar masla hal na ho → 24 ghante mein human escalation',
        style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildSuccessView(BuildContext context) {
    final issue = _selected!;
    final ticketId =
        'DT-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';

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
                  color: issue.color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.assignment_turned_in_outlined,
                    size: 48, color: issue.color),
              ),
              const SizedBox(height: 24),
              const Text(
                'Dispute Darj Ho Gaya',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textDark,
                ),
              ),
              const SizedBox(height: 10),
              // Ticket ID
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Ticket ID: ',
                      style: TextStyle(
                          fontSize: 13, color: AppTheme.textGrey),
                    ),
                    Text(
                      ticketId,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textDark,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _resolutionFromServer.isNotEmpty ? _resolutionFromServer : issue.resolution,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: issue.color,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Aapko 24 ghante mein update milega',
                textAlign: TextAlign.center,
                style:
                    TextStyle(fontSize: 13, color: AppTheme.textGrey),
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

class _IssueType {
  final String key;
  final String label;
  final IconData icon;
  final Color color;
  final String hint;
  final String resolution;

  const _IssueType({
    required this.key,
    required this.label,
    required this.icon,
    required this.color,
    required this.hint,
    required this.resolution,
  });
}
