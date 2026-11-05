import '../../../client_portal/presentation/widgets/request_upg_modal.dart';
import '../../../orders/presentation/providers/orders_provider.dart';
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
import '../../../../core/widgets/user_avatar_widget.dart';
import '../providers/pipeline_chat_provider.dart';
import 'conversation_list_modal.dart';
import 'chat_user_profile_card_modal.dart';
import 'dart:async';
import 'package:file_picker/file_picker.dart';
import '../../../../core/services/voice_recorder/voice_recorder.dart';
import 'voice_note_player_widget.dart';
import 'file_attachment_bubble_widget.dart';
import '../../../../core/widgets/notification_sound_settings_modal.dart';

class ChatPickedAttachment {
  final Uint8List bytes;
  final String fileName;
  final int fileSize;
  final bool isImage;
  final String? mimeType;

  const ChatPickedAttachment({
    required this.bytes,
    required this.fileName,
    required this.fileSize,
    required this.isImage,
    this.mimeType,
  });
}

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

  final Map<String, GlobalKey> _messageKeys = {};
  String? _highlightedMessageId;
  Timer? _highlightTimer;

  GlobalKey _getKeyForMessage(String messageId) {
    return _messageKeys.putIfAbsent(messageId, () => GlobalKey());
  }

  bool _showMentionSuggestions = false;
  String _mentionQuery = '';
  int _mentionStartIndex = -1;

  late final VoiceNoteRecorder _voiceRecorder;
  bool _isRecordingVoice = false;
  Duration _recordingDuration = Duration.zero;
  StreamSubscription? _recordingSub;
  ChatPickedAttachment? _stagedAttachment;
  OrderConversationMessageEntity? _replyingToMessage;
  int _prevMessageCount = 0;
  String? _prevLastMessageId;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _shimmerAnimation = Tween<double>(begin: 0.35, end: 0.85).animate(
      CurvedAnimation(parent: _shimmerController, curve: Curves.easeInOut),
    );

    _msgController.addListener(_onTextChanged);
    _voiceRecorder = VoiceNoteRecorder();
    _recordingSub = _voiceRecorder.durationStream.listen((dur) {
      if (mounted) setState(() => _recordingDuration = dur);
    });

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
    _highlightTimer?.cancel();
    _recordingSub?.cancel();
    _voiceRecorder.dispose();
    _shimmerController.dispose();
    _msgController.removeListener(_onTextChanged);
    _msgController.dispose();
    _scrollController.dispose();
    _msgFocusNode.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final text = _msgController.text;
    final conv = ref.read(pipelineChatProvider).activeConversation;
    if (conv != null) {
      ref.read(pipelineChatProvider.notifier).broadcastUserPresence(
        conversationId: conv.id,
        status: text.trim().isNotEmpty ? 'typing' : 'idle',
      );
    }

    final selection = _msgController.selection;
    if (selection.baseOffset < 0) {
      if (_showMentionSuggestions) {
        setState(() => _showMentionSuggestions = false);
      }
      return;
    }

    final cursorPos = selection.baseOffset;
    final textBeforeCursor = text.substring(0, cursorPos);
    final lastAt = textBeforeCursor.lastIndexOf('@');

    if (lastAt >= 0) {
      final queryCandidate = textBeforeCursor.substring(lastAt + 1);
      if (!queryCandidate.contains('\n') && queryCandidate.length <= 25) {
        final isAtStartOrPrecededBySpace = lastAt == 0 || textBeforeCursor[lastAt - 1] == ' ';
        if (isAtStartOrPrecededBySpace) {
          if (!_showMentionSuggestions || _mentionQuery != queryCandidate || _mentionStartIndex != lastAt) {
            setState(() {
              _showMentionSuggestions = true;
              _mentionQuery = queryCandidate.toLowerCase();
              _mentionStartIndex = lastAt;
            });
          }
          return;
        }
      }
    }

    if (_showMentionSuggestions) {
      setState(() => _showMentionSuggestions = false);
    } else {
      if (mounted) setState(() {});
    }
  }

  void _selectMentionSuggestion(String tagToInsert) {
    final text = _msgController.text;
    final cursorPos = _msgController.selection.baseOffset;
    final start = _mentionStartIndex >= 0 ? _mentionStartIndex : text.length;
    final before = text.substring(0, start);
    final after = (cursorPos >= 0 && cursorPos <= text.length)
        ? text.substring(cursorPos)
        : '';

    final cleanTag = tagToInsert.startsWith('@') ? tagToInsert : '@$tagToInsert';
    final newText = '$before$cleanTag $after';
    final newCursor = start + cleanTag.length + 1;

    _msgController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newCursor),
    );

    setState(() {
      _showMentionSuggestions = false;
      _mentionStartIndex = -1;
      _mentionQuery = '';
    });
    _msgFocusNode.requestFocus();
  }

  List<Map<String, dynamic>> _getAvailableMentionProfiles(OrderConversationEntity? conv) {
    final list = <Map<String, dynamic>>[];

    // 1. Closer
    if (conv?.closerName != null && conv!.closerName!.trim().isNotEmpty) {
      list.add({
        'name': conv.closerName!.trim(),
        'role': 'Telesales Closer',
        'tag': '@${conv.closerName!.trim()}',
        'color': const Color(0xFF8B5CF6),
        'icon': Icons.headset_mic_rounded,
        'avatarUrl': conv.closerAvatarUrl,
      });
    } else {
      list.add({
        'name': 'Closer Team',
        'role': 'Assigned Telesales Closer',
        'tag': '@Closer',
        'color': const Color(0xFF8B5CF6),
        'icon': Icons.headset_mic_rounded,
        'avatarUrl': null,
      });
    }

    // 2. DC Operations & Operational Staff
    final dcTitle = conv?.distributionCenterName ?? 'Central Command DC';
    list.add({
      'name': '$dcTitle Operations',
      'role': 'DC Command & Dispatch Desk',
      'tag': '@Operations',
      'color': const Color(0xFF6366F1),
      'icon': Icons.corporate_fare_rounded,
      'avatarUrl': null,
    });
    list.add({
      'name': 'DC Fleet Dispatcher',
      'role': 'Fleet Routing & Dispatch Officer',
      'tag': '@Dispatch',
      'color': const Color(0xFF6366F1),
      'icon': Icons.alt_route_rounded,
      'avatarUrl': null,
    });
    list.add({
      'name': 'DC Warehouse / Stock Desk',
      'role': 'DC Inventory & Stock Fulfillment',
      'tag': '@Warehouse',
      'color': const Color(0xFF6366F1),
      'icon': Icons.inventory_2_rounded,
      'avatarUrl': null,
    });
    list.add({
      'name': 'DC Station Accountant',
      'role': 'DC Finance & Remittance Desk',
      'tag': '@Finance',
      'color': const Color(0xFF6366F1),
      'icon': Icons.account_balance_wallet_rounded,
      'avatarUrl': null,
    });

    // 3. Courier Rider
    if (conv?.deliveryAgentName != null && conv!.deliveryAgentName!.trim().isNotEmpty) {
      list.add({
        'name': conv.deliveryAgentName!.trim(),
        'role': 'Delivery Agent',
        'tag': '@${conv.deliveryAgentName!.trim()}',
        'color': const Color(0xFFF59E0B),
        'icon': Icons.two_wheeler_rounded,
        'avatarUrl': null,
      });
    } else {
      list.add({
        'name': 'Field Courier',
        'role': 'Assigned Rider',
        'tag': '@Rider',
        'color': const Color(0xFFF59E0B),
        'icon': Icons.two_wheeler_rounded,
        'avatarUrl': null,
      });
    }

    // 4. Digital Marketer
    if (conv?.marketerName != null && conv!.marketerName!.trim().isNotEmpty) {
      list.add({
        'name': conv.marketerName!.trim(),
        'role': 'Digital Marketer',
        'tag': '@${conv.marketerName!.trim()}',
        'color': const Color(0xFF10B981),
        'icon': Icons.campaign_rounded,
        'avatarUrl': conv.marketerAvatarUrl,
      });
    }

    // 5. Merchant Brand Owner
    list.add({
      'name': conv?.clientName ?? 'Merchant Owner',
      'role': 'Merchant Brand',
      'tag': '@Client',
      'color': const Color(0xFF0D9488),
      'icon': Icons.storefront_rounded,
      'avatarUrl': null,
    });

    // 6. Customer / Receiver
    list.add({
      'name': widget.customerName,
      'role': 'Recipient Customer',
      'tag': '@${widget.customerName}',
      'color': const Color(0xFF0284C7),
      'icon': Icons.person_rounded,
      'avatarUrl': null,
    });

    return list;
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

  void _scrollToBottom({bool animate = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      final target = _scrollController.position.maxScrollExtent;
      if (animate) {
        _scrollController.animateTo(
          target,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
        );
      } else {
        _scrollController.jumpTo(target);
      }
    });
  }

  Widget _buildMessageContent(
    OrderConversationMessageEntity msg, {
    required bool isMyMessage,
    required bool isDark,
    required OrderConversationEntity? conv,
  }) {
    if (msg.isVoiceNote && msg.voiceNoteUrl != null) {
      return VoiceNotePlayerWidget(
        audioUrl: msg.voiceNoteUrl!,
        durationSeconds: msg.voiceNoteDuration,
        isMyMessage: isMyMessage,
        isDark: isDark,
      );
    }
    if (msg.isFileAttachment || msg.isImage) {
      return FileAttachmentBubbleWidget(
        msg: msg,
        isMyMessage: isMyMessage,
        isDark: isDark,
      );
    }
    return _buildMessageBodyWithInteractiveMentions(
      msg.messageBody,
      isMyMessage: isMyMessage,
      isDark: isDark,
      conv: conv,
    );
  }

  Future<void> _startVoiceRecording() async {
    final started = await _voiceRecorder.start();
    if (started) {
      if (!_shimmerController.isAnimating) {
        _shimmerController.repeat(reverse: true);
      }
      setState(() {
        _isRecordingVoice = true;
        _recordingDuration = Duration.zero;
      });

      final conv = ref.read(pipelineChatProvider).activeConversation;
      if (conv != null) {
        ref.read(pipelineChatProvider.notifier).broadcastUserPresence(
          conversationId: conv.id,
          status: 'recording_voice_note',
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Microphone access is required to record voice notes.',
              style: GoogleFonts.inter(color: Colors.white),
            ),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  Future<void> _cancelVoiceRecording() async {
    await _voiceRecorder.cancel();
    if (_shimmerController.isAnimating) {
      _shimmerController.stop();
    }
    if (mounted) {
      setState(() {
        _isRecordingVoice = false;
        _recordingDuration = Duration.zero;
      });
    }

    final conv = ref.read(pipelineChatProvider).activeConversation;
    if (conv != null) {
      ref.read(pipelineChatProvider.notifier).broadcastUserPresence(
        conversationId: conv.id,
        status: 'idle',
      );
    }
  }

  Future<void> _sendVoiceRecording() async {
    final result = await _voiceRecorder.stop();
    if (_shimmerController.isAnimating) {
      _shimmerController.stop();
    }
    if (mounted) {
      setState(() {
        _isRecordingVoice = false;
        _recordingDuration = Duration.zero;
      });
    }

    final conv = ref.read(pipelineChatProvider).activeConversation;
    if (conv != null) {
      ref.read(pipelineChatProvider.notifier).broadcastUserPresence(
        conversationId: conv.id,
        status: 'idle',
      );
    }

    if (result != null && result.bytes.isNotEmpty) {
      final ok = await ref.read(pipelineChatProvider.notifier).sendVoiceNote(
            audioBytes: result.bytes,
            duration: result.duration,
            mimeType: result.mimeType,
            fileExtension: result.fileExtension,
          );
      if (ok) {
        Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
      }
    }
  }

  Future<void> _pickMediaAttachment({required bool isImageOnly}) async {
    try {
      final result = await FilePickerPlatform.instance.pickFiles(
        type: isImageOnly ? FileType.custom : FileType.any,
        allowedExtensions: isImageOnly ? ['png', 'jpg', 'jpeg', 'webp', 'gif'] : null,
      );

      if (result.isNotEmpty) {
        final file = result.first;
        final bytes = await file.readAsBytes();
        if (bytes.isNotEmpty) {
          final ext = file.extension?.toLowerCase() ?? '';
          final isImg = isImageOnly || ['png', 'jpg', 'jpeg', 'webp', 'gif'].contains(ext);
          String? mime;
          if (isImg) {
            mime = ext == 'png' ? 'image/png' : 'image/jpeg';
          } else if (ext == 'pdf') {
            mime = 'application/pdf';
          }

          setState(() {
            _stagedAttachment = ChatPickedAttachment(
              bytes: bytes,
              fileName: file.name,
              fileSize: bytes.length,
              isImage: isImg,
              mimeType: mime,
            );
          });
          _msgFocusNode.requestFocus();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to select file: $e', style: GoogleFonts.inter(color: Colors.white)),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  Future<void> _handleSendMessage() async {
    final Map<String, dynamic>? replyMeta = _replyingToMessage != null
        ? {
            'reply_to_id': _replyingToMessage!.id,
            'reply_to_sender': _replyingToMessage!.senderName,
            'reply_to_body': _replyingToMessage!.messageBody,
            'reply_to_type': _replyingToMessage!.messageType.name,
          }
        : null;

    if (_stagedAttachment != null) {
      final attachment = _stagedAttachment!;
      final caption = _msgController.text.trim();
      _msgController.clear();
      setState(() {
        _stagedAttachment = null;
        _replyingToMessage = null;
        _showMentionSuggestions = false;
      });

      final ok = await ref.read(pipelineChatProvider.notifier).sendFileAttachment(
            fileBytes: attachment.bytes,
            fileName: attachment.fileName,
            mimeType: attachment.mimeType,
            caption: caption.isNotEmpty ? caption : null,
            isImage: attachment.isImage,
            metadata: replyMeta,
          );
      if (ok) {
        Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
      }
      return;
    }

    final text = _msgController.text.trim();
    if (text.isEmpty) return;

    _msgController.clear();
    setState(() {
      _showMentionSuggestions = false;
      _replyingToMessage = null;
    });
    final ok = await ref.read(pipelineChatProvider.notifier).sendTextMessage(text, metadata: replyMeta);
    if (ok) {
      Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
    }
  }

  void _appendMentionTag(String tag) {
    _selectMentionSuggestion(tag);
  }

  Widget _buildInitialsDp(String initials, Color bgColor) {
    return Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        color: bgColor,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          initials,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 7.5,
            fontWeight: FontWeight.w700,
            height: 1.0,
          ),
        ),
      ),
    );
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
      fontSize: 14.2,
      height: 1.38,
      color: isDark ? const Color(0xFFE9EDEF) : const Color(0xFF111B21),
      fontWeight: FontWeight.w400,
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
      final rawName = tag.substring(1).trim();

      // Look up participant profile from available profiles
      final profiles = _getAvailableMentionProfiles(conv);
      Map<String, dynamic>? matchedProfile;
      final rawLower = rawName.toLowerCase();

      for (final p in profiles) {
        final pTag = (p['tag'] as String).substring(1).trim().toLowerCase();
        final pName = (p['name'] as String).trim().toLowerCase();
        if (pTag == rawLower || pName == rawLower || pName.contains(rawLower) || rawLower.contains(pName)) {
          matchedProfile = p;
          break;
        }
      }

      final displayName = matchedProfile != null ? (matchedProfile['name'] as String) : rawName;
      final avatarUrl = matchedProfile?['avatarUrl'] as String?;

      // Calculate initials (e.g. "Oladele Omowaye" -> "OO")
      final nameParts = displayName.trim().split(RegExp(r'\s+'));
      final initials = nameParts.length >= 2
          ? '\${nameParts[0][0]}\${nameParts[1][0]}'.toUpperCase()
          : (nameParts.isNotEmpty && nameParts[0].isNotEmpty ? nameParts[0][0].toUpperCase() : '@');

      // WhatsApp deep green colors
      final deepGreen = isDark ? const Color(0xFF25D366) : const Color(0xFF008069);
      final pillBg = isDark
          ? const Color(0xFF005C4B).withOpacity(0.35)
          : const Color(0xFF008069).withOpacity(0.09);
      final pillBorder = isDark
          ? const Color(0xFF00A884).withOpacity(0.35)
          : const Color(0xFF008069).withOpacity(0.24);

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
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.fromLTRB(2.5, 1.5, 6, 1.5),
                decoration: BoxDecoration(
                  color: pillBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: pillBorder,
                    width: 0.8,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Rounded DP
                    if (avatarUrl != null && avatarUrl.isNotEmpty)
                      ClipOval(
                        child: Image.network(
                          avatarUrl,
                          width: 16,
                          height: 16,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _buildInitialsDp(initials, deepGreen),
                        ),
                      )
                    else
                      _buildInitialsDp(initials, deepGreen),
                    const SizedBox(width: 4),
                    // Bold Name in Deep Green Color
                    Text(
                      '@$displayName',
                      style: GoogleFonts.inter(
                        fontSize: 12.2,
                        fontWeight: FontWeight.w700,
                        color: deepGreen,
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

    // Signature WhatsApp Wallpaper Palette
    final chatBg = isDark ? const Color(0xFF0B141A) : const Color(0xFFEFEAE2);

    // Defense: Retrieve order messages from state.messages (if active matches) or from per-order cache
    final orderMessages = (conv?.orderId == widget.orderId && chatState.messages.isNotEmpty)
        ? chatState.messages
        : chatState.getMessagesForOrder(widget.orderId);

    // Auto-scroll to bottom immediately whenever new incoming or outgoing messages are dropped
    if (orderMessages.isNotEmpty) {
      final lastId = orderMessages.last.id;
      if (orderMessages.length != _prevMessageCount || lastId != _prevLastMessageId) {
        final isFirst = _prevMessageCount == 0;
        _prevMessageCount = orderMessages.length;
        _prevLastMessageId = lastId;

        _scrollToBottom(animate: !isFirst);
      }
    }

    return Container(
      width: double.infinity,
      height: double.infinity,
      color: chatBg,
      child: Column(
        children: [
          // WhatsApp Header / App Bar
          _buildHeader(context, conv, isDark),

          // Pinned Order Info & Active Participants Bar (WhatsApp Group Context)
          if (conv != null) _buildOrderInfoBanner(context, conv, isDark),
          if (conv != null) _buildParticipantsBar(context, conv, isDark),

            // Chat Messages Body with WhatsApp Doodle Wallpaper
            Expanded(
              child: CustomPaint(
                painter: WhatsAppWallpaperPainter(isDark: isDark),
                child: (orderMessages.isEmpty && chatState.isLoading)
                    ? _buildSkeletalChatMessages(isDark)
                    : chatState.errorMessage != null && conv == null && orderMessages.isEmpty
                        ? _buildAccessRestrictedState(chatState.errorMessage!, isDark)
                        : orderMessages.isEmpty
                            ? _buildEmptyState(isDark)
                            : ListView.builder(
                                controller: _scrollController,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                itemCount: orderMessages.length,
                                itemBuilder: (context, index) {
                                  final msg = orderMessages[index];
                                  final bool showDateSeparator = (index == 0) ||
                                      (msg.createdAt.year != orderMessages[index - 1].createdAt.year ||
                                          msg.createdAt.month != orderMessages[index - 1].createdAt.month ||
                                          msg.createdAt.day != orderMessages[index - 1].createdAt.day);

                                  final messageWidget = _buildMessageItem(msg, isDark, conv);

                                  if (showDateSeparator) {
                                    return Column(
                                      key: _getKeyForMessage(msg.id),
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        _buildDateSeparator(msg.createdAt, isDark),
                                        messageWidget,
                                      ],
                                    );
                                  }
                                  return KeyedSubtree(
                                    key: _getKeyForMessage(msg.id),
                                    child: messageWidget,
                                  );
                                },
                              ),
              ),
            ),

            // WhatsApp Floating Two-Piece Input Composer
            if (conv != null)
              _buildInputFooter(context, isDark, chatState.isSending, conv),
          ],
        ),
      );
  }

  Widget _buildSkeletalChatMessages(bool isDark) {
    if (!_shimmerController.isAnimating) {
      _shimmerController.repeat(reverse: true);
    }
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
                    color: const Color(0xFF00A884).withOpacity(0.35 * opacity),
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
    final receiverName = (conv?.customerName != null && conv!.customerName.trim().isNotEmpty)
        ? conv.customerName.trim()
        : widget.customerName.trim();
    final receiverPhone = widget.customerPhone ?? conv?.customerPhone;

    // Classic WhatsApp App Bar Colors: Deep Teal-Green in Light, Dark Teal-Slate in Dark
    final headerBg = isDark ? const Color(0xFF1F2C34) : const Color(0xFF008069);
    final presence = ref.watch(pipelineChatProvider).activePresence;
    final isPresenceActive = presence != null && presence.isActive;

    return Container(
      color: headerBg,
      padding: const EdgeInsets.fromLTRB(4, 6, 8, 8),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            if (widget.showBackButton)
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white, size: 22),
                tooltip: 'Back to Conversations',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                onPressed: widget.onBack ?? () => Navigator.of(context).pop(),
              ),

            // Receiver Avatar with online indicator
            Stack(
              children: [
                UserAvatarWidget(
                  fullName: receiverName,
                  radius: 19,
                  backgroundColor: isDark ? const Color(0xFF2A3942) : Colors.white.withOpacity(0.2),
                  textColor: Colors.white,
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: const Color(0xFF25D366), // WhatsApp online beacon
                      shape: BoxShape.circle,
                      border: Border.all(color: headerBg, width: 1.8),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 10),

            // Contact / Group Info
            Expanded(
              child: InkWell(
                onTap: () {
                  if (conv != null) {
                    _showOrderQuickDetailsModal(context, conv, isDark);
                  }
                },
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Customer: $receiverName',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 1.5),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.orderNumber,
                          style: GoogleFonts.inter(
                            fontSize: 11.5,
                            color: Colors.white.withOpacity(0.9),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (isPresenceActive)
                          Flexible(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text(' • ', style: TextStyle(color: Colors.white70, fontSize: 11)),
                                Icon(
                                  presence.isRecording ? Icons.mic_rounded : Icons.edit_note_rounded,
                                  size: 13,
                                  color: presence.isRecording ? const Color(0xFFFCA5A5) : const Color(0xFF86EFAC),
                                ),
                                const SizedBox(width: 3),
                                Flexible(
                                  child: Text(
                                    presence.displayLabel,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.inter(
                                      fontSize: 11.5,
                                      fontStyle: FontStyle.italic,
                                      fontWeight: FontWeight.w600,
                                      color: presence.isRecording ? const Color(0xFFFCA5A5) : const Color(0xFF86EFAC),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          Flexible(
                            child: Text(
                              ' • ${_getWhatsAppSubtitle(conv)}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontSize: 11.5,
                                color: Colors.white.withOpacity(0.85),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Direct Call Action
            if (receiverPhone != null && receiverPhone.trim().isNotEmpty)
              IconButton(
                icon: const Icon(Icons.call_rounded, color: Colors.white, size: 20),
                tooltip: 'Call $receiverName',
                padding: const EdgeInsets.all(6),
                constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
                onPressed: () => _callNumber(context, receiverPhone),
              ),

            // WhatsApp More Menu
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.white, size: 21),
              tooltip: 'More options',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              color: isDark ? const Color(0xFF233138) : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              onSelected: (val) {
                if (val == 'info' && conv != null) {
                  _showOrderQuickDetailsModal(context, conv, isDark);
                } else if (val == 'close') {
                  (widget.onClose ?? () => Navigator.of(context).pop())();
                } else if (val == 'sounds') {
                  NotificationSoundSettingsModal.show(context);
                }
              },
              itemBuilder: (ctx) => [
                PopupMenuItem(
                  value: 'info',
                  child: Row(
                    children: [
                      Icon(Icons.info_outline_rounded, size: 18, color: isDark ? Colors.white : const Color(0xFF111B21)),
                      const SizedBox(width: 10),
                      Text('Order Details', style: GoogleFonts.inter(fontSize: 13, color: isDark ? Colors.white : const Color(0xFF111B21))),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'sounds',
                  child: Row(
                    children: [
                      Icon(Icons.music_note_rounded, size: 18, color: isDark ? Colors.white : const Color(0xFF111B21)),
                      const SizedBox(width: 10),
                      Text('Sound Preferences', style: GoogleFonts.inter(fontSize: 13, color: isDark ? Colors.white : const Color(0xFF111B21))),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'close',
                  child: Row(
                    children: [
                      Icon(Icons.close_rounded, size: 18, color: isDark ? Colors.white : const Color(0xFF111B21)),
                      const SizedBox(width: 10),
                      Text('Close Chat', style: GoogleFonts.inter(fontSize: 13, color: isDark ? Colors.white : const Color(0xFF111B21))),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderInfoBanner(BuildContext context, OrderConversationEntity conv, bool isDark) {
    final currency = NumberFormat.currency(locale: 'en_NG', symbol: '₦', decimalDigits: 0);
    final authUser = ref.watch(authProvider).user;
    final isCloser = authUser?.isCloser == true;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF182229) : const Color(0xFFF0F2F5),
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF222E35) : const Color(0xFFE9EDEF),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          // Current product package & total price
          Expanded(
            child: Row(
              children: [
                const Icon(Icons.inventory_2_outlined, size: 15, color: Color(0xFF0D9488)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${conv.currentProductName ?? 'Product'} (${conv.currentPackageName ?? 'Standard'})',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                    ),
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

          // UPG Request Button - strictly for Closers ONLY
          if (isCloser) ...[
            const SizedBox(width: 10),
            InkWell(
              onTap: () {
                final orders = ref.read(ordersProvider).orders;
                final existingOrder = orders.where((o) => o.id == widget.orderId || o.orderNumber == widget.orderNumber).firstOrNull;
                final currentOrder = existingOrder ??
                    OrderEntity(
                      id: widget.orderId,
                      orderNumber: widget.orderNumber,
                      customerName: conv.customerName,
                      customerPhone: conv.customerPhone ?? '',
                      deliveryAddress: 'Customer Delivery Address',
                      deliveryCity: 'City',
                      deliveryState: 'State',
                      productName: conv.currentProductName ?? 'Current Product',
                      packageDealName: conv.currentPackageName,
                      quantity: 1,
                      basePrice: conv.currentTotalAmount,
                      upsellAmount: 0.0,
                      totalAmount: conv.currentTotalAmount,
                      paymentType: 'pay_on_delivery',
                      paymentStatus: 'pending',
                      status: 'booked',
                      clientName: conv.clientName,
                      clientCompany: conv.clientName,
                      createdAt: DateTime.now(),
                    );

                RequestUpgModal.show(
                  context,
                  order: currentOrder,
                  closerId: authUser?.id ?? '',
                  closerName: authUser?.fullName ?? 'Closer',
                  closerCode: authUser?.closerCode ?? 'CLS',
                  isSupervisor: authUser?.isCloserSupervisor == true,
                );
              },
              borderRadius: BorderRadius.circular(6),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
                  ),
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF8B5CF6).withValues(alpha: 0.35),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.bolt_rounded, size: 14, color: Colors.amberAccent),
                    const SizedBox(width: 4),
                    Text(
                      'UPG',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildParticipantsBar(BuildContext context, OrderConversationEntity conv, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF182229) : const Color(0xFFF7F8FA),
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF222E35) : const Color(0xFFE9EDEF),
            width: 1,
          ),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.hub_rounded, size: 12, color: Color(0xFF6366F1)),
                const SizedBox(width: 4),
                Text(
                  'ACTIVE PIPELINE:',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 8),

            // 1. DC Operations Chip (Always Connected)
            _buildParticipantChip(
              icon: Icons.corporate_fare_rounded,
              label: 'DC Operations',
              color: const Color(0xFF6366F1),
              isDark: isDark,
              hasBeacon: true,
              onTap: () => _appendMentionTag('@Operations'),
              tooltip: 'DC Operations Hub is actively in this room. Tap to tag @Operations',
            ),
            const SizedBox(width: 6),

            // 2. Rider Chip
            if (conv.deliveryAgentName != null && conv.deliveryAgentName!.trim().isNotEmpty) ...[
              _buildParticipantChip(
                icon: Icons.two_wheeler_rounded,
                label: 'Rider: ${conv.deliveryAgentName!.trim()}',
                color: const Color(0xFFF59E0B),
                isDark: isDark,
                onTap: () => _appendMentionTag('@${conv.deliveryAgentName!.trim()}'),
                tooltip: 'Tap to tag rider @${conv.deliveryAgentName!.trim()}',
              ),
              const SizedBox(width: 6),
            ] else ...[
              _buildParticipantChip(
                icon: Icons.two_wheeler_rounded,
                label: 'Field Courier',
                color: const Color(0xFFF59E0B),
                isDark: isDark,
                onTap: () => _appendMentionTag('@Rider'),
                tooltip: 'Tap to tag @Rider',
              ),
              const SizedBox(width: 6),
            ],

            // 3. Closer Chip
            if (conv.closerName != null && conv.closerName!.trim().isNotEmpty) ...[
              _buildParticipantChip(
                icon: Icons.headset_mic_rounded,
                label: 'Closer: ${conv.closerName!.trim()}',
                color: const Color(0xFF8B5CF6),
                isDark: isDark,
                onTap: () => _appendMentionTag('@${conv.closerName!.trim()}'),
                tooltip: 'Tap to tag closer @${conv.closerName!.trim()}',
              ),
              const SizedBox(width: 6),
            ],

            // 4. Merchant Brand Chip
            _buildParticipantChip(
              icon: Icons.storefront_rounded,
              label: 'Merchant: ${conv.clientName.trim()}',
              color: const Color(0xFF0D9488),
              isDark: isDark,
              onTap: () => _appendMentionTag('@Client'),
              tooltip: 'Tap to tag @Client (${conv.clientName.trim()})',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildParticipantChip({
    required IconData icon,
    required String label,
    required Color color,
    required bool isDark,
    bool hasBeacon = false,
    required VoidCallback onTap,
    required String tooltip,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
          decoration: BoxDecoration(
            color: color.withValues(alpha: isDark ? 0.16 : 0.09),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: color.withValues(alpha: isDark ? 0.35 : 0.25),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (hasBeacon) ...[
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: Color(0xFF10B981),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
              ],
              Icon(icon, size: 12, color: color),
              const SizedBox(width: 4),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMessageItem(OrderConversationMessageEntity msg, bool isDark, OrderConversationEntity? conv) {
    if (msg.isSystem || msg.isStatusEvent) {
      return _buildSystemMilestone(msg, isDark, conv);
    }

    final authUser = ref.watch(authProvider).user;
    final currentUserId = authUser?.id;
    final isMyMessage = (currentUserId != null && msg.senderId == currentUserId);

    final isMarketer = msg.senderRole == ChatSenderRole.marketer;
    final isCloser = msg.senderRole == ChatSenderRole.closer;
    final isClient = msg.senderRole == ChatSenderRole.client;
    final isDc = msg.senderRole == ChatSenderRole.dcManager;
    final isRider = msg.senderRole == ChatSenderRole.deliveryAgent;

    Color roleColor = const Color(0xFF536471);
    String roleLabel = 'Member';
    if (isMarketer) {
      roleColor = const Color(0xFF10B981);
      roleLabel = 'Marketer';
    } else if (isCloser) {
      roleColor = const Color(0xFF8B5CF6);
      roleLabel = 'Closer';
    } else if (isClient) {
      roleColor = const Color(0xFF0D9488);
      roleLabel = 'Merchant';
    } else if (isDc) {
      roleColor = const Color(0xFF2563EB);
      roleLabel = 'DC Operations';
    } else if (isRider) {
      roleColor = const Color(0xFFD97706);
      roleLabel = 'Rider';
    }

    final timeStr = _formatMessageTime(msg.createdAt);
    final reactions = _getMessageReactions(msg);
    final isHighlighted = _highlightedMessageId == msg.id;

    if (isMyMessage) {
      // Outgoing WhatsApp Bubble (Green #D9FDD3 in light, #005C4B in dark)
      final bubbleBg = isHighlighted
          ? (isDark ? const Color(0xFF007A65) : const Color(0xFFA7EBB0))
          : (isDark ? const Color(0xFF005C4B) : const Color(0xFFD9FDD3));

      return Dismissible(
        key: ValueKey('swipe_reply_\${msg.id}'),
        direction: DismissDirection.startToEnd,
        dismissThresholds: const {
          DismissDirection.startToEnd: 0.16,
        },
        confirmDismiss: (direction) async {
          HapticFeedback.lightImpact();
          setState(() {
            _replyingToMessage = msg;
          });
          _msgFocusNode.requestFocus();
          return false;
        },
        background: Container(
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.only(left: 14),
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1F2C34) : Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.12),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: const Icon(
              Icons.reply_rounded,
              color: Color(0xFF00A884),
              size: 19,
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const SizedBox(width: 48), // WhatsApp standard opposite indent
              Flexible(
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    GestureDetector(
                      onLongPress: () => _showReactionPopup(context, msg, isDark),
                      onSecondaryTap: () => _showReactionPopup(context, msg, isDark),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                        margin: EdgeInsets.only(bottom: reactions.isNotEmpty ? 8 : 0),
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.80,
                        ),
                        padding: const EdgeInsets.fromLTRB(10, 7, 8, 5),
                        decoration: BoxDecoration(
                          color: bubbleBg,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(12),
                            topRight: Radius.circular(12),
                            bottomLeft: Radius.circular(12),
                            bottomRight: Radius.circular(2),
                          ),
                          boxShadow: isHighlighted
                              ? [
                                  BoxShadow(
                                    color: const Color(0xFF00A884).withOpacity(0.55),
                                    blurRadius: 10,
                                    spreadRadius: 2,
                                  ),
                                ]
                              : const [
                                  BoxShadow(
                                    color: Color(0x1F000000),
                                    offset: Offset(0, 1),
                                    blurRadius: 1,
                                  ),
                                ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (msg.metadata['reply_to_sender'] != null)
                              _buildQuotedReplyBox(msg, isDark, true),
                            _buildMessageContent(
                              msg,
                              isMyMessage: true,
                              isDark: isDark,
                              conv: conv,
                            ),
                            const SizedBox(height: 2),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Text(
                                  timeStr,
                                  style: GoogleFonts.inter(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w400,
                                    color: isDark ? const Color(0xFF8696A0) : const Color(0xFF667781),
                                  ),
                                ),
                                const SizedBox(width: 3),
                                if (msg.isPending) ...[
                                  Tooltip(
                                    message: 'Waiting to send • Will sync when online',
                                    child: Icon(
                                      Icons.access_time_rounded,
                                      size: 13,
                                      color: isDark ? const Color(0xFF8696A0) : const Color(0xFF667781),
                                    ),
                                  ),
                                ] else if (msg.isFailed) ...[
                                  Tooltip(
                                    message: 'Failed to send • Tap to retry',
                                    child: InkWell(
                                      onTap: () => ref.read(pipelineChatProvider.notifier).retryOutboxMessage(msg.clientMessageId ?? msg.id),
                                      child: const Icon(
                                        Icons.error_outline_rounded,
                                        size: 14,
                                        color: Color(0xFFEF4444),
                                      ),
                                    ),
                                  ),
                                ] else ...[
                                  Icon(
                                    Icons.done_all_rounded,
                                    size: 15,
                                    color: (msg.readByClient || msg.readByDc || msg.readByRider)
                                        ? const Color(0xFF53BDEB) // WhatsApp double blue checkmarks
                                        : (isDark ? const Color(0xFF8696A0) : const Color(0xFF667781)),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (reactions.isNotEmpty)
                      Positioned(
                        bottom: -4,
                        left: 8,
                        child: _buildReactionBadge(msg, isDark, true),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

    // Incoming WhatsApp Bubble (White in light, #202C33 in dark)
    final bubbleBg = isHighlighted
        ? (isDark ? const Color(0xFF2A3942) : const Color(0xFFE2F7E4))
        : (isDark ? const Color(0xFF202C33) : Colors.white);

    return Dismissible(
      key: ValueKey('swipe_reply_${msg.id}'),
      direction: DismissDirection.startToEnd,
      dismissThresholds: const {
        DismissDirection.startToEnd: 0.16,
      },
      confirmDismiss: (direction) async {
        HapticFeedback.lightImpact();
        setState(() {
          _replyingToMessage = msg;
        });
        _msgFocusNode.requestFocus();
        return false;
      },
      background: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 14),
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1F2C34) : Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.12),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: const Icon(
            Icons.reply_rounded,
            color: Color(0xFF00A884),
            size: 19,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          // WhatsApp Group Member Avatar
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
            child: Padding(
              padding: const EdgeInsets.only(top: 2, right: 6),
              child: UserAvatarWidget(
                avatarUrl: msg.senderAvatarUrl,
                fullName: msg.senderName,
                radius: 14,
                backgroundColor: roleColor.withOpacity(0.18),
                textColor: roleColor,
              ),
            ),
          ),
          Flexible(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                GestureDetector(
                  onLongPress: () => _showReactionPopup(context, msg, isDark),
                  onSecondaryTap: () => _showReactionPopup(context, msg, isDark),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    margin: EdgeInsets.only(bottom: reactions.isNotEmpty ? 8 : 0),
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.80,
                    ),
                    padding: const EdgeInsets.fromLTRB(10, 7, 8, 5),
                    decoration: BoxDecoration(
                      color: bubbleBg,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(2),
                        topRight: Radius.circular(12),
                        bottomLeft: Radius.circular(12),
                        bottomRight: Radius.circular(12),
                      ),
                      boxShadow: isHighlighted
                          ? [
                              BoxShadow(
                                color: const Color(0xFF00A884).withOpacity(0.55),
                                blurRadius: 10,
                                spreadRadius: 2,
                              ),
                            ]
                          : const [
                              BoxShadow(
                                color: Color(0x1F000000),
                                offset: Offset(0, 1),
                                blurRadius: 1,
                              ),
                            ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // WhatsApp Group Sender Title
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
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 3),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
                                  child: Text(
                                    msg.senderName,
                                    style: GoogleFonts.inter(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700,
                                      color: roleColor,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 5),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 4.5, vertical: 0.8),
                                  decoration: BoxDecoration(
                                    color: roleColor.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    roleLabel,
                                    style: GoogleFonts.inter(
                                      fontSize: 8.5,
                                      fontWeight: FontWeight.w700,
                                      color: roleColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        if (msg.metadata['reply_to_sender'] != null)
                          _buildQuotedReplyBox(msg, isDark, false),

                        // Message Content
                        _buildMessageContent(
                          msg,
                          isMyMessage: false,
                          isDark: isDark,
                          conv: conv,
                        ),

                        // Timestamp
                        Align(
                          alignment: Alignment.bottomRight,
                          child: Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              timeStr,
                              style: GoogleFonts.inter(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w400,
                                color: isDark ? const Color(0xFF8696A0) : const Color(0xFF667781),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (reactions.isNotEmpty)
                  Positioned(
                    bottom: -4,
                    right: 8,
                    child: _buildReactionBadge(msg, isDark, false),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 48), // Indent on opposite side
        ],
      ),
    ),
  );
}

  Widget _buildQuotedReplyBox(
    OrderConversationMessageEntity msg,
    bool isDark,
    bool isMyMessage,
  ) {
    final replyToId = msg.metadata['reply_to_id']?.toString();
    final replySender = msg.metadata['reply_to_sender']?.toString();
    final replyBody = msg.metadata['reply_to_body']?.toString();
    final replyType = msg.metadata['reply_to_type']?.toString();

    if (replySender == null || replySender.isEmpty) return const SizedBox.shrink();

    String snippet = replyBody ?? '';
    IconData? typeIcon;
    if (replyType == ChatMessageType.voiceNote.name) {
      typeIcon = Icons.mic_rounded;
      snippet = 'Voice message';
    } else if (replyType == ChatMessageType.fileAttachment.name || replyType == ChatMessageType.image.name) {
      typeIcon = Icons.insert_drive_file_rounded;
      snippet = 'Attachment';
    }

    const accentColor = Color(0xFF00A884);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _scrollToRepliedMessage(replyToId, snippet: replyBody),
        borderRadius: BorderRadius.circular(6),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Container(
            margin: const EdgeInsets.only(bottom: 5),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.black.withOpacity(0.25)
                  : (isMyMessage
                      ? const Color(0xFFB4EBB0).withOpacity(0.65)
                      : const Color(0xFFF0F2F5)),
            ),
            child: IntrinsicHeight(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: 3.5,
                    color: accentColor,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(0, 4, 8, 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            replySender,
                            style: GoogleFonts.inter(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: accentColor,
                            ),
                          ),
                          const SizedBox(height: 1),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (typeIcon != null) ...[
                                Icon(
                                  typeIcon,
                                  size: 11.5,
                                  color: isDark ? const Color(0xFF8696A0) : const Color(0xFF667781),
                                ),
                                const SizedBox(width: 4),
                              ],
                              Flexible(
                                child: Text(
                                  snippet,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    color: isDark ? const Color(0xFF8696A0) : const Color(0xFF54656F),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _scrollToRepliedMessage(String? replyToId, {String? snippet}) {
    if (!mounted) return;
    final chatState = ref.read(pipelineChatProvider);
    final messages = chatState.messages;
    if (messages.isEmpty) return;

    OrderConversationMessageEntity? target;
    if (replyToId != null && replyToId.isNotEmpty) {
      final idx = messages.indexWhere((m) => m.id == replyToId);
      if (idx != -1) target = messages[idx];
    }
    if (target == null && snippet != null && snippet.trim().isNotEmpty) {
      final cleanSnippet = snippet.trim();
      final idx = messages.indexWhere((m) =>
          m.messageBody.trim() == cleanSnippet ||
          m.messageBody.contains(cleanSnippet) ||
          cleanSnippet.contains(m.messageBody));
      if (idx != -1) target = messages[idx];
    }

    if (target == null) {
      HapticFeedback.lightImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Original message not found in this thread.',
            style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w500),
          ),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
      return;
    }

    final targetMessageId = target.id;
    HapticFeedback.selectionClick();

    // Trigger visual pulse highlight on the target message
    _highlightMessage(targetMessageId);

    // If target widget context exists in viewport or nearby
    final key = _getKeyForMessage(targetMessageId);
    final ctx = key.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOutCubic,
        alignment: 0.25, // Scroll into comfortable view near top-middle
      );
      return;
    }

    // Otherwise calculate estimated position in ListView and animate towards it
    if (_scrollController.hasClients) {
      final targetIndex = messages.indexWhere((m) => m.id == targetMessageId);
      if (targetIndex >= 0) {
        final total = messages.length <= 1 ? 1 : messages.length - 1;
        final fraction = (targetIndex / total).clamp(0.0, 1.0);
        final targetOffset = fraction * _scrollController.position.maxScrollExtent;

        _scrollController.animateTo(
          targetOffset,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOutCubic,
        ).then((_) {
          if (!mounted) return;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            final lateCtx = _getKeyForMessage(targetMessageId).currentContext;
            if (lateCtx != null) {
              Scrollable.ensureVisible(
                lateCtx,
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                alignment: 0.25,
              );
            }
          });
        });
      }
    }
  }

  void _highlightMessage(String messageId) {
    setState(() {
      _highlightedMessageId = messageId;
    });
    _highlightTimer?.cancel();
    _highlightTimer = Timer(const Duration(milliseconds: 1400), () {
      if (mounted) {
        setState(() {
          if (_highlightedMessageId == messageId) {
            _highlightedMessageId = null;
          }
        });
      }
    });
  }


  Widget _buildOutboxSyncBanner(bool isDark, int count) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
          width: 0.8,
        ),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Color(0xFF00A884),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$count ${count == 1 ? "message" : "messages"} queued • Auto-syncing when online',
              style: GoogleFonts.inter(
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              ),
            ),
          ),
          InkWell(
            onTap: () {
              ref.read(pipelineChatProvider.notifier).flushOutbox(widget.orderId);
            },
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.sync_rounded,
                    size: 14,
                    color: isDark ? const Color(0xFF00A884) : const Color(0xFF008069),
                  ),
                  const SizedBox(width: 3),
                  Text(
                    'Sync',
                    style: GoogleFonts.inter(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: isDark ? const Color(0xFF00A884) : const Color(0xFF008069),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReplyingToBanner(bool isDark) {
    if (_replyingToMessage == null) return const SizedBox.shrink();

    final isMine = _replyingToMessage!.senderId == ref.read(authProvider).user?.id;
    final senderDisplay = isMine ? 'You' : _replyingToMessage!.senderName;

    String previewText = _replyingToMessage!.messageBody;
    IconData? previewIcon;
    if (_replyingToMessage!.messageType == ChatMessageType.voiceNote) {
      previewIcon = Icons.mic_rounded;
      previewText = 'Voice message';
    } else if (_replyingToMessage!.messageType == ChatMessageType.fileAttachment ||
        _replyingToMessage!.messageType == ChatMessageType.image) {
      previewIcon = Icons.insert_drive_file_rounded;
      previewText = 'Attachment';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1F2C34) : const Color(0xFFF7F8FA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF2A3942) : const Color(0xFFE2E8F0),
          width: 0.8,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 4,
                color: const Color(0xFF00A884),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Replying to $senderDisplay',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF00A884),
                        ),
                      ),
                      const SizedBox(height: 1),
                      Row(
                        children: [
                          if (previewIcon != null) ...[
                            Icon(previewIcon, size: 12, color: isDark ? const Color(0xFF8696A0) : const Color(0xFF667781)),
                            const SizedBox(width: 4),
                          ],
                          Expanded(
                            child: Text(
                              previewText,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontSize: 11.5,
                                color: isDark ? const Color(0xFF8696A0) : const Color(0xFF667781),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: isDark ? const Color(0xFF8696A0) : const Color(0xFF667781),
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                onPressed: () => setState(() => _replyingToMessage = null),
              ),
            ],
          ),
        ),
      ),
    );
  }


  List<Map<String, dynamic>> _getMessageReactions(OrderConversationMessageEntity msg) {
    final raw = msg.metadata['reactions'];
    if (raw is List) {
      return raw.map((r) => Map<String, dynamic>.from(r as Map)).toList();
    }
    return [];
  }

  void _showReactionPopup(BuildContext context, OrderConversationMessageEntity msg, bool isDark) {
    HapticFeedback.lightImpact();
    final reactions = _getMessageReactions(msg);
    final currentUserId = ref.read(authProvider).user?.id;
    final myReaction = reactions.firstWhere(
      (r) => r['userId'] == currentUserId,
      orElse: () => {},
    )['emoji'];

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.2),
      builder: (ctx) {
        return Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF202C33) : Colors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.25),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
                border: Border.all(
                  color: isDark ? const Color(0xFF2A3942) : const Color(0xFFE2E8F0),
                  width: 0.8,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ...['👍', '❤️', '😂', '😮', '😢', '🙏'].map((emoji) {
                    final isReacted = myReaction == emoji;
                    return InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () {
                        Navigator.pop(ctx);
                        HapticFeedback.mediumImpact();
                        ref.read(pipelineChatProvider.notifier).toggleReaction(
                              messageId: msg.id,
                              emoji: emoji,
                            );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 6),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isReacted
                              ? (isDark
                                  ? const Color(0xFF00A884).withOpacity(0.35)
                                  : const Color(0xFF008069).withOpacity(0.18))
                              : Colors.transparent,
                        ),
                        child: Text(
                          emoji,
                          style: const TextStyle(fontSize: 24),
                        ),
                      ),
                    );
                  }),
                  // More Emojis Button (+)
                  InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () {
                      Navigator.pop(ctx);
                      _showMoreReactionsModal(context, msg, isDark);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(7),
                      child: Icon(
                        Icons.add_rounded,
                        size: 24,
                        color: isDark ? const Color(0xFF8696A0) : const Color(0xFF667781),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showMoreReactionsModal(BuildContext context, OrderConversationMessageEntity msg, bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1F2C34) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final emojis = [
          '👍', '❤️', '😂', '😮', '😢', '🙏', '👏', '🎉',
          '🔥', '💯', '✨', '🚀', '✅', '❌', '👀', '🤝',
          '💪', '👌', '⚡', '📦', '🚚', '📍', '💰', '📞'
        ];
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF374151) : const Color(0xFFD1D5DB),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'React with Emoji',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isDark ? const Color(0xFFE9EDEF) : const Color(0xFF111B21),
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: emojis.map((e) {
                    return InkWell(
                      onTap: () {
                        Navigator.pop(ctx);
                        HapticFeedback.mediumImpact();
                        ref.read(pipelineChatProvider.notifier).toggleReaction(
                              messageId: msg.id,
                              emoji: e,
                            );
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF2A3942) : const Color(0xFFF0F2F5),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(e, style: const TextStyle(fontSize: 22)),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showReactionDetailsModal(
    BuildContext context,
    OrderConversationMessageEntity msg,
    List<Map<String, dynamic>> reactions,
    bool isDark,
  ) {
    final currentUserId = ref.read(authProvider).user?.id;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1F2C34) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF374151) : const Color(0xFFD1D5DB),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Text(
                      'Reactions (${reactions.length})',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: isDark ? const Color(0xFFE9EDEF) : const Color(0xFF111B21),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'Tap your reaction to remove',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: isDark ? const Color(0xFF8696A0) : const Color(0xFF667781),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: reactions.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final r = reactions[index];
                    final emoji = r['emoji']?.toString() ?? '👍';
                    final userName = r['userName']?.toString() ?? 'User';
                    final userId = r['userId']?.toString();
                    final isMe = userId == currentUserId;

                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: const Color(0xFF00A884).withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            userName.isNotEmpty ? userName[0].toUpperCase() : '?',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF00A884),
                            ),
                          ),
                        ),
                      ),
                      title: Text(
                        isMe ? '$userName (You)' : userName,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: isMe ? FontWeight.w700 : FontWeight.w500,
                          color: isDark ? const Color(0xFFE9EDEF) : const Color(0xFF111B21),
                        ),
                      ),
                      subtitle: isMe
                          ? Text(
                              'Click to remove',
                              style: GoogleFonts.inter(
                                fontSize: 10.5,
                                color: const Color(0xFF00A884),
                              ),
                            )
                          : null,
                      trailing: Text(
                        emoji,
                        style: const TextStyle(fontSize: 20),
                      ),
                      onTap: isMe
                          ? () {
                              Navigator.pop(ctx);
                              ref.read(pipelineChatProvider.notifier).toggleReaction(
                                    messageId: msg.id,
                                    emoji: emoji,
                                  );
                            }
                          : null,
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildReactionBadge(OrderConversationMessageEntity msg, bool isDark, bool isMyMessage) {
    final reactions = _getMessageReactions(msg);
    if (reactions.isEmpty) return const SizedBox.shrink();

    final currentUserId = ref.watch(authProvider).user?.id;
    final hasMyReaction = reactions.any((r) => r['userId'] == currentUserId);

    final uniqueEmojis = <String>{};
    for (final r in reactions) {
      if (r['emoji'] != null) uniqueEmojis.add(r['emoji'].toString());
    }

    return InkWell(
      onTap: () => _showReactionDetailsModal(context, msg, reactions, isDark),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 5.5, vertical: 2),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1F2C34) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: hasMyReaction
                ? const Color(0xFF00A884).withOpacity(0.6)
                : (isDark ? const Color(0xFF2A3942) : const Color(0xFFE2E8F0)),
            width: hasMyReaction ? 1.0 : 0.8,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.10),
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              uniqueEmojis.take(3).join(''),
              style: const TextStyle(fontSize: 12),
            ),
            if (reactions.length > 1) ...[
              const SizedBox(width: 3),
              Text(
                '${reactions.length}',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: hasMyReaction
                      ? const Color(0xFF00A884)
                      : (isDark ? const Color(0xFF8696A0) : const Color(0xFF667781)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSystemMilestone(
    OrderConversationMessageEntity msg,
    bool isDark,
    OrderConversationEntity? conv,
  ) {
    IconData icon = Icons.info_outline_rounded;
    Color color = const Color(0xFF00A884);

    switch (msg.messageType) {
      case ChatMessageType.riderAssigned:
        icon = Icons.two_wheeler_rounded;
        color = const Color(0xFFD97706);
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
        color = const Color(0xFF00A884);
    }

    final timeStr = DateFormat('h:mm a').format(msg.createdAt);

    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 20),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF182229) : Colors.white.withOpacity(0.92),
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                msg.messageBody,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: isDark ? const Color(0xFFD1D7DB) : const Color(0xFF54656F),
                ),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              timeStr,
              style: GoogleFonts.inter(
                fontSize: 9.5,
                color: isDark ? const Color(0xFF8696A0) : const Color(0xFF667781),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF182229) : const Color(0xFFFFF7D6),
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.lock_rounded,
                    size: 13,
                    color: isDark ? const Color(0xFFE9EDEF) : const Color(0xFF54656F),
                  ),
                  const SizedBox(width: 5),
                  Flexible(
                    child: Text(
                      'Order Pipeline Room Active',
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isDark ? const Color(0xFFE9EDEF) : const Color(0xFF111B21),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              Text(
                'Direct live coordination between Courier Rider, Distribution Center Operations, Merchant, and Telesales. Send a message to start.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  height: 1.35,
                  color: isDark ? const Color(0xFF8696A0) : const Color(0xFF54656F),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMentionSuggestionsOverlay(
    BuildContext context,
    bool isDark,
    OrderConversationEntity? conv,
  ) {
    final allProfiles = _getAvailableMentionProfiles(conv);
    final filtered = allProfiles.where((p) {
      if (_mentionQuery.isEmpty) return true;
      final name = (p['name'] as String).toLowerCase();
      final role = (p['role'] as String).toLowerCase();
      final tag = (p['tag'] as String).toLowerCase();
      return name.contains(_mentionQuery) ||
          role.contains(_mentionQuery) ||
          tag.contains(_mentionQuery);
    }).toList();

    if (filtered.isEmpty) return const SizedBox.shrink();

    return Container(
      constraints: const BoxConstraints(maxHeight: 220),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.12),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Row(
                children: [
                  const Icon(Icons.alternate_email_rounded, size: 14, color: Color(0xFF0284C7)),
                  const SizedBox(width: 6),
                  Text(
                    'Mention Participant',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: 4),
                itemCount: filtered.length,
                separatorBuilder: (_, __) => const Divider(height: 1, indent: 48),
                itemBuilder: (ctx, i) {
                  final p = filtered[i];
                  final name = p['name'] as String;
                  final role = p['role'] as String;
                  final tag = p['tag'] as String;
                  final color = p['color'] as Color;
                  final icon = p['icon'] as IconData;
                  final avatarUrl = p['avatarUrl'] as String?;

                  return InkWell(
                    onTap: () => _selectMentionSuggestion(tag),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      child: Row(
                        children: [
                          if (avatarUrl != null && avatarUrl.isNotEmpty)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: Image.network(
                                avatarUrl,
                                width: 28,
                                height: 28,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => CircleAvatar(
                                  radius: 14,
                                  backgroundColor: color.withValues(alpha: 0.15),
                                  child: Icon(icon, size: 14, color: color),
                                ),
                              ),
                            )
                          else
                            CircleAvatar(
                              radius: 14,
                              backgroundColor: color.withValues(alpha: 0.15),
                              child: Icon(icon, size: 14, color: color),
                            ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                                  ),
                                ),
                                Text(
                                  role,
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: color.withValues(alpha: 0.3)),
                            ),
                            child: Text(
                              tag,
                              style: GoogleFonts.inter(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: color,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes <= 0) return '0 B';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Widget _buildInputFooter(
    BuildContext context,
    bool isDark,
    bool isSending,
    OrderConversationEntity? conv,
  ) {
    final chatState = ref.watch(pipelineChatProvider);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final hasText = _msgController.text.trim().isNotEmpty;
    final hasAttachment = _stagedAttachment != null;

    return Container(
      padding: EdgeInsets.fromLTRB(
        8,
        4,
        8,
        bottomInset + (bottomPadding > 0 ? bottomPadding : 8),
      ),
      color: Colors.transparent, // Floating over WhatsApp Wallpaper!
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Live Presence Indicator (Typing or Voice Note Recording)
          if (chatState.activePresence != null && chatState.activePresence!.isActive)
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                margin: const EdgeInsets.only(bottom: 6, left: 4),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1F2C34).withValues(alpha: 0.96) : Colors.white.withValues(alpha: 0.96),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: chatState.activePresence!.isRecording
                        ? const Color(0xFFEF4444).withValues(alpha: 0.4)
                        : const Color(0xFF0D9488).withValues(alpha: 0.4),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (chatState.activePresence!.isRecording)
                      const Icon(Icons.mic_rounded, size: 14, color: Color(0xFFEF4444))
                    else
                      const Icon(Icons.more_horiz_rounded, size: 14, color: Color(0xFF0D9488)),
                    const SizedBox(width: 6),
                    Text(
                      chatState.activePresence!.displayLabel,
                      style: GoogleFonts.inter(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF334155),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Mention suggestions overlay if active
          if (_showMentionSuggestions)
            _buildMentionSuggestionsOverlay(context, isDark, conv),

          // WhatsApp Replying To Banner
          if (_replyingToMessage != null)
            _buildReplyingToBanner(isDark),

          // Outbox Sync Banner
          if (chatState.pendingOutboxCount > 0)
            _buildOutboxSyncBanner(isDark, chatState.pendingOutboxCount),

          // Attachment preview if staged
          if (_stagedAttachment != null)
            Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF202C33) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: _stagedAttachment!.isImage
                        ? Image.memory(
                            _stagedAttachment!.bytes,
                            width: 38,
                            height: 38,
                            fit: BoxFit.cover,
                          )
                        : Container(
                            width: 38,
                            height: 38,
                            color: const Color(0xFF00A884).withOpacity(0.15),
                            child: const Icon(
                              Icons.insert_drive_file_rounded,
                              color: Color(0xFF00A884),
                              size: 22,
                            ),
                          ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _stagedAttachment!.fileName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : const Color(0xFF111B21),
                          ),
                        ),
                        Text(
                          _formatFileSize(_stagedAttachment!.fileSize),
                          style: GoogleFonts.inter(
                            fontSize: 10.5,
                            color: isDark ? const Color(0xFF8696A0) : const Color(0xFF667781),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 18),
                    tooltip: 'Discard attachment',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    onPressed: () => setState(() => _stagedAttachment = null),
                  ),
                ],
              ),
            ),

          // WhatsApp Live Voice Recording Mode
          if (_isRecordingVoice)
            _buildWhatsAppVoiceRecordingBar(isDark, isSending)
          else
            _buildWhatsAppInputBar(context, isDark, isSending, hasText, hasAttachment),
        ],
      ),
    );
  }

  Widget _buildWhatsAppVoiceRecordingBar(bool isDark, bool isSending) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF202C33) : Colors.white,
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      child: Row(
        children: [
          // Pulsing recording red dot
          FadeTransition(
            opacity: _shimmerAnimation,
            child: Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                color: Color(0xFFEF4444),
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Stopwatch Duration Timer
          Text(
            '${_recordingDuration.inMinutes}:${(_recordingDuration.inSeconds % 60).toString().padLeft(2, '0')}',
            style: GoogleFonts.inter(
              fontSize: 13.5,
              fontWeight: FontWeight.bold,
              color: const Color(0xFFEF4444),
            ),
          ),
          const SizedBox(width: 12),

          // Waveform hint
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.graphic_eq_rounded,
                  size: 18,
                  color: isDark ? const Color(0xFF8696A0) : const Color(0xFF667781),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    'Slide to cancel',
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: isDark ? const Color(0xFF8696A0) : const Color(0xFF667781),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // WhatsApp Trash / Discard Button
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 22),
            tooltip: 'Cancel & Discard',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            onPressed: _cancelVoiceRecording,
          ),
          const SizedBox(width: 6),

          // WhatsApp Send Voice Note Button
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              color: Color(0xFF00A884), // WhatsApp Emerald
              shape: BoxShape.circle,
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: isSending ? null : _sendVoiceRecording,
                child: Center(
                  child: isSending
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(
                          Icons.arrow_upward_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWhatsAppInputBar(
    BuildContext context,
    bool isDark,
    bool isSending,
    bool hasText,
    bool hasAttachment,
  ) {
    final pillBg = isDark ? const Color(0xFF202C33) : Colors.white;
    final iconColor = isDark ? const Color(0xFF8696A0) : const Color(0xFF54656F);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // 1. WhatsApp Floating Input Pill
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: pillBg,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Emoji icon
                IconButton(
                  icon: Icon(
                    Icons.sentiment_satisfied_alt_outlined,
                    size: 23,
                    color: iconColor,
                  ),
                  padding: const EdgeInsets.all(7),
                  constraints: const BoxConstraints(),
                  tooltip: 'Emoji',
                  onPressed: () => _showQuickEmojiPicker(context, isDark),
                ),

                // Pure borderless text input (Strict border elimination matching real WhatsApp)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Theme(
                      data: Theme.of(context).copyWith(
                        inputDecorationTheme: const InputDecorationTheme(
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          disabledBorder: InputBorder.none,
                          errorBorder: InputBorder.none,
                          focusedErrorBorder: InputBorder.none,
                          filled: false,
                          fillColor: Colors.transparent,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      child: TextField(
                        controller: _msgController,
                        focusNode: _msgFocusNode,
                        minLines: 1,
                        maxLines: 5,
                        textCapitalization: TextCapitalization.sentences,
                        cursorColor: const Color(0xFF00A884),
                        cursorWidth: 2,
                        cursorRadius: const Radius.circular(2),
                        style: GoogleFonts.inter(
                          fontSize: 14.5,
                          height: 1.35,
                          color: isDark ? const Color(0xFFE9EDEF) : const Color(0xFF111B21),
                        ),
                        decoration: InputDecoration(
                          hintText: _stagedAttachment != null
                              ? 'Add a caption...'
                              : 'Message',
                          hintStyle: GoogleFonts.inter(
                            fontSize: 14.5,
                            color: isDark ? const Color(0xFF8696A0) : const Color(0xFF667781),
                          ),
                          isDense: true,
                          filled: false,
                          fillColor: Colors.transparent,
                          contentPadding: EdgeInsets.zero,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          disabledBorder: InputBorder.none,
                          errorBorder: InputBorder.none,
                          focusedErrorBorder: InputBorder.none,
                        ),
                      ),
                    ),
                  ),
                ),

                // Paperclip attachment button
                IconButton(
                  icon: Transform.rotate(
                    angle: -0.785,
                    child: Icon(
                      Icons.attach_file_rounded,
                      size: 22,
                      color: iconColor,
                    ),
                  ),
                  padding: const EdgeInsets.all(7),
                  constraints: const BoxConstraints(),
                  tooltip: 'Attach file or media',
                  onPressed: () => _showWhatsAppAttachmentSheet(context, isDark),
                ),

                // Camera button (when empty)
                if (!hasText && !hasAttachment)
                  IconButton(
                    icon: Icon(
                      Icons.camera_alt_rounded,
                      size: 22,
                      color: iconColor,
                    ),
                    padding: const EdgeInsets.all(7),
                    constraints: const BoxConstraints(),
                    tooltip: 'Camera / Photos',
                    onPressed: () => _pickMediaAttachment(isImageOnly: true),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 6),

        // 2. WhatsApp Circular Action FAB (Mic / Send)
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: const Color(0xFF00A884), // WhatsApp Emerald
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF00A884).withOpacity(0.35),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(23),
              onTap: isSending
                  ? null
                  : (hasText || hasAttachment)
                      ? _handleSendMessage
                      : _startVoiceRecording,
              child: Center(
                child: isSending
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Icon(
                        (hasText || hasAttachment)
                            ? Icons.send_rounded
                            : Icons.mic_rounded,
                        color: Colors.white,
                        size: (hasText || hasAttachment) ? 20 : 23,
                      ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showWhatsAppAttachmentSheet(BuildContext context, bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1F2C34) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildWhatsAppAttachmentItem(
                      icon: Icons.insert_drive_file_rounded,
                      label: 'Document',
                      color: const Color(0xFF5F66CD),
                      onTap: () {
                        Navigator.pop(ctx);
                        _pickMediaAttachment(isImageOnly: false);
                      },
                    ),
                    _buildWhatsAppAttachmentItem(
                      icon: Icons.camera_alt_rounded,
                      label: 'Camera',
                      color: const Color(0xFFD3396D),
                      onTap: () {
                        Navigator.pop(ctx);
                        _pickMediaAttachment(isImageOnly: true);
                      },
                    ),
                    _buildWhatsAppAttachmentItem(
                      icon: Icons.image_rounded,
                      label: 'Gallery',
                      color: const Color(0xFFAC44CF),
                      onTap: () {
                        Navigator.pop(ctx);
                        _pickMediaAttachment(isImageOnly: true);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildWhatsAppAttachmentItem(
                      icon: Icons.mic_rounded,
                      label: 'Audio Note',
                      color: const Color(0xFFE0662D),
                      onTap: () {
                        Navigator.pop(ctx);
                        _startVoiceRecording();
                      },
                    ),
                    _buildWhatsAppAttachmentItem(
                      icon: Icons.alternate_email_rounded,
                      label: 'Mention',
                      color: const Color(0xFF0E9BD4),
                      onTap: () {
                        Navigator.pop(ctx);
                        final cur = _msgController.text;
                        _msgController.text = cur.isEmpty ? '@' : '$cur @';
                        _msgController.selection = TextSelection.fromPosition(
                          TextPosition(offset: _msgController.text.length),
                        );
                        _msgFocusNode.requestFocus();
                      },
                    ),
                    _buildWhatsAppAttachmentItem(
                      icon: Icons.inventory_2_rounded,
                      label: 'Order Info',
                      color: const Color(0xFF1BA458),
                      onTap: () {
                        Navigator.pop(ctx);
                        final conv = ref.read(pipelineChatProvider).activeConversation;
                        if (conv != null) {
                          _msgController.text = '📦 Order #${conv.orderNumber} (${conv.currentProductName ?? 'Package'}) - Status: ${conv.orderStatus.toUpperCase()}';
                          _msgController.selection = TextSelection.fromPosition(
                            TextPosition(offset: _msgController.text.length),
                          );
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildWhatsAppAttachmentItem({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [color, color.withOpacity(0.85)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Icon(icon, color: Colors.white, size: 24),
            ),
            const SizedBox(height: 7),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showQuickEmojiPicker(BuildContext context, bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1F2C34) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final emojis = ['👍', '❤️', '😂', '😮', '😢', '🙏', '✅', '📦', '🚚', '📍', '💰', '📞', '⚠️', '🚨', '🤝', '🔥'];
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Quick Reactions',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isDark ? const Color(0xFF8696A0) : const Color(0xFF54656F),
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: emojis.map((e) {
                    return InkWell(
                      onTap: () {
                        Navigator.pop(ctx);
                        final cur = _msgController.text;
                        _msgController.text = '$cur $e '.trimLeft();
                        _msgController.selection = TextSelection.fromPosition(
                          TextPosition(offset: _msgController.text.length),
                        );
                        _msgFocusNode.requestFocus();
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF2A3942) : const Color(0xFFF0F2F5),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(e, style: const TextStyle(fontSize: 22)),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDateSeparator(DateTime date, bool isDark) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final msgDate = DateTime(date.year, date.month, date.day);

    String text;
    if (msgDate == today) {
      text = 'TODAY';
    } else if (msgDate == yesterday) {
      text = 'YESTERDAY';
    } else if (now.difference(msgDate).inDays < 7) {
      text = DateFormat('EEEE').format(date).toUpperCase();
    } else {
      text = DateFormat('MMMM d, yyyy').format(date).toUpperCase();
    }

    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4.5),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF182229) : Colors.white.withOpacity(0.92),
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Text(
          text,
          style: GoogleFonts.inter(
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
            color: isDark ? const Color(0xFF8696A0) : const Color(0xFF54656F),
          ),
        ),
      ),
    );
  }

  void _showOrderQuickDetailsModal(BuildContext context, OrderConversationEntity conv, bool isDark) {
    final currency = NumberFormat.currency(locale: 'en_NG', symbol: '₦', decimalDigits: 0);

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1F2C34) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    UserAvatarWidget(
                      fullName: conv.customerName,
                      radius: 24,
                      backgroundColor: const Color(0xFF008069),
                      textColor: Colors.white,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            conv.customerName,
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : const Color(0xFF111B21),
                            ),
                          ),
                          if (conv.customerPhone != null && conv.customerPhone!.isNotEmpty)
                            Text(
                              conv.customerPhone!,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: isDark ? const Color(0xFF8696A0) : const Color(0xFF667781),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 10),
                Text(
                  'ORDER SUMMARY',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                    color: const Color(0xFF00A884),
                  ),
                ),
                const SizedBox(height: 8),
                _buildQuickDetailRow('Order Number', conv.orderNumber, isDark),
                _buildQuickDetailRow('Product', '${conv.currentProductName ?? 'Standard'} (${conv.currentPackageName ?? 'Deal'})', isDark),
                _buildQuickDetailRow('Total Amount', currency.format(conv.currentTotalAmount), isDark),
                _buildQuickDetailRow('Status', conv.orderStatus.toUpperCase(), isDark),
                _buildQuickDetailRow('Distribution Center', conv.distributionCenterName ?? 'Central Command DC', isDark),
                if (conv.deliveryAgentName != null && conv.deliveryAgentName!.isNotEmpty)
                  _buildQuickDetailRow('Assigned Courier', conv.deliveryAgentName!, isDark),
                if (conv.closerName != null && conv.closerName!.isNotEmpty)
                  _buildQuickDetailRow('Telesales Closer', conv.closerName!, isDark),
                _buildQuickDetailRow('Merchant Brand', conv.clientName, isDark),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildQuickDetailRow(String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12.5,
              color: isDark ? const Color(0xFF8696A0) : const Color(0xFF667781),
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : const Color(0xFF111B21),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getWhatsAppSubtitle(OrderConversationEntity? conv) {
    if (conv == null) return 'tap for order details';
    final parts = <String>[];
    if (conv.deliveryAgentName != null && conv.deliveryAgentName!.isNotEmpty) {
      parts.add('Rider');
    }
    parts.add('DC Ops');
    parts.add('Merchant');
    if (conv.closerName != null && conv.closerName!.isNotEmpty) {
      parts.add('Closer');
    }
    return parts.join(', ');
  }

  Widget _buildAccessRestrictedState(String error, bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withOpacity(0.1),
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
              error,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 13, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Canvas Doodle Wallpaper mimicking WhatsApp's iconic background
class WhatsAppWallpaperPainter extends CustomPainter {
  final bool isDark;
  const WhatsAppWallpaperPainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final strokeColor = (isDark ? Colors.white : Colors.black).withOpacity(isDark ? 0.025 : 0.038);
    final paint = Paint()
      ..color = strokeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    const stepX = 85.0;
    const stepY = 85.0;
    int row = 0;

    for (double y = 20; y < size.height; y += stepY, row++) {
      final offsetX = (row % 2 == 1) ? stepX / 2 : 0.0;
      int col = 0;
      for (double x = 20 + offsetX; x < size.width; x += stepX, col++) {
        final iconType = (col + row * 3) % 6;
        final c = Offset(x, y);

        switch (iconType) {
          case 0:
            // Chat bubble
            final path = Path();
            path.addRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: c, width: 22, height: 16), const Radius.circular(5)));
            path.moveTo(c.dx - 6, c.dy + 8);
            path.lineTo(c.dx - 10, c.dy + 12);
            path.lineTo(c.dx - 2, c.dy + 8);
            canvas.drawPath(path, paint);
            break;
          case 1:
            // 4-pointed star
            final path = Path();
            path.moveTo(c.dx, c.dy - 10);
            path.lineTo(c.dx + 3, c.dy - 3);
            path.lineTo(c.dx + 10, c.dy);
            path.lineTo(c.dx + 3, c.dy + 3);
            path.lineTo(c.dx, c.dy + 10);
            path.lineTo(c.dx - 3, c.dy + 3);
            path.lineTo(c.dx - 10, c.dy);
            path.lineTo(c.dx - 3, c.dy - 3);
            path.close();
            canvas.drawPath(path, paint);
            break;
          case 2:
            // Clock
            canvas.drawCircle(c, 8, paint);
            canvas.drawLine(c, Offset(c.dx, c.dy - 4), paint);
            canvas.drawLine(c, Offset(c.dx + 3, c.dy), paint);
            break;
          case 3:
            // Package / box
            canvas.drawRect(Rect.fromCenter(center: c, width: 16, height: 14), paint);
            canvas.drawLine(Offset(c.dx - 8, c.dy), Offset(c.dx + 8, c.dy), paint);
            canvas.drawLine(Offset(c.dx, c.dy - 7), Offset(c.dx, c.dy + 7), paint);
            break;
          case 4:
            // Musical note
            final path = Path();
            path.moveTo(c.dx - 4, c.dy + 5);
            path.lineTo(c.dx - 4, c.dy - 6);
            path.lineTo(c.dx + 4, c.dy - 9);
            path.lineTo(c.dx + 4, c.dy + 2);
            canvas.drawPath(path, paint);
            canvas.drawCircle(Offset(c.dx - 6, c.dy + 5), 2.5, paint);
            canvas.drawCircle(Offset(c.dx + 2, c.dy + 2), 2.5, paint);
            break;
          case 5:
            // Heart
            final path = Path();
            path.moveTo(c.dx, c.dy + 6);
            path.cubicTo(c.dx - 8, c.dy + 1, c.dx - 8, c.dy - 6, c.dx, c.dy - 3);
            path.cubicTo(c.dx + 8, c.dy - 6, c.dx + 8, c.dy + 1, c.dx, c.dy + 6);
            canvas.drawPath(path, paint);
            break;
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant WhatsAppWallpaperPainter oldDelegate) => oldDelegate.isDark != isDark;
}

