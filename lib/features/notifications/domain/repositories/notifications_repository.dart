import '../entities/app_notification.dart';

abstract class NotificationsRepository {
  Future<List<AppNotificationEntity>> getNotifications();
  Future<void> markAsRead(String notificationId);
  Future<void> markAllAsRead();
}
