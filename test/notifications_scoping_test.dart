import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:novexps/core/services/local_storage_service.dart';
import 'package:novexps/features/notifications/domain/entities/app_notification.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Rider Real-Time Notifications & Scoping Verification Suite', () {
    late LocalStorageService storageService;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      storageService = LocalStorageServiceImpl();
    });

    test('1. Newly Registered Rider: Has isolated notifications containing welcome guide', () async {
      const newAgentId = 'agt-new-rider-999';

      // 1. Initial cached state for new rider is null
      final initial = await storageService.getCachedNotifications(newAgentId);
      expect(initial, isNull);

      // 2. Simulate newly registered rider welcome notification
      final welcomeNotif = AppNotificationEntity(
        id: 'notif-welcome-$newAgentId',
        title: 'Welcome to NovaExpress Delivery! 🛵',
        message: 'Your rider account is active. Explore your daily manifest, track your commission & allowances, and verify custody stock before departing the DC.',
        category: NotificationCategory.system,
        createdAt: DateTime.now(),
        isRead: false,
        actionRoute: '/profile',
      );

      await storageService.cacheNotifications(newAgentId, [welcomeNotif]);

      // 3. Verify that new rider only sees their welcome guide
      final cached = await storageService.getCachedNotifications(newAgentId);
      expect(cached, isNotNull);
      expect(cached!.length, equals(1));
      expect(cached.first.title, contains('Welcome to NovaExpress'));
      expect(cached.first.category, equals(NotificationCategory.system));
      expect(cached.first.isRead, isFalse);
    });

    test('2. Multi-Agent Scoping: Ensures separate notification channels per delivery agent', () async {
      const riderA = 'agt-rider-aaa';
      const riderB = 'agt-rider-bbb';

      final notifA = AppNotificationEntity(
        id: 'notif-pod-001',
        title: 'Delivery POD Confirmed 🎉',
        message: 'Order NX-1001 was successfully delivered. Net collection of ₦30,000 recorded.',
        category: NotificationCategory.delivery,
        createdAt: DateTime.now(),
        isRead: false,
        actionRoute: '/orders',
      );

      final notifB = AppNotificationEntity(
        id: 'notif-rmt-002',
        title: 'Remittance Logged 💸',
        message: 'Your cash remittance of ₦50,000 was logged and sent for DC verification.',
        category: NotificationCategory.finance,
        createdAt: DateTime.now(),
        isRead: false,
        actionRoute: '/cash/history',
      );

      await storageService.cacheNotifications(riderA, [notifA]);
      await storageService.cacheNotifications(riderB, [notifB]);

      final cachedA = await storageService.getCachedNotifications(riderA);
      final cachedB = await storageService.getCachedNotifications(riderB);

      expect(cachedA!.length, equals(1));
      expect(cachedA.first.title, equals('Delivery POD Confirmed 🎉'));

      expect(cachedB!.length, equals(1));
      expect(cachedB.first.title, equals('Remittance Logged 💸'));
    });
  });
}
