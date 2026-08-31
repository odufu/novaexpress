// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:typed_data';

/// Browser web file downloader using HTML5 Blob and anchor trigger
Future<String?> downloadBytes({
  required Uint8List bytes,
  required String fileName,
  String mimeType = 'image/png',
}) async {
  final blob = html.Blob([bytes], mimeType);
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..setAttribute('download', fileName)
    ..style.display = 'none';

  html.document.body?.children.add(anchor);
  anchor.click();
  anchor.remove();

  // Delayed revocation to ensure browser has completed file download transfer
  Timer(const Duration(seconds: 2), () {
    html.Url.revokeObjectUrl(url);
  });

  return fileName;
}

/// Browser web string downloader (e.g. CSV, JSON, TXT)
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

/// No-op on web since the browser natively handles file placement in user's browser downloads
Future<bool> openSavedFile(String filePath) async {
  return false;
}
