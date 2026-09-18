import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/widgets/user_avatar_widget.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/order_conversation.dart';
import '../providers/pipeline_chat_provider.dart';
import 'order_pipeline_chat_sheet.dart';

class ConversationListModal extends ConsumerStatefulWidget {
  final String? initialOrderId;
  final String? initialOrderNumber;
  final String? initialCustomerName;
  final String? initialCustomerPhone;
  final String? initialMessage;

  const ConversationListModal({
    super.key,
    this.initialOrderId,
    this.initialOrderNumber,
    this.initialCustomerName,
    this.initialCustomerPhone,
    this.initialMessage,
  });

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const ConversationListModal(),
    );
  }

  static Future<void> showForOrder(
    BuildContext context, {
    required String orderId,
    required String orderNumber,
    required String customerName,
    String? customerPhone,
    String? initialMessage,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ConversationListModal(
        initialOrderId: orderId,
        initialOrderNumber: orderNumber,
        initialCustomerName: customerName,
        initialCustomerPhone: customerPhone,
        initialMessage: initialMessage,
      ),
    );
  }

  @override
  ConsumerState<ConversationListModal> createState() => _ConversationListModalState();
}

class _ConversationListModalState extends ConsumerState<ConversationListModal> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  String? _activeOrderId;
  String? _activeOrderNumber;
  String? _activeCustomerName;
  String? _activeCustomerPhone;
  String? _activeInitialMessage;

  @override
  void initState() {
    super.initState();
    _activeOrderId = widget.initialOrderId;
    _activeOrderNumber = widget.initialOrderNumber;
    _activeCustomerName = widget.initialCustomerName;
    _activeCustomerPhone = widget.initialCustomerPhone;
    _activeInitialMessage = widget.initialMessage;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(pipelineChatProvider.notifier).loadScopedConversations();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _formatTimestamp(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inMinutes < 1) {
      return 'Just now';
    } else if (diff.inHours < 1) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inDays < 1 && now.day == dt.day) {
      return DateFormat('h:mm a').format(dt);
    } else if (diff.inDays < 7) {
      return DateFormat('EEE, h:mm a').format(dt);
    } else {
      return DateFormat('MMM d, h:mm a').format(dt);
    }
  }

  int _getUnreadForConversation(OrderConversationEntity conv, String role) {
    final r = role.toLowerCase().trim();
    if (r.contains('rider') || r.contains('delivery_agent') || r.contains('pda') || r.contains('driver')) {
      return conv.unreadRiderCount;
    } else if (r.contains('dc') || r.contains('manager') || r.contains('operations')) {
      return conv.unreadDcCount;
    } else {
      return conv.unreadClientCount;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isChatView = _activeOrderId != null;

    return PopScope(
      canPop: !isChatView,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && isChatView) {
          setState(() {
            _activeOrderId = null;
            _activeOrderNumber = null;
            _activeCustomerName = null;
            _activeCustomerPhone = null;
            _activeInitialMessage = null;
          });
          ref.read(pipelineChatProvider.notifier).loadScopedConversations();
        }
      },
      child: isChatView
          ? OrderPipelineChatSheet(
              key: ValueKey(_activeOrderId!),
              orderId: _activeOrderId!,
              orderNumber: _activeOrderNumber ?? '',
              customerName: _activeCustomerName ?? 'Customer',
              customerPhone: _activeCustomerPhone,
              initialMessage: _activeInitialMessage,
              showBackButton: true,
              onBack: () {
                setState(() {
                  _activeOrderId = null;
                  _activeOrderNumber = null;
                  _activeCustomerName = null;
                  _activeCustomerPhone = null;
                  _activeInitialMessage = null;
                });
                ref.read(pipelineChatProvider.notifier).loadScopedConversations();
              },
              onClose: () => Navigator.of(context).pop(),
            )
          : _buildConversationListView(context),
    );
  }

  Widget _buildConversationListView(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final chatState = ref.watch(pipelineChatProvider);
    final authUser = ref.watch(authProvider).user;
    final userRole = authUser?.role ?? 'client';
    final isCloser = authUser?.isCloser == true;
    final closerId = authUser?.closerId ?? authUser?.id;
    final closerName = authUser?.fullName.trim().toLowerCase();

    // Defense-in-depth: Closers only have access to conversations that concern their orders
    final allConversations = isCloser
        ? chatState.recentConversations.where((conv) {
            final matchId = conv.closerId != null && (conv.closerId == closerId || conv.closerId == authUser?.id);
            final matchName = closerName != null && closerName.isNotEmpty && conv.closerName != null && conv.closerName!.trim().toLowerCase() == closerName;
            return matchId || matchName;
          }).toList()
        : chatState.recentConversations;

    // Filter conversations chronologically top to bottom and by search query
    final filteredConversations = allConversations.where((conv) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      final cust = conv.customerName.toLowerCase();
      final num = conv.orderNumber.toLowerCase();
      final prod = (conv.currentProductName ?? '').toLowerCase();
      return cust.contains(q) || num.contains(q) || prod.contains(q);
    }).toList();

    // Already ordered by last_message_at DESC from remote source, but sort defensively
    filteredConversations.sort((a, b) => b.lastMessageAt.compareTo(a.lastMessageAt));

    final totalUnread = chatState.getUnreadCountForRole(userRole);

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 25,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        children: [
          // Drag handle
          const SizedBox(height: 10),
          Container(
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),

          // Modal Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D9488).withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.forum_rounded,
                    color: Color(0xFF0D9488),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              'Order Pipeline Chats',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                            ),
                          ),
                          if (totalUnread > 0) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEF4444),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '$totalUnread new',
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 1),
                      Text(
                        isCloser ? 'Live coordination for your booked & assigned orders' : 'Live coordination between Merchant, DC & Rider',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: const Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  padding: const EdgeInsets.all(6),
                  visualDensity: VisualDensity.compact,
                  onPressed: () => ref.read(pipelineChatProvider.notifier).loadScopedConversations(),
                  icon: const Icon(Icons.refresh_rounded, size: 20, color: Color(0xFF94A3B8)),
                  tooltip: 'Refresh Conversations',
                ),
                IconButton(
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  padding: const EdgeInsets.all(6),
                  visualDensity: VisualDensity.compact,
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded, size: 20, color: Color(0xFF94A3B8)),
                  tooltip: 'Close',
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchController,
              onChanged: (val) => setState(() => _searchQuery = val.trim()),
              style: GoogleFonts.inter(
                fontSize: 13,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
              decoration: InputDecoration(
                hintText: 'Search receiver name, order #, or product...',
                hintStyle: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF94A3B8)),
                prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFF94A3B8)),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 16),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          const Divider(height: 1),

          // Conversations List Body
          Expanded(
            child: chatState.isLoading && allConversations.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : filteredConversations.isEmpty
                    ? _buildEmptyState(isDark)
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        itemCount: filteredConversations.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final conv = filteredConversations[index];
                          final unread = _getUnreadForConversation(conv, userRole);
                          final isUnread = unread > 0;
                          return _buildConversationCard(
                            context: context,
                            conv: conv,
                            unreadCount: unread,
                            isUnread: isUnread,
                            isDark: isDark,
                            userRole: userRole,
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.chat_bubble_outline_rounded,
                size: 44,
                color: Color(0xFF94A3B8),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isNotEmpty
                  ? 'No matching conversations'
                  : 'No conversations yet',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _searchQuery.isNotEmpty
                  ? 'Try searching with another receiver name or order number.'
                  : 'Order pipeline conversations appear here as orders are assigned and dispatched.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 12.5,
                color: const Color(0xFF94A3B8),
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConversationCard({
    required BuildContext context,
    required OrderConversationEntity conv,
    required int unreadCount,
    required bool isUnread,
    required bool isDark,
    required String userRole,
  }) {
    // Clean uniform background and border for all cards (highlight removed as requested)
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    // Creator of the order / Closer that owns the order
    final creatorName = (conv.closerName != null && conv.closerName!.trim().isNotEmpty)
        ? conv.closerName!.trim()
        : (conv.clientName.trim().isNotEmpty ? conv.clientName.trim() : conv.customerName);
    final creatorAvatar = (conv.closerAvatarUrl != null && conv.closerAvatarUrl!.trim().isNotEmpty)
        ? conv.closerAvatarUrl!.trim()
        : null;

    return InkWell(
      onTap: () {
        // Mark conversation as read
        ref.read(pipelineChatProvider.notifier).markConversationAsRead(conv.id, userRole);

        // Seamlessly switch to the chat view within the same modal
        setState(() {
          _activeOrderId = conv.orderId;
          _activeOrderNumber = conv.orderNumber;
          _activeCustomerName = conv.customerName;
          _activeCustomerPhone = null;
          _activeInitialMessage = null;
        });
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor, width: 1.0),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Profile Picture / DP of the creator of the order / closer that owns the order
            UserAvatarWidget(
              fullName: creatorName,
              avatarUrl: creatorAvatar,
              radius: 24,
              backgroundColor: const Color(0xFF4F46E5), // Closer/Creator Indigo
              textColor: Colors.white,
            ),
            const SizedBox(width: 12),

            // Conversation Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Row 1: Receiver Name & Timestamp
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          conv.customerName,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: isUnread ? FontWeight.w800 : FontWeight.w600,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _formatTimestamp(conv.lastMessageAt),
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: isUnread ? FontWeight.w700 : FontWeight.w500,
                          color: const Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),

                  // Row 2: Subtle Order ID & Status tag with wrap support
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 6,
                    runSpacing: 3,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Order #${conv.orderNumber}',
                          style: GoogleFonts.inter(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          conv.orderStatus.toUpperCase(),
                          style: GoogleFonts.inter(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF10B981),
                          ),
                        ),
                      ),
                      if (conv.closerName != null && conv.closerName!.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: const Color(0xFF7C3AED).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (conv.closerAvatarUrl != null && conv.closerAvatarUrl!.isNotEmpty) ...[
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: Image.network(
                                    conv.closerAvatarUrl!,
                                    width: 12,
                                    height: 12,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                                  ),
                                ),
                                const SizedBox(width: 3),
                              ],
                              Text(
                                'Closer: ${conv.closerName!.split(' ').first}',
                                style: GoogleFonts.inter(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF7C3AED),
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (conv.currentProductName != null && conv.currentProductName!.isNotEmpty)
                        Text(
                          '• ${conv.currentProductName}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 10.5,
                            color: const Color(0xFF94A3B8),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 5),

                  // Row 3: Latest Message Preview & Unread Badge
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${conv.lastMessageSenderName ?? 'System'}: ${conv.lastMessageText ?? 'Pipeline active.'}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: isUnread ? FontWeight.w600 : FontWeight.w400,
                            color: isUnread
                                ? (isDark ? Colors.white : const Color(0xFF0F172A))
                                : const Color(0xFF64748B),
                          ),
                        ),
                      ),
                      if (isUnread) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0D9488),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '$unreadCount',
                            style: GoogleFonts.inter(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
