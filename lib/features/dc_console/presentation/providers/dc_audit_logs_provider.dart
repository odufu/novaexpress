import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/helpers/formatters.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../finance/presentation/providers/finance_provider.dart';
import '../../../orders/presentation/providers/orders_provider.dart';
import '../../domain/entities/dc_audit_log_item.dart';
import 'dc_console_provider.dart';

class DCAuditLogsState {
  final List<DCAuditLogItem> logs;
  final bool isLoading;
  final String searchQuery;
  final String activeFilter; // 'all', 'remittance', 'delivery', 'failure', 'stock', 'dispatch'
  final String? errorMessage;

  const DCAuditLogsState({
    this.logs = const [],
    this.isLoading = false,
    this.searchQuery = '',
    this.activeFilter = 'all',
    this.errorMessage,
  });

  DCAuditLogsState copyWith({
    List<DCAuditLogItem>? logs,
    bool? isLoading,
    String? searchQuery,
    String? activeFilter,
    String? errorMessage,
  }) {
    return DCAuditLogsState(
      logs: logs ?? this.logs,
      isLoading: isLoading ?? this.isLoading,
      searchQuery: searchQuery ?? this.searchQuery,
      activeFilter: activeFilter ?? this.activeFilter,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  int get totalCount => logs.length;
  int get remittancesCount => logs.where((l) =>
      l.actionType == DCAuditActionType.remittanceApproved ||
      l.actionType == DCAuditActionType.remittanceSubmitted ||
      l.actionType == DCAuditActionType.remittanceRejected).length;
  int get deliveriesCount => logs.where((l) => l.actionType == DCAuditActionType.deliverySuccess).length;
  int get failuresCount => logs.where((l) => l.actionType == DCAuditActionType.deliveryFailed).length;
  int get stockCount => logs.where((l) => l.actionType == DCAuditActionType.stockTransfer).length;
  int get dispatchCount => logs.where((l) =>
      l.actionType == DCAuditActionType.orderDispatched ||
      l.actionType == DCAuditActionType.orderRerouted).length;

  List<DCAuditLogItem> get filteredLogs {
    var result = logs;

    // Filter by action type
    if (activeFilter == 'remittance') {
      result = result.where((l) =>
          l.actionType == DCAuditActionType.remittanceApproved ||
          l.actionType == DCAuditActionType.remittanceSubmitted ||
          l.actionType == DCAuditActionType.remittanceRejected).toList();
    } else if (activeFilter == 'delivery') {
      result = result.where((l) => l.actionType == DCAuditActionType.deliverySuccess).toList();
    } else if (activeFilter == 'failure') {
      result = result.where((l) => l.actionType == DCAuditActionType.deliveryFailed).toList();
    } else if (activeFilter == 'stock') {
      result = result.where((l) => l.actionType == DCAuditActionType.stockTransfer).toList();
    } else if (activeFilter == 'dispatch') {
      result = result.where((l) =>
          l.actionType == DCAuditActionType.orderDispatched ||
          l.actionType == DCAuditActionType.orderRerouted).toList();
    }

    // Search by Account (Who performed the action) or reference
    final q = searchQuery.trim().toLowerCase();
    if (q.isNotEmpty) {
      result = result.where((l) {
        final actorMatch = l.actorName.toLowerCase().contains(q);
        final roleMatch = l.actorRole.toLowerCase().contains(q);
        final refMatch = (l.referenceId ?? '').toLowerCase().contains(q);
        final titleMatch = l.title.toLowerCase().contains(q);
        final msgMatch = l.message.toLowerCase().contains(q);
        return actorMatch || roleMatch || refMatch || titleMatch || msgMatch;
      }).toList();
    }

    return result;
  }
}

class DCAuditLogsNotifier extends StateNotifier<DCAuditLogsState> {
  final Ref _ref;

  DCAuditLogsNotifier(this._ref) : super(const DCAuditLogsState());

  SupabaseClient get _db => Supabase.instance.client;

  Future<void> loadLogs({String? dcId}) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    final resolvedDcId = (dcId != null && dcId.isNotEmpty)
        ? dcId
        : (_ref.read(dcConsoleProvider).activeHubId.isNotEmpty
            ? _ref.read(dcConsoleProvider).activeHubId
            : (_ref.read(authProvider).user?.distributionCenterId ?? ''));

    try {
      final List<DCAuditLogItem> aggregatedLogs = [];
      final Set<String> seenIds = {};

      // 1. Fetch live DB logs from Supabase 'notifications' table scoped to DC
      try {
        var query = _db.from('notifications').select('*');
        if (resolvedDcId.isNotEmpty) {
          query = query.or('distribution_center_id.eq.$resolvedDcId,category.ilike.%remittance%,category.ilike.%delivery%');
        }
        final dbRes = await query.order('created_at', ascending: false).limit(100);

        for (final row in (dbRes as List)) {
          final item = DCAuditLogItem.fromJson(row as Map<String, dynamic>);
          if (!seenIds.contains(item.id)) {
            seenIds.add(item.id);
            aggregatedLogs.add(item);
          }
        }
      } catch (dbErr) {
        debugPrint('[DC_AUDIT_LOGS] notice reading notifications: $dbErr');
      }

      // 2. Synthesize live orders events in this DC
      try {
        final orders = _ref.read(ordersProvider).orders;
        for (final o in orders) {
          if (resolvedDcId.isNotEmpty && o.distributionCenterId != null && o.distributionCenterId != resolvedDcId) {
            continue;
          }

          // A. Delivered Orders
          if (o.isDelivered) {
            final logId = 'order-del-${o.id}';
            if (!seenIds.contains(logId)) {
              seenIds.add(logId);
              aggregatedLogs.add(DCAuditLogItem(
                id: logId,
                dcId: o.distributionCenterId ?? resolvedDcId,
                title: 'Order Delivered Successfully',
                message: 'Order #${o.orderNumber} delivered to ${o.customerName} (${CurrencyFormatter.formatNaira(o.totalAmount)}).',
                actionType: DCAuditActionType.deliverySuccess,
                actorName: o.deliveryAgentName ?? (o.deliveryAgentCode != null ? 'Rider ${o.deliveryAgentCode}' : 'Fleet Rider'),
                actorRole: 'Rider',
                actorId: o.deliveryAgentId,
                referenceId: o.orderNumber,
                actionRoute: '/orders',
                createdAt: o.deliveredAt ?? o.updatedAt ?? o.createdAt,
              ));
            }
          }

          // B. Failed Orders
          if (o.isFailed) {
            final logId = 'order-fail-${o.id}';
            if (!seenIds.contains(logId)) {
              seenIds.add(logId);
              final reason = o.failureReason ?? 'Customer unavailable or rescheduled';
              aggregatedLogs.add(DCAuditLogItem(
                id: logId,
                dcId: o.distributionCenterId ?? resolvedDcId,
                title: 'Delivery Attempt Failed',
                message: 'Delivery attempt failed for #${o.orderNumber} (${o.customerName}). Reason: $reason.',
                actionType: DCAuditActionType.deliveryFailed,
                actorName: o.deliveryAgentName ?? (o.deliveryAgentCode != null ? 'Rider ${o.deliveryAgentCode}' : 'Fleet Rider'),
                actorRole: 'Rider',
                actorId: o.deliveryAgentId,
                referenceId: o.orderNumber,
                actionRoute: '/orders',
                createdAt: o.updatedAt ?? o.createdAt,
              ));
            }
          }
        }
      } catch (_) {}

      // 3. Synthesize events from Remittances in this DC
      try {
        final remittances = _ref.read(financeProvider).remittances;
        for (final r in remittances) {
          final isApproved = r.isVerified || r.status.toLowerCase() == 'approved';
          final logId = 'rem-${r.id}-${isApproved ? "app" : "sub"}';
          if (!seenIds.contains(logId)) {
            seenIds.add(logId);
            aggregatedLogs.add(DCAuditLogItem(
              id: logId,
              dcId: resolvedDcId,
              title: isApproved ? 'Remittance Approved & Cleared' : 'Remittance Clearance Requested',
              message: isApproved
                  ? 'Remittance ${r.referenceNumber} (${CurrencyFormatter.formatNaira(r.amount)}) verified into DC Treasury.'
                  : 'Rider ${r.payerName ?? "Rider"} requested clearance for ${CurrencyFormatter.formatNaira(r.amount)} (${r.referenceNumber}).',
              actionType: isApproved ? DCAuditActionType.remittanceApproved : DCAuditActionType.remittanceSubmitted,
              actorName: isApproved
                  ? (r.verifiedByName ?? 'Financial Ops')
                  : (r.payerName ?? 'Fleet Rider'),
              actorRole: isApproved ? 'Finance Ops' : 'Rider',
              actorId: isApproved ? r.verifiedByUserId : r.deliveryAgentId,
              referenceId: r.referenceNumber,
              actionRoute: '/finance-ops',
              createdAt: isApproved ? (r.verifiedAt ?? r.createdAt) : r.createdAt,
            ));
          }
        }
      } catch (_) {}

      // Sort chronological descending
      aggregatedLogs.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      state = state.copyWith(logs: aggregatedLogs, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<void> emitDcAuditLog({
    required String dcId,
    required String title,
    required String message,
    required DCAuditActionType actionType,
    required String actorName,
    required String actorRole,
    String? actorId,
    String? referenceId,
    String? actionRoute,
  }) async {
    try {
      final formattedMessage = '[Actor: $actorName | Role: $actorRole] $message';
      final row = {
        'company_id': '11111111-1111-4111-8111-111111111111',
        'distribution_center_id': dcId,
        'title': title,
        'message': formattedMessage,
        'category': actionType.name,
        'action_route': actionRoute,
        'is_read': false,
        'created_at': DateTime.now().toIso8601String(),
        if (actorId != null && actorId.isNotEmpty) 'user_id': actorId,
      };

      await _db.from('notifications').insert(row);
      debugPrint('[DC_AUDIT_LOGS] Emitted audit log: $title by $actorName ($actorRole)');
      await loadLogs(dcId: dcId);
    } catch (e) {
      debugPrint('[DC_AUDIT_LOGS] notice while inserting audit log: $e');
    }
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  void setFilter(String filter) {
    state = state.copyWith(activeFilter: filter);
  }
}

final dcAuditLogsProvider = StateNotifierProvider<DCAuditLogsNotifier, DCAuditLogsState>((ref) {
  return DCAuditLogsNotifier(ref);
});
