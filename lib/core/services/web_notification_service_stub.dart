import 'web_notification_service.dart';

WebNotificationService createWebNotificationService() =>
    WebNotificationServiceStub();

class WebNotificationServiceStub implements WebNotificationService {
  @override
  Future<bool> requestPermission() async => true;

  @override
  void showNotification({
    required String title,
    required String body,
    String? tag,
  }) {}
}

