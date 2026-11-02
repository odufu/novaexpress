import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../features/admin_console/domain/entities/admin_models.dart';

class AuditLoggingService {
  static final AuditLoggingService instance = AuditLoggingService._();
  AuditLoggingService._();

  SupabaseClient get _supabase => Supabase.instance.client;

  /// Record an immutable audit log entry to Supabase
  Future<void> logAction({
    String? actorId,
    required String actorName,
    required String actorEmail,
    required String actorRole,
    required String action,
    required String resource,
    required String details,
    String? distributionCenterId,
    String? distributionCenterName,
    String ipAddress = '102.89.44.12',
    Map<String, dynamic>? metadata,
  }) async {
    try {
      await _supabase.from('audit_logs').insert({
        if (actorId != null && actorId.isNotEmpty && actorId.contains('-') && actorId.length >= 32)
          'actor_id': actorId,
        'actor_name': actorName,
        'actor_email': actorEmail,
        'actor_role': actorRole,
        'action': action,
        'resource': resource,
        'details': details,
        if (distributionCenterId != null && distributionCenterId.isNotEmpty && distributionCenterId.contains('-') && distributionCenterId.length >= 32)
          'distribution_center_id': distributionCenterId,
        if (distributionCenterName != null && distributionCenterName.isNotEmpty)
          'distribution_center_name': distributionCenterName,
        'ip_address': ipAddress,
        'metadata': metadata ?? {},
        'created_at': DateTime.now().toIso8601String(),
      });
      debugPrint('[AUDIT_LOG] 🛡️ Recorded audit event: $action on $resource by $actorName ($actorRole)');
    } catch (e) {
      debugPrint('[AUDIT_LOG] ⚠️ Notice recording audit log to Supabase: $e');
    }
  }

  /// Fetch all system audit logs for Super Admin
  Future<List<AdminAuditLog>> fetchAllAuditLogs({int limit = 300}) async {
    try {
      final response = await _supabase
          .from('audit_logs')
          .select('*')
          .order('created_at', ascending: false)
          .limit(limit);

      if (response.isNotEmpty) {
        return (response as List)
            .map((row) => AdminAuditLog.fromJson(row as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      debugPrint('[AUDIT_LOG] ⚠️ fetchAllAuditLogs Supabase notice: $e');
    }
    return [];
  }
}

