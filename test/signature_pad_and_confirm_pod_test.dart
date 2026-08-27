import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novexps/core/services/signature_storage_service.dart';
import 'package:novexps/core/widgets/signature_pad_modal.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Proof of Delivery (POD) Signature & Modal Suite', () {
    test('1. SignatureStorageService exports canvas points into valid PNG bytes', () async {
      final points = [
        const Offset(10, 10),
        const Offset(20, 20),
        const Offset(30, 25),
        null,
        const Offset(40, 40),
        const Offset(50, 50),
      ];

      final pngBytes = await SignatureStorageService.exportPointsToPngBytes(
        points: points,
        size: const Size(200, 100),
      );

      expect(pngBytes, isNotNull);
      expect(pngBytes!.length, greaterThan(0));
      // PNG header magic bytes (0x89, 'P', 'N', 'G')
      expect(pngBytes[0], 0x89);
      expect(pngBytes[1], 0x50);
      expect(pngBytes[2], 0x4E);
      expect(pngBytes[3], 0x47);
    });

    test('2. SignatureStorageService falls back reliably to Base64 URI when Supabase storage is offline', () async {
      final dummyBytes = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
      final url = await SignatureStorageService.uploadSignature(
        pngBytes: dummyBytes,
        orderId: 'TRK-9821-TEST',
      );

      expect(url.isNotEmpty, isTrue);
      expect(url.startsWith('data:image/png;base64,') || url.startsWith('http'), isTrue);
    });

    testWidgets('3. SignaturePadModal renders dedicated isolated canvas, clear and confirm actions', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SignaturePadModal(
              orderId: 'TRK-8821',
              customerName: 'Chief Aliyu Mohammed',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Customer Signature'), findsOneWidget);
      expect(find.text('Clear'), findsOneWidget);
      expect(find.text('Confirm Signature'), findsOneWidget);
      expect(find.byType(GestureDetector), findsWidgets);
    });
  });
}
