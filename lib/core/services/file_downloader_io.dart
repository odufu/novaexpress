import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Native cross-platform file downloader & saver (Windows, macOS, Linux, Android, iOS)
Future<String?> downloadBytes({
  required Uint8List bytes,
  required String fileName,
  String mimeType = 'image/png',
}) async {
  try {
    Directory? targetDir;

    if (Platform.isWindows) {
      // 1. Try Windows User Downloads folder
      final userProfile = Platform.environment['USERPROFILE'];
      if (userProfile != null && userProfile.isNotEmpty) {
        final winDownloads = Directory('$userProfile\\Downloads');
        if (await winDownloads.exists()) {
          targetDir = winDownloads;
        }
      }
      targetDir ??= await getDownloadsDirectory() ??
          await getApplicationDocumentsDirectory();
    } else if (Platform.isAndroid) {
      // 1. Try Android public Downloads directory (/storage/emulated/0/Download)
      final publicDownload = Directory('/storage/emulated/0/Download');
      if (await publicDownload.exists()) {
        targetDir = publicDownload;
      } else {
        // 2. Try Android public Pictures directory
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
      targetDir = await getDownloadsDirectory() ??
          await getApplicationDocumentsDirectory();
    } else if (Platform.isLinux) {
      final home = Platform.environment['HOME'];
      if (home != null && home.isNotEmpty) {
        final linuxDownloads = Directory('$home/Downloads');
        if (await linuxDownloads.exists()) {
          targetDir = linuxDownloads;
        }
      }
      targetDir ??= await getDownloadsDirectory() ??
          await getApplicationDocumentsDirectory();
    } else {
      targetDir = await getApplicationDocumentsDirectory();
    }

    final separator = Platform.isWindows ? '\\' : '/';
    final filePath = '${targetDir.path}$separator$fileName';
    final file = File(filePath);
    await file.writeAsBytes(bytes, flush: true);
    debugPrint('[FILE_DOWNLOADER] ✅ File saved successfully to: $filePath');

    return filePath;
  } catch (e) {
    debugPrint('[FILE_DOWNLOADER] ⚠️ Primary save failed ($e), attempting app document fallback...');
    try {
      final docDir = await getApplicationDocumentsDirectory();
      final separator = Platform.isWindows ? '\\' : '/';
      final fallbackPath = '${docDir.path}$separator$fileName';
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

/// Download string content (e.g. CSV, JSON, TXT)
Future<String?> downloadString({
  required String content,
  required String fileName,
  String mimeType = 'text/csv',
}) async {
  final bytes = Uint8List.fromList(utf8.encode(content));
  return downloadBytes(
    bytes: bytes,
    fileName: fileName,
    mimeType: mimeType,
  );
}

/// Open the saved file or highlight it in the native platform file manager (Windows Explorer, macOS Finder, etc.)
Future<bool> openSavedFile(String filePath) async {
  try {
    final file = File(filePath);
    if (!await file.exists()) {
      debugPrint('[FILE_DOWNLOADER] ⚠️ File does not exist: $filePath');
      return false;
    }

    if (Platform.isWindows) {
      await Process.run('explorer.exe', ['/select,', filePath]);
      return true;
    } else if (Platform.isMacOS) {
      await Process.run('open', ['-R', filePath]);
      return true;
    } else if (Platform.isLinux) {
      await Process.run('xdg-open', [file.parent.path]);
      return true;
    }
    return false;
  } catch (e) {
    debugPrint('[FILE_DOWNLOADER] ⚠️ Failed to open file in system explorer: $e');
    return false;
  }
}
