import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/provider_session.dart';
import 'chat_screen.dart';
import 'dispute_screen.dart';
import 'provider_notification_screen.dart';
import 'provider_registration_screen.dart';

// Color tokens from DESIGN.md
const Color kPrimaryNavy = Color(0xFF000666);
const Color kPrimaryContainer = Color(0xFF1A237E);
const Color kOnPrimaryContainer = Color(0xFF8690EE);
const Color kSecondaryGreen = Color(0xFF006C4E);
const Color kSecondaryContainer = Color(0xFF83F5C6);
const Color kTertiaryContainer = Color(0xFF492800);
const Color kOnTertiaryContainer = Color(0xFFDC8200);
const Color kErrorRed = Color(0xFFBA1A1A);
const Color kErrorContainer = Color(0xFFFFDAD6);
const Color kSurfaceContainerLow = Color(0xFFF5F2FB);
const Color kOutlineVariant = Color(0xFFC6C5D4);
const Color kOnSurface = Color(0xFF1B1B21);
const Color kOnSurfaceVariant = Color(0xFF454652);

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with TickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  late AnimationController _controller;
  late AnimationController _orbitController;
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
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    
    _orbitController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15),
    )..repeat();

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    _orbitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      drawer: _buildNavDrawer(context),
      backgroundColor: const Color(0xFFEEF0FB),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFEEF0FB), Color(0xFFF8F9FF)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: FadeTransition(
                  opacity: _fadeAnim,
                  child: SlideTransition(
                    position: _slideAnim,
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 450),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 20),
                                _buildHeroSection(),
                                const SizedBox(height: 20),
                                _buildAgentIllustration(),
                                const SizedBox(height: 24),
                                _buildPrimaryActionCard(context),
                                const SizedBox(height: 16),
                                _buildSecondaryActionCards(context),
                                const SizedBox(height: 24),
                                _buildFooterBadge(),
                                const SizedBox(height: 32),
                              ],
                            ),
                          ),
                        ),
                      ),
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

  Widget _buildHeader() {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: kPrimaryContainer.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: kSecondaryGreen,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.smart_toy_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'KhidmatBot',
                style: GoogleFonts.manrope(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: kPrimaryNavy,
                ),
              ),
            ],
          ),
          IconButton(
            onPressed: () => _scaffoldKey.currentState?.openDrawer(),
            icon: const Icon(Icons.menu_rounded, color: kPrimaryNavy, size: 24),
            splashRadius: 20,
          ),
        ],
      ),
    );
  }

  Widget _buildNavDrawer(BuildContext context) {
    return Drawer(
      backgroundColor: Colors.white,
      child: Column(
        children: [
          DrawerHeader(
            margin: EdgeInsets.zero,
            padding: EdgeInsets.zero,
            child: Container(
              color: kPrimaryNavy,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.smart_toy_rounded,
                        color: kPrimaryNavy,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'KhidmatBot',
                            style: GoogleFonts.manrope(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Smart Concierge',
                            style: GoogleFonts.manrope(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.home_rounded, color: kPrimaryNavy),
            title: Text(
              'Home',
              style: GoogleFonts.manrope(
                fontWeight: FontWeight.w600,
                color: kOnSurface,
              ),
            ),
            onTap: () {
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.chat_rounded, color: kPrimaryNavy),
            title: Text(
              'Chat',
              style: GoogleFonts.manrope(
                fontWeight: FontWeight.w600,
                color: kOnSurface,
              ),
            ),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ChatScreen()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.app_registration_rounded, color: kPrimaryNavy),
            title: Text(
              'Provider Register',
              style: GoogleFonts.manrope(
                fontWeight: FontWeight.w600,
                color: kOnSurface,
              ),
            ),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProviderRegistrationScreen()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.info_rounded, color: kPrimaryNavy),
            title: Text(
              'About',
              style: GoogleFonts.manrope(
                fontWeight: FontWeight.w600,
                color: kOnSurface,
              ),
            ),
            onTap: () {
              Navigator.pop(context);
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  backgroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  title: Row(
                    children: [
                      const Icon(Icons.smart_toy_rounded, color: kPrimaryNavy),
                      const SizedBox(width: 8),
                      Text(
                        'About KhidmatBot',
                        style: GoogleFonts.manrope(
                          fontWeight: FontWeight.w800,
                          color: kPrimaryNavy,
                        ),
                      ),
                    ],
                  ),
                  content: Text(
                    'KhidmatBot is a premium, AI-driven digital assistant designed to seamlessly discover, book, and negotiate with verified informal service providers in Pakistan. Driven by advanced Gemini multi-agent systems and real-time trust parameters, it bridges the gap in the informal economy with exceptional transparency.',
                    style: GoogleFonts.manrope(
                      fontSize: 14,
                      color: kOnSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        'Theek Hai',
                        style: GoogleFonts.manrope(
                          fontWeight: FontWeight.bold,
                          color: kPrimaryNavy,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildHeroSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Smart Services.',
          style: GoogleFonts.manrope(
            fontSize: 32,
            fontWeight: FontWeight.w800,
            color: kPrimaryNavy,
            height: 1.15,
          ),
        ),
        Text(
          'Seamless Connections.',
          style: GoogleFonts.manrope(
            fontSize: 32,
            fontWeight: FontWeight.w800,
            color: kOnPrimaryContainer,
            height: 1.15,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          width: 48,
          height: 4,
          decoration: BoxDecoration(
            color: kPrimaryNavy,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Our dedicated agents work behind the scenes to find, verify and connect you with the best service providers in your area.',
          style: TextStyle(
            fontSize: 15,
            color: kOnSurfaceVariant,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildAgentIllustration() {
    return Center(
      child: SizedBox(
        width: 250,
        height: 250,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Revolving dashed orbit ring
            AnimatedBuilder(
              animation: _orbitController,
              builder: (context, child) {
                return Transform.rotate(
                  angle: _orbitController.value * 2 * math.pi,
                  child: child,
                );
              },
              child: SizedBox(
                width: 192,
                height: 192,
                child: CustomPaint(
                  painter: DashedCirclePainter(
                    color: kOutlineVariant.withValues(alpha: 0.8),
                    strokeWidth: 2,
                    dashLength: 8,
                    gapLength: 6,
                  ),
                ),
              ),
            ),
            // Center Agent Icon on Navy Background (No URL used as requested)
            Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                color: kPrimaryContainer,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 4),
                boxShadow: [
                  BoxShadow(
                    color: kPrimaryContainer.withValues(alpha: 0.2),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: const Center(
                child: Icon(
                  Icons.support_agent_rounded,
                  color: Colors.white,
                  size: 56,
                ),
              ),
            ),
            // 4 Orbiting Nodes dynamically placed using AnimatedBuilder
            AnimatedBuilder(
              animation: _orbitController,
              builder: (context, child) {
                return Stack(
                  children: [
                    _buildOrbitingNode(
                      icon: Icons.bolt_rounded,
                      iconColor: kSecondaryGreen,
                      angleOffset: 0,
                    ),
                    _buildOrbitingNode(
                      icon: Icons.plumbing_rounded,
                      iconColor: kOnTertiaryContainer,
                      angleOffset: math.pi / 2,
                    ),
                    _buildOrbitingNode(
                      icon: Icons.ac_unit_rounded,
                      iconColor: kPrimaryNavy,
                      angleOffset: math.pi,
                    ),
                    _buildOrbitingNode(
                      icon: Icons.school_rounded,
                      iconColor: kOnTertiaryContainer,
                      angleOffset: 3 * math.pi / 2,
                    ),
                  ],
                );
              },
            ),
            // Location Indicator
            Positioned(
              bottom: 0,
              right: 60,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.location_on_rounded,
                    color: kPrimaryNavy,
                    size: 40,
                  ),
                  Container(
                    width: 14,
                    height: 3,
                    decoration: BoxDecoration(
                      color: kPrimaryNavy.withValues(alpha: 0.2),
                      borderRadius: const BorderRadius.all(Radius.elliptical(7, 1.5)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrbitingNode({
    required IconData icon,
    required Color iconColor,
    required double angleOffset,
  }) {
    const double radius = 96.0;
    const double nodeRadius = 21.0;
    const double centerX = 125.0;
    const double centerY = 125.0;

    // Current rotation angle of the orbit
    double angle = _orbitController.value * 2 * math.pi + angleOffset;

    // Trig coordinates
    double x = centerX + radius * math.cos(angle) - nodeRadius;
    double y = centerY + radius * math.sin(angle) - nodeRadius;

    return Positioned(
      left: x,
      top: y,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: kOutlineVariant.withValues(alpha: 0.5), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(
          icon,
          color: iconColor,
          size: 20,
        ),
      ),
    );
  }

  Widget _buildPrimaryActionCard(BuildContext context) {
    return Material(
      color: kPrimaryContainer,
      borderRadius: BorderRadius.circular(32),
      elevation: 4,
      shadowColor: kPrimaryContainer.withValues(alpha: 0.3),
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ChatScreen()),
        ),
        borderRadius: BorderRadius.circular(32),
        splashColor: Colors.white.withValues(alpha: 0.1),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.smart_toy_rounded,
                  color: Colors.white,
                  size: 30,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'KhidmatBot Kholein',
                      style: GoogleFonts.manrope(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Chat with our smart assistant',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withValues(alpha: 0.75),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.arrow_forward_rounded,
                  color: kPrimaryContainer,
                  size: 20,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSecondaryActionCards(BuildContext context) {
    return Column(
      children: [
        // Provider Registration Card
        _buildSecondaryCard(
          icon: Icons.person_add_rounded,
          iconColor: kSecondaryGreen,
          iconBgColor: kSecondaryContainer.withValues(alpha: 0.3),
          circleBgColor: kSecondaryGreen,
          title: 'Provider Registration',
          subtitle: 'Join our network of professionals',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ProviderRegistrationScreen()),
          ),
        ),
        const SizedBox(height: 12),
        // Provider Notifications Card with Badge
        _buildSecondaryCard(
          icon: Icons.notifications_rounded,
          iconColor: kOnTertiaryContainer,
          iconBgColor: const Color(0xFFFFDCBE).withValues(alpha: 0.3),
          circleBgColor: kTertiaryContainer,
          title: 'Provider Notifications',
          subtitle: 'Stay updated with important alerts',
          badgeCount: 1,
          onTap: () => _openProviderScreen(context),
        ),
        const SizedBox(height: 12),
        // Dispute Card
        _buildSecondaryCard(
          icon: Icons.gavel_rounded,
          iconColor: kErrorRed,
          iconBgColor: kErrorContainer.withValues(alpha: 0.3),
          circleBgColor: kErrorRed,
          title: 'Shikayat Darj Karein',
          subtitle: 'Report any service issues',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const DisputeScreen()),
          ),
        ),
      ],
    );
  }

  Widget _buildSecondaryCard({
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
    required Color circleBgColor,
    required String title,
    required String subtitle,
    int? badgeCount,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        splashColor: kOutlineVariant.withValues(alpha: 0.2),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: kSurfaceContainerLow, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: kPrimaryContainer.withValues(alpha: 0.02),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: iconBgColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      icon,
                      color: iconColor,
                      size: 24,
                    ),
                  ),
                  if (badgeCount != null && badgeCount > 0)
                    Positioned(
                      top: -4,
                      right: -4,
                      child: Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: kErrorRed,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: Center(
                          child: Text(
                            '$badgeCount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.manrope(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: kOnSurface,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: kOnSurfaceVariant,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: circleBgColor,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFooterBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: kSurfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kOutlineVariant.withValues(alpha: 0.1), width: 1),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.verified_user_rounded,
                color: kSecondaryGreen,
                size: 14,
              ),
              const SizedBox(width: 6),
              Text(
                'Trusted Services. Verified Providers.',
                style: GoogleFonts.manrope(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: kSecondaryGreen,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.group_rounded,
                color: kPrimaryNavy,
                size: 14,
              ),
              const SizedBox(width: 6),
              Text(
                'Agents 24/7',
                style: GoogleFonts.manrope(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: kPrimaryNavy,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _openProviderScreen(BuildContext context) async {
    final savedId = await ProviderSession.load();
    if (!context.mounted) return;

    if (savedId != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ProviderNotificationScreen(providerId: savedId),
        ),
      );
      return;
    }

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
            Icon(Icons.notifications_active, color: kPrimaryNavy, size: 20),
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
                color: kSurfaceContainerLow,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Agar aapne register kiya tha to Provider ID registration ke baad milti hai. Notification aane par automatically khul jata hai.',
                style: TextStyle(fontSize: 11, color: kOnSurfaceVariant),
              ),
            ),
            const SizedBox(height: 14),
            const Text('Provider ID daalein:',
                style: TextStyle(fontSize: 13, color: kOnSurfaceVariant)),
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
                style: TextStyle(fontSize: 11, color: kOnSurfaceVariant)),
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
                          size: 13, color: kPrimaryNavy),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text('${e.$1}  •  ${e.$2}',
                            style: const TextStyle(
                                fontSize: 11, color: kPrimaryNavy)),
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
              backgroundColor: kPrimaryNavy,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Login', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

class DashedCirclePainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double dashLength;
  final double gapLength;

  DashedCirclePainter({
    required this.color,
    this.strokeWidth = 2.0,
    this.dashLength = 6.0,
    this.gapLength = 6.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    double circumference = 2 * math.pi * radius;
    int dashCount = (circumference / (dashLength + gapLength)).floor();

    for (int i = 0; i < dashCount; i++) {
      double startAngle = (i * (dashLength + gapLength) / circumference) * 2 * math.pi;
      double sweepAngle = (dashLength / circumference) * 2 * math.pi;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant DashedCirclePainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.dashLength != dashLength ||
        oldDelegate.gapLength != gapLength;
  }
}
