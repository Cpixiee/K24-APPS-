import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:apps_k24/theme/app_colors.dart';
import 'package:apps_k24/theme/gaps.dart';
import 'package:apps_k24/services/api_service.dart';
import 'package:apps_k24/models/dashboard_data.dart';
import 'package:apps_k24/pages/verifikasi_pod_page.dart';
import 'package:apps_k24/pages/detail_pesanan_page.dart';

class TrackLivePage extends StatefulWidget {
  final OrderModel? initialOrder;
  const TrackLivePage({super.key, this.initialOrder});

  @override
  State<TrackLivePage> createState() => _TrackLivePageState();
}

class _TrackLivePageState extends State<TrackLivePage> {
  OrderModel? _selectedOrder;
  List<OrderModel> _allOrders = [];
  bool _isLoading = true;
  final MapController _mapController = MapController();
  List<LatLng> _routePoints = [];
  bool _loadingRoute = false;

  @override
  void initState() {
    super.initState();
    _fetchDashboardAndOrders();
  }

  Future<void> _fetchDashboardAndOrders() async {
    setState(() => _isLoading = true);
    try {
      final dashboard = await ApiService.getDashboard();
      final combined = <OrderModel>[];
      combined.addAll(dashboard.activeOrders);
      for (final r in dashboard.recentOrders) {
        if (!combined.any((o) => o.id == r.id)) {
          combined.add(r);
        }
      }

      setState(() {
        _allOrders = combined;
        if (widget.initialOrder != null) {
          final found = combined.firstWhere(
            (o) => o.id == widget.initialOrder!.id,
            orElse: () => widget.initialOrder!,
          );
          _selectedOrder = found;
        } else if (combined.isNotEmpty) {
          _selectedOrder = combined.first;
        }
      });

      if (_selectedOrder != null) {
        _fetchRoute();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memuat data live tracking: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _fetchRoute() async {
    if (_selectedOrder == null) return;
    setState(() => _loadingRoute = true);

    final start = LatLng(_selectedOrder!.pharmacyLat, _selectedOrder!.pharmacyLng);
    final end = LatLng(_selectedOrder!.customerLat, _selectedOrder!.customerLng);

    try {
      final url = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/'
        '${start.longitude},${start.latitude};${end.longitude},${end.latitude}'
        '?overview=full&geometries=geojson',
      );
      final response = await http.get(url).timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final coords = data['routes'][0]['geometry']['coordinates'] as List;
        if (mounted) {
          setState(() {
            _routePoints = coords.map((c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble())).toList();
            _loadingRoute = false;
          });
          _fitBounds(start, end);
        }
        return;
      }
    } catch (_) {}

    if (mounted) {
      setState(() {
        _routePoints = [start, end];
        _loadingRoute = false;
      });
      _fitBounds(start, end);
    }
  }

  void _fitBounds(LatLng start, LatLng end) {
    try {
      final bounds = LatLngBounds.fromPoints([start, end]);
      _mapController.fitCamera(CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(40)));
    } catch (_) {}
  }

  int _getStatusStep(String status) {
    switch (status.toUpperCase()) {
      case 'PICKING_UP':
      case 'READY_FOR_PICKUP_FACTURE':
        return 1;
      case 'DELIVERING':
        return 2;
      case 'ARRIVED':
      case 'ARRIVED_AT_LOCATION':
        return 3;
      case 'COMPLETED':
        return 4;
      default:
        return 0;
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'PICKING_UP':
      case 'READY_FOR_PICKUP_FACTURE':
        return Colors.orange;
      case 'DELIVERING':
        return const Color(0xFF3B82F6);
      case 'ARRIVED':
      case 'ARRIVED_AT_LOCATION':
        return const Color(0xFF8B5CF6);
      case 'COMPLETED':
        return const Color(0xFF10B981);
      default:
        return Colors.grey;
    }
  }

  String _getStatusTitle(String status) {
    switch (status.toUpperCase()) {
      case 'PICKING_UP':
      case 'READY_FOR_PICKUP_FACTURE':
        return 'Penjemputan di Apotek';
      case 'DELIVERING':
        return 'Kurir Dalam Pengantaran';
      case 'ARRIVED':
      case 'ARRIVED_AT_LOCATION':
        return 'Tiba di Lokasi Penerima';
      case 'COMPLETED':
        return 'Pesanan Selesai (POD Terverifikasi)';
      default:
        return 'Menunggu Proses';
    }
  }

  void _shareReport() {
    if (_selectedOrder == null) return;
    final order = _selectedOrder!;
    final report = '''
📌 LAPORAN TRACKING PENGIRIMAN K-24 APPS
----------------------------------------
No. Order: ${order.orderNumber}
Status: ${_getStatusTitle(order.status)}
Apotek Asal: ${order.pharmacyName}
Penerima: ${order.customerName}
Alamat Tujuan: ${order.deliveryAddress}
Ringkasan Item: ${order.medicineSummary}
----------------------------------------
Dipantau secara Real-time di Aplikasi K-24 Driver.
''';
    Share.share(report);
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Lacak Live & Laporan Order',
          style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Poppins', fontSize: 16),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: AppColors.darkGrey,
        elevation: 0.5,
        actions: [
          IconButton(
            icon: const Icon(Icons.share_rounded),
            tooltip: 'Bagikan Laporan',
            onPressed: _selectedOrder != null ? _shareReport : null,
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Perbarui Data',
            onPressed: _fetchDashboardAndOrders,
          ),
        ],
      ),
      backgroundColor: const Color(0xFFF8FAFC),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF10B981)))
          : _allOrders.isEmpty
              ? _buildEmptyView()
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // 1. Selector dropdown if multiple orders exist
                      _buildOrderSelector(),
                      gapH16,

                      if (_selectedOrder != null) ...[
                        // 2. Status Banner Header
                        _buildStatusHeaderCard(_selectedOrder!),
                        gapH16,

                        // 3. Live Stepper Progress Tracker
                        _buildLiveStepperCard(_selectedOrder!),
                        gapH16,

                        // 4. Interactive Live Route Map
                        _buildLiveMapCard(_selectedOrder!),
                        gapH16,

                        // 5. Timeline Event Logs & Reports
                        _buildTimelineLogsCard(_selectedOrder!),
                        gapH16,

                        // 6. Delivery Detail & POD Info
                        _buildDeliveryDetailsCard(_selectedOrder!),
                        gapH24,
                      ],
                    ],
                  ),
                ),
    );
  }

  Widget _buildEmptyView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.location_off_rounded, size: 72, color: Colors.grey.shade400),
          gapH16,
          const Text(
            'Belum Ada Order Aktif',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Poppins'),
          ),
          gapH8,
          Text(
            'Saat Anda mengambil atau mengantar pesanan,\nlaporan tracking live akan muncul di sini secara real-time.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13, fontFamily: 'Poppins'),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: _selectedOrder?.id,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF10B981)),
          items: _allOrders.map((order) {
            final isCompleted = order.status == 'COMPLETED';
            return DropdownMenuItem<int>(
              value: order.id,
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _getStatusColor(order.status),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${order.orderNumber} - ${order.pharmacyName}',
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: isCompleted ? Colors.green.shade50 : Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      isCompleted ? 'SELESAI' : 'AKTIF',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: isCompleted ? Colors.green.shade700 : Colors.blue.shade700,
                        fontFamily: 'Poppins',
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
          onChanged: (id) {
            if (id == null) return;
            setState(() {
              _selectedOrder = _allOrders.firstWhere((o) => o.id == id);
            });
            _fetchRoute();
          },
        ),
      ),
    );
  }

  Widget _buildStatusHeaderCard(OrderModel order) {
    final color = _getStatusColor(order.status);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, color.withValues(alpha: 0.85)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.3),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.radar_rounded, color: Colors.white, size: 14),
                    SizedBox(width: 6),
                    Text(
                      'LIVE TRACKING',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                        fontFamily: 'Poppins',
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                order.orderNumber,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  fontFamily: 'Poppins',
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            _getStatusTitle(order.status),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 18,
              fontFamily: 'Poppins',
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Tujuan: ${order.customerName} (${order.deliveryAddress})',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 12,
              fontFamily: 'Poppins',
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildLiveStepperCard(OrderModel order) {
    final currentStep = _getStatusStep(order.status);

    Widget buildStepItem(int stepIndex, String label, IconData icon) {
      final isDone = currentStep >= stepIndex;
      final isCurrent = currentStep == stepIndex;

      return Expanded(
        child: Column(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDone ? const Color(0xFF10B981) : Colors.grey.shade200,
                boxShadow: isCurrent
                    ? [
                        BoxShadow(
                          color: const Color(0xFF10B981).withValues(alpha: 0.4),
                          blurRadius: 10,
                          spreadRadius: 2,
                        )
                      ]
                    : null,
              ),
              child: Icon(
                icon,
                size: 18,
                color: isDone ? Colors.white : Colors.grey.shade500,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isDone ? FontWeight.bold : FontWeight.w500,
                color: isDone ? AppColors.darkGrey : Colors.grey.shade500,
                fontFamily: 'Poppins',
              ),
              maxLines: 2,
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Progres Pengiriman',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, fontFamily: 'Poppins'),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              buildStepItem(1, 'Apotek', Icons.storefront_rounded),
              Container(
                height: 2,
                width: 24,
                color: currentStep >= 2 ? const Color(0xFF10B981) : Colors.grey.shade300,
              ),
              buildStepItem(2, 'Pengantaran', Icons.two_wheeler_rounded),
              Container(
                height: 2,
                width: 24,
                color: currentStep >= 3 ? const Color(0xFF10B981) : Colors.grey.shade300,
              ),
              buildStepItem(3, 'Tiba Alamat', Icons.location_on_rounded),
              Container(
                height: 2,
                width: 24,
                color: currentStep >= 4 ? const Color(0xFF10B981) : Colors.grey.shade300,
              ),
              buildStepItem(4, 'POD Selesai', Icons.verified_rounded),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLiveMapCard(OrderModel order) {
    final start = LatLng(order.pharmacyLat, order.pharmacyLng);
    final end = LatLng(order.customerLat, order.customerLng);

    return Container(
      height: 260,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: start,
                initialZoom: 13.5,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.k24.apps',
                ),
                if (_routePoints.isNotEmpty)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: _routePoints,
                        strokeWidth: 4.5,
                        color: const Color(0xFF10B981),
                      ),
                    ],
                  ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: start,
                      width: 40,
                      height: 40,
                      child: const Icon(Icons.storefront_rounded, color: Colors.blue, size: 36),
                    ),
                    Marker(
                      point: end,
                      width: 40,
                      height: 40,
                      child: const Icon(Icons.location_on_rounded, color: Colors.red, size: 38),
                    ),
                  ],
                ),
              ],
            ),

            if (_loadingRoute)
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 6),
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF10B981)),
                      ),
                      SizedBox(width: 8),
                      Text('Memuat rute...', style: TextStyle(fontSize: 10, fontFamily: 'Poppins')),
                    ],
                  ),
                ),
              ),

            Positioned(
              bottom: 12,
              right: 12,
              child: FloatingActionButton.small(
                heroTag: 'recenter_live_map',
                backgroundColor: Colors.white,
                foregroundColor: AppColors.darkGrey,
                onPressed: () => _fitBounds(start, end),
                child: const Icon(Icons.my_location_rounded),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineLogsCard(OrderModel order) {
    final List<Map<String, String>> logs = [
      {
        'time': '${order.createdAt.hour.toString().padLeft(2, '0')}:${order.createdAt.minute.toString().padLeft(2, '0')}',
        'title': 'Pesanan Diterbitkan',
        'desc': 'Order #${order.orderNumber} diterima di sistem apotek ${order.pharmacyName}',
        'icon': '1',
      },
      {
        'time': '${order.createdAt.add(const Duration(minutes: 5)).hour.toString().padLeft(2, '0')}:${order.createdAt.add(const Duration(minutes: 5)).minute.toString().padLeft(2, '0')}',
        'title': 'Driver Menuju Apotek',
        'desc': 'Penjemputan pesanan di lokasi apotek',
        'icon': '2',
      },
      if (order.status == 'DELIVERING' || order.status == 'ARRIVED' || order.status == 'COMPLETED')
        {
          'time': '${order.createdAt.add(const Duration(minutes: 15)).hour.toString().padLeft(2, '0')}:${order.createdAt.add(const Duration(minutes: 15)).minute.toString().padLeft(2, '0')}',
          'title': 'Dalam Pengantaran Kurir',
          'desc': 'Faktur fisik diperiksa, kurir menuju alamat ${order.customerName}',
          'icon': '3',
        },
      if (order.status == 'ARRIVED' || order.status == 'COMPLETED')
        {
          'time': '${order.createdAt.add(const Duration(minutes: 30)).hour.toString().padLeft(2, '0')}:${order.createdAt.add(const Duration(minutes: 30)).minute.toString().padLeft(2, '0')}',
          'title': 'Tiba di Lokasi Tujuan',
          'desc': 'Kurir telah sampai di ${order.deliveryAddress}',
          'icon': '4',
        },
      if (order.status == 'COMPLETED')
        {
          'time': order.completedAt != null
              ? '${order.completedAt!.hour.toString().padLeft(2, '0')}:${order.completedAt!.minute.toString().padLeft(2, '0')}'
              : '${order.createdAt.add(const Duration(minutes: 40)).hour.toString().padLeft(2, '0')}:${order.createdAt.add(const Duration(minutes: 40)).minute.toString().padLeft(2, '0')}',
          'title': 'Laporan Pengiriman Selesai',
          'desc': 'Bukti POD & Tanda tangan penerima berhasil diverifikasi',
          'icon': '5',
        },
    ];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.history_toggle_off_rounded, color: Color(0xFF10B981), size: 20),
              SizedBox(width: 8),
              Text(
                'Laporan Log Aktivitas Real-time',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, fontFamily: 'Poppins'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Column(
            children: logs.map((log) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        log['time']!,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade700,
                          fontFamily: 'Poppins',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            log['title']!,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              fontFamily: 'Poppins',
                              color: AppColors.darkGrey,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            log['desc']!,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                              fontFamily: 'Poppins',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildDeliveryDetailsCard(OrderModel order) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Detail Penerima & Tindakan Cepat',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, fontFamily: 'Poppins'),
          ),
          const SizedBox(height: 14),

          // Customer info row
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(
              backgroundColor: const Color(0xFF10B981).withValues(alpha: 0.1),
              child: const Icon(Icons.person, color: Color(0xFF10B981)),
            ),
            title: Text(
              order.customerName,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, fontFamily: 'Poppins'),
            ),
            subtitle: Text(
              order.customerPhone.isNotEmpty ? order.customerPhone : 'No Hp Tidak Tersedia',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontFamily: 'Poppins'),
            ),
            trailing: order.customerPhone.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.phone_in_talk_rounded, color: Color(0xFF10B981)),
                    onPressed: () => _makePhoneCall(order.customerPhone),
                  )
                : null,
          ),

          const Divider(),
          const SizedBox(height: 8),

          // Medicines
          Text(
            'Ringkasan Obatan/Barang:',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade700, fontFamily: 'Poppins'),
          ),
          const SizedBox(height: 4),
          Text(
            order.medicineSummary,
            style: const TextStyle(fontSize: 12.5, fontFamily: 'Poppins', color: AppColors.darkGrey),
          ),
          const SizedBox(height: 16),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => DetailPesananPage(order: order)),
                    );
                  },
                  icon: const Icon(Icons.assignment_outlined, size: 18),
                  label: const Text('Detail Order', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'Poppins')),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.darkGrey,
                    side: BorderSide(color: Colors.grey.shade300),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              if (order.status != 'COMPLETED')
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => VerifikasiPODPage(order: order)),
                      );
                    },
                    icon: const Icon(Icons.camera_alt_rounded, size: 18),
                    label: const Text('Verifikasi POD', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'Poppins')),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                )
              else
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.green.shade300),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle_rounded, color: Colors.green.shade700, size: 18),
                        const SizedBox(width: 6),
                        Text(
                          'POD Terverifikasi',
                          style: TextStyle(
                            color: Colors.green.shade700,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            fontFamily: 'Poppins',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
