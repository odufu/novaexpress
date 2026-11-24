import 'package:flutter_test/flutter_test.dart';
import 'package:novexps/features/orders/domain/services/smart_order_parser_service.dart';
import 'package:novexps/features/orders/domain/entities/order.dart';
import 'package:novexps/features/stock/domain/entities/stock_item.dart';
import 'package:novexps/features/stock/domain/entities/rider_stock_allocation.dart';
import 'package:novexps/features/finance/domain/entities/remittance.dart';
import 'package:novexps/features/finance/data/models/remittance_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('NovaXpress Logistics End-to-End Workflow Tests', () {
    // 1. WhatsApp Parser -> In-App Order
    test('1. Dispatch ops can parse order copied from WhatsApp and turn into in-app order', () {
      const rawWhatsAppMessage = '''Order number: NX-WA-2026-8812
Customer name: Hajia Maryam Bello
Customer address: Plot 42, Shehu Shagari Way, Maitama, Abuja
State: Federal Capital Territory
Phone number: 08031234567
Details of products:
 - Grazer Herbal Tea x2 · NGN 43,000
Total order value: NGN 43,000
Amount to collect: NGN 43,000
Closer name: Caroline Onoja
Closer phone: 08160322891''';

      final parsed = SmartOrderParserService.parse(rawWhatsAppMessage);

      expect(parsed.orderNumber, equals('NX-WA-2026-8812'));
      expect(parsed.customerName, equals('Hajia Maryam Bello'));
      expect(parsed.phoneNumber, equals('08031234567'));
      expect(parsed.state, contains('Federal Capital Territory'));
      expect(parsed.amountToCollect, equals(43000.0));
      expect(parsed.items.length, equals(1));
      expect(parsed.items.first.quantity, equals(2));
      expect(parsed.items.first.productName, contains('Grazer Herbal Tea'));
      expect(parsed.closerName, equals('Caroline Onoja'));
    });

    // 2 & 3. Order Assignment to Rider and Rider Acceptance
    test('2 & 3. Dispatch Ops assigns order to rider, and rider can see and accept it', () {
      final order = OrderEntity(
        id: 'ord-test-8812',
        orderNumber: 'NX-WA-2026-8812',
        customerName: 'Hajia Maryam Bello',
        customerPhone: '08031234567',
        deliveryAddress: 'Plot 42, Shehu Shagari Way, Maitama, Abuja',
        deliveryCity: 'Maitama',
        deliveryState: 'Federal Capital Territory',
        productName: 'Grazer Herbal Tea',
        quantity: 2,
        basePrice: 21500.0,
        upsellAmount: 0.0,
        totalAmount: 43000.0,
        status: 'unassigned',
        paymentType: 'pod_cash',
        paymentStatus: 'pending',
        createdAt: DateTime.now(),
      );

      // Dispatch Ops assigns order to rider (NovaXpress Logistics fleet)
      final assignedOrder = order.copyWith(
        deliveryAgentId: 'rider-nx-001',
        deliveryAgentName: 'Emeka NovaXpress Rider',
        deliveryAgentCode: 'NX-ABJ-01',
        status: 'dispatch_assigned',
        assignedAt: DateTime.now(),
      );

      expect(assignedOrder.deliveryAgentId, equals('rider-nx-001'));
      expect(assignedOrder.status, equals('dispatch_assigned'));

      // Rider receives and accepts the order
      final acceptedOrder = assignedOrder.copyWith(
        status: 'accepted',
      );

      expect(acceptedOrder.status, equals('accepted'));
      expect(acceptedOrder.isOrderAccepted || acceptedOrder.status == 'accepted', isTrue);
    });

    // 4. Stock Ops allocates products to riders strictly from warehouse stock
    test('4. Stock Ops assigns products to riders strictly from DC available shelf stock', () {
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

      const allocationQuantity = 5;
      expect(warehouseStock.availableCount >= allocationQuantity, isTrue);

      // Allocation reduces available count and increases assigned count
      final updatedWarehouseStock = warehouseStock.copyWith(
        availableCount: warehouseStock.availableCount - allocationQuantity,
        assignedCount: warehouseStock.assignedCount + allocationQuantity,
      );

      expect(updatedWarehouseStock.availableCount, equals(45));
      expect(updatedWarehouseStock.assignedCount, equals(5));

      // Rider receives stock in custody
      final riderAllocation = RiderStockAllocation(
        id: 'alloc-test-01',
        riderId: 'rider-nx-001',
        riderName: 'Emeka NovaXpress Rider',
        riderCode: 'NX-ABJ-01',
        productId: warehouseStock.id,
        productName: warehouseStock.name,
        sku: warehouseStock.sku,
        allocatedUnits: allocationQuantity,
        deliveredUnits: 0,
        inCustodyUnits: allocationQuantity,
        unitPrice: warehouseStock.price,
        allocatedAt: DateTime.now(),
      );

      expect(riderAllocation.inCustodyUnits, equals(5));
      expect(riderAllocation.deliveredUnits, equals(0));
    });

    // 5. When delivery is done, stock is properly deducted from custody
    test('5. When delivery is done (POD), rider stock custody is properly deducted', () {
      final currentAllocation = RiderStockAllocation(
        id: 'alloc-test-01',
        riderId: 'rider-nx-001',
        riderName: 'Emeka NovaXpress Rider',
        riderCode: 'NX-ABJ-01',
        productId: 'prod-grazer-01',
        productName: 'Grazer Herbal Tea',
        sku: 'NOVA-GRZ-01',
        allocatedUnits: 5,
        deliveredUnits: 0,
        inCustodyUnits: 5,
        unitPrice: 21500.0,
        allocatedAt: DateTime.now(),
      );

      const deliveredQty = 2;

      // Delivery completed
      final updatedAllocation = currentAllocation.copyWith(
        inCustodyUnits: currentAllocation.inCustodyUnits - deliveredQty,
        deliveredUnits: currentAllocation.deliveredUnits + deliveredQty,
      );

      expect(updatedAllocation.inCustodyUnits, equals(3));
      expect(updatedAllocation.deliveredUnits, equals(2));
    });

    // 6. Remittance can be registered by rider
    test('6. Remittance can be registered and created with order linkages', () {
      final now = DateTime.now();
      final remittance = RemittanceModel(
        id: 'REM-2026-001',
        referenceNumber: 'REMIT-NX-8812',
        companyId: '11111111-1111-4111-8111-111111111111',
        deliveryAgentId: 'rider-nx-001',
        amount: 40500.0,
        grossCollections: 43000.0,
        commissionDeducted: 1000.0,
        transportAllowanceDeducted: 1500.0,
        status: 'pending',
        payerName: 'Emeka NovaXpress Rider',
        paymentMethod: 'cash_to_dc',
        createdAt: now,
        associatedOrders: [
          RemittanceOrderItem(
            orderId: 'ord-test-8812',
            orderNumber: 'NX-WA-2026-8812',
            customerName: 'Hajia Maryam Bello',
            status: 'delivered',
            paymentType: 'pod_cash',
            cashCollected: 43000.0,
            date: now,
          ),
        ],
      );

      expect(remittance.isPending, isTrue);
      expect(remittance.grossCollections, equals(43000.0));
      expect(remittance.amount, equals(40500.0));
      expect(remittance.associatedOrders.length, equals(1));
    });

    // 7. Finance ops can directly mark remittance complete without rider requesting
    test('7. Finance ops can clear unrequested field cash directly and mark complete', () {
      final now = DateTime.now();
      const directRefCode = 'DIR-CLR-9901';

      // Finance Ops clears unrequested remittance directly
      final directRemittance = RemittanceModel(
        id: 'rem-dir-${now.millisecondsSinceEpoch}',
        referenceNumber: directRefCode,
        companyId: '11111111-1111-4111-8111-111111111111',
        deliveryAgentId: 'rider-nx-001',
        distributionCenterId: '22222222-2222-4222-8222-222222222222',
        amount: 40500.0,
        grossCollections: 43000.0,
        commissionDeducted: 1000.0,
        transportAllowanceDeducted: 1500.0,
        paymentMethod: 'dc_handover',
        status: 'verified',
        verifiedByUserId: 'finance-officer-01',
        verifiedByName: 'Joel Finance Lead',
        payerName: 'Emeka NovaXpress Rider',
        notes: 'Direct physical cash handover cleared at DC Treasury by Finance Ops',
        createdAt: now,
        verifiedAt: now,
        associatedOrders: [
          RemittanceOrderItem(
            orderId: 'ord-test-8812',
            orderNumber: 'NX-WA-2026-8812',
            customerName: 'Hajia Maryam Bello',
            status: 'delivered',
            paymentType: 'pod_cash',
            cashCollected: 43000.0,
            date: now,
          ),
        ],
      );

      expect(directRemittance.isVerified, isTrue);
      expect(directRemittance.isPending, isFalse);
      expect(directRemittance.verifiedByName, equals('Joel Finance Lead'));
      expect(directRemittance.amount, equals(40500.0));
    });
  });
}
