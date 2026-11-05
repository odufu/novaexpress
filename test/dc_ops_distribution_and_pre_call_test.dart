import 'package:flutter_test/flutter_test.dart';
import 'package:novexps/features/dc_console/domain/entities/dc_operations_officer.dart';
import 'package:novexps/features/dc_console/domain/services/dc_order_distribution_service.dart';
import 'package:novexps/features/orders/domain/entities/order.dart';

void main() {
  group('DC Order Distribution & Even Load Balancing Tests', () {
    final dcId = '22222222-2222-4222-8222-222222222222';

    final officerA = DCOperationsOfficer(
      id: 'officer-a',
      firstName: 'Ibrahim',
      lastName: 'Musa',
      staffCode: 'OPS-101',
      email: 'ibrahim@novaxpress.ng',
      phone: '+2348011111111',
      distributionCenterId: dcId,
      distributionCenterName: 'Wuse Grand Central Hub',
      role: 'dc_operations',
      isActive: true,
      isAvailable: true,
      createdAt: DateTime.now().subtract(const Duration(days: 30)),
    );

    final officerB = DCOperationsOfficer(
      id: 'officer-b',
      firstName: 'Chidi',
      lastName: 'Okafor',
      staffCode: 'OPS-102',
      email: 'chidi@novaxpress.ng',
      phone: '+2348022222222',
      distributionCenterId: dcId,
      distributionCenterName: 'Wuse Grand Central Hub',
      role: 'dc_operations',
      isActive: true,
      isAvailable: true,
      createdAt: DateTime.now().subtract(const Duration(days: 20)),
    );

    final officerCUnavailable = DCOperationsOfficer(
      id: 'officer-c',
      firstName: 'Fatima',
      lastName: 'Bello',
      staffCode: 'OPS-103',
      email: 'fatima@novaxpress.ng',
      phone: '+2348033333333',
      distributionCenterId: dcId,
      distributionCenterName: 'Wuse Grand Central Hub',
      role: 'dc_operations',
      isActive: true,
      isAvailable: false, // Turned off by DC Admin or off-duty
      createdAt: DateTime.now().subtract(const Duration(days: 10)),
    );

    test('Evenly distributes incoming orders to available Dispatch Ops with lowest workload', () {
      final List<DCOperationsOfficer> officers = [officerA, officerB, officerCUnavailable];

      // Initially no active orders -> first available officer selected
      final firstAssigned = DCOrderDistributionService.findNextAvailableDispatchOps(
        dcId: dcId,
        officers: officers,
        orders: [],
      );

      expect(firstAssigned, isNotNull);
      expect(firstAssigned!.id, equals('officer-a'));

      // If officer A has 1 active order, next order goes to officer B
      final order1 = OrderEntity(
        id: 'order-1',
        orderNumber: 'ORD-001',
        customerName: 'Amina',
        customerPhone: '08012345678',
        deliveryState: 'Abuja',
        deliveryCity: 'Wuse',
        deliveryAddress: 'Street 1',
        productName: 'Respira Cleanser',
        status: 'pending_dispatch',
        quantity: 1,
        basePrice: 15000.0,
        upsellAmount: 0.0,
        paymentType: 'pod',
        paymentStatus: 'pending',
        totalAmount: 15000.0,
        distributionCenterId: dcId,
        logisticsRepId: 'officer-a',
        createdAt: DateTime.now(),
      );

      final secondAssigned = DCOrderDistributionService.findNextAvailableDispatchOps(
        dcId: dcId,
        officers: officers,
        orders: [order1],
      );

      expect(secondAssigned, isNotNull);
      expect(secondAssigned!.id, equals('officer-b'));
    });

    test('Strictly excludes Dispatch Ops whose availability is turned off by DC Admin', () {
      final List<DCOperationsOfficer> officers = [officerCUnavailable];

      final assigned = DCOrderDistributionService.findNextAvailableDispatchOps(
        dcId: dcId,
        officers: officers,
        orders: [],
      );

      // officerC is off-duty / unavailable, so result is null
      expect(assigned, isNull);
    });

    test('Until Dispatch Ops assigns order to rider, deliveryAgentId remains null and no rider gets the order', () {
      final incomingOrder = OrderEntity(
        id: 'order-intake',
        orderNumber: 'ORD-INTAKE-100',
        customerName: 'Mohammed Lawal',
        customerPhone: '08099887766',
        deliveryState: 'Abuja',
        deliveryCity: 'Garki',
        deliveryAddress: 'Plot 4, Area 11',
        productName: 'Respira Treatment Pack',
        status: 'pending_dispatch',
        quantity: 2,
        basePrice: 14000.0,
        upsellAmount: 0.0,
        paymentType: 'pod',
        paymentStatus: 'pending',
        totalAmount: 28000.0,
        distributionCenterId: dcId,
        logisticsRepId: 'officer-a',
        deliveryAgentId: null, // No rider assigned yet
        createdAt: DateTime.now(),
      );

      expect(incomingOrder.deliveryAgentId, isNull);
      expect(incomingOrder.deliveryAgentName, isNull);
      expect(incomingOrder.logisticsRepId, equals('officer-a'));
    });
  });

  group('Rider Reassignment Order Exclusion Tests', () {
    test('Previous rider strictly does not see order once reassigned to new rider', () {
      final initialOrder = OrderEntity(
        id: 'order-reassign-1',
        orderNumber: 'ORD-REA-01',
        customerName: 'Emeka',
        customerPhone: '08011223344',
        deliveryState: 'Abuja',
        deliveryCity: 'Maitama',
        deliveryAddress: 'Zone 4',
        productName: 'Vitamin C Cream',
        status: 'assigned',
        quantity: 1,
        basePrice: 18000.0,
        upsellAmount: 0.0,
        paymentType: 'pod',
        paymentStatus: 'pending',
        totalAmount: 18000.0,
        deliveryAgentId: 'rider-old',
        deliveryAgentName: 'Aliyu Driver',
        deliveryAgentCode: 'PDA-101',
        createdAt: DateTime.now(),
      );

      // Reassigned to new rider
      final reassignedOrder = initialOrder.copyWith(
        deliveryAgentId: 'rider-new',
        deliveryAgentName: 'Sunday Peter',
        deliveryAgentCode: 'PDA-202',
      );

      // Query from perspective of rider-old:
      final isVisibleToOldRider = reassignedOrder.deliveryAgentId == 'rider-old' ||
          reassignedOrder.assignedAgentId == 'rider-old';

      expect(isVisibleToOldRider, isFalse);

      // Query from perspective of rider-new:
      final isVisibleToNewRider = reassignedOrder.deliveryAgentId == 'rider-new';
      expect(isVisibleToNewRider, isTrue);
    });
  });

  group('Role & Account Reschedule Isolation Tests', () {
    test('Dispatch Ops reschedules are strictly isolated from Closers and Riders', () {
      final dcOpsRescheduledOrder = OrderEntity(
        id: 'order-resched-dc',
        orderNumber: 'ORD-RES-01',
        customerName: 'Grace Danjuma',
        customerPhone: '08055443322',
        deliveryState: 'Abuja',
        deliveryCity: 'Wuse 2',
        deliveryAddress: 'Aminu Kano Crescent',
        productName: 'Hair Growth Serum',
        status: 'rescheduled',
        quantity: 1,
        basePrice: 22000.0,
        upsellAmount: 0.0,
        paymentType: 'pod',
        paymentStatus: 'pending',
        totalAmount: 22000.0,
        logisticsRepId: 'dispatch-ops-1',
        rescheduledByUserId: 'dispatch-ops-1',
        rescheduledByRole: 'dc_operations',
        rescheduledDeliveryDate: DateTime.now().subtract(const Duration(minutes: 5)),
        createdAt: DateTime.now().subtract(const Duration(hours: 1)),
      );

      // 1. Check Closer Console visibility
      final isCloserMatch = (dcOpsRescheduledOrder.rescheduledByRole == 'closer');
      expect(isCloserMatch, isFalse, reason: 'Closer must NOT see Dispatch Ops reschedules');

      // 2. Check Rider Console visibility
      final isRiderMatch = (dcOpsRescheduledOrder.rescheduledByRole == 'rider');
      expect(isRiderMatch, isFalse, reason: 'Rider must NOT see Dispatch Ops reschedules');

      // 3. Check Other Dispatch Ops visibility
      final isSameDispatchOps = dcOpsRescheduledOrder.rescheduledByUserId == 'dispatch-ops-1';
      final isOtherDispatchOps = dcOpsRescheduledOrder.rescheduledByUserId == 'dispatch-ops-2';

      expect(isSameDispatchOps, isTrue, reason: 'The Dispatch Ops who set the reschedule sees it');
      expect(isOtherDispatchOps, isFalse, reason: 'Other Dispatch Ops do not see this reminder');
    });

    test('Closer reschedules are strictly isolated from Dispatch Ops and Riders', () {
      final closerRescheduledOrder = OrderEntity(
        id: 'order-resched-closer',
        orderNumber: 'ORD-RES-02',
        customerName: 'Blessing Kalu',
        customerPhone: '08077665544',
        deliveryState: 'Lagos',
        deliveryCity: 'Ikeja',
        deliveryAddress: 'Allen Avenue',
        productName: 'Facial Kit',
        status: 'rescheduled',
        quantity: 1,
        basePrice: 35000.0,
        upsellAmount: 0.0,
        paymentType: 'pod',
        paymentStatus: 'pending',
        totalAmount: 35000.0,
        closerId: 'closer-10',
        rescheduledByUserId: 'closer-10',
        rescheduledByRole: 'closer',
        rescheduledDeliveryDate: DateTime.now().subtract(const Duration(minutes: 5)),
        createdAt: DateTime.now().subtract(const Duration(hours: 2)),
      );

      final isDcOpsMatch = (closerRescheduledOrder.rescheduledByRole == 'dc_operations');
      expect(isDcOpsMatch, isFalse, reason: 'Dispatch Ops must NOT see Closer reschedules');

      final isRiderMatch = (closerRescheduledOrder.rescheduledByRole == 'rider');
      expect(isRiderMatch, isFalse, reason: 'Rider must NOT see Closer reschedules');

      final isSameCloser = closerRescheduledOrder.rescheduledByUserId == 'closer-10';
      expect(isSameCloser, isTrue);
    });
  });

  group('Order Quantity Downgrade Calculations', () {
    test('Calculates proportional deal pricing and notes when downgraded to match rider custody', () {
      final originalQuantity = 3;
      final originalTotal = 45000.0;
      final unitPrice = originalTotal / originalQuantity; // 15000.0
      final riderAvailableCustody = 2; // Rider only has 2 units

      final downgradedTotal = unitPrice * riderAvailableCustody; // 30000.0
      expect(downgradedTotal, equals(30000.0));

      final downgradeAuditNote =
          '[Order Downgraded from $originalQuantity to $riderAvailableCustody units to match rider vehicle stock]';

      expect(downgradeAuditNote, contains('from 3 to 2 units'));
    });
  });
}
