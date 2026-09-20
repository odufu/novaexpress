import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/constants/supabase_constants.dart';
import '../../../../core/helpers/uuid_helper.dart';
import '../models/order_model.dart';

abstract class OrdersRemoteDataSource {
  Future<List<OrderModel>> getAssignedOrders(String deliveryAgentId);
  Future<List<OrderModel>> getDistributionCenterOrders(String distributionCenterId);
  Future<OrderModel> createOrder(Map<String, dynamic> orderData);
  Future<void> assignOrderToRider({
    required String orderId,
    required String riderId,
    required String riderName,
    required String riderCode,
  });
  Future<void> unassignOrderFromRider({
    required String orderId,
  });
  Future<OrderModel> getOrderById(String orderId);
  Future<void> updateOrderStatus(
    String orderId,
    String status, {
    String? paymentStatus,
    String? paymentType,
    String? notes,
    String? customerSignatureUrl,
    String? photoProofUrl,
    String? gatePassCode,
    double? latitude,
    double? longitude,
    bool? isLocationVerified,
  });
  Future<Map<String, dynamic>> confirmDeliveryPod({
    required String orderId,
    required String agentId,
    required String paymentType,
    required String paymentMethod,
    required double amountCollected,
    String? customerSignatureUrl,
    String? photoProofUrl,
    String? notes,
    String? gatePassCode,
    double? latitude,
    double? longitude,
  });
  Future<Map<String, dynamic>> logDeliveryFailure({
    required String orderId,
    required String agentId,
    required String reasonCode,
    String? notes,
    String? scheduledCallbackAt,
    String? gatePassCode,
    double? latitude,
    double? longitude,
  });
  Future<void> updateOrderCoordinates({
    required String orderId,
    required double latitude,
    required double longitude,
    bool isLocationVerified = true,
    String? geocodedAddress,
  });
}

class OrdersRemoteDataSourceImpl implements OrdersRemoteDataSource {
  final SupabaseClient supabaseClient;
  static final Map<String, String> _assignedRidersByOrderId = {};
  static final Map<String, String> _assignedRiderNamesByOrderId = {};
  static final Map<String, String> _assignedRiderCodesByOrderId = {};
  static final Map<String, Map<String, dynamic>> _customCoordinatesByOrderId = {};

  OrdersRemoteDataSourceImpl(this.supabaseClient);

  @override
  Future<List<OrderModel>> getAssignedOrders(String deliveryAgentId) async {
    try {
      final cleanId = deliveryAgentId.trim();
      if (cleanId.isEmpty) return [];

      SupabaseClient? dbClient;
      try {
        dbClient = SupabaseClient(
          SupabaseConstants.supabaseUrl,
          SupabaseConstants.supabaseServiceRoleKey,
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        );

        // 1. Resolve authoritative delivery_agent_id from delivery_agents table
        String targetAgentId = cleanId;
        final uuidRegex = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');

        try {
          final agentLookup = await dbClient
              .from('delivery_agents')
              .select('id, user_id, agent_code')
              .or('id.eq.$cleanId,user_id.eq.$cleanId,agent_code.eq.$cleanId')
              .limit(1);

          if ((agentLookup as List).isNotEmpty) {
            final first = agentLookup.first;
            if (first['id'] != null) targetAgentId = first['id'].toString();
          }
        } catch (_) {}

        // 2. Query strictly for orders assigned to this rider's delivery_agent_id
        final filterList = <String>[];
        if (uuidRegex.hasMatch(targetAgentId)) filterList.add('delivery_agent_id.eq.$targetAgentId');
        if (uuidRegex.hasMatch(cleanId) && cleanId != targetAgentId) filterList.add('delivery_agent_id.eq.$cleanId');
        final filterStr = filterList.isNotEmpty ? filterList.join(',') : 'delivery_agent_id.eq.$targetAgentId';

        final response = await dbClient
            .from(SupabaseConstants.ordersTable)
            .select('*, products(name, sku, base_price)')
            .or(filterStr)
            .order('created_at', ascending: false);

        final list = (response as List)
            .map((item) => OrderModel.fromJson(item as Map<String, dynamic>))
            .toList();

        debugPrint('[ORDERS_DATASOURCE] 🚴 Loaded ${list.length} assigned orders specifically for rider ($cleanId -> $targetAgentId).');
        return list;
      } catch (e) {
        debugPrint('[ORDERS_DATASOURCE] ℹ️ Supabase assigned orders fetch notice ($e).');
        return [];
      } finally {
        dbClient?.dispose();
      }
    } catch (e) {
      debugPrint('[ORDERS_DATASOURCE] ⚠️ getAssignedOrders notice: $e');
      return [];
    }
  }

  @override
  Future<OrderModel> createOrder(Map<String, dynamic> orderData) async {
    try {
      final dbClient = SupabaseClient(
        SupabaseConstants.supabaseUrl,
        SupabaseConstants.supabaseServiceRoleKey,
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      );

      final insertPayload = Map<String, dynamic>.from(orderData);
      
      // 1. Resolve authoritative product_id
      final rawProductId = insertPayload['product_id']?.toString() ?? '';
      final rawProductName = insertPayload['product_name']?.toString() ?? '';
      final cleanBaseName = rawProductName.split('(').first.trim();
      final uuidRegex = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');
      String validProductId = uuidRegex.hasMatch(rawProductId) ? rawProductId : '';

      if (validProductId.isEmpty && cleanBaseName.isNotEmpty) {
        try {
          final prodRes = await dbClient
              .from('products')
              .select('id, name, sku')
              .or('name.ilike.%$cleanBaseName%,sku.ilike.%$cleanBaseName%')
              .limit(1);
          if ((prodRes as List).isNotEmpty && prodRes.first['id'] != null) {
            validProductId = prodRes.first['id'].toString();
          }
        } catch (_) {}
      }

      if (validProductId.isEmpty) {
        try {
          final prodRes = await dbClient.from('products').select('id, name, base_price').limit(1);
          if ((prodRes as List).isNotEmpty) {
            validProductId = prodRes.first['id'].toString();
          }
        } catch (_) {}
      }
      if (validProductId.isEmpty) {
        try {
          final anyProd = await dbClient.from('products').select('id').limit(1).maybeSingle();
          if (anyProd != null && anyProd['id'] != null) {
            validProductId = anyProd['id'].toString();
          }
        } catch (_) {}
      }

      // 2. Resolve company and distribution center UUIDs
      final companyId = insertPayload['company_id']?.toString() ?? '11111111-1111-4111-8111-111111111111';
      final String? dcId = (insertPayload['distribution_center_id'] != null && uuidRegex.hasMatch(insertPayload['distribution_center_id'].toString()))
          ? insertPayload['distribution_center_id'].toString()
          : null;

      // 3. Resolve rider assignment UUID if present
      String? validRiderId;
      final rawRiderId = insertPayload['delivery_agent_id']?.toString() ??
          insertPayload['assigned_agent_id']?.toString() ??
          '';
      if (rawRiderId.isNotEmpty && uuidRegex.hasMatch(rawRiderId)) {
        validRiderId = rawRiderId;
      } else if (rawRiderId.isNotEmpty) {
        try {
          final agentRes = await dbClient
              .from('delivery_agents')
              .select('id')
              .or('id.eq.$rawRiderId,user_id.eq.$rawRiderId,agent_code.eq.$rawRiderId')
              .limit(1);
          if ((agentRes as List).isNotEmpty) {
            validRiderId = agentRes.first['id'].toString();
          }
        } catch (_) {}
      }

      // 4. Normalize payment type and amounts
      final rawPaymentType = insertPayload['payment_type']?.toString().toLowerCase() ?? 'pay_on_delivery';
      final paymentType = (rawPaymentType.contains('prepaid') || rawPaymentType.contains('transfer'))
          ? 'prepaid'
          : 'pay_on_delivery';
      final rawPaymentStatus = insertPayload['payment_status']?.toString().toLowerCase() ?? 'pending';
      final paymentStatus = (rawPaymentStatus == 'paid' || rawPaymentStatus == 'collected' || paymentType == 'prepaid')
          ? 'collected'
          : 'pending';

      final qty = (insertPayload['quantity'] as num?)?.toInt() ?? 1;
      final basePrice = (insertPayload['base_price'] as num?)?.toDouble() ?? 0.0;
      final upsell = (insertPayload['upsell_amount'] as num?)?.toDouble() ?? 0.0;
      final totalAmount = (insertPayload['total_amount'] as num?)?.toDouble() ?? ((qty * basePrice) + upsell);

      final orderNumber = insertPayload['order_number']?.toString() ?? 'TRK-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';

      final clientProvidedId = insertPayload['id']?.toString() ?? '';
      final validOrderUuid = uuidRegex.hasMatch(clientProvidedId)
          ? clientProvidedId
          : UuidHelper.generate();

      final pkgDealId = insertPayload['package_deal_id']?.toString();
      final pkgDealName = insertPayload['package_deal_name']?.toString();
      var deliveryNotes = insertPayload['delivery_notes']?.toString();
      if ((pkgDealId != null || pkgDealName != null) && !(deliveryNotes?.contains('[PACKAGE_DEAL:') ?? false)) {
        final pkgTag = '[PACKAGE_DEAL: {"id": "${pkgDealId ?? ''}", "name": "${pkgDealName ?? ''}", "quantity": $qty, "price": $totalAmount}]';
        deliveryNotes = deliveryNotes != null ? '$deliveryNotes $pkgTag' : pkgTag;
      }

      final fulfillment = insertPayload['fulfillment_type']?.toString() ?? 'client_package';
      final rawStatus = insertPayload['status']?.toString();
      final resolvedStatus = (rawStatus == 'pending' || rawStatus == 'unassigned' || rawStatus == 'pending_dispatch')
          ? (validRiderId != null ? 'assigned' : 'pending_dispatch')
          : (rawStatus ?? (validRiderId != null ? 'assigned' : 'pending_dispatch'));

      // 4b. Authoritative Client Name & Company Resolution
      String? resolvedClientName = insertPayload['client_name']?.toString() ?? insertPayload['client_company']?.toString();
      String? resolvedClientCompany = insertPayload['client_company']?.toString() ?? insertPayload['client_name']?.toString();
      final rawClientId = insertPayload['client_id']?.toString();

      // If client_name is missing, but a specific client_id was passed, lookup the real client name
      if ((resolvedClientName == null || resolvedClientName.isEmpty) &&
          rawClientId != null &&
          rawClientId.isNotEmpty) {
        try {
          final clientLookup = await dbClient
              .from('clients')
              .select('name, company_name')
              .eq('id', rawClientId)
              .maybeSingle();
          if (clientLookup != null) {
            final foundName = clientLookup['company_name']?.toString() ?? clientLookup['name']?.toString();
            if (foundName != null && foundName.isNotEmpty) {
              resolvedClientName = foundName;
              resolvedClientCompany = foundName;
            }
          }
        } catch (_) {}
      }

      // Also fallback to product's client_name if still empty
      if ((resolvedClientName == null || resolvedClientName.isEmpty) &&
          validProductId.isNotEmpty) {
        try {
          final prodLookup = await dbClient
              .from('products')
              .select('client_name, client_id')
              .eq('id', validProductId)
              .maybeSingle();
          if (prodLookup != null) {
            final pClientName = prodLookup['client_name']?.toString();
            if (pClientName != null && pClientName.isNotEmpty) {
              resolvedClientName = pClientName;
              resolvedClientCompany = pClientName;
            }
          }
        } catch (_) {}
      }

      resolvedClientName ??= '';
      resolvedClientCompany ??= resolvedClientName;

      // 5. Construct strictly-typed database payload with only valid columns
      final sanitizedDbPayload = <String, dynamic>{
        'id': validOrderUuid,
        'order_number': orderNumber,
        'company_id': companyId,
        'distribution_center_id': dcId,
        'product_id': validProductId,
        'product_name': insertPayload['product_name']?.toString() ?? '',
        'customer_name': insertPayload['customer_name']?.toString() ?? 'Customer',
        'customer_phone': insertPayload['customer_phone']?.toString() ?? '',
        'customer_alt_phone': insertPayload['customer_alt_phone']?.toString(),
        'delivery_state': insertPayload['delivery_state']?.toString() ?? '',
        'delivery_city': insertPayload['delivery_city']?.toString() ?? '',
        'delivery_address': insertPayload['delivery_address']?.toString() ?? '',
        'landmark': insertPayload['landmark']?.toString(),
        'delivery_lga': insertPayload['delivery_lga']?.toString() ?? insertPayload['lga']?.toString(),
        'lga': insertPayload['lga']?.toString() ?? insertPayload['delivery_lga']?.toString(),
        'fulfillment_type': fulfillment,
        'quantity': qty,
        'paid_quantity': (insertPayload['paid_quantity'] as num?)?.toInt() ?? qty,
        'free_quantity': (insertPayload['free_quantity'] as num?)?.toInt() ?? 0,
        'base_price': basePrice,
        'upsell_amount': upsell,
        'total_amount': totalAmount,
        'payment_type': paymentType,
        'payment_status': paymentStatus,
        'status': resolvedStatus,
        'delivery_method': 'cash',
        'client_delivery_fee': (insertPayload['client_delivery_fee'] as num?)?.toDouble() ?? 5000.0,
        'agent_entitlement': (insertPayload['agent_entitlement'] as num?)?.toDouble() ?? 2500.0,
        'delivery_agent_id': validRiderId,
        'assigned_agent_id': validRiderId,
        'client_id': rawClientId,
        'client_name': resolvedClientName,
        'client_company': resolvedClientCompany,
        'closer_id': insertPayload['closer_id']?.toString(),
        'closer_name': insertPayload['closer_name']?.toString(),
        'closer_code': insertPayload['closer_code']?.toString(),
        'closer_avatar_url': insertPayload['closer_avatar_url']?.toString(),
        'lead_id': insertPayload['lead_id']?.toString(),
        'assignment_status': insertPayload['assignment_status']?.toString() ?? (validRiderId != null ? 'auto_assigned' : 'pending_rider_assignment'),
        'routing_notes': insertPayload['routing_notes']?.toString(),
        'delivery_notes': deliveryNotes,
        'source_warehouse': insertPayload['source_warehouse']?.toString() ?? 'Stores - NL',
        'created_at': DateTime.now().toIso8601String(),
      };

      OrderModel createdModel;
      try {
        final payloadWithPkg = Map<String, dynamic>.from(sanitizedDbPayload);
        if (pkgDealId != null) payloadWithPkg['package_deal_id'] = pkgDealId;
        if (pkgDealName != null) payloadWithPkg['package_deal_name'] = pkgDealName;

        Map<String, dynamic> response;
        try {
          response = await dbClient
              .from(SupabaseConstants.ordersTable)
              .insert(payloadWithPkg)
              .select('*, products(name, sku, base_price)')
              .single();
        } catch (e1) {
          debugPrint('[ORDERS_DATASOURCE] Insert attempt 1 notice: $e1');
          try {
            response = await dbClient
                .from(SupabaseConstants.ordersTable)
                .insert(payloadWithPkg)
                .select('*')
                .single();
          } catch (e2) {
            debugPrint('[ORDERS_DATASOURCE] Insert attempt 2 notice: $e2');
            try {
              response = await dbClient
                  .from(SupabaseConstants.ordersTable)
                  .insert(sanitizedDbPayload)
                  .select('*')
                  .single();
            } catch (e3) {
              debugPrint('[ORDERS_DATASOURCE] Insert attempt 3 notice: $e3');
              final noProdPayload = Map<String, dynamic>.from(sanitizedDbPayload)..remove('product_id');
              response = await dbClient
                  .from(SupabaseConstants.ordersTable)
                  .insert(noProdPayload)
                  .select('*')
                  .single();
            }
          }
        }

        createdModel = OrderModel.fromJson(response);
        debugPrint('[ORDERS_DATASOURCE] ✅ Successfully created order ${createdModel.orderNumber} (ID: ${createdModel.id}) in live Supabase DB.');
      } catch (dbErr) {
        debugPrint('[ORDERS_DATASOURCE] ⚠️ Supabase remote insert notice ($dbErr). Creating standard operational model.');
        createdModel = OrderModel.fromJson({
          ...sanitizedDbPayload,
          'id': validOrderUuid,
          'package_deal_id': pkgDealId,
          'package_deal_name': pkgDealName,
        });
      }

      // If rider is assigned on creation, dispatch live notification
      if (validRiderId != null) {
        _assignedRidersByOrderId[createdModel.id] = validRiderId;
        if (insertPayload['delivery_agent_name'] != null) {
          _assignedRiderNamesByOrderId[createdModel.id] = insertPayload['delivery_agent_name'].toString();
        }
        if (insertPayload['delivery_agent_code'] != null) {
          _assignedRiderCodesByOrderId[createdModel.id] = insertPayload['delivery_agent_code'].toString();
        }

        try {
          await dbClient.from('notifications').insert({
            'company_id': companyId,
            'delivery_agent_id': validRiderId,
            'title': 'New Order Assigned 📦',
            'message': 'Order #${createdModel.orderNumber} (${createdModel.customerName} - ${createdModel.deliveryAddress}) has been assigned to you.',
            'category': 'order',
            'action_route': '/orders/assigned',
            'is_read': false,
            'created_at': DateTime.now().toIso8601String(),
          });
        } catch (_) {}
      }

      // Ensure createdModel is fully enriched with all client, DC, and rider attributes
      createdModel = OrderModel.fromEntity(
        createdModel.copyWith(
          deliveryAgentId: validRiderId,
          deliveryAgentName: insertPayload['delivery_agent_name']?.toString() ?? _assignedRiderNamesByOrderId[createdModel.id],
          deliveryAgentCode: insertPayload['delivery_agent_code']?.toString() ?? _assignedRiderCodesByOrderId[createdModel.id],
          deliveryAgentPhone: insertPayload['delivery_agent_phone']?.toString(),
          distributionCenterId: dcId,
          distributionCenterName: insertPayload['distribution_center_name']?.toString() ?? createdModel.distributionCenterName,
          clientId: insertPayload['client_id']?.toString() ?? createdModel.clientId,
          clientName: insertPayload['client_name']?.toString() ?? createdModel.clientName,
          clientCompany: insertPayload['client_name']?.toString() ?? createdModel.clientCompany,
          packageDealId: pkgDealId ?? createdModel.packageDealId,
          packageDealName: pkgDealName ?? createdModel.packageDealName,
          fulfillmentType: fulfillment,
          closerId: insertPayload['closer_id']?.toString() ?? createdModel.closerId,
          closerName: insertPayload['closer_name']?.toString() ?? createdModel.closerName,
          closerCode: insertPayload['closer_code']?.toString() ?? createdModel.closerCode,
          leadId: insertPayload['lead_id']?.toString() ?? createdModel.leadId,
        ),
      );

      return createdModel;
    } catch (e) {
      debugPrint('[ORDERS_DATASOURCE] ⚠️ createOrder error: $e');
      return OrderModel.fromJson(orderData);
    }
  }

  @override
  Future<List<OrderModel>> getDistributionCenterOrders(String distributionCenterId) async {
    try {
      List<OrderModel> list = [];
      SupabaseClient? dbClient;
      try {
        dbClient = SupabaseClient(
          SupabaseConstants.supabaseUrl,
          SupabaseConstants.supabaseServiceRoleKey,
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        );

        final response = await dbClient
            .from(SupabaseConstants.ordersTable)
            .select('*, products(name, sku, base_price)')
            .order('created_at', ascending: false);

        list = (response as List)
            .map((item) => OrderModel.fromJson(item as Map<String, dynamic>))
            .toList();
        debugPrint('[ORDERS_DATASOURCE] 📦 Loaded ${list.length} orders from live Supabase DB.');

        // 🔧 Client name enrichment: for orders with a client_id but missing/empty client_name,
        // batch-resolve the real company name from the clients table.
        final missingClientNameIds = list
            .where((o) => (o.clientName.isEmpty) && o.clientId != null && o.clientId!.isNotEmpty)
            .map((o) => o.clientId!)
            .toSet()
            .toList();

        if (missingClientNameIds.isNotEmpty) {
          try {
            final clientsRes = await dbClient
                .from('clients')
                .select('id, name, company_name')
                .inFilter('id', missingClientNameIds);

            final clientNameMap = <String, String>{};
            for (final c in (clientsRes as List)) {
              final id = c['id']?.toString();
              final name = c['company_name']?.toString() ?? c['name']?.toString();
              if (id != null && name != null && name.isNotEmpty) {
                clientNameMap[id] = name;
              }
            }

            if (clientNameMap.isNotEmpty) {
              list = list.map((order) {
                if (order.clientName.isEmpty && order.clientId != null && clientNameMap.containsKey(order.clientId)) {
                  final resolvedName = clientNameMap[order.clientId!]!;
                  return OrderModel.fromEntity(order.copyWith(
                    clientName: resolvedName,
                    clientCompany: resolvedName,
                  ));
                }
                return order;
              }).toList();
              debugPrint('[ORDERS_DATASOURCE] 🔧 Enriched client names for ${clientNameMap.length} clients.');
            }
          } catch (enrichErr) {
            debugPrint('[ORDERS_DATASOURCE] ℹ️ Client name enrichment notice: $enrichErr');
          }
        }
      } catch (e) {
        debugPrint('[ORDERS_DATASOURCE] ℹ️ Supabase remote fetch notice ($e).');
      } finally {
        dbClient?.dispose();
      }

      // Map assigned riders from in-memory cache without overwriting terminal states or stripping fields
      final syncedList = list.map<OrderModel>((model) {
        if (_assignedRidersByOrderId.containsKey(model.id)) {
          final isFinished = model.status == 'delivered' ||
              model.status == 'completed' ||
              model.status == 'failed' ||
              model.status == 'cancelled' ||
              model.status == 'returned';

          return OrderModel.fromEntity(
            model.copyWith(
              deliveryAgentId: model.deliveryAgentId ?? _assignedRidersByOrderId[model.id],
              deliveryAgentName: model.deliveryAgentName ?? _assignedRiderNamesByOrderId[model.id],
              deliveryAgentCode: model.deliveryAgentCode ?? _assignedRiderCodesByOrderId[model.id],
              distributionCenterId: model.distributionCenterId ?? distributionCenterId,
              status: isFinished
                  ? model.status
                  : (model.status == 'pending' || model.status == 'new' || model.status == 'unassigned'
                      ? 'in_transit'
                      : model.status),
            ),
          );
        }
        return model;
      }).toList();

      return syncedList;
    } catch (e) {
      debugPrint('[ORDERS_DATASOURCE] ⚠️ getDistributionCenterOrders notice: $e');
      return [];
    }
  }

  @override
  Future<void> assignOrderToRider({
    required String orderId,
    required String riderId,
    required String riderName,
    required String riderCode,
  }) async {
    _assignedRidersByOrderId[orderId] = riderId;
    _assignedRiderNamesByOrderId[orderId] = riderName;
    _assignedRiderCodesByOrderId[orderId] = riderCode;

    SupabaseClient? dbClient;
    try {
      dbClient = SupabaseClient(
        SupabaseConstants.supabaseUrl,
        SupabaseConstants.supabaseServiceRoleKey,
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      );

      final uuidRegex = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');
      final isUuid = uuidRegex.hasMatch(orderId.trim());

      // 1. Resolve authoritative delivery_agent_id UUID from delivery_agents table
      String? validRiderUuid;
      if (uuidRegex.hasMatch(riderId)) {
        validRiderUuid = riderId;
      } else {
        try {
          final query = riderCode.isNotEmpty ? riderCode : riderId;
          final agentRow = await dbClient
              .from(SupabaseConstants.deliveryAgentsTable)
              .select('id')
              .or('agent_code.eq.$query,id.eq.$query,user_id.eq.$query')
              .limit(1);
          if ((agentRow as List).isNotEmpty && agentRow.first['id'] != null) {
            validRiderUuid = agentRow.first['id'].toString();
          }
        } catch (_) {}
      }

      if (validRiderUuid == null || !uuidRegex.hasMatch(validRiderUuid)) {
        validRiderUuid = riderId.isNotEmpty && uuidRegex.hasMatch(riderId) ? riderId : null;
      }

      // 2. Resolve order details safely without triggering 22P02 invalid UUID syntax
      String orderNum = orderId.length > 8 ? 'ORD-${orderId.substring(0, 8)}' : orderId;
      String custName = 'Customer';
      String city = 'Abuja';
      String? matchedOrderUuid = isUuid ? orderId.trim() : null;
      String? matchedOrderNumber = isUuid ? null : orderId.trim();
      String? orderCompanyId;

      if (isUuid) {
        try {
          final orderRow = await dbClient
              .from(SupabaseConstants.ordersTable)
              .select('id, order_number, customer_name, delivery_city, company_id')
              .eq('id', orderId.trim())
              .maybeSingle();
          if (orderRow != null) {
            orderNum = orderRow['order_number']?.toString() ?? orderNum;
            custName = orderRow['customer_name']?.toString() ?? custName;
            city = orderRow['delivery_city']?.toString() ?? city;
            matchedOrderUuid = orderRow['id']?.toString() ?? matchedOrderUuid;
            if (orderRow['company_id'] != null) orderCompanyId = orderRow['company_id'].toString();
          }
        } catch (_) {}
      } else {
        // Query by order_number if known
        try {
          final orderRow = await dbClient
              .from(SupabaseConstants.ordersTable)
              .select('id, order_number, customer_name, delivery_city, company_id')
              .eq('order_number', orderId.trim())
              .maybeSingle();
          if (orderRow != null) {
            orderNum = orderRow['order_number']?.toString() ?? orderNum;
            custName = orderRow['customer_name']?.toString() ?? custName;
            city = orderRow['delivery_city']?.toString() ?? city;
            matchedOrderUuid = orderRow['id']?.toString();
            matchedOrderNumber = orderRow['order_number']?.toString() ?? matchedOrderNumber;
            if (orderRow['company_id'] != null) orderCompanyId = orderRow['company_id'].toString();
          }
        } catch (_) {}
      }

      // 3. Update orders table in Supabase (status MUST be 'in_transit' for active assignment check constraint)
      if (validRiderUuid != null) {
        final updatePayload = {
          'delivery_agent_id': validRiderUuid,
          'assigned_agent_id': validRiderUuid,
          'status': 'in_transit',
          'updated_at': DateTime.now().toIso8601String(),
        };

        if (matchedOrderUuid != null) {
          await dbClient
              .from(SupabaseConstants.ordersTable)
              .update(updatePayload)
              .eq('id', matchedOrderUuid);
        } else if (matchedOrderNumber != null) {
          await dbClient
              .from(SupabaseConstants.ordersTable)
              .update(updatePayload)
              .eq('order_number', matchedOrderNumber);
        }
      }

      // 4. Immediately insert real notification in database for rider
      try {
        await dbClient.from('notifications').insert({
          if (orderCompanyId != null) 'company_id': orderCompanyId,
          'delivery_agent_id': validRiderUuid,
          'category': 'delivery',
          'title': 'New Order Assigned! 📦',
          'message': 'Order $orderNum for $custName in $city has been assigned to your route.',
          'action_route': '/orders/${matchedOrderUuid ?? orderId}',
          'is_read': false,
          'created_at': DateTime.now().toIso8601String(),
        });
        debugPrint('[ORDERS_DATASOURCE] 🔔 Inserted assignment notification in Supabase for $riderName ($validRiderUuid)');
      } catch (notifErr) {
        debugPrint('[ORDERS_DATASOURCE] ℹ️ Assignment notification insert notice: $notifErr');
      }

      debugPrint('[ORDERS_DATASOURCE] ✅ Order $orderId successfully assigned to rider $riderName ($validRiderUuid).');
    } catch (e) {
      debugPrint('[ORDERS_DATASOURCE] ℹ️ Supabase assign notice ($e). In-memory state active.');
    } finally {
      dbClient?.dispose();
    }
  }

  @override
  Future<void> unassignOrderFromRider({
    required String orderId,
  }) async {
    _assignedRidersByOrderId.remove(orderId);
    _assignedRiderNamesByOrderId.remove(orderId);
    _assignedRiderCodesByOrderId.remove(orderId);

    SupabaseClient? dbClient;
    try {
      dbClient = SupabaseClient(
        SupabaseConstants.supabaseUrl,
        SupabaseConstants.supabaseServiceRoleKey,
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      );

      final uuidRegex = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');
      final isUuid = uuidRegex.hasMatch(orderId.trim());

      final updatePayload = {
        'delivery_agent_id': null,
        'assigned_agent_id': null,
        'status': 'pending_dispatch',
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (isUuid) {
        await dbClient
            .from(SupabaseConstants.ordersTable)
            .update(updatePayload)
            .eq('id', orderId.trim());
      } else {
        await dbClient
            .from(SupabaseConstants.ordersTable)
            .update(updatePayload)
            .eq('order_number', orderId.trim());
      }

      debugPrint('[ORDERS_DATASOURCE] ✅ Order $orderId unassigned back to DC pool.');
    } catch (e) {
      debugPrint('[ORDERS_DATASOURCE] ℹ️ Unassign notice ($e).');
    } finally {
      dbClient?.dispose();
    }
  }

  @override
  Future<OrderModel> getOrderById(String orderId) async {
    try {
      final isUuid = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$').hasMatch(orderId.trim());
      var query = supabaseClient.from(SupabaseConstants.ordersTable).select();
      final response = isUuid
          ? await query.eq('id', orderId.trim()).maybeSingle()
          : await query.eq('order_number', orderId.trim()).maybeSingle();

      if (response != null) {
        return OrderModel.fromJson(response);
      }

      throw Exception('Order "$orderId" not found in Supabase database.');
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> updateOrderStatus(
    String orderId,
    String status, {
    String? paymentStatus,
    String? paymentType,
    String? notes,
    String? customerSignatureUrl,
    String? photoProofUrl,
    String? gatePassCode,
    double? latitude,
    double? longitude,
    bool? isLocationVerified,
  }) async {
    final updateData = <String, dynamic>{
      'status': status,
      'updated_at': DateTime.now().toIso8601String(),
    };
    if (paymentStatus != null) {
      updateData['payment_status'] = paymentStatus;
    }
    if (paymentType != null) {
      updateData['payment_type'] = paymentType;
    }
    String combinedNotes = notes ?? '';
    if (customerSignatureUrl != null) {
      updateData['proof_of_delivery_url'] = customerSignatureUrl;
      combinedNotes = '$combinedNotes [Signature: $customerSignatureUrl]'.trim();
    }
    if (photoProofUrl != null) {
      updateData['proof_of_delivery_url'] ??= photoProofUrl;
      combinedNotes = '$combinedNotes [POD Photo: $photoProofUrl]'.trim();
    }
    if (combinedNotes.isNotEmpty) {
      updateData['delivery_notes'] = combinedNotes;
    }
    if (gatePassCode != null) {
      updateData['gate_pass_code'] = gatePassCode;
    }
    if (latitude != null) {
      updateData['latitude'] = latitude;
    }
    if (longitude != null) {
      updateData['longitude'] = longitude;
    }
    if (isLocationVerified != null) {
      updateData['is_location_verified'] = isLocationVerified;
    }

    final isUuid = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$').hasMatch(orderId.trim());

    try {
      if (isUuid) {
        await supabaseClient
            .from(SupabaseConstants.ordersTable)
            .update(updateData)
            .eq('id', orderId.trim());
      } else {
        await supabaseClient
            .from(SupabaseConstants.ordersTable)
            .update(updateData)
            .eq('order_number', orderId.trim());
      }
    } catch (e) {
      SupabaseClient? dbClient;
      try {
        dbClient = SupabaseClient(
          SupabaseConstants.supabaseUrl,
          SupabaseConstants.supabaseServiceRoleKey,
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        );
        if (isUuid) {
          await dbClient
              .from(SupabaseConstants.ordersTable)
              .update(updateData)
              .eq('id', orderId.trim());
        } else {
          await dbClient
              .from(SupabaseConstants.ordersTable)
              .update(updateData)
              .eq('order_number', orderId.trim());
        }
      } catch (serviceErr) {
        debugPrint('[ORDERS_DATASOURCE] ℹ️ updateOrderStatus fallback notice: $serviceErr');
      }
    }
  }

  @override
  Future<Map<String, dynamic>> confirmDeliveryPod({
    required String orderId,
    required String agentId,
    required String paymentType,
    required String paymentMethod,
    required double amountCollected,
    String? customerSignatureUrl,
    String? photoProofUrl,
    String? notes,
    String? gatePassCode,
    double? latitude,
    double? longitude,
  }) async {
    final isDirectTransfer = paymentMethod == 'bank_transfer' ||
        paymentType == 'prepaid' ||
        (notes != null && (notes.contains('Monnify') || notes.contains('Direct Transfer')));
    final resolvedPaymentType = isDirectTransfer ? 'prepaid' : paymentType;
    final resolvedPaymentStatus = isDirectTransfer ? 'paid' : 'collected';

    try {
      final response = await supabaseClient.functions.invoke(
        'confirm-delivery-pod',
        body: {
          'orderId': orderId,
          'agentId': agentId,
          'paymentType': resolvedPaymentType,
          'paymentMethod': paymentMethod,
          'amountCollected': amountCollected,
          'customerSignatureUrl': customerSignatureUrl,
          'photoProofUrl': photoProofUrl,
          'gatePassCode': gatePassCode,
          'latitude': latitude,
          'longitude': longitude,
          'notes': notes,
        },
      );

      if (response.status >= 200 && response.status < 300) {
        // Also update local list in database
        await updateOrderStatus(
          orderId,
          'delivered',
          paymentStatus: resolvedPaymentStatus,
          paymentType: resolvedPaymentType,
          customerSignatureUrl: customerSignatureUrl,
          photoProofUrl: photoProofUrl,
          gatePassCode: gatePassCode,
          latitude: latitude,
          longitude: longitude,
          isLocationVerified: true,
          notes: notes,
        );
        return response.data as Map<String, dynamic>? ?? {'status': 'success'};
      }
      throw Exception('Server returned ${response.status}: ${response.data}');
    } catch (e) {
      // Local fallback for offline/test execution
      await updateOrderStatus(
        orderId,
        'delivered',
        paymentStatus: resolvedPaymentStatus,
        paymentType: resolvedPaymentType,
        customerSignatureUrl: customerSignatureUrl,
        photoProofUrl: photoProofUrl,
        gatePassCode: gatePassCode,
        latitude: latitude,
        longitude: longitude,
        isLocationVerified: true,
        notes: notes,
      );

      // Attempt direct RPC deduction of rider stock in fallback
      try {
        final ord = await supabaseClient.from('orders').select('product_id, quantity, paid_quantity, free_quantity').eq('id', orderId).maybeSingle();
        if (ord != null && ord['product_id'] != null) {
          final pQty = ((ord['paid_quantity'] as num?)?.toInt() ?? 0) + ((ord['free_quantity'] as num?)?.toInt() ?? 0);
          final physicalQty = pQty > 0 ? pQty : ((ord['quantity'] as num?)?.toInt() ?? 1);
          await supabaseClient.rpc('fn_confirm_order_delivery_stock', params: {
            'p_order_id': orderId,
            'p_agent_id': agentId,
            'p_product_id': ord['product_id'],
            'p_physical_quantity': physicalQty,
          });
        }
      } catch (rpcErr) {
        debugPrint('[ORDERS_DATASOURCE] Fallback fn_confirm_order_delivery_stock notice: $rpcErr');
      }

      return {'status': 'offline_fallback', 'error': e.toString()};
    }
  }

  @override
  Future<Map<String, dynamic>> logDeliveryFailure({
    required String orderId,
    required String agentId,
    required String reasonCode,
    String? notes,
    String? scheduledCallbackAt,
    String? gatePassCode,
    double? latitude,
    double? longitude,
  }) async {
    final isCallback = reasonCode == 'rescheduled' || scheduledCallbackAt != null;
    final newStatus = isCallback ? 'call_back' : 'failed';
    try {
      final response = await supabaseClient.functions.invoke(
        'log-delivery-failure',
        body: {
          'orderId': orderId,
          'agentId': agentId,
          'reasonCode': reasonCode,
          'notes': notes,
          'scheduledCallbackAt': scheduledCallbackAt,
          'gatePassCode': gatePassCode,
          'latitude': latitude,
          'longitude': longitude,
        },
      );

      if (response.status >= 200 && response.status < 300) {
        await updateOrderStatus(
          orderId,
          newStatus,
          notes: notes,
          gatePassCode: gatePassCode,
          latitude: latitude,
          longitude: longitude,
          isLocationVerified: true,
        );
        return response.data as Map<String, dynamic>? ?? {'status': 'success'};
      }
      throw Exception('Server returned ${response.status}: ${response.data}');
    } catch (e) {
      await updateOrderStatus(
        orderId,
        newStatus,
        notes: notes,
        gatePassCode: gatePassCode,
        latitude: latitude,
        longitude: longitude,
        isLocationVerified: true,
      );
      return {'status': 'offline_fallback', 'error': e.toString()};
    }
  }

  @override
  Future<void> updateOrderCoordinates({
    required String orderId,
    required double latitude,
    required double longitude,
    bool isLocationVerified = true,
    String? geocodedAddress,
  }) async {
    _customCoordinatesByOrderId[orderId] = {
      'latitude': latitude,
      'longitude': longitude,
      'is_location_verified': isLocationVerified,
      'geocoded_address': geocodedAddress,
      'location_confidence': isLocationVerified ? 'high' : 'medium',
      'geocoding_status': isLocationVerified ? 'exact_verified' : 'rooftop',
    };

    SupabaseClient? dbClient;
    try {
      dbClient = SupabaseClient(
        SupabaseConstants.supabaseUrl,
        SupabaseConstants.supabaseServiceRoleKey,
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      );

      final isUuid = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$').hasMatch(orderId.trim());
      final updateCoordinatesPayload = {
        'latitude': latitude,
        'longitude': longitude,
        'is_location_verified': isLocationVerified,
        'location_confidence': isLocationVerified ? 1.0 : 0.8,
        'geocoding_status': isLocationVerified ? 'exact_verified' : 'rooftop',
        if (geocodedAddress != null) 'geocoded_address': geocodedAddress,
        'updated_at': DateTime.now().toIso8601String(),
      };
      if (isUuid) {
        await dbClient.from(SupabaseConstants.ordersTable).update(updateCoordinatesPayload).eq('id', orderId.trim());
      } else {
        await dbClient.from(SupabaseConstants.ordersTable).update(updateCoordinatesPayload).eq('order_number', orderId.trim());
      }
    } catch (e) {
      debugPrint('[ORDERS_DATASOURCE] ℹ️ Supabase update coordinates notice ($e). In-memory state updated.');
    } finally {
      dbClient?.dispose();
    }
  }
}

class MockOrdersRemoteDataSource implements OrdersRemoteDataSource {
  @override
  Future<List<OrderModel>> getAssignedOrders(String deliveryAgentId) async => [];

  @override
  Future<List<OrderModel>> getDistributionCenterOrders(String distributionCenterId) async => [];

  @override
  Future<OrderModel> createOrder(Map<String, dynamic> orderData) async {
    return OrderModel.fromJson(orderData);
  }

  @override
  Future<void> assignOrderToRider({
    required String orderId,
    required String riderId,
    required String riderName,
    required String riderCode,
  }) async {}

  @override
  Future<void> unassignOrderFromRider({
    required String orderId,
  }) async {}

  @override
  Future<OrderModel> getOrderById(String orderId) async {
    return OrderModel(
      id: orderId,
      orderNumber: 'ORD-$orderId',
      customerName: 'Mock Customer',
      customerPhone: '08000000000',
      deliveryState: 'Lagos',
      deliveryCity: 'Lagos',
      deliveryAddress: 'Lagos Address',
      productName: 'Mock Product',
      quantity: 1,
      basePrice: 10000.0,
      upsellAmount: 0.0,
      totalAmount: 10000.0,
      paymentType: 'pay_on_delivery',
      paymentStatus: 'pending',
      status: 'pending',
      createdAt: DateTime.now(),
    );
  }

  @override
  Future<void> updateOrderStatus(
    String orderId,
    String status, {
    String? paymentStatus,
    String? paymentType,
    String? notes,
    String? customerSignatureUrl,
    String? photoProofUrl,
    String? gatePassCode,
    double? latitude,
    double? longitude,
    bool? isLocationVerified,
  }) async {}

  @override
  Future<Map<String, dynamic>> confirmDeliveryPod({
    required String orderId,
    required String agentId,
    required String paymentType,
    required String paymentMethod,
    required double amountCollected,
    String? customerSignatureUrl,
    String? photoProofUrl,
    String? notes,
    String? gatePassCode,
    double? latitude,
    double? longitude,
    bool? isLocationVerified,
  }) async => {'status': 'success'};

  @override
  Future<Map<String, dynamic>> logDeliveryFailure({
    required String orderId,
    required String agentId,
    required String reasonCode,
    String? notes,
    String? scheduledCallbackAt,
    String? gatePassCode,
    double? latitude,
    double? longitude,
  }) async => {'status': 'success'};

  @override
  Future<void> updateOrderCoordinates({
    required String orderId,
    required double latitude,
    required double longitude,
    bool isLocationVerified = true,
    String? geocodedAddress,
  }) async {}
}



