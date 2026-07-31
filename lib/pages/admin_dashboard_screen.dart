import 'dart:async';
import 'package:flutter/material.dart';
import 'package:apps_k24/theme/app_colors.dart';
import 'package:apps_k24/theme/gaps.dart';
import 'package:apps_k24/services/api_service.dart';
import 'package:apps_k24/models/dashboard_data.dart';
import 'package:apps_k24/pages/get_started_screen.dart';
import 'package:apps_k24/components/toast_helper.dart';
import 'package:apps_k24/pages/profile_pages.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> with TickerProviderStateMixin {
  int _currentTab = 0;
  
  // Data State
  AdminStatsModel? _stats;
  List<DriverModel> _drivers = [];
  List<MitraModel> _mitra = [];
  
  // Filtered Lists for Search
  List<DriverModel> _filteredDrivers = [];
  List<MitraModel> _filteredMitra = [];
  
  // Loading & Error States
  bool _isLoadingStats = true;
  bool _isLoadingDrivers = true;
  bool _isLoadingMitra = true;
  String? _errorStats;
  String? _errorDrivers;
  String? _errorMitra;

  // Search Controllers
  final TextEditingController _driverSearchController = TextEditingController();
  final TextEditingController _mitraSearchController = TextEditingController();

  // Create Mitra Form State
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isCreatingMitra = false;
  bool _showPassword = false;

  // Sliding Banner State
  final PageController _pageController = PageController(initialPage: 0);
  int _currentPage = 0;
  Timer? _slideTimer;
  int _userAvatarIndex = 0;
  String? _customProfilePicPath;

  Future<void> _loadAvatarIndex() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _userAvatarIndex = prefs.getInt('user_avatar_index') ?? 0;
        _customProfilePicPath = prefs.getString('user_profile_pic_path');
      });
    }
  }

  // Visual Theme Colors matching official K-24 branding
  static const Color themeBg = Color(0xFFF5F6F9); // Professional light gray background
  static const Color themeAccentGreen = Color(0xFF00A859); // K-24 Green
  static const Color themeAccentBlue = Color(0xFF0054A6); // K-24 Blue
  static const Color themeTextDark = Color(0xFF2C3E50); // Dark Slate Charcoal for typography
  static const Color themeTextMuted = Color(0xFF7F8C8D); // Slate Grey
  static const Color themeCardShadow = Color(0x0A000000); // Extremely subtle card shadow

  // Banner slide content
  final List<Map<String, String>> _bannerData = [
    {
      'image': 'assets/images/asset-login-hero-banner-k24.png',
      'title': 'Kelola Layanan Driver',
      'desc': 'Selamat bekerja, kelola driver dan apotek mitra K-24 dengan cepat.'
    },
    {
      'image': 'assets/images/banner2.png',
      'title': 'Kirim Obat Cepat & Aman',
      'desc': 'Bantu jutaan pasien mendapatkan pelayanan kesehatan terbaik.'
    },
    {
      'image': 'assets/images/banner3.png',
      'title': 'Mitra Apotek Terintegrasi',
      'desc': 'Pantau status kesiapan stok obat dan operasional apotek mitra.'
    },
    {
      'image': 'assets/images/banner4.png',
      'title': 'Pelacakan Kurir Real-Time',
      'desc': 'Lacak posisi driver pengirim obat secara real-time dan akurat.'
    },
  ];

  @override
  void initState() {
    super.initState();
    _fetchStats();
    _fetchDrivers();
    _fetchMitra();
    _loadAvatarIndex();

    _driverSearchController.addListener(_filterDrivers);
    _mitraSearchController.addListener(_filterMitra);

    // Initialize Auto-sliding banner timer
    _slideTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (_currentPage < 3) {
        _currentPage++;
      } else {
        _currentPage = 0;
      }
      if (_pageController.hasClients) {
        _pageController.animateToPage(
          _currentPage,
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeInOutCubic,
        );
      }
    });
  }

  @override
  void dispose() {
    _slideTimer?.cancel();
    _pageController.dispose();
    _driverSearchController.dispose();
    _mitraSearchController.dispose();
    _nameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------
  // API Fetch Operations
  // ---------------------------------------------------------

  Future<void> _fetchStats() async {
    setState(() {
      _isLoadingStats = true;
      _errorStats = null;
    });
    try {
      final stats = await ApiService.getAdminStats();
      setState(() {
        _stats = stats;
        _isLoadingStats = false;
      });
    } catch (e) {
      setState(() {
        _errorStats = e.toString();
        _isLoadingStats = false;
      });
    }
  }

  Future<void> _fetchDrivers() async {
    setState(() {
      _isLoadingDrivers = true;
      _errorDrivers = null;
    });
    try {
      final list = await ApiService.getDrivers();
      setState(() {
        _drivers = list;
        _filteredDrivers = list;
        _isLoadingDrivers = false;
      });
    } catch (e) {
      setState(() {
        _errorDrivers = e.toString();
        _isLoadingDrivers = false;
      });
    }
  }

  Future<void> _fetchMitra() async {
    setState(() {
      _isLoadingMitra = true;
      _errorMitra = null;
    });
    try {
      final list = await ApiService.getMitra();
      setState(() {
        _mitra = list;
        _filteredMitra = list;
        _isLoadingMitra = false;
      });
    } catch (e) {
      setState(() {
        _errorMitra = e.toString();
        _isLoadingMitra = false;
      });
    }
  }

  // ---------------------------------------------------------
  // Search Filter Functions
  // ---------------------------------------------------------

  void _filterDrivers() {
    final query = _driverSearchController.text.toLowerCase();
    setState(() {
      _filteredDrivers = _drivers.where((driver) {
        return driver.name.toLowerCase().contains(query) ||
               driver.plateNumber.toLowerCase().contains(query) ||
               driver.phone.contains(query);
      }).toList();
    });
  }

  void _filterMitra() {
    final query = _mitraSearchController.text.toLowerCase();
    setState(() {
      _filteredMitra = _mitra.where((m) {
        return m.name.toLowerCase().contains(query) ||
               m.username.toLowerCase().contains(query) ||
               m.email.toLowerCase().contains(query);
      }).toList();
    });
  }

  // ---------------------------------------------------------
  // Form Submission
  // ---------------------------------------------------------

  Future<void> _handleCreateMitra() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isCreatingMitra = true);

    try {
      await ApiService.createMitra(
        username: _usernameController.text.trim(),
        email: _emailController.text.trim(),
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        password: _passwordController.text,
      );

      if (!mounted) return;

      // Show beautiful success dialog with scaling check icon
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            backgroundColor: Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(28.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: themeAccentGreen.withOpacity(0.08),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_circle_outline_rounded,
                      color: themeAccentGreen,
                      size: 64,
                    ),
                  ),
                  gapH20,
                  const Text(
                    "Mitra Sukses Terdaftar!",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: themeTextDark,
                    ),
                  ),
                  gapH12,
                  Text(
                    "Akun mitra ${_nameController.text} kini telah aktif di sistem.",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: themeTextMuted, fontSize: 13),
                  ),
                  gapH24,
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: themeAccentGreen,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 50),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                    ),
                    onPressed: () {
                      Navigator.pop(context); // Close dialog
                      _clearMitraForm();
                      _fetchStats(); // Refresh stats
                      _fetchMitra(); // Refresh list
                      setState(() => _currentTab = 1); // Switch to Mitra List Tab
                    },
                    child: const Text(
                      "Lihat Mitra",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    } catch (e) {
      _showToast(e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _isCreatingMitra = false);
    }
  }

  void _clearMitraForm() {
    _nameController.clear();
    _usernameController.clear();
    _emailController.clear();
    _phoneController.clear();
    _passwordController.clear();
  }

  void _showToast(String message, {bool isError = false}) {
    ToastHelper.show(context, message: message, isError: isError);
  }

  // Logout Flow
  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        title: const Text("Keluar Sesi", style: TextStyle(fontWeight: FontWeight.bold, color: themeTextDark)),
        content: const Text("Kembali ke layar awal dan akhiri sesi admin Anda?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false), 
            child: const Text("Batal", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accentRed, 
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Keluar"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ApiService.clearAuthData();
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const GetStartedScreen(title: "Get Started")),
          (route) => false,
        );
      }
    }
  }

  // ---------------------------------------------------------
  // UI Building Blocks
  // ---------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: themeBg,
      body: SafeArea(
        bottom: false, // Custom nav goes to the bottom
        child: Stack(
          children: [
            // Top App Bar Area
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 70,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(30),
                    bottomRight: Radius.circular(30),
                  ),
                  boxShadow: [
                    BoxShadow(color: themeCardShadow, blurRadius: 10, offset: Offset(0, 4)),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: themeAccentGreen.withOpacity(0.08),
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: const Icon(Icons.admin_panel_settings_rounded, color: themeAccentGreen, size: 22),
                        ),
                        const SizedBox(width: 12),
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              "SISTEM ADMIN",
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: themeTextMuted,
                                letterSpacing: 1.0,
                              ),
                            ),
                            Text(
                              "Apotek K-24",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: themeTextDark,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    // Status dot
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: themeAccentGreen.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: themeAccentGreen.withOpacity(0.3), width: 1),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.wifi_tethering_rounded, color: themeAccentGreen, size: 12),
                          SizedBox(width: 4),
                          Text(
                            "ONLINE",
                            style: TextStyle(color: themeAccentGreen, fontSize: 9, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Content Area - Scrollable with padding for Top Bar and Floating Bottom Bar
            Positioned.fill(
              top: 70,
              bottom: 95, // Leave enough space for floating navigation bar
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                transitionBuilder: (Widget child, Animation<double> animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0.04, 0.0),
                        end: Offset.zero,
                      ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
                      child: child,
                    ),
                  );
                },
                child: _buildSelectedTabContent(),
              ),
            ),

            // Floating Navigation Bar (Matches user's screenshot layout)
            Positioned(
              bottom: 16,
              left: 20,
              right: 20,
              height: 72,
              child: _buildFloatingBottomNav(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedTabContent() {
    switch (_currentTab) {
      case 0:
        return _buildStatsTab();
      case 1:
        return _buildMitraTab();
      case 2:
        return _buildDriverTab();
      case 3:
        return _buildProfilTab();
      case 4:
        return _buildCreateMitraTab();
      default:
        return _buildStatsTab();
    }
  }

  // Custom premium floating bottom nav matching the mockup with green accent
  Widget _buildFloatingBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(36),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Home / Stats
          _buildNavButton(
            index: 0,
            icon: Icons.grid_view_rounded,
            label: "Dashboard",
          ),
          // Mitra
          _buildNavButton(
            index: 1,
            icon: Icons.store_rounded,
            label: "Mitra",
          ),
          
          // Center Floating '+' button for Registering Mitra
          GestureDetector(
            onTap: () {
              setState(() => _currentTab = 4);
            },
            child: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: themeAccentGreen,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: themeAccentGreen.withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
            ),
          ),

          // Drivers
          _buildNavButton(
            index: 2,
            icon: Icons.two_wheeler_rounded,
            label: "Driver",
          ),
          // Profil Tab (Replacing segarkan)
          _buildNavButton(
            index: 3,
            icon: Icons.person_outline_rounded,
            label: "Profil",
          ),
        ],
      ),
    );
  }

  Widget _buildNavButton({
    required int index,
    required IconData icon,
    required String label,
  }) {
    final isSelected = _currentTab == index;
    return InkWell(
      onTap: () {
        setState(() => _currentTab = index);
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? themeAccentGreen : themeTextMuted.withOpacity(0.6),
              size: 24,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 9,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? themeAccentGreen : themeTextMuted.withOpacity(0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------
  // 1. STATS TAB (Dashboard Home)
  // ---------------------------------------------------------

  Widget _buildStatsTab() {
    if (_isLoadingStats) {
      return const Center(child: CircularProgressIndicator(color: themeAccentGreen));
    }

    if (_errorStats != null) {
      return _buildErrorState(_errorStats!, _fetchStats);
    }

    final stats = _stats;
    if (stats == null) {
      return const Center(child: Text("Data statistik tidak ditemukan"));
    }

    return RefreshIndicator(
      onRefresh: () async {
        await _fetchStats();
      },
      color: themeAccentGreen,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
        child: Column(
          key: const ValueKey("stats_tab_content"),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Auto-sliding Hero banner with dot indicators
            SizedBox(
              height: 180,
              child: Stack(
                children: [
                  PageView.builder(
                    controller: _pageController,
                    itemCount: _bannerData.length,
                    onPageChanged: (index) {
                      setState(() {
                        _currentPage = index;
                      });
                    },
                    itemBuilder: (context, index) {
                      final item = _bannerData[index];
                      return Container(
                        margin: const EdgeInsets.only(right: 2.0),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          image: DecorationImage(
                            image: AssetImage(item['image']!),
                            fit: BoxFit.cover,
                          ),
                        ),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(24),
                            gradient: LinearGradient(
                              colors: [
                                themeAccentBlue.withOpacity(0.9),
                                Colors.transparent,
                              ],
                              begin: Alignment.bottomLeft,
                              end: Alignment.topRight,
                            ),
                          ),
                          padding: const EdgeInsets.all(22.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: themeAccentGreen,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Text(
                                  "INFO SISTEM",
                                  style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                                ),
                              ),
                              gapH8,
                              Text(
                                item['title']!,
                                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              gapH4,
                              Text(
                                item['desc']!,
                                style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 10.5),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  
                  // Dot Indicators
                  Positioned(
                    bottom: 14,
                    right: 20,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(_bannerData.length, (index) {
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          margin: const EdgeInsets.symmetric(horizontal: 3.0),
                          height: 6,
                          width: _currentPage == index ? 16 : 6,
                          decoration: BoxDecoration(
                            color: _currentPage == index ? themeAccentGreen : Colors.white.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        );
                      }),
                    ),
                  ),
                ],
              ),
            ),
            
            gapH24,
            
            // Section Title
            const Text(
              "Ringkasan Sistem",
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: themeTextDark, letterSpacing: 0.5),
            ),
            const SizedBox(height: 14),

            // Professional Stats Panel (Enterprise unified metrics box)
            _buildProfessionalStatsPanel(stats),
            
            gapH20,

            // Security Policy Card
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: const [
                  BoxShadow(color: themeCardShadow, blurRadius: 16, offset: Offset(0, 4)),
                ],
                border: Border.all(color: const Color(0xFFEDF2F7), width: 1),
              ),
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: themeAccentBlue.withOpacity(0.08),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.health_and_safety_rounded, color: themeAccentBlue, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Patuhi Protokol & Regulasi",
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: themeTextDark),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "Pastikan seluruh mitra apotek melampirkan izin apoteker yang valid.",
                          style: TextStyle(color: themeTextMuted, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            gapH16,
          ],
        ),
      ),
    );
  }

  // Enterprise Metrics Panel
  Widget _buildProfessionalStatsPanel(AdminStatsModel stats) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(color: themeCardShadow, blurRadius: 16, offset: Offset(0, 4)),
        ],
        border: Border.all(color: const Color(0xFFEDF2F7), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Panel Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "IKHTISAR OPERASIONAL",
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: themeTextMuted,
                    letterSpacing: 0.8,
                  ),
                ),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: themeAccentGreen,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      "Sistem Stabil",
                      style: TextStyle(fontSize: 10.5, color: themeTextMuted, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFEDF2F7)),
          
          // 3-Column Metrics Rows
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
            child: Row(
              children: [
                // Column 1: Mitra
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _currentTab = 1),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: const BoxDecoration(
                            color: Color(0xFFFFF9E6), // Soft Yellow
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.store_rounded, color: Color(0xFFD6A000), size: 20),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "${stats.totalMitra}",
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: themeTextDark),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          "Mitra Apotek",
                          style: TextStyle(fontSize: 11, color: themeTextMuted, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),
                
                // Divider 1
                Container(height: 48, width: 1, color: const Color(0xFFEDF2F7)),

                // Column 2: Drivers
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _currentTab = 2),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: const BoxDecoration(
                            color: Color(0xFFE6F0FA), // Soft Blue
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.two_wheeler_rounded, color: themeAccentBlue, size: 20),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "${stats.totalDrivers}",
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: themeTextDark),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          "Driver Online",
                          style: TextStyle(fontSize: 11, color: themeTextMuted, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),
                
                // Divider 2
                Container(height: 48, width: 1, color: const Color(0xFFEDF2F7)),

                // Column 3: Orders
                Expanded(
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: const BoxDecoration(
                          color: Color(0xFFFEECEE), // Soft Red
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.receipt_long_rounded, color: AppColors.accentRed, size: 20),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "${stats.totalOrders}",
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: themeTextDark),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        "Total Pesanan",
                        style: TextStyle(fontSize: 11, color: themeTextMuted, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          const Divider(height: 1, color: Color(0xFFEDF2F7)),
          
          // Footer indicator
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Row(
              children: [
                const Icon(Icons.insights_rounded, size: 16, color: themeAccentGreen),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "Operasional kurir k24 berjalan aman dan tepat waktu.",
                    style: TextStyle(fontSize: 11, color: themeTextDark.withOpacity(0.85), fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------
  // 2. MITRA TAB
  // ---------------------------------------------------------

  Widget _buildMitraTab() {
    if (_isLoadingMitra) {
      return const Center(child: CircularProgressIndicator(color: themeAccentGreen));
    }

    if (_errorMitra != null) {
      return _buildErrorState(_errorMitra!, _fetchMitra);
    }

    return RefreshIndicator(
      onRefresh: () async {
        await _fetchMitra();
      },
      color: themeAccentGreen,
      child: Column(
        key: const ValueKey("mitra_tab_content"),
        children: [
          // Search Field matching mockup style
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
                boxShadow: const [
                  BoxShadow(color: themeCardShadow, blurRadius: 10, offset: Offset(0, 4)),
                ],
              ),
              child: TextField(
                controller: _mitraSearchController,
                style: const TextStyle(color: themeTextDark, fontSize: 14),
                decoration: InputDecoration(
                  hintText: "Cari mitra apotek...",
                  hintStyle: TextStyle(color: themeTextMuted.withOpacity(0.5)),
                  prefixIcon: const Icon(Icons.search, color: themeAccentGreen),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                ),
              ),
            ),
          ),
          
          Expanded(
            child: _filteredMitra.isEmpty
                ? const Center(
                    child: Text(
                      "Mitra tidak ditemukan",
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    itemCount: _filteredMitra.length,
                    itemBuilder: (context, index) {
                      final m = _filteredMitra[index];
                      return _buildMitraCard(m);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildMitraCard(MitraModel m) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: themeCardShadow,
            blurRadius: 10,
            offset: Offset(0, 4),
          )
        ],
        border: Border.all(color: const Color(0xFFEDF2F7), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18.0),
        child: Row(
          children: [
            // Circular Avatar Letter in blue/green accents
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: themeAccentBlue.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                m.name.isNotEmpty ? m.name[0].toUpperCase() : 'M',
                style: const TextStyle(
                  color: themeAccentBlue,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    m.name,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: themeTextDark),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    "@${m.username}",
                    style: TextStyle(color: themeTextMuted, fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.email_outlined, size: 13, color: themeTextMuted),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          m.email,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: themeTextMuted, fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(Icons.phone_android_rounded, size: 13, color: themeTextMuted),
                      const SizedBox(width: 6),
                      Text(
                        m.phone.isNotEmpty ? m.phone : "-",
                        style: const TextStyle(color: themeTextMuted, fontSize: 11),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                color: themeBg,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.keyboard_arrow_right_rounded, size: 18, color: themeAccentGreen),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------
  // 3. DRIVER TAB
  // ---------------------------------------------------------

  Widget _buildDriverTab() {
    if (_isLoadingDrivers) {
      return const Center(child: CircularProgressIndicator(color: themeAccentGreen));
    }

    if (_errorDrivers != null) {
      return _buildErrorState(_errorDrivers!, _fetchDrivers);
    }

    return RefreshIndicator(
      onRefresh: () async {
        await _fetchDrivers();
      },
      color: themeAccentGreen,
      child: Column(
        key: const ValueKey("driver_tab_content"),
        children: [
          // Search Field matching mockup style
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
                boxShadow: const [
                  BoxShadow(color: themeCardShadow, blurRadius: 10, offset: Offset(0, 4)),
                ],
              ),
              child: TextField(
                controller: _driverSearchController,
                style: const TextStyle(color: themeTextDark, fontSize: 14),
                decoration: InputDecoration(
                  hintText: "Cari driver K-24...",
                  hintStyle: TextStyle(color: themeTextMuted.withOpacity(0.5)),
                  prefixIcon: const Icon(Icons.search, color: themeAccentGreen),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                ),
              ),
            ),
          ),

          Expanded(
            child: _filteredDrivers.isEmpty
                ? const Center(
                    child: Text(
                      "Driver tidak ditemukan",
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    itemCount: _filteredDrivers.length,
                    itemBuilder: (context, index) {
                      final d = _filteredDrivers[index];
                      return _buildDriverCard(d);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildDriverCard(DriverModel d) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: themeCardShadow,
            blurRadius: 10,
            offset: Offset(0, 4),
          )
        ],
        border: Border.all(color: const Color(0xFFEDF2F7), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Driver Profile Pic Placeholder
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: themeBg,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.two_wheeler_rounded, color: themeAccentGreen, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          d.name,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: themeTextDark),
                        ),
                      ),
                      // Rating display
                      Row(
                        children: [
                          const Icon(Icons.star, color: Colors.amber, size: 14),
                          const SizedBox(width: 2),
                          Text(
                            d.rating.toStringAsFixed(1),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: themeTextDark),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // Status + Plat Number
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: d.isActive 
                              ? const Color(0xFFE2F6EA)
                              : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Status Pulse Indicator
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: d.isActive ? themeAccentGreen : Colors.grey,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              d.isActive ? "ONLINE" : "OFFLINE",
                              style: TextStyle(
                                color: d.isActive ? themeAccentGreen : Colors.grey.shade700,
                                fontWeight: FontWeight.bold,
                                                    fontSize: 9,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        d.plateNumber.isNotEmpty ? d.plateNumber : "[No Plat]",
                        style: TextStyle(color: themeTextMuted, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  gapH12,
                  // Phone & Email
                  Row(
                    children: [
                      Icon(Icons.phone_android_rounded, size: 12, color: themeTextMuted),
                      const SizedBox(width: 6),
                      Text(
                        d.phone,
                        style: const TextStyle(color: themeTextMuted, fontSize: 11),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(Icons.email_outlined, size: 12, color: themeTextMuted),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          d.email,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: themeTextMuted, fontSize: 11),
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
    );
  }

  // ---------------------------------------------------------
  // 4. PROFIL TAB (Admin details & Logout action)
  // ---------------------------------------------------------

  Widget _buildProfilTab() {
    return FutureBuilder<List<String?>>(
      future: Future.wait([ApiService.getName(), ApiService.getEmail()]),
      builder: (context, snapshot) {
        final name = (snapshot.hasData ? snapshot.data![0] : "Goodwheel Admin") ?? "Goodwheel Admin";
        final email = (snapshot.hasData ? snapshot.data![1] : "goodwheel@k24.com") ?? "goodwheel@k24.com";
        
        final List<IconData> avatarIcons = [
          Icons.person_rounded,
          Icons.medical_services_rounded,
          Icons.two_wheeler_rounded,
        ];
        final List<Color> avatarColors = [
          themeAccentBlue,
          themeAccentGreen,
          Colors.orange,
        ];

        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            key: const ValueKey("profil_tab_content"),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Profile Header Card
              Container(
                padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: const [
                    BoxShadow(color: themeCardShadow, blurRadius: 16, offset: Offset(0, 4)),
                  ],
                  border: Border.all(color: const Color(0xFFEDF2F7), width: 1),
                ),
                child: Column(
                  children: [
                    _customProfilePicPath != null
                        ? buildProfileImage(_customProfilePicPath, size: 80)
                        : buildProfileImage(
                            null,
                            size: 80,
                            fallbackIcon: avatarIcons[_userAvatarIndex],
                            fallbackColor: avatarColors[_userAvatarIndex],
                          ),
                    gapH16,
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: themeTextDark,
                      ),
                    ),
                    Text(
                      email,
                      style: const TextStyle(
                        fontSize: 12,
                        color: themeTextMuted,
                      ),
                    ),
                    gapH8,
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: themeAccentGreen.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        "ADMIN UTAMA",
                        style: TextStyle(
                          color: themeAccentGreen,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              gapH20,

              // Unified card container for all menu settings rows
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: const [
                    BoxShadow(color: themeCardShadow, blurRadius: 16, offset: Offset(0, 4)),
                  ],
                  border: Border.all(color: const Color(0xFFEDF2F7), width: 1),
                ),
                child: Column(
                  children: [
                    // Pengaturan Profil
                    _buildProfileMenuRow(
                      icon: Icons.person_outline_rounded,
                      title: "Pengaturan Profil",
                      desc: "Ubah nama, email, nomor HP, & foto profil",
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const ProfileSettingsPage()),
                        ).then((value) {
                          if (value == true) {
                            _loadAvatarIndex();
                            setState(() {}); // reload display name/email
                          }
                        });
                      },
                    ),
                    const Divider(height: 1, indent: 56, endIndent: 20, color: Color(0xFFEDF2F7)),

                    // Keamanan Akun
                    _buildProfileMenuRow(
                      icon: Icons.security_rounded,
                      title: "Keamanan Akun",
                      desc: "Kelola kata sandi, email, & biometrik wajah",
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const AccountSecurityPage()),
                        );
                      },
                    ),
                    const Divider(height: 1, indent: 56, endIndent: 20, color: Color(0xFFEDF2F7)),

                    // Ketentuan Layanan
                    _buildProfileMenuRow(
                      icon: Icons.assignment_rounded,
                      title: "Ketentuan Layanan",
                      desc: "Syarat operasional penggunaan sistem Apotek K-24",
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const TermsOfServicePage()),
                        );
                      },
                    ),
                    const Divider(height: 1, indent: 56, endIndent: 20, color: Color(0xFFEDF2F7)),

                    // Kebijakan Privasi
                    _buildProfileMenuRow(
                      icon: Icons.privacy_tip_rounded,
                      title: "Kebijakan Privasi",
                      desc: "Pernyataan komitmen perlindungan data pengguna",
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const PrivacyPolicyPage()),
                        );
                      },
                    ),
                    const Divider(height: 1, indent: 56, endIndent: 20, color: Color(0xFFEDF2F7)),

                    // Aktivitas Akun
                    _buildProfileMenuRow(
                      icon: Icons.history_rounded,
                      title: "Aktivitas Akun",
                      desc: "Riwayat login dan log audit keamanan terkini",
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const AccountActivityPage()),
                        );
                      },
                    ),
                    const Divider(height: 1, indent: 56, endIndent: 20, color: Color(0xFFEDF2F7)),

                    // Segarkan Data
                    _buildProfileMenuRow(
                      icon: Icons.refresh_rounded,
                      title: "Segarkan Data",
                      desc: "Muat ulang stats, driver, dan mitra secara real-time",
                      onTap: () {
                        _fetchStats();
                        _fetchDrivers();
                        _fetchMitra();
                        ToastHelper.show(context, message: "Data berhasil disegarkan!");
                      },
                    ),
                  ],
                ),
              ),
              gapH16,

              // Standalone Logout Card
              GestureDetector(
                onTap: _handleLogout,
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AppColors.accentRed.withValues(alpha: 0.2), width: 1),
                    boxShadow: const [
                      BoxShadow(color: themeCardShadow, blurRadius: 16, offset: Offset(0, 4)),
                    ],
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.logout_rounded, color: AppColors.accentRed, size: 20),
                      SizedBox(width: 10),
                      Text(
                        "Keluar Sesi Admin",
                        style: TextStyle(
                          color: AppColors.accentRed,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          fontFamily: 'Poppins',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              gapH48, // Padding at bottom for floating nav
            ],
          ),
        );
      },
    );
  }

  Widget _buildProfileMenuRow({
    required IconData icon,
    required String title,
    required String desc,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: themeAccentGreen.withOpacity(0.08),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: themeAccentGreen, size: 20),
      ),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: themeTextDark, fontFamily: 'Poppins'),
      ),
      subtitle: Text(
        desc,
        style: const TextStyle(fontSize: 11, color: themeTextMuted),
      ),
      trailing: const Icon(Icons.chevron_right_rounded, size: 18, color: themeTextMuted),
      onTap: onTap,
    );
  }



  // ---------------------------------------------------------
  // 5. CREATE MITRA TAB
  // ---------------------------------------------------------

  Widget _buildCreateMitraTab() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
      child: Form(
        key: _formKey,
        child: Column(
          key: const ValueKey("create_mitra_content"),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              "Daftarkan Mitra Baru",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: themeTextDark,
              ),
            ),
            gapH4,
            const Text(
              "Masukkan data mitra apotek baru secara lengkap di bawah ini.",
              style: TextStyle(fontSize: 12, color: themeTextMuted),
            ),
            gapH24,
            
            // Name Field
            _buildFieldLabel("Nama Mitra"),
            TextFormField(
              controller: _nameController,
              style: const TextStyle(color: themeTextDark, fontSize: 14),
              decoration: _buildInputDecoration("Masukkan nama outlet mitra", Icons.store_rounded),
              validator: (v) => v == null || v.trim().isEmpty ? "Nama wajib diisi" : null,
            ),
            gapH16,

            // Username Field
            _buildFieldLabel("Username"),
            TextFormField(
              controller: _usernameController,
              style: const TextStyle(color: themeTextDark, fontSize: 14),
              decoration: _buildInputDecoration("Masukkan username unik", Icons.person_outline_rounded),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return "Username wajib diisi";
                if (v.contains(' ')) return "Username tidak boleh mengandung spasi";
                return null;
              },
            ),
            gapH16,

            // Email Field
            _buildFieldLabel("Email Mitra"),
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              style: const TextStyle(color: themeTextDark, fontSize: 14),
              decoration: _buildInputDecoration("Masukkan email resmi", Icons.email_outlined),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return "Email wajib diisi";
                final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
                if (!emailRegex.hasMatch(v)) return "Format email tidak valid";
                return null;
              },
            ),
            gapH16,

            // Phone Field
            _buildFieldLabel("Nomor HP"),
            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              style: const TextStyle(color: themeTextDark, fontSize: 14),
              decoration: _buildInputDecoration("Masukkan nomor telepon", Icons.phone_android_rounded),
              validator: (v) => v == null || v.trim().isEmpty ? "Nomor telepon wajib diisi" : null,
            ),
            gapH16,

            // Password Field
            _buildFieldLabel("Kata Sandi"),
            TextFormField(
              controller: _passwordController,
              obscureText: !_showPassword,
              style: const TextStyle(color: themeTextDark, fontSize: 14),
              decoration: InputDecoration(
                hintText: "Minimal 6 karakter",
                hintStyle: TextStyle(color: themeTextMuted.withOpacity(0.5)),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: const BorderSide(color: themeAccentGreen, width: 1.5),
                ),
                prefixIcon: const Icon(Icons.lock_outline_rounded, color: themeAccentGreen),
                suffixIcon: IconButton(
                  icon: Icon(_showPassword ? Icons.visibility : Icons.visibility_off, color: Colors.grey),
                  onPressed: () => setState(() => _showPassword = !_showPassword),
                ),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return "Kata sandi wajib diisi";
                if (v.length < 6) return "Kata sandi minimal 6 karakter";
                return null;
              },
            ),
            gapH32,

            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: themeAccentGreen,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 54),
                elevation: 4,
                shadowColor: themeAccentGreen.withOpacity(0.2),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(27)),
              ),
              onPressed: _isCreatingMitra ? null : _handleCreateMitra,
              child: _isCreatingMitra
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                    )
                  : const Text(
                      "Daftarkan Mitra Baru",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
            ),
            gapH48, // space for nav
          ],
        ),
      ),
    );
  }

  Widget _buildFieldLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 4.0, bottom: 8.0),
      child: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: themeTextDark),
      ),
    );
  }

  InputDecoration _buildInputDecoration(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: themeTextMuted.withOpacity(0.5)),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: const BorderSide(color: themeAccentGreen, width: 1.5),
      ),
      prefixIcon: Icon(icon, color: themeAccentGreen),
    );
  }

  // ---------------------------------------------------------
  // Common Widgets
  // ---------------------------------------------------------

  Widget _buildErrorState(String error, VoidCallback onRetry) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off_rounded, color: themeAccentBlue, size: 60),
            gapH16,
            const Text(
              "Koneksi Gagal",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: themeTextDark),
            ),
            gapH8,
            Text(
              error,
              textAlign: TextAlign.center,
              style: const TextStyle(color: themeTextMuted, fontSize: 12),
            ),
            gapH24,
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: themeAccentGreen,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
              onPressed: onRetry,
              child: const Text("Coba Lagi"),
            ),
          ],
        ),
      ),
    );
  }
}
