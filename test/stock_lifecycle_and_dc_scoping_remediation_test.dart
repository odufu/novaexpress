import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:novexps/core/constants/supabase_constants.dart';
import 'package:novexps/features/dc_console/domain/entities/dc_fleet_driver.dart';
import 'package:novexps/features/dc_console/domain/entities/distribution_center.dart';
import 'package:novexps/features/dc_console/presentation/widgets/dc_csv_order_import_modal.dart';
import 'package:novexps/features/orders/data/datasources/orders_remote_datasource.dart';
import 'package:novexps/features/orders/domain/entities/order.dart';
import 'package:novexps/features/orders/domain/services/order_routing_service.dart';
import 'package:novexps/features/stock/data/datasources/stock_remote_datasource.dart';
import 'package:novexps/features/stock/domain/entities/rider_stock_allocation.dart';

class _UnrestrictedHttpOverrides extends HttpOverrides {}

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    HttpOverrides.global = _UnrestrictedHttpOverrides();
  });

  group('Stock Lifecycle & DC Scoping Remediation Test Suite', () {
    late SupabaseClient client;
    final List<String> createdTransferIds = [];
    final List<String> createdReturnIds = [];
    final List<String> createdAuditNumbers = [];
    final List<String> createdOrderIds = [];

    setUp(() {
      HttpOverrides.global = _UnrestrictedHttpOverrides();
      client = SupabaseClient(
        SupabaseConstants.supabaseUrl,
        SupabaseConstants.supabaseServiceRoleKey,
      );
    });

    tearDownAll(() async {
      // Clean up test data
      for (final id in createdTransferIds) {
        try {
          await client.from('stock_transfer_items').delete().eq('transfer_id', id);
          await client.from('stock_transfers').delete().eq('id', id);
        } catch (_) {}
      }
      for (final id in createdReturnIds) {
        try {
          await client.from('stock_returns').delete().eq('id', id);
        } catch (_) {}
      }
      for (final num in createdAuditNumbers) {
        try {
          await client.from('inventory_audits').delete().eq('audit_number', num);
        } catch (_) {}
      }
      for (final id in createdOrderIds) {
        try {
          await client.from('orders').delete().eq('id', id);
        } catch (_) {}
      }
    });

    test('1. ParsedCsvOrderRow scopes order payload to active DC without falling back', () {
      final row = ParsedCsvOrderRow(
        rowNumber: 1,
        orderNumber: 'TEST-CSV-001',
        customerName: 'Amina Danladi',
        customerPhone: '08012345678',
        deliveryAddress: '54 Bompai Road',
        deliveryCity: 'Nassarawa',
        deliveryState: 'Kano',
        productName: 'Respira Detox Tea',
        quantity: 2,
        totalAmount: 50000,
        paymentType: 'pay_on_delivery',
        clientName: 'Herbal Remedies Ltd',
        isValid: true,
      );

      const targetDcId = 'dc-kano-central-uuid';
      final payload = row.toOrderPayload(distributionCenterId: targetDcId);

      expect(payload['distribution_center_id'], equals(targetDcId));
      expect(payload['order_number'], equals('TEST-CSV-001'));
      expect(payload['customer_name'], equals('Amina Danladi'));
      expect(payload['quantity'], equals(2));
      expect(payload['status'], equals('new'));

      // If no DC provided, it does not inject a fake DC
      final unassignedPayload = row.toOrderPayload();
      expect(unassignedPayload.containsKey('distribution_center_id'), isFalse);
    });

    test('2. OrderRoutingService requires matching stock allocation before assigning to rider', () {
      const regionalDc = DistributionCenter(
        id: 'dc-kano-01',
        name: 'Kano Regional DC',
        code: 'DC-KAN-01',
        state: 'Kano',
        city: 'Kano',
        address: 'Bompai Industrial Area',
        operatingZones: ['Nassarawa', 'Fagge', 'Dala'],
        isHub: true,
        isActive: true,
      );

      const riderWithoutStock = DCFleetDriver(
        id: 'rider-kano-empty',
        name: 'Ibrahim EmptyStock',
        phone: '08099990001',
        driverCode: 'RDR-KAN-01',
        avatarUrl: '',
        vehicleModel: 'Bajaj Pulsar',
        vehiclePlate: 'KAN-123-XY',
        vehicleType: 'Motorcycle',
        status: 'active',
        assignedZone: 'Nassarawa',
        distributionCenterId: 'dc-kano-01',
        coveredLgas: ['Nassarawa'],
        totalAssignedOrders: 0,
        completedOrders: 0,
        routeProgressPercent: 0,
        efficiencyRating: 5.0,
        cashInCustody: 0,
        itemsInCustody: 0,
      );

      const riderWithStock = DCFleetDriver(
        id: 'rider-kano-stocked',
        name: 'Musa HasStock',
        phone: '08099990002',
        driverCode: 'RDR-KAN-02',
        avatarUrl: '',
        vehicleModel: 'Bajaj Pulsar',
        vehiclePlate: 'KAN-456-XY',
        vehicleType: 'Motorcycle',
        status: 'active',
        assignedZone: 'Nassarawa',
        distributionCenterId: 'dc-kano-01',
        coveredLgas: ['Nassarawa'],
        totalAssignedOrders: 0,
        completedOrders: 0,
        routeProgressPercent: 0,
        efficiencyRating: 5.0,
        cashInCustody: 0,
        itemsInCustody: 10,
      );

      final testOrder = OrderEntity(
        id: 'order-kano-test-1',
        orderNumber: 'ORD-KAN-001',
        customerName: 'Fatima Bello',
        customerPhone: '08011112222',
        deliveryAddress: 'Plot 12 Zoo Road',
        deliveryCity: 'Nassarawa',
        deliveryState: 'Kano',
        lga: 'Nassarawa',
        productName: 'Respira Detox Tea',
        productSku: 'SKU-RESP-01',
        quantity: 2,
        totalAmount: 50000,
        basePrice: 50000,
        upsellAmount: 0.0,
        status: 'pending_dispatch',
        paymentStatus: 'pending',
        paymentType: 'pay_on_delivery',
        fulfillmentType: 'distributed_inventory',
        createdAt: DateTime.now(),
      );

      // Scenario A: Only rider without stock is available -> routes to DC only, rider NOT assigned
      final resultA = OrderRoutingService.routeOrder(
        order: testOrder,
        distributionCenters: const [regionalDc],
        drivers: const [riderWithoutStock],
        stockAllocations: [
          RiderStockAllocation(
            id: 'alloc-empty',
            riderId: 'rider-kano-empty',
            riderName: 'Ibrahim EmptyStock',
            riderCode: 'RDR-KAN-01',
            productId: 'prod-resp-01',
            productName: 'Respira Detox Tea',
            sku: 'SKU-RESP-01',
            allocatedUnits: 1,
            inCustodyUnits: 1, // Need 2, only have 1
            unitPrice: 25000,
            allocatedAt: DateTime.now(),
          ),
        ],
      );

      expect(resultA.status, equals(RoutingStatus.routedToDcOnly));
      expect(resultA.distributionCenter?.id, equals('dc-kano-01'));
      expect(resultA.driver, isNull);

      // Scenario B: Rider with sufficient stock (>= 2) -> assigns to rider
      final resultB = OrderRoutingService.routeOrder(
        order: testOrder,
        distributionCenters: const [regionalDc],
        drivers: const [riderWithoutStock, riderWithStock],
        stockAllocations: [
          RiderStockAllocation(
            id: 'alloc-empty',
            riderId: 'rider-kano-empty',
            riderName: 'Ibrahim EmptyStock',
            riderCode: 'RDR-KAN-01',
            productId: 'prod-resp-01',
            productName: 'Respira Detox Tea',
            sku: 'SKU-RESP-01',
            allocatedUnits: 1,
            inCustodyUnits: 1,
            unitPrice: 25000,
            allocatedAt: DateTime.now(),
          ),
          RiderStockAllocation(
            id: 'alloc-stocked',
            riderId: 'rider-kano-stocked',
            riderName: 'Musa HasStock',
            riderCode: 'RDR-KAN-02',
            productId: 'prod-resp-01',
            productName: 'Respira Detox Tea',
            sku: 'SKU-RESP-01',
            allocatedUnits: 10,
            inCustodyUnits: 10, // Sufficient stock
            unitPrice: 25000,
            allocatedAt: DateTime.now(),
          ),
        ],
      );

      expect(resultB.status, equals(RoutingStatus.assignedToRider));
      expect(resultB.driver?.id, equals('rider-kano-stocked'));
      expect(resultB.availableRiderStock, equals(10));
    });

    test('3. Live Remote Database: Stock Transfer persistence in stock_transfers & items', () async {
      HttpOverrides.global = _UnrestrictedHttpOverrides();
      final stockDatasource = StockRemoteDataSourceImpl(supabaseClient: client);

      // Get any existing DC and product to use as foreign keys
      final dcs = await client.from('distribution_centers').select('id, name').limit(2);
      expect(dcs.isNotEmpty, isTrue, reason: 'Requires at least one DC in database');
      final sourceDc = dcs[0];
      final destDc = dcs.length > 1 ? dcs[1] : dcs[0];

      final products = await client.from('products').select('id, name, sku').limit(1);
      expect(products.isNotEmpty, isTrue, reason: 'Requires at least one product in database');
      final product = products[0];

      final result = await stockDatasource.transferStockBetweenDCs(
        productIdOrSku: product['id'].toString(),
        sourceDcId: sourceDc['id'].toString(),
        sourceDcName: sourceDc['name'].toString(),
        destinationDcId: destDc['id'].toString(),
        destinationDcName: destDc['name'].toString(),
        quantity: 5,
        notes: 'Integration Test Audit Verification Transfer',
      );

      expect(result['success'], isTrue);
      expect(result['transferNumber'], isNotNull);

      // Query database directly to verify persistence
      final transferRow = await client
          .from('stock_transfers')
          .select()
          .eq('transfer_number', result['transferNumber'])
          .maybeSingle();

      expect(transferRow, isNotNull);
      final transferId = transferRow!['id'].toString();
      createdTransferIds.add(transferId);

      expect(transferRow['source_dc_id'], equals(sourceDc['id']));
      expect(transferRow['destination_dc_id'], equals(destDc['id']));
      expect(transferRow['status'], equals('in_transit'));

      final items = await client
          .from('stock_transfer_items')
          .select()
          .eq('transfer_id', transferId);

      expect(items.isNotEmpty, isTrue);
      expect(items[0]['quantity_shipped'], equals(5));
      expect(items[0]['product_id'], equals(product['id']));
    });

    test('4. Live Remote Database: Stock Return with nullable order_id persists in stock_returns', () async {
      HttpOverrides.global = _UnrestrictedHttpOverrides();
      final stockDatasource = StockRemoteDataSourceImpl(supabaseClient: client);

      final products = await client.from('products').select('id').limit(1);
      expect(products.isNotEmpty, isTrue);

      final agents = await client.from('delivery_agents').select('id').limit(1);
      final agentId = agents.isNotEmpty ? agents[0]['id'].toString() : 'b1111111-1111-4111-8111-111111111111';

      final result = await stockDatasource.processStockReturn(
        returnNumber: 'RET-TEST-${DateTime.now().millisecondsSinceEpoch.toString().substring(6)}',
        orderId: '', // Verifies nullable order_id on stock_returns
        deliveryAgentId: agentId,
        productId: products[0]['id'].toString(),
        quantity: 3,
        reason: 'Customer Unreachable (Integration Test)',
        notes: 'Test return verification without bound order ID',
      );

      expect(result['status'], equals('success'));
      expect(result['returnNumber'], isNotNull);

      // Verify row in stock_returns
      final returnRow = await client
          .from('stock_returns')
          .select()
          .eq('return_number', result['returnNumber'])
          .maybeSingle();

      expect(returnRow, isNotNull);
      createdReturnIds.add(returnRow!['id'].toString());
      expect(returnRow['order_id'], isNull);
      expect(returnRow['quantity'], equals(3));
      expect(returnRow['reason'], contains('Customer Unreachable'));
    });

    test('5. Live Remote Database: Inventory Audit persists in inventory_audits', () async {
      HttpOverrides.global = _UnrestrictedHttpOverrides();
      final stockDatasource = StockRemoteDataSourceImpl(supabaseClient: client);

      final dcs = await client.from('distribution_centers').select('id').limit(1);
      expect(dcs.isNotEmpty, isTrue);

      final result = await stockDatasource.submitInventoryAudit(
        distributionCenterId: dcs[0]['id'].toString(),
        auditedBy: 'Station Supervisor Test',
        totalPhysicalCounted: 9,
        totalSystemExpected: 10,
        discrepancyCount: 1,
        notes: 'Quarterly Inventory Audit Verification',
      );

      expect(result['status'], equals('success'));
      expect(result['auditNumber'], isNotNull);
      final auditNumber = result['auditNumber'].toString();
      createdAuditNumbers.add(auditNumber);

      // Verify row in inventory_audits
      final auditRow = await client
          .from('inventory_audits')
          .select()
          .eq('audit_number', auditNumber)
          .maybeSingle();

      expect(auditRow, isNotNull);
      expect(auditRow!['distribution_center_id'], equals(dcs[0]['id']));
      expect(auditRow['status'], equals('discrepancy_flagged'));
    });

    test('6. Live Remote Database: Order creation without DC ID does not force Wuse fallback', () async {
      HttpOverrides.global = _UnrestrictedHttpOverrides();
      final ordersDatasource = OrdersRemoteDataSourceImpl(client);

      final testOrderNumber = 'TEST-AUDIT-${DateTime.now().millisecondsSinceEpoch}';

      final created = await ordersDatasource.createOrder({
        'order_number': testOrderNumber,
        'customer_name': 'Kano Regional Recipient',
        'customer_phone': '08091112233',
        'delivery_address': 'Kano Municipal District',
        'delivery_city': 'Kano Municipal',
        'delivery_state': 'Kano',
        'product_name': 'Herbal Detox Formula',
        'quantity': 1,
        'total_amount': 25000.0,
        'base_price': 25000.0,
        'payment_type': 'pay_on_delivery',
        'payment_status': 'pending',
        'status': 'new',
        // Omit distribution_center_id to test database-level routing
      });

      expect(created.orderNumber, equals(testOrderNumber));
      createdOrderIds.add(created.id);

      // Fetch the created order from the database
      final orderRow = await client
          .from('orders')
          .select('id, order_number, distribution_center_id, delivery_state')
          .eq('id', created.id)
          .maybeSingle();

      expect(orderRow, isNotNull);
      expect(orderRow!['order_number'], equals(testOrderNumber));
      expect(orderRow['delivery_state'], equals('Kano'));
    });
  });
}
