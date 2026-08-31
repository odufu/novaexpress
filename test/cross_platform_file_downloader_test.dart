import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:novexps/core/services/file_downloader.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Cross-Platform File Downloader & Exporter Suite', () {
    test('downloadBytes saves PNG bytes to disk on native platform and returns valid file path', () async {
      final dummyBytes = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
      final testFileName = 'test_receipt_${DateTime.now().millisecondsSinceEpoch}.png';

      final savedPath = await downloadBytes(
        bytes: dummyBytes,
        fileName: testFileName,
        mimeType: 'image/png',
      );

      expect(savedPath, isNotNull);
      expect(savedPath!, contains(testFileName));

      final file = File(savedPath);
      expect(await file.exists(), isTrue);
      expect(await file.length(), equals(dummyBytes.length));

      // Cleanup
      try {
        await file.delete();
      } catch (_) {}
    });

    test('downloadString exports text/csv data cleanly to storage', () async {
      const csvData = 'OrderNumber,CustomerName,Amount,Status\nTRK-1001,John Doe,55000,Delivered\n';
      final testFileName = 'test_manifest_${DateTime.now().millisecondsSinceEpoch}.csv';

      final savedPath = await downloadString(
        content: csvData,
        fileName: testFileName,
        mimeType: 'text/csv',
      );

      expect(savedPath, isNotNull);
      expect(savedPath!, contains(testFileName));

      final file = File(savedPath);
      expect(await file.exists(), isTrue);
      final readText = await file.readAsString();
      expect(readText, equals(csvData));

      // Cleanup
      try {
        await file.delete();
      } catch (_) {}
    });
  });
}
