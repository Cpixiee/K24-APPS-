import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:apps_k24/models/dashboard_data.dart';
import 'package:apps_k24/services/api_service.dart';
import 'package:apps_k24/theme/app_colors.dart';
import 'package:apps_k24/theme/gaps.dart';
import 'package:apps_k24/components/signature_pad.dart';

class VerifikasiPODPage extends StatefulWidget {
  final OrderModel? order;
  final List<OrderModel>? groupOrders;

  const VerifikasiPODPage({
    super.key,
    this.order,
    this.groupOrders,
  });

  @override
  State<VerifikasiPODPage> createState() => _VerifikasiPODPageState();
}

class _VerifikasiPODPageState extends State<VerifikasiPODPage> {
  final GlobalKey<SignaturePadWidgetState> _podSignatureKey = GlobalKey();
  bool _submitting = false;

  List<OrderModel> get _orders {
    if (widget.groupOrders != null && widget.groupOrders!.isNotEmpty) {
      return widget.groupOrders!;
    }
    if (widget.order != null) {
      return [widget.order!];
    }
    return [];
  }

  OrderModel get _primaryOrder => _orders.isNotEmpty ? _orders.first : widget.order!;

  Future<void> _handleCompletePOD() async {
    final sig = await _podSignatureKey.currentState?.getSignatureBase64();
    if (sig == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Wajib mengisi Tanda Tangan Digital Pengembalian POD!'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _submitting = true);

    try {
      await ApiService.completePODOrder(
        orderId: _primaryOrder.id,
        podSignaturePhoto: sig,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Verifikasi Pengembalian POD Berhasil! Pesanan resmi SELESAI (COMPLETED).'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 4),
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menyelesaikan POD: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ordersList = _orders;
    final primary = _primaryOrder;
    final groupTitle = primary.dispatchId.isNotEmpty
        ? primary.dispatchId
        : (primary.parentOrderNumber.isNotEmpty ? primary.parentOrderNumber : primary.orderNumber);

    // Combine checked invoices from all stops
    final allCheckedInvoices = ordersList
        .map((o) => o.checkedInvoices)
        .where((inv) => inv.isNotEmpty)
        .join('\n---\n');

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Pengembalian POD (K-24)',
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
            // Order Info Header Card
            Container(
              padding: const EdgeInsets.all(16),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        groupTitle,
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, fontFamily: 'Poppins', color: Color(0xFF0054A6)),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${ordersList.length} Titik Invoice POD',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.orange.shade900, fontFamily: 'Poppins'),
                        ),
                      ),
                    ],
                  ),
                  gapH8,
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: ordersList.map((o) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '📍 ${o.customerName} (${o.orderNumber})',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'Poppins'),
                            ),
                            Text(
                              'Alamat: ${o.deliveryAddress}',
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontFamily: 'Poppins'),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),

            gapH20,

            // Summary Card: Ringkasan Invoice & Foto Faktur Terverifikasi untuk SEMUA Stop
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.primaryGreen, width: 1.5),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 6, offset: const Offset(0, 2)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Row(
                    children: [
                      Icon(
                        Icons.check_circle_rounded,
                        color: AppColors.primaryGreen,
                      ),
                      gapW8,
                      Expanded(
                        child: Text(
                          'Ringkasan Invoice & Faktur Terverifikasi',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, fontFamily: 'Poppins'),
                        ),
                      ),
                    ],
                  ),
                  gapH12,
                  if (allCheckedInvoices.isNotEmpty) ...[
                    const Text(
                      'Rincian Invoice Terverifikasi:',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.darkGrey, fontFamily: 'Poppins'),
                    ),
                    gapH4,
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Text(
                        allCheckedInvoices,
                        style: const TextStyle(fontSize: 11, fontFamily: 'Poppins', color: Color(0xFF1E293B)),
                      ),
                    ),
                    gapH12,
                  ],

                  // Display Uploaded Photos for ALL stops in the dispatch group
                  ...ordersList.expand((o) {
                    final photos = <Widget>[];
                    if (o.facturePhotoUrl.isNotEmpty) {
                      photos.add(_buildPhotoPreview('Foto Bukti Faktur (${o.customerName} - ${o.orderNumber}):', o.facturePhotoUrl));
                    }
                    if (o.pickupPhotoUrl.isNotEmpty) {
                      photos.add(_buildPhotoPreview('Foto Bukti Serah Terima (${o.customerName} - ${o.orderNumber}):', o.pickupPhotoUrl));
                    }
                    if (o.signaturePhotoUrl.isNotEmpty) {
                      photos.add(_buildPhotoPreview('Tanda Tangan Apoteker (${o.customerName}):', o.signaturePhotoUrl));
                    }
                    return photos;
                  }),
                ],
              ),
            ),

            gapH20,

            // Action 2: TTD Digital Canvas for POD Return
            SignaturePadWidget(
              key: _podSignatureKey,
              title: 'Tanda Tangan Digital Pengembalian POD (K-24)',
              subtitle: 'Serahkan HP kepada staf K-24 / penerima untuk tanda tangan',
            ),

            gapH24,

            // Final Submit Button -> Completed
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 52),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              onPressed: _submitting ? null : _handleCompletePOD,
              icon: _submitting
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.task_alt_rounded),
              label: const Text(
                'Selesaikan POD & Masuk Selesai (Done)',
                style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w800, fontSize: 14),
              ),
            ),
            gapH24,
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoPreview(String title, String photoUrl) {
    if (photoUrl.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.darkGrey, fontFamily: 'Poppins'),
        ),
        gapH4,
        Container(
          height: 150,
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: photoUrl.startsWith('data:image')
                ? Image.memory(
                    base64Decode(photoUrl.split(',')[1]),
                    fit: BoxFit.cover,
                    width: double.infinity,
                  )
                : Image.network(
                    photoUrl,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    errorBuilder: (context, error, stackTrace) => const Center(
                      child: Icon(Icons.broken_image_outlined, size: 40, color: Colors.grey),
                    ),
                  ),
          ),
        ),
        gapH12,
      ],
    );
  }
}
