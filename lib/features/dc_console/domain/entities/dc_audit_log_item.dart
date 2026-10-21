import 'package:flutter/material.dart';

enum DCAuditActionType {
  remittanceApproved,
  remittanceSubmitted,
  remittanceRejected,
  deliverySuccess,
  deliveryFailed,
  stockTransfer,
  orderDispatched,
  orderRerouted,
  system,
}

class DCAuditLogItem {
  final String id;
  final String dcId;
  final String dcName;
  final String title;
  final String message;
  final DCAuditActionType actionType;
  final String actorName;
  final String actorRole;
  final String? actorId;
  final String? actorEmail;
  final String? referenceId;
  final String? actionRoute;
  final DateTime createdAt;
  final bool isRead;
  final Map<String, dynamic>? metadata;

  const DCAuditLogItem({
    required this.id,
    required this.dcId,
    this.dcName = '',
    required this.title,
    required this.message,
    required this.actionType,
    required this.actorName,
    required this.actorRole,
    this.actorId,
    this.actorEmail,
    this.referenceId,
    this.actionRoute,
    required this.createdAt,
    this.isRead = false,
    this.metadata,
  });

  IconData get icon {
    switch (actionType) {
      case DCAuditActionType.remittanceApproved:
        return Icons.verified_user_rounded;
      case DCAuditActionType.remittanceSubmitted:
        return Icons.hourglass_top_rounded;
      case DCAuditActionType.remittanceRejected:
        return Icons.highlight_off_rounded;
      case DCAuditActionType.deliverySuccess:
        return Icons.check_circle_rounded;
      case DCAuditActionType.deliveryFailed:
        return Icons.error_outline_rounded;
      case DCAuditActionType.stockTransfer:
        return Icons.inventory_2_rounded;
      case DCAuditActionType.orderDispatched:
        return Icons.local_shipping_rounded;
      case DCAuditActionType.orderRerouted:
        return Icons.swap_horiz_rounded;
      case DCAuditActionType.system:
        return Icons.notifications_active_rounded;
    }
  }

  Color get color {
    switch (actionType) {
      case DCAuditActionType.remittanceApproved:
        return const Color(0xFF10B981);
      case DCAuditActionType.remittanceSubmitted:
        return const Color(0xFFF59E0B);
      case DCAuditActionType.remittanceRejected:
        return const Color(0xFFEF4444);
      case DCAuditActionType.deliverySuccess:
        return const Color(0xFF0D9488);
      case DCAuditActionType.deliveryFailed:
        return const Color(0xFFDC2626);
      case DCAuditActionType.stockTransfer:
        return const Color(0xFF6366F1);
      case DCAuditActionType.orderDispatched:
        return const Color(0xFF2563EB);
      case DCAuditActionType.orderRerouted:
        return const Color(0xFFF97316);
      case DCAuditActionType.system:
        return const Color(0xFF64748B);
    }
  }

  String get actionTypeLabel {
    switch (actionType) {
      case DCAuditActionType.remittanceApproved:
        return 'Remittance Approved';
      case DCAuditActionType.remittanceSubmitted:
        return 'Remittance Submitted';
      case DCAuditActionType.remittanceRejected:
        return 'Remittance Rejected';
      case DCAuditActionType.deliverySuccess:
        return 'Delivery Success';
      case DCAuditActionType.deliveryFailed:
        return 'Delivery Failure';
      case DCAuditActionType.stockTransfer:
        return 'Stock Action';
      case DCAuditActionType.orderDispatched:
        return 'Order Dispatched';
      case DCAuditActionType.orderRerouted:
        return 'Order Rerouted';
      case DCAuditActionType.system:
        return 'System Alert';
    }
  }

  factory DCAuditLogItem.fromJson(Map<String, dynamic> json) {
    final cat = (json['category']?.toString() ?? 'system').toLowerCase();
    DCAuditActionType type = DCAuditActionType.system;
    if (cat.contains('approved') || cat == 'remittance_approved') {
      type = DCAuditActionType.remittanceApproved;
    } else if (cat.contains('submitted') || cat == 'remittance_submitted') {
      type = DCAuditActionType.remittanceSubmitted;
    } else if (cat.contains('rejected') || cat == 'remittance_rejected') {
      type = DCAuditActionType.remittanceRejected;
    } else if (cat.contains('success') || cat == 'delivery_success' || (cat == 'delivery' && !cat.contains('fail'))) {
      type = DCAuditActionType.deliverySuccess;
    } else if (cat.contains('fail') || cat == 'delivery_failed') {
      type = DCAuditActionType.deliveryFailed;
    } else if (cat.contains('stock')) {
      type = DCAuditActionType.stockTransfer;
    } else if (cat.contains('dispatch') || cat == 'order_dispatch') {
      type = DCAuditActionType.orderDispatched;
    } else if (cat.contains('reroute')) {
      type = DCAuditActionType.orderRerouted;
    }

    String rawMessage = json['message']?.toString() ?? '';
    String actorName = 'DC Operations';
    String actorRole = 'System';

    if (rawMessage.startsWith('[Actor:')) {
      final endIdx = rawMessage.indexOf(']');
      if (endIdx != -1) {
        final actorBlock = rawMessage.substring(7, endIdx);
        rawMessage = rawMessage.substring(endIdx + 1).trim();
        final parts = actorBlock.split('|');
        actorName = parts[0].trim();
        if (parts.length > 1) {
          final rolePart = parts[1].replaceFirst('Role:', '').trim();
          if (rolePart.isNotEmpty) actorRole = rolePart;
        }
      }
    }

    return DCAuditLogItem(
      id: json['id']?.toString() ?? '',
      dcId: json['distribution_center_id']?.toString() ?? '',
      dcName: json['dc_name']?.toString() ?? '',
      title: json['title']?.toString() ?? 'DC Event',
      message: rawMessage,
      actionType: type,
      actorName: actorName,
      actorRole: actorRole,
      actorId: json['user_id']?.toString() ?? json['delivery_agent_id']?.toString(),
      actionRoute: json['action_route']?.toString(),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      isRead: json['is_read'] == true,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }
}
