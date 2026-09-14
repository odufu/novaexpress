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
  const ConversationListModal({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const ConversationListModal(),
    );
  }

  @override
  ConsumerState<ConversationListModal> createState() => _ConversationListModalState();
}

class _ConversationListModalState extends ConsumerState<ConversationListModal> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final chatState = ref.watch(pipelineChatProvider);
    final authUser = ref.watch(authProvider).user;
    final userRole = authUser?.role ?? 'client';

    // Filter conversations chronologically top to bottom and by search query
    final allConversations = chatState.recentConversations;
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
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D9488).withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.forum_rounded,
                    color: Color(0xFF0D9488),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Order Pipeline Chats',
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                          if (totalUnread > 0) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEF4444),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '$totalUnread new',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Live coordination between Merchant, DC & Rider',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: const Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => ref.read(pipelineChatProvider.notifier).loadScopedConversations(),
                  icon: const Icon(Icons.refresh_rounded, size: 20, color: Color(0xFF94A3B8)),
                  tooltip: 'Refresh Conversations',
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded, size: 20, color: Color(0xFF94A3B8)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
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
          const SizedBox(height: 12),
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
    // Unread conversations have distinct border and soft vibrant accent background
    final cardBg = isUnread
        ? (isDark
            ? const Color(0xFF0D9488).withValues(alpha: 0.15)
            : const Color(0xFF0D9488).withValues(alpha: 0.08))
        : (isDark ? const Color(0xFF1E293B) : Colors.white);

    final borderColor = isUnread
        ? const Color(0xFF0D9488).withValues(alpha: 0.5)
        : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0));

    return InkWell(
      onTap: () {
        // Mark conversation as read
        ref.read(pipelineChatProvider.notifier).markConversationAsRead(conv.id, userRole);

        // Close modal sheet
        Navigator.of(context).pop();

        // Open chat sheet for this order with callback returning to conversations list
        OrderPipelineChatSheet.show(
          context,
          orderId: conv.orderId,
          orderNumber: conv.orderNumber,
          customerName: conv.customerName,
          showBackButton: true,
          onBack: () => ConversationListModal.show(context),
        );
      },
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor, width: isUnread ? 1.5 : 1.0),
          boxShadow: [
            if (isUnread)
              BoxShadow(
                color: const Color(0xFF0D9488).withValues(alpha: 0.12),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Profile Picture / DP of the receiver
            Stack(
              children: [
                UserAvatarWidget(
                  fullName: conv.customerName,
                  radius: 24,
                  backgroundColor: isUnread ? const Color(0xFF0D9488) : const Color(0xFF2563EB),
                  textColor: Colors.white,
                ),
                if (isUnread)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981), // Active green indicator
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
              ],
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
                          color: isUnread
                              ? const Color(0xFF0D9488)
                              : const Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),

                  // Row 2: Subtle Order ID & Status tag
                  Row(
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
                      const SizedBox(width: 6),
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
                      if (conv.currentProductName != null) ...[
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '• ${conv.currentProductName}',
                            style: GoogleFonts.inter(
                              fontSize: 10.5,
                              color: const Color(0xFF94A3B8),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
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
