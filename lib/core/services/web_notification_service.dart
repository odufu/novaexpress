import 'web_notification_service_stub.dart'
    if (dart.library.js_interop) 'web_notification_service_web.dart';

abstract class WebNotificationService {
  static WebNotificationService? _instance;
  static WebNotificationService get instance =>
      _instance ??= createWebNotificationService();

  Future<bool> requestPermission();

  void showNotification({
    required String title,
    required String body,
    String? tag,
  });
}

