import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

class UserAvatarWidget extends StatelessWidget {
  final String? avatarUrl;
  final String fullName;
  final double radius;
  final Color? backgroundColor;
  final Color? textColor;
  final bool showBorder;
  final Color? borderColor;
  final double borderWidth;

  const UserAvatarWidget({
    super.key,
    this.avatarUrl,
    required this.fullName,
    this.radius = 40,
    this.backgroundColor,
    this.textColor,
    this.showBorder = false,
    this.borderColor,
    this.borderWidth = 2.0,
  });

  String get _initials {
    if (fullName.trim().isEmpty) return 'U';
    final parts = fullName.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2 && parts[0].isNotEmpty && parts[1].isNotEmpty) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return parts[0][0].toUpperCase();
  }

  Uint8List? _tryDecodeBase64(String uri) {
    try {
      if (uri.startsWith('data:image')) {
        final commaIdx = uri.indexOf(',');
        if (commaIdx != -1) {
          final b64Str = uri.substring(commaIdx + 1);
          return base64Decode(b64Str);
        }
      }
    } catch (_) {}
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final bg = backgroundColor ?? AppColors.primary;
    final fg = textColor ?? (bg.computeLuminance() > 0.5 ? const Color(0xFF031632) : Colors.white);

    Widget avatarContent;

    if (avatarUrl != null && avatarUrl!.trim().isNotEmpty) {
      final cleanUrl = avatarUrl!.trim();
      final bytes = _tryDecodeBase64(cleanUrl);

      if (bytes != null) {
        avatarContent = ClipOval(
          child: Image.memory(
            bytes,
            width: radius * 2,
            height: radius * 2,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _buildInitials(bg, fg),
          ),
        );
      } else if (cleanUrl.startsWith('http://') || cleanUrl.startsWith('https://')) {
        avatarContent = ClipOval(
          child: Image.network(
            cleanUrl,
            width: radius * 2,
            height: radius * 2,
            fit: BoxFit.cover,
            loadingBuilder: (ctx, child, progress) {
              if (progress == null) return child;
              return Container(
                width: radius * 2,
                height: radius * 2,
                color: bg.withValues(alpha: 0.1),
                child: const Center(
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              );
            },
            errorBuilder: (_, __, ___) => _buildInitials(bg, fg),
          ),
        );
      } else {
        avatarContent = _buildInitials(bg, fg);
      }
    } else {
      avatarContent = _buildInitials(bg, fg);
    }

    if (showBorder) {
      return Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: borderColor ?? AppColors.orange,
            width: borderWidth,
          ),
        ),
        child: avatarContent,
      );
    }

    return avatarContent;
  }

  Widget _buildInitials(Color bg, Color fg) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: bg,
      child: Text(
        _initials,
        style: GoogleFonts.inter(
          fontSize: radius * 0.85,
          fontWeight: FontWeight.bold,
          color: fg,
        ),
      ),
    );
  }
}
