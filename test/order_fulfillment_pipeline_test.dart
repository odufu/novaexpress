import 'package:flutter_test/flutter_test.dart';
import 'package:novexps/features/orders/domain/entities/order.dart';
import 'package:novexps/features/dc_console/domain/entities/distribution_center.dart';

void main() {
  group('Order Fulfillment Pipeline End-to-End Tests', () {
    final now = DateTime.now();

    test('Stage 1 & 2: Order created has status "assigned" and unassigned rider', () {
      final order = OrderEntity(
        id: 'ord-001',
        orderNumber: 'ORD-1001',
        customerName: 'Amina Bello',
        customerPhone: '08012345678',
        deliveryAddress: 'Wuse 2, Abuja',
        deliveryCity: 'Abuja',
        deliveryState: 'FCT',
        lga: 'Abuja Municipal',
        productName: 'Respira Herbal Blend',
        quantity: 2,
        paidQuantity: 2,
        freeQuantity: 0,
        basePrice: 25000,
        upsellAmount: 0,
        totalAmount: 50000,
        paymentType: 'pay_on_delivery',
        paymentStatus: 'pending',
        fulfillmentType: 'distribution_center',
        status: 'assigned',
        deliveryAgentId: null, // Strictly null at creation
        closerId: 'closer-001',
        closerName: 'Zainab Call Agent',
        createdAt: now,
      );

      expect(order.status, equals('assigned'));
      expect(order.isAssignedToCloser, isTrue);
      expect(order.deliveryAgentId, isNull);
      expect(order.isDispatchAssigned, isFalse);
      expect(order.isReady, isFalse);
    });

    test('Stage 3: 24h Inactivity check triggers for assigned order', () {
      final staleOrder = OrderEntity(
        id: 'ord-002',
        orderNumber: 'ORD-1002',
        customerName: 'John Doe',
        customerPhone: '08087654321',
        deliveryAddress: 'Garki, Abuja',
        deliveryCity: 'Abuja',
        deliveryState: 'FCT',
        productName: 'Respira Herbal Blend',
        quantity: 1,
        paidQuantity: 1,
        freeQuantity: 0,
        basePrice: 25000,
        upsellAmount: 0,
        totalAmount: 25000,
        paymentType: 'pay_on_delivery',
        paymentStatus: 'pending',
        fulfillmentType: 'distribution_center',
        status: 'assigned',
        closerId: 'closer-001',
        createdAt: now.subtract(const Duration(hours: 25)), // Stale > 24 hours
      );

      expect(staleOrder.isCloserPendingOver24Hours, isTrue);

      final freshOrder = staleOrder.copyWith(createdAt: now.subtract(const Duration(hours: 2)));
      expect(freshOrder.isCloserPendingOver24Hours, isFalse);
    });

    test('Stage 4: Multi-State DC Coverage matching', () {
      const multiStateDc = DistributionCenter(
        id: 'dc-north-central',
        code: 'DC-NC-01',
        name: 'North Central Regional Hub',
        state: 'FCT',
        city: 'Abuja',
        address: 'Idu Industrial Layout',
        operatingZones: [
          'STATE:FCT',
          'STATE:Nasarawa',
          'STATE:Niger',
          'ZONE:Karshi',
          'ZONE:Keffi',
        ],
        coveredStates: ['FCT', 'Nasarawa', 'Niger'],
      );

      // Matches state in coveredStates
      expect(multiStateDc.coversState('FCT'), isTrue);
      expect(multiStateDc.coversState('Nasarawa'), isTrue);
      expect(multiStateDc.coversState('Niger'), isTrue);
      expect(multiStateDc.coversState('Lagos'), isFalse);

      // Location match
      expect(multiStateDc.coversLocation(stateName: 'Nasarawa', lgaName: 'Keffi'), isTrue);
      expect(multiStateDc.coversLocation(stateName: 'Kano', lgaName: 'Nasarawa'), isFalse);
    });

    test('Stage 5 & 6: Closer marks ready and DC assigns rider -> status "dispatch_assigned"', () {
      final order = OrderEntity(
        id: 'ord-003',
        orderNumber: 'ORD-1003',
        customerName: 'Emeka Okafor',
        customerPhone: '08123456789',
        deliveryAddress: 'Maitama, Abuja',
        deliveryCity: 'Abuja',
        deliveryState: 'FCT',
        productName: 'Respira Herbal Blend',
        quantity: 1,
        paidQuantity: 1,
        freeQuantity: 0,
        basePrice: 25000,
        upsellAmount: 0,
        totalAmount: 25000,
        paymentType: 'pay_on_delivery',
        paymentStatus: 'pending',
        fulfillmentType: 'distribution_center',
        status: 'ready', // Closer confirmed readiness
        distributionCenterId: 'dc-north-central',
        createdAt: now,
      );

      expect(order.isReady, isTrue);

      // DC Dispatch Ops assigns available rider
      final dispatchAssigned = order.copyWith(
        status: 'dispatch_assigned',
        deliveryAgentId: 'rider-007',
        deliveryAgentName: 'Musa Garba',
        deliveryAgentCode: 'RD-007',
        assignedAt: now,
      );

      expect(dispatchAssigned.isDispatchAssigned, isTrue);
      expect(dispatchAssigned.status, equals('dispatch_assigned'));
      expect(dispatchAssigned.deliveryAgentId, equals('rider-007'));
    });

    test('Stage 7: Rider Accept & Reject Flow', () {
      final dispatchOrder = OrderEntity(
        id: 'ord-004',
        orderNumber: 'ORD-1004',
        customerName: 'Fatima Aliyu',
        customerPhone: '08099887766',
        deliveryAddress: 'Kubwa, Abuja',
        deliveryCity: 'Abuja',
        deliveryState: 'FCT',
        productName: 'Respira Herbal Blend',
        quantity: 1,
        paidQuantity: 1,
        freeQuantity: 0,
        basePrice: 25000,
        upsellAmount: 0,
        totalAmount: 25000,
        paymentType: 'pay_on_delivery',
        paymentStatus: 'pending',
        fulfillmentType: 'distribution_center',
        status: 'dispatch_assigned',
        deliveryAgentId: 'rider-007',
        deliveryAgentName: 'Musa Garba',
        createdAt: now,
      );

      // Action A: Rider Accepts
      final acceptedOrder = dispatchOrder.copyWith(
        status: 'order_accepted',
      );
      expect(acceptedOrder.isOrderAccepted, isTrue);
      expect(acceptedOrder.status, equals('order_accepted'));

      // Action B: Rider Rejects (Returns to DC intake queue as ready)
      final rejectedOrder = dispatchOrder.copyWith(
        status: 'ready',
        clearAssignment: true,
        deliveryNotes: '[RIDER REJECTED] Bike breakdown',
      );
      expect(rejectedOrder.status, equals('ready'));
      expect(rejectedOrder.isReady, isTrue);
      expect(rejectedOrder.deliveryAgentId, isNull);
      expect(rejectedOrder.deliveryAgentName, isNull);
    });

    test('Stage 8: Rider starts delivery trip -> delivery_in_progress (in_transit)', () {
      final acceptedOrder = OrderEntity(
        id: 'ord-005',
        orderNumber: 'ORD-1005',
        customerName: 'Chidi Anozie',
        customerPhone: '08033445566',
        deliveryAddress: 'Utako, Abuja',
        deliveryCity: 'Abuja',
        deliveryState: 'FCT',
        productName: 'Respira Herbal Blend',
        quantity: 1,
        paidQuantity: 1,
        freeQuantity: 0,
        basePrice: 25000,
        upsellAmount: 0,
        totalAmount: 25000,
        paymentType: 'pay_on_delivery',
        paymentStatus: 'pending',
        fulfillmentType: 'distribution_center',
        status: 'order_accepted',
        deliveryAgentId: 'rider-007',
        createdAt: now,
      );

      final inProgressOrder = acceptedOrder.copyWith(
        status: 'in_transit',
      );

      expect(inProgressOrder.isDeliveryInProgress, isTrue);
      expect(inProgressOrder.status, equals('in_transit'));
    });

    test('Stage 9: Reschedule flow with today & 12:00 PM default and snooze reminder', () {
      final scheduledDate = DateTime(now.year, now.month, now.day, 12, 0);

      final order = OrderEntity(
        id: 'ord-006',
        orderNumber: 'ORD-1006',
        customerName: 'Kemi Adebayo',
        customerPhone: '08122334455',
        deliveryAddress: 'Gwarinpa, Abuja',
        deliveryCity: 'Abuja',
        deliveryState: 'FCT',
        productName: 'Respira Herbal Blend',
        quantity: 1,
        paidQuantity: 1,
        freeQuantity: 0,
        basePrice: 25000,
        upsellAmount: 0,
        totalAmount: 25000,
        paymentType: 'pay_on_delivery',
        paymentStatus: 'pending',
        fulfillmentType: 'distribution_center',
        status: 'rescheduled',
        rescheduledDeliveryDate: scheduledDate,
        createdAt: now,
      );

      expect(order.isRescheduled, isTrue);
      expect(order.rescheduledDeliveryDate, equals(scheduledDate));
      expect(order.rescheduledDeliveryDate!.hour, equals(12));
      expect(order.rescheduledDeliveryDate!.minute, equals(0));

      expect(order.hasScheduledFollowUp, isTrue);

      // Past or due reminder is due
      final dueOrder = order.copyWith(rescheduledDeliveryDate: now.subtract(const Duration(minutes: 5)));
      expect(dueOrder.isFollowUpReminderDue, isTrue);
      expect(dueOrder.followUpTimingLabel.contains('Overdue'), isTrue);

      // Future reminder is not due yet
      final futureOrder = order.copyWith(rescheduledDeliveryDate: now.add(const Duration(hours: 2)));
      expect(futureOrder.isFollowUpReminderDue, isFalse);
      expect(futureOrder.followUpTimingLabel.contains('Due in'), isTrue);

      // Snooze reminder by 5 minutes suppresses due status until snooze expires
      final snoozed = dueOrder.copyWith(
        reminderSnoozedUntil: now.add(const Duration(minutes: 5)),
      );
      expect(snoozed.reminderSnoozedUntil, isNotNull);
      expect(snoozed.isFollowUpReminderDue, isFalse); // Suppressed by active snooze!
      expect(snoozed.followUpTimingLabel.contains('Snoozed'), isTrue);
    });

    test('Stage 10 & 11: Not Picking, Call Back over 4 hours urgency', () {
      final notPickingOrder = OrderEntity(
        id: 'ord-007',
        orderNumber: 'ORD-1007',
        customerName: 'Haruna Sanusi',
        customerPhone: '08055667788',
        deliveryAddress: 'Lugbe, Abuja',
        deliveryCity: 'Abuja',
        deliveryState: 'FCT',
        productName: 'Respira Herbal Blend',
        quantity: 1,
        paidQuantity: 1,
        freeQuantity: 0,
        basePrice: 25000,
        upsellAmount: 0,
        totalAmount: 25000,
        paymentType: 'pay_on_delivery',
        paymentStatus: 'pending',
        fulfillmentType: 'distribution_center',
        status: 'not_picking',
        createdAt: now,
      );

      expect(notPickingOrder.isNotPicking, isTrue);

      final staleCallBackOrder = notPickingOrder.copyWith(
        status: 'call_back',
        createdAt: now.subtract(const Duration(hours: 5)),
      );
      expect(staleCallBackOrder.isCallBack, isTrue);
      expect(staleCallBackOrder.isCallBackPendingOver4Hours, isTrue);
    });

    test('Stage 12: Direct Company Account Transfer delivery settlement', () {
      final order = OrderEntity(
        id: 'ord-008',
        orderNumber: 'ORD-1008',
        customerName: 'Oluwaseun David',
        customerPhone: '08099112233',
        deliveryAddress: 'Jabi, Abuja',
        deliveryCity: 'Abuja',
        deliveryState: 'FCT',
        productName: 'Respira Herbal Blend',
        quantity: 1,
        paidQuantity: 1,
        freeQuantity: 0,
        basePrice: 25000,
        upsellAmount: 0,
        totalAmount: 25000,
        paymentType: 'prepaid',
        paymentStatus: 'paid',
        remittanceStatus: 'direct_transfer',
        financialSettlementStatus: 'direct_transfer_settled',
        fulfillmentType: 'distribution_center',
        status: 'delivered',
        deliveryAgentId: 'rider-007',
        agentEntitlement: 1500,
        transportFee: 500,
        deliveryNotes: '[DIRECT COMPANY TRANSFER to Zenith Bank (1234567890)]',
        createdAt: now,
      );

      expect(order.isDelivered, isTrue);
      expect(order.isDirectTransfer, isTrue);
      expect(order.isCashPod, isFalse);
      expect(order.isUnremitted, isFalse); // Does NOT add up to awaiting cash remittance!
      expect(order.isRemitted, isTrue);
      expect(order.agentEntitlement, equals(1500));
      expect(order.transportFee, equals(500));
    });
  });
}
