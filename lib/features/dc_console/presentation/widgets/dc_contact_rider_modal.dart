import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/helpers/formatters.dart';
import '../../../notifications/presentation/providers/notifications_provider.dart';
import '../../../orders/domain/entities/order.dart';

class DCContactRiderModal extends ConsumerStatefulWidget {
  final OrderEntity order;
  final String riderName;
  final String riderCode;
  final String riderPhone;
  final String? riderId;
  final double amountAwaitingRemittance;

  const DCContactRiderModal({
    super.key,
    required this.order,
    required this.riderName,
    required this.riderCode,
    required this.riderPhone,
    this.riderId,
    required this.amountAwaitingRemittance,
  });

  static Future<void> show({
    required BuildContext context,
    required OrderEntity order,
    required String riderName,
    required String riderCode,
    required String riderPhone,
    String? riderId,
    required double amountAwaitingRemittance,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => DCContactRiderModal(
        order: order,
        riderName: riderName,
        riderCode: riderCode,
        riderPhone: riderPhone,
        riderId: riderId,
        amountAwaitingRemittance: amountAwaitingRemittance,
      ),
    );
  }

  @override
  ConsumerState<DCContactRiderModal> createState() => _DCContactRiderModalState();
}

class _DCContactRiderModalState extends ConsumerState<DCContactRiderModal> {
  bool _isSendingInAppAlert = false;
  bool _inAppAlertSent = false;
  final TextEditingController _customNoteController = TextEditingController();

  @override
  void dispose() {
    _customNoteController.dispose();
    super.dispose();
  }

  String get _formattedPhone {
    String clean = widget.riderPhone.replaceAll(RegExp(r'[^\d+]'), '');
    if (clean.startsWith('+234')) {
      return clean.substring(1);
    } else if (clean.startsWith('234')) {
      return clean;
    } else if (clean.startsWith('0')) {
      return '234${clean.substring(1)}';
    }
    return clean.replaceAll('+', '');
  }

  void _callRider() async {
    final cleanPhone = widget.riderPhone.replaceAll(RegExp(r'[^\d+]'), '');
    final uri = Uri.parse('tel:$cleanPhone');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      if (mounted) {
        Clipboard.setData(ClipboardData(text: widget.riderPhone));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Phone ${widget.riderPhone} copied to clipboard!'),
            backgroundColor: const Color(0xFF0F172A),
          ),
        );
      }
    }
  }

  void _sendWhatsAppReminder() async {
    final customNote = _customNoteController.text.trim();
    final message = '''Hello ${widget.riderName.trim()} (${widget.riderCode.trim()}),

This is DC Supervisor Adekunle from NovaExpress Logistics Command regarding Order #${widget.order.orderNumber}.

• Customer: ${widget.order.customerName}
• Delivery Address: ${widget.order.deliveryAddress}
• Total Amount Collected: ${CurrencyFormatter.formatNaira(widget.order.totalAmount)}
• Net Expected Remittance: ${CurrencyFormatter.formatNaira(widget.amountAwaitingRemittance)}

${customNote.isNotEmpty ? "Note: $customNote\n" : ""}Kindly remit the cash custody of ${CurrencyFormatter.formatNaira(widget.amountAwaitingRemittance)} via the Paystack Instant Remittance tab in your PDA app or at the DC. Thank you! 🙏''';

    final encodedMsg = Uri.encodeComponent(message);
    final phone = _formattedPhone;
    final uri = Uri.parse('https://wa.me/$phone?text=$encodedMsg');

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(uri);
      }
    } catch (_) {
      if (mounted) {
        Clipboard.setData(ClipboardData(text: message));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('WhatsApp message template copied to clipboard!'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
      }
    }
  }

  void _sendInAppPushAlert() async {
    setState(() => _isSendingInAppAlert = true);

    const title = 'Cash Remittance Notice ⚠️';
    final customNote = _customNoteController.text.trim();
    final message = customNote.isNotEmpty
        ? 'DC Notice for #${widget.order.orderNumber}: $customNote (Pending Remittance: ${CurrencyFormatter.formatNaira(widget.amountAwaitingRemittance)})'
        : 'Please remit cash custody of ${CurrencyFormatter.formatNaira(widget.amountAwaitingRemittance)} for order #${widget.order.orderNumber} via Paystack or at DC.';

    ref.read(notificationsProvider.notifier).emitNotification(
          title: title,
          message: message,
          category: 'finance',
          actionRoute: '/cash',
        );

    await Future.delayed(const Duration(milliseconds: 600));

    if (mounted) {
      setState(() {
        _isSendingInAppAlert = false;
        _inAppAlertSent = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF16A34A),
          content: Text('✓ In-App Alert dispatched to ${widget.riderName}\'s PDA device!'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with Title and Close Button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF37021).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.support_agent_rounded, color: Color(0xFFF37021), size: 24),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Contact Delivery Agent',
                            style: GoogleFonts.inter(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                          Text(
                            'Remittance & Route Communication',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: isDark ? Colors.white70 : const Color(0xFF64748B)),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Rider Profile Hero Box
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: const Color(0xFF00A2D3),
                      child: Text(
                        widget.riderName.isNotEmpty ? widget.riderName.substring(0, 1).toUpperCase() : 'R',
                        style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                widget.riderName,
                                style: GoogleFonts.inter(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF00A2D3).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  widget.riderCode,
                                  style: GoogleFonts.jetBrainsMono(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF00A2D3),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            widget.riderPhone,
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 12.5,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Order & Remittance Context Box
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.3)),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Target Shipment', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF78350F))),
                        Text('#${widget.order.orderNumber}', style: GoogleFonts.jetBrainsMono(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFFB45309))),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Customer & Location', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF78350F))),
                        Text('${widget.order.customerName} (${widget.order.deliveryCity})', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF78350F))),
                      ],
                    ),
                    const Divider(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Amount Awaiting Remittance', style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.bold, color: const Color(0xFFB45309))),
                        Text(
                          CurrencyFormatter.formatNaira(widget.amountAwaitingRemittance),
                          style: GoogleFonts.jetBrainsMono(fontSize: 16, fontWeight: FontWeight.w900, color: const Color(0xFFB45309)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Custom Note Input
              Text(
                'Optional Supervisor Note / Message',
                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569)),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _customNoteController,
                maxLines: 2,
                style: GoogleFonts.inter(fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'e.g. Please reconcile before 5:00 PM cutoff today.',
                  hintStyle: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8)),
                  filled: true,
                  fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
              const SizedBox(height: 18),

              // Primary Contact Actions
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _callRider,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.phone_rounded, size: 18),
                      label: Text('Direct Call', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _sendWhatsAppReminder,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF16A34A),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
                      label: Text('WhatsApp Reminder', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Action 3: Send In-App Remittance Push Alert
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _isSendingInAppAlert ? null : _sendInAppPushAlert,
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: _inAppAlertSent ? const Color(0xFF16A34A) : const Color(0xFFF37021)),
                    foregroundColor: _inAppAlertSent ? const Color(0xFF16A34A) : const Color(0xFFF37021),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: _isSendingInAppAlert
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : Icon(_inAppAlertSent ? Icons.check_circle_rounded : Icons.notifications_active_rounded, size: 18),
                  label: Text(
                    _inAppAlertSent ? 'In-App Notice Dispatched ✓' : 'Send Instant In-App Remittance Alert',
                    style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Future In-App Communications Channel Feature Hook Banner
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF031632) : const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.forum_rounded, color: Color(0xFF00A2D3), size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'IN-APP COMMUNICATIONS CHANNEL',
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 9.5,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF00A2D3),
                              letterSpacing: 0.8,
                            ),
                          ),
                          Text(
                            'Direct bidirectional dispatcher-rider in-app messaging channel will be enabled here.',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
