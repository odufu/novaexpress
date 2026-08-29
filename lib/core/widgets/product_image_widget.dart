import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';

class ProductImageWidget extends StatelessWidget {
  final String? imageUrl;
  final double width;
  final double height;
  final double borderRadius;
  final BoxFit fit;
  final Color? backgroundColor;
  final Color? borderColor;
  final double borderWidth;
  final IconData fallbackIcon;

  const ProductImageWidget({
    super.key,
    required this.imageUrl,
    this.width = 48,
    this.height = 48,
    this.borderRadius = 8,
    this.fit = BoxFit.contain,
    this.backgroundColor,
    this.borderColor,
    this.borderWidth = 1.0,
    this.fallbackIcon = Icons.inventory_2_outlined,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = backgroundColor ?? (isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9));
    final border = borderColor ?? (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0));

    final url = imageUrl?.trim();

    Widget imageContent;

    if (url == null || url.isEmpty) {
      imageContent = _buildFallback(isDark);
    } else if (url.startsWith('data:image')) {
      try {
        final commaIdx = url.indexOf(',');
        final base64Str = commaIdx != -1 ? url.substring(commaIdx + 1) : url;
        final Uint8List bytes = base64Decode(base64Str);
        imageContent = Image.memory(
          bytes,
          fit: fit,
          errorBuilder: (_, __, ___) => _buildFallback(isDark),
        );
      } catch (_) {
        imageContent = _buildFallback(isDark);
      }
    } else if (url.startsWith('http://') || url.startsWith('https://')) {
      imageContent = Image.network(
        url,
        fit: fit,
        loadingBuilder: (ctx, child, progress) {
          if (progress == null) return child;
          return Center(
            child: SizedBox(
              width: width * 0.4,
              height: height * 0.4,
              child: const CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        },
        errorBuilder: (_, __, ___) => _buildFallback(isDark),
      );
    } else {
      // Local asset path
      imageContent = Image.asset(
        url,
        fit: fit,
        errorBuilder: (_, __, ___) => _buildFallback(isDark),
      );
    }

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: border, width: borderWidth),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius > 1 ? borderRadius - 1 : borderRadius),
        child: imageContent,
      ),
    );
  }

  Widget _buildFallback(bool isDark) {
    return Center(
      child: Icon(
        fallbackIcon,
        size: (width < height ? width : height) * 0.5,
        color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
      ),
    );
  }
}
