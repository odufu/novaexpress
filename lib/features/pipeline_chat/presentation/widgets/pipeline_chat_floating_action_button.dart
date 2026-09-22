import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/pipeline_chat_provider.dart';
import '../providers/pipeline_chat_fab_provider.dart';
import 'conversation_list_modal.dart';

class PipelineChatFloatingActionButton extends ConsumerStatefulWidget {
  const PipelineChatFloatingActionButton({super.key});

  @override
  ConsumerState<PipelineChatFloatingActionButton> createState() =>
      _PipelineChatFloatingActionButtonState();
}

class _PipelineChatFloatingActionButtonState
    extends ConsumerState<PipelineChatFloatingActionButton> {
  bool _isDragging = false;

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(pipelineChatProvider);
    final authUser = ref.watch(authProvider).user;
    final role = authUser?.role ?? 'client';

    final unreadCount = chatState.getUnreadCountForRole(role);
    final hasUnread = unreadCount > 0;

    return MouseRegion(
      cursor: _isDragging ? SystemMouseCursors.grabbing : SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanStart: (details) {
          _isDragging = false;
        },
        onPanUpdate: (details) {
          _isDragging = true;
          final size = MediaQuery.of(context).size;
          ref
              .read(pipelineChatFabPositionProvider.notifier)
              .updateDelta(details.delta, size);
        },
        onPanEnd: (details) {
          if (_isDragging) {
            ref.read(pipelineChatFabPositionProvider.notifier).savePosition();
            setState(() {
              _isDragging = false;
            });
          }
        },
        onTap: () {
          ConversationListModal.show(context);
        },
        onDoubleTap: () {
          ref.read(pipelineChatFabPositionProvider.notifier).resetPosition();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '📍 Chat button position reset to default',
                style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600),
              ),
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          );
        },
        child: AnimatedScale(
          scale: _isDragging ? 1.08 : 1.0,
          duration: const Duration(milliseconds: 150),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              FloatingActionButton(
                heroTag: 'pipeline_chat_fab',
                onPressed: () {
                  if (!_isDragging) {
                    ConversationListModal.show(context);
                  }
                },
                backgroundColor: const Color(0xFF0D9488), // Emerald/Teal brand color
                elevation: _isDragging ? 12 : 4,
                shape: const CircleBorder(),
                tooltip: 'Order Pipeline Chats • Drag to reposition, Double-tap to reset',
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF14B8A6),
                        Color(0xFF0D9488),
                        Color(0xFF0F766E),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0D9488)
                            .withValues(alpha: _isDragging ? 0.6 : 0.35),
                        blurRadius: _isDragging ? 14 : 10,
                        offset: Offset(0, _isDragging ? 6 : 4),
                      ),
                    ],
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      const Icon(
                        Icons.support_agent_rounded,
                        color: Colors.white,
                        size: 30,
                      ),
                      // Subtle drag handle grip indicator at bottom
                      Positioned(
                        bottom: 4,
                        child: Container(
                          width: 14,
                          height: 3,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (hasUnread)
                Positioned(
                  top: -4,
                  right: -4,
                  child: IgnorePointer(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444), // Vibrant Red badge
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.red.withValues(alpha: 0.4),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 22,
                        minHeight: 22,
                      ),
                      child: Center(
                        child: Text(
                          unreadCount > 99 ? '99+' : unreadCount.toString(),
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            height: 1,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
