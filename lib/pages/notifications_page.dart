import 'package:flutter/material.dart';
import 'package:apps_k24/services/api_service.dart';
import 'package:apps_k24/theme/app_colors.dart';
import 'package:apps_k24/pages/track_live_page.dart';
import 'package:apps_k24/models/dashboard_data.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  List<dynamic> _notifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
  }

  Future<void> _fetchNotifications() async {
    setState(() => _isLoading = true);
    try {
      final data = await ApiService.getNotifications();
      setState(() {
        _notifications = data;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memuat notifikasi: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _markAllRead() async {
    try {
      await ApiService.markNotificationsRead();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Semua notifikasi ditandai dibaca'), backgroundColor: Colors.green),
        );
      }
      _fetchNotifications();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menandai notifikasi: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _handleNotificationTap(Map<String, dynamic> item) async {
    // Mark notifications read
    try {
      await ApiService.markNotificationsRead();
    } catch (_) {}

    if (!mounted) return;

    // Try to open Track Live page
    try {
      final dashboard = await ApiService.getDashboard();
      OrderModel? matchedOrder;
      
      // Match order number in notification message/title
      final text = '${item['title']} ${item['message']}';
      final reg = RegExp(r'ORD-\d+|#\d+');
      final match = reg.firstMatch(text);

      if (match != null) {
        final foundStr = match.group(0)!.replaceAll('#', '');
        matchedOrder = dashboard.activeOrders.firstWhere(
          (o) => o.orderNumber.contains(foundStr),
          orElse: () => dashboard.recentOrders.firstWhere(
            (o) => o.orderNumber.contains(foundStr),
            orElse: () => dashboard.activeOrders.isNotEmpty
                ? dashboard.activeOrders.first
                : (dashboard.recentOrders.isNotEmpty ? dashboard.recentOrders.first : OrderModel.fromJson({})),
          ),
        );
      }

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => TrackLivePage(initialOrder: matchedOrder?.id != 0 ? matchedOrder : null),
        ),
      );
    } catch (_) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const TrackLivePage()),
      );
    }
  }

  String _formatDateTime(String timestamp) {
    try {
      final date = DateTime.parse(timestamp).toLocal();
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inMinutes < 60) {
        return '${difference.inMinutes} menit yang lalu';
      } else if (difference.inHours < 24) {
        return '${difference.inHours} jam yang lalu';
      } else {
        return '${date.day}/${date.month}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
      }
    } catch (_) {
      return '';
    }
  }

  IconData _getNotificationIcon(String title, String message) {
    final combined = '$title $message'.toLowerCase();
    if (combined.contains('sampai') || combined.contains('tiba') || combined.contains('lokasi')) {
      return Icons.location_on_rounded;
    } else if (combined.contains('selesai') || combined.contains('pod') || combined.contains('terverifikasi')) {
      return Icons.verified_rounded;
    } else if (combined.contains('baru') || combined.contains('tugas') || combined.contains('order')) {
      return Icons.local_shipping_rounded;
    }
    return Icons.notifications_rounded;
  }

  Color _getNotificationColor(String title, String message) {
    final combined = '$title $message'.toLowerCase();
    if (combined.contains('sampai') || combined.contains('tiba')) {
      return const Color(0xFF8B5CF6);
    } else if (combined.contains('selesai') || combined.contains('pod')) {
      return const Color(0xFF10B981);
    } else if (combined.contains('baru') || combined.contains('order')) {
      return const Color(0xFF3B82F6);
    }
    return const Color(0xFFFFB300);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Notifikasi & Update Order',
          style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Poppins', fontSize: 16),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: AppColors.darkGrey,
        elevation: 0.5,
        actions: [
          IconButton(
            icon: const Icon(Icons.radar_rounded, color: Color(0xFF10B981)),
            tooltip: 'Halaman Lacak Live',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const TrackLivePage()),
              );
            },
          ),
          if (_notifications.any((n) => !(n['is_read'] ?? false)))
            IconButton(
              icon: const Icon(Icons.done_all),
              tooltip: 'Tandai Semua Dibaca',
              onPressed: _markAllRead,
            ),
        ],
      ),
      backgroundColor: const Color(0xFFF7F9FC),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF00AA5B)))
          : RefreshIndicator(
              color: const Color(0xFF00AA5B),
              onRefresh: _fetchNotifications,
              child: _notifications.isEmpty
                  ? ListView(
                      children: [
                        SizedBox(height: MediaQuery.of(context).size.height * 0.20),
                        const Icon(
                          Icons.notifications_off_outlined,
                          size: 72,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Belum Ada Notifikasi',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Poppins',
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Semua pemberitahuan tentang tugas pengantaran Anda\nakan muncul di sini.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            fontFamily: 'Poppins',
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Center(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const TrackLivePage()),
                              );
                            },
                            icon: const Icon(Icons.radar_rounded),
                            label: const Text('Buka Halaman Lacak Live', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Poppins')),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF10B981),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    )
                  : ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(16),
                      itemCount: _notifications.length,
                      itemBuilder: (context, index) {
                        final item = Map<String, dynamic>.from(_notifications[index]);
                        final isUnread = !(item['is_read'] ?? false);
                        final title = item['title'] ?? '';
                        final message = item['message'] ?? '';
                        final icon = _getNotificationIcon(title, message);
                        final color = _getNotificationColor(title, message);

                        return Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => _handleNotificationTap(item),
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.03),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                                border: isUnread
                                    ? Border.all(color: color.withOpacity(0.4), width: 1.5)
                                    : Border.all(color: Colors.grey.shade200, width: 0.8),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: IntrinsicHeight(
                                  child: Row(
                                    children: [
                                      // Left colored accent indicator for unread notifications
                                      Container(
                                        width: 6,
                                        color: isUnread ? color : Colors.grey.shade300,
                                      ),
                                      Expanded(
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
                                          child: Row(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.all(10),
                                                decoration: BoxDecoration(
                                                  color: color.withOpacity(0.12),
                                                  shape: BoxShape.circle,
                                                ),
                                                child: Icon(icon, color: color, size: 20),
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Row(
                                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                      children: [
                                                        Expanded(
                                                          child: Text(
                                                            title,
                                                            style: TextStyle(
                                                              fontWeight: isUnread ? FontWeight.bold : FontWeight.w600,
                                                              fontSize: 14,
                                                              fontFamily: 'Poppins',
                                                              color: isUnread ? Colors.black : Colors.grey.shade800,
                                                            ),
                                                          ),
                                                        ),
                                                        if (isUnread)
                                                          Container(
                                                            width: 8,
                                                            height: 8,
                                                            decoration: BoxDecoration(
                                                              color: color,
                                                              shape: BoxShape.circle,
                                                            ),
                                                          ),
                                                      ],
                                                    ),
                                                    const SizedBox(height: 6),
                                                    Text(
                                                      message,
                                                      style: TextStyle(
                                                        fontSize: 12.5,
                                                        fontFamily: 'Poppins',
                                                        color: Colors.grey.shade600,
                                                        height: 1.35,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 10),
                                                    Row(
                                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                      children: [
                                                        Text(
                                                          _formatDateTime(item['created_at'] ?? ''),
                                                          style: TextStyle(
                                                            fontSize: 10,
                                                            fontFamily: 'Poppins',
                                                            color: Colors.grey.shade400,
                                                            fontWeight: FontWeight.w500,
                                                          ),
                                                        ),
                                                        Text(
                                                          'Lihat Laporan ➔',
                                                          style: TextStyle(
                                                            fontSize: 11,
                                                            fontFamily: 'Poppins',
                                                            color: color,
                                                            fontWeight: FontWeight.bold,
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
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}
