import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';

/// Production-hardened map and communication launcher for Rider PDAs.
/// Resolves Android intent conflicts (e.g. 3rd party apps intercepting web intents)
/// with a 4-tier fallback system and automatic clipboard backup.
class MapLauncherHelper {
  /// Launches turn-by-turn navigation to destination coordinates or address.
  static Future<void> launchTurnByTurnNavigation({
    required BuildContext context,
    double? latitude,
    double? longitude,
    required String destinationAddress,
    String? customerName,
  }) async {
    final hasCoords = latitude != null && longitude != null;
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    // 1. Prepare candidate URIs
    final String label = customerName != null && customerName.isNotEmpty
        ? customerName
        : 'NovaExpress Customer';
    final String encodedLabel = Uri.encodeComponent(label);

    // Strategy 1: Android native geo URI (Only routes to Map apps, never to OPay / shopping apps)
    final Uri geoUri = hasCoords
        ? Uri.parse('geo:$latitude,$longitude?q=$latitude,$longitude($encodedLabel)')
        : Uri.parse('geo:0,0?q=${Uri.encodeComponent(destinationAddress)}');

    // Strategy 2: Google Maps navigation intent (Direct turn-by-turn driving mode)
    final Uri googleNavUri = hasCoords
        ? Uri.parse('google.navigation:q=$latitude,$longitude&mode=d')
        : Uri.parse('google.navigation:q=${Uri.encodeComponent(destinationAddress)}&mode=d');

    // Strategy 3: Universal Web directions URL
    final Uri webDirectionsUri = hasCoords
        ? Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$latitude,$longitude&travelmode=driving')
        : Uri.parse('https://www.google.com/maps/dir/?api=1&destination=${Uri.encodeComponent(destinationAddress)}');

    // -------------------------------------------------------------
    // TIER 1: Try Native Geo Intent (Bypasses third-party webview interceptors)
    // -------------------------------------------------------------
    if (!kIsWeb && Platform.isAndroid) {
      try {
        final launched = await launchUrl(geoUri, mode: LaunchMode.externalNonBrowserApplication);
        if (launched) return;
      } catch (_) {
        // Fall through to next tier
      }

      // -------------------------------------------------------------
      // TIER 2: Try Direct Google Navigation Scheme
      // -------------------------------------------------------------
      try {
        final launched = await launchUrl(googleNavUri, mode: LaunchMode.externalApplication);
        if (launched) return;
      } catch (_) {
        // Fall through to next tier
      }
    }

    // -------------------------------------------------------------
    // TIER 3: Try External Web Maps (Google Maps Web)
    // -------------------------------------------------------------
    try {
      final launched = await launchUrl(webDirectionsUri, mode: LaunchMode.externalApplication);
      if (launched) return;
    } catch (_) {
      // In case an unexported 3rd party app (e.g. OPay) throws a SecurityException
      // Try inAppBrowserView as isolated fallback
      try {
        final launchedInApp = await launchUrl(webDirectionsUri, mode: LaunchMode.inAppBrowserView);
        if (launchedInApp) return;
      } catch (_) {
        // Fall through to clipboard backup
      }
    }

    // -------------------------------------------------------------
    // TIER 4: Graceful Fallback with Clipboard Copy
    // -------------------------------------------------------------
    final copyText = hasCoords ? '$latitude, $longitude' : destinationAddress;
    await Clipboard.setData(ClipboardData(text: copyText));

    scaffoldMessenger.showSnackBar(
      SnackBar(
        backgroundColor: AppColors.primary,
        duration: const Duration(seconds: 4),
        content: Row(
          children: [
            const Icon(Icons.content_copy_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Destination coordinates copied ($copyText). Paste in Maps to navigate.',
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Launches WhatsApp with pre-filled message using robust package/web routing
  static Future<void> launchWhatsApp({
    required BuildContext context,
    required Uri waUri,
    required String customerPhone,
  }) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      final launched = await launchUrl(waUri, mode: LaunchMode.externalApplication);
      if (launched) return;
    } catch (_) {
      try {
        final launchedInApp = await launchUrl(waUri, mode: LaunchMode.platformDefault);
        if (launchedInApp) return;
      } catch (_) {}
    }

    scaffoldMessenger.showSnackBar(
      SnackBar(
        backgroundColor: AppColors.warning,
        content: Text('Could not open WhatsApp for $customerPhone. Make sure WhatsApp is installed.'),
      ),
    );
  }

  /// Launches direct telephone call intent
  static Future<void> launchPhoneCall({
    required BuildContext context,
    required String phoneNumber,
  }) async {
    final cleanPhone = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '').trim();
    if (cleanPhone.isEmpty) return;

    final uri = Uri.parse('tel:$cleanPhone');
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      final launched = await launchUrl(uri);
      if (!launched) {
        await Clipboard.setData(ClipboardData(text: cleanPhone));
        scaffoldMessenger.showSnackBar(
          SnackBar(
            backgroundColor: AppColors.primary,
            content: Text('Phone number $cleanPhone copied to clipboard! 📞'),
          ),
        );
      }
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: cleanPhone));
      scaffoldMessenger.showSnackBar(
        SnackBar(
          backgroundColor: AppColors.primary,
          content: Text('Phone number $cleanPhone copied to clipboard! 📞'),
        ),
      );
    }
  }
}
