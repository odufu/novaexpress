import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/signature_storage_service.dart';
import '../theme/app_theme.dart';

class SignatureResult {
  final Uint8List pngBytes;
  final String signatureUrl;

  const SignatureResult({
    required this.pngBytes,
    required this.signatureUrl,
  });
}

class SignaturePadModal extends StatefulWidget {
  final String orderId;
  final String customerName;

  const SignaturePadModal({
    super.key,
    required this.orderId,
    this.customerName = 'Customer',
  });

  static Future<SignatureResult?> show({
    required BuildContext context,
    required String orderId,
    String customerName = 'Customer',
  }) {
    return showModalBottomSheet<SignatureResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SignaturePadModal(
        orderId: orderId,
        customerName: customerName,
      ),
    );
  }

  @override
  State<SignaturePadModal> createState() => _SignaturePadModalState();
}

class _SignaturePadModalState extends State<SignaturePadModal> {
  final ValueNotifier<List<Offset?>> _pointsNotifier = ValueNotifier<List<Offset?>>([]);
  final ValueNotifier<bool> _hasSignatureNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<bool> _isSavingNotifier = ValueNotifier<bool>(false);
  final GlobalKey _canvasKey = GlobalKey();

  @override
  void dispose() {
    _pointsNotifier.dispose();
    _hasSignatureNotifier.dispose();
    _isSavingNotifier.dispose();
    super.dispose();
  }

  void _clear() {
    _pointsNotifier.value = [];
    _hasSignatureNotifier.value = false;
  }

  Future<void> _saveAndConfirm() async {
    final points = _pointsNotifier.value;
    if (!_hasSignatureNotifier.value || points.isEmpty) return;

    _isSavingNotifier.value = true;
    try {
      final renderBox = _canvasKey.currentContext?.findRenderObject() as RenderBox?;
      final size = renderBox?.size ?? const Size(400, 240);

      final pngBytes = await SignatureStorageService.exportPointsToPngBytes(
        points: points,
        size: size,
        strokeColor: const Color(0xFF0F172A),
        strokeWidth: 3.2,
      );

      if (pngBytes == null) {
        if (mounted) _isSavingNotifier.value = false;
        return;
      }

      final signatureUrl = await SignatureStorageService.uploadSignature(
        pngBytes: pngBytes,
        orderId: widget.orderId,
      );

      if (mounted) {
        Navigator.of(context).pop(
          SignatureResult(
            pngBytes: pngBytes,
            signatureUrl: signatureUrl,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        _isSavingNotifier.value = false;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFFEF4444),
            content: Text('Failed to save signature: $e'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final screenHeight = MediaQuery.of(context).size.height;

    return Container(
      constraints: BoxConstraints(
        maxHeight: screenHeight * 0.85,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Grab Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Header Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.orange.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.draw_rounded, color: AppColors.orange, size: 20),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Customer Signature',
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          Text(
                            'POD Confirmation • #${widget.orderId}',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Drawing Canvas Container (Completely isolated gesture container)
              ValueListenableBuilder<bool>(
                valueListenable: _hasSignatureNotifier,
                builder: (context, hasSig, _) {
                  return Container(
                    key: _canvasKey,
                    height: 240,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: hasSig
                            ? const Color(0xFF10B981)
                            : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                        width: hasSig ? 1.8 : 1.2,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(15),
                      child: Stack(
                        children: [
                          // Baseline guide line
                          Positioned(
                            left: 20,
                            right: 20,
                            bottom: 45,
                            child: Container(
                              height: 1.5,
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.12)
                                  : Colors.black.withValues(alpha: 0.1),
                            ),
                          ),
                          Positioned(
                            left: 24,
                            bottom: 24,
                            child: Row(
                              children: [
                                Icon(Icons.touch_app_outlined, size: 13, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                                const SizedBox(width: 4),
                                Text(
                                  'Sign on the line above with finger or stylus',
                                  style: GoogleFonts.inter(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w500,
                                    color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Dedicated Gesture Drawing Canvas
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onPanStart: (details) {
                              final current = List<Offset?>.from(_pointsNotifier.value);
                              current.add(details.localPosition);
                              _pointsNotifier.value = current;
                              if (!_hasSignatureNotifier.value) {
                                _hasSignatureNotifier.value = true;
                              }
                            },
                            onPanUpdate: (details) {
                              final current = List<Offset?>.from(_pointsNotifier.value);
                              current.add(details.localPosition);
                              _pointsNotifier.value = current;
                            },
                            onPanEnd: (details) {
                              final current = List<Offset?>.from(_pointsNotifier.value);
                              current.add(null);
                              _pointsNotifier.value = current;
                            },
                            child: ValueListenableBuilder<List<Offset?>>(
                              valueListenable: _pointsNotifier,
                              builder: (context, points, _) {
                                return CustomPaint(
                                  painter: _ModalSignaturePainter(
                                    points: points,
                                    strokeColor: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0F172A),
                                  ),
                                  size: Size.infinite,
                                );
                              },
                            ),
                          ),

                          if (!hasSig)
                            Center(
                              child: IgnorePointer(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.gesture_rounded,
                                      size: 32,
                                      color: isDark ? const Color(0xFF475569) : const Color(0xFF94A3B8),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Draw signature here',
                                      style: GoogleFonts.inter(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 14),

              // Action Buttons: Clear vs Confirm & Save
              ValueListenableBuilder<bool>(
                valueListenable: _hasSignatureNotifier,
                builder: (context, hasSig, _) {
                  return ValueListenableBuilder<bool>(
                    valueListenable: _isSavingNotifier,
                    builder: (context, isSaving, _) {
                      return Row(
                        children: [
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              side: BorderSide(color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1)),
                            ),
                            onPressed: hasSig && !isSaving ? _clear : null,
                            icon: const Icon(Icons.refresh_rounded, size: 18, color: Color(0xFFEF4444)),
                            label: Text(
                              'Clear',
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: hasSig ? const Color(0xFFEF4444) : const Color(0xFF94A3B8),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF10B981),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                elevation: 0,
                              ),
                              onPressed: hasSig && !isSaving ? _saveAndConfirm : null,
                              icon: isSaving
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                    )
                                  : const Icon(Icons.check_rounded, size: 20),
                              label: Text(
                                isSaving ? 'Saving Signature...' : 'Confirm Signature',
                                style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModalSignaturePainter extends CustomPainter {
  final List<Offset?> points;
  final Color strokeColor;

  _ModalSignaturePainter({
    required this.points,
    required this.strokeColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = strokeColor
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = 3.2;

    for (int i = 0; i < points.length - 1; i++) {
      if (points[i] != null && points[i + 1] != null) {
        canvas.drawLine(points[i]!, points[i + 1]!, paint);
      } else if (points[i] != null && points[i + 1] == null) {
        canvas.drawPoints(ui.PointMode.points, [points[i]!], paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ModalSignaturePainter oldDelegate) {
    return oldDelegate.points.length != points.length;
  }
}
