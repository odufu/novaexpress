import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/constants/supabase_constants.dart';

class ChatStorageService {
  static Future<String> uploadVoiceNote({
    required Uint8List bytes,
    required String conversationId,
    String ext = 'webm',
    String mimeType = 'audio/webm',
  }) async {
    final cleanId = conversationId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '');
    final cleanExt = ext.toLowerCase().replaceAll('.', '');
    final fileName = 'vn_${cleanId}_${DateTime.now().millisecondsSinceEpoch}.$cleanExt';

    return _uploadToBucket(
      bucketName: SupabaseConstants.chatAttachmentsBucket,
      fileName: fileName,
      bytes: bytes,
      contentType: mimeType,
    );
  }

  static Future<String> uploadFileAttachment({
    required Uint8List bytes,
    required String conversationId,
    required String originalFileName,
    String? mimeType,
  }) async {
    final cleanId = conversationId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '');
    final cleanName = originalFileName.replaceAll(RegExp(r'[^a-zA-Z0-9_.-]'), '_');
    final fileName = 'file_${cleanId}_${DateTime.now().millisecondsSinceEpoch}_$cleanName';

    String cType = mimeType ?? 'application/octet-stream';
    if (cleanName.endsWith('.pdf')) {
      cType = 'application/pdf';
    } else if (cleanName.endsWith('.png')) {
      cType = 'image/png';
    } else if (cleanName.endsWith('.jpg') || cleanName.endsWith('.jpeg')) {
      cType = 'image/jpeg';
    } else if (cleanName.endsWith('.webp')) {
      cType = 'image/webp';
    } else if (cleanName.endsWith('.csv')) {
      cType = 'text/csv';
    } else if (cleanName.endsWith('.xlsx')) {
      cType = 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
    }

    return _uploadToBucket(
      bucketName: SupabaseConstants.chatAttachmentsBucket,
      fileName: fileName,
      bytes: bytes,
      contentType: cType,
    );
  }

  static Future<String> uploadImage({
    required Uint8List bytes,
    required String conversationId,
    String ext = 'jpg',
  }) async {
    final cleanId = conversationId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '');
    final cleanExt = ext.toLowerCase().replaceAll('.', '');
    final fileName = 'img_${cleanId}_${DateTime.now().millisecondsSinceEpoch}.$cleanExt';
    final mimeType = cleanExt == 'png' ? 'image/png' : 'image/jpeg';

    return _uploadToBucket(
      bucketName: SupabaseConstants.chatAttachmentsBucket,
      fileName: fileName,
      bytes: bytes,
      contentType: mimeType,
    );
  }

  static Future<String> _uploadToBucket({
    required String bucketName,
    required String fileName,
    required Uint8List bytes,
    required String contentType,
  }) async {
    try {
      final client = Supabase.instance.client;
      await client.storage.from(bucketName).uploadBinary(
            fileName,
            bytes,
            fileOptions: FileOptions(
              contentType: contentType,
              upsert: true,
            ),
          );
      return client.storage.from(bucketName).getPublicUrl(fileName);
    } catch (authError) {
      debugPrint('[ChatStorageService] Client upload fallback to service client: $authError');
      final adminClient = SupabaseClient(
        SupabaseConstants.supabaseUrl,
        SupabaseConstants.supabaseServiceRoleKey,
      );
      await adminClient.storage.from(bucketName).uploadBinary(
            fileName,
            bytes,
            fileOptions: FileOptions(
              contentType: contentType,
              upsert: true,
            ),
          );
      return adminClient.storage.from(bucketName).getPublicUrl(fileName);
    }
  }
}
