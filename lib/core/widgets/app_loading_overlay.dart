import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// A universal loading overlay widget that wraps any widget tree.
/// When [isLoading] is true, it displays a blurred backdrop with an elegant
/// NovaExpress branded loading card and status message.
class AppLoadingOverlay extends StatelessWidget {
  final bool isLoading;
  final String message;
  final String? subMessage;
  final Widget child;
  final bool isDark;

  const AppLoadingOverlay({
    super.key,
    required this.isLoading,
    this.message = 'Processing request...',
    this.subMessage,
    required this.child,
    this.isDark = false,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (isLoading)
          Positioned.fill(
            child: AbsorbPointer(
              absorbing: true,
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
                child: Container(
                  color: (isDark ? Colors.black : const Color(0xFF0F172A)).withValues(alpha: 0.55),
                  alignment: Alignment.center,
                  child: AppLoadingCard(
                    message: message,
                    subMessage: subMessage,
                    isDark: isDark,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// The core branded loading card component.
class AppLoadingCard extends StatelessWidget {
  final String message;
  final String? subMessage;
  final bool isDark;

  const AppLoadingCard({
    super.key,
    required this.message,
    this.subMessage,
    this.isDark = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 28),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
      constraints: const BoxConstraints(maxWidth: 360),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.15),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 54,
                height: 54,
                child: CircularProgressIndicator(
                  strokeWidth: 3.5,
                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFF37021)),
                  backgroundColor: const Color(0xFFF37021).withValues(alpha: 0.15),
                ),
              ),
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFF031632),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.warehouse_rounded,
                  color: Color(0xFFF37021),
                  size: 20,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            message,
            style: GoogleFonts.inter(
              fontSize: 14.5,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
            textAlign: TextAlign.center,
          ),
          if (subMessage != null && subMessage!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              subMessage!,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: const Color(0xFF64748B),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}

/// Helper function to execute an async operation while showing a universal loading overlay modal.
/// Prevents all touch inputs, shows active status, and automatically closes upon completion.
Future<T?> showAppLoadingDialog<T>({
  required BuildContext context,
  required String message,
  String? subMessage,
  required Future<T> Function() task,
  bool isDark = false,
}) async {
  // Show dialog
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: (isDark ? Colors.black : const Color(0xFF0F172A)).withValues(alpha: 0.6),
    builder: (ctx) => PopScope(
      canPop: false,
      child: Center(
        child: AppLoadingCard(
          message: message,
          subMessage: subMessage ?? 'Please hold on while the server updates...',
          isDark: isDark,
        ),
      ),
    ),
  );

  try {
    final result = await task();
    if (context.mounted) {
      Navigator.of(context, rootNavigator: true).pop();
    }
    return result;
  } catch (e) {
    if (context.mounted) {
      Navigator.of(context, rootNavigator: true).pop();
    }
    rethrow;
  }
}
