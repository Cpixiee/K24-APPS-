import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:apps_k24/theme/app_colors.dart';
import 'package:apps_k24/theme/gaps.dart';
import 'package:apps_k24/services/api_service.dart';
import 'package:apps_k24/models/dashboard_data.dart';
import 'package:apps_k24/pages/verifikasi_invoice_page.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:apps_k24/pages/verifikasi_pod_page.dart';
import 'package:apps_k24/utils/watermark_helper.dart';

class DetailPesananPage extends StatefulWidget {
  final OrderModel order;
  const DetailPesananPage({super.key, required this.order});

  @override
  State<DetailPesananPage> createState() => _DetailPesananPageState();
}

class _DetailPesananPageState extends State<DetailPesananPage> {
  final ImagePicker _picker = ImagePicker();
  late OrderModel _currentOrder;
  bool _isLoading = false;
  String _driverName = 'Driver K-24';
  
  // Map parameters
  final MapController _mapController = MapController();
  List<LatLng> _routePoints = [];
  bool _loadingRoute = false;
  List<OrderModel> _allActiveOrders = [];

  @override
  void initState() {
    super.initState();
    _currentOrder = widget.order;
    _fetchRoute();
    _loadInitialActiveOrders();
  }

  Future<void> _loadInitialActiveOrders() async {
    try {
      final dashboard = await ApiService.getDashboard();
      if (mounted) {
        setState(() {
          _allActiveOrders = dashboard.activeOrders;
          if (dashboard.driver.name.isNotEmpty) {
            _driverName = dashboard.driver.name;
          }
        });
      }
    } catch (_) {}
  }

  List<OrderModel> get _batchStops {
    if (_allActiveOrders.isEmpty) return [_currentOrder];
    
    final siblings = _allActiveOrders.where((o) {
      if (_currentOrder.dispatchId.isNotEmpty && o.dispatchId.isNotEmpty) {
        return o.dispatchId == _currentOrder.dispatchId;
      }
      if (_currentOrder.parentOrderNumber.isNotEmpty && o.parentOrderNumber.isNotEmpty) {
        return o.parentOrderNumber == _currentOrder.parentOrderNumber;
      }
      return o.id == _currentOrder.id;
    }).toList();

    return siblings.isNotEmpty ? siblings : [_currentOrder];
  }

  int get _currentStopIndex {
    final stops = _batchStops;
    final idx = stops.indexWhere((s) => s.id == _currentOrder.id);
    return idx >= 0 ? idx : 0;
  }

  OrderModel? get _nextUncompletedStop {
    if (_allActiveOrders.isEmpty) return null;
    for (final o in _allActiveOrders) {
      if (o.id == _currentOrder.id) continue;
      final bool isSameBatch = (_currentOrder.dispatchId.isNotEmpty && o.dispatchId.isNotEmpty && o.dispatchId == _currentOrder.dispatchId) ||
          (_currentOrder.parentOrderNumber.isNotEmpty && o.parentOrderNumber.isNotEmpty && o.parentOrderNumber == _currentOrder.parentOrderNumber);
      if (isSameBatch && o.status != 'COMPLETED' && o.status != 'CANCELLED' && o.status != 'READY_FOR_PICKUP_FACTURE') {
        return o;
      }
    }
    return null;
  }

  Future<void> _refreshOrderDetails() async {
    setState(() => _isLoading = true);
    try {
      final dashboard = await ApiService.getDashboard();
      if (mounted) {
        setState(() {
          _allActiveOrders = dashboard.activeOrders;
        });
      }
      // Find this order in either active or recent list
      OrderModel? found;
      for (var o in dashboard.activeOrders) {
        if (o.id == _currentOrder.id) {
          found = o;
          break;
        }
      }
      if (found == null) {
        for (var o in dashboard.recentOrders) {
          if (o.id == _currentOrder.id) {
            found = o;
            break;
          }
        }
      }

      // If current order is now completed/unboxed, automatically advance to next uncompleted stop
      if (found != null && (found.status == 'READY_FOR_PICKUP_FACTURE' || found.status == 'COMPLETED')) {
        final next = _nextUncompletedStop;
        if (next != null) {
          found = next;
        }
      }

      if (found != null && mounted) {
        setState(() {
          _currentOrder = found!;
        });
        _fetchRoute();
      }
    } catch (e) {
      debugPrint('Error refreshing order details: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchRoute() async {
    setState(() {
      _loadingRoute = true;
    });

    final startLat = _currentOrder.pharmacyLat;
    final startLng = _currentOrder.pharmacyLng;
    final endLat = _currentOrder.customerLat;
    final endLng = _currentOrder.customerLng;

    final url = 'https://router.project-osrm.org/route/v1/driving/$startLng,$startLat;$endLng,$endLat?overview=full&geometries=geojson';
    try {
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final routes = data['routes'] as List;
        if (routes.isNotEmpty) {
          final geometry = routes[0]['geometry'];
          final coordinates = geometry['coordinates'] as List;
          final points = coordinates.map((c) => LatLng(c[1].toDouble(), c[0].toDouble())).toList();
          if (mounted) {
            setState(() {
              _routePoints = points;
            });
            WidgetsBinding.instance.addPostFrameCallback((_) => _fitMapBounds());
            return;
          }
        }
      }
    } catch (e) {
      debugPrint('Error fetching OSRM route: $e');
    }

    // Fallback to straight line if OSRM fails
    if (mounted) {
      setState(() {
        _routePoints = [
          LatLng(startLat, startLng),
          LatLng(endLat, endLng),
        ];
        _loadingRoute = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => _fitMapBounds());
    }
  }

  void _fitMapBounds() {
    if (_routePoints.isEmpty) return;
    try {
      final bounds = LatLngBounds.fromPoints(_routePoints);
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: bounds,
          padding: const EdgeInsets.only(top: 40, bottom: 40, left: 40, right: 40),
        ),
      );
    } catch (e) {
      debugPrint('Error fitting map camera bounds: $e');
    }
  }

  Future<void> _launchUrl(String urlString) async {
    final Uri url = Uri.parse(urlString);
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Tidak dapat membuka navigasi: $urlString')),
          );
        }
      }
    } catch (e) {
      debugPrint('Error launching url: $e');
    }
  }

  Future<void> _launchMap(double lat, double lng, {double? originLat, double? originLng}) async {
    String nativeUrl = '';
    String webUrl = '';
    
    try {
      if (Platform.isAndroid) {
        if (originLat != null && originLng != null) {
          nativeUrl = 'google.navigation:q=$lat,$lng&mode=d';
        } else {
          nativeUrl = 'geo:$lat,$lng?q=$lat,$lng';
        }
        webUrl = originLat != null && originLng != null
            ? 'https://www.google.com/maps/dir/?api=1&origin=$originLat,$originLng&destination=$lat,$lng&travelmode=driving'
            : 'https://www.google.com/maps/search/?api=1&query=$lat,$lng';
      } else {
        if (originLat != null && originLng != null) {
          nativeUrl = 'http://maps.apple.com/?saddr=$originLat,$originLng&daddr=$lat,$lng&dirflg=d';
        } else {
          nativeUrl = 'http://maps.apple.com/?q=$lat,$lng';
        }
        webUrl = originLat != null && originLng != null
            ? 'https://www.google.com/maps/dir/?api=1&origin=$originLat,$originLng&destination=$lat,$lng&travelmode=driving'
            : 'https://maps.apple.com/?q=$lat,$lng';
      }
    } catch (_) {
      webUrl = 'https://www.google.com/maps/search/?api=1&query=$lat,$lng';
    }

    final Uri nativeUri = Uri.parse(nativeUrl.isNotEmpty ? nativeUrl : webUrl);
    final Uri webUri = Uri.parse(webUrl);

    try {
      if (nativeUrl.isNotEmpty && await canLaunchUrl(nativeUri)) {
        await launchUrl(nativeUri, mode: LaunchMode.externalNonBrowserApplication);
      } else {
        await launchUrl(webUri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('Error launching map: $e');
      try {
        await launchUrl(webUri, mode: LaunchMode.externalApplication);
      } catch (err) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Tidak dapat membuka peta navigasi: $err')),
          );
        }
      }
    }
  }

  Future<String?> _pickAndGetBase64({String? locationText}) async {
    try {
      XFile? image;
      try {
        image = await _picker.pickImage(
          source: ImageSource.camera,
          imageQuality: 70,
          maxWidth: 1024,
        );
      } catch (e) {
        debugPrint('[Camera Fallback] Camera unavailable, using gallery: $e');
        image = await _picker.pickImage(
          source: ImageSource.gallery,
          imageQuality: 70,
          maxWidth: 1024,
        );
      }

      if (image != null) {
        final bytes = await File(image.path).readAsBytes();
        final rawBase64 = 'data:image/jpeg;base64,${base64Encode(bytes)}';
        final driverName = _driverName.isNotEmpty ? _driverName : 'Driver K-24';
        final loc = (locationText != null && locationText.trim().isNotEmpty)
            ? locationText
            : (_currentOrder.pharmacyName.isNotEmpty ? _currentOrder.pharmacyName : 'Gudang K-24 Matraman');
        return await WatermarkHelper.addWatermarkToBase64(
          base64Image: rawBase64,
          driverName: driverName,
          locationText: loc,
          titleText: 'K-24 BUKTI PICKUP GUDANG',
        );
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
    }
    return null;
  }

  Future<void> _sendWhatsAppPickupReport({
    required String pickupPhotoBase64,
    required String pickupNote,
  }) async {
    final now = DateTime.now();
    final dateStr = '${now.day}/${now.month}/${now.year}';
    final pickupTimeStr = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')} WIB';
    final driverName = _driverName.isNotEmpty ? _driverName : 'Driver K-24';
    final totalStops = _batchStops.isNotEmpty ? _batchStops.length : 1;
    final noteText = pickupNote.trim().isNotEmpty ? pickupNote.trim() : 'Barang sudah diambil dari Gudang K-24';

    final message = '''K24 JAKARTA
LAPORAN PICKUP GUDANG
Tanggal: $dateStr
Jam pickup: $pickupTimeStr
Nama driver: $driverName
Jumlah alamat: $totalStops Apotek
Catatan: $noteText''';

    // 1. First, attempt to share the Watermarked Pickup Photo as media attachment with caption via Share.shareXFiles
    try {
      if (pickupPhotoBase64.isNotEmpty) {
        final cleanBase64 = pickupPhotoBase64.contains(',')
            ? pickupPhotoBase64.split(',')[1]
            : pickupPhotoBase64;
        final bytes = base64Decode(cleanBase64);
        final tempDir = await getTemporaryDirectory();
        final tempFile = File('${tempDir.path}/bukti_pickup_gudang.jpg');
        await tempFile.writeAsBytes(bytes);

        if (await tempFile.exists()) {
          final xFile = XFile(tempFile.path);
          await Share.shareXFiles(
            [xFile],
            text: message,
            subject: 'K24 JAKARTA LAPORAN PICKUP GUDANG',
          );
          return;
        }
      }
    } catch (e) {
      debugPrint('[WA Pickup Share] Could not share pickup image file: $e');
    }

    // 2. Fallback to direct url_launcher wa.me link
    const waNumber = '6287877807780';
    final encodedMessage = Uri.encodeComponent(message);
    final waUrl = Uri.parse('https://wa.me/$waNumber?text=$encodedMessage');

    try {
      if (await canLaunchUrl(waUrl)) {
        await launchUrl(waUrl, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(waUrl, mode: LaunchMode.externalNonBrowserApplication);
      }
    } catch (e) {
      debugPrint('[WA Pickup] Failed to launch WhatsApp: $e');
    }
  }

  void _showPickupModal() {
    final noteController = TextEditingController();
    bool modalLoading = false;
    final List<String> photos = [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) => Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Konfirmasi Pickup Barang',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'Poppins'),
                    ),
                    if (photos.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primaryGreen.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${photos.length} Foto Terpilih',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primaryGreen, fontFamily: 'Poppins'),
                        ),
                      ),
                  ],
                ),
                gapH16,
                
                // Photo List & Add Button
                if (photos.isEmpty)
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 80),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () async {
                      final img = await _pickAndGetBase64(
                        locationText: _currentOrder.pharmacyName.isNotEmpty ? _currentOrder.pharmacyName : 'Gudang K-24 Matraman',
                      );
                      if (img != null) {
                        setModalState(() {
                          photos.add(img);
                        });
                      }
                    },
                    icon: const Icon(Icons.camera_alt_outlined),
                    label: const Text('Ambil Foto Bukti Pickup (Wajib)', style: TextStyle(fontFamily: 'Poppins')),
                  )
                else
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        height: 110,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: photos.length + (photos.length < 6 ? 1 : 0),
                          separatorBuilder: (_, __) => const SizedBox(width: 10),
                          itemBuilder: (context, idx) {
                            if (idx < photos.length) {
                              final p = photos[idx];
                              return Stack(
                                children: [
                                  Container(
                                    width: 110,
                                    height: 110,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: Colors.grey.shade300),
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: Image.memory(
                                        base64Decode(p.split(',')[1]),
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    top: 4,
                                    right: 4,
                                    child: GestureDetector(
                                      onTap: () => setModalState(() => photos.removeAt(idx)),
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: const BoxDecoration(
                                          color: Colors.black54,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(Icons.close, color: Colors.white, size: 14),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            }
                            return GestureDetector(
                              onTap: () async {
                                final img = await _pickAndGetBase64(
                                  locationText: _currentOrder.pharmacyName.isNotEmpty ? _currentOrder.pharmacyName : 'Gudang K-24 Matraman',
                                );
                                if (img != null) {
                                  setModalState(() => photos.add(img));
                                }
                              },
                              child: Container(
                                width: 110,
                                height: 110,
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppColors.primaryGreen, style: BorderStyle.solid, width: 1.5),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: const [
                                    Icon(Icons.add_a_photo_outlined, color: AppColors.primaryGreen, size: 26),
                                    SizedBox(height: 4),
                                    Text('+ Foto Lagi', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primaryGreen, fontFamily: 'Poppins')),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text('Bisa menambah hingga 6 foto bukti pickup.', style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontFamily: 'Poppins')),
                    ],
                  ),

                gapH12,
                TextField(
                  controller: noteController,
                  decoration: InputDecoration(
                    labelText: 'Catatan Pickup (Opsional)',
                    labelStyle: const TextStyle(fontFamily: 'Poppins', fontSize: 13),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  maxLines: 2,
                ),
                gapH20,
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 50),
                  ),
                  onPressed: modalLoading || photos.isEmpty ? null : () async {
                    setModalState(() => modalLoading = true);
                    try {
                      final payload = photos.length == 1 ? photos[0] : jsonEncode(photos);
                      await ApiService.updateOrderPickup(
                        orderId: _currentOrder.id,
                        pickupPhoto: payload,
                        pickupNote: noteController.text,
                      );
                      if (mounted) {
                        Navigator.pop(context);
                        await _sendWhatsAppPickupReport(
                          pickupPhotoBase64: photos.first,
                          pickupNote: noteController.text,
                        );
                        await _refreshOrderDetails();
                      }
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal: $e'), backgroundColor: Colors.red));
                    } finally {
                      setModalState(() => modalLoading = false);
                    }
                  },
                  child: modalLoading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Konfirmasi & Mulai Pengiriman', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Poppins')),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showQrDialog() async {
    // Pastikan IP LAN server terupdate dari backend sebelum QR digenerate
    await ApiService.fetchServerLanIp();

    // Ambil host dari baseUrl backend (misal http://192.168.8.15:8087/api → http://192.168.8.15)
    // lalu arahkan ke port 3000 tempat Next.js web berjalan
    String backendBase = ApiService.baseUrl
        .replaceAll('/api', '')
        .replaceAll(RegExp(r':\d+$'), ''); // hapus port backend

    // Jika host adalah internal localhost/emulator (10.0.2.2 atau localhost)
    // dan kita berhasil mendeteksi IP LAN server laptop, gunakan IP LAN laptop
    // agar HP fisik yang melakukan scan QR bisa mengakses website tersebut.
    if ((backendBase.contains('10.0.2.2') || backendBase.contains('localhost')) &&
        ApiService.serverLanIp != null) {
      backendBase = 'http://${ApiService.serverLanIp}';
    }

    final webPort = backendBase.contains('103.236.140.19') ? '9002' : '3000';
    final webBase = '$backendBase:$webPort';
    final qrUrl = '$webBase/apoteker/unbox/${_currentOrder.id}';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('QR Code Verifikasi Apotek', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Poppins')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 160,
              height: 160,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300, width: 2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: QrImageView(
                data: qrUrl,
                version: QrVersions.auto,
                size: 140,
              ),
            ),
            gapH16,
            const Text(
              'Apoteker memindai kode ini untuk mulai mencocokkan invoice unboxing.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey, height: 1.4),
            ),
            gapH12,
            const Text('Link Manual Apoteker:', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
            SelectableText(
              qrUrl,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11, color: AppColors.secondaryBlue, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _refreshOrderDetails();
            },
            child: const Text('Segarkan Status'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }

  void _showFactureModal() async {
    final res = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VerifikasiInvoicePage(
          order: _currentOrder,
          batchStops: _batchStops,
        ),
      ),
    );
    if (res != null && mounted) {
      if (res is OrderModel) {
        setState(() {
          _currentOrder = res;
          _routePoints = [];
        });
        await _refreshOrderDetails();
        _promptNextStopVerification(res);
      } else {
        await _refreshOrderDetails();
      }
    }
  }

  void _promptNextStopVerification(OrderModel nextStop) {
    final targetName = nextStop.customerName.isNotEmpty ? nextStop.customerName : nextStop.pharmacyName;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 16),
              const Icon(Icons.location_on_rounded, color: AppColors.primaryGreen, size: 36),
              const SizedBox(height: 10),
              Text(
                'Lanjut ke Titik Berikutnya ($targetName)',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, fontFamily: 'Poppins'),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                nextStop.deliveryAddress,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontFamily: 'Poppins'),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () {
                  Navigator.pop(context);
                  _showFactureModal();
                },
                icon: const Icon(Icons.assignment_turned_in_rounded),
                label: Text(
                  'Langsung Verifikasi Invoice ($targetName)',
                  style: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Lihat Peta / Detail Dulu', style: TextStyle(fontFamily: 'Poppins', fontSize: 12)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatRupiah(double val) {
    return 'Rp ${val.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}';
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'WAITING_FOR_PICKUP':
        return AppColors.primaryGreen;
      case 'DELIVERING':
        return AppColors.secondaryBlue;
      case 'READY_FOR_PICKUP_FACTURE':
        return Colors.orange.shade700;
      case 'PENDING':
        return Colors.blue.shade700;
      case 'COMPLETED_WAITING_APPROVAL':
        return Colors.purple.shade700;
      case 'REJECTED_WAITING_APPROVAL':
        return Colors.red.shade900;
      case 'COMPLETED':
        return Colors.green.shade800;
      case 'CANCELLED':
        return Colors.red.shade700;
      default:
        return Colors.grey;
    }
  }

  Widget _buildMap() {
    final startLat = _currentOrder.pharmacyLat;
    final startLng = _currentOrder.pharmacyLng;
    final endLat = _currentOrder.customerLat;
    final endLng = _currentOrder.customerLng;

    return SizedBox(
      height: 280,
      width: double.infinity,
      child: Stack(
        children: [
          // 1. FlutterMap Core Layer
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: LatLng(startLat, startLng),
              initialZoom: 13.5,
              onMapReady: () {
                WidgetsBinding.instance.addPostFrameCallback((_) => _fitMapBounds());
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.apps_k24',
                errorTileCallback: (tile, error, stackTrace) {
                  // Silently swallow network/DNS errors when offline
                },
              ),
              if (_routePoints.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    // Outer glow Polyline
                    Polyline(
                      points: _routePoints,
                      color: const Color(0xFF0054A6).withValues(alpha: 0.25),
                      strokeWidth: 8.0,
                    ),
                    // Inner main Polyline
                    Polyline(
                      points: _routePoints,
                      color: const Color(0xFF0054A6),
                      strokeWidth: 4.5,
                    ),
                  ],
                ),
              MarkerLayer(
                markers: [
                  // Pharmacy Marker (Start)
                  Marker(
                    point: LatLng(startLat, startLng),
                    width: 44,
                    height: 44,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0054A6),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF0054A6).withValues(alpha: 0.35),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Container(
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.storefront_rounded,
                          color: Color(0xFF0054A6),
                          size: 22,
                        ),
                      ),
                    ),
                  ),
                  // Destination Marker (End)
                  Marker(
                    point: LatLng(endLat, endLng),
                    width: 44,
                    height: 44,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFEF4444).withValues(alpha: 0.35),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Container(
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.location_on_rounded,
                          color: Color(0xFFEF4444),
                          size: 22,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),

          // 3. Top Left Route Status Badge Pill
          Positioned(
            top: 14,
            left: 14,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
                border: Border.all(color: Colors.white),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Color(0xFF10B981),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _batchStops.length > 1
                        ? 'Titik ${_currentStopIndex + 1} dari ${_batchStops.length}: ${_currentOrder.customerName}'
                        : 'Rute Pengantaran Apotek → Pelanggan',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.darkGrey,
                      fontFamily: 'Poppins',
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 4. Floating Action Control Buttons
          Positioned(
            bottom: 24,
            right: 14,
            child: Column(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: IconButton(
                    onPressed: _fitMapBounds,
                    icon: const Icon(Icons.my_location_rounded, size: 20, color: AppColors.darkGrey),
                    tooltip: 'Pusatkan Peta',
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF0054A6),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0054A6).withValues(alpha: 0.35),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: IconButton(
                    onPressed: () {
                      _launchMap(endLat, endLng, originLat: startLat, originLng: startLng);
                    },
                    icon: const Icon(Icons.navigation_rounded, size: 20, color: Colors.white),
                    tooltip: 'Buka Navigasi',
                  ),
                ),
              ],
            ),
          ),

          // 5. Route Loading Indicator
          if (_loadingRoute && _routePoints.isEmpty)
            const Center(
              child: CircularProgressIndicator(color: Color(0xFF0054A6)),
            ),
        ],
      ),
    );
  }

  void _showUnboxingOptionDialog() {
    bool isDelaying = false;
    final delayController = TextEditingController();
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Column(
            children: [
              Icon(
                isDelaying ? Icons.schedule_rounded : Icons.assignment_turned_in_rounded,
                color: isDelaying ? Colors.amber.shade800 : AppColors.primaryGreen,
                size: 36,
              ),
              const SizedBox(height: 8),
              Text(
                isDelaying ? 'Tunda Unboxing' : 'Pilih Aksi Unboxing',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, fontFamily: 'Poppins'),
              ),
              const SizedBox(height: 4),
              Text(
                _currentOrder.pharmacyName,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontFamily: 'Poppins'),
              ),
            ],
          ),
          content: isDelaying
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Tuliskan alasan penundaan unboxing:',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade700, fontFamily: 'Poppins'),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: delayController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: 'Misal: Apoteker sedang istirahat / toko tutup sementara...',
                        hintStyle: TextStyle(fontSize: 11, color: Colors.grey.shade400, fontFamily: 'Poppins'),
                        contentPadding: const EdgeInsets.all(12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        fillColor: const Color(0xFFFEF3C7),
                        filled: true,
                      ),
                      style: const TextStyle(fontSize: 12, fontFamily: 'Poppins'),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber.shade800,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 46),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: isSubmitting
                          ? null
                          : () async {
                              final reason = delayController.text.trim();
                              if (reason.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Alasan penundaan wajib diisi!'), backgroundColor: Colors.red),
                                );
                                return;
                              }
                              setDialogState(() => isSubmitting = true);
                              try {
                                await ApiService.waitUnboxOrder(_currentOrder.id, reason);
                                if (mounted) {
                                  Navigator.pop(context);
                                  await _refreshOrderDetails();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Unboxing ditunda. Alasan berhasil disimpan.'),
                                      backgroundColor: Colors.amber.shade900,
                                    ),
                                  );
                                }
                              } catch (e) {
                                setDialogState(() => isSubmitting = false);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Gagal menunda: $e'), backgroundColor: Colors.red),
                                );
                              }
                            },
                      icon: isSubmitting
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.send_rounded, size: 18),
                      label: const Text('Simpan & Tunda Unboxing', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => setDialogState(() => isDelaying = false),
                      child: const Text('Kembali ke pilihan', style: TextStyle(fontFamily: 'Poppins', fontSize: 12)),
                    ),
                  ],
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryGreen,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 48),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => VerifikasiInvoicePage(
                              order: _currentOrder,
                              batchStops: _batchStops,
                            ),
                          ),
                        ).then((res) {
                          if (res != null && mounted) {
                            if (res is OrderModel) {
                              setState(() {
                                _currentOrder = res;
                                _routePoints = [];
                              });
                              _refreshOrderDetails();
                            } else {
                              _refreshOrderDetails();
                            }
                          }
                        });
                      },
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text('Lanjut Unboxing', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.amber.shade900,
                        side: BorderSide(color: Colors.amber.shade800, width: 1.5),
                        minimumSize: const Size(double.infinity, 48),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: () {
                        setDialogState(() => isDelaying = true);
                      },
                      icon: const Icon(Icons.schedule_rounded),
                      label: const Text('Tunda Unboxing', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildActionButton() {
    if (_currentOrder.status == 'READY_FOR_PICKUP_FACTURE' || _currentOrder.status == 'COMPLETED') {
      final nextStop = _nextUncompletedStop;
      if (nextStop != null) {
        return ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryGreen,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 50),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 0,
          ),
          onPressed: () {
            setState(() {
              _currentOrder = nextStop;
              _routePoints = [];
            });
            _fetchRoute();
            _refreshOrderDetails();
          },
          icon: const Icon(Icons.navigation_rounded),
          label: Text(
            'Lanjutkan Titik (Lanjut ke ${nextStop.customerName.isNotEmpty ? nextStop.customerName : (nextStop.pharmacyName.isNotEmpty ? nextStop.pharmacyName : 'Titik Berikutnya')})',
            style: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold, fontSize: 14),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        );
      } else {
        return ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.secondaryBlue,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 50),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 0,
          ),
          onPressed: () async {
            final res = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => VerifikasiPODPage(
                  order: _currentOrder,
                ),
              ),
            );
            if (res == true && mounted) {
              await _refreshOrderDetails();
              Navigator.pop(context, true);
            }
          },
          icon: const Icon(Icons.assignment_returned_rounded),
          label: const Text('Verifikasi Pengembalian POD', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold, fontSize: 14)),
        );
      }
    }

    if (_currentOrder.status == 'WAITING_FOR_PICKUP') {
      return ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryGreen,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 50),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
        ),
        onPressed: _showPickupModal,
        icon: const Icon(Icons.camera_alt_outlined),
        label: const Text('Upload Bukti Pickup', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold, fontSize: 14)),
      );
    } else if (_currentOrder.status == 'PENDING' && _currentOrder.unboxingOption == 'WAITING_FOR_UNBOXING') {
      // Unboxing ditunda: tampilkan tombol lanjut ke titik berikutnya, atau kembali jika ini titik terakhir
      final nextDelayStop = _nextUncompletedStop;
      if (nextDelayStop != null) {
        return ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFF59E0B),
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 50),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 0,
          ),
          onPressed: () {
            setState(() {
              _currentOrder = nextDelayStop;
              _routePoints = [];
            });
            _fetchRoute();
            _refreshOrderDetails();
          },
          icon: const Icon(Icons.skip_next_rounded),
          label: Text(
            'Lanjutkan ke ${nextDelayStop.customerName.isNotEmpty ? nextDelayStop.customerName : (nextDelayStop.pharmacyName.isNotEmpty ? nextDelayStop.pharmacyName : 'Titik Berikutnya')}',
            style: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold, fontSize: 14),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        );
      } else {
        // Titik terakhir & unboxing ditunda → kembali ke daftar pesanan
        return ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF6B7280),
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 50),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 0,
          ),
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_rounded),
          label: const Text('Kembali ke Daftar Pesanan', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold, fontSize: 14)),
        );
      }
    } else if (_currentOrder.status == 'DELIVERING' || _currentOrder.status == 'PENDING') {
      if (_currentOrder.arrivedPhotoUrl.isEmpty) {
        return ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.secondaryBlue,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 50),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 0,
          ),
          onPressed: _showArrivedAtLocationModal,
          icon: const Icon(Icons.location_on_rounded),
          label: const Text('📍 Sudah Tiba di Lokasi', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold, fontSize: 14)),
        );
      } else {
        return Column(
          children: [
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFD1FAE5),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF10B981)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_rounded, color: Color(0xFF047857), size: 18),
                  SizedBox(width: 6),
                  Text('Driver Sudah Tiba di Lokasi Apotek', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF047857), fontFamily: 'Poppins')),
                ],
              ),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              onPressed: _showUnboxingOptionDialog,
              icon: const Icon(Icons.assignment_turned_in_rounded),
              label: const Text('📋 Verifikasi Invoice / Unboxing', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold, fontSize: 14)),
            ),
          ],
        );
      }
    }
    return const SizedBox.shrink();
  }

  void _showArrivedAtLocationModal() {
    final noteController = TextEditingController();
    String? arrivedPhotoBase64;
    bool isSubmitting = false;

    final targetName = _currentOrder.customerName.isNotEmpty ? _currentOrder.customerName : _currentOrder.pharmacyName;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) => Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    Text(
                      'Konfirmasi Tiba di Lokasi',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'Poppins'),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Ambil foto bukti bahwa driver telah tiba di apotek tujuan ($targetName)',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontFamily: 'Poppins'),
                ),
                gapH16,
                if (arrivedPhotoBase64 == null)
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 80),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      side: const BorderSide(color: AppColors.secondaryBlue, width: 1.5),
                    ),
                    onPressed: () async {
                      final img = await _pickAndGetBase64(locationText: targetName);
                      if (img != null) {
                        setModalState(() => arrivedPhotoBase64 = img);
                      }
                    },
                    icon: const Icon(Icons.camera_alt_outlined, color: AppColors.secondaryBlue),
                    label: const Text('Foto Tiba di Lokasi (Wajib)', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold, color: AppColors.secondaryBlue)),
                  )
                else
                  Stack(
                    children: [
                      Container(
                        width: double.infinity,
                        height: 160,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.memory(
                            base64Decode(arrivedPhotoBase64!.split(',')[1]),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: GestureDetector(
                          onTap: () => setModalState(() => arrivedPhotoBase64 = null),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.64), shape: BoxShape.circle),
                            child: const Icon(Icons.close, color: Colors.white, size: 16),
                          ),
                        ),
                      ),
                    ],
                  ),
                gapH12,
                TextField(
                  controller: noteController,
                  decoration: InputDecoration(
                    labelText: 'Catatan Tiba di Lokasi (Opsional)',
                    hintText: 'Contoh: Sudah parkir di depan apotek...',
                    labelStyle: const TextStyle(fontFamily: 'Poppins', fontSize: 13),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  maxLines: 2,
                ),
                gapH20,
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.secondaryBlue,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: isSubmitting || arrivedPhotoBase64 == null ? null : () async {
                    setModalState(() => isSubmitting = true);
                    try {
                      await ApiService.updateOrderArrived(
                        orderId: _currentOrder.id,
                        arrivedPhoto: arrivedPhotoBase64!,
                        arrivedNote: noteController.text,
                      );
                      if (mounted) {
                        Navigator.pop(context);
                        setState(() {
                          _currentOrder = _currentOrder.copyWith(
                            arrivedPhotoUrl: arrivedPhotoBase64!,
                            arrivedNote: noteController.text,
                          );
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('✅ Bukti Tiba di Lokasi Berhasil Disimpan'), backgroundColor: AppColors.primaryGreen),
                        );
                        await _refreshOrderDetails();
                        if (mounted) {
                          _showUnboxingOptionDialog();
                        }
                      }
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Gagal: $e'), backgroundColor: Colors.red),
                      );
                    } finally {
                      setModalState(() => isSubmitting = false);
                    }
                  },
                  child: isSubmitting
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Simpan Bukti Tiba di Lokasi', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Poppins')),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final statusLabel = _currentOrder.status == 'WAITING_FOR_PICKUP'
        ? 'Waiting Pickup'
        : _currentOrder.status == 'DELIVERING'
            ? 'Delivery Active'
            : _currentOrder.status == 'REJECTED_WAITING_APPROVAL'
                ? 'Waiting Approval'
                : _currentOrder.status == 'PENDING'
                    ? (_currentOrder.unboxingOption == 'WAITING_FOR_UNBOXING' ? 'Unboxing Ditunda' : 'Apoteker Unboxing')
                    : _currentOrder.status == 'READY_FOR_PICKUP_FACTURE'
                        ? 'Waiting for Pickup Facture'
                        : _currentOrder.status == 'COMPLETED_WAITING_APPROVAL'
                            ? 'Menunggu Approval Faktur'
                            : _currentOrder.status == 'COMPLETED'
                                ? 'Completed'
                                : 'Cancelled';

    final nextStop = _nextUncompletedStop;
    final isActionable = (_currentOrder.status != 'COMPLETED' && _currentOrder.status != 'CANCELLED') || nextStop != null;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Navigator.of(context).pop(true);
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Detail Pesanan', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Poppins')),
          centerTitle: true,
          backgroundColor: Colors.white,
          foregroundColor: AppColors.darkGrey,
          elevation: 0.5,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _refreshOrderDetails,
            ),
          ],
        ),
        backgroundColor: AppColors.lightGrey,
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(color: AppColors.primaryGreen))
            : Column(
                children: [
                  _buildMap(),
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                             // Status Header Card
                            Container(
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.grey.shade200),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.03),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: _getStatusColor(_currentOrder.status).withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          width: 7,
                                          height: 7,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: _getStatusColor(_currentOrder.status),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          statusLabel,
                                          style: TextStyle(
                                            color: _getStatusColor(_currentOrder.status),
                                            fontWeight: FontWeight.w800,
                                            fontSize: 12,
                                            fontFamily: 'Poppins',
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Spacer(),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        _currentOrder.orderNumber,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w900,
                                          fontSize: 14,
                                          color: AppColors.darkGrey,
                                          fontFamily: 'Poppins',
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        _formatDateTime(_currentOrder.createdAt),
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.grey.shade500,
                                          fontFamily: 'Poppins',
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            gapH12,
                            if (_currentOrder.status == 'PENDING' && _currentOrder.unboxingOption == 'WAITING_FOR_UNBOXING') ...[
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.amber.shade50,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: Colors.amber.shade200),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(Icons.warning_amber_rounded, color: Colors.amber.shade800, size: 20),
                                        gapW8,
                                        const Text(
                                          'Unboxing Ditunda Apoteker',
                                          style: TextStyle(
                                            color: AppColors.darkGrey,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                            fontFamily: 'Poppins',
                                          ),
                                        ),
                                      ],
                                    ),
                                    gapH8,
                                    Text(
                                      'Alasan: "${_currentOrder.extraItemsNote}"',
                                      style: TextStyle(
                                        color: Colors.amber.shade900,
                                        fontSize: 12,
                                        fontStyle: FontStyle.italic,
                                        fontFamily: 'Poppins',
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              gapH12,
                            ],

                            // Pharmacy Information Card
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6, offset: const Offset(0, 2)),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: AppColors.secondaryBlue.withOpacity(0.1),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(Icons.storefront_rounded, color: AppColors.secondaryBlue, size: 20),
                                      ),
                                      gapW12,
                                      const Text(
                                        'Apotek Pengambilan',
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.darkGrey),
                                      ),
                                    ],
                                  ),
                                  gapH12,
                                  Text(
                                    _currentOrder.pharmacyName,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.darkGrey),
                                  ),
                                  gapH4,
                                  Text(
                                    _currentOrder.pharmacyAddress,
                                    style: const TextStyle(fontSize: 12, color: Colors.grey, height: 1.3),
                                  ),
                                  gapH12,
                                  OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: AppColors.secondaryBlue,
                                      side: const BorderSide(color: AppColors.secondaryBlue),
                                      minimumSize: const Size(double.infinity, 40),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                    onPressed: () {
                                      _launchMap(_currentOrder.pharmacyLat, _currentOrder.pharmacyLng);
                                    },
                                    icon: const Icon(Icons.navigation_outlined, size: 16),
                                    label: const Text('Navigasi ke Apotek', style: TextStyle(fontSize: 12, fontFamily: 'Poppins', fontWeight: FontWeight.w600)),
                                  ),
                                ],
                              ),
                            ),
                            gapH12,

                            // Recipient Information Card
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6, offset: const Offset(0, 2)),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: AppColors.accentRed.withOpacity(0.1),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(Icons.location_on, color: AppColors.accentRed, size: 20),
                                      ),
                                      gapW12,
                                      const Text(
                                        'Alamat Pengiriman',
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.darkGrey),
                                      ),
                                    ],
                                  ),
                                  gapH12,
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              _currentOrder.customerName,
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.darkGrey),
                                            ),
                                            Text(
                                              _currentOrder.customerPhone,
                                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                                            ),
                                          ],
                                        ),
                                      ),
                                      IconButton(
                                        style: IconButton.styleFrom(
                                          backgroundColor: Colors.green.withOpacity(0.1),
                                          foregroundColor: Colors.green.shade800,
                                        ),
                                        onPressed: () {
                                          _launchUrl('tel:${_currentOrder.customerPhone}');
                                        },
                                        icon: const Icon(Icons.phone_rounded, size: 20),
                                      ),
                                    ],
                                  ),
                                  gapH8,
                                  Text(
                                    _currentOrder.deliveryAddress,
                                    style: const TextStyle(fontSize: 12, color: Colors.grey, height: 1.3),
                                  ),
                                  gapH12,
                                  OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: AppColors.accentRed,
                                      side: const BorderSide(color: AppColors.accentRed),
                                      minimumSize: const Size(double.infinity, 40),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                    onPressed: () {
                                      _launchMap(_currentOrder.customerLat, _currentOrder.customerLng);
                                    },
                                    icon: const Icon(Icons.navigation_outlined, size: 16),
                                    label: const Text('Navigasi ke Penerima', style: TextStyle(fontSize: 12, fontFamily: 'Poppins', fontWeight: FontWeight.w600)),
                                  ),
                                ],
                              ),
                            ),
                            gapH12,

                            // Medicine List Card
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6, offset: const Offset(0, 2)),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: Colors.orange.withOpacity(0.1),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(Icons.medication_rounded, color: Colors.orange, size: 20),
                                      ),
                                      gapW12,
                                      const Text(
                                        'Daftar Obat',
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.darkGrey),
                                      ),
                                    ],
                                  ),
                                  gapH12,
                                  Text(
                                    _currentOrder.medicineSummary,
                                    style: const TextStyle(fontSize: 13, height: 1.4, color: AppColors.darkGrey),
                                  ),
                                ],
                              ),
                            ),
                            gapH12,

                            // Delivery Fee Card
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6, offset: const Offset(0, 2)),
                                ],
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Ongkos Kirim',
                                        style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w500),
                                      ),
                                      gapH4,
                                      Text(
                                        'Metode: Non-Tunai (Auto-Credit)',
                                        style: TextStyle(fontSize: 11, color: Colors.grey),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    _formatRupiah(_currentOrder.deliveryFee),
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.primaryGreen, fontFamily: 'Poppins'),
                                  ),
                                ],
                              ),
                            ),
                            
                            // Completed / Cancelled Status banner if not actionable or transition banner
                            if (!isActionable || (_currentOrder.status == 'COMPLETED' && nextStop == null)) ...[
                              gapH16,
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: _currentOrder.status == 'COMPLETED' ? Colors.green.shade50 : Colors.red.shade50,
                                  border: Border.all(color: _currentOrder.status == 'COMPLETED' ? Colors.green.shade200 : Colors.red.shade200),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      _currentOrder.status == 'COMPLETED' ? Icons.check_circle : Icons.cancel,
                                      color: _currentOrder.status == 'COMPLETED' ? AppColors.primaryGreen : Colors.red.shade700,
                                    ),
                                    gapW12,
                                    Expanded(
                                      child: Text(
                                        _currentOrder.status == 'COMPLETED'
                                            ? 'Pengantaran obat seluruh titik telah sukses diselesaikan.'
                                            : 'Pengantaran obat ini telah dibatalkan.',
                                        style: const TextStyle(fontSize: 12, color: Colors.black87),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ] else if (_currentOrder.status == 'COMPLETED' && nextStop != null) ...[
                              gapH16,
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  border: Border.all(color: Colors.blue.shade200),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.check_circle, color: AppColors.secondaryBlue),
                                    gapW12,
                                    Expanded(
                                      child: Text(
                                        'Titik ${_currentOrder.pharmacyName} telah selesai. Tekan tombol "Lanjut ke Titik Berikutnya" di bawah untuk menuju ke ${nextStop.pharmacyName}.',
                                        style: const TextStyle(fontSize: 12, color: Colors.black87, fontFamily: 'Poppins'),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
        bottomNavigationBar: isActionable
            ? Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, -2)),
                  ],
                ),
                child: SafeArea(
                  child: _buildActionButton(),
                ),
              )
            : null,
      ),
    );
  }
}

class QrMockPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.fill;

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

    paint.color = Colors.black;
    for (int i = 0; i < 15; i++) {
      for (int j = 0; j < 15; j++) {
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
