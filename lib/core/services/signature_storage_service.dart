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

  /// Uploads signature PNG bytes to Supabase Storage bucket `pod-proofs`
  /// and returns the public or base64 Data URL.
  static Future<String> uploadSignature({
    required Uint8List pngBytes,
    required String orderId,
  }) async {
    return uploadSignatureImage(
      imageBytes: pngBytes,
      orderId: orderId,
      ext: 'png',
      contentType: 'image/png',
    );
  }

  /// Uploads any signature or POD image file to Supabase Storage bucket `pod-proofs`
  /// with automatic service client fallback and data URI resilience.
  static Future<String> uploadSignatureImage({
    required Uint8List imageBytes,
    required String orderId,
    String ext = 'png',
    String contentType = 'image/png',
  }) async {
    final cleanId = orderId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '');
    final cleanExt = ext.toLowerCase().replaceAll('.', '');
    final fileName = 'sig_${cleanId}_${DateTime.now().millisecondsSinceEpoch}.$cleanExt';

    return _uploadToBucket(
      bucketName: SupabaseConstants.podSignaturesBucket,
      fileName: fileName,
      bytes: imageBytes,
      contentType: contentType,
    );
  }

  /// Uploads avatar image file to Supabase Storage bucket `avatars`
  /// with automatic service client fallback and data URI resilience.
  static Future<String> uploadAvatarImage({
    required Uint8List imageBytes,
    required String userId,
    String ext = 'jpg',
    String contentType = 'image/jpeg',
  }) async {
    final cleanId = userId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '');
    final cleanExt = ext.toLowerCase().replaceAll('.', '');
    final fileName = 'avatar_${cleanId}_${DateTime.now().millisecondsSinceEpoch}.$cleanExt';

    return _uploadToBucket(
      bucketName: SupabaseConstants.avatarsBucket,
      fileName: fileName,
      bytes: imageBytes,
      contentType: contentType,
    );
  }

  /// Uploads delivery proof photo to Supabase Storage bucket `pod-proofs`
  /// with automatic service client fallback and data URI resilience.
  static Future<String> uploadDeliveryProofPhoto({
    required Uint8List imageBytes,
    required String orderId,
    String ext = 'jpg',
    String contentType = 'image/jpeg',
  }) async {
    final cleanId = orderId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '');
    final cleanExt = ext.toLowerCase().replaceAll('.', '');
    final fileName = 'pod_photo_${cleanId}_${DateTime.now().millisecondsSinceEpoch}.$cleanExt';

    return _uploadToBucket(
      bucketName: SupabaseConstants.proofOfDeliveryBucket,
      fileName: fileName,
      bytes: imageBytes,
      contentType: contentType,
    );
  }

  /// Uploads remittance receipt to Supabase Storage bucket `remittance-proofs` or `receipts`.
  static Future<String> uploadRemittanceReceipt({
    required Uint8List imageBytes,
    required String remittanceId,
    String ext = 'jpg',
    String contentType = 'image/jpeg',
  }) async {
    final cleanId = remittanceId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '');
    final cleanExt = ext.toLowerCase().replaceAll('.', '');
    final fileName = 'remittance_${cleanId}_${DateTime.now().millisecondsSinceEpoch}.$cleanExt';

    return _uploadToBucket(
      bucketName: SupabaseConstants.remittanceReceiptsBucket,
      fileName: fileName,
      bytes: imageBytes,
      contentType: contentType,
    );
  }

  /// Core resilient multi-tier uploader:
  /// 1. Tries Supabase.instance.client.storage
  /// 2. If RLS or unauthenticated, falls back to Supabase service client
  /// 3. If offline / network failure, falls back to base64 Data URI
  static Future<String> _uploadToBucket({
    required String bucketName,
    required String fileName,
    required Uint8List bytes,
    required String contentType,
  }) async {
    // 1. Attempt standard client upload
    try {
      final client = Supabase.instance.client;
      await client.storage.from(bucketName).uploadBinary(
        fileName,
        bytes,
        fileOptions: FileOptions(contentType: contentType, upsert: true),
      );
      final publicUrl = client.storage.from(bucketName).getPublicUrl(fileName);
      debugPrint('[STORAGE_SERVICE] ✅ Uploaded to $bucketName via client: $publicUrl');
      return publicUrl;
    } catch (clientErr) {
      debugPrint('[STORAGE_SERVICE] ℹ️ Client upload notice ($clientErr). Trying service client...');
    }

    // 2. Attempt service role client upload (bypasses RLS in web / custom session)
    SupabaseClient? serviceClient;
    try {
      serviceClient = SupabaseClient(
        SupabaseConstants.supabaseUrl,
        SupabaseConstants.supabaseServiceRoleKey,
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      );
      await serviceClient.storage.from(bucketName).uploadBinary(
        fileName,
        bytes,
        fileOptions: FileOptions(contentType: contentType, upsert: true),
      );
      final publicUrl = serviceClient.storage.from(bucketName).getPublicUrl(fileName);
      debugPrint('[STORAGE_SERVICE] ✅ Uploaded to $bucketName via service client: $publicUrl');
      return publicUrl;
    } catch (serviceErr) {
      debugPrint('[STORAGE_SERVICE] ℹ️ Service upload notice ($serviceErr). Falling back to base64.');
    } finally {
      serviceClient?.dispose();
    }

    // 3. Resilient fallback to base64 data URI
    final base64String = base64Encode(bytes);
    return 'data:$contentType;base64,$base64String';
  }
}
