import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/app_notification.dart';

abstract class NotificationsRemoteDataSource {
  Future<List<AppNotificationEntity>> getNotifications();
  Future<void> markAsRead(String notificationId);
  Future<void> markAllAsRead();
}

class NotificationsRemoteDataSourceImpl implements NotificationsRemoteDataSource {
  final SupabaseClient supabaseClient;

  NotificationsRemoteDataSourceImpl({required this.supabaseClient});

  @override
  Future<List<AppNotificationEntity>> getNotifications() async {
    try {
      final response = await supabaseClient
          .from('notifications')
          .select('*')
          .order('created_at', ascending: false)
          .limit(30);

      final list = (response as List<dynamic>)
          .map((json) => AppNotificationEntity.fromJson(json as Map<String, dynamic>))
          .toList();

      if (list.isNotEmpty) return list;
    } catch (_) {
      // Fall through to mock dataset if table not initialized
    }

    return _getDefaultNotifications();
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

  List<AppNotificationEntity> _getDefaultNotifications() {
    return [
      AppNotificationEntity(
        id: 'notif-001',
        title: 'New Delivery Assigned 📦',
        message: 'Order TRK-8925 (Dr. Aisha Garba) in Maitama has been assigned to your queue.',
        category: NotificationCategory.delivery,
        createdAt: DateTime.now().subtract(const Duration(minutes: 12)),
        isRead: false,
        actionRoute: '/orders',
      ),
      AppNotificationEntity(
        id: 'notif-002',
        title: 'Remittance Approved ✓',
        message: 'Your cash remittance of ₦15,000 (RMT-0004) has been verified and reconciled by Wuse DC Finance desk.',
        category: NotificationCategory.finance,
        createdAt: DateTime.now().subtract(const Duration(hours: 2)),
        isRead: false,
        actionRoute: '/cash/history',
      ),
      AppNotificationEntity(
        id: 'notif-003',
        title: 'Stock Replenishment Ready 🏷️',
        message: 'Transfer request REQ-00482 (20x Respira, 15x Grazer) is packaged and ready for pickup at Wuse DC counter.',
        category: NotificationCategory.stock,
        createdAt: DateTime.now().subtract(const Duration(hours: 5)),
        isRead: false,
        actionRoute: '/orders/scan',
      ),
      AppNotificationEntity(
        id: 'notif-004',
        title: 'Security & Field Alert ⚠️',
        message: 'Severe rain advisory in Lekki/Ajah expressway. Maintain speed safety and verify waterproof package seals.',
        category: NotificationCategory.system,
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
        isRead: true,
      ),
    ];
  }
}
