import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/local_storage_service.dart';

/// Provider for managing the custom position (Offset) of the draggable Pipeline Chat FAB
final pipelineChatFabPositionProvider =
    StateNotifierProvider<PipelineChatFabPositionNotifier, Offset?>((ref) {
  final storage = ref.watch(localStorageServiceProvider);
  return PipelineChatFabPositionNotifier(storage);
});

class PipelineChatFabPositionNotifier extends StateNotifier<Offset?> {
  static const String _storageKey = 'novexps_chat_fab_pos';
  final LocalStorageService _storage;

  PipelineChatFabPositionNotifier(this._storage) : super(null) {
    _loadSavedPosition();
  }

  Future<void> _loadSavedPosition() async {
    try {
      final data = await _storage.getJsonObject(_storageKey);
      if (data != null && data['x'] != null && data['y'] != null) {
        final x = (data['x'] as num).toDouble();
        final y = (data['y'] as num).toDouble();
        state = Offset(x, y);
      }
    } catch (_) {}
  }

  void updateDelta(Offset delta, Size screenSize) {
    const double fabSize = 56.0;
    const double margin = 16.0;

    // Determine base position if user hasn't dragged yet
    final current = state ??
        Offset(
          screenSize.width - fabSize - margin,
          screenSize.height - fabSize - 88.0,
        );

    final maxW = screenSize.width;
    final maxH = screenSize.height;

    final newX = (current.dx + delta.dx).clamp(
      margin,
      (maxW - fabSize - margin).clamp(margin, maxW),
    );
    final newY = (current.dy + delta.dy).clamp(
      margin + kToolbarHeight,
      (maxH - fabSize - margin).clamp(margin, maxH),
    );

    state = Offset(newX, newY);
  }

  Future<void> savePosition() async {
    if (state == null) return;
    try {
      await _storage.saveJsonObject(_storageKey, {
        'x': state!.dx,
        'y': state!.dy,
      });
    } catch (_) {}
  }

  Future<void> resetPosition() async {
    state = null;
    try {
      await _storage.remove(_storageKey);
    } catch (_) {}
  }
}

/// Dynamic FloatingActionButtonLocation that positions the chat button according to user drag
final pipelineChatFabLocationProvider =
    Provider<FloatingActionButtonLocation>((ref) {
  final customOffset = ref.watch(pipelineChatFabPositionProvider);
  return PipelineChatDraggableFabLocation(customOffset);
});

class PipelineChatDraggableFabLocation extends FloatingActionButtonLocation {
  final Offset? customOffset;

  const PipelineChatDraggableFabLocation(this.customOffset);

  @override
  Offset getOffset(ScaffoldPrelayoutGeometry scaffoldGeometry) {
    const double fabWidth = 56.0;
    const double fabHeight = 56.0;
    const double margin = 16.0;

    final double maxW = scaffoldGeometry.scaffoldSize.width;
    final double maxH = scaffoldGeometry.scaffoldSize.height;

    if (maxW <= 0 || maxH <= 0 || maxW < fabWidth || maxH < fabHeight) {
      return Offset.zero;
    }

    final double maxPossibleX = (maxW - fabWidth - margin) > 0 ? (maxW - fabWidth - margin) : 0.0;
    final double maxPossibleY = (maxH - fabHeight - margin) > 0 ? (maxH - fabHeight - margin) : 0.0;
    final double minPossibleX = margin < maxPossibleX ? margin : maxPossibleX;
    final double minPossibleY = margin < maxPossibleY ? margin : maxPossibleY;

    if (customOffset != null) {
      final double clampedX = customOffset!.dx.clamp(minPossibleX, maxPossibleX);
      final double clampedY = customOffset!.dy.clamp(minPossibleY, maxPossibleY);
      return Offset(clampedX, clampedY);
    }

    // Default positioning:
    // If a bottom navigation bar is present, scaffoldGeometry.contentBottom already sits
    // right above the bottom nav bar, so standard margin (16.0) docks it neatly in the bottom corner.
    // On wide desktop screens without a bottom bar, float at 84.0 to clear sticky footers.
    final bool hasBottomBar = scaffoldGeometry.contentBottom < (maxH - 30);
    final double bottomMargin = hasBottomBar ? 16.0 : (maxW >= 960 ? 84.0 : 16.0);
    final double defaultX = maxPossibleX;
    final double rawY = scaffoldGeometry.contentBottom - fabHeight - bottomMargin;
    final double defaultY = rawY.clamp(minPossibleY, maxPossibleY);

    return Offset(defaultX, defaultY);
  }
}
