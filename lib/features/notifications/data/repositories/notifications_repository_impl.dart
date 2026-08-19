import '../../domain/entities/app_notification.dart';
import '../../domain/repositories/notifications_repository.dart';
import '../datasources/notifications_remote_datasource.dart';

class NotificationsRepositoryImpl implements NotificationsRepository {
  final NotificationsRemoteDataSource remoteDataSource;

  NotificationsRepositoryImpl({required this.remoteDataSource});

  @override
  Future<List<AppNotificationEntity>> getNotifications([String? agentId]) {
    return remoteDataSource.getNotifications(agentId);
  }

  @override
  Future<void> emitNotification({
    required String title,
    required String message,
    required String category,
    String? agentId,
    String? actionRoute,
  }) {
    return remoteDataSource.createNotification(
      title: title,
      message: message,
      category: category,
      agentId: agentId,
      actionRoute: actionRoute,
    );
  }

  @override
  Future<void> markAsRead(String notificationId) {
    return remoteDataSource.markAsRead(notificationId);
  }

  @override
  Future<void> markAllAsRead() {
    return remoteDataSource.markAllAsRead();
  }
}
