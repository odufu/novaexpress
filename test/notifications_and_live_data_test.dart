import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novexps/features/notifications/domain/entities/app_notification.dart';
import 'package:novexps/features/notifications/domain/repositories/notifications_repository.dart';
import 'package:novexps/features/notifications/presentation/pages/notifications_page.dart';
import 'package:novexps/features/notifications/presentation/providers/notifications_provider.dart';

class MockNotificationsRepository implements NotificationsRepository {
  List<AppNotificationEntity> list = [
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

  @override
  Future<List<AppNotificationEntity>> getNotifications() async => list;

  @override
  Future<void> markAsRead(String notificationId) async {
    list = list.map((n) => n.id == notificationId ? n.copyWith(isRead: true) : n).toList();
  }

  @override
  Future<void> markAllAsRead() async {
    list = list.map((n) => n.copyWith(isRead: true)).toList();
  }
}

void main() {
  group('AppNotificationEntity & State Tests', () {
    test('Notification Category Parsing', () {
      final json1 = {
        'id': '1',
        'title': 'Delivery Alert',
        'message': 'Order ready',
        'category': 'delivery',
        'is_read': false,
      };
      final notif1 = AppNotificationEntity.fromJson(json1);
      expect(notif1.category, NotificationCategory.delivery);
      expect(notif1.isRead, false);

      final json2 = {
        'id': '2',
        'title': 'Remittance Alert',
        'message': 'Cash confirmed',
        'category': 'finance',
        'is_read': true,
      };
      final notif2 = AppNotificationEntity.fromJson(json2);
      expect(notif2.category, NotificationCategory.finance);
      expect(notif2.isRead, true);
    });

    test('NotificationsState Filter and Unread Count', () {
      final notifs = [
        AppNotificationEntity(
          id: '1',
          title: 'Order 1',
          message: 'msg',
          category: NotificationCategory.delivery,
          createdAt: DateTime.now(),
          isRead: false,
        ),
        AppNotificationEntity(
          id: '2',
          title: 'Remit 1',
          message: 'msg',
          category: NotificationCategory.finance,
          createdAt: DateTime.now(),
          isRead: true,
        ),
        AppNotificationEntity(
          id: '3',
          title: 'Stock 1',
          message: 'msg',
          category: NotificationCategory.stock,
          createdAt: DateTime.now(),
          isRead: false,
        ),
      ];

      final state = NotificationsState(notifications: notifs, activeFilter: 'all');
      expect(state.unreadCount, 2);
      expect(state.filteredNotifications.length, 3);

      final deliveryState = state.copyWith(activeFilter: 'delivery');
      expect(deliveryState.filteredNotifications.length, 1);
      expect(deliveryState.filteredNotifications.first.title, 'Order 1');

      final financeState = state.copyWith(activeFilter: 'finance');
      expect(financeState.filteredNotifications.length, 1);
      expect(financeState.filteredNotifications.first.title, 'Remit 1');
    });
  });

  group('NotificationsPage Widget Tests', () {
    testWidgets('Renders NotificationsPage with filter chips and notification cards', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            notificationsRepositoryProvider.overrideWithValue(MockNotificationsRepository()),
          ],
          child: const MaterialApp(
            home: NotificationsPage(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Notifications'), findsOneWidget);
      expect(find.textContaining('All'), findsOneWidget);
      expect(find.text('Deliveries'), findsOneWidget);
      expect(find.text('Finance & Remittance'), findsOneWidget);
      expect(find.text('Stock & Handover'), findsOneWidget);
      expect(find.text('System Alerts'), findsOneWidget);

      // Verify notification cards appear
      expect(find.textContaining('New Delivery Assigned'), findsOneWidget);
      expect(find.textContaining('Remittance Approved'), findsOneWidget);
    });
  });
}
