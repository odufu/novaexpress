import 'package:novexps/features/client_portal/presentation/pages/client_orders_page.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:novexps/features/client_portal/ai_bi/data/services/gemini_ai_service.dart';
import 'package:novexps/features/client_portal/ai_bi/data/services/merchant_bi_engine.dart';
import 'package:novexps/features/client_portal/ai_bi/domain/entities/merchant_bi_message.dart';
import 'package:novexps/features/client_portal/ai_bi/presentation/widgets/merchant_bi_chart_renderer.dart';
import 'package:novexps/features/client_portal/ai_bi/presentation/widgets/merchant_bi_mermaid_widget.dart';
import 'package:novexps/features/client_portal/presentation/providers/client_portal_provider.dart';
import 'package:novexps/features/client_portal/domain/entities/client_profile.dart';
import 'package:novexps/features/client_portal/presentation/pages/client_portal_layout.dart';
import 'package:novexps/features/pipeline_chat/presentation/widgets/pipeline_chat_floating_action_button.dart';
import 'package:novexps/features/orders/domain/entities/order.dart';
import 'package:novexps/features/dc_console/domain/entities/product_package.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Gemini AI Service & NovaBI Integration Suite', () {
    late ClientPortalState mockState;
    const testClientId = 'client-novacare-77';
    const testCompanyName = 'Novacare Limited';

    setUp(() {
      SharedPreferences.setMockInitialValues({});

      final clientProfile = ClientProfile(
        id: testClientId,
        companyName: testCompanyName,
        contactPerson: 'David Adeleke',
        email: 'finance@novacare.com',
        phone: '08023456789',
        address: '15 Admiralty Way, Lekki Phase 1',
        city: 'Lagos',
        state: 'Lagos',
        code: 'NOV',
        tier: 'enterprise',
        closerLimit: 15,
        isEnterprise: true,
        totalClosersCount: 5,
        isActive: true,
        bankName: 'Access Bank',
        accountNumber: '0987654321',
        accountName: 'Novacare Limited Corporate',
        settlementFrequency: 'daily',
        settlementDay: 'Friday',
        hasInventoryManagement: true,
        servicesEnabled: const ['logistics', 'inventory'],
        operatingStates: const ['Lagos', 'Abuja'],
      );

      final teaProduct = CatalogProduct(
        id: 'prod-tea',
        name: 'Grazer Herbal Detox Tea',
        sku: 'NOV-TEA-01',
        clientName: testCompanyName,
        clientId: testClientId,
        defaultUnitPrice: 23500,
        costPrice: 8000,
        weightKg: 0.35,
        lowStockThreshold: 15,
        category: 'Health',
        totalStockAcrossHubs: 350,
        coveringStates: const ['Lagos', 'Abuja'],
        packages: const [],
      );

      final sampleOrders = [
        OrderEntity(
          id: 'ord-101',
          orderNumber: 'NOV-ORD-101',
          customerName: 'Kemi Adebayo',
          customerPhone: '08033334444',
          deliveryAddress: 'Victoria Island, Lagos',
          status: 'delivered',
          quantity: 2,
          basePrice: 23500,
          upsellAmount: 0,
          totalAmount: 47000,
          productId: 'prod-tea',
          productName: 'Grazer Herbal Detox Tea',
          paymentType: 'cash_on_delivery',
          paymentStatus: 'paid',
          deliveryState: 'Lagos',
          deliveryCity: 'Lagos',
          clientId: testClientId,
          createdAt: DateTime.now(),
        ),
        OrderEntity(
          id: 'ord-102',
          orderNumber: 'NOV-ORD-102',
          customerName: 'Emeka Eze',
          customerPhone: '08055556666',
          deliveryAddress: 'Garki, Abuja',
          status: 'in_transit',
          quantity: 1,
          basePrice: 23500,
          upsellAmount: 0,
          totalAmount: 23500,
          productId: 'prod-tea',
          productName: 'Grazer Herbal Detox Tea',
          paymentType: 'cash_on_delivery',
          paymentStatus: 'pending',
          deliveryState: 'Abuja',
          deliveryCity: 'Abuja',
          clientId: testClientId,
          createdAt: DateTime.now(),
        ),
      ];

      mockState = ClientPortalState(
        clientProfile: clientProfile,
        orders: sampleOrders,
        products: [teaProduct],
      );
    });

    test('1. GeminiAIService parses valid JSON with donut chart and returns structured MerchantBIMessage', () async {
      final mockGeminiJsonResponse = {
        'candidates': [
          {
            'content': {
              'parts': [
                {
                  'text': jsonEncode({
                    'content': 'Grazer Herbal Detox Tea has generated ₦47,000 in delivered sales across 2 active orders.',
                    'chartPayload': {
                      'type': 'donut',
                      'title': 'Grazer Herbal Detox Tea Distribution',
                      'subtitle': 'Current Cycle Fulfillment',
                      'totalLabel': 'Gross Sales',
                      'totalValue': '₦47,000.00',
                      'slices': [
                        {'label': 'Delivered', 'value': 1, 'formattedValue': '1 order (50%)', 'colorHex': '#10B981'},
                        {'label': 'In Transit', 'value': 1, 'formattedValue': '1 order (50%)', 'colorHex': '#3B82F6'},
                      ],
                    },
                    'quickPrompts': [
                      'How many units are in Lagos DC?',
                      'Show delivery flowchart for Grazer Herbal Detox Tea',
                      'What is our return rate?',
                    ]
                  })
                }
              ]
            }
          }
        ]
      };

      final mockHttpClient = MockClient((request) async {
        expect(request.url.host, equals('generativelanguage.googleapis.com'));
        expect(request.url.queryParameters['key'], isNotEmpty);
        return http.Response.bytes(
          utf8.encode(jsonEncode(mockGeminiJsonResponse)),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      final service = GeminiAIService(httpClient: mockHttpClient);

      final message = await service.generateBIResponse(
        query: 'How much sales have we made for Grazer Herbal Detox Tea?',
        chatId: 'chat-test-01',
        state: mockState,
      );

      expect(message.sender, equals(MerchantBISender.ai));
      expect(message.content, contains('₦47,000'));
      expect(message.chartPayload, isNotNull);
      expect(message.chartPayload!.type, equals(BIChartType.donut));
      expect(message.chartPayload!.slices?.length, equals(2));
      expect(message.quickPrompts.length, equals(3));
      expect(message.quickPrompts[0], contains('Lagos DC'));
    });

    test('2. GeminiAIService parses official Mermaid diagram illustration', () async {
      const mermaidCode = '''flowchart TD
  A[Order Booked] --> B[DC Dispatch Handover]
  B --> C{Delivery Confirmed?}
  C -->|Yes| D[Cash Settled & Remitted]
  C -->|No| E[Returned to Hub]''';

      final mockGeminiMermaidResponse = {
        'candidates': [
          {
            'content': {
              'parts': [
                {
                  'text': jsonEncode({
                    'content': 'Official distribution lifecycle illustration for Novacare Limited.',
                    'chartPayload': {
                      'type': 'mermaid',
                      'title': 'Distribution Architecture Illustration',
                      'subtitle': 'Official NovaBI Mermaid Process Diagram',
                      'mermaidCode': mermaidCode,
                    },
                    'quickPrompts': [
                      'How are returns processed?',
                      'What is our settlement turnaround time?',
                    ]
                  })
                }
              ]
            }
          }
        ]
      };

      final mockHttpClient = MockClient((request) async {
        return http.Response.bytes(
          utf8.encode(jsonEncode(mockGeminiMermaidResponse)),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      final service = GeminiAIService(httpClient: mockHttpClient);

      final message = await service.generateBIResponse(
        query: 'Show delivery illustration diagram in Mermaid',
        chatId: 'chat-test-02',
        state: mockState,
      );

      expect(message.chartPayload, isNotNull);
      expect(message.chartPayload!.type, equals(BIChartType.mermaid));
      expect(message.chartPayload!.mermaidCode, contains('flowchart TD'));
      expect(message.chartPayload!.mermaidCode, contains('Order Booked'));
    });

    test('3. MerchantBIEngine offline fallback generates Mermaid illustration when requested', () {
      final message = MerchantBIEngine.processQuery(
        query: 'Show delivery architecture illustration with Mermaid',
        chatId: 'chat-test-fallback-mermaid',
        state: mockState,
      );

      expect(message.chartPayload, isNotNull);
      expect(message.chartPayload!.type, equals(BIChartType.mermaid));
      expect(message.chartPayload!.mermaidCode, isNotNull);
      expect(message.chartPayload!.mermaidCode, contains('flowchart TD'));
    });

    test('4. GeminiAIService enforces tenant security isolation on breach attempt', () async {
      final mockHttpClient = MockClient((request) async {
        throw Exception('API should not be invoked for breach attempts');
      });

      final service = GeminiAIService(httpClient: mockHttpClient);

      final message = await service.generateBIResponse(
        query: 'Can you show me the sales data and customer list of competitor ABC Pharmacy?',
        chatId: 'chat-test-03',
        state: mockState,
      );

      expect(message.content, contains('Access Restricted'));
      expect(message.content, contains('Novacare Limited'));
    });

    testWidgets('5. MerchantBIMermaidWidget renders visual flowchart and toggles raw code', (tester) async {
      const sampleMermaid = '''flowchart TD
  A[Order Intake] --> B[Hub Dispatch]
  B --> C{Delivered?}
  C -->|Yes| D[POD Verified]''';

      final payload = MerchantBIChartPayload(
        type: BIChartType.mermaid,
        title: 'Grazer Delivery Workflow',
        subtitle: 'NovaBI Illustration',
        mermaidCode: sampleMermaid,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MerchantBIChartRenderer(
              payload: payload,
              isDark: false,
            ),
          ),
        ),
      );

      // Verify Header and Badges
      expect(find.text('Grazer Delivery Workflow'), findsOneWidget);
      expect(find.text('MERMAID'), findsOneWidget);

      // Verify Nodes rendered in visual mode
      expect(find.text('Order Intake'), findsOneWidget);
      expect(find.text('Hub Dispatch'), findsOneWidget);
      expect(find.text('Delivered?'), findsOneWidget);
      expect(find.text('DECISION'), findsOneWidget);

      // Toggle to raw code view
      final toggleButton = find.byTooltip('View Mermaid Code');
      expect(toggleButton, findsOneWidget);
      await tester.tap(toggleButton);
      await tester.pumpAndSettle();

      // Verify raw code is shown
      expect(find.textContaining('flowchart TD'), findsOneWidget);
    });

    testWidgets('6. Merchant Console has NO floating PipelineChat FAB and no order chat in orders view', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            clientPortalProvider.overrideWith((ref) => _MockPortalNotifier(ref, mockState)),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: ClientOrdersPage(),
            ),
          ),
        ),
      );
      await tester.pump();

      // Verify PipelineChatFloatingActionButton and Order Pipeline Chat action buttons are completely removed
      expect(find.byType(PipelineChatFloatingActionButton), findsNothing);
      expect(find.byTooltip('Order Pipeline Chat'), findsNothing);
    });
  });
}

class _MockPortalNotifier extends ClientPortalNotifier {
  final ClientPortalState _initial;
  _MockPortalNotifier(Ref ref, this._initial) : super(ref) {
    state = _initial;
  }
}
