import 'package:flutter/material.dart';
import 'package:apps_k24/theme/app_colors.dart';
import 'package:apps_k24/theme/gaps.dart';
import 'package:apps_k24/pages/register_screen.dart';
import 'package:apps_k24/pages/logged_screen.dart';
import 'package:apps_k24/pages/admin_dashboard_screen.dart';
import 'package:apps_k24/services/api_service.dart';
import 'package:apps_k24/components/profile_security_sheets.dart';
import 'package:apps_k24/components/toast_helper.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;

  // Premium design color variables (White & Yellow theme)
  static const Color primaryYellow = Color(0xFFFFB300); // Warm Gold/Amber
  static const Color accentYellow = Color(0xFFFFD54F);  // Soft Yellow
  static const Color darkSlate = Color(0xFF1E2022);     // Deep text color
  static const Color inputBg = Color(0xFFF9FAFB);       // Crisp grey-white input fill

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  Future<void> _handleRoleRedirection(String? role) async {
    if (role == null) {
      await ApiService.clearAuthData();
      _showError("Gagal mengambil data peran (role).");
      return;
    }
    if (role == 'ADMIN') {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const AdminDashboardScreen()),
      );
    } else if (role == 'DRIVER') {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoggedScreen()),
      );
    } else {
      await ApiService.clearAuthData();
      _showError("Akun Anda terdaftar sebagai $role. Aplikasi ini khusus untuk Driver.");
    }
  }

  Future<void> _handleEmailLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await ApiService.login(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (mounted) {
        final role = await ApiService.getRole();
        await _handleRoleRedirection(role);
      }
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleGoogleLogin() async {
    setState(() => _isLoading = true);

    try {
      await ApiService.loginWithGoogle(
        email: 'driver.google@k24.com',
        name: 'Mitra Google Driver',
      );

      if (mounted) {
        final role = await ApiService.getRole();
        await _handleRoleRedirection(role);
      }
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleFaceLogin() async {
    final userController = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text(
          "Verifikasi Wajah",
          style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Poppins', color: darkSlate),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Masukkan email atau username Anda untuk memuat data wajah:",
              style: TextStyle(fontSize: 12, color: Colors.grey, fontFamily: 'Poppins'),
            ),
            gapH16,
            TextField(
              controller: userController,
              decoration: InputDecoration(
                hintText: "Email atau Username",
                hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13, fontFamily: 'Poppins'),
                filled: true,
                fillColor: inputBg,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: Colors.grey.shade200, width: 1.5),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: primaryYellow, width: 2.0),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Batal", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryYellow,
              foregroundColor: darkSlate,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            onPressed: () {
              if (userController.text.trim().isEmpty) return;
              Navigator.pop(context, true);
            },
            child: const Text("Lanjut Pindai", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      final username = userController.text.trim();
      final loginSuccess = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (context) => MockFaceCameraScreen(
            isRegisterMode: false,
            usernameForLogin: username,
          ),
        ),
      );

      if (loginSuccess == true && mounted) {
        final role = await ApiService.getRole();
        if (!mounted) return;
        
        ToastHelper.show(context, message: "Verifikasi wajah sukses! Selamat datang.");
        await _handleRoleRedirection(role);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final double headerHeight = MediaQuery.of(context).size.height * 0.28;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Yellow-Gold Gradient Decorative Header Background
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: headerHeight,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [accentYellow, primaryYellow],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(40),
                  bottomRight: Radius.circular(40),
                ),
              ),
              child: Stack(
                children: [
                  // Abstract decorative vector circles in the background
                  Positioned(
                    top: -50,
                    left: -50,
                    child: CircleAvatar(
                      radius: 100,
                      backgroundColor: Colors.white.withOpacity(0.1),
                    ),
                  ),
                  Positioned(
                    bottom: -30,
                    right: -20,
                    child: CircleAvatar(
                      radius: 70,
                      backgroundColor: Colors.white.withOpacity(0.1),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Main Scrollable Content
          SafeArea(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                // Top Custom Header App Bar area (back button)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.9),
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: darkSlate, size: 20),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Form & Login details
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(height: headerHeight * 0.15),
                          
                          // Decorative delivery icon in circle
                          Center(
                            child: Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.08),
                                    blurRadius: 16,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.two_wheeler_rounded,
                                size: 48,
                                color: primaryYellow,
                              ),
                            ),
                          ),
                          gapH24,

                          // Card container wrapping input elements for premium look
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(30),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.04),
                                  blurRadius: 20,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const Text(
                                  "Masuk Driver",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'Poppins',
                                    color: darkSlate,
                                  ),
                                ),
                                gapH8,
                                const Text(
                                  "Silakan masuk untuk mulai menerima pesanan obat Apotek K-24",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: Colors.grey,
                                    fontFamily: 'Poppins',
                                    height: 1.35,
                                  ),
                                ),
                                gapH24,

                                // Email Input
                                const Text(
                                  "Email",
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'Poppins',
                                    color: darkSlate,
                                  ),
                                ),
                                gapH8,
                                TextFormField(
                                  controller: _emailController,
                                  keyboardType: TextInputType.emailAddress,
                                  decoration: InputDecoration(
                                    hintText: "Masukkan alamat email Anda",
                                    hintStyle: const TextStyle(fontSize: 13, color: Colors.grey),
                                    filled: true,
                                    fillColor: inputBg,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: BorderSide(color: Colors.grey.shade100, width: 1.5),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: const BorderSide(color: primaryYellow, width: 2.0),
                                    ),
                                    errorBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
                                    ),
                                    focusedErrorBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: const BorderSide(color: Colors.redAccent, width: 2.0),
                                    ),
                                    prefixIcon: const Icon(Icons.email_outlined, color: Colors.grey, size: 20),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return 'Email wajib diisi';
                                    }
                                    final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
                                    if (!emailRegex.hasMatch(value)) {
                                      return 'Format email tidak valid';
                                    }
                                    return null;
                                  },
                                ),
                                gapH16,

                                // Password Input
                                const Text(
                                  "Kata Sandi",
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'Poppins',
                                    color: darkSlate,
                                  ),
                                ),
                                gapH8,
                                TextFormField(
                                  controller: _passwordController,
                                  obscureText: _obscurePassword,
                                  decoration: InputDecoration(
                                    hintText: "Masukkan kata sandi Anda",
                                    hintStyle: const TextStyle(fontSize: 13, color: Colors.grey),
                                    filled: true,
                                    fillColor: inputBg,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: BorderSide(color: Colors.grey.shade100, width: 1.5),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: const BorderSide(color: primaryYellow, width: 2.0),
                                    ),
                                    errorBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
                                    ),
                                    focusedErrorBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: const BorderSide(color: Colors.redAccent, width: 2.0),
                                    ),
                                    prefixIcon: const Icon(Icons.lock_outline_rounded, color: Colors.grey, size: 20),
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                        color: Colors.grey,
                                        size: 20,
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          _obscurePassword = !_obscurePassword;
                                        });
                                      },
                                    ),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Kata sandi wajib diisi';
                                    }
                                    if (value.length < 6) {
                                      return 'Kata sandi minimal 6 karakter';
                                    }
                                    return null;
                                  },
                                ),
                                gapH8,

                                // Forgot Password Link
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton(
                                    onPressed: () {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Fitur Lupa Kata Sandi belum tersedia.')),
                                      );
                                    },
                                    child: const Text(
                                      "Lupa Kata Sandi?",
                                      style: TextStyle(
                                        color: primaryYellow,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12.5,
                                        fontFamily: 'Poppins',
                                      ),
                                    ),
                                  ),
                                ),
                                gapH12,

                                // Main Login Button (Yellow-Gold Premium)
                                Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(30),
                                    gradient: const LinearGradient(
                                      colors: [accentYellow, primaryYellow],
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: primaryYellow.withOpacity(0.3),
                                        blurRadius: 12,
                                        offset: const Offset(0, 6),
                                      ),
                                    ],
                                  ),
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.transparent,
                                      foregroundColor: darkSlate,
                                      shadowColor: Colors.transparent,
                                      minimumSize: const Size(double.infinity, 54),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(30),
                                      ),
                                      elevation: 0,
                                    ),
                                    onPressed: _isLoading ? null : _handleEmailLogin,
                                    child: _isLoading
                                        ? const SizedBox(
                                            width: 24,
                                            height: 24,
                                            child: CircularProgressIndicator(
                                              color: darkSlate,
                                              strokeWidth: 2.5,
                                            ),
                                          )
                                        : const Text(
                                            "Masuk",
                                            style: TextStyle(
                                              fontSize: 15.5,
                                              fontWeight: FontWeight.bold,
                                              fontFamily: 'Poppins',
                                            ),
                                          ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          gapH24,

                          // Divider "atau masuk dengan"
                          Row(
                            children: [
                              Expanded(child: Divider(color: Colors.grey.shade300, thickness: 0.8)),
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 16),
                                child: Text(
                                  "atau masuk dengan",
                                  style: TextStyle(color: Colors.grey, fontSize: 11.5, fontFamily: 'Poppins'),
                                ),
                              ),
                              Expanded(child: Divider(color: Colors.grey.shade300, thickness: 0.8)),
                            ],
                          ),
                          gapH20,

                          // Third-party buttons
                          // Google Login Button (Clean layout)
                          OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(double.infinity, 54),
                              side: BorderSide(color: Colors.grey.shade300, width: 1.2),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                              backgroundColor: Colors.white,
                              foregroundColor: darkSlate,
                              elevation: 0,
                            ),
                            onPressed: _isLoading ? null : _handleGoogleLogin,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Image.asset(
                                  "assets/images/google_logo.png",
                                  width: 22,
                                  height: 22,
                                  fit: BoxFit.contain,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF4285F4).withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Text(
                                        "G",
                                        style: TextStyle(
                                          color: Color(0xFF4285F4),
                                          fontWeight: FontWeight.w900,
                                          fontSize: 16,
                                          fontFamily: 'Poppins',
                                        ),
                                      ),
                                    );
                                  },
                                ),
                                gapW12,
                                const Text(
                                  "Masuk dengan Google",
                                  style: TextStyle(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'Poppins',
                                  ),
                                ),
                              ],
                            ),
                          ),
                          gapH12,
                          
                          // Face Login Button (Modern outline)
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(double.infinity, 54),
                              side: const BorderSide(color: primaryYellow, width: 1.5),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                              backgroundColor: Colors.white,
                              foregroundColor: primaryYellow,
                              elevation: 0,
                            ),
                            onPressed: _isLoading ? null : _handleFaceLogin,
                            icon: const Icon(Icons.face_retouching_natural_rounded, color: primaryYellow),
                            label: const Text(
                              "Masuk dengan Verifikasi Wajah",
                              style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Poppins',
                                color: darkSlate,
                              ),
                            ),
                          ),
                          gapH32,

                          // Footer to Register Screen
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text(
                                "Belum punya akun? ",
                                style: TextStyle(color: Colors.grey, fontSize: 13, fontFamily: 'Poppins'),
                              ),
                              GestureDetector(
                                onTap: () {
                                  Navigator.pushReplacement(
                                    context,
                                    MaterialPageRoute(builder: (context) => const RegisterScreen()),
                                  );
                                },
                                child: const Text(
                                  "Daftar Sekarang",
                                  style: TextStyle(
                                    color: primaryYellow,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    fontFamily: 'Poppins',
                                  ),
                                ),
                              ),
                            ],
                          ),
                          gapH40,
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
