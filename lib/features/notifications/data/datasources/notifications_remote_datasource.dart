import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/app_notification.dart';

abstract class NotificationsRemoteDataSource {
  Future<List<AppNotificationEntity>> getNotifications([String? agentId]);
  Future<void> markAsRead(String notificationId);
  Future<void> markAllAsRead();
  Future<void> createNotification({
    required String title,
    required String message,
    required String category,
    String? agentId,
    String? actionRoute,
  });
}

class NotificationsRemoteDataSourceImpl implements NotificationsRemoteDataSource {
  final SupabaseClient supabaseClient;

  NotificationsRemoteDataSourceImpl({required this.supabaseClient});

  @override
  Future<List<AppNotificationEntity>> getNotifications([String? agentId]) async {
    try {
      final effectiveAgentId = agentId ?? 'b1111111-1111-4111-8111-111111111111';
      debugPrint('[NOTIF_DATASOURCE] 📥 Fetching notifications for agent_id: "$effectiveAgentId"...');

      final response = await supabaseClient
          .from('notifications')
          .select('*')
          .or('delivery_agent_id.eq.$effectiveAgentId,delivery_agent_id.is.null')
          .order('created_at', ascending: false)
          .limit(40);

      final list = (response as List<dynamic>)
          .map((json) => AppNotificationEntity.fromJson(json as Map<String, dynamic>))
          .toList();

      debugPrint('[NOTIF_DATASOURCE] ✅ Fetched ${list.length} live notifications from Supabase');
      return list;
    } catch (e) {
      debugPrint('[NOTIF_DATASOURCE] ⚠️ Error fetching notifications ($e)');
      return [];
    }
  }

  @override
  Future<void> createNotification({
    required String title,
    required String message,
    required String category,
    String? agentId,
    String? actionRoute,
  }) async {
    try {
      final targetAgent = agentId ?? 'b1111111-1111-4111-8111-111111111111';
      debugPrint('[NOTIF_DATASOURCE] 📤 Emitting notification to Supabase for agent: "$targetAgent"...');

      await supabaseClient.from('notifications').insert({
        'company_id': '11111111-1111-4111-8111-111111111111',
        'delivery_agent_id': targetAgent,
        'title': title,
        'message': message,
        'category': category,
        'action_route': actionRoute,
        'is_read': false,
        'created_at': DateTime.now().toIso8601String(),
      });
      debugPrint('[NOTIF_DATASOURCE] ✅ Notification emitted successfully.');
    } catch (e) {
      debugPrint('[NOTIF_DATASOURCE] ⚠️ Failed to emit notification ($e).');
    }
  }

  @override
  Future<void> markAsRead(String notificationId) async {
    try {
      await supabaseClient
          .from('notifications')
          .update({'is_read': true})
          .eq('id', notificationId);
    } catch (_) {}
  }

  @override
  Future<void> markAllAsRead() async {
    try {
      await supabaseClient
          .from('notifications')
          .update({'is_read': true})
          .eq('is_read', false);
    } catch (_) {}
  }
}
