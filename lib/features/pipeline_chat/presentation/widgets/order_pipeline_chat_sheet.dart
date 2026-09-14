import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/order_conversation.dart';
import '../../domain/entities/order_conversation_message.dart';
import '../../../orders/domain/entities/order.dart';
import '../../../orders/presentation/widgets/order_product_switch_modal.dart';
import '../../../../core/widgets/user_avatar_widget.dart';
import '../providers/pipeline_chat_provider.dart';
import 'conversation_list_modal.dart';

class OrderPipelineChatSheet extends ConsumerStatefulWidget {
  final String orderId;
  final String orderNumber;
  final String customerName;
  final String? customerPhone;
  final String? initialMessage;
  final bool showBackButton;
  final VoidCallback? onBack;

  const OrderPipelineChatSheet({
    super.key,
    required this.orderId,
    required this.orderNumber,
    required this.customerName,
    this.customerPhone,
    this.initialMessage,
    this.showBackButton = true,
    this.onBack,
  });

  static Future<void> showForOrder(
    BuildContext context,
    OrderEntity order, {
    String? initialMessage,
    bool showBackButton = true,
    VoidCallback? onBack,
  }) {
    return show(
      context,
      orderId: order.id,
      orderNumber: order.orderNumber,
      customerName: order.customerName,
      customerPhone: order.customerPhone,
      initialMessage: initialMessage,
      showBackButton: showBackButton,
      onBack: onBack,
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
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => OrderPipelineChatSheet(
        orderId: orderId,
        orderNumber: orderNumber,
        customerName: customerName,
        customerPhone: customerPhone,
        initialMessage: initialMessage,
        showBackButton: showBackButton,
        onBack: onBack,
      ),
    );
  }

  @override
  ConsumerState<OrderPipelineChatSheet> createState() => _OrderPipelineChatSheetState();
}

class _OrderPipelineChatSheetState extends ConsumerState<OrderPipelineChatSheet> {
  final TextEditingController _msgController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _msgFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
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
    _msgController.dispose();
    _scrollController.dispose();
    _msgFocusNode.dispose();
    super.dispose();
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

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(pipelineChatProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
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
                ? const Center(child: CircularProgressIndicator())
                : chatState.messages.isEmpty
                    ? _buildEmptyState(isDark)
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        itemCount: chatState.messages.length,
                        itemBuilder: (context, index) {
                          final msg = chatState.messages[index];
                          return _buildMessageItem(msg, isDark);
                        },
                      ),
          ),

          // Input Footer
          _buildInputFooter(context, isDark, chatState.isSending),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, OrderConversationEntity? conv, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      child: Row(
        children: [
          if (widget.showBackButton) ...[
            Tooltip(
              message: 'Back to Conversations',
              child: InkWell(
                onTap: () {
                  Navigator.of(context).pop();
                  if (widget.onBack != null) {
                    widget.onBack!();
                  } else {
                    ConversationListModal.show(context);
                  }
                },
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF334155).withValues(alpha: 0.5) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isDark ? const Color(0xFF475569) : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Icon(
                    Icons.arrow_back_ios_new_rounded,
                    size: 15,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
          ],

          // Order / Customer Avatar
          UserAvatarWidget(
            fullName: widget.customerName,
            radius: 20,
            backgroundColor: const Color(0xFF0D9488),
            textColor: Colors.white,
          ),
          const SizedBox(width: 12),

          // Order Number & Participants
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        widget.orderNumber,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        conv?.orderStatus.toUpperCase() ?? 'LIVE PIPELINE',
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
                  'Customer: ${widget.customerName} • 3-Way Order Hub',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),

          // Action: Switch Product (Restricted to DC Operations & Managers)
          Builder(
            builder: (context) {
              final authState = ref.watch(authProvider);
              final userRole = authState.user?.role.toLowerCase() ?? '';
              final isDcOperations = userRole.contains('dc') ||
                  userRole.contains('manager') ||
                  userRole.contains('admin') ||
                  userRole.contains('operation') ||
                  userRole.contains('supervisor');

              if (isDcOperations) {
                return TextButton.icon(
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
                  icon: const Icon(Icons.swap_horiz_rounded, size: 16, color: Color(0xFF6366F1)),
                  label: Text(
                    'Switch Product',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF6366F1),
                    ),
                  ),
                  style: TextButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1).withValues(alpha: 0.08),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                );
              }

              // Rider / Delivery Agent View: Tag Operations Button
              return TextButton.icon(
                onPressed: () {
                  if (!_msgController.text.contains('@Operations')) {
                    _msgController.text = '@Operations Customer requested to change product/package: ${_msgController.text}'.trim();
                    _msgController.selection = TextSelection.fromPosition(TextPosition(offset: _msgController.text.length));
                  }
                  _msgFocusNode.requestFocus();
                },
                icon: const Icon(Icons.alternate_email_rounded, size: 15, color: Color(0xFF0D9488)),
                label: Text(
                  'Tag @Operations',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0D9488),
                  ),
                ),
                style: TextButton.styleFrom(
                  backgroundColor: const Color(0xFF0D9488).withValues(alpha: 0.08),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              );
            },
          ),
          const SizedBox(width: 6),

          // Close button
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close_rounded),
            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            iconSize: 20,
          ),
        ],
      ),
    );
  }

  Widget _buildOrderInfoBanner(BuildContext context, OrderConversationEntity conv, bool isDark) {
    final currency = NumberFormat.currency(locale: 'en_NG', symbol: '₦', decimalDigits: 0);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Product & Package
          Expanded(
            child: Row(
              children: [
                const Icon(Icons.inventory_2_outlined, size: 16, color: Color(0xFF0D9488)),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    '${conv.currentProductName ?? 'Product'} (${conv.currentPackageName ?? 'Standard'})',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  currency.format(conv.currentTotalAmount),
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0D9488),
                  ),
                ),
              ],
            ),
          ),

          // Participants Pills
          Row(
            children: [
              _buildParticipantPill('Client', conv.clientName, const Color(0xFF0D9488)),
              const SizedBox(width: 6),
              _buildParticipantPill('DC', conv.distributionCenterName ?? 'DC', const Color(0xFF6366F1)),
              const SizedBox(width: 6),
              _buildParticipantPill('Rider', conv.deliveryAgentName ?? 'Unassigned', const Color(0xFFF59E0B)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildParticipantPill(String role, String name, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Text(
        '$role: ${name.split(' ').first}',
        style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }

  Widget _buildMessageItem(OrderConversationMessageEntity msg, bool isDark) {
    if (msg.isSystem || msg.isStatusEvent) {
      return _buildSystemMilestone(msg, isDark);
    }

    final authUser = ref.watch(authProvider).user;
    final currentUserId = authUser?.id;
    final isMyMessage = (currentUserId != null && msg.senderId == currentUserId);

    final isClient = msg.senderRole == ChatSenderRole.client;
    final isDc = msg.senderRole == ChatSenderRole.dcManager;
    final isRider = msg.senderRole == ChatSenderRole.deliveryAgent;

    Color roleColor = const Color(0xFF64748B);
    String roleLabel = 'Member';
    if (isClient) {
      roleColor = const Color(0xFFD97706); // Warm Amber
      roleLabel = 'Merchant';
    } else if (isDc) {
      roleColor = const Color(0xFF6366F1); // Indigo
      roleLabel = 'DC Operations';
    } else if (isRider) {
      roleColor = const Color(0xFF0284C7); // Sky Blue / Cyan
      roleLabel = 'Rider';
    }

    final timeStr = DateFormat('h:mm a').format(msg.createdAt);

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
                          Color(0xFF0D9488),
                          Color(0xFF0F766E),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(16),
                        topRight: Radius.circular(16),
                        bottomLeft: Radius.circular(16),
                        bottomRight: Radius.circular(4),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0D9488).withValues(alpha: 0.25),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          msg.messageBody,
                          style: GoogleFonts.inter(
                            fontSize: 13.5,
                            height: 1.35,
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              timeStr,
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                color: Colors.white.withValues(alpha: 0.75),
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.done_all_rounded,
                              size: 13,
                              color: Colors.white70,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // User Avatar / DP
            UserAvatarWidget(
              avatarUrl: msg.senderAvatarUrl ?? authUser?.avatarUrl,
              fullName: authUser?.fullName.isNotEmpty == true ? authUser!.fullName : 'You',
              radius: 15,
              backgroundColor: const Color(0xFF0D9488),
              textColor: Colors.white,
            ),
          ],
        ),
      );
    }

    // 2. Left-aligned with role-based color differentiation for other accounts
    Color otherBg;
    Color otherBorder;
    if (isDc) {
      otherBg = isDark ? const Color(0xFF1E1B4B).withValues(alpha: 0.5) : const Color(0xFFEEF2FF);
      otherBorder = const Color(0xFF6366F1).withValues(alpha: 0.25);
    } else if (isRider) {
      otherBg = isDark ? const Color(0xFF0C4A6E).withValues(alpha: 0.3) : const Color(0xFFF0F9FF);
      otherBorder = const Color(0xFF0284C7).withValues(alpha: 0.25);
    } else {
      otherBg = isDark ? const Color(0xFF451A03).withValues(alpha: 0.3) : const Color(0xFFFFFBEB);
      otherBorder = const Color(0xFFD97706).withValues(alpha: 0.25);
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // DP of sender
          UserAvatarWidget(
            avatarUrl: msg.senderAvatarUrl,
            fullName: msg.senderName,
            radius: 16,
            backgroundColor: roleColor.withValues(alpha: 0.18),
            textColor: roleColor,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Sender name and role tag
                Row(
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
                    const SizedBox(width: 6),
                    Text(
                      timeStr,
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),

                // Bubble
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: otherBg,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(4),
                      topRight: Radius.circular(16),
                      bottomLeft: Radius.circular(16),
                      bottomRight: Radius.circular(16),
                    ),
                    border: Border.all(color: otherBorder),
                  ),
                  child: Text(
                    msg.messageBody,
                    style: GoogleFonts.inter(
                      fontSize: 13.5,
                      height: 1.4,
                      color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF1E293B),
                    ),
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

  Widget _buildInputFooter(BuildContext context, bool isDark, bool isSending) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final authUser = ref.watch(authProvider).user;
    final userRole = authUser?.role.toLowerCase() ?? '';
    final isRider = userRole.contains('rider') || userRole.contains('agent') || userRole.contains('pda');
    final isDc = userRole.contains('dc') || userRole.contains('manager') || userRole.contains('admin');

    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 8,
        bottom: bottomInset + (bottomPadding > 0 ? bottomPadding : 14),
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        border: Border(
          top: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Quick tag pills (Role-aware for Rider, DC Operations, and Merchant)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                if (isRider) ...[
                  ActionChip(
                    avatar: const Icon(Icons.swap_horiz_rounded, size: 12, color: Color(0xFF0D9488)),
                    label: Text('Tag @Operations (Package Change)', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF0D9488))),
                    backgroundColor: const Color(0xFF0D9488).withValues(alpha: 0.08),
                    side: const BorderSide(color: Color(0xFF0D9488)),
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                    onPressed: () {
                      final cur = _msgController.text;
                      if (!cur.contains('@Operations')) {
                        _msgController.text = '@Operations Customer requested product/package change: $cur'.trim();
                        _msgController.selection = TextSelection.fromPosition(TextPosition(offset: _msgController.text.length));
                      }
                      _msgFocusNode.requestFocus();
                    },
                  ),
                  const SizedBox(width: 6),
                  ActionChip(
                    avatar: const Icon(Icons.location_on_outlined, size: 12, color: Color(0xFF2563EB)),
                    label: Text('Tag @Operations (Address Adjustment)', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF2563EB))),
                    backgroundColor: const Color(0xFF2563EB).withValues(alpha: 0.08),
                    side: const BorderSide(color: Color(0xFF2563EB)),
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                    onPressed: () {
                      final cur = _msgController.text;
                      if (!cur.contains('@Operations')) {
                        _msgController.text = '@Operations Customer requested address adjustment: $cur'.trim();
                        _msgController.selection = TextSelection.fromPosition(TextPosition(offset: _msgController.text.length));
                      }
                      _msgFocusNode.requestFocus();
                    },
                  ),
                ] else if (isDc) ...[
                  ActionChip(
                    avatar: const Icon(Icons.two_wheeler_rounded, size: 12, color: Color(0xFFF59E0B)),
                    label: Text('Tag @Rider (Delivery Instructions)', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFFF59E0B))),
                    backgroundColor: const Color(0xFFF59E0B).withValues(alpha: 0.08),
                    side: const BorderSide(color: Color(0xFFF59E0B)),
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                    onPressed: () {
                      final cur = _msgController.text;
                      if (!cur.contains('@Rider')) {
                        _msgController.text = '@Rider '.trim();
                        _msgController.selection = TextSelection.fromPosition(TextPosition(offset: _msgController.text.length));
                      }
                      _msgFocusNode.requestFocus();
                    },
                  ),
                  const SizedBox(width: 6),
                  ActionChip(
                    avatar: const Icon(Icons.storefront_rounded, size: 12, color: Color(0xFF0D9488)),
                    label: Text('Tag @Client (Status Update)', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF0D9488))),
                    backgroundColor: const Color(0xFF0D9488).withValues(alpha: 0.08),
                    side: const BorderSide(color: Color(0xFF0D9488)),
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                    onPressed: () {
                      final cur = _msgController.text;
                      if (!cur.contains('@Client')) {
                        _msgController.text = '@Client '.trim();
                        _msgController.selection = TextSelection.fromPosition(TextPosition(offset: _msgController.text.length));
                      }
                      _msgFocusNode.requestFocus();
                    },
                  ),
                ] else ...[
                  ActionChip(
                    avatar: const Icon(Icons.corporate_fare_rounded, size: 12, color: Color(0xFF0D9488)),
                    label: Text('Tag @Operations (Urgent Request)', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF0D9488))),
                    backgroundColor: const Color(0xFF0D9488).withValues(alpha: 0.08),
                    side: const BorderSide(color: Color(0xFF0D9488)),
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                    onPressed: () {
                      final cur = _msgController.text;
                      if (!cur.contains('@Operations')) {
                        _msgController.text = '@Operations '.trim();
                        _msgController.selection = TextSelection.fromPosition(TextPosition(offset: _msgController.text.length));
                      }
                      _msgFocusNode.requestFocus();
                    },
                  ),
                  const SizedBox(width: 6),
                  ActionChip(
                    avatar: const Icon(Icons.two_wheeler_rounded, size: 12, color: Color(0xFFF59E0B)),
                    label: Text('Tag @Rider (Delivery Notes)', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFFF59E0B))),
                    backgroundColor: const Color(0xFFF59E0B).withValues(alpha: 0.08),
                    side: const BorderSide(color: Color(0xFFF59E0B)),
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                    onPressed: () {
                      final cur = _msgController.text;
                      if (!cur.contains('@Rider')) {
                        _msgController.text = '@Rider '.trim();
                        _msgController.selection = TextSelection.fromPosition(TextPosition(offset: _msgController.text.length));
                      }
                      _msgFocusNode.requestFocus();
                    },
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _msgController,
                  focusNode: _msgFocusNode,
                  onSubmitted: (_) => _handleSendMessage(),
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
              decoration: InputDecoration(
                hintText: 'Type order update or message...',
                hintStyle: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF94A3B8)),
                filled: true,
                fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: const BorderSide(color: Color(0xFF0D9488), width: 1.5),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            decoration: const BoxDecoration(
              color: Color(0xFF0D9488),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              onPressed: isSending ? null : _handleSendMessage,
              icon: isSending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.send_rounded, color: Colors.white, size: 18),
            ),
          ),
        ],
      ),
    ],
  ),
);

  }
}

