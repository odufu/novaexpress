import 'dart:js_interop' as js;
import 'web_notification_service.dart';

WebNotificationService createWebNotificationService() =>
    WebNotificationServiceWeb();

@js.JS('__showWebNotification')
external void _showWebNotification(
    js.JSString title, js.JSString body, js.JSString tag);

@js.JS('__requestWebNotificationPermission')
external js.JSPromise<js.JSString> _requestWebNotificationPermission();

class WebNotificationServiceWeb implements WebNotificationService {
  @override
  Future<bool> requestPermission() async {
    try {
      final res = await _requestWebNotificationPermission().toDart;
      return res.toDart == 'granted';
    } catch (_) {
      return false;
    }
  }

  @override
  void showNotification({
    required String title,
    required String body,
    String? tag,
  }) {
    try {
      _showWebNotification(
        title.toJS,
        body.toJS,
        (tag ?? 'novaxpress-reminder').toJS,
      );
    } catch (_) {}
  }
}

