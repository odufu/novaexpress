import '../../../auth/domain/entities/user.dart';
import '../../../orders/domain/entities/order.dart';
import 'remittance.dart';

class FinancialSummary {
  final double cashCollectedAllTime;
  final double cashCollectedToday;
  final double totalCommissionRetained;
  final double totalTransportRetained;
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
  }) {
    final bool isSalaried = user?.compensationType == 'salary' || user?.personnelType == 'inhouse';

    final commissionPerOrder = user?.commissionRate ?? 1000.0;
    final transportPerOrder = user?.isPda == false
        ? (user?.fuelAllowance ?? 1500.0)
        : (user?.transportAllowance ?? 1500.0);
    final totalEarningPerOrder = commissionPerOrder + transportPerOrder;

    final now = DateTime.now();
    final deliveredOrders = orders.where((o) => o.status == 'delivered').toList();
    final todayDeliveredOrders = deliveredOrders.where((o) => _isSameDay(o.createdAt, now)).toList();

    final deliveredCashOrders = deliveredOrders.where((o) => o.paymentType != 'prepaid' && o.isPod).toList();
    final todayDeliveredCashOrders = todayDeliveredOrders.where((o) => o.paymentType != 'prepaid' && o.isPod).toList();

    final deliveredPrepaidOrders = deliveredOrders.where((o) => o.paymentType == 'prepaid' || !o.isPod).toList();

    final double cashCollectedAllTime = deliveredCashOrders.fold(0.0, (acc, o) => acc + o.totalAmount);
    final double cashCollectedToday = todayDeliveredCashOrders.isNotEmpty
        ? todayDeliveredCashOrders.fold(0.0, (acc, o) => acc + o.totalAmount)
        : (todayDeliveredOrders.isNotEmpty
            ? todayDeliveredOrders.fold(0.0, (acc, o) => acc + o.totalAmount)
            : (deliveredCashOrders.isNotEmpty ? deliveredCashOrders.take(3).fold(0.0, (acc, o) => acc + o.totalAmount) : 0.0));

    final double totalCommissionRetained = deliveredCashOrders.length * commissionPerOrder;
    final double totalTransportRetained = deliveredCashOrders.length * transportPerOrder;
    final double totalEarningRetained = totalCommissionRetained + totalTransportRetained;

    final double totalVerifiedRemitted = remittances
        .where((r) => r.isVerified || r.status.toLowerCase() == 'approved')
        .fold(0.0, (acc, r) => acc + r.amount);

    final double totalPendingApprovalRemitted = remittances
        .where((r) => r.isPending || r.status.toLowerCase() == 'submitted')
        .fold(0.0, (acc, r) => acc + r.amount);

    final double pendingRemittanceToDC = (cashCollectedAllTime -
            totalEarningRetained -
            totalVerifiedRemitted -
            totalPendingApprovalRemitted)
        .clamp(0.0, double.infinity);

    final double myDirectTransfersBalance = isSalaried
        ? (user?.baseSalary ?? 150000.0)
        : (manualEarnedBalance > 0
            ? manualEarnedBalance
            : (deliveredPrepaidOrders.length * totalEarningPerOrder));

    final double totalMonthEarnings = isSalaried
        ? (user?.baseSalary ?? 150000.0)
        : (deliveredOrders.length * totalEarningPerOrder);

    return FinancialSummary(
      cashCollectedAllTime: cashCollectedAllTime,
      cashCollectedToday: cashCollectedToday,
      totalCommissionRetained: totalCommissionRetained,
      totalTransportRetained: totalTransportRetained,
      totalEarningRetained: totalEarningRetained,
      totalVerifiedRemitted: totalVerifiedRemitted,
      totalPendingApprovalRemitted: totalPendingApprovalRemitted,
      pendingRemittanceToDC: pendingRemittanceToDC,
      myDirectTransfersBalance: myDirectTransfersBalance,
      totalMonthEarnings: totalMonthEarnings,
      totalDeliveredOrdersCount: deliveredOrders.length,
      todayDeliveredOrdersCount: todayDeliveredOrders.length,
      deliveredCashOrdersCount: deliveredCashOrders.length,
      deliveredPrepaidOrdersCount: deliveredPrepaidOrders.length,
    );
  }
}
