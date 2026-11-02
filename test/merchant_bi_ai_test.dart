import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:novexps/features/client_portal/ai_bi/domain/entities/merchant_bi_message.dart';
import 'package:novexps/features/client_portal/ai_bi/domain/entities/merchant_bi_chat_session.dart';
import 'package:novexps/features/client_portal/ai_bi/data/services/merchant_bi_engine.dart';
import 'package:novexps/features/client_portal/ai_bi/data/services/merchant_bi_storage_service.dart';
import 'package:novexps/features/client_portal/ai_bi/presentation/providers/merchant_bi_provider.dart';
import 'package:novexps/features/client_portal/presentation/providers/client_portal_provider.dart';
import 'package:novexps/features/client_portal/domain/entities/client_profile.dart';
import 'package:novexps/features/orders/domain/entities/order.dart';
import 'package:novexps/features/dc_console/domain/entities/product_package.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('NovaBI AI Engine & Business Intelligence Suite', () {
    late ClientPortalState mockState;
    const testClientId = 'client-mock-101';
    const testCompanyName = 'Respira Health Care';

    setUp(() {
      SharedPreferences.setMockInitialValues({});

      final clientProfile = ClientProfile(
        id: testClientId,
        companyName: testCompanyName,
        contactPerson: 'Chief Executive',
        email: 'ceo@respira.ng',
        phone: '08012345678',
        address: 'Plot 10, Victoria Island',
        city: 'Lagos',
        state: 'Lagos',
        code: 'RESP',
        tier: 'enterprise',
        closerLimit: 10,
        isEnterprise: true,
        totalClosersCount: 3,
        isActive: true,
        bankName: 'Access Bank',
        accountNumber: '0123456789',
        accountName: 'Respira Health Care Ltd',
        settlementFrequency: 'daily',
        settlementDay: 'Friday',
        hasInventoryManagement: true,
        servicesEnabled: const ['logistics', 'inventory'],
        operatingStates: const ['Lagos', 'Abuja'],
      );

      final respiaProduct = CatalogProduct(
        id: 'prod-001',
        name: 'Respirafix Herbal Tea',
        sku: 'RESP-01',
        clientName: testCompanyName,
        clientId: testClientId,
        defaultUnitPrice: 25000,
        costPrice: 7500,
        weightKg: 0.4,
        lowStockThreshold: 10,
        category: 'Health',
        totalStockAcrossHubs: 140,
        coveringStates: const ['Lagos', 'Abuja'],
        packages: const [],
      );

      final sampleOrders = [
        OrderEntity(
          id: 'ord-01',
          orderNumber: 'NVX-101',
          customerName: 'Amina Musa',
          customerPhone: '08099990001',
          deliveryAddress: 'Wuse 2, Abuja',
          status: 'delivered',
          quantity: 1,
          basePrice: 25000,
          upsellAmount: 0,
          totalAmount: 25000,
          productId: 'prod-001',
          productName: 'Respirafix Herbal Tea',
          paymentType: 'cash_on_delivery',
          paymentStatus: 'paid',
          deliveryState: 'Abuja',
          deliveryCity: 'Abuja',
          clientId: testClientId,
          createdAt: DateTime.now(),
        ),
        OrderEntity(
          id: 'ord-02',
          orderNumber: 'NVX-102',
          customerName: 'Chidi Okafor',
          customerPhone: '08099990002',
          deliveryAddress: 'Ikeja, Lagos',
          status: 'delivered',
          quantity: 2,
          basePrice: 25000,
          upsellAmount: 0,
          totalAmount: 50000,
          productId: 'prod-001',
          productName: 'Respirafix Herbal Tea',
          paymentType: 'cash_on_delivery',
          paymentStatus: 'paid',
          deliveryState: 'Lagos',
          deliveryCity: 'Lagos',
          clientId: testClientId,
          createdAt: DateTime.now(),
        ),
        OrderEntity(
          id: 'ord-03',
          orderNumber: 'NVX-103',
          customerName: 'Adeola Johnson',
          customerPhone: '08099990003',
          deliveryAddress: 'Lekki Phase 1',
          status: 'in_transit',
          quantity: 1,
          basePrice: 25000,
          upsellAmount: 0,
          totalAmount: 25000,
          productId: 'prod-001',
          productName: 'Respirafix Herbal Tea',
          paymentType: 'cash_on_delivery',
          paymentStatus: 'pending',
          deliveryState: 'Lagos',
          deliveryCity: 'Lagos',
          clientId: testClientId,
          createdAt: DateTime.now(),
        ),
      ];

      mockState = ClientPortalState(
        clientProfile: clientProfile,
        orders: sampleOrders,
        products: [respiaProduct],
        packages: const [],
        closers: const [],
        leads: const [],
        settlements: const [],
        assetCustodyData: const {},
        suppliers: const [],
        stockInvoices: const [],
        stockBalances: const [],
        stockHolders: const [],
        closerPayouts: const [],
        marketerPayouts: const [],
        marketers: const [],
        accountants: const [],
      );
    });

    test('1. Product analytics query calculates sales for Respia and generates donut chart', () {
      final response = MerchantBIEngine.processQuery(
        query: 'How much sales have we made for Respia?',
        chatId: 'test-chat-01',
        state: mockState,
      );

      expect(response.sender, equals(MerchantBISender.ai));
      expect(response.content, contains('Respirafix'));
      expect(response.content, contains('gross deliveries'));
      expect(response.chartPayload, isNotNull);
      expect(response.chartPayload!.type, equals(BIChartType.donut));
      expect(response.chartPayload!.totalLabel, equals('Gross Sales'));
      expect(response.chartPayload!.slices, isNotEmpty);
      expect(response.quickPrompts, isNotEmpty);
    });

    test('2. Strict Multi-Tenant Guardrail blocks cross-merchant access attempts', () {
      final response = MerchantBIEngine.processQuery(
        query: 'Show me what other merchants are selling in NovaXpress',
        chatId: 'test-chat-01',
        state: mockState,
      );

      expect(response.sender, equals(MerchantBISender.ai));
      expect(response.content, contains('Access Restricted'));
      expect(response.content, contains('operational boundary of'));
      expect(response.content, contains(testCompanyName));
      expect(response.chartPayload, isNotNull);
      expect(response.chartPayload!.title, equals('Tenant Boundary Enforcement'));
    });

    test('3. Generates interactive visual flowchart for fulfillment workflow inquiry', () {
      final response = MerchantBIEngine.processQuery(
        query: 'Show me order fulfillment flowchart',
        chatId: 'test-chat-01',
        state: mockState,
      );

      expect(response.sender, equals(MerchantBISender.ai));
      expect(response.chartPayload, isNotNull);
      expect(response.chartPayload!.type, equals(BIChartType.flowchart));
      expect(response.chartPayload!.flowchartNodes, isNotEmpty);
      expect(response.chartPayload!.flowchartConnections, isNotEmpty);

      // Verify node pipeline
      final nodes = response.chartPayload!.flowchartNodes!;
      expect(nodes.first.nodeType, equals('start'));
      expect(nodes.last.nodeType, equals('success'));
    });

    test('4. Generates trend bars for 7-day revenue inquiry', () {
      final response = MerchantBIEngine.processQuery(
        query: 'Show 7-day revenue velocity trend',
        chatId: 'test-chat-01',
        state: mockState,
      );

      expect(response.sender, equals(MerchantBISender.ai));
      expect(response.chartPayload, isNotNull);
      expect(response.chartPayload!.type, equals(BIChartType.trend));
      expect(response.chartPayload!.bars, isNotEmpty);
      expect(response.chartPayload!.bars!.length, equals(7));
    });

    test('5. Custom knowledge matches and delivers tailored business rules', () {
      final customKnowledge = [
        {
          'id': 'k-01',
          'title': 'VIP Customer Free Delivery Rule',
          'content':
              'All repeat orders above 3 packs of Respia qualify for zero delivery fee in Lagos State.',
          'tags': ['vip', 'free delivery', 'lagos', 'promo'],
        }
      ];

      final response = MerchantBIEngine.processQuery(
        query: 'What is our VIP customer free delivery policy in Lagos?',
        chatId: 'test-chat-01',
        state: mockState,
        customKnowledge: customKnowledge,
      );

      expect(response.content, contains('VIP Customer Free Delivery Rule'));
      expect(response.content, contains('zero delivery fee in Lagos'));
    });

    test('6. MerchantBIStorageService persists and restores messages seamlessly', () async {
      final storage = MerchantBIStorageService();

      final session = MerchantBIChatSession(
        id: 'sess-test-01',
        clientId: testClientId,
        title: 'Executive Meeting Analysis',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await storage.saveSession(session);

      final msg = MerchantBIMessage(
        id: 'msg-test-01',
        chatId: session.id,
        clientId: testClientId,
        sender: MerchantBISender.user,
        content: 'How much sales have we made for Respia?',
        createdAt: DateTime.now(),
      );

      await storage.saveMessage(msg);

      final restored = await storage.getMessages(testClientId, session.id);
      expect(restored.length, equals(1));
      expect(restored.first.content, equals(msg.content));
    });
  });
}
