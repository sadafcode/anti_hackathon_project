import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/scheduler.dart';
import '../models/provider_model.dart';
import '../models/pricing_model.dart';
import '../services/api_service.dart';
import '../screens/booking_waiting_screen.dart';

class MicroContractCard extends StatefulWidget {
  final String contractId;
  final ProviderModel provider;
  final PricingModel pricing;

  const MicroContractCard({
    super.key,
    required this.contractId,
    required this.provider,
    required this.pricing,
  });

  @override
  State<MicroContractCard> createState() => _MicroContractCardState();
}

class _MicroContractCardState extends State<MicroContractCard> {
  bool _accepting = false;
  bool _declined = false;

  void _acceptContract() async {
    if (_accepting) return;
    setState(() => _accepting = true);
    try {
      await ApiService.acceptContract(widget.contractId, 'user');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error accepting contract: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _accepting = false);
      }
    }
  }

  void _declineContract() async {
    setState(() => _declined = true);
    try {
      await FirebaseFirestore.instance
          .collection('contracts')
          .doc(widget.contractId)
          .update({'status': 'cancelled'});
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('contracts')
          .doc(widget.contractId)
          .snapshots(),
      builder: (context, snapshot) {
        Map<String, dynamic> data = {};
        if (snapshot.hasData && snapshot.data != null && snapshot.data!.exists) {
          data = snapshot.data!.data() ?? {};
        }

        final status = data['status'] as String? ?? 'pending_both_accept';
        final userAccepted = data['user_accepted'] as bool? ?? false;
        final providerAccepted = data['provider_accepted'] as bool? ?? false;
        final bookingId = data['booking_id'] as String? ?? '';

        final laborCost = data['labor_cost'] as num? ?? widget.pricing.providerReceives;
        final materialsCost = data['materials_cost'] as num? ?? 0;
        final total = data['total'] as num? ?? widget.pricing.total;

        if (status == 'locked' && bookingId.isNotEmpty) {
          SchedulerBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => BookingWaitingScreen(
                    bookingId: bookingId,
                    providerId: widget.provider.id,
                    provider: widget.provider,
                    pricing: widget.pricing,
                  ),
                ),
              );
            }
          });
        }

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(
              color: status == 'locked' 
                  ? Colors.green.shade300 
                  : (status == 'cancelled' || _declined ? Colors.red.shade200 : Colors.grey.shade200),
              width: 1.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Gradient Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: status == 'locked'
                        ? [Colors.green.shade700, Colors.green.shade500]
                        : (status == 'cancelled' || _declined
                            ? [Colors.red.shade700, Colors.red.shade500]
                            : [const Color(0xFF1E3A8A), const Color(0xFF3B82F6)]),
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.gavel, color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                    const Text(
                      'Price Micro-Contract',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const Spacer(),
                    if (widget.provider.blueTick) ...[
                      const Icon(Icons.verified, color: Colors.white, size: 16),
                      const SizedBox(width: 4),
                      const Text(
                        'Verified',
                        style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                    ]
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Provider: ${widget.provider.name}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1F2937)),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Service: ${widget.pricing.budgetAlternativeDesc.isNotEmpty == true ? widget.pricing.budgetAlternativeDesc : (widget.provider.serviceTypes.isNotEmpty ? widget.provider.serviceTypes.first.replaceAll('_', ' ').toUpperCase() : 'General Service')}',
                      style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12),
                    ),
                    const SizedBox(height: 12),
                    const Divider(height: 1, color: Color(0xFFE5E7EB)),
                    const SizedBox(height: 12),
                    _costRow('Labor Cost (Ujrat)', 'Rs. $laborCost', Colors.black87),
                    const SizedBox(height: 6),
                    _costRow('Materials Cost (Saman)', 'Rs. $materialsCost', Colors.black87),
                    const SizedBox(height: 12),
                    const Divider(height: 1, color: Color(0xFFE5E7EB)),
                    const SizedBox(height: 12),
                    _costRow(
                      'Total locked price', 
                      'Rs. $total', 
                      Colors.green.shade700, 
                      isTotal: true
                    ),
                    const SizedBox(height: 16),
                    
                    if (status == 'cancelled' || _declined)
                      _badge('Contract Cancelled ✗', Colors.red.shade50, Colors.red.shade700)
                    else if (status == 'locked') ...[
                      _badge('Contract Locked ✓', Colors.green.shade50, Colors.green.shade700),
                      if (bookingId.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              'Booking Ref: ',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                            Text(
                              bookingId,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(width: 4),
                            IconButton(
                              constraints: const BoxConstraints(),
                              padding: EdgeInsets.zero,
                              icon: const Icon(Icons.copy, size: 14, color: Colors.grey),
                              onPressed: () {
                                Clipboard.setData(ClipboardData(text: bookingId));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Booking reference copied to clipboard!'),
                                    duration: Duration(seconds: 1),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ],
                    ]
                    else if (userAccepted && !providerAccepted)
                      _badge('Waiting for provider...', Colors.amber.shade50, Colors.amber.shade800, isPulsing: true)
                    else ...[
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _declineContract,
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: Colors.red.shade300),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                padding: const EdgeInsets.symmetric(vertical: 10),
                              ),
                              child: Text('Decline ✗', style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.bold, fontSize: 13)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _acceptContract,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green.shade600,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                elevation: 0,
                              ),
                              child: _accepting
                                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                  : const Text('Accept ✓', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                            ),
                          ),
                        ],
                      )
                    ]
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _costRow(String label, String value, Color valueColor, {bool isTotal = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isTotal ? 14 : 13,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.w500,
            color: isTotal ? const Color(0xFF374151) : const Color(0xFF6B7280),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isTotal ? 16 : 13,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.w600,
            color: valueColor,
          ),
        ),
      ],
    );
  }

  Widget _badge(String label, Color bgColor, Color textColor, {bool isPulsing = false}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: isPulsing
            ? _PulsingBadge(label: label, textColor: textColor)
            : Text(
                label,
                style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 13),
              ),
      ),
    );
  }
}

class _PulsingBadge extends StatefulWidget {
  final String label;
  final Color textColor;

  const _PulsingBadge({required this.label, required this.textColor});

  @override
  State<_PulsingBadge> createState() => _PulsingBadgeState();
}

class _PulsingBadgeState extends State<_PulsingBadge> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.5, end: 1.0).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _animation,
      child: Text(
        widget.label,
        style: TextStyle(color: widget.textColor, fontWeight: FontWeight.bold, fontSize: 13),
      ),
    );
  }
}
