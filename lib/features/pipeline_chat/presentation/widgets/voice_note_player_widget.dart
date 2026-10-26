import 'dart:async';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:google_fonts/google_fonts.dart';

class VoiceNotePlayerWidget extends StatefulWidget {
  final String audioUrl;
  final int durationSeconds;
  final bool isMyMessage;
  final bool isDark;

  const VoiceNotePlayerWidget({
    super.key,
    required this.audioUrl,
    required this.durationSeconds,
    required this.isMyMessage,
    required this.isDark,
  });

  // Coordinator to ensure only one voice note plays at any time
  static AudioPlayer? _activePlayer;
  static VoidCallback? _stopActiveCallback;

  @override
  State<VoiceNotePlayerWidget> createState() => _VoiceNotePlayerWidgetState();
}

class _VoiceNotePlayerWidgetState extends State<VoiceNotePlayerWidget> {
  late final AudioPlayer _player;
  PlayerState _playerState = PlayerState.stopped;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _isLoading = false;
  double _playbackSpeed = 1.0;

  StreamSubscription? _posSub;
  StreamSubscription? _durSub;
  StreamSubscription? _stateSub;
  StreamSubscription? _compSub;

  // Static waveform amplitudes (24 bars)
  static const List<double> _waveformHeights = [
    10, 16, 8, 22, 14, 24, 18, 12, 26, 16, 20, 12,
    28, 16, 22, 14, 18, 10, 24, 14, 20, 12, 16, 8,
  ];

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _duration = Duration(seconds: widget.durationSeconds > 0 ? widget.durationSeconds : 0);

    _posSub = _player.onPositionChanged.listen((pos) {
      if (mounted) setState(() => _position = pos);
    });

    _durSub = _player.onDurationChanged.listen((dur) {
      if (mounted && dur > Duration.zero) setState(() => _duration = dur);
    });

    _stateSub = _player.onPlayerStateChanged.listen((st) {
      if (mounted) {
        setState(() {
          _playerState = st;
          if (st == PlayerState.playing) _isLoading = false;
        });
      }
    });

    _compSub = _player.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _playerState = PlayerState.completed;
          _position = Duration.zero;
        });
      }
    });
  }

  @override
  void dispose() {
    if (VoiceNotePlayerWidget._activePlayer == _player) {
      VoiceNotePlayerWidget._activePlayer = null;
      VoiceNotePlayerWidget._stopActiveCallback = null;
    }
    _posSub?.cancel();
    _durSub?.cancel();
    _stateSub?.cancel();
    _compSub?.cancel();
    _player.dispose();
    super.dispose();
  }

  Future<void> _togglePlayPause() async {
    if (_playerState == PlayerState.playing) {
      await _player.pause();
    } else {
      // Pause any previously active player
      if (VoiceNotePlayerWidget._activePlayer != null &&
          VoiceNotePlayerWidget._activePlayer != _player) {
        VoiceNotePlayerWidget._stopActiveCallback?.call();
      }

      VoiceNotePlayerWidget._activePlayer = _player;
      VoiceNotePlayerWidget._stopActiveCallback = () {
        if (mounted) {
          _player.pause();
          setState(() => _playerState = PlayerState.paused);
        }
      };

      setState(() => _isLoading = true);
      try {
        if (_playerState == PlayerState.paused) {
          await _player.resume();
        } else {
          await _player.play(UrlSource(widget.audioUrl));
          await _player.setPlaybackRate(_playbackSpeed);
        }
      } catch (e) {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  void _cycleSpeed() {
    double nextSpeed = 1.0;
    if (_playbackSpeed == 1.0) {
      nextSpeed = 1.5;
    } else if (_playbackSpeed == 1.5) {
      nextSpeed = 2.0;
    } else {
      nextSpeed = 1.0;
    }

    setState(() => _playbackSpeed = nextSpeed);
    _player.setPlaybackRate(nextSpeed);
  }

  void _seekToPercent(double percent) {
    if (_duration <= Duration.zero) return;
    final targetMs = (_duration.inMilliseconds * percent.clamp(0.0, 1.0)).toInt();
    _player.seek(Duration(milliseconds: targetMs));
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '${m.toString().padLeft(1, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final isPlaying = _playerState == PlayerState.playing;
    final totalMs = _duration.inMilliseconds > 0 ? _duration.inMilliseconds : 1;
    final currentMs = _position.inMilliseconds.clamp(0, totalMs);
    final progress = (currentMs / totalMs).clamp(0.0, 1.0);

    final primaryAccent = widget.isMyMessage
        ? Colors.white
        : const Color(0xFF0284C7);
    final playedBarColor = widget.isMyMessage
        ? Colors.white
        : const Color(0xFF0284C7);
    final unplayedBarColor = widget.isMyMessage
        ? Colors.white.withValues(alpha: 0.35)
        : (widget.isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1));

    return Container(
      constraints: const BoxConstraints(minWidth: 230, maxWidth: 300),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              // 1. Play / Pause Circular Button
              InkWell(
                onTap: _togglePlayPause,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: widget.isMyMessage
                        ? Colors.white.withValues(alpha: 0.22)
                        : (widget.isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: _isLoading
                        ? SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: primaryAccent,
                            ),
                          )
                        : Icon(
                            isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                            color: primaryAccent,
                            size: 22,
                          ),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // 2. Interactive Audio Waveform
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapDown: (details) {
                        final percent = details.localPosition.dx / constraints.maxWidth;
                        _seekToPercent(percent);
                      },
                      onHorizontalDragUpdate: (details) {
                        final percent = details.localPosition.dx / constraints.maxWidth;
                        _seekToPercent(percent);
                      },
                      child: SizedBox(
                        height: 30,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: List.generate(_waveformHeights.length, (index) {
                            final barFraction = (index + 1) / _waveformHeights.length;
                            final isBarPlayed = barFraction <= progress;
                            return Expanded(
                              child: Container(
                                margin: const EdgeInsets.symmetric(horizontal: 1.2),
                                height: _waveformHeights[index],
                                decoration: BoxDecoration(
                                  color: isBarPlayed ? playedBarColor : unplayedBarColor,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            );
                          }),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 6),

              // 3. WhatsApp 1x / 1.5x / 2x Speed Multiplier Pill
              InkWell(
                onTap: _cycleSpeed,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
                  decoration: BoxDecoration(
                    color: widget.isMyMessage
                        ? Colors.white.withValues(alpha: 0.2)
                        : (widget.isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_playbackSpeed == 1.0 ? '1' : _playbackSpeed}x',
                    style: GoogleFonts.inter(
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                      color: primaryAccent,
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 3),
          // Sub-row: Duration and Mic indicator
          Padding(
            padding: const EdgeInsets.only(left: 44, right: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isPlaying || _position > Duration.zero
                      ? '${_formatDuration(_position)} / ${_formatDuration(_duration)}'
                      : _formatDuration(_duration),
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: widget.isMyMessage
                        ? Colors.white.withValues(alpha: 0.8)
                        : (widget.isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                  ),
                ),
                Icon(
                  Icons.mic_rounded,
                  size: 13,
                  color: widget.isMyMessage
                      ? Colors.white.withValues(alpha: 0.7)
                      : const Color(0xFF10B981),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
