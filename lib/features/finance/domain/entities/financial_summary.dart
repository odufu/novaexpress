import '../../../auth/domain/entities/user.dart';
import '../../../orders/domain/entities/order.dart';
import 'remittance.dart';
import 'transaction_item.dart';

class FinancialSummary {
  final double cashCollectedAllTime;
  final double cashCollectedToday;
  final double totalCommissionRetained;
  final double totalTransportRetained;
  final double totalTransferFeesRetained;
  final double totalEarningRetained;
  final double totalVerifiedRemitted;
  final double totalPendingApprovalRemitted;
  final double pendingRemittanceToDC; // Cash in custody to remit
  final double myDirectTransfersBalance; // Withdrawable balance from prepaid / direct transfers
  final double totalMonthEarnings;
  final int totalDeliveredOrdersCount;
  final int todayDeliveredOrdersCount;
  final int deliveredCashOrdersCount;
  final int deliveredPrepaidOrdersCount;

  const FinancialSummary({
    required this.cashCollectedAllTime,
    required this.cashCollectedToday,
    required this.totalCommissionRetained,
    required this.totalTransportRetained,
    required this.totalTransferFeesRetained,
    required this.totalEarningRetained,
    required this.totalVerifiedRemitted,
    required this.totalPendingApprovalRemitted,
    required this.pendingRemittanceToDC,
    required this.myDirectTransfersBalance,
    required this.totalMonthEarnings,
    required this.totalDeliveredOrdersCount,
    required this.todayDeliveredOrdersCount,
    required this.deliveredCashOrdersCount,
    required this.deliveredPrepaidOrdersCount,
  });

  double get totalRemittedAllTime => totalVerifiedRemitted + totalPendingApprovalRemitted;

  static bool _isSameDay(DateTime a, DateTime b) {
    final localA = a.toLocal();
    final localB = b.toLocal();
    return localA.year == localB.year &&
        localA.month == localB.month &&
        localA.day == localB.day;
  }

  factory FinancialSummary.calculate({
    required List<OrderEntity> orders,
    required List<RemittanceEntity> remittances,
    UserEntity? user,
    double manualEarnedBalance = 0.0,
    List<TransactionItem>? transactions,
    double posFee = 0.0,
  }) {
    final bool isSalaried = user?.compensationType == 'salary' || user?.personnelType == 'in_house_rider';
    final isInHouse = user?.isInHouseRider == true || user?.isPda == false;
    final commissionPerOrder = (user?.commissionRate != null && user!.commissionRate > 0)
        ? user.commissionRate
        : (isInHouse ? 700.0 : 1000.0);
    final transportPerOrder = isInHouse
        ? ((user?.fuelAllowance != null && user!.fuelAllowance > 0) ? user.fuelAllowance : 800.0)
        : ((user?.transportAllowance != null && user!.transportAllowance > 0) ? user.transportAllowance : 1500.0);
    final failedPerOrder = (user?.failedDeliveryAllowance != null && user!.failedDeliveryAllowance > 0)
        ? user.failedDeliveryAllowance
        : (isInHouse ? 300.0 : 500.0);
    final totalEarningPerOrder = commissionPerOrder + transportPerOrder;

    final now = DateTime.now();
    final deliveredOrders = orders.where((o) => o.isDelivered).toList();
    final failedOrders = orders.where((o) => o.isFailed).toList();
    final todayDeliveredOrders = deliveredOrders.where((o) => _isSameDay(o.createdAt, now)).toList();

    final deliveredCashOrders = deliveredOrders.where((o) => o.isCashPod).toList();
    final todayDeliveredCashOrders = todayDeliveredOrders.where((o) => o.isCashPod).toList();
    final deliveredPrepaidOrders = deliveredOrders.where((o) => o.isDirectTransfer || !o.isCashPod).toList();

    final double cashCollectedAllTime = deliveredCashOrders.fold(0.0, (acc, o) => acc + o.totalAmount);
    final double cashCollectedToday = todayDeliveredCashOrders.fold(0.0, (acc, o) => acc + o.totalAmount);

    final double totalCommissionRetained = deliveredCashOrders.length * commissionPerOrder;
    final double totalTransportRetained = deliveredCashOrders.length * transportPerOrder;
    final double totalTransferFeesRetained = posFee;
    final double totalFailedAllowanceEarned = failedOrders.length * failedPerOrder;
    final double totalEarningRetained = totalCommissionRetained + totalTransportRetained + totalFailedAllowanceEarned + totalTransferFeesRetained;

    final double totalVerifiedRemitted = remittances
        .where((r) => r.isVerified)
        .fold(0.0, (acc, r) => acc + r.amount);

    final double totalPendingApprovalRemitted = remittances
        .where((r) => r.isPending && !r.isVerified)
        .fold(0.0, (acc, r) => acc + r.amount);

    // Unremitted delivered cash orders (orders not yet remitted)
    final unremittedDeliveredCashOrders = deliveredCashOrders
        .where((o) => !o.isRemitted && o.paymentStatus.toLowerCase() != 'remitted')
        .toList();

    double pendingRemittanceToDC = 0.0;
    if (unremittedDeliveredCashOrders.isNotEmpty) {
      final double unremittedCash = unremittedDeliveredCashOrders.fold(0.0, (acc, o) => acc + o.totalAmount);
      final double unremittedCommission = unremittedDeliveredCashOrders.fold(
        0.0,
        (acc, o) => acc + (o.agentEntitlement > 0 ? o.agentEntitlement : commissionPerOrder),
      );
      final double unremittedTransport = unremittedDeliveredCashOrders.fold(
        0.0,
        (acc, o) => acc + (o.transportFee > 0 ? o.transportFee : transportPerOrder),
      );
      final double unremittedTotalEarnings = unremittedCommission + unremittedTransport;

      pendingRemittanceToDC = isSalaried
          ? unremittedCash
          : (unremittedCash - unremittedTotalEarnings).clamp(0.0, double.infinity);
    } else {
      pendingRemittanceToDC = 0.0;
    }

    final double directTransfersEarnings = deliveredPrepaidOrders.fold<double>(
      0.0,
      (acc, o) => acc + (o.agentEntitlement > 0 ? o.agentEntitlement : totalEarningPerOrder),
    );

    final double payoutsDeducted = (transactions ?? const [])
        .where((t) =>
            (t.category.toLowerCase() == 'payout' || t.title.toLowerCase().contains('payout')) &&
            t.status.toLowerCase() != 'rejected' &&
            t.status.toLowerCase() != 'cancelled')
        .fold(0.0, (acc, t) => acc + t.amount);

    final double dynamicDirectTransfersBalance = (directTransfersEarnings + totalFailedAllowanceEarned - payoutsDeducted).clamp(0.0, double.infinity);

    final double myDirectTransfersBalance = isSalaried
        ? 0.0
        : (dynamicDirectTransfersBalance > 0
            ? dynamicDirectTransfersBalance
            : (manualEarnedBalance > 0 ? manualEarnedBalance : 0.0));

    final double totalDeliveredEarnings = deliveredOrders.fold<double>(
      0.0,
      (acc, o) => acc + (o.agentEntitlement > 0 ? o.agentEntitlement : totalEarningPerOrder),
    );

    final double totalMonthEarnings = isSalaried
        ? (user?.baseSalary ?? 120000.0)
        : (totalDeliveredEarnings + totalFailedAllowanceEarned);

    return FinancialSummary(
      cashCollectedAllTime: cashCollectedAllTime,
      cashCollectedToday: cashCollectedToday,
      totalCommissionRetained: totalCommissionRetained,
      totalTransportRetained: totalTransportRetained,
      totalTransferFeesRetained: totalTransferFeesRetained,
      totalEarningRetained: totalEarningRetained,
      totalVerifiedRemitted: totalVerifiedRemitted,
      totalPendingApprovalRemitted: totalPendingApprovalRemitted,
      pendingRemittanceToDC: pendingRemittanceToDC,
      myDirectTransfersBalance: myDirectTransfersBalance,
      totalMonthEarnings: totalMonthEarnings,
      totalDeliveredOrdersCount: deliveredOrders.length,
      todayDeliveredOrdersCount: todayDeliveredOrders.length,
      deliveredCashOrdersCount: unremittedDeliveredCashOrders.length,
      deliveredPrepaidOrdersCount: deliveredPrepaidOrders.length,
    );
  }
}
