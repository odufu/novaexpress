import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/order_conversation.dart';
import '../../domain/entities/order_conversation_message.dart';
import '../../../orders/domain/entities/order.dart';
import '../../../orders/presentation/widgets/order_product_switch_modal.dart';
import '../../../../core/widgets/user_avatar_widget.dart';
import '../providers/pipeline_chat_provider.dart';
import 'conversation_list_modal.dart';
import 'chat_user_profile_card_modal.dart';

class OrderPipelineChatSheet extends ConsumerStatefulWidget {
  final String orderId;
  final String orderNumber;
  final String customerName;
  final String? customerPhone;
  final String? initialMessage;
  final bool showBackButton;
  final VoidCallback? onBack;
  final VoidCallback? onClose;

  const OrderPipelineChatSheet({
    super.key,
    required this.orderId,
    required this.orderNumber,
    required this.customerName,
    this.customerPhone,
    this.initialMessage,
    this.showBackButton = true,
    this.onBack,
    this.onClose,
  });

  static Future<void> showForOrder(
    BuildContext context,
    OrderEntity order, {
    String? initialMessage,
    bool showBackButton = true,
    VoidCallback? onBack,
  }) {
    return ConversationListModal.showForOrder(
      context,
      orderId: order.id,
      orderNumber: order.orderNumber,
      customerName: order.customerName,
      customerPhone: order.customerPhone,
      initialMessage: initialMessage,
    );
  }

  static Future<void> show(
    BuildContext context, {
    required String orderId,
    required String orderNumber,
    required String customerName,
    String? customerPhone,
    String? initialMessage,
    bool showBackButton = true,
    VoidCallback? onBack,
  }) {
    return ConversationListModal.showForOrder(
      context,
      orderId: orderId,
      orderNumber: orderNumber,
      customerName: customerName,
      customerPhone: customerPhone,
      initialMessage: initialMessage,
    );
  }

  @override
  ConsumerState<OrderPipelineChatSheet> createState() => _OrderPipelineChatSheetState();
}

class _OrderPipelineChatSheetState extends ConsumerState<OrderPipelineChatSheet>
    with SingleTickerProviderStateMixin {
  final TextEditingController _msgController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _msgFocusNode = FocusNode();
  late AnimationController _shimmerController;
  late Animation<double> _shimmerAnimation;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _shimmerAnimation = Tween<double>(begin: 0.35, end: 0.85).animate(
      CurvedAnimation(parent: _shimmerController, curve: Curves.easeInOut),
    );

    if (widget.initialMessage != null && widget.initialMessage!.isNotEmpty) {
      _msgController.text = widget.initialMessage!;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(pipelineChatProvider.notifier).openOrderConversation(widget.orderId);
      if (widget.initialMessage != null && widget.initialMessage!.isNotEmpty) {
        _msgFocusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    _msgController.dispose();
    _scrollController.dispose();
    _msgFocusNode.dispose();
    super.dispose();
  }

  void _callNumber(BuildContext context, String phone) async {
    final clean = phone.replaceAll(RegExp(r'[^\d+]'), '');
    final uri = Uri.parse('tel:$clean');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      Clipboard.setData(ClipboardData(text: phone));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Phone copied: $phone'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 80,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _handleSendMessage() async {
    final text = _msgController.text.trim();
    if (text.isEmpty) return;

    _msgController.clear();
    final ok = await ref.read(pipelineChatProvider.notifier).sendTextMessage(text);
    if (ok) {
      Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
    }
  }

  void _appendMentionTag(String tag) {
    final cur = _msgController.text.trim();
    if (cur.isEmpty) {
      _msgController.text = '$tag ';
    } else {
      _msgController.text = '$cur $tag ';
    }
    _msgController.selection = TextSelection.fromPosition(
      TextPosition(offset: _msgController.text.length),
    );
    _msgFocusNode.requestFocus();
  }

  String _formatMessageTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inSeconds < 60) {
      return 'now';
    } else if (diff.inHours < 1) {
      return '${diff.inMinutes}m ago';
    } else if (now.year == dt.year && now.month == dt.month && now.day == dt.day) {
      return DateFormat('h:mm a').format(dt);
    } else if (now.difference(dt).inDays < 7) {
      return DateFormat('EEE, h:mm a').format(dt);
    } else {
      return DateFormat('d MMM, h:mm a').format(dt);
    }
  }

  Widget _buildMessageBodyWithInteractiveMentions(
    String text, {
    required bool isMyMessage,
    required bool isDark,
    required OrderConversationEntity? conv,
  }) {
    final mentionRegex = RegExp(r'@([A-Za-z0-9_.\-]+(?:\s+[A-Za-z0-9_.\-]+)?)');
    final matches = mentionRegex.allMatches(text);

    final defaultStyle = GoogleFonts.inter(
      fontSize: 13.5,
      height: 1.4,
      color: isMyMessage
          ? Colors.white
          : (isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A)),
      fontWeight: isMyMessage ? FontWeight.w500 : FontWeight.w400,
    );

    if (matches.isEmpty) {
      return Text(text, style: defaultStyle);
    }

    final spans = <InlineSpan>[];
    int lastEnd = 0;

    for (final match in matches) {
      if (match.start > lastEnd) {
        spans.add(TextSpan(
          text: text.substring(lastEnd, match.start),
          style: defaultStyle,
        ));
      }

      final tag = match.group(0)!;

      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: InkWell(
              onTap: () {
                ChatUserProfileCardModal.show(
                  context: context,
                  ref: ref,
                  tag: tag,
                  conversation: conv,
                  onMention: _appendMentionTag,
                );
              },
              borderRadius: BorderRadius.circular(6),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isMyMessage
                      ? Colors.white.withValues(alpha: 0.24)
                      : (isDark
                          ? const Color(0xFF38BDF8).withValues(alpha: 0.2)
                          : const Color(0xFF0284C7).withValues(alpha: 0.12)),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isMyMessage
                        ? Colors.white.withValues(alpha: 0.45)
                        : (isDark
                            ? const Color(0xFF38BDF8).withValues(alpha: 0.45)
                            : const Color(0xFF0284C7).withValues(alpha: 0.3)),
                    width: 0.8,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.alternate_email_rounded,
                      size: 11,
                      color: isMyMessage
                          ? Colors.white
                          : (isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7)),
                    ),
                    const SizedBox(width: 2),
                    Text(
                      tag.substring(1),
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isMyMessage
                            ? Colors.white
                            : (isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7)),
                        decoration: TextDecoration.underline,
                        decorationStyle: TextDecorationStyle.solid,
                        decorationThickness: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      lastEnd = match.end;
    }

    if (lastEnd < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastEnd),
        style: defaultStyle,
      ));
    }

    return Text.rich(TextSpan(children: spans));
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(pipelineChatProvider);
    final themeMode = ref.watch(themeProvider);
    final isDark = themeMode == ThemeMode.dark ||
        (themeMode == ThemeMode.system &&
            MediaQuery.of(context).platformBrightness == Brightness.dark);
    final conv = chatState.activeConversation;

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Drag Handle
          const SizedBox(height: 10),
          Container(
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          _buildHeader(context, conv, isDark),
          const Divider(height: 1),

          // Product & Dispatch Status Banner
          if (conv != null) _buildOrderInfoBanner(context, conv, isDark),

          // Chat Messages Body
          Expanded(
            child: chatState.isLoading
                ? _buildSkeletalChatMessages(isDark)
                : chatState.errorMessage != null && chatState.activeConversation == null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.lock_person_rounded, size: 48, color: Color(0xFFEF4444)),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Access Restricted',
                                style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFFEF4444)),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                chatState.errorMessage!,
                                textAlign: TextAlign.center,
                                style: GoogleFonts.inter(fontSize: 13, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                              ),
                            ],
                          ),
                        ),
                      )
                : chatState.messages.isEmpty
                    ? _buildEmptyState(isDark)
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        itemCount: chatState.messages.length,
                        itemBuilder: (context, index) {
                          final msg = chatState.messages[index];
                          return _buildMessageItem(msg, isDark, conv);
                        },
                      ),
          ),

          // Input Footer (only rendered if user is authorized and conversation is loaded)
          if (conv != null)
            _buildInputFooter(context, isDark, chatState.isSending, conv),
        ],
      ),
    );
  }

  Widget _buildSkeletalChatMessages(bool isDark) {
    final shimmerColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final altShimmerColor = isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9);

    return AnimatedBuilder(
      animation: _shimmerAnimation,
      builder: (context, _) {
        final opacity = _shimmerAnimation.value;
        return Opacity(
          opacity: opacity,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            physics: const NeverScrollableScrollPhysics(),
            children: [
              // System milestone placeholder in center
              Center(
                child: Container(
                  width: 260,
                  height: 32,
                  decoration: BoxDecoration(
                    color: shimmerColor.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // Incoming message skeleton (left aligned with avatar)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: shimmerColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 80,
                        height: 10,
                        decoration: BoxDecoration(
                          color: shimmerColor.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        width: 210,
                        height: 52,
                        decoration: BoxDecoration(
                          color: altShimmerColor,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(4),
                            topRight: Radius.circular(16),
                            bottomLeft: Radius.circular(16),
                            bottomRight: Radius.circular(16),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Outgoing message skeleton (right aligned)
              Align(
                alignment: Alignment.centerRight,
                child: Container(
                  width: 190,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0284C7).withValues(alpha: 0.35 * opacity),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                      bottomLeft: Radius.circular(16),
                      bottomRight: Radius.circular(4),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // Another incoming message
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: shimmerColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 90,
                        height: 10,
                        decoration: BoxDecoration(
                          color: shimmerColor.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        width: 170,
                        height: 38,
                        decoration: BoxDecoration(
                          color: altShimmerColor,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(4),
                            topRight: Radius.circular(16),
                            bottomLeft: Radius.circular(16),
                            bottomRight: Radius.circular(16),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, OrderConversationEntity? conv, bool isDark) {
    final authState = ref.watch(authProvider);
    final userRole = authState.user?.role.toLowerCase() ?? '';
    final isDcOperations = userRole.contains('dc') ||
        userRole.contains('manager') ||
        userRole.contains('admin') ||
        userRole.contains('operation') ||
        userRole.contains('supervisor');

    // Receiver is the customer who will receive the delivery
    final receiverName = (conv?.customerName != null && conv!.customerName.trim().isNotEmpty)
        ? conv.customerName.trim()
        : widget.customerName.trim();
    final receiverPhone = widget.customerPhone ?? conv?.customerPhone;
    final orderStatus = (conv?.orderStatus.isNotEmpty == true)
        ? conv!.orderStatus.toUpperCase()
        : 'PENDING_DISPATCH';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          if (widget.showBackButton) ...[
            Tooltip(
              message: 'Back to Conversations',
              child: InkWell(
                onTap: widget.onBack ?? () => Navigator.of(context).pop(),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF334155).withValues(alpha: 0.5) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isDark ? const Color(0xFF475569) : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Icon(
                    Icons.arrow_back_ios_new_rounded,
                    size: 14,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
          ],

          // Receiver Avatar (Customer)
          UserAvatarWidget(
            fullName: receiverName,
            radius: 18,
            backgroundColor: const Color(0xFF0284C7),
            textColor: Colors.white,
          ),
          const SizedBox(width: 10),

          // Receiver Name (Header Title) & Order Number / Status (Subtitle)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        receiverName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        orderStatus,
                        style: GoogleFonts.inter(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF10B981),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Order #${widget.orderNumber}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),

          // Action: Direct Call Receiver (if phone available)
          if (receiverPhone != null && receiverPhone.trim().isNotEmpty) ...[
            Tooltip(
              message: 'Call $receiverName ($receiverPhone)',
              child: InkWell(
                onTap: () => _callNumber(context, receiverPhone),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: const Color(0xFF10B981).withValues(alpha: 0.3),
                    ),
                  ),
                  child: const Icon(
                    Icons.phone_in_talk_rounded,
                    size: 16,
                    color: Color(0xFF10B981),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
          ],

          // Action: Switch Product (Restricted to DC Operations & Managers)
          if (isDcOperations) ...[
            IconButton(
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              padding: const EdgeInsets.all(6),
              visualDensity: VisualDensity.compact,
              tooltip: 'Switch Product',
              icon: const Icon(Icons.swap_horiz_rounded, size: 20, color: Color(0xFF6366F1)),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (ctx) => OrderProductSwitchModal(
                    orderId: widget.orderId,
                    orderNumber: widget.orderNumber,
                    currentProductName: conv?.currentProductName ?? 'Current Product',
                    currentPackageName: conv?.currentPackageName,
                    currentTotalAmount: conv?.currentTotalAmount ?? 0.0,
                    currentClientId: conv?.clientId ?? '',
                    currentClientName: conv?.clientName ?? '',
                  ),
                );
              },
            ),
          ],

          // Close button
          IconButton(
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            padding: const EdgeInsets.all(6),
            visualDensity: VisualDensity.compact,
            onPressed: widget.onClose ?? () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close_rounded, size: 20),
            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            tooltip: 'Close',
          ),
        ],
      ),
    );
  }

  Widget _buildOrderInfoBanner(BuildContext context, OrderConversationEntity conv, bool isDark) {
    final currency = NumberFormat.currency(locale: 'en_NG', symbol: '₦', decimalDigits: 0);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.inventory_2_outlined, size: 14, color: Color(0xFF0D9488)),
            const SizedBox(width: 5),
            Text(
              '${conv.currentProductName ?? 'Product'} (${conv.currentPackageName ?? 'Standard'})',
              style: GoogleFonts.inter(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              currency.format(conv.currentTotalAmount),
              style: GoogleFonts.inter(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF0D9488),
              ),
            ),
            const SizedBox(width: 10),
            Container(width: 1, height: 12, color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
            const SizedBox(width: 10),
            _buildParticipantPill('Client', conv.clientName, const Color(0xFF0D9488), conv: conv),
            if (conv.marketerName != null && conv.marketerName!.trim().isNotEmpty) ...[
              const SizedBox(width: 5),
              _buildParticipantPill(
                'Marketer',
                conv.marketerName!,
                const Color(0xFF10B981),
                avatarUrl: conv.marketerAvatarUrl,
                conv: conv,
              ),
            ],
            if (conv.closerName != null && conv.closerName!.trim().isNotEmpty) ...[
              const SizedBox(width: 5),
              _buildParticipantPill(
                'Closer',
                conv.closerName!,
                const Color(0xFF7C3AED),
                avatarUrl: conv.closerAvatarUrl,
                conv: conv,
              ),
            ],
            const SizedBox(width: 5),
            _buildParticipantPill('DC', conv.distributionCenterName ?? 'DC', const Color(0xFF6366F1), conv: conv),
            const SizedBox(width: 5),
            _buildParticipantPill('Rider', conv.deliveryAgentName ?? 'Unassigned', const Color(0xFFF59E0B), conv: conv),
          ],
        ),
      ),
    );
  }

  Widget _buildParticipantPill(
    String role,
    String name,
    Color color, {
    String? avatarUrl,
    required OrderConversationEntity conv,
  }) {
    return InkWell(
      onTap: () {
        ChatUserProfileCardModal.show(
          context: context,
          ref: ref,
          tag: role.toLowerCase(),
          conversation: conv,
          onMention: _appendMentionTag,
        );
      },
      borderRadius: BorderRadius.circular(6),
      child: Tooltip(
        message: 'View $role profile',
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: color.withValues(alpha: 0.25)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (avatarUrl != null && avatarUrl.isNotEmpty) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    avatarUrl,
                    width: 14,
                    height: 14,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
                const SizedBox(width: 4),
              ],
              Text(
                '$role: ${name.split(' ').first}',
                style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMessageItem(OrderConversationMessageEntity msg, bool isDark, OrderConversationEntity? conv) {
    if (msg.isSystem || msg.isStatusEvent) {
      return _buildSystemMilestone(msg, isDark);
    }

    final authUser = ref.watch(authProvider).user;
    final currentUserId = authUser?.id;
    final isMyMessage = (currentUserId != null && msg.senderId == currentUserId);

    final isMarketer = msg.senderRole == ChatSenderRole.marketer;
    final isCloser = msg.senderRole == ChatSenderRole.closer;
    final isClient = msg.senderRole == ChatSenderRole.client;
    final isDc = msg.senderRole == ChatSenderRole.dcManager;
    final isRider = msg.senderRole == ChatSenderRole.deliveryAgent;

    Color roleColor = const Color(0xFF64748B);
    String roleLabel = 'Member';
    if (isMarketer) {
      roleColor = const Color(0xFF10B981); // Emerald
      roleLabel = 'Marketer';
    } else if (isCloser) {
      roleColor = const Color(0xFF8B5CF6); // Vibrant Purple
      roleLabel = 'Closer';
    } else if (isClient) {
      roleColor = const Color(0xFF0D9488); // Teal
      roleLabel = 'Merchant';
    } else if (isDc) {
      roleColor = const Color(0xFF6366F1); // Indigo
      roleLabel = 'DC Operations';
    } else if (isRider) {
      roleColor = const Color(0xFFF59E0B); // Amber Courier
      roleLabel = 'Rider';
    }

    final timeStr = _formatMessageTime(msg.createdAt);

    // 1. Right-aligned for current account
    if (isMyMessage) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            const SizedBox(width: 48), // Padding on opposite side
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFF0284C7),
                          Color(0xFF0369A1),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(18),
                        topRight: Radius.circular(18),
                        bottomLeft: Radius.circular(18),
                        bottomRight: Radius.circular(4),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0284C7).withValues(alpha: 0.22),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: _buildMessageBodyWithInteractiveMentions(
                      msg.messageBody,
                      isMyMessage: true,
                      isDark: isDark,
                      conv: conv,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        timeStr,
                        style: GoogleFonts.inter(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w500,
                          color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.done_all_rounded,
                        size: 14,
                        color: Color(0xFF0284C7),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // User Avatar / DP
            UserAvatarWidget(
              avatarUrl: msg.senderAvatarUrl ?? authUser?.avatarUrl,
              fullName: authUser?.fullName.isNotEmpty == true ? authUser!.fullName : 'You',
              radius: 14,
              backgroundColor: const Color(0xFF0284C7),
              textColor: Colors.white,
            ),
          ],
        ),
      );
    }

    // 2. Left-aligned with role-based color differentiation for other accounts
    final bubbleBg = isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9);
    final bubbleBorder = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // DP of sender (interactive: tap to view profile card)
          InkWell(
            onTap: () {
              ChatUserProfileCardModal.show(
                context: context,
                ref: ref,
                tag: msg.senderName,
                conversation: conv,
                onMention: _appendMentionTag,
              );
            },
            borderRadius: BorderRadius.circular(16),
            child: Tooltip(
              message: 'View ${msg.senderName} profile',
              child: UserAvatarWidget(
                avatarUrl: msg.senderAvatarUrl,
                fullName: msg.senderName,
                radius: 16,
                backgroundColor: roleColor.withValues(alpha: 0.18),
                textColor: roleColor,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Sender name and role tag (interactive: tap to view profile card)
                InkWell(
                  onTap: () {
                    ChatUserProfileCardModal.show(
                      context: context,
                      ref: ref,
                      tag: msg.senderName,
                      conversation: conv,
                      onMention: _appendMentionTag,
                    );
                  },
                  borderRadius: BorderRadius.circular(4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          msg.senderName,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: roleColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: roleColor.withValues(alpha: 0.2)),
                        ),
                        child: Text(
                          roleLabel,
                          style: GoogleFonts.inter(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: roleColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),

                // Organic Recipient Bubble with clickable mentions
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: bubbleBg,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(4),
                      topRight: Radius.circular(18),
                      bottomLeft: Radius.circular(18),
                      bottomRight: Radius.circular(18),
                    ),
                    border: Border.all(color: bubbleBorder),
                  ),
                  child: _buildMessageBodyWithInteractiveMentions(
                    msg.messageBody,
                    isMyMessage: false,
                    isDark: isDark,
                    conv: conv,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  timeStr,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 48), // Padding on opposite side
        ],
      ),
    );
  }

  Widget _buildSystemMilestone(OrderConversationMessageEntity msg, bool isDark) {
    IconData icon = Icons.info_outline_rounded;
    Color color = const Color(0xFF6366F1);

    switch (msg.messageType) {
      case ChatMessageType.riderAssigned:
        icon = Icons.two_wheeler_rounded;
        color = const Color(0xFFF59E0B);
        break;
      case ChatMessageType.deliveryCompleted:
        icon = Icons.check_circle_rounded;
        color = const Color(0xFF10B981);
        break;
      case ChatMessageType.deliveryFailed:
        icon = Icons.cancel_rounded;
        color = const Color(0xFFEF4444);
        break;
      case ChatMessageType.productChanged:
      case ChatMessageType.ownershipTransferred:
        icon = Icons.published_with_changes_rounded;
        color = const Color(0xFF8B5CF6);
        break;
      default:
        icon = Icons.notifications_active_outlined;
        color = const Color(0xFF0D9488);
    }

    final timeStr = DateFormat('h:mm a').format(msg.createdAt);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  msg.messageBody,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                timeStr,
                style: GoogleFonts.inter(
                  fontSize: 10,
                  color: color.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.chat_bubble_outline_rounded, size: 40, color: Color(0xFF94A3B8)),
          const SizedBox(height: 10),
          Text(
            'Order Pipeline Conversation Active',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Updates, rider assignments, and notes appear in real-time.',
            style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8)),
          ),
        ],
      ),
    );
  }

  Widget _buildInputFooter(
    BuildContext context,
    bool isDark,
    bool isSending,
    OrderConversationEntity? conv,
  ) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Container(
      padding: EdgeInsets.only(
        left: 14,
        right: 14,
        top: 10,
        bottom: bottomInset + (bottomPadding > 0 ? bottomPadding : 12),
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? const Color(0xFF334155).withValues(alpha: 0.6) : const Color(0xFFE2E8F0),
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                  width: 1.2,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const SizedBox(width: 14),
                  // Clean Organic Text Field
                  Expanded(
                    child: TextField(
                      controller: _msgController,
                      focusNode: _msgFocusNode,
                      minLines: 1,
                      maxLines: 4,
                      textCapitalization: TextCapitalization.sentences,
                      onSubmitted: (_) => _handleSendMessage(),
                      style: GoogleFonts.inter(
                        fontSize: 13.5,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                        height: 1.35,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        hintStyle: GoogleFonts.inter(
                          fontSize: 13,
                          color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 12),
                        isDense: true,
                      ),
                    ),
                  ),

                  // Emoji Quick Picker Popup Button
                  Tooltip(
                    message: 'Add Emoji',
                    child: PopupMenuButton<String>(
                      icon: Icon(
                        Icons.sentiment_satisfied_alt_outlined,
                        size: 20,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                      padding: const EdgeInsets.only(left: 4, right: 10, bottom: 10, top: 10),
                      constraints: const BoxConstraints(minWidth: 34, minHeight: 44),
                      tooltip: 'Add emoji',
                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
                          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                        ),
                      ),
                      onSelected: (emoji) {
                        final cur = _msgController.text;
                        _msgController.text = '$cur $emoji '.trimLeft();
                        _msgController.selection = TextSelection.fromPosition(
                          TextPosition(offset: _msgController.text.length),
                        );
                        _msgFocusNode.requestFocus();
                      },
                      itemBuilder: (ctx) => [
                        PopupMenuItem(
                          enabled: false,
                          child: Text(
                            'Quick Reactions',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            ),
                          ),
                        ),
                        const PopupMenuDivider(height: 4),
                        PopupMenuItem(
                          padding: EdgeInsets.zero,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            child: Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: [
                                '👍', '✅', '📦', '🚚', '📍', '💰', '📞', '⚠️', '🚨', '🙏'
                              ].map((emoji) {
                                return InkWell(
                                  onTap: () {
                                    Navigator.of(ctx).pop(emoji);
                                  },
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? const Color(0xFF334155).withValues(alpha: 0.5)
                                          : const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(emoji, style: const TextStyle(fontSize: 18)),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Circular Organic Send Button (Smooth micro-pulse on sending, NO circular spinner)
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF0284C7),
                  Color(0xFF0369A1),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0284C7).withValues(alpha: 0.35),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(22),
                onTap: isSending ? null : _handleSendMessage,
                child: Center(
                  child: isSending
                      ? FadeTransition(
                          opacity: _shimmerAnimation,
                          child: const Icon(
                            Icons.arrow_upward_rounded,
                            color: Colors.white,
                            size: 19,
                          ),
                        )
                      : const Icon(
                          Icons.send_rounded,
                          color: Colors.white,
                          size: 19,
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

