import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// A robust image widget designed to render client/merchant corporate logos and closer brand badges.
///
/// Features:
/// - Supports standard HTTPS public image URLs (e.g. Supabase Storage CDN).
/// - Automatically resolves Google Image search links (e.g. extracts direct `imgurl`).
/// - Supports base64 data URIs (`data:image/...;base64,...`).
/// - Gracefully falls back to stylized brand initials or an icon if the URL fails or is empty.
class ClientLogoWidget extends StatelessWidget {
  final String? logoUrl;
  final String companyName;
  final double size;
  final double borderRadius;
  final Color? borderColor;
  final double borderWidth;
  final Color? brandColor;
  final Color? backgroundColor;
  final bool isCloser;
  final BoxFit fit;

  const ClientLogoWidget({
    super.key,
    required this.logoUrl,
    required this.companyName,
    this.size = 36.0,
    this.borderRadius = 10.0,
    this.borderColor,
    this.borderWidth = 1.5,
    this.brandColor,
    this.backgroundColor,
    this.isCloser = false,
    this.fit = BoxFit.contain,
  });

  /// Extracts the direct image URL if a Google Images wrapper was stored.
  static String? normalizeLogoUrl(String? raw) {
    if (raw == null) return null;
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;

    if (trimmed.contains('google.com/imgres') && trimmed.contains('imgurl=')) {
      try {
        final uri = Uri.parse(trimmed);
        final direct = uri.queryParameters['imgurl'];
        if (direct != null && direct.isNotEmpty) {
          return direct;
        }
      } catch (_) {}
    }
    return trimmed;
  }

  static Uint8List? _tryDecodeBase64(String uri) {
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

  String get _initials {
    final clean = companyName.trim();
    if (clean.isEmpty) return 'EC';
    final parts = clean.split(RegExp(r'\s+'));
    if (parts.length >= 2 && parts[0].isNotEmpty && parts[1].isNotEmpty) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return clean.substring(0, clean.length >= 2 ? 2 : 1).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final effectiveBrand = brandColor ?? const Color(0xFF0D9488);
    final effectiveBorder = borderColor ?? effectiveBrand;
    final effectiveBg = backgroundColor ?? Colors.white;
    final cleanUrl = normalizeLogoUrl(logoUrl);

    Widget innerContent;

    if (cleanUrl != null && cleanUrl.isNotEmpty) {
      final base64Bytes = _tryDecodeBase64(cleanUrl);
      if (base64Bytes != null) {
        innerContent = Image.memory(
          base64Bytes,
          width: size,
          height: size,
          fit: fit,
          errorBuilder: (_, __, ___) => _buildFallback(effectiveBrand),
        );
      } else if (cleanUrl.startsWith('http://') || cleanUrl.startsWith('https://')) {
        innerContent = Image.network(
          cleanUrl,
          width: size,
          height: size,
          fit: fit,
          errorBuilder: (_, __, ___) => _buildFallback(effectiveBrand),
        );
      } else {
        innerContent = _buildFallback(effectiveBrand);
      }
    } else {
      innerContent = _buildFallback(effectiveBrand);
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: effectiveBg,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: effectiveBorder, width: borderWidth),
      ),
      clipBehavior: Clip.antiAlias,
      child: Center(child: innerContent),
    );
  }

  Widget _buildFallback(Color brand) {
    return Container(
      width: size,
      height: size,
      color: brand,
      child: Center(
        child: size < 28
            ? Icon(
                isCloser ? Icons.headset_mic_rounded : Icons.storefront_rounded,
                color: Colors.white,
                size: size * 0.6,
              )
            : Text(
                _initials,
                style: GoogleFonts.inter(
                  fontSize: size * 0.38,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
              ),
      ),
    );
  }
}
