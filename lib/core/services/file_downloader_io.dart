import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Native cross-platform file downloader & saver (Android, iOS, macOS, Windows, Linux)
Future<String?> downloadBytes({
  required Uint8List bytes,
  required String fileName,
  String mimeType = 'image/png',
}) async {
  try {
    Directory? targetDir;

    if (Platform.isAndroid) {
      // 1. Try public Download directory first (/storage/emulated/0/Download)
      final publicDownload = Directory('/storage/emulated/0/Download');
      if (await publicDownload.exists()) {
        targetDir = publicDownload;
      } else {
        // 2. Try public Pictures directory
        final publicPictures = Directory('/storage/emulated/0/Pictures');
        if (await publicPictures.exists()) {
          targetDir = publicPictures;
        } else {
          // 3. Fallback to path_provider external storage or downloads
          targetDir = await getDownloadsDirectory() ??
              await getExternalStorageDirectory() ??
              await getApplicationDocumentsDirectory();
        }
      }
    } else if (Platform.isIOS || Platform.isMacOS) {
      targetDir = await getApplicationDocumentsDirectory();
    } else if (Platform.isWindows || Platform.isLinux) {
      targetDir = await getDownloadsDirectory() ??
          await getApplicationDocumentsDirectory();
    } else {
      targetDir = await getApplicationDocumentsDirectory();
    }

    final filePath = '${targetDir.path}/$fileName';
    final file = File(filePath);
    await file.writeAsBytes(bytes, flush: true);
    debugPrint('[FILE_DOWNLOADER] ✅ File saved successfully to: $filePath');

    return filePath;
  } catch (e) {
    debugPrint('[FILE_DOWNLOADER] ⚠️ Primary save failed ($e), attempting app document fallback...');
    try {
      final docDir = await getApplicationDocumentsDirectory();
      final fallbackPath = '${docDir.path}/$fileName';
      final file = File(fallbackPath);
      await file.writeAsBytes(bytes, flush: true);
      debugPrint('[FILE_DOWNLOADER] ✅ File saved to fallback path: $fallbackPath');
      return fallbackPath;
    } catch (inner) {
      debugPrint('[FILE_DOWNLOADER] ❌ All save attempts failed: $inner');
      rethrow;
    }
  }
}
