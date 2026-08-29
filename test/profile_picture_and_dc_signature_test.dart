import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novexps/core/services/signature_storage_service.dart';
import 'package:novexps/core/widgets/signature_pad_modal.dart';
import 'package:novexps/core/widgets/user_avatar_widget.dart';
import 'package:novexps/features/auth/domain/entities/user.dart';
import 'package:novexps/features/auth/presentation/providers/auth_provider.dart';
import 'package:novexps/features/dc_console/presentation/widgets/dc_order_detail_modal.dart';
import 'package:novexps/features/finance/presentation/providers/finance_provider.dart';
import 'package:novexps/features/orders/domain/entities/order.dart';
import 'package:novexps/features/orders/presentation/providers/orders_provider.dart';
import 'package:novexps/features/stock/presentation/providers/stock_provider.dart';

class _MockOrdersNotifier extends StateNotifier<OrdersState> implements OrdersNotifier {
  _MockOrdersNotifier(List<OrderEntity> orders) : super(OrdersState(orders: orders, isLoading: false));

  @override
  void updateOrderInList(OrderEntity updatedOrder) {
    state = state.copyWith(orders: [updatedOrder]);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockAuthNotifier extends StateNotifier<AuthState> implements AuthNotifier {
  _MockAuthNotifier()
      : super(
          const AuthState(
            user: UserEntity(
              id: 'user-001',
              email: 'dc.supervisor@novaexpress.ng',
              firstName: 'Adekunle',
              lastName: 'Supervisor',
              phone: '08099887766',
              role: 'dc_manager',
              distributionCenterName: 'Wuse Distribution Center',
            ),
          ),
        );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockStockNotifier extends StateNotifier<StockState> implements StockNotifier {
  _MockStockNotifier() : super(const StockState());

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockFinanceNotifier extends StateNotifier<FinanceState> implements FinanceNotifier {
  _MockFinanceNotifier() : super(FinanceState(remittances: const []));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Profile Picture (DP) & UserAvatarWidget Suite', () {
    testWidgets('1. UserAvatarWidget renders initials when avatarUrl is null', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: UserAvatarWidget(
              avatarUrl: null,
              fullName: 'Joel Odufu',
              radius: 20,
            ),
          ),
        ),
      );

      expect(find.text('JO'), findsOneWidget);
    });

    testWidgets('2. UserAvatarWidget renders base64 data URI image smoothly', (tester) async {
      // 1x1 transparent png in base64
      const transparentPngBase64 =
          'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: UserAvatarWidget(
              avatarUrl: transparentPngBase64,
              fullName: 'Joel Odufu',
              radius: 24,
              showBorder: true,
            ),
          ),
        ),
      );

      expect(find.byType(Image), findsOneWidget);
    });
  });

  group('Digital Signature & POD Suite', () {
    test('3. SignatureStorageService converts bytes to data URI on fallback', () async {
      final sampleBytes = Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10]);
      final uri = await SignatureStorageService.uploadSignatureImage(
        imageBytes: sampleBytes,
        orderId: 'ORD-TEST-999',
        ext: 'png',
      );

      expect(uri, contains('data:image/png;base64,'));
    });

    testWidgets('4. SignaturePadModal renders mode toggle tabs (Draw vs Upload)', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SignaturePadModal(
              orderId: 'ORD-8821',
              customerName: 'Amina Bello',
            ),
          ),
        ),
      );

      expect(find.text('Customer Signature'), findsOneWidget);
      expect(find.text('Draw Signature'), findsOneWidget);
      expect(find.text('Upload Image / POD'), findsOneWidget);
      expect(find.text('Draw signature here'), findsOneWidget);

      // Switch to upload mode
      await tester.tap(find.text('Upload Image / POD'));
      await tester.pumpAndSettle();

      expect(find.text('Tap to choose signature or waybill photo'), findsOneWidget);
    });

    testWidgets('5. DCOrderDetailModal displays Proof of Delivery and Customer Signature Section', (tester) async {
      final sampleOrder = OrderEntity(
        id: 'ord-sig-1',
        orderNumber: 'ORD-7182',
        customerName: 'Tunde Bakare',
        customerPhone: '08012345678',
        deliveryState: 'Abuja',
        deliveryCity: 'Garki',
        deliveryAddress: 'Plot 42 Area 11',
        productName: 'Solar Inverter 5kVA',
        quantity: 1,
        basePrice: 250000.0,
        upsellAmount: 0.0,
        totalAmount: 250000.0,
        status: 'delivered',
        paymentType: 'pay_on_delivery',
        paymentStatus: 'remitted',
        createdAt: DateTime.now(),
        customerSignatureUrl: 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
      );

      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith((ref) => _MockAuthNotifier()),
            ordersProvider.overrideWith((ref) => _MockOrdersNotifier([sampleOrder])),
            stockProvider.overrideWith((ref) => _MockStockNotifier()),
            financeProvider.overrideWith((ref) => _MockFinanceNotifier()),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: DCOrderDetailModal(order: sampleOrder),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('📝 Digital Proof of Delivery (POD) & Customer Signature'), findsOneWidget);
      expect(find.text('✓ Customer Signature Verified & Stored'), findsOneWidget);
      expect(find.text('POD SIGNATURE RECORD'), findsOneWidget);
      expect(find.text('Recipient: Tunde Bakare'), findsOneWidget);
      expect(find.text('Update / Re-sign'), findsOneWidget);
    });
  });
}
