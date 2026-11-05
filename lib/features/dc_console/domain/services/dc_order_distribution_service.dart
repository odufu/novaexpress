import '../../../orders/domain/entities/order.dart';
import '../entities/dc_operations_officer.dart';

/// Service responsible for evenly distributing incoming orders at a Distribution Center
/// to the available, on-duty Dispatch Operations officers.
///
/// Business Rule:
/// 1. Any order that comes to a DC must be evenly distributed among available Dispatch Ops.
/// 2. Until the Dispatch Ops calls the customer and explicitly assigns the order to a rider,
///    NO rider will receive or see the order.
/// 3. If a DC Admin turns off a Dispatch Ops' availability, that Dispatch Ops is strictly excluded.
class DCOrderDistributionService {
  /// Finds the next available Dispatch Operations officer for [dcId] using
  /// lowest active workload balancing (even distribution).
  static DCOperationsOfficer? findNextAvailableDispatchOps({
    required String dcId,
    required List<DCOperationsOfficer> officers,
    required List<OrderEntity> orders,
  }) {
    final cleanDcId = dcId.trim();

    // 1. Filter available officers for this DC
    final available = officers.where((o) {
      final officerDc = o.distributionCenterId.trim();
      final matchesDc = officerDc == cleanDcId ||
          (cleanDcId == '22222222-2222-4222-8222-222222222222' && (officerDc.isEmpty || officerDc == '22222222-2222-4222-8222-222222222222'));
      final isOps = o.role == 'dc_operations' || o.role == 'dispatcher' || o.role == 'operations';
      return matchesDc && isOps && o.isActive && o.isAvailable;
    }).toList();

    if (available.isEmpty) return null;

    // 2. Count active uncompleted orders assigned to each available officer
    final Map<String, int> activeCountByOfficerId = {
      for (final off in available) off.id: 0,
    };

    for (final order in orders) {
      if (order.isDelivered || order.isCancelled) continue;
      final assignedId = order.logisticsRepId ?? order.assignedDispatcherId;
      if (assignedId != null && activeCountByOfficerId.containsKey(assignedId)) {
        activeCountByOfficerId[assignedId] = (activeCountByOfficerId[assignedId] ?? 0) + 1;
      }
    }

    // 3. Sort available officers by lowest active workload
    available.sort((a, b) {
      final countA = activeCountByOfficerId[a.id] ?? 0;
      final countB = activeCountByOfficerId[b.id] ?? 0;
      if (countA != countB) return countA.compareTo(countB);
      return a.createdAt.compareTo(b.createdAt);
    });

    return available.first;
  }
}

