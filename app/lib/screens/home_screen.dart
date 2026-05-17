import 'package:flutter/material.dart';
import '../services/provider_session.dart';
import '../theme/app_theme.dart';
import 'chat_screen.dart';
import 'provider_notification_screen.dart';
import 'provider_registration_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fadeAnim = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.18),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1D9E75), Color(0xFF0D6E52)],
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnim,
            child: SlideTransition(
              position: _slideAnim,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    const Spacer(flex: 2),
                    _buildLogoSection(),
                    const Spacer(flex: 3),
                    _buildButtons(context),
                    const Spacer(flex: 1),
                    _buildFooter(),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogoSection() {
    return Column(
      children: [
        Container(
          width: 88,
          height: 88,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.home_repair_service_rounded,
            size: 48,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'KhidmatBot',
          style: TextStyle(
            fontSize: 38,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Pakistan ka Apna Service Network',
          style: TextStyle(
            fontSize: 16,
            color: Colors.white.withValues(alpha: 0.88),
            fontWeight: FontWeight.w400,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Plumber  •  Electrician  •  AC Tech  •  aur bhi bahut kuch',
          style: TextStyle(
            fontSize: 12,
            color: Colors.white.withValues(alpha: 0.65),
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildButtons(BuildContext context) {
    return Column(
      children: [
        _ActionCard(
          icon: Icons.chat_bubble_rounded,
          title: 'KhidmatBot Kholo',
          subtitle: 'Service book karo — Plumber, AC Tech, Electrician aur zyada',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ChatScreen()),
          ),
        ),
        const SizedBox(height: 14),
        _ActionCard(
          icon: Icons.person_add_alt_1_rounded,
          title: 'Service Provider Baniye',
          subtitle: 'Register karein aur customers tak pohonchein — bilkul free',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ProviderRegistrationScreen()),
          ),
        ),
        const SizedBox(height: 14),
        _ActionCard(
          icon: Icons.notifications_active_rounded,
          title: 'Provider Hoon — Bookings Dekhein',
          subtitle: 'Incoming booking requests dekhein aur accept/decline karein',
          onTap: () => _openProviderScreen(context),
        ),
      ],
    );
  }

  Future<void> _openProviderScreen(BuildContext context) async {
    // 1. Check in-memory session (same app session as registration)
    // 2. Check Firestore (persists across restarts if OTP session alive)
    final savedId = await ProviderSession.load();
    if (!context.mounted) return;

    if (savedId != null) {
      // Registered provider — go straight to their dashboard
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ProviderNotificationScreen(providerId: savedId),
        ),
      );
      return;
    }

    // Not registered yet / no session — show manual entry dialog
    _showProviderIdDialog(context);
  }

  void _showProviderIdDialog(BuildContext context) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.notifications_active, color: AppTheme.primary, size: 20),
            SizedBox(width: 8),
            Text('Provider Login',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Agar aapne register kiya tha to Provider ID registration ke baad milti hai. Notification aane par automatically khul jata hai.',
                style: TextStyle(fontSize: 11, color: Colors.blueGrey),
              ),
            ),
            const SizedBox(height: 14),
            const Text('Provider ID daalein:',
                style: TextStyle(fontSize: 13, color: AppTheme.textGrey)),
            const SizedBox(height: 8),
            TextField(
              controller: ctrl,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'e.g. PRV-RNH1ZCTE',
                hintStyle: const TextStyle(fontSize: 13),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10)),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
            const SizedBox(height: 12),
            const Text('Demo providers:',
                style: TextStyle(fontSize: 11, color: AppTheme.textGrey)),
            const SizedBox(height: 4),
            ...[
              ('p1', 'Ali Hassan — AC Repair, G-11'),
              ('p3', 'Bilal Ahmed — Plumber, F-10'),
              ('p5', 'Sana Malik — Tutor, I-8'),
            ].map(
              (e) => InkWell(
                onTap: () => ctrl.text = e.$1,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      const Icon(Icons.person_outline,
                          size: 13, color: AppTheme.primary),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text('${e.$1}  •  ${e.$2}',
                            style: const TextStyle(
                                fontSize: 11, color: AppTheme.primary)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final id = ctrl.text.trim();
              if (id.isEmpty) return;
              ProviderSession.save(id, '');
              Navigator.pop(ctx);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ProviderNotificationScreen(providerId: id),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Login', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Text(
      'Powered by Google Antigravity',
      style: TextStyle(
        fontSize: 11,
        color: Colors.white.withValues(alpha: 0.55),
        letterSpacing: 0.3,
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      elevation: 0,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        splashColor: AppTheme.primaryLight,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
            color: Colors.white,
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppTheme.primaryLight,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: AppTheme.primary, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textDark,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textGrey,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.arrow_forward_ios_rounded,
                  size: 15, color: AppTheme.textGrey),
            ],
          ),
        ),
      ),
    );
  }
}
