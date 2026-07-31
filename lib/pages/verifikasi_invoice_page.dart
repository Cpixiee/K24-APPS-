import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:apps_k24/models/dashboard_data.dart';
import 'package:apps_k24/services/api_service.dart';
import 'package:apps_k24/theme/app_colors.dart';
import 'package:apps_k24/theme/gaps.dart';
import 'package:apps_k24/components/signature_pad.dart';

class VerifikasiInvoicePage extends StatefulWidget {
  final OrderModel order;
  final List<OrderModel> batchStops;
  final bool isDelayMode;

  const VerifikasiInvoicePage({
    super.key,
    required this.order,
    this.batchStops = const [],
    this.isDelayMode = false,
  });

  @override
  State<VerifikasiInvoicePage> createState() => _VerifikasiInvoicePageState();
}

class _VerifikasiInvoicePageState extends State<VerifikasiInvoicePage> {
  final GlobalKey<SignaturePadWidgetState> _signaturePadKey = GlobalKey();
  
  bool _submitting = false;

  // Invoice Checklist state
  late List<String> _invoices;
  final Map<String, String> _invoiceStatuses = {};
  final Map<String, String> _missingNotes = {};
  final Map<String, String> _facturePhotos = {}; // Photo base64 per invoice
  final Map<String, Uint8List> _factureBytesMap = {}; // Raw bytes
  final Map<String, File> _factureFileMap = {}; // File for instant 0-delay UI preview

  final ImagePicker _picker = ImagePicker();



  void _initInvoices() {
    _invoices = [];
    final textToParse = '${widget.order.checkedInvoices} ${widget.order.medicineSummary}';

    if (textToParse.toUpperCase().contains('BARANG SUSULAN') || textToParse.toUpperCase().contains('BARANG_SUSULAN')) {
      if (!_invoices.contains('BARANG SUSULAN')) {
        _invoices.add('BARANG SUSULAN');
      }
    }

    // 1. First, try matching explicit invoice numbers with digits (e.g. 64297, 64299)
    final regExp = RegExp(r'\b(?:INV-?\d+|\d{4,10})\b', caseSensitive: false);
    final matches = regExp.allMatches(textToParse);

    for (final m in matches) {
      final raw = m.group(0)!;
      final formatted = raw.toUpperCase().startsWith('INV-')
          ? raw.toUpperCase()
          : 'INV-$raw';
      if (!_invoices.contains(formatted)) {
        _invoices.add(formatted);
      }
    }

    // 2. If no numeric invoices were found, parse tokens ignoring metadata like Armada/Rate/KM
    if (_invoices.isEmpty) {
      final rawParts = textToParse.split(RegExp(r'[;,]'));
      for (final p in rawParts) {
        final clean = p.split(':').first.trim();
        final lower = clean.toLowerCase();
        if (clean.isNotEmpty &&
            !lower.contains('armada') &&
            !lower.contains('rate') &&
            !lower.contains('km') &&
            !lower.contains('motor') &&
            !lower.contains('mobil') &&
            !lower.contains('invoices')) {
          final formatted = clean.toUpperCase().startsWith('INV-')
              ? clean.toUpperCase()
              : 'INV-$clean';
          if (!_invoices.contains(formatted)) {
            _invoices.add(formatted);
          }
        }
      }
    }

    // 3. Fallback default invoices if still empty
    if (_invoices.isEmpty) {
      final baseNum = widget.order.orderNumber.replaceAll(RegExp(r'^ORDER-'), '');
      _invoices = [
        'INV-$baseNum-01',
        'INV-$baseNum-02',
        'INV-$baseNum-03',
      ];
    }

    for (final inv in _invoices) {
      _invoiceStatuses[inv] = 'done';
    }
  }

  Future<void> _pickFacturePhoto(String inv) async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Upload Foto Faktur ($inv)',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, fontFamily: 'Poppins'),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primaryGreen.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.photo_library_rounded, color: AppColors.primaryGreen),
                ),
                title: const Text('Pilih dari Galeri Foto (Cepat/Instan)', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600, fontSize: 13)),
                subtitle: const Text('Proses langsung tanpa jeda/delay', style: TextStyle(fontSize: 11)),
                onTap: () {
                  Navigator.pop(context);
                  _processPickImage(inv, ImageSource.gallery);
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.camera_alt_rounded, color: Colors.blue),
                ),
                title: const Text('Ambil Foto Kamera', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600, fontSize: 13)),
                subtitle: const Text('Gunakan kamera perangkat HP', style: TextStyle(fontSize: 11)),
                onTap: () {
                  Navigator.pop(context);
                  _processPickImage(inv, ImageSource.camera);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _processPickImage(String inv, ImageSource source) async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: source,
        imageQuality: 70,
        maxWidth: 1024,
      );
      if (photo != null) {
        final imgFile = File(photo.path);
        // Instant UI update using native local File handle (0 delay)
        setState(() {
          _factureFileMap[inv] = imgFile;
        });

        final bytes = await photo.readAsBytes();
        _factureBytesMap[inv] = bytes;
        _facturePhotos[inv] = 'data:image/jpeg;base64,${base64Encode(bytes)}';
      }
    } catch (e) {
      debugPrint('Error picking photo for $inv: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal mengambil foto untuk $inv: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _handleSubmitUnboxing() async {
    // 1. Check Facture Photo PER INVOICE (Required if Sesuai (Done))
    for (final inv in _invoices) {
      final stat = _invoiceStatuses[inv] ?? 'done';
      if (stat == 'done' && _factureBytesMap[inv] == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('⚠️ Invoice $inv (Sesuai) wajib diunggah foto faktur fisiknya sebelum menekan Done!'),
            backgroundColor: Colors.red.shade700,
            duration: const Duration(seconds: 4),
          ),
        );
        return;
      }
    }

    // 2. Check Missing Notes for Tidak Sesuai items ("kalo missing cukup keterangan aja")
    for (final inv in _invoices) {
      final stat = _invoiceStatuses[inv] ?? 'done';
      if (stat == 'missing' && (_missingNotes[inv] ?? '').trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('⚠️ Invoice $inv (Tidak Sesuai) wajib diisi keterangan/alasan barang tidak sesuai!'),
            backgroundColor: Colors.red.shade700,
            duration: const Duration(seconds: 4),
          ),
        );
        return;
      }
    }

    // 3. Get Digital Signature
    final sig = await _signaturePadKey.currentState?.getSignatureBase64();
    if (sig == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('⚠️ Tanda tangan digital penerima/apoteker wajib diisi sebelum menekan Done!'),
          backgroundColor: Colors.red.shade700,
          duration: const Duration(seconds: 4),
        ),
      );
      return;
    }

    setState(() => _submitting = true);

    try {
      final checkedPayload = _invoices.map((inv) {
        final stat = _invoiceStatuses[inv] ?? 'done';
        final note = stat == 'missing' ? ' (Tidak Sesuai: ${_missingNotes[inv]})' : '';
        return '$inv: ${stat.toUpperCase()}$note';
      }).join('; ');

      // Combined photos payload
      final allPhotos = _facturePhotos.values.toList();
      final mainPhoto = allPhotos.isNotEmpty ? allPhotos[0] : '';

      await ApiService.submitUnboxAndFacture(
        orderId: widget.order.id,
        checkedInvoices: checkedPayload,
        facturePhoto: mainPhoto,
        signaturePhoto: sig,
      );

      // Open WhatsApp automatically to send real-time delivery report per stop
      await _sendWhatsAppReport(checkedPayload);

      if (!mounted) return;

      // Check if there are remaining uncompleted stops in batchStops
      final remainingStops = widget.batchStops.where((s) => s.id != widget.order.id && s.status != 'COMPLETED' && s.status != 'READY_FOR_PICKUP_FACTURE').toList();

      if (remainingStops.isNotEmpty) {
        final nextStop = remainingStops.first;
        final name = nextStop.customerName.isNotEmpty ? nextStop.customerName : nextStop.pharmacyName;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Unboxing & Laporan WA terkirim! Melanjutkan ke titik berikutnya: $name'),
            backgroundColor: AppColors.primaryGreen,
            duration: const Duration(seconds: 4),
          ),
        );
        Navigator.pop(context, nextStop);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('🎉 Seluruh titik pengantaran selesai! Silakan lakukan pengembalian POD ke K-24 Hub.'),
            backgroundColor: AppColors.primaryGreen,
            duration: const Duration(seconds: 5),
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menyimpan verifikasi: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  late TextEditingController _recipientNameController;
  late TextEditingController _recipientPhoneController;
  late TextEditingController _catatanController;

  String _driverName = 'Driver K-24';
  int _driverId = 0;

  @override
  void initState() {
    super.initState();
    _recipientNameController = TextEditingController(text: widget.order.customerName);
    _recipientPhoneController = TextEditingController(text: widget.order.customerPhone);
    _catatanController = TextEditingController(text: widget.order.extraItemsNote);
    _initInvoices();
    _loadDriverInfo();
  }

  @override
  void dispose() {
    _recipientNameController.dispose();
    _recipientPhoneController.dispose();
    _catatanController.dispose();
    super.dispose();
  }

  Future<void> _loadDriverInfo() async {
    try {
      final dashboard = await ApiService.getDashboard();
      if (mounted) {
        setState(() {
          _driverName = dashboard.driver.name.isNotEmpty ? dashboard.driver.name : 'Driver K-24';
          _driverId = dashboard.driver.id;
        });
      }
    } catch (_) {}
  }

  Future<void> _sendWhatsAppReport(String checkedPayload) async {
    const waNumber = '6287877807780';
    final now = DateTime.now();
    final dateStr = '${now.day}/${now.month}/${now.year}';
    final timeStr = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')} WIB';
    final pickupTimeStr = '${widget.order.createdAt.hour.toString().padLeft(2, '0')}:${widget.order.createdAt.minute.toString().padLeft(2, '0')} WIB';

    final apotekName = widget.order.customerName.isNotEmpty
        ? widget.order.customerName
        : (widget.order.pharmacyName.isNotEmpty ? widget.order.pharmacyName : 'Apotek K-24');

    final invoiceListText = _invoices.map((inv) {
      final stat = _invoiceStatuses[inv] ?? 'done';
      final note = stat == 'missing' ? ' (Tidak Sesuai: ${_missingNotes[inv]})' : '';
      return '- $inv: ${stat.toUpperCase()}$note';
    }).join('\n');

    final recipientName = _recipientNameController.text.trim().isNotEmpty
        ? _recipientNameController.text.trim()
        : widget.order.customerName;
    final recipientPhone = _recipientPhoneController.text.trim().isNotEmpty
        ? _recipientPhoneController.text.trim()
        : widget.order.customerPhone;
    final catatan = _catatanController.text.trim().isNotEmpty
        ? _catatanController.text.trim()
        : (checkedPayload.contains('Tidak Sesuai') ? checkedPayload : 'Semua invoice sesuai & terverifikasi');

    final driverTag = _driverId != 0 ? '$_driverName (ID: $_driverId)' : _driverName;

    final message = '''K24 JAKARTA
REALTIME REPORT
Tanggal pengiriman: $dateStr
——————————————————————
ID apotek: $apotekName
Alamat pengiriman: ${widget.order.deliveryAddress}
No order: ${widget.order.orderNumber}
ID driver: $driverTag
Jam pickup: $pickupTimeStr
Jam delivery: $timeStr
——————————————————————
Daftar invoice:
$invoiceListText
Catatan: $catatan
——————————————————————
Penerima:
Nama: $recipientName
No telp: $recipientPhone''';

    // 1. First, attempt to share the Ningrat Logo Image WITH the report text as caption via Share.shareXFiles
    try {
      final byteData = await rootBundle.load('assets/images/logo_ningrat_text.jpg');
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/logo_ningrat_report.jpg');
      await tempFile.writeAsBytes(byteData.buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes));

      if (await tempFile.exists()) {
        final xFile = XFile(tempFile.path);
        await Share.shareXFiles(
          [xFile],
          text: message,
          subject: 'K24 JAKARTA REALTIME REPORT',
        );
        return;
      }
    } catch (e) {
      debugPrint('[WA Image Share] Could not share logo image, falling back to url_launcher: $e');
    }

    // 2. Fallback to direct url_launcher wa.me link
    final encodedMessage = Uri.encodeComponent(message);
    final waUrl = Uri.parse('https://wa.me/$waNumber?text=$encodedMessage');

    try {
      if (await canLaunchUrl(waUrl)) {
        await launchUrl(waUrl, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(waUrl, mode: LaunchMode.externalNonBrowserApplication);
      }
    } catch (e) {
      debugPrint('[WA] Failed to launch WhatsApp: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Verifikasi Invoice & Unboxing',
          style: TextStyle(fontWeight: FontWeight.w800, fontFamily: 'Poppins', fontSize: 16),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: AppColors.darkGrey,
        elevation: 0.5,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Order Info Header Card (Overflow Free)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0054A6), Color(0xFF0072CE)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0054A6).withValues(alpha: 0.2),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.order.pharmacyName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 15,
                            fontFamily: 'Poppins',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          widget.order.orderNumber,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Poppins',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    widget.order.deliveryAddress,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white70, fontSize: 11, fontFamily: 'Poppins'),
                  ),
                ],
              ),
            ),

            gapH20,

            // Invoice Checklist Card
            Text(
              'Checklist Invoice Obat (${_invoices.length} Invoice Wajib Diperiksa)',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, fontFamily: 'Poppins', color: AppColors.darkGrey),
            ),
            gapH8,
            ..._invoices.map((inv) {
              final stat = _invoiceStatuses[inv] ?? 'done';
              final imgFile = _factureFileMap[inv];

              return Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: imgFile != null ? AppColors.primaryGreen : Colors.grey.shade200, width: imgFile != null ? 1.5 : 1.0),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 6, offset: const Offset(0, 2)),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Title Header
                    Row(
                      children: [
                        Icon(
                          inv.toUpperCase().contains('SUSULAN') ? Icons.inventory_2_rounded : Icons.receipt_long_rounded,
                          color: inv.toUpperCase().contains('SUSULAN') ? const Color(0xFFD97706) : const Color(0xFF0054A6),
                          size: 18,
                        ),
                        gapW8,
                        Expanded(
                          child: Text(
                            inv.toUpperCase().contains('SUSULAN') ? '📦 BARANG SUSULAN (Tanpa Invoice)' : inv,
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                              fontFamily: 'Poppins',
                              color: inv.toUpperCase().contains('SUSULAN') ? const Color(0xFFB45309) : AppColors.darkGrey,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // 2. FOTO UPLOAD FAKTUR FISIK DULU (TOP) - Instant Image.file (0 delay)
                    if (imgFile == null)
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 44),
                          backgroundColor: inv.toUpperCase().contains('SUSULAN') ? const Color(0xFFFFFBEB) : Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          side: BorderSide(color: inv.toUpperCase().contains('SUSULAN') ? const Color(0xFFF59E0B) : AppColors.primaryGreen, width: 1.2),
                        ),
                        onPressed: () => _pickFacturePhoto(inv),
                        icon: Icon(Icons.camera_alt_outlined, color: inv.toUpperCase().contains('SUSULAN') ? const Color(0xFFD97706) : AppColors.primaryGreen, size: 18),
                        label: Text(
                          inv.toUpperCase().contains('SUSULAN') ? 'Upload Foto Bukti Barang Susulan' : 'Upload Foto Faktur Fisik ($inv)',
                          style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold, fontSize: 12, color: inv.toUpperCase().contains('SUSULAN') ? const Color(0xFFB45309) : AppColors.primaryGreen),
                        ),
                      )
                    else
                      Stack(
                        children: [
                          Container(
                            height: 140,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFF10B981), width: 1.5),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.file(
                                imgFile,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          Positioned(
                            top: 6,
                            right: 6,
                            child: GestureDetector(
                              onTap: () => setState(() {
                                _factureFileMap.remove(inv);
                                _factureBytesMap.remove(inv);
                                _facturePhotos.remove(inv);
                              }),
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: const BoxDecoration(
                                  color: Colors.black54,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.close, color: Colors.white, size: 14),
                              ),
                            ),
                          ),
                        ],
                      ),

                    const SizedBox(height: 12),

                    // 3. BARU DI BAWAHNYA BUTTON CHOICES (BOTTOM)
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        ChoiceChip(
                          label: Text(
                            inv.toUpperCase().contains('SUSULAN') ? 'Barang Susulan Sesuai' : 'Sesuai (Done)',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'Poppins'),
                          ),
                          selected: stat == 'done',
                          selectedColor: const Color(0xFFD1FAE5),
                          onSelected: (val) {
                            if (val) setState(() => _invoiceStatuses[inv] = 'done');
                          },
                        ),
                        ChoiceChip(
                          label: const Text('Tidak Sesuai', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'Poppins')),
                          selected: stat == 'missing',
                          selectedColor: Colors.red.shade100,
                          onSelected: (val) {
                            if (val) setState(() => _invoiceStatuses[inv] = 'missing');
                          },
                        ),
                      ],
                    ),

                    if (stat == 'missing') ...[
                      const SizedBox(height: 8),
                      TextField(
                        decoration: InputDecoration(
                          hintText: 'Tuliskan keterangan / alasan barang tidak sesuai (Wajib)...',
                          hintStyle: TextStyle(fontSize: 11, color: Colors.grey.shade400, fontFamily: 'Poppins'),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          fillColor: const Color(0xFFFEF2F2),
                          filled: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: Colors.red.shade200),
                          ),
                        ),
                        style: const TextStyle(fontSize: 12, fontFamily: 'Poppins'),
                        onChanged: (val) => _missingNotes[inv] = val,
                      ),
                    ],
                  ],
                ),
              );
            }),

            gapH16,

            // Data Penerima & Catatan Card (Wajib diisi/diverifikasi driver)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 6, offset: const Offset(0, 2)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.person_outline_rounded, color: AppColors.secondaryBlue, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Data Penerima & Catatan (Untuk WA Realtime)',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, fontFamily: 'Poppins', color: AppColors.darkGrey),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text('Nama Penerima (Apoteker / Petugas)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, fontFamily: 'Poppins')),
                  const SizedBox(height: 4),
                  TextField(
                    controller: _recipientNameController,
                    decoration: InputDecoration(
                      hintText: 'Nama penerima barang...',
                      hintStyle: TextStyle(fontSize: 11, color: Colors.grey.shade400, fontFamily: 'Poppins'),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    style: const TextStyle(fontSize: 12, fontFamily: 'Poppins'),
                  ),
                  const SizedBox(height: 12),
                  const Text('No. Telp Penerima', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, fontFamily: 'Poppins')),
                  const SizedBox(height: 4),
                  TextField(
                    controller: _recipientPhoneController,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      hintText: 'Nomor HP/WA penerima...',
                      hintStyle: TextStyle(fontSize: 11, color: Colors.grey.shade400, fontFamily: 'Poppins'),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    style: const TextStyle(fontSize: 12, fontFamily: 'Poppins'),
                  ),
                  const SizedBox(height: 12),
                  const Text('Catatan Pengiriman (Opsional)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, fontFamily: 'Poppins')),
                  const SizedBox(height: 4),
                  TextField(
                    controller: _catatanController,
                    decoration: InputDecoration(
                      hintText: 'Catatan/keterangan pengiriman...',
                      hintStyle: TextStyle(fontSize: 11, color: Colors.grey.shade400, fontFamily: 'Poppins'),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    style: const TextStyle(fontSize: 12, fontFamily: 'Poppins'),
                  ),
                ],
              ),
            ),

            gapH16,

            // TTD Digital Canvas
            SignaturePadWidget(
              key: _signaturePadKey,
              title: 'Tanda Tangan Digital Apoteker / Penerima',
              subtitle: 'Gunakan touch screen HP untuk membubuhkan tanda tangan',
            ),

            gapH24,

            // Tombol Done
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 52),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              onPressed: _submitting ? null : _handleSubmitUnboxing,
              icon: _submitting
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.check_circle_rounded),
              label: const Text(
                'Selesaikan Unboxing (Done)',
                style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w800, fontSize: 14),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
