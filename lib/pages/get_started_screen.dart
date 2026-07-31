import 'package:flutter/material.dart';
import 'package:apps_k24/pages/login_screen.dart';
import 'package:apps_k24/pages/register_screen.dart';
import 'package:apps_k24/services/api_service.dart';

// Custom painter to draw elegant, thin golden waves in the background
class BackgroundWavePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint1 = Paint()
      ..color = const Color(0xFFFFB300).withValues(alpha: 0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    final paint2 = Paint()
      ..color = const Color(0xFFFFD54F).withValues(alpha: 0.05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

    // Wave 1
    final path1 = Path();
    path1.moveTo(0, size.height * 0.55);
    path1.cubicTo(
      size.width * 0.3, size.height * 0.5,
      size.width * 0.7, size.height * 0.65,
      size.width, size.height * 0.58,
    );
    canvas.drawPath(path1, paint1);

    // Wave 2
    final path2 = Path();
    path2.moveTo(0, size.height * 0.58);
    path2.cubicTo(
      size.width * 0.25, size.height * 0.55,
      size.width * 0.75, size.height * 0.62,
      size.width, size.height * 0.61,
    );
    canvas.drawPath(path2, paint2);

    // Wave 3 (Bottom area curves)
    final path3 = Path();
    path3.moveTo(0, size.height * 0.78);
    path3.cubicTo(
      size.width * 0.35, size.height * 0.72,
      size.width * 0.65, size.height * 0.84,
      size.width, size.height * 0.76,
    );
    canvas.drawPath(path3, paint1);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class GetStartedScreen extends StatefulWidget {
  const GetStartedScreen({super.key, required this.title});
  final String title;

  @override
  State<GetStartedScreen> createState() => _GetStartedScreenState();
}

class _GetStartedScreenState extends State<GetStartedScreen> {
  // Current active language: 'ID' or 'EN'
  String _currentLang = 'ID';

  // Localization map for multi-language functionality
  final Map<String, Map<String, String>> _localizedValues = {
    'ID': {
      'title_1': "Kirim Cepat,",
      'title_2': "Aman &",
      'title_3': "Ningrat.",
      'slogan': "Pengiriman kilat dengan layanan premium dan prioritas untuk pelanggan istimewa.",
      'trusted_by': "Terpercaya oleh",
      'trusted_count': "500+ Apotek",
      'trusted_scope': "di seluruh Indonesia",
      'feat_1_title': "CEPAT",
      'feat_1_desc': "Pengiriman kilat sampai tujuan.",
      'feat_2_title': "AMAN",
      'feat_2_desc': "Paket terjaga keamanannya.",
      'feat_3_title': "NINGRAT",
      'feat_3_desc': "Layanan premium, pelanggan prioritas.",
      'promo_title': "Baru di Kuning?",
      'promo_body': "Daftar segera untuk mendapatkan banyak keuntungan",
      'btn_register': "Daftar Sebagai Driver",
      'btn_login': "Masuk ke Akun",
      'footer': "Aman & Terpercaya",
    },
    'EN': {
      'title_1': "Send Fast,",
      'title_2': "Safe &",
      'title_3': "Royal.",
      'slogan': "Express delivery with premium service and priority for special customers.",
      'trusted_by': "Trusted by",
      'trusted_count': "500+ Pharmacies",
      'trusted_scope': "all over Indonesia",
      'feat_1_title': "FAST",
      'feat_1_desc': "Express delivery to destination.",
      'feat_2_title': "SAFE",
      'feat_2_desc': "Package security guaranteed.",
      'feat_3_title': "ROYAL",
      'feat_3_desc': "Premium service, priority customers.",
      'promo_title': "New to Kuning?",
      'promo_body': "Register now to get many benefits",
      'btn_register': "Register as Driver",
      'btn_login': "Log In to Account",
      'footer': "Safe & Trusted",
    }
  };

  void _showLanguagePicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Pilih Bahasa / Select Language",
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E2022),
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Text("🇮🇩", style: TextStyle(fontSize: 24)),
                title: const Text(
                  "Bahasa Indonesia",
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w600,
                  ),
                ),
                trailing: _currentLang == 'ID'
                    ? const Icon(Icons.check_circle_rounded, color: Color(0xFFFFB300))
                    : null,
                onTap: () {
                  setState(() {
                    _currentLang = 'ID';
                  });
                  Navigator.pop(context);
                },
              ),
              const Divider(),
              ListTile(
                leading: const Text("🇬🇧", style: TextStyle(fontSize: 24)),
                title: const Text(
                  "English",
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w600,
                  ),
                ),
                trailing: _currentLang == 'EN'
                    ? const Icon(Icons.check_circle_rounded, color: Color(0xFFFFB300))
                    : null,
                onTap: () {
                  setState(() {
                    _currentLang = 'EN';
                  });
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFeatureItem({
    required IconData icon,
    required String title,
    required String desc,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: const Color(0xFFFFB300),
            size: 20,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          title,
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          desc,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 8.5,
            color: Colors.grey.shade400,
            height: 1.3,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final strings = _localizedValues[_currentLang]!;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // 1. Top-Right Radial Glow Bubble Background
          Positioned(
            top: -150,
            right: -150,
            width: 480,
            height: 480,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFFFFB300).withValues(alpha: 0.18),
                    const Color(0xFFFFB300).withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),

          // 2. Dot Grid in the top-right
          Positioned(
            top: 76,
            right: 32,
            child: Opacity(
              opacity: 0.25,
              child: Column(
                children: List.generate(
                  5,
                  (index) => Row(
                    children: List.generate(
                      3,
                      (index) => Container(
                        margin: const EdgeInsets.all(3.5),
                        width: 4,
                        height: 4,
                        decoration: const BoxDecoration(
                          color: Color(0xFFFFB300),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // 3. Elegant Thin Waves Background Effect
          Positioned.fill(
            child: CustomPaint(
              painter: BackgroundWavePainter(),
            ),
          ),

          // 4. Main Body Content
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 10), // Spacing below top safe area

                  // 1. Header: Brand Logo & Language Selector
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Logo and Brand Name
                      Row(
                        children: [
                          // Yellow box with package logo icon
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFB300),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            alignment: Alignment.center,
                            child: const Icon(
                              Icons.inventory_2_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                "KUNING",
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 13,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFFFFB300),
                                  height: 1.1,
                                ),
                              ),
                              GestureDetector(
                                onDoubleTap: () => _showDeveloperSettings(context),
                                child: const Text(
                                  "Kurir Ningrat",
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF1E2022),
                                    height: 1.1,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),

                      // Language Selector Pill Button (Interactive)
                      GestureDetector(
                        onTap: () => _showLanguagePicker(context),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.grey.shade300, width: 1.0),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.03),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.language_rounded,
                                size: 14,
                                color: Color(0xFF1E2022),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _currentLang,
                                style: const TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1E2022),
                                ),
                              ),
                              const SizedBox(width: 2),
                              const Icon(
                                Icons.keyboard_arrow_down_rounded,
                                size: 14,
                                color: Color(0xFF1E2022),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Hero Section: Text (Left) + Scooter (Right)
                  SizedBox(
                    height: screenHeight * 0.35,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Left Text Column
                        Expanded(
                          flex: 6,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                strings['title_1']!,
                                style: const TextStyle(
                                  fontSize: 30,
                                  fontWeight: FontWeight.w900,
                                  fontFamily: 'Poppins',
                                  color: Color(0xFF1E2022),
                                  height: 1.1,
                                ),
                              ),
                              Text(
                                strings['title_2']!,
                                style: const TextStyle(
                                  fontSize: 30,
                                  fontWeight: FontWeight.w900,
                                  fontFamily: 'Poppins',
                                  color: Color(0xFF1E2022),
                                  height: 1.1,
                                ),
                              ),
                              Text(
                                strings['title_3']!,
                                style: const TextStyle(
                                  fontSize: 30,
                                  fontWeight: FontWeight.w900,
                                  fontFamily: 'Poppins',
                                  color: Color(0xFFFFB300),
                                  height: 1.1,
                                ),
                              ),
                              const SizedBox(height: 8),
                              // Yellow underline indicator
                              Container(
                                width: 54,
                                height: 4,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFB300),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                strings['slogan']!,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: Colors.grey.shade600,
                                  fontFamily: 'Poppins',
                                  height: 1.45,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 10),
                              // Trust Badge Card
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.04),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                  border: Border.all(color: Colors.grey.shade200, width: 1.0),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: Colors.green.shade50,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.check_circle_rounded,
                                        color: Colors.green,
                                        size: 18,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          strings['trusted_by']!,
                                          style: TextStyle(
                                            fontSize: 9,
                                            color: Colors.grey.shade500,
                                            fontFamily: 'Poppins',
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 1),
                                        Text(
                                          strings['trusted_count']!,
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF1E2022),
                                            fontFamily: 'Poppins',
                                            height: 1.1,
                                          ),
                                        ),
                                        const SizedBox(height: 1),
                                        Text(
                                          strings['trusted_scope']!,
                                          style: TextStyle(
                                            fontSize: 9,
                                            color: Colors.grey.shade500,
                                            fontFamily: 'Poppins',
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Right Scooter Image (with diagonal speed lanes and transparent background)
                        Expanded(
                          flex: 5,
                          child: Stack(
                            alignment: Alignment.centerRight,
                            children: [
                              // 1. Secondary parallel speed line (adds dynamism and depth)
                              Positioned(
                                bottom: 34,
                                right: -30,
                                width: 170,
                                height: 6,
                                child: Transform.rotate(
                                  angle: -0.22,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(3),
                                      gradient: LinearGradient(
                                        colors: [
                                          const Color(0xFFFFB300).withValues(alpha: 0.0),
                                          const Color(0xFFFFB300).withValues(alpha: 0.3),
                                          const Color(0xFFFFB300).withValues(alpha: 0.5),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),

                              // 2. Yellow diagonal road stripe with gradient fading on the left
                              Positioned(
                                bottom: 42,
                                right: -42,
                                width: 220,
                                height: 32,
                                child: Transform.rotate(
                                  angle: -0.22,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(16),
                                      gradient: LinearGradient(
                                        colors: [
                                          const Color(0xFFFFB300).withValues(alpha: 0.0), // Smooth fade out on the left
                                          const Color(0xFFFFB300).withValues(alpha: 0.85),
                                          const Color(0xFFFFB300),
                                          const Color(0xFFFF9100), // Deep orange-yellow on the right
                                        ],
                                        begin: Alignment.centerLeft,
                                        end: Alignment.centerRight,
                                      ),
                                    ),
                                  ),
                                ),
                              ),

                              // 3. Halo glow behind scooter
                              Container(
                                width: 120,
                                height: 120,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFFFFB300).withValues(alpha: 0.18),
                                      blurRadius: 30,
                                      spreadRadius: 5,
                                    ),
                                  ],
                                ),
                              ),

                              // 4. Scooter Image
                              Image.asset(
                                "assets/images/kuning_scooter.png",
                                fit: BoxFit.contain,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Fixed spacing to pull features card closer
                  const SizedBox(height: 16),

                  // 2. Dark Features Card
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E2022),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF1E2022).withValues(alpha: 0.15),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildFeatureItem(
                            icon: Icons.flash_on_rounded,
                            title: strings['feat_1_title']!,
                            desc: strings['feat_1_desc']!,
                          ),
                        ),
                        Container(
                          width: 1,
                          height: 54,
                          color: Colors.white.withValues(alpha: 0.12),
                        ),
                        Expanded(
                          child: _buildFeatureItem(
                            icon: Icons.verified_user_rounded,
                            title: strings['feat_2_title']!,
                            desc: strings['feat_2_desc']!,
                          ),
                        ),
                        Container(
                          width: 1,
                          height: 54,
                          color: Colors.white.withValues(alpha: 0.12),
                        ),
                        Expanded(
                          child: _buildFeatureItem(
                            icon: Icons.star_rounded,
                            title: strings['feat_3_title']!,
                            desc: strings['feat_3_desc']!,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 3. Promo Card (Baru di Kuning? Gift box card)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBEB), // soft yellow-white
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFFFD54F).withValues(alpha: 0.4), width: 1.0),
                    ),
                    child: Row(
                      children: [
                        // 3D Gift Box Image
                        Image.asset(
                          "assets/images/kuning_gift_box.png",
                          width: 44,
                          height: 44,
                          fit: BoxFit.contain,
                        ),
                        const SizedBox(width: 12),
                        // Promo Text
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                strings['promo_title']!,
                                style: const TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFD97706),
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                strings['promo_body']!,
                                style: const TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1E2022),
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Spacer to push the action buttons to the bottom of the screen
                  const Spacer(),

                  // 4. Action Buttons
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFFB300),
                      foregroundColor: const Color(0xFF1E2022),
                      minimumSize: const Size(double.infinity, 56),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const RegisterScreen(),
                        ),
                      );
                    },
                    child: Row(
                      children: [
                        const Icon(Icons.person_outline_rounded, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            strings['btn_register']!,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Poppins',
                            ),
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded, size: 20),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 56),
                      side: const BorderSide(color: Color(0xFF1E2022), width: 1.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                      foregroundColor: const Color(0xFF1E2022),
                      backgroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const LoginScreen(),
                        ),
                      );
                    },
                    child: Row(
                      children: [
                        const Icon(Icons.login_rounded, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            strings['btn_login']!,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Poppins',
                            ),
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded, size: 20),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 5. Footer: Aman & Terpercaya
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.verified_user_rounded,
                        color: Color(0xFFFFB300),
                        size: 14,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        strings['footer']!,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                          fontFamily: 'Poppins',
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // 6. Page Dots Indicator
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 12,
                        height: 4,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFB300),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Container(
                        width: 4,
                        height: 4,
                        decoration: const BoxDecoration(
                          color: Colors.grey,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Container(
                        width: 4,
                        height: 4,
                        decoration: const BoxDecoration(
                          color: Colors.grey,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Container(
                        width: 4,
                        height: 4,
                        decoration: const BoxDecoration(
                          color: Colors.grey,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showDeveloperSettings(BuildContext context) {
    final controller = TextEditingController(text: ApiService.baseUrl);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Row(
            children: [
              Icon(Icons.developer_mode, color: Color(0xFFFFB300)),
              SizedBox(width: 12),
              Text(
                "Developer Settings",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Poppins',
                  fontSize: 18,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                "Pengaturan IP/URL Backend API saat ini:",
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                  fontFamily: 'Poppins',
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  ApiService.baseUrl,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    color: Colors.black87,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                "Ubah URL Backend:",
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Poppins',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: controller,
                style: const TextStyle(fontSize: 14, fontFamily: 'Poppins'),
                decoration: InputDecoration(
                  hintText: "Contoh: 192.168.1.15:8087 atau ngrok url",
                  hintStyle: TextStyle(color: Colors.grey[400], fontSize: 12),
                  filled: true,
                  fillColor: Colors.grey[50],
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFFFB300)),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                "Tips:\n- Hubungkan laptop dan HP ke WiFi yang sama lalu masukkan IP laptop.\n- Gunakan localtunnel/ngrok jika menggunakan Paket Data seluler.",
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey,
                  fontFamily: 'Poppins',
                  height: 1.4,
                ),
              ),
            ],
          ),
          actionsAlignment: MainAxisAlignment.spaceBetween,
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          actions: [
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: Colors.red[700],
              ),
              onPressed: () async {
                await ApiService.setCustomBaseUrl('');
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("IP Backend di-reset ke default otomatis."),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
              child: const Text(
                "Reset",
                style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600),
              ),
            ),
            Row(
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    "Batal",
                    style: TextStyle(color: Colors.grey, fontFamily: 'Poppins'),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFB300),
                    foregroundColor: const Color(0xFF1E2022),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () async {
                    final newUrl = controller.text.trim();
                    await ApiService.setCustomBaseUrl(newUrl);
                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text("Backend URL diubah ke: ${ApiService.baseUrl}"),
                          behavior: SnackBarBehavior.floating,
                          backgroundColor: const Color(0xFFFFB300),
                        ),
                      );
                    }
                  },
                  child: const Text(
                    "Simpan",
                    style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}
