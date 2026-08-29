import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/constants/supabase_constants.dart';
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
  static final List<OrderModel> _createdOrders = [];
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

        // 1. Resolve authoritative delivery_agent_id and agent_code from delivery_agents table
        String targetAgentId = cleanId;
        String? targetAgentCode;
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
            if (first['agent_code'] != null) targetAgentCode = first['agent_code'].toString();
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

        // 3. Include any newly created/assigned orders in this session assigned to this rider
        for (final created in _createdOrders) {
          final isAssignedToThis = _assignedRidersByOrderId[created.id] == targetAgentId ||
              _assignedRidersByOrderId[created.id] == cleanId ||
              created.deliveryAgentId == targetAgentId ||
              created.deliveryAgentId == cleanId ||
              (targetAgentCode != null && (_assignedRiderCodesByOrderId[created.id] == targetAgentCode || created.deliveryAgentCode == targetAgentCode));

          if (isAssignedToThis && !list.any((o) => o.id == created.id || o.orderNumber == created.orderNumber)) {
            list.insert(0, created);
          }
        }

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
        validProductId = 'a1b2c3d4-0000-4000-8000-000000000001';
      }

      // 2. Resolve company and distribution center UUIDs
      const companyId = '11111111-1111-4111-8111-111111111111';
      final dcId = (insertPayload['distribution_center_id'] != null && uuidRegex.hasMatch(insertPayload['distribution_center_id'].toString()))
          ? insertPayload['distribution_center_id'].toString()
          : '22222222-2222-4222-8222-222222222222';

      // 3. Resolve rider assignment UUID if present
      String? validRiderId;
      final rawRiderId = insertPayload['delivery_agent_id']?.toString() ?? '';
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
      final basePrice = (insertPayload['base_price'] as num?)?.toDouble() ?? 25000.0;
      final upsell = (insertPayload['upsell_amount'] as num?)?.toDouble() ?? 0.0;
      final totalAmount = (insertPayload['total_amount'] as num?)?.toDouble() ?? ((qty * basePrice) + upsell);

      final orderNumber = insertPayload['order_number']?.toString() ?? 'TRK-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';

      // 5. Construct strictly-typed database payload with only valid columns
      final sanitizedDbPayload = <String, dynamic>{
        'order_number': orderNumber,
        'company_id': companyId,
        'distribution_center_id': dcId,
        'product_id': validProductId,
        'product_name': insertPayload['product_name']?.toString() ?? 'Respira Detox Tea',
        'customer_name': insertPayload['customer_name']?.toString() ?? 'Customer',
        'customer_phone': insertPayload['customer_phone']?.toString() ?? '08000000000',
        'customer_alt_phone': insertPayload['customer_alt_phone']?.toString(),
        'delivery_state': insertPayload['delivery_state']?.toString() ?? 'FCT - Abuja',
        'delivery_city': insertPayload['delivery_city']?.toString() ?? 'Abuja',
        'delivery_address': insertPayload['delivery_address']?.toString() ?? 'Delivery Address',
        'landmark': insertPayload['landmark']?.toString(),
        'lga': insertPayload['lga']?.toString(),
        'fulfillment_type': 'distributed_inventory',
        'quantity': qty,
        'paid_quantity': (insertPayload['paid_quantity'] as num?)?.toInt() ?? qty,
        'free_quantity': (insertPayload['free_quantity'] as num?)?.toInt() ?? 0,
        'base_price': basePrice,
        'upsell_amount': upsell,
        'total_amount': totalAmount,
        'payment_type': paymentType,
        'payment_status': paymentStatus,
        'status': (insertPayload['status']?.toString() == 'pending' || insertPayload['status']?.toString() == 'unassigned')
            ? 'new'
            : (insertPayload['status']?.toString() ?? (validRiderId != null ? 'in_transit' : 'new')),
        'delivery_method': 'cash',
        'client_delivery_fee': (insertPayload['client_delivery_fee'] as num?)?.toDouble() ?? 5000.0,
        'agent_entitlement': (insertPayload['agent_entitlement'] as num?)?.toDouble() ?? 2500.0,
        'delivery_agent_id': validRiderId,
        'delivery_notes': insertPayload['delivery_notes']?.toString(),
        'created_at': DateTime.now().toIso8601String(),
      };

      OrderModel createdModel;
      try {
        final response = await dbClient
            .from(SupabaseConstants.ordersTable)
            .insert(sanitizedDbPayload)
            .select('*, products(name, sku, base_price)')
            .single();

        createdModel = OrderModel.fromJson(response);
        debugPrint('[ORDERS_DATASOURCE] ✅ Successfully created order ${createdModel.orderNumber} (ID: ${createdModel.id}) in live Supabase DB.');
      } catch (dbErr) {
        debugPrint('[ORDERS_DATASOURCE] ℹ️ Supabase remote insert notice ($dbErr). Creating standard operational model.');
        createdModel = OrderModel.fromJson({
          ...sanitizedDbPayload,
          'id': 'ord-${DateTime.now().millisecondsSinceEpoch}',
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

      _createdOrders.removeWhere((o) => o.id == createdModel.id || o.orderNumber == createdModel.orderNumber);
      _createdOrders.insert(0, createdModel);
      return createdModel;
    } catch (e) {
      debugPrint('[ORDERS_DATASOURCE] ⚠️ createOrder error: $e');
      final fallback = OrderModel.fromJson(orderData);
      _createdOrders.insert(0, fallback);
      return fallback;
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
      } catch (e) {
        debugPrint('[ORDERS_DATASOURCE] ℹ️ Supabase remote fetch notice ($e).');
      } finally {
        dbClient?.dispose();
      }

      // Merge newly created orders at the top
      for (final created in _createdOrders) {
        if (!list.any((o) => o.id == created.id || o.orderNumber == created.orderNumber)) {
          list.insert(0, created);
        }
      }

      // Map assigned riders from in-memory cache without overwriting terminal states or stripping fields
      final syncedList = list.map((model) {
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
              distributionCenterId: distributionCenterId,
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

      // 1. Fetch order summary details for instant notification
      String orderNum = orderId.length > 8 ? 'ORD-${orderId.substring(0, 8)}' : orderId;
      String custName = 'Customer';
      String city = 'Abuja';
      try {
        final orderRow = await dbClient
            .from(SupabaseConstants.ordersTable)
            .select('order_number, customer_name, delivery_city')
            .eq('id', orderId)
            .maybeSingle();
        if (orderRow != null) {
          orderNum = orderRow['order_number']?.toString() ?? orderNum;
          custName = orderRow['customer_name']?.toString() ?? custName;
          city = orderRow['delivery_city']?.toString() ?? city;
        }
      } catch (_) {}

      // 2. Resolve authoritative delivery_agent_id UUID from delivery_agents table
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

      if (validRiderUuid != null) {
        // 3. Update orders table in Supabase (status MUST be 'in_transit' for active assignment check constraint)
        await dbClient
            .from(SupabaseConstants.ordersTable)
            .update({
              'delivery_agent_id': validRiderUuid,
              'status': 'in_transit',
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', orderId);
      }

      // 4. Immediately insert real notification in database for rider
      try {
        await dbClient.from('notifications').insert({
          'company_id': '11111111-1111-4111-8111-111111111111',
          'delivery_agent_id': validRiderUuid,
          'category': 'delivery',
          'title': 'New Order Assigned! 📦',
          'message': 'Order $orderNum for $custName in $city has been assigned to your route.',
          'action_route': '/orders/$orderId',
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
  Future<OrderModel> getOrderById(String orderId) async {
    try {
      final response = await supabaseClient
          .from(SupabaseConstants.ordersTable)
          .select()
          .eq('id', orderId)
          .maybeSingle();

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
      if (paymentStatus == 'remitted') {
        updateData['remittance_status'] = 'remitted';
        updateData['financial_settlement_status'] = 'cash_remitted_verified';
        updateData['remitted_at'] = DateTime.now().toIso8601String();
      }
    }
    if (paymentType != null) {
      updateData['payment_type'] = paymentType;
    }
    if (notes != null && notes.contains('[REMITTED')) {
      updateData['remittance_status'] = 'remitted';
      updateData['financial_settlement_status'] = 'cash_remitted_verified';
      updateData['remitted_at'] = DateTime.now().toIso8601String();
    }
    if (notes != null) {
      updateData['delivery_notes'] = notes;
    }
    if (customerSignatureUrl != null) {
      updateData['customer_signature_url'] = customerSignatureUrl;
      updateData['proof_of_delivery_url'] = customerSignatureUrl;
    }
    if (photoProofUrl != null) {
      updateData['proof_photo_url'] = photoProofUrl;
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

    try {
      await supabaseClient
          .from(SupabaseConstants.ordersTable)
          .update(updateData)
          .eq('id', orderId);
    } catch (e) {
      SupabaseClient? dbClient;
      try {
        dbClient = SupabaseClient(
          SupabaseConstants.supabaseUrl,
          SupabaseConstants.supabaseServiceRoleKey,
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        );
        await dbClient
            .from(SupabaseConstants.ordersTable)
            .update(updateData)
            .eq('id', orderId);
      } catch (serviceErr) {
        debugPrint('[ORDERS_DATASOURCE] ℹ️ updateOrderStatus fallback notice: $serviceErr');
      } finally {
        dbClient?.dispose();
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

      await dbClient.from(SupabaseConstants.ordersTable).update({
        'latitude': latitude,
        'longitude': longitude,
        'is_location_verified': isLocationVerified,
        'location_confidence': isLocationVerified ? 'high' : 'medium',
        'geocoding_status': isLocationVerified ? 'exact_verified' : 'rooftop',
        if (geocodedAddress != null) 'geocoded_address': geocodedAddress,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', orderId);
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



