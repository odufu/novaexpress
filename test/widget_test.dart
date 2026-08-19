import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novexps/core/widgets/offline_sync_banner.dart';
import 'package:novexps/core/widgets/signature_pad_widget.dart';

void main() {
  testWidgets('NovaExpressApp smoke and core UI components test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              OfflineSyncBanner(
                status: SyncStatus.offline,
                pendingQueueCount: 2,
              ),
              Expanded(
                child: SignaturePadWidget(),
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.byType(OfflineSyncBanner), findsOneWidget);
    expect(find.byType(SignaturePadWidget), findsOneWidget);
    expect(find.textContaining('Offline Mode'), findsOneWidget);
  });
}
