import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/services/local_storage_service.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
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
  final LocalStorageService _storageService;
  final Ref _ref;

  NotificationsNotifier({
    required NotificationsRepository repository,
    required Ref ref,
    LocalStorageService? storageService,
  })  : _repository = repository,
        _ref = ref,
        _storageService = storageService ?? LocalStorageServiceImpl(),
        super(const NotificationsState()) {
    final agentId = _getAgentId();
    if (agentId.isNotEmpty) {
      _initCache(agentId);
      fetchNotifications(agentId);
    }
  }

  Future<void> _initCache(String agentId) async {
    final cached = await _storageService.getCachedNotifications(agentId);
    if (cached != null && cached.isNotEmpty) {
      state = state.copyWith(notifications: cached);
    }
  }

  String _getAgentId() {
    final user = _ref.read(authProvider).user;
    return user?.deliveryAgentId ?? user?.id ?? '';
  }

  Future<void> fetchNotifications([String? agentId]) async {
    final targetId = (agentId != null && agentId.isNotEmpty) ? agentId : _getAgentId();
    if (targetId.isEmpty) {
      state = state.copyWith(notifications: [], isLoading: false);
      return;
    }

    state = state.copyWith(isLoading: state.notifications.isEmpty, errorMessage: null);
    try {
      final list = await _repository.getNotifications(targetId);
      state = state.copyWith(notifications: list, isLoading: false);
      _storageService.cacheNotifications(targetId, list);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<void> emitNotification({
    required String title,
    required String message,
    required String category,
    String? actionRoute,
  }) async {
    final agentId = _getAgentId();
    if (agentId.isEmpty) return;

    await _repository.emitNotification(
      title: title,
      message: message,
      category: category,
      agentId: agentId,
      actionRoute: actionRoute,
    );
    await fetchNotifications(agentId);
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
    final agentId = _getAgentId();
    if (agentId.isNotEmpty) {
      _storageService.cacheNotifications(agentId, updated);
    }
    await _repository.markAsRead(id);
  }

  Future<void> markAllAsRead() async {
    final updated = state.notifications.map((n) => n.copyWith(isRead: true)).toList();
    state = state.copyWith(notifications: updated);
    final agentId = _getAgentId();
    if (agentId.isNotEmpty) {
      _storageService.cacheNotifications(agentId, updated);
    }
    await _repository.markAllAsRead();
  }
}

final notificationsProvider = StateNotifierProvider<NotificationsNotifier, NotificationsState>((ref) {
  final repository = ref.watch(notificationsRepositoryProvider);
  final storage = ref.watch(localStorageServiceProvider);
  // Re-instantiate when active user changes
  ref.watch(authProvider.select((s) => s.user?.deliveryAgentId ?? s.user?.id));
  return NotificationsNotifier(repository: repository, ref: ref, storageService: storage);
});
