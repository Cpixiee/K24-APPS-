import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

class WatermarkHelper {
  /// Adds a professional watermark overlay (Dark banner with timestamp, driver name, location)
  /// directly onto the base64 or raw byte image.
  static Future<String> addWatermarkToBase64({
    required String base64Image,
    required String driverName,
    required String locationText,
    String titleText = 'K-24 LOGISTICS REALTIME VERIFIED',
  }) async {
    try {
      final cleanBase64 = base64Image.contains(',')
          ? base64Image.split(',')[1]
          : base64Image;
      final bytes = base64Decode(cleanBase64);

      final watermarkedBytes = await addWatermarkToBytes(
        imageBytes: bytes,
        driverName: driverName,
        locationText: locationText,
        titleText: titleText,
      );

      final prefix = base64Image.contains(',')
          ? base64Image.split(',')[0] + ','
          : 'data:image/jpeg;base64,';

      return prefix + base64Encode(watermarkedBytes);
    } catch (e) {
      debugPrint('[WatermarkHelper] Error adding watermark: $e');
      return base64Image; // Fallback to original
    }
  }

  /// Low level canvas watermarking using dart:ui
  static Future<Uint8List> addWatermarkToBytes({
    required Uint8List imageBytes,
    required String driverName,
    required String locationText,
    String titleText = 'K-24 LOGISTICS REALTIME VERIFIED',
  }) async {
    try {
      final codec = await ui.instantiateImageCodec(imageBytes);
      final frame = await codec.getNextFrame();
      final ui.Image originalImage = frame.image;

      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);

      final width = originalImage.width.toDouble();
      final height = originalImage.height.toDouble();

      // 1. Draw original image
      canvas.drawImage(originalImage, ui.Offset.zero, ui.Paint());

      // 2. Format Timestamp
      final now = DateTime.now();
      final timeStr =
          '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')} WIB';

      // 3. Compute Banner Height proportional to image height
      final bannerHeight = (height * 0.18).clamp(130.0, 260.0);
      final bgPaint = ui.Paint()..color = const ui.Color(0xD9000000); // 85% opacity dark bar

      canvas.drawRect(
        ui.Rect.fromLTWH(0, height - bannerHeight, width, bannerHeight),
        bgPaint,
      );

      // Accent Green Vertical Line
      final accentPaint = ui.Paint()..color = const ui.Color(0xFF10B981);
      final accentWidth = (width * 0.012).clamp(6.0, 16.0);
      canvas.drawRect(
        ui.Rect.fromLTWH(0, height - bannerHeight, accentWidth, bannerHeight),
        accentPaint,
      );

      // 4. Calculate Text Sizes dynamically based on image width
      final titleSize = (width * 0.028).clamp(16.0, 32.0);
      final bodySize = (width * 0.024).clamp(14.0, 26.0);

      final pb = ui.ParagraphBuilder(ui.ParagraphStyle(
        textDirection: ui.TextDirection.ltr,
        maxLines: 4,
      ));

      // Title
      pb.pushStyle(ui.TextStyle(
        color: const ui.Color(0xFF10B981),
        fontSize: titleSize,
        fontWeight: ui.FontWeight.bold,
      ));
      pb.addText('📍 $titleText\n');

      // Body Details
      pb.pushStyle(ui.TextStyle(
        color: const ui.Color(0xFFFFFFFF),
        fontSize: bodySize,
        fontWeight: ui.FontWeight.w600,
      ));
      pb.addText('🕒 WAKTU & TANGGAL: $timeStr\n');
      pb.addText('👤 DRIVER: $driverName\n');
      pb.addText('🏥 LOKASI: $locationText');

      final paragraph = pb.build()
        ..layout(ui.ParagraphConstraints(width: width - accentWidth - 30));

      canvas.drawParagraph(
        paragraph,
        ui.Offset(accentWidth + 16, height - bannerHeight + 12),
      );

      final picture = recorder.endRecording();
      final img = await picture.toImage(width.toInt(), height.toInt());
      final byteData = await img.toByteData(format: ui.ImageByteFormat.png);

      return byteData!.buffer.asUint8List();
    } catch (e) {
      debugPrint('[WatermarkHelper] Low level canvas error: $e');
      return imageBytes;
    }
  }
}
