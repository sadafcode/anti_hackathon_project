import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../services/booking_firestore_service.dart';
import '../theme/app_theme.dart';

class BookingStatusScreen extends StatelessWidget {
  final String bookingId;
  final String providerName;
  final String serviceType;

  const BookingStatusScreen({
    super.key,
    required this.bookingId,
    required this.providerName,
    required this.serviceType,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: const Text('Booking Status')),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: BookingFirestoreService.bookingStatusStream(bookingId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Error: ${snapshot.error}',
                  style: const TextStyle(color: AppTheme.textGrey),
                ),
              ),
            );
          }

          final data = snapshot.data?.data();
          final status = data?['status'] as String? ?? 'pending';

          return switch (status) {
            'confirmed' => _buildConfirmed(data!),
            'declined' => _buildDeclined(data?['declineReason'] as String?),
            'cancelled' => _buildCancelled(),
            _ => _buildPending(),
          };
        },
      ),
    );
  }

  Widget _buildPending() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 56,
              height: 56,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
            const SizedBox(height: 24),
            const Text(
              'Provider ka Intezaar',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppTheme.textDark,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '$providerName apki request dekh rahe hain...',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: AppTheme.textGrey),
            ),
            const SizedBox(height: 24),
            _infoCard(
              Icons.info_outline,
              'Provider ko 5 minute mein jawab dena hoga. Agar jawab na aye tu doosra provider dhoondha jaye ga.',
              Colors.blue.shade600,
              Colors.blue.shade50,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConfirmed(Map<String, dynamic> data) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 24),
            decoration: BoxDecoration(
              color: AppTheme.primary,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Column(
              children: [
                Icon(Icons.check_circle, color: Colors.white, size: 56),
                SizedBox(height: 10),
                Text(
                  'Provider Ne Accept Kar Liya!',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Aapki booking confirm ho gayi hai',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _detailCard([
            _DetailRow(Icons.person_outline, 'Provider', data['providerName'] as String? ?? ''),
            _DetailRow(Icons.build_outlined, 'Service', data['serviceType'] as String? ?? serviceType),
            _DetailRow(Icons.location_on_outlined, 'Area', data['area'] as String? ?? ''),
            _DetailRow(Icons.calendar_today_outlined, 'Date/Time', data['datetime'] as String? ?? ''),
            _DetailRow(
              Icons.payments_outlined,
              'Amount',
              'Rs. ${data['amount'] ?? 0}',
              valueColor: AppTheme.primary,
              valueBold: true,
            ),
          ]),
          const SizedBox(height: 16),
          _infoCard(
            Icons.phone_outlined,
            'Provider jald hi aap se rabta kare ga. Koi masla ho tu KhidmatBot support se milein.',
            AppTheme.primary,
            AppTheme.primaryLight,
          ),
        ],
      ),
    );
  }

  Widget _buildDeclined(String? reason) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.search, size: 40, color: Colors.orange.shade600),
            ),
            const SizedBox(height: 20),
            const Text(
              'Provider Busy Hai',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppTheme.textDark,
              ),
            ),
            const SizedBox(height: 10),
            if (reason != null && reason.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'Wajah: $reason',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13, color: AppTheme.textGrey),
                ),
              ),
            const SizedBox(height: 16),
            _infoCard(
              Icons.autorenew,
              'Doosra provider dhoondha ja raha hai. Chat mein wapas jayein.',
              Colors.orange.shade600,
              Colors.orange.shade50,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCancelled() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.cancel, size: 40, color: Colors.red.shade600),
            ),
            const SizedBox(height: 20),
            const Text(
              'Booking Cancel Ho Gayi',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppTheme.textDark,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Provider ne booking cancel kar di. Naya provider dhoondha ja raha hai.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: AppTheme.textGrey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailCard(List<_DetailRow> rows) {
    return Container(
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
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: rows
              .map(
                (r) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  child: Row(
                    children: [
                      Icon(r.icon, size: 15, color: AppTheme.textGrey),
                      const SizedBox(width: 8),
                      Text(
                        r.label,
                        style: const TextStyle(
                            fontSize: 13, color: AppTheme.textGrey),
                      ),
                      const Spacer(),
                      Text(
                        r.value,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: r.valueBold
                              ? FontWeight.w700
                              : FontWeight.w600,
                          color: r.valueColor ?? AppTheme.textDark,
                        ),
                      ),
                    ],
                  ),
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  Widget _infoCard(
      IconData icon, String text, Color iconColor, Color bgColor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: iconColor),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 12, color: iconColor),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;
  final bool valueBold;

  const _DetailRow(
    this.icon,
    this.label,
    this.value, {
    this.valueColor,
    this.valueBold = false,
  });
}
