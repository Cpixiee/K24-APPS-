import 'dart:async';
import 'package:flutter/material.dart';
import 'package:apps_k24/theme/app_colors.dart';
import 'package:apps_k24/theme/gaps.dart';
import 'package:apps_k24/services/api_service.dart';
import 'package:apps_k24/models/dashboard_data.dart';
import 'package:apps_k24/pages/get_started_screen.dart';
import 'package:apps_k24/pages/profile_pages.dart';
import 'package:apps_k24/pages/detail_pesanan_page.dart';
import 'package:apps_k24/pages/verifikasi_pod_page.dart';
import 'package:apps_k24/pages/notifications_page.dart';
import 'package:apps_k24/pages/track_live_page.dart';
import 'package:apps_k24/services/notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LoggedScreen extends StatefulWidget {
  const LoggedScreen({super.key});

  @override
  State<LoggedScreen> createState() => _LoggedScreenState();
}

class _LoggedScreenState extends State<LoggedScreen> {
  int _currentTab = 0;
  DashboardDataModel? _dashboardData;
  bool _isLoading = true;
  String? _errorMessage;
  bool _isTogglingActive = false;
  int _userAvatarIndex = 0;
  String? _customProfilePicPath;
  Timer? _notificationTimer;
  int _unreadNotificationCount = 0;
  final Set<String> _collapsedCardIds = {};

  static const List<IconData> _avatarIcons = [
    Icons.person_rounded,
    Icons.medical_services_rounded,
    Icons.two_wheeler_rounded,
  ];
  static const List<Color> _avatarColors = [
    AppColors.secondaryBlue,
    Color(0xFFFFB300),
    Colors.orange,
  ];

  Future<void> _loadAvatarIndex() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _userAvatarIndex = prefs.getInt('user_avatar_index') ?? 0;
        _customProfilePicPath = prefs.getString('user_profile_pic_path');
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _fetchDashboardData(showLoading: true);
    _loadAvatarIndex();
    
    // Register background worker task
    NotificationService.registerBackgroundTask();
    
    // Initial notifications check
    _checkNotifications();

    // Setup periodic polling for new notifications every 15 seconds
    _notificationTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
      _checkNotifications();
    });
  }

  @override
  void dispose() {
    _notificationTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkNotifications() async {
    // 1. Run local notification trigger if any new IDs
    await NotificationService.checkNotificationsNow();
    
    // 2. Fetch unread count for UI badge
    try {
      final list = await ApiService.getNotifications();
      final unread = list.where((n) => !(n['is_read'] ?? false)).length;
      if (mounted) {
        setState(() {
          _unreadNotificationCount = unread;
        });
      }
    } catch (_) {
      // Ignore background/polling errors
    }
  }

  // Currency Formatter Helper (Rupiah)
  String _formatRupiah(double amount) {
    final value = amount.toStringAsFixed(0);
    final reg = RegExp(r'(\d)(?=(\d{3})+(?!\d))');
    final formatted = value.replaceAllMapped(reg, (Match m) => '${m[1]}.');
    return 'Rp $formatted';
  }

  // Fetch all dashboard data from the Go backend
  Future<void> _fetchDashboardData({bool showLoading = false}) async {
    if (showLoading) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final data = await ApiService.getDashboard();
      setState(() {
        _dashboardData = data;
        _errorMessage = null;
        _isLoading = false;
      });
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('driver_phone', data.driver.phone);
      await prefs.setString('driver_plate', data.driver.plateNumber);
      await prefs.setString('driver_rating', data.driver.rating.toStringAsFixed(2));
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  // Toggle driver active status
  Future<void> _handleToggleActive(bool value) async {
    setState(() {
      _isTogglingActive = true;
    });

    try {
      await ApiService.toggleActive(value);
      // Refresh dashboard data to sync status
      await _fetchDashboardData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal memperbarui status aktif: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isTogglingActive = false;
      });
    }
  }

  // Selesaikan Pengantaran
  Future<void> _handleCompleteOrder(int orderId) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Selesaikan Pengantaran?', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Apakah Anda sudah mengantarkan obat ke tangan pelanggan dengan selamat?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGreen,
              foregroundColor: AppColors.white,
            ),
            onPressed: () async {
              Navigator.pop(context); // Close dialog
              
              setState(() => _isLoading = true);
              try {
                await ApiService.completeOrder(orderId);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Pengantaran berhasil diselesaikan! Pendapatan Anda telah ditambahkan.'),
                    backgroundColor: AppColors.primaryGreen,
                  ),
                );
                // Refresh to update stats & remove active card
                _fetchDashboardData(showLoading: true);
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Gagal menyelesaikan pengantaran: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
                setState(() => _isLoading = false);
              }
            },
            child: const Text('Ya, Selesai'),
          ),
        ],
      ),
    );
  }

  // Logout & clear JWT tokens
  Future<void> _handleLogout() async {
    await NotificationService.cancelBackgroundTask();
    await ApiService.clearAuthData();
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const GetStartedScreen(title: 'Get Started'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: _buildTabContent(),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentTab,
        onTap: (index) {
          setState(() {
            _currentTab = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppColors.primaryGreen,
        unselectedItemColor: Colors.grey.shade400,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, fontFamily: 'Poppins'),
        unselectedLabelStyle: const TextStyle(fontSize: 11, fontFamily: 'Poppins'),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.grid_view_rounded),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.assignment_outlined),
            label: 'Pesanan',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_balance_wallet_outlined),
            label: 'Penghasilan',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline_rounded),
            label: 'Akun',
          ),
        ],
      ),
    );
  }

  Widget _buildTabContent() {
    switch (_currentTab) {
      case 0:
        return _buildDashboardContent();
      case 1:
        return _buildPesananContent();
      case 2:
        return _buildPenghasilanContent();
      case 3:
        return _buildAkunContent();
      default:
        return _buildDashboardContent();
    }
  }

  // -------------------------------------------------------------
  // TAB 0: ENHANCED KINETIC DRIVER DASHBOARD
  // -------------------------------------------------------------
  Widget _buildDashboardContent() {
    if (_isLoading && _dashboardData == null) {
      return const Center(
        child: CircularProgressIndicator(
          color: AppColors.primaryGreen,
        ),
      );
    }

    if (_errorMessage != null && _dashboardData == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.wifi_off_rounded, size: 48, color: Colors.red.shade400),
              ),
              gapH16,
              const Text(
                'Gagal Terhubung ke Server',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.darkGrey, fontFamily: 'Poppins'),
              ),
              gapH8,
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13, fontFamily: 'Poppins'),
              ),
              gapH24,
              ElevatedButton.icon(
                onPressed: () => _fetchDashboardData(showLoading: true),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Coba Lagi', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Poppins')),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final data = _dashboardData!;
    final activeOrders = data.recentOrders.where((o) => o.status != 'COMPLETED' && o.status != 'CANCELLED').toList();

    return Stack(
      children: [
        // Kinetic background subtle ambient glow circles
        Positioned(
          top: -100,
          right: -80,
          child: Container(
            width: 320,
            height: 320,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  const Color(0xFF10B981).withValues(alpha: 0.15),
                  const Color(0xFF3B82F6).withValues(alpha: 0.05),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
            ),
          ),
        ),
        Positioned(
          top: 240,
          left: -100,
          child: Container(
            width: 280,
            height: 280,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  const Color(0xFFFFB300).withValues(alpha: 0.12),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),

        // Main Refreshable Content
        RefreshIndicator(
          onRefresh: () => _fetchDashboardData(showLoading: false),
          color: AppColors.primaryGreen,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Kinetic Top Navigation Bar
                _buildKineticAppBar(data.driver),
                gapH20,

                // 2. Kinetic Hero Driver Card (Glassmorphic Status & Toggle)
                _buildKineticHeroCard(data.driver),
                gapH20,

                // 3. Active Delivery Kinetic Highlight (Render ALL Dispatch Group Cards)
                if (activeOrders.isNotEmpty) ...[
                  ..._buildGroupedActiveCards(activeOrders),
                  gapH12,
                ],

                // 4. Kinetic Quick Actions Dock
                _buildKineticQuickActionsDock(data.driver),
                gapH24,

                // 5. Kinetic Performance & Stats Grid
                _buildKineticStatsSection(data.stats, data.driver.rating),
                gapH24,

                // 6. Recent Deliveries Feed
                _buildRecentHistorySection(data.recentOrders),
                gapH24,
              ],
            ),
          ),
        ),
      ],
    );
  }

  // -------------------------------------------------------------
  // 1. KINETIC TOP NAVIGATION BAR
  // -------------------------------------------------------------
  Widget _buildKineticAppBar(DriverModel driver) {
    return Row(
      children: [
        // Kinetic Avatar Pill
        GestureDetector(
          onTap: () {
            setState(() {
              _currentTab = 3; // Navigate to profile/account
            });
          },
          child: Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFF10B981), Color(0xFF3B82F6)],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF10B981).withValues(alpha: 0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Container(
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
              ),
              child: _customProfilePicPath != null
                  ? buildProfileImage(_customProfilePicPath, size: 42)
                  : buildProfileImage(
                      null,
                      size: 42,
                      fallbackIcon: _avatarIcons[_userAvatarIndex],
                      fallbackColor: _avatarColors[_userAvatarIndex],
                    ),
            ),
          ),
        ),
        gapW12,

        // Greeting Title
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      driver.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.darkGrey,
                        fontFamily: 'Poppins',
                        letterSpacing: -0.3,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'PRO',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF059669),
                        fontFamily: 'Poppins',
                      ),
                    ),
                  ),
                ],
              ),
              Text(
                'Selamat datang kembali! 👋',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade600,
                  fontFamily: 'Poppins',
                ),
              ),
            ],
          ),
        ),

        // Kinetic Notification Bell Button
        Container(
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            shape: BoxShape.circle,
          ),
          child: Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined, color: AppColors.darkGrey, size: 24),
                onPressed: () async {
                  final refresh = await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const NotificationsPage()),
                  );
                  if (refresh == true || refresh == null) {
                    _checkNotifications();
                  }
                },
              ),
              if (_unreadNotificationCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                      color: Color(0xFFEF4444),
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 14,
                      minHeight: 14,
                    ),
                    child: Text(
                      '$_unreadNotificationCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  // -------------------------------------------------------------
  // 2. KINETIC HERO DRIVER CARD (GLASSMORPHIC ACTIVE TOGGLE)
  // -------------------------------------------------------------
  Widget _buildKineticHeroCard(DriverModel driver) {
    final bool isOnline = driver.isActive;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isOnline
              ? [
                  const Color(0xFF0F172A), // Dark Slate
                  const Color(0xFF1E293B),
                ]
              : [
                  const Color(0xFF334155),
                  const Color(0xFF1E293B),
                ],
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: isOnline
                ? const Color(0xFF10B981).withValues(alpha: 0.25)
                : Colors.black.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Ambient Glass geometric background patterns
          Positioned(
            right: -30,
            top: -30,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isOnline
                    ? const Color(0xFF10B981).withValues(alpha: 0.15)
                    : Colors.white.withValues(alpha: 0.05),
              ),
            ),
          ),
          Positioned(
            left: -40,
            bottom: -40,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.04),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(22.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Driver Profile Info Row
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            driver.name.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              fontFamily: 'Poppins',
                              letterSpacing: 0.5,
                            ),
                          ),
                          gapH4,
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.two_wheeler_rounded, size: 14, color: Color(0xFFFFB300)),
                                    const SizedBox(width: 6),
                                    Text(
                                      driver.plateNumber,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                        fontFamily: 'Poppins',
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              gapW8,
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.star_rounded, size: 13, color: Color(0xFFFFB300)),
                                    gapW4,
                                    Text(
                                      driver.rating.toStringAsFixed(1),
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                        fontFamily: 'Poppins',
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                gapH20,

                // Kinetic Shift Status & Toggle Glass Container
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isOnline
                          ? const Color(0xFF10B981).withValues(alpha: 0.3)
                          : Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          // Pulse dot indicator
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isOnline ? const Color(0xFF10B981) : Colors.grey.shade400,
                              boxShadow: isOnline
                                  ? [
                                      const BoxShadow(
                                        color: Color(0xFF10B981),
                                        blurRadius: 8,
                                        spreadRadius: 2,
                                      ),
                                    ]
                                  : null,
                            ),
                          ),
                          gapW12,
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isOnline ? 'SHIFT AKTIF' : 'OFFLINE',
                                style: TextStyle(
                                  color: isOnline ? const Color(0xFF10B981) : Colors.grey.shade300,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 13,
                                  fontFamily: 'Poppins',
                                  letterSpacing: 0.5,
                                ),
                              ),
                              Text(
                                isOnline ? 'Siap menerima orderan baru' : 'Aktifkan untuk mulai bekerja',
                                style: TextStyle(
                                  color: Colors.grey.shade400,
                                  fontSize: 10,
                                  fontFamily: 'Poppins',
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),

                      _isTogglingActive
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2.5, color: Color(0xFF10B981)),
                            )
                          : Transform.scale(
                              scale: 0.9,
                              child: Switch.adaptive(
                                value: driver.isActive,
                                activeTrackColor: const Color(0xFF10B981),
                                inactiveThumbColor: Colors.white,
                                inactiveTrackColor: Colors.white.withValues(alpha: 0.2),
                                onChanged: _handleToggleActive,
                              ),
                            ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildGroupedActiveCards(List<OrderModel> activeOrders) {
    final Map<String, List<OrderModel>> grouped = {};
    for (final o in activeOrders) {
      final key = o.dispatchId.isNotEmpty
          ? o.dispatchId
          : (o.parentOrderNumber.isNotEmpty ? o.parentOrderNumber : o.orderNumber);
      if (!grouped.containsKey(key)) grouped[key] = [];
      grouped[key]!.add(o);
    }

    final widgets = <Widget>[];
    grouped.forEach((dispId, orders) {
      // Pick current active (uncompleted) stop dynamically
      final activeStop = orders.firstWhere(
        (s) => s.status != 'COMPLETED' && s.status != 'READY_FOR_PICKUP_FACTURE' && s.status != 'CANCELLED',
        orElse: () => orders.first,
      );
      final activeIndex = orders.indexOf(activeStop) + 1;
      widgets.add(_buildKineticActiveOrderHighlight(
        activeStop,
        groupStops: orders,
        dispatchTag: dispId,
        activeStopIndex: activeIndex,
      ));
      widgets.add(gapH12);
    });
    return widgets;
  }

  // -------------------------------------------------------------
  // 3. KINETIC ACTIVE ORDER HIGHLIGHT CARD (COLLAPSIBLE DROPDOWN)
  // -------------------------------------------------------------
  Widget _buildKineticActiveOrderHighlight(
    OrderModel order, {
    List<OrderModel>? groupStops,
    String? dispatchTag,
    int activeStopIndex = 1,
  }) {
    final stopsCount = groupStops?.length ?? 1;
    final tagText = dispatchTag != null && dispatchTag.isNotEmpty
        ? dispatchTag
        : (order.dispatchId.isNotEmpty ? order.dispatchId : order.orderNumber);

    final isCollapsed = _collapsedCardIds.contains(tagText);
    final targetPharmacy = order.customerName.isNotEmpty ? order.customerName : order.pharmacyName;

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0054A6), Color(0xFF003B75)],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0054A6).withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row with Dropdown/Collapse Toggle
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.local_shipping_rounded, color: Colors.white, size: 16),
                    ),
                    gapW8,
                    Flexible(
                      child: Text(
                        stopsCount > 1
                            ? 'TITIK AKTIF $activeStopIndex/$stopsCount (BATCH)'
                            : 'PENGANTARAN AKTIF',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                          fontFamily: 'Poppins',
                          letterSpacing: 0.5,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFB300),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      tagText,
                      style: const TextStyle(
                        color: AppColors.darkGrey,
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                        fontFamily: 'Poppins',
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  // Dropdown / Collapse Button Toggle
                  IconButton(
                    constraints: const BoxConstraints(),
                    padding: const EdgeInsets.all(4),
                    icon: Icon(
                      isCollapsed
                          ? Icons.keyboard_arrow_down_rounded
                          : Icons.keyboard_arrow_up_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                    onPressed: () {
                      setState(() {
                        if (_collapsedCardIds.contains(tagText)) {
                          _collapsedCardIds.remove(tagText);
                        } else {
                          _collapsedCardIds.add(tagText);
                        }
                      });
                    },
                    tooltip: isCollapsed ? 'Buka Card' : 'Kecilkan Card',
                  ),
                ],
              ),
            ],
          ),

          // If Collapsed: Render 1-line Compact View
          if (isCollapsed) ...[
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () {
                setState(() {
                  _collapsedCardIds.remove(tagText);
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.location_on_rounded, color: Color(0xFFFFB300), size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Titik $activeStopIndex: $targetPharmacy (${order.deliveryAddress})',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'Poppins',
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const Icon(Icons.unfold_more_rounded, color: Colors.white70, size: 16),
                  ],
                ),
              ),
            ),
          ] else ...[
            gapH12,

            // Customer & Address Row
            Row(
              children: [
                const Icon(Icons.person_pin_circle_rounded, color: Colors.white70, size: 20),
                gapW8,
                Expanded(
                  child: Text(
                    'Titik $activeStopIndex: $targetPharmacy (${order.deliveryAddress})',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      fontFamily: 'Poppins',
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            gapH12,

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => TrackLivePage(initialOrder: order),
                        ),
                      ).then((_) => _fetchDashboardData());
                    },
                    icon: const Icon(Icons.radar_rounded, size: 16),
                    label: const Text('Lacak Live', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'Poppins')),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => DetailPesananPage(order: order),
                        ),
                      ).then((_) => _fetchDashboardData());
                    },
                    icon: const Icon(Icons.visibility_rounded, size: 16),
                    label: const Text('Detail', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'Poppins')),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white.withOpacity(0.2),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _handleCompleteOrder(order.id),
                    icon: const Icon(Icons.check_circle_rounded, size: 16),
                    label: Text(
                      stopsCount > 1 ? 'Titik $activeStopIndex' : 'Selesai',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'Poppins'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF0054A6),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // 4. KINETIC QUICK ACTIONS DOCK
  // -------------------------------------------------------------
  Widget _buildKineticQuickActionsDock(DriverModel driver) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.grey.shade100),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildQuickActionButton(
            icon: Icons.radar_rounded,
            label: 'Lacak Live',
            color: const Color(0xFF10B981),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const TrackLivePage()),
              );
            },
          ),
          _buildQuickActionButton(
            icon: Icons.assignment_rounded,
            label: 'Pesanan',
            color: const Color(0xFF0054A6),
            onTap: () => setState(() => _currentTab = 1),
          ),
          _buildQuickActionButton(
            icon: Icons.account_balance_wallet_rounded,
            label: 'Dompet',
            color: const Color(0xFF059669),
            onTap: () => setState(() => _currentTab = 2),
          ),
          _buildQuickActionButton(
            icon: Icons.notifications_active_rounded,
            label: 'Notifikasi',
            color: const Color(0xFFFFB300),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const NotificationsPage()),
              );
            },
          ),
          _buildQuickActionButton(
            icon: Icons.person_rounded,
            label: 'Profil',
            color: const Color(0xFF8B5CF6),
            onTap: () => setState(() => _currentTab = 3),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.darkGrey,
              fontFamily: 'Poppins',
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // 5. KINETIC STATS & PERFORMANCE SECTION
  // -------------------------------------------------------------
  Widget _buildKineticStatsSection(StatsModel stats, double rating) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              "Kinerja & Performa",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                fontFamily: 'Poppins',
                color: AppColors.darkGrey,
              ),
            ),
            GestureDetector(
              onTap: () => setState(() => _currentTab = 2),
              child: const Row(
                children: [
                  Text(
                    "Detail",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryGreen,
                      fontFamily: 'Poppins',
                    ),
                  ),
                  gapW4,
                  Icon(Icons.arrow_forward_ios_rounded, size: 12, color: AppColors.primaryGreen),
                ],
              ),
            ),
          ],
        ),
        gapH12,

        // Top Main Kinetic Earning Card
        Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF10B981), Color(0xFF059669)],
            ),
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF10B981).withValues(alpha: 0.25),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          padding: const EdgeInsets.all(20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.account_balance_wallet_rounded, color: Colors.white, size: 16),
                      ),
                      gapW8,
                      Text(
                        'PENDAPATAN HARI INI',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Colors.white.withValues(alpha: 0.9),
                          fontFamily: 'Poppins',
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _formatRupiah(stats.todayEarnings),
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      fontFamily: 'Poppins',
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.trending_up_rounded, color: Colors.white, size: 16),
                    gapW4,
                    Text(
                      '+14.2%',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        fontFamily: 'Poppins',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        gapH12,

        // 2 Secondary Kinetic Metric Cards
        Row(
          children: [
            Expanded(
              child: _buildKineticMiniMetric(
                icon: Icons.local_shipping_rounded,
                iconColor: const Color(0xFF0054A6),
                iconBg: const Color(0xFFEBF4FA),
                title: 'Pengantaran',
                value: '${stats.todayOrders} Selesai',
                subtitle: 'Hari ini',
              ),
            ),
            gapW12,
            Expanded(
              child: _buildKineticMiniMetric(
                icon: Icons.star_rounded,
                iconColor: const Color(0xFFFFB300),
                iconBg: const Color(0xFFFEF5E7),
                title: 'Rating Driver',
                value: rating.toStringAsFixed(2),
                subtitle: 'Sangat Baik',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildKineticMiniMetric({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String title,
    required String value,
    required String subtitle,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.grey.shade100),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey.shade600,
                    fontFamily: 'Poppins',
                  ),
                ),
              ),
            ],
          ),
          gapH12,
          Text(
            title,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade500,
              fontFamily: 'Poppins',
            ),
          ),
          gapH2,
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.darkGrey,
              fontFamily: 'Poppins',
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // Recent History section matching the mockup image (empty clipboard list layout)
  Widget _buildRecentHistorySection(List<OrderModel> recentOrders) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              "Riwayat Pengantaran Terbaru",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                fontFamily: 'Poppins',
                color: AppColors.darkGrey,
              ),
            ),
            GestureDetector(
              onTap: () {
                setState(() {
                  _currentTab = 1; // Switch to Pesanan tab
                });
              },
              child: const Row(
                children: [
                  Text(
                    "Lihat Semua",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryGreen,
                      fontFamily: 'Poppins',
                    ),
                  ),
                  gapW4,
                  Icon(Icons.chevron_right, size: 16, color: AppColors.primaryGreen),
                ],
              ),
            ),
          ],
        ),
        gapH12,
        if (recentOrders.isEmpty)
          // Empty State Clipboard card from the mockup image
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFFFAFAFA),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade100),
            ),
            padding: const EdgeInsets.symmetric(vertical: 36),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: const BoxDecoration(
                    color: Color(0xFFF3F4F6),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.assignment, size: 28, color: Colors.grey.shade400),
                ),
                gapH16,
                const Text(
                  'Belum ada riwayat pengantaran',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.darkGrey,
                    fontFamily: 'Poppins',
                  ),
                ),
                gapH4,
                const Text(
                  'Riwayat pengantaran Anda akan muncul di sini',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey,
                    fontFamily: 'Poppins',
                  ),
                ),
              ],
            ),
          )
        else
          // If orders history exists, render them cleanly
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: recentOrders.length > 3 ? 3 : recentOrders.length, // Show up to 3 in dashboard list
            separatorBuilder: (context, index) => gapH8,
            itemBuilder: (context, index) {
              final o = recentOrders[index];
              return Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                  border: Border.all(color: Colors.grey.shade100),
                ),
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFF00B05C).withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.check_circle_rounded, color: Color(0xFF00B05C), size: 22),
                    ),
                    gapW16,
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            o.pharmacyName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: AppColors.darkGrey,
                              fontFamily: 'Poppins',
                            ),
                          ),
                          gapH4,
                          Row(
                            children: [
                              const Icon(Icons.location_on_outlined, size: 12, color: Colors.grey),
                              gapW4,
                              Expanded(
                                child: Text(
                                  o.deliveryAddress,
                                  style: const TextStyle(fontSize: 11, color: Colors.grey, fontFamily: 'Poppins'),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    gapW8,
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          _formatRupiah(o.deliveryFee),
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                            color: Color(0xFF00B05C), // Clean Green for Earning!
                            fontFamily: 'Poppins',
                          ),
                        ),
                        gapH4,
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            o.orderNumber,
                            style: TextStyle(
                              fontSize: 9,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Poppins',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }

  // -------------------------------------------------------------
  // TAB 1: ALL ORDERS CONTENT
  // -------------------------------------------------------------
  // -------------------------------------------------------------
  // TAB 1: KINETIC ALL ORDERS CONTENT
  // -------------------------------------------------------------
  Widget _buildOrderCard(OrderModel o, {required bool isCurrentActive}) {
    // Dynamic status color & label
    Color statusBgColor = Colors.blue.shade50;
    Color statusTextColor = const Color(0xFF0054A6);
    String statusLabel = o.status;

    if (o.status == 'WAITING_FOR_PICKUP' || o.status == 'PENDING') {
      statusBgColor = const Color(0xFFFEF5E7);
      statusTextColor = const Color(0xFFD97706);
      statusLabel = o.unboxingOption == 'WAITING_FOR_UNBOXING' ? 'Unboxing Ditunda' : 'Menunggu Penjemputan';
    } else if (o.status == 'DELIVERING' || o.status == 'PICKED_UP') {
      statusBgColor = const Color(0xFFECFDF5);
      statusTextColor = const Color(0xFF10B981);
      statusLabel = 'Dalam Pengantaran';
    } else if (o.status == 'READY_FOR_PICKUP_FACTURE') {
      statusBgColor = Colors.purple.shade50;
      statusTextColor = Colors.purple.shade700;
      statusLabel = 'Ambil Faktur';
    } else if (o.status == 'COMPLETED') {
      statusBgColor = const Color(0xFFF3F4F6);
      statusTextColor = Colors.grey.shade700;
      statusLabel = 'Selesai';
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isCurrentActive ? const Color(0xFF10B981).withValues(alpha: 0.5) : Colors.grey.shade100,
          width: isCurrentActive ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isCurrentActive
                ? const Color(0xFF10B981).withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () async {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => DetailPesananPage(order: o),
              ),
            );
            if (result == true) {
              _fetchDashboardData(showLoading: true);
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Header Row: Status Badge & Order Number
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusBgColor,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: statusTextColor,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                statusLabel,
                                style: TextStyle(
                                  color: statusTextColor,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 10,
                                  fontFamily: 'Poppins',
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      o.orderNumber,
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Poppins',
                      ),
                    ),
                  ],
                ),
                gapH12,

                // Pharmacy Name
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0054A6).withValues(alpha: 0.08),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.local_pharmacy_rounded, color: Color(0xFF0054A6), size: 16),
                    ),
                    gapW8,
                    Expanded(
                      child: Text(
                        o.pharmacyName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          color: AppColors.darkGrey,
                          fontFamily: 'Poppins',
                        ),
                      ),
                    ),
                  ],
                ),
                gapH8,

                // Delivery Destination
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.location_on_rounded, color: Colors.grey.shade600, size: 16),
                    ),
                    gapW8,
                    Expanded(
                      child: Text(
                        '${o.customerName} • ${o.deliveryAddress}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade700,
                          fontFamily: 'Poppins',
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                gapH12,
                const Divider(height: 1, color: Color(0xFFF1F5F9)),
                gapH12,

                // Footer Row: Delivery Fee & Navigation Arrow
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Ongkos Kirim',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey.shade500,
                            fontFamily: 'Poppins',
                          ),
                        ),
                        Text(
                          _formatRupiah(o.deliveryFee),
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF10B981),
                            fontSize: 15,
                            fontFamily: 'Poppins',
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.arrow_forward_ios_rounded, color: AppColors.darkGrey, size: 14),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGroupedOrderCard(String parentNo, List<OrderModel> orders) {
    final firstStatus = orders.isNotEmpty ? orders.first.status : '';
    final isNeedsPickup = firstStatus == 'PICKING_UP' || firstStatus == 'ASSIGNED';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Parent Card Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: Color(0xFFD1FAE5),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.alt_route_rounded, color: Color(0xFF10B981), size: 20),
                ),
                gapW12,
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      parentNo,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                        fontFamily: 'Poppins',
                        color: AppColors.darkGrey,
                      ),
                    ),
                    Text(
                      'Rute Pengantaran Multi-Titik',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade600,
                        fontFamily: 'Poppins',
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${orders.length} Titik',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontFamily: 'Poppins',
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Sub-orders list inside this parent card
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: orders.length,
            separatorBuilder: (context, index) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
            itemBuilder: (context, index) {
              final o = orders[index];
              return InkWell(
                onTap: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => DetailPesananPage(order: o),
                    ),
                  );
                  if (result == true) {
                    _fetchDashboardData(showLoading: true);
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0054A6).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                'Titik ${index + 1}: ${o.pharmacyName}',
                                style: const TextStyle(
                                  color: Color(0xFF0054A6),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                  fontFamily: 'Poppins',
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            o.orderNumber,
                            style: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 11,
                              fontFamily: 'Poppins',
                            ),
                          ),
                        ],
                      ),
                      gapH8,
                      Text(
                        'Tujuan: ${o.customerName} (${o.deliveryAddress})',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade700,
                          fontFamily: 'Poppins',
                        ),
                      ),
                      gapH8,
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _formatRupiah(o.deliveryFee),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF10B981),
                              fontSize: 14,
                              fontFamily: 'Poppins',
                            ),
                          ),
                          if (isNeedsPickup)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.amber.shade50,
                                border: Border.all(color: Colors.amber.shade200),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Siap Pickup',
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.amber.shade900, fontFamily: 'Poppins'),
                              ),
                            )
                          else
                            const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

          // Unified Single Batch Pickup Action Button
          if (isNeedsPickup)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
                border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
              ),
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 46),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                onPressed: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => DetailPesananPage(order: orders.first),
                    ),
                  );
                  if (result == true) {
                    _fetchDashboardData(showLoading: true);
                  }
                },
                icon: const Icon(Icons.camera_alt_outlined, size: 20),
                label: Text(
                  'Konfirmasi Pickup Batch (${orders.length} Titik Alamat)',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, fontFamily: 'Poppins'),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPesananContent() {
    if (_isLoading && _dashboardData == null) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primaryGreen));
    }
    final data = _dashboardData!;

    // Group active orders by dispatchId or parentOrderNumber (excluding READY_FOR_PICKUP_FACTURE)
    final groupedActive = <String, List<OrderModel>>{};
    for (final o in data.activeOrders.where((o) => o.status != 'READY_FOR_PICKUP_FACTURE')) {
      final key = o.dispatchId.isNotEmpty
          ? o.dispatchId
          : (o.parentOrderNumber.isNotEmpty 
              ? o.parentOrderNumber 
              : o.orderNumber.replaceAll(RegExp(r'-[0-9]+$'), ''));
      groupedActive.putIfAbsent(key, () => []).add(o);
    }

    final activeListItems = <Widget>[];
    groupedActive.forEach((parentNo, orders) {
      activeListItems.add(_buildGroupedOrderCard(parentNo, orders));
      activeListItems.add(gapH12);
    });

    // POD Return orders list (status READY_FOR_PICKUP_FACTURE)
    final rawPodReturnOrders = <OrderModel>[];
    for (final o in data.recentOrders.where((o) => o.status == 'READY_FOR_PICKUP_FACTURE')) {
      rawPodReturnOrders.add(o);
    }
    for (final o in data.activeOrders.where((o) => o.status == 'READY_FOR_PICKUP_FACTURE')) {
      if (!rawPodReturnOrders.any((item) => item.id == o.id)) {
        rawPodReturnOrders.add(o);
      }
    }

    final groupedPOD = <String, List<OrderModel>>{};
    for (final o in rawPodReturnOrders) {
      final key = o.dispatchId.isNotEmpty
          ? o.dispatchId
          : (o.parentOrderNumber.isNotEmpty 
              ? o.parentOrderNumber 
              : o.orderNumber.replaceAll(RegExp(r'-[0-9]+$'), ''));
      groupedPOD.putIfAbsent(key, () => []).add(o);
    }

    final podReturnListItems = <Widget>[];
    groupedPOD.forEach((groupKey, orders) {
      podReturnListItems.add(
        InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () async {
            final res = await Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => VerifikasiPODPage(groupOrders: orders)),
            );
            if (res == true && mounted) {
              _fetchDashboardData(showLoading: false);
            }
          },
          child: _buildGroupedOrderCard(groupKey, orders),
        ),
      );
      podReturnListItems.add(gapH12);
    });

    // Completed orders list (status COMPLETED)
    final completedListItems = <Widget>[];
    for (final o in data.recentOrders.where((o) => o.status == 'COMPLETED')) {
      completedListItems.add(_buildOrderCard(o, isCurrentActive: false));
      completedListItems.add(gapH12);
    }

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          title: const Text('Daftar Pesanan', style: TextStyle(fontWeight: FontWeight.w800, fontFamily: 'Poppins', fontSize: 18)),
          centerTitle: true,
          backgroundColor: Colors.white,
          foregroundColor: AppColors.darkGrey,
          elevation: 0,
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(48),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(16),
              ),
              child: TabBar(
                indicator: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                labelColor: const Color(0xFF10B981),
                unselectedLabelColor: Colors.grey.shade600,
                labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontFamily: 'Poppins', fontSize: 11),
                unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontFamily: 'Poppins', fontSize: 11),
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                tabs: [
                  Tab(text: 'Proses (${groupedActive.length})'),
                  Tab(text: 'Pengembalian POD (${groupedPOD.length})'),
                  Tab(text: 'Selesai (${completedListItems.length ~/ 2})'),
                ],
              ),
            ),
          ),
        ),
        body: TabBarView(
          children: [
            // Active orders tab
            RefreshIndicator(
              onRefresh: () => _fetchDashboardData(showLoading: false),
              color: AppColors.primaryGreen,
              child: activeListItems.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        SizedBox(height: MediaQuery.of(context).size.height * 0.2),
                        Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: const BoxDecoration(
                                  color: Color(0xFFF1F5F9),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(Icons.assignment_outlined, size: 48, color: Colors.grey.shade400),
                              ),
                              gapH16,
                              const Text('Belum ada pesanan aktif', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.darkGrey, fontFamily: 'Poppins')),
                              gapH4,
                              Text('Pesanan baru yang siap diantar akan muncul di sini', style: TextStyle(color: Colors.grey.shade500, fontSize: 12, fontFamily: 'Poppins')),
                            ],
                          ),
                        ),
                      ],
                    )
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: activeListItems,
                    ),
            ),
            // Pengembalian POD Tab
            RefreshIndicator(
              onRefresh: () => _fetchDashboardData(showLoading: false),
              color: AppColors.primaryGreen,
              child: podReturnListItems.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        SizedBox(height: MediaQuery.of(context).size.height * 0.2),
                        Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: Colors.purple.shade50,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(Icons.qr_code_scanner_rounded, size: 48, color: Colors.purple.shade400),
                              ),
                              gapH16,
                              const Text('Tidak ada Pengembalian POD', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.darkGrey, fontFamily: 'Poppins')),
                              gapH4,
                              Text('Pesanan yang telah di-unboxing Apoteker akan muncul di sini', style: TextStyle(color: Colors.grey.shade500, fontSize: 12, fontFamily: 'Poppins')),
                            ],
                          ),
                        ),
                      ],
                    )
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: podReturnListItems,
                    ),
            ),
            // Completed orders tab
            RefreshIndicator(
              onRefresh: () => _fetchDashboardData(showLoading: false),
              color: AppColors.primaryGreen,
              child: completedListItems.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        SizedBox(height: MediaQuery.of(context).size.height * 0.2),
                        Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: const BoxDecoration(
                                  color: Color(0xFFF1F5F9),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(Icons.check_circle_outline_rounded, size: 48, color: Colors.grey.shade400),
                              ),
                              gapH16,
                              const Text('Belum ada riwayat pesanan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.darkGrey, fontFamily: 'Poppins')),
                              gapH4,
                              Text('Riwayat pesanan yang telah selesai akan muncul di sini', style: TextStyle(color: Colors.grey.shade500, fontSize: 12, fontFamily: 'Poppins')),
                            ],
                          ),
                        ),
                      ],
                    )
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: completedListItems,
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------
  // TAB 2: KINETIC EARNINGS CONTENT
  // -------------------------------------------------------------
  Widget _buildPenghasilanContent() {
    if (_isLoading && _dashboardData == null) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primaryGreen));
    }
    final stats = _dashboardData!.stats;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Dompet Penghasilan', style: TextStyle(fontWeight: FontWeight.w800, fontFamily: 'Poppins', fontSize: 18)),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: AppColors.darkGrey,
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: () => _fetchDashboardData(showLoading: false),
        color: const Color(0xFF10B981),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Hero Wallet Balance Card
              Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF10B981), Color(0xFF059669)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF10B981).withValues(alpha: 0.25),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Total Pendapatan Bersih',
                          style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600, fontFamily: 'Poppins'),
                        ),
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.account_balance_wallet_rounded, color: Colors.white, size: 18),
                        ),
                      ],
                    ),
                    gapH8,
                    Text(
                      _formatRupiah(stats.totalEarnings),
                      style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900, fontFamily: 'Poppins', letterSpacing: -0.5),
                    ),
                    const SizedBox(height: 18),
                    Container(height: 1, color: Colors.white.withValues(alpha: 0.2)),
                    const SizedBox(height: 18),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Total Selesai', style: TextStyle(color: Colors.white70, fontSize: 11, fontFamily: 'Poppins')),
                            gapH4,
                            Text(
                              '${stats.totalOrders} Pengantaran',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14, fontFamily: 'Poppins'),
                            ),
                          ],
                        ),
                        Container(width: 1, height: 30, color: Colors.white.withValues(alpha: 0.2)),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Hari Ini', style: TextStyle(color: Colors.white70, fontSize: 11, fontFamily: 'Poppins')),
                            gapH4,
                            Text(
                              _formatRupiah(stats.todayEarnings),
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14, fontFamily: 'Poppins'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              gapH24,
              const Text(
                'Rincian Pembayaran',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.darkGrey, fontFamily: 'Poppins'),
              ),
              gapH12,
              _buildWalletListTile('Pengantaran Sukses', '${stats.totalOrders} Transaksi Selesai', stats.totalEarnings, const Color(0xFF10B981), Icons.check_circle_rounded),
              gapH12,
              _buildWalletListTile('Bonus Target Harian', 'Tercapai', 0.0, const Color(0xFFF59E0B), Icons.stars_rounded),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWalletListTile(String title, String subtitle, double amount, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              gapW16,
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppColors.darkGrey, fontFamily: 'Poppins')),
                  gapH2,
                  Text(subtitle, style: TextStyle(color: Colors.grey.shade500, fontSize: 11, fontFamily: 'Poppins')),
                ],
              ),
            ],
          ),
          Text(
            amount > 0 ? _formatRupiah(amount) : 'Rp 0',
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: AppColors.darkGrey, fontFamily: 'Poppins'),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // TAB 3: KINETIC ACCOUNT PROFILE CONTENT
  // -------------------------------------------------------------
  Widget _buildAkunContent() {
    if (_isLoading && _dashboardData == null) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primaryGreen));
    }
    final driver = _dashboardData!.driver;

    return FutureBuilder<List<String?>>(
      future: Future.wait([ApiService.getName(), ApiService.getEmail()]),
      builder: (context, snapshot) {
        final name = (snapshot.hasData ? snapshot.data![0] : driver.name) ?? driver.name;
        final email = (snapshot.hasData ? snapshot.data![1] : driver.email) ?? driver.email;

        return Scaffold(
          backgroundColor: const Color(0xFFF8FAFC),
          appBar: AppBar(
            title: const Text('Profil Saya', style: TextStyle(fontWeight: FontWeight.w800, fontFamily: 'Poppins', fontSize: 18)),
            centerTitle: true,
            backgroundColor: Colors.white,
            foregroundColor: AppColors.darkGrey,
            elevation: 0,
          ),
          body: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Profile Header Card
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.grey.shade100),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [Color(0xFF10B981), Color(0xFF3B82F6)],
                          ),
                        ),
                        child: _customProfilePicPath != null
                            ? buildProfileImage(_customProfilePicPath, size: 76)
                            : buildProfileImage(
                                null,
                                size: 76,
                                fallbackIcon: _avatarIcons[_userAvatarIndex],
                                fallbackColor: _avatarColors[_userAvatarIndex],
                              ),
                      ),
                      gapH12,
                      Text(
                        name,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, fontFamily: 'Poppins', color: AppColors.darkGrey),
                      ),
                      Text(
                        email,
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 12, fontFamily: 'Poppins'),
                      ),
                      gapH8,
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          driver.role.toUpperCase(),
                          style: const TextStyle(
                            color: Color(0xFF059669),
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            fontFamily: 'Poppins',
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                gapH20,

                // Unified menu container card for settings
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                    border: Border.all(color: Colors.grey.shade100, width: 1),
                  ),
                  child: Column(
                    children: [
                      // Pengaturan Profil
                      _buildDriverProfileMenuRow(
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
                      const Divider(height: 1, indent: 64, endIndent: 20, color: Color(0xFFF1F5F9)),

                      // Keamanan Akun
                      _buildDriverProfileMenuRow(
                        icon: Icons.security_rounded,
                        title: "Keamanan Akun",
                        desc: "Kelola sandi, verifikasi email, & login wajah",
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const AccountSecurityPage()),
                          );
                        },
                      ),
                      const Divider(height: 1, indent: 64, endIndent: 20, color: Color(0xFFF1F5F9)),

                      // Ketentuan Layanan
                      _buildDriverProfileMenuRow(
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
                      const Divider(height: 1, indent: 64, endIndent: 20, color: Color(0xFFF1F5F9)),

                      // Kebijakan Privasi
                      _buildDriverProfileMenuRow(
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
                      const Divider(height: 1, indent: 64, endIndent: 20, color: Color(0xFFF1F5F9)),

                      // Aktivitas Akun
                      _buildDriverProfileMenuRow(
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
                    ],
                  ),
                ),
                gapH20,

                // Logout Card
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _handleLogout,
                    borderRadius: BorderRadius.circular(24),
                    child: Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: AppColors.accentRed.withValues(alpha: 0.25), width: 1.2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.logout_rounded, color: AppColors.accentRed, size: 20),
                          SizedBox(width: 10),
                          Text(
                            "Keluar Akun",
                            style: TextStyle(
                              color: AppColors.accentRed,
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                              fontFamily: 'Poppins',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                gapH32,
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDriverProfileMenuRow({
    required IconData icon,
    required String title,
    required String desc,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFF10B981).withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: const Color(0xFF10B981), size: 20),
      ),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppColors.darkGrey, fontFamily: 'Poppins'),
      ),
      subtitle: Text(
        desc,
        style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontFamily: 'Poppins'),
      ),
      trailing: Icon(Icons.chevron_right_rounded, size: 18, color: Colors.grey.shade400),
      onTap: onTap,
    );
  }
}

class QrMockPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.fill;

    // Corner squares
    void drawFinder(double x, double y) {
      canvas.drawRect(Rect.fromLTWH(x, y, 24, 24), paint);
      paint.color = Colors.white;
      canvas.drawRect(Rect.fromLTWH(x + 4, y + 4, 16, 16), paint);
      paint.color = Colors.black;
      canvas.drawRect(Rect.fromLTWH(x + 8, y + 8, 8, 8), paint);
    }

    drawFinder(0, 0);
    drawFinder(size.width - 24, 0);
    drawFinder(0, size.height - 24);

    // Random QR noise pixels
    paint.color = Colors.black;
    for (int i = 0; i < 15; i++) {
      for (int j = 0; j < 15; j++) {
        // Skip finder areas
        if ((i < 6 && j < 6) || (i > 9 && j < 6) || (i < 6 && j > 9)) continue;
        if ((i * j) % 3 == 0 || (i + j) % 5 == 0) {
          canvas.drawRect(Rect.fromLTWH(i * 6.5, j * 6.5, 5, 5), paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}


