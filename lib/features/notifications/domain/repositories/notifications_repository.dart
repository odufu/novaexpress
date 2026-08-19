import '../entities/app_notification.dart';

abstract class NotificationsRepository {
  Future<List<AppNotificationEntity>> getNotifications([String? agentId]);
  Future<void> markAsRead(String notificationId);
  Future<void> markAllAsRead();
  Future<void> emitNotification({
    required String title,
    required String message,
    required String category,
    String? agentId,
    String? actionRoute,
  });
}
