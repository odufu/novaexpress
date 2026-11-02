import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import '../../../../../core/constants/gemini_constants.dart';
import '../../../presentation/providers/client_portal_provider.dart';
import '../../domain/entities/merchant_bi_message.dart';
import 'merchant_bi_engine.dart';

/// Production Google Gemini AI service powering NovaBI Copilot
class GeminiAIService {
  static final GeminiAIService instance = GeminiAIService._internal();
  GeminiAIService._internal();

  factory GeminiAIService({http.Client? httpClient}) {
    if (httpClient != null) {
      return GeminiAIService._withClient(httpClient);
    }
    return instance;
  }

  GeminiAIService._withClient(this._client);
  http.Client? _client;

  http.Client get _httpClient => _client ?? http.Client();

  static final _currencyFormat = NumberFormat.currency(
    locale: 'en_NG',
    symbol: '₦',
    decimalDigits: 2,
  );

  /// Generate intelligent, data-dense BI response powered by Google Gemini
  Future<MerchantBIMessage> generateBIResponse({
    required String query,
    required String chatId,
    required ClientPortalState state,
    List<Map<String, dynamic>> customKnowledge = const [],
    String? overrideApiKey,
  }) async {
    final client = state.clientProfile;
    final apiKey = (overrideApiKey != null && overrideApiKey.isNotEmpty)
        ? overrideApiKey
        : GeminiConstants.apiKey;

    // 1. Strict Client-side Tenant Guardrail Check
    final normalized = query.trim().toLowerCase();
    if (_isSecurityBreachAttempt(normalized, client.id, client.companyName)) {
      return MerchantBIEngine.processQuery(
        query: query,
        chatId: chatId,
        state: state,
        customKnowledge: customKnowledge,
      );
    }

    // 2. Build live enterprise data snapshot for this merchant
    final businessContext = _buildEnterpriseBusinessContext(state, customKnowledge);

    // 3. Assemble Gemini System Instructions & Prompt
    final systemPrompt = '''
You are NovaBI, the intelligent enterprise AI Business Intelligence Copilot for ${client.companyName}.
You are strictly scoped to ${client.companyName} (Tenant ID: ${client.id}).

ENTERPRISE SCOPE & SECURITY RULES:
1. STRICT MULTI-TENANT ISOLATION: You have zero access to other merchants, competitors, or internal platform credentials. If the user asks about another merchant or platform-wide confidential metrics, decline politely, citing single-tenant enterprise isolation.
2. CONCISE & DATA-DENSE: Provide actionable business answers. Avoid conversational filler or long pleasantries. Present processed metrics, calculations, percentages, and summaries.
3. VISUALIZATION & DIAGRAM ILLUSTRATION CHOICE:
   - OFFICIAL ILLUSTRATION DIAGRAM: Mermaid is NovaBI's official illustration diagram language!
   - When the user asks for illustrations, architecture diagrams, sequence of delivery events, distribution lifecycles, failure recovery, or workflow flowcharts -> Output chartPayload with type "mermaid" and provide clean, valid Mermaid syntax in "mermaidCode" (e.g. flowchart TD, graph LR, sequenceDiagram, etc.). You can also embed ```mermaid code blocks in your markdown text.
   - When the user asks about sales distribution, order statuses, or product consignment shares -> Output chartPayload with type "donut".
   - When the user asks about revenue over time, 7-day velocity, or growth trends -> Output chartPayload with type "trend".
   - When the user asks for a high-level summary or KPI overview -> Output chartPayload with type "metricCards".
   - When the user asks a quick textual question -> Output chartPayload with type "metricCards" or omit chartPayload.

LIVE ENTERPRISE BUSINESS SNAPSHOT:
$businessContext

OUTPUT FORMAT:
You MUST respond strictly with valid JSON conforming to this schema:
{
  "content": "Informative, concise executive explanation answering the merchant's question directly.",
  "chartPayload": {
    "type": "mermaid" | "donut" | "trend" | "flowchart" | "metricCards",
    "title": "Chart Title",
    "mermaidCode": "flowchart TD\n  A[Order Booked] --> B[DC Dispatch Handover]\n  B --> C{Delivery Successful?}\n  C -->|Yes| D[Cash Settled & Remitted]\n  C -->|No| E[Returned to Hub]", 
    "subtitle": "Brief subtitle or period",
    "totalLabel": "Gross Sales or Total",
    "totalValue": "formatted ₦ or count",
    "slices": [
      {"label": "Delivered", "value": 45, "formattedValue": "45 orders (90%)", "colorHex": "#10B981"}
    ],
    "bars": [
      {"label": "Mon", "value": 150000, "formattedValue": "₦150,000", "colorHex": "#F37021"}
    ],
    "flowchartNodes": [
      {"id": "n1", "stepNumber": "1", "title": "Dispatch Handover", "description": "Package assigned to rider", "nodeType": "process", "iconName": "local_shipping"}
    ],
    "flowchartConnections": [
      {"fromId": "n1", "toId": "n2", "label": "In Transit"}
    ],
    "metricBadges": [
      {"label": "Gross Sales", "value": "₦117,500.00", "isPositive": true, "iconName": "payments"}
    ]
  },
  "quickPrompts": [
    "Contextual follow-up question 1",
    "Contextual follow-up question 2",
    "Contextual follow-up question 3"
  ]
}
''';

    // 4. Attempt call to Gemini with model fallback
    final modelsToTry = [
      GeminiConstants.primaryModel,
      GeminiConstants.fallbackModel,
      GeminiConstants.backupModel,
    ];

    for (final model in modelsToTry) {
      try {
        final result = await _callGeminiApi(
          model: model,
          apiKey: apiKey,
          systemPrompt: systemPrompt,
          userQuery: query,
        );

        if (result != null) {
          final message = _parseGeminiResponse(
            jsonResponse: result,
            chatId: chatId,
            clientId: client.id,
            fallbackState: state,
          );
          if (message != null) {
            return message;
          }
        }
      } catch (e) {
        debugPrint('[GEMINI_AI_SERVICE] ⚠️ Error on model $model: $e');
        // Proceed to next fallback model
      }
    }

    // 5. Seamless fallback to deterministic engine if all network calls fail
    debugPrint('[GEMINI_AI_SERVICE] ℹ️ Falling back to deterministic on-device intelligence engine.');
    return MerchantBIEngine.processQuery(
      query: query,
      chatId: chatId,
      state: state,
      customKnowledge: customKnowledge,
    );
  }

  /// REST call to Google Gemini GenerateContent API
  Future<Map<String, dynamic>?> _callGeminiApi({
    required String model,
    required String apiKey,
    required String systemPrompt,
    required String userQuery,
  }) async {
    final endpoint = Uri.parse(
      '${GeminiConstants.apiBaseUrl}$model:generateContent?key=$apiKey',
    );

    final requestBody = jsonEncode({
      'systemInstruction': {
        'parts': [
          {'text': systemPrompt}
        ]
      },
      'contents': [
        {
          'role': 'user',
          'parts': [
            {'text': userQuery}
          ]
        }
      ],
      'generationConfig': {
        'responseMimeType': 'application/json',
        'temperature': 0.2,
      },
    });

    final response = await _httpClient
        .post(
          endpoint,
          headers: {'Content-Type': 'application/json'},
          body: requestBody,
        )
        .timeout(const Duration(seconds: 12));

    if (response.statusCode == 200) {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final candidates = decoded['candidates'] as List?;
      if (candidates != null && candidates.isNotEmpty) {
        final content = candidates[0]['content'] as Map<String, dynamic>?;
        final parts = content?['parts'] as List?;
        if (parts != null && parts.isNotEmpty) {
          final rawText = parts[0]['text']?.toString() ?? '';
          if (rawText.isNotEmpty) {
            return jsonDecode(rawText) as Map<String, dynamic>;
          }
        }
      }
    } else {
      debugPrint('[GEMINI_AI_SERVICE] API Error ${response.statusCode}: ${response.body}');
      throw Exception('Gemini API returned status ${response.statusCode}');
    }

    return null;
  }

  /// Parse structured JSON from Gemini into a MerchantBIMessage
  MerchantBIMessage? _parseGeminiResponse({
    required Map<String, dynamic> jsonResponse,
    required String chatId,
    required String clientId,
    required ClientPortalState fallbackState,
  }) {
    try {
      final content = jsonResponse['content']?.toString() ??
          'Here is the executive analysis for your business request:';

      MerchantBIChartPayload? chartPayload;
      if (jsonResponse['chartPayload'] is Map) {
        chartPayload = MerchantBIChartPayload.fromJson(
          Map<String, dynamic>.from(jsonResponse['chartPayload'] as Map),
        );
      }

      List<String> quickPrompts = const [
        'How much sales have we made?',
        'What is our delivery success rate?',
        'Show fulfillment flowchart',
      ];

      if (jsonResponse['quickPrompts'] is List) {
        quickPrompts = (jsonResponse['quickPrompts'] as List)
            .map((e) => e.toString().trim())
            .where((s) => s.isNotEmpty)
            .take(3)
            .toList();
      }

      return MerchantBIMessage(
        id: 'msg-${DateTime.now().millisecondsSinceEpoch}',
        chatId: chatId,
        clientId: clientId,
        sender: MerchantBISender.ai,
        content: content,
        chartPayload: chartPayload,
        quickPrompts: quickPrompts,
        createdAt: DateTime.now(),
      );
    } catch (e) {
      debugPrint('[GEMINI_AI_SERVICE] JSON parsing error: $e');
      return null;
    }
  }

  /// Build live enterprise business data snapshot for context injection
  String _buildEnterpriseBusinessContext(
    ClientPortalState state,
    List<Map<String, dynamic>> customKnowledge,
  ) {
    final client = state.clientProfile;
    final orders = state.orders;
    final products = state.products;

    // Delivery metrics
    final totalOrders = orders.length;
    final deliveredOrders = orders.where((o) => o.status.toLowerCase() == 'delivered').toList();
    final inTransitOrders = orders.where((o) =>
        o.status.toLowerCase() == 'in_transit' ||
        o.status.toLowerCase() == 'dispatched' ||
        o.status.toLowerCase() == 'assigned').toList();
    final pendingOrders = orders.where((o) =>
        o.status.toLowerCase() == 'pending' ||
        o.status.toLowerCase() == 'unassigned' ||
        o.status.toLowerCase() == 'processing').toList();
    final failedOrders = orders.where((o) =>
        o.status.toLowerCase() == 'failed' ||
        o.status.toLowerCase() == 'returned' ||
        o.status.toLowerCase() == 'cancelled').toList();

    final grossRevenue = deliveredOrders.fold(0.0, (sum, o) => sum + o.totalAmount);
    final successRate = totalOrders > 0
        ? ((deliveredOrders.length / totalOrders) * 100).toStringAsFixed(1)
        : '0.0';

    // Product sales breakdown
    final Map<String, double> salesByProduct = {};
    final Map<String, int> countByProduct = {};
    for (final o in orders) {
      final name = o.productName.isNotEmpty ? o.productName : 'Standard Item';
      salesByProduct[name] = (salesByProduct[name] ?? 0.0) + o.totalAmount;
      countByProduct[name] = (countByProduct[name] ?? 0) + 1;
    }

    final productLines = salesByProduct.entries.map((e) {
      final name = e.key;
      final total = _currencyFormat.format(e.value);
      final count = countByProduct[name] ?? 0;
      return '- Product: "$name", Total Orders: $count, Total Value: $total';
    }).join('\n');

    // Custody & stock balances
    final stockLines = products.map((p) {
      return '- Catalog Item: "${p.name}", SKU: "${p.sku}", Unit Price: ${_currencyFormat.format(p.defaultUnitPrice)}, Stock: ${p.totalStockAcrossHubs} units';
    }).join('\n');

    // Custom Merchant Knowledge items
    final knowledgeLines = customKnowledge.isNotEmpty
        ? customKnowledge.map((k) => '- ${k['title']}: ${k['content']}').join('\n')
        : 'None recorded.';

    return '''
Company: ${client.companyName}
Contact: ${client.contactPerson} (${client.phone}, ${client.email})
Payout Destination: ${client.bankName} - Account: ${client.accountNumber} (${client.accountName})

LIVE FULFILLMENT & SALES TELEMETRY:
- Total Consignments: $totalOrders
- Delivered: ${deliveredOrders.length} (${successRate}% success rate)
- Gross Delivered Sales: ${_currencyFormat.format(grossRevenue)}
- Currently In Transit: ${inTransitOrders.length}
- Pending Dispatch: ${pendingOrders.length}
- Delivery Exceptions / Failed: ${failedOrders.length}

PRODUCT REVENUE BREAKDOWN:
${productLines.isNotEmpty ? productLines : "No order transactions recorded yet."}

PRODUCT CATALOG:
${stockLines.isNotEmpty ? stockLines : "Standard catalog products."}

MERCHANT OPERATIONAL KNOWLEDGE & FAQ:
$knowledgeLines
''';
  }

  /// Tenant boundary check
  bool _isSecurityBreachAttempt(String query, String clientId, String companyName) {
    final lower = query.toLowerCase();
    final otherTenants = [
      'other client',
      'other merchant',
      'competitor',
      'all clients',
      'system secrets',
      'service_role',
      'database password',
      'admin password',
      'supabase key',
      'other companies',
    ];

    for (final flag in otherTenants) {
      if (lower.contains(flag)) return true;
    }
    return false;
  }
}
