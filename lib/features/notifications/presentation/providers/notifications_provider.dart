import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/datasources/notifications_remote_datasource.dart';
import '../../data/repositories/notifications_repository_impl.dart';
import '../../domain/entities/app_notification.dart';
import '../../domain/repositories/notifications_repository.dart';

final notificationsRemoteDataSourceProvider = Provider<NotificationsRemoteDataSource>((ref) {
  return NotificationsRemoteDataSourceImpl(
    supabaseClient: Supabase.instance.client,
  );
});

final notificationsRepositoryProvider = Provider<NotificationsRepository>((ref) {
  final remoteDataSource = ref.watch(notificationsRemoteDataSourceProvider);
  return NotificationsRepositoryImpl(remoteDataSource: remoteDataSource);
});

class NotificationsState {
  final List<AppNotificationEntity> notifications;
  final bool isLoading;
  final String? errorMessage;
  final String activeFilter; // 'all', 'delivery', 'finance', 'stock', 'system'

  const NotificationsState({
    this.notifications = const [],
    this.isLoading = false,
    this.errorMessage,
    this.activeFilter = 'all',
  });

  int get unreadCount => notifications.where((n) => !n.isRead).length;

  List<AppNotificationEntity> get filteredNotifications {
    if (activeFilter == 'all') return notifications;
    if (activeFilter == 'delivery') {
      return notifications.where((n) => n.category == NotificationCategory.delivery).toList();
    }
    if (activeFilter == 'finance') {
      return notifications.where((n) => n.category == NotificationCategory.finance).toList();
    }
    if (activeFilter == 'stock') {
      return notifications.where((n) => n.category == NotificationCategory.stock).toList();
    }
    if (activeFilter == 'system') {
      return notifications.where((n) => n.category == NotificationCategory.system).toList();
    }
    return notifications;
  }

  NotificationsState copyWith({
    List<AppNotificationEntity>? notifications,
    bool? isLoading,
    String? errorMessage,
    String? activeFilter,
  }) {
    return NotificationsState(
      notifications: notifications ?? this.notifications,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage ?? this.errorMessage,
      activeFilter: activeFilter ?? this.activeFilter,
    );
  }
}

class NotificationsNotifier extends StateNotifier<NotificationsState> {
  final NotificationsRepository _repository;

  NotificationsNotifier({required NotificationsRepository repository})
      : _repository = repository,
        super(const NotificationsState()) {
    fetchNotifications();
  }

  Future<void> fetchNotifications() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final list = await _repository.getNotifications();
      state = state.copyWith(notifications: list, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  void setFilter(String filter) {
    state = state.copyWith(activeFilter: filter);
  }

  Future<void> markAsRead(String id) async {
    final updated = state.notifications.map((n) {
      if (n.id == id) return n.copyWith(isRead: true);
      return n;
    }).toList();
    state = state.copyWith(notifications: updated);
    await _repository.markAsRead(id);
  }

  Future<void> markAllAsRead() async {
    final updated = state.notifications.map((n) => n.copyWith(isRead: true)).toList();
    state = state.copyWith(notifications: updated);
    await _repository.markAllAsRead();
  }
}

final notificationsProvider = StateNotifierProvider<NotificationsNotifier, NotificationsState>((ref) {
  final repository = ref.watch(notificationsRepositoryProvider);
  return NotificationsNotifier(repository: repository);
});
