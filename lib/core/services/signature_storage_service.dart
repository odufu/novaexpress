import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../constants/supabase_constants.dart';

class SignatureStorageService {
  /// Converts drawn points into a PNG byte array
  static Future<Uint8List?> exportPointsToPngBytes({
    required List<Offset?> points,
    required Size size,
    Color strokeColor = const Color(0xFF0F172A),
    double strokeWidth = 3.0,
    Color backgroundColor = Colors.white,
  }) async {
    if (points.isEmpty) return null;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, size.width, size.height));

    // Paint background
    final bgPaint = Paint()..color = backgroundColor;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    // Paint baseline guide
    final linePaint = Paint()
      ..color = const Color(0xFFE2E8F0)
      ..strokeWidth = 1.0;
    canvas.drawLine(
      Offset(20, size.height - 40),
      Offset(size.width - 20, size.height - 40),
      linePaint,
    );

    // Paint signature strokes
    final paint = Paint()
      ..color = strokeColor
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = strokeWidth;

    for (int i = 0; i < points.length - 1; i++) {
      if (points[i] != null && points[i + 1] != null) {
        canvas.drawLine(points[i]!, points[i + 1]!, paint);
      } else if (points[i] != null && points[i + 1] == null) {
        canvas.drawPoints(ui.PointMode.points, [points[i]!], paint);
      }
    }

    final picture = recorder.endRecording();
    final width = size.width.toInt().clamp(100, 1200);
    final height = size.height.toInt().clamp(100, 800);
    final img = await picture.toImage(width, height);
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    return byteData?.buffer.asUint8List();
  }

  /// Uploads signature PNG bytes to Supabase Storage bucket `pod_signatures`
  /// and returns the public or base64 Data URL.
  static Future<String> uploadSignature({
    required Uint8List pngBytes,
    required String orderId,
  }) async {
    final cleanId = orderId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '');
    final fileName = 'sig_${cleanId}_${DateTime.now().millisecondsSinceEpoch}.png';

    try {
      final client = Supabase.instance.client;
      await client.storage.from(SupabaseConstants.podSignaturesBucket).uploadBinary(
        fileName,
        pngBytes,
        fileOptions: const FileOptions(contentType: 'image/png', upsert: true),
      );
      final publicUrl = client.storage
          .from(SupabaseConstants.podSignaturesBucket)
          .getPublicUrl(fileName);
      return publicUrl;
    } catch (e) {
      debugPrint('[SIGNATURE_SERVICE] ℹ️ Cloud upload fallback to base64: $e');
      final base64String = base64Encode(pngBytes);
      return 'data:image/png;base64,$base64String';
    }
  }
}
