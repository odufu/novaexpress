import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/theme_provider.dart';
import '../providers/client_portal_provider.dart';
import '../../ai_bi/presentation/providers/merchant_bi_provider.dart';
import '../../ai_bi/presentation/widgets/merchant_bi_chart_renderer.dart';
import '../../ai_bi/presentation/widgets/merchant_bi_mermaid_widget.dart';
import '../../ai_bi/domain/entities/merchant_bi_message.dart';

class MerchantBiChatPage extends ConsumerStatefulWidget {
  const MerchantBiChatPage({super.key});

  @override
  ConsumerState<MerchantBiChatPage> createState() => _MerchantBiChatPageState();
}

class _MerchantBiChatPageState extends ConsumerState<MerchantBiChatPage> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final client = ref.read(clientPortalProvider).clientProfile;
      ref.read(merchantBIProvider.notifier).initialize(client.id);
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _handleSend([String? presetQuery]) {
    final text = presetQuery ?? _textController.text;
    if (text.trim().isEmpty) return;

    ref.read(merchantBIProvider.notifier).askQuestion(text);
    if (presetQuery == null) {
      _textController.clear();
    }
    _scrollToBottom();
  }

  void _showKnowledgeModal(BuildContext context, bool isDark) {
    final titleController = TextEditingController();
    final contentController = TextEditingController();
    final tagsController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF6366F1).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.menu_book_rounded, color: Color(0xFF6366F1), size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Add Business Knowledge',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 480,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Feed custom business notes, return rules, product USPs, or preferred logistics instructions to NovaBI.',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: titleController,
                  decoration: InputDecoration(
                    labelText: 'Topic / Rule Title',
                    hintText: 'e.g. Return Policy, Respia Upsell Pitch',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: contentController,
                  maxLines: 4,
                  decoration: InputDecoration(
                    labelText: 'Details / Instructions',
                    hintText: 'Describe business context, delivery constraints, or pricing guidelines...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: tagsController,
                  decoration: InputDecoration(
                    labelText: 'Keywords / Tags (comma separated)',
                    hintText: 'e.g. respia, return, lagos, delivery',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              final title = titleController.text.trim();
              final content = contentController.text.trim();
              if (title.isNotEmpty && content.isNotEmpty) {
                final tags = tagsController.text
                    .split(',')
                    .map((e) => e.trim().toLowerCase())
                    .where((e) => e.isNotEmpty)
                    .toList();
                ref.read(merchantBIProvider.notifier).addCustomKnowledge(
                      title: title,
                      content: content,
                      tags: tags,
                    );
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Business knowledge saved to NovaBI.'),
                    backgroundColor: Color(0xFF10B981),
                  ),
                );
              }
            },
            child: const Text('Save Knowledge'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeProvider);
    final isDark = themeMode == ThemeMode.dark ||
        (themeMode == ThemeMode.system &&
            MediaQuery.of(context).platformBrightness == Brightness.dark);

    final portalState = ref.watch(clientPortalProvider);
    final biState = ref.watch(merchantBIProvider);
    final client = portalState.clientProfile;
    final messages = biState.messages;

    return Container(
      color: isDark ? const Color(0xFF0B1120) : const Color(0xFFF8FAFC),
      child: Column(
        children: [
          // Header Bar
          _buildHeaderBar(context, client.companyName, isDark),

          // Main Chat Body or Welcome Cards
          Expanded(
            child: messages.isEmpty
                ? _buildEmptyStateWelcome(client.companyName, isDark, biState.defaultSuggestions)
                : _buildMessageList(messages, isDark, biState.isLoading),
          ),

          // Bottom Input Bar
          _buildInputBar(context, isDark, biState.isLoading),
        ],
      ),
    );
  }

  Widget _buildHeaderBar(BuildContext context, String companyName, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.auto_awesome,
              color: Colors.white,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        'NovaBI Copilot',
                        style: GoogleFonts.inter(
                          fontSize: 14.0,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6366F1).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(
                          color: const Color(0xFF6366F1).withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        'AI',
                        style: GoogleFonts.inter(
                          fontSize: 8.5,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF6366F1),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Color(0xFF10B981),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'Strictly Scoped: $companyName Data Only',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Action Buttons (Compact constraints & padding to fit all screen sizes)
          Tooltip(
            message: 'Add Business Knowledge',
            child: IconButton(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.all(5),
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              icon: const Icon(Icons.menu_book_rounded, size: 18),
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              onPressed: () => _showKnowledgeModal(context, isDark),
            ),
          ),
          Tooltip(
            message: 'New Chat Session',
            child: IconButton(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.all(5),
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              icon: const Icon(Icons.add_comment_rounded, size: 18),
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              onPressed: () {
                ref.read(merchantBIProvider.notifier).createNewSession();
              },
            ),
          ),
          Tooltip(
            message: 'Clear Chat History',
            child: IconButton(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.all(5),
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              icon: const Icon(Icons.delete_sweep_rounded, size: 18),
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              onPressed: () {
                ref.read(merchantBIProvider.notifier).clearCurrentChat();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyStateWelcome(
    String companyName,
    bool isDark,
    List<String> suggestions,
  ) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(Icons.psychology_rounded, color: Colors.white, size: 32),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Welcome, $companyName BI Copilot',
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Ask anything about your product sales, warehouse stock across hubs, delivery performance, and end-to-end logistics flowcharts.',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              Text(
                'SUGGESTED EXECUTIVE INQUIRIES',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF6366F1),
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 14),
              LayoutBuilder(
                builder: (context, constraints) {
                  final maxPillWidth = constraints.maxWidth;
                  return Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: suggestions.map((prompt) {
                      return ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: maxPillWidth),
                    child: InkWell(
                      onTap: () => _handleSend(prompt),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              prompt.contains('flowchart')
                                  ? Icons.account_tree_rounded
                                  : (prompt.contains('sales') || prompt.contains('Respia')
                                      ? Icons.monetization_on_rounded
                                      : (prompt.contains('stock')
                                          ? Icons.warehouse_rounded
                                          : Icons.insights_rounded)),
                              size: 15,
                              color: const Color(0xFF6366F1),
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                prompt,
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF334155),
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                    }).toList(),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMessageList(
    List<MerchantBIMessage> messages,
    bool isDark,
    bool isLoading,
  ) {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      itemCount: messages.length + (isLoading ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == messages.length && isLoading) {
          return _buildTypingIndicator(isDark);
        }

        final msg = messages[index];
        return _buildMessageBubble(msg, isDark);
      },
    );
  }

  Widget _buildMessageBubble(MerchantBIMessage msg, bool isDark) {
    if (msg.isUser) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.only(bottom: 16, left: 60),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF4F46E5), Color(0xFF6366F1)],
            ),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
              bottomLeft: Radius.circular(16),
              bottomRight: Radius.circular(4),
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF6366F1).withValues(alpha: 0.25),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Text(
            msg.content,
            style: GoogleFonts.inter(
              fontSize: 13.5,
              fontWeight: FontWeight.w500,
              color: Colors.white,
              height: 1.4,
            ),
          ),
        ),
      );
    }

    // AI Response Bubble
    return Container(
      margin: const EdgeInsets.only(bottom: 24, right: 30),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // AI Avatar
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Center(
              child: Icon(Icons.auto_awesome, color: Colors.white, size: 16),
            ),
          ),
          const SizedBox(width: 12),
          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Text bubble
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(4),
                      topRight: Radius.circular(16),
                      bottomLeft: Radius.circular(16),
                      bottomRight: Radius.circular(16),
                    ),
                    border: Border.all(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Text content (markdown-style simple rendering)
                      _buildFormattedText(msg.content, isDark),

                      // Embedded Visual Chart / Flowchart if present
                      if (msg.chartPayload != null) ...[
                        const SizedBox(height: 12),
                        MerchantBIChartRenderer(
                          payload: msg.chartPayload!,
                          isDark: isDark,
                        ),
                      ],
                    ],
                  ),
                ),

                // Quick Follow-up Prompts
                if (msg.quickPrompts.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final maxPillWidth = constraints.maxWidth;
                      return Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: msg.quickPrompts.map((prompt) {
                          return ConstrainedBox(
                            constraints: BoxConstraints(maxWidth: maxPillWidth),
                        child: InkWell(
                          onTap: () => _handleSend(prompt),
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF1E293B)
                                  : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isDark
                                    ? const Color(0xFF334155)
                                    : const Color(0xFFCBD5E1),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.subdirectory_arrow_right_rounded,
                                  size: 12,
                                  color: Color(0xFF6366F1),
                                ),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    prompt,
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: isDark
                                          ? const Color(0xFF94A3B8)
                                          : const Color(0xFF475569),
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                        }).toList(),
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormattedText(String text, bool isDark) {
    if (text.contains('```mermaid')) {
      final parts = text.split('```mermaid');
      final before = parts[0];
      final after = parts[1];
      final endIdx = after.indexOf('```');
      final mermaidCode = endIdx != -1 ? after.substring(0, endIdx).trim() : after.trim();
      final remaining = endIdx != -1 ? after.substring(endIdx + 3).trim() : '';

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (before.trim().isNotEmpty) _buildPlainFormattedText(before, isDark),
          MerchantBIMermaidWidget(
            payload: MerchantBIChartPayload(
              type: BIChartType.mermaid,
              title: 'Official Mermaid Illustration Diagram',
              mermaidCode: mermaidCode,
            ),
            isDark: isDark,
            rawMermaidCode: mermaidCode,
          ),
          if (remaining.isNotEmpty) _buildPlainFormattedText(remaining, isDark),
        ],
      );
    }
    return _buildPlainFormattedText(text, isDark);
  }

  Widget _buildPlainFormattedText(String text, bool isDark) {
    final lines = text.split('\n');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: lines.map((line) {
        if (line.trim().isEmpty) return const SizedBox(height: 6);

        // Simple markdown boldness parsing
        final hasBullet = line.startsWith('• ');
        final content = hasBullet ? line.substring(2) : line;

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (hasBullet) ...[
                Text(
                  '• ',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF6366F1),
                  ),
                ),
              ],
              Expanded(
                child: Text(
                  content.replaceAll('**', '').replaceAll('*', ''),
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: line.startsWith('📈') ||
                            line.startsWith('🚚') ||
                            line.startsWith('📦') ||
                            line.startsWith('💳') ||
                            line.startsWith('📊') ||
                            line.startsWith('🔄') ||
                            line.startsWith('⚠️') ||
                            line.startsWith('🎯') ||
                            line.startsWith('🔒') ||
                            line.startsWith('📐')
                        ? FontWeight.w700
                        : FontWeight.w500,
                    color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF1E293B),
                    height: 1.45,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTypingIndicator(bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Center(
              child: Icon(Icons.auto_awesome, color: Colors.white, size: 16),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFF6366F1),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'NovaBI is crunching your business analytics...',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar(BuildContext context, bool isDark, bool isLoading) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          ),
        ),
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                  ),
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 14),
                    const Icon(
                      Icons.auto_awesome_rounded,
                      size: 18,
                      color: Color(0xFF6366F1),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _textController,
                        focusNode: _focusNode,
                        enabled: !isLoading,
                        style: GoogleFonts.inter(
                          fontSize: 13.5,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                        decoration: InputDecoration(
                          hintText: 'Ask NovaBI: "How much sales for Respia?", flowcharts, stock...',
                          hintStyle: GoogleFonts.inter(
                            fontSize: 12.5,
                            color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                          ),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onSubmitted: (_) => _handleSend(),
                      ),
                    ),
                    if (_textController.text.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 16),
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        onPressed: () {
                          setState(() {
                            _textController.clear();
                          });
                        },
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                ),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                onPressed: isLoading ? null : () => _handleSend(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

