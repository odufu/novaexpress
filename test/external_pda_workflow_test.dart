import 'package:flutter_test/flutter_test.dart';
import 'package:novexps/features/dc_console/domain/entities/dc_fleet_driver.dart';
import 'package:novexps/features/orders/domain/entities/order.dart';
import 'package:novexps/features/stock/domain/entities/stock_item.dart';
import 'package:novexps/features/stock/domain/entities/rider_stock_allocation.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('External PDA System & Logistics Workflow Tests', () {
    test('1. DCFleetDriver recognizes External PDA classification and code prefix', () {
      const extDriver = DCFleetDriver(
        id: 'drv-ext-001',
        driverCode: 'EXT-PDA-782',
        name: 'Garba Offline Courier',
        phone: '08039988776',
        assignedZone: 'Wuse 2',
        personnelType: 'external_pda',
        compensationType: 'commission',
        commissionRate: 1500.0,
      );

      expect(extDriver.isExternalPda, isTrue);
      expect(extDriver.isPda, isFalse);
      expect(extDriver.isInHouseRider, isFalse);
      expect(extDriver.driverCode.startsWith('EXT-PDA-'), isTrue);

      const regularPda = DCFleetDriver(
        id: 'drv-pda-002',
        driverCode: 'PDA-7102',
        name: 'Musa App Courier',
        phone: '08021112233',
        assignedZone: 'Garki',
        personnelType: 'pda',
      );

      expect(regularPda.isExternalPda, isFalse);
      expect(regularPda.isPda, isTrue);
    });

    test('2. Stock Ops allocates DC shelf stock to External PDA custody', () {
      final warehouseStock = StockItemEntity(
        id: 'prod-grazer-01',
        sku: 'NOVA-GRZ-01',
        name: 'Grazer Herbal Tea',
        description: 'Herbal Detox Tea',
        category: 'Health & Wellness',
        price: 21500.0,
        availableCount: 50,
        assignedCount: 0,
        deliveredCount: 0,
        returnedCount: 0,
        ownerName: 'Novacare Limited',
      );

      const allocationQuantity = 10;
      expect(warehouseStock.availableCount >= allocationQuantity, isTrue);

      // Stock Ops allocates 10 units to External PDA: warehouse available drops, assigned increases
      final updatedWarehouseStock = warehouseStock.copyWith(
        availableCount: warehouseStock.availableCount - allocationQuantity,
        assignedCount: warehouseStock.assignedCount + allocationQuantity,
      );

      expect(updatedWarehouseStock.availableCount, equals(40));
      expect(updatedWarehouseStock.assignedCount, equals(10));

      // External PDA receives stock in custody
      final extAllocation = RiderStockAllocation(
        id: 'alloc-ext-01',
        riderId: 'drv-ext-001',
        riderName: 'Garba Offline Courier',
        riderCode: 'EXT-PDA-782',
        productId: warehouseStock.id,
        productName: warehouseStock.name,
        sku: warehouseStock.sku,
        allocatedUnits: allocationQuantity,
        deliveredUnits: 0,
        inCustodyUnits: allocationQuantity,
        unitPrice: warehouseStock.price,
        allocatedAt: DateTime.now(),
      );

      expect(extAllocation.inCustodyUnits, equals(10));
      expect(extAllocation.deliveredUnits, equals(0));
      expect(extAllocation.riderCode, equals('EXT-PDA-782'));
    });

    test('3. Dispatch Ops assigns order to External PDA and marks In-Transit with dispatch audit note', () {
      final order = OrderEntity(
        id: 'ord-test-ext-101',
        orderNumber: 'NX-EXT-901',
        customerName: 'Hauwa Mohammed',
        customerPhone: '08099881122',
        deliveryAddress: 'Plot 402 Maitama Crescent',
        deliveryCity: 'Maitama',
        deliveryState: 'Federal Capital Territory',
        productName: 'Respira Lungs Detox Tea',
        quantity: 2,
        basePrice: 18000.0,
        upsellAmount: 0.0,
        totalAmount: 36000.0,
        status: 'unassigned',
        paymentType: 'pod_cash',
        paymentStatus: 'pending',
        createdAt: DateTime.now(),
      );

      // Dispatch Ops assigns order to External PDA
      final assignedOrder = order.copyWith(
        deliveryAgentId: 'drv-ext-001',
        deliveryAgentName: 'Garba Offline Courier',
        deliveryAgentCode: 'EXT-PDA-782',
        status: 'assigned',
        assignedAt: DateTime.now(),
      );

      expect(assignedOrder.deliveryAgentId, equals('drv-ext-001'));
      expect(assignedOrder.deliveryAgentCode, equals('EXT-PDA-782'));

      // Dispatch Ops marks Out for Delivery / In-Transit on behalf of offline courier
      final inTransitOrder = assignedOrder.copyWith(
        status: 'in_transit',
        deliveryNotes: '[EXTERNAL PDA DISPATCH: Out for delivery with Garba Offline Courier (EXT-PDA-782)]',
      );

      expect(inTransitOrder.status, equals('in_transit'));
      expect(inTransitOrder.deliveryNotes, contains('EXTERNAL PDA DISPATCH'));
    });

    test('4. Dispatch Ops logs POD and delivery completion for External PDA, deducting custody', () {
      final currentAllocation = RiderStockAllocation(
        id: 'alloc-ext-01',
        riderId: 'drv-ext-001',
        riderName: 'Garba Offline Courier',
        riderCode: 'EXT-PDA-782',
        productId: 'prod-grazer-01',
        productName: 'Grazer Herbal Tea',
        sku: 'NOVA-GRZ-01',
        allocatedUnits: 10,
        deliveredUnits: 0,
        inCustodyUnits: 10,
        unitPrice: 21500.0,
        allocatedAt: DateTime.now(),
      );

      const deliveredQty = 2;

      // Delivery completed by Dispatch Ops on behalf of External PDA
      final updatedAllocation = currentAllocation.copyWith(
        inCustodyUnits: currentAllocation.inCustodyUnits - deliveredQty,
        deliveredUnits: currentAllocation.deliveredUnits + deliveredQty,
      );

      expect(updatedAllocation.inCustodyUnits, equals(8));
      expect(updatedAllocation.deliveredUnits, equals(2));

      // Delivered order with proxy POD
      final deliveredOrder = OrderEntity(
        id: 'ord-test-ext-101',
        orderNumber: 'NX-EXT-901',
        customerName: 'Hauwa Mohammed',
        customerPhone: '08099881122',
        deliveryAddress: 'Plot 402 Maitama Crescent',
        deliveryCity: 'Maitama',
        deliveryState: 'Federal Capital Territory',
        productName: 'Grazer Herbal Tea',
        quantity: deliveredQty,
        basePrice: 21500.0,
        upsellAmount: 0.0,
        totalAmount: 43000.0,
        status: 'delivered',
        paymentType: 'pod_cash',
        paymentStatus: 'collected',
        deliveredAt: DateTime.now(),
        deliveryAgentId: 'drv-ext-001',
        deliveryAgentName: 'Garba Offline Courier',
        deliveryAgentCode: 'EXT-PDA-782',
        deliveryNotes: '[DELIVERED BY DISPATCH OPS: Abigail Operations • Fulfilling Rider: Garba Offline Courier (EXT-PDA-782) • Cash Collected POD: ₦43000]',
        createdAt: DateTime.now().subtract(const Duration(hours: 3)),
      );

      expect(deliveredOrder.isDelivered, isTrue);
      expect(deliveredOrder.paymentStatus, equals('collected'));
      expect(deliveredOrder.deliveryAgentCode, equals('EXT-PDA-782'));
      expect(deliveredOrder.deliveryNotes, contains('Garba Offline Courier'));
    });

    test('5. Dispatch Ops logs Attempt / Reschedule for External PDA with audit details', () {
      final order = OrderEntity(
        id: 'ord-test-ext-102',
        orderNumber: 'NX-EXT-902',
        customerName: 'Bala Danladi',
        customerPhone: '08055443322',
        deliveryAddress: 'Area 11, Garki, Abuja',
        deliveryCity: 'Garki',
        deliveryState: 'Federal Capital Territory',
        productName: 'Ura Clear',
        quantity: 1,
        basePrice: 15000.0,
        upsellAmount: 0.0,
        totalAmount: 15000.0,
        status: 'in_transit',
        paymentType: 'pod_cash',
        paymentStatus: 'pending',
        deliveryAgentId: 'drv-ext-001',
        deliveryAgentName: 'Garba Offline Courier',
        deliveryAgentCode: 'EXT-PDA-782',
        createdAt: DateTime.now(),
      );

      // Dispatch Ops logs callback/reschedule attempt
      final rescheduledOrder = order.copyWith(
        status: 'rescheduled',
        deliveryNotes: '[ATTEMPT LOG: Customer phone unreachable / switched off • Reschedule: 25 Nov 2026 • Logged by Dispatch Ops]',
      );

      expect(rescheduledOrder.status, equals('rescheduled'));
      expect(rescheduledOrder.deliveryNotes, contains('Customer phone unreachable'));
    });
  });
}
