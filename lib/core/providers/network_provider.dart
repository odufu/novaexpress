import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../widgets/offline_sync_banner.dart';

class NetworkState {
  final SyncStatus status;
  final bool isSlow;
  final int latencyMs;
  final int pendingQueueCount;
  final DateTime lastChecked;

  const NetworkState({
    this.status = SyncStatus.online,
    this.isSlow = false,
    this.latencyMs = 0,
    this.pendingQueueCount = 0,
    required this.lastChecked,
  });

  bool get isOnline => status == SyncStatus.online;
  bool get isOffline => status == SyncStatus.offline;
  bool get isSyncing => status == SyncStatus.syncing;

  NetworkState copyWith({
    SyncStatus? status,
    bool? isSlow,
    int? latencyMs,
    int? pendingQueueCount,
    DateTime? lastChecked,
  }) {
    return NetworkState(
      status: status ?? this.status,
      isSlow: isSlow ?? this.isSlow,
      latencyMs: latencyMs ?? this.latencyMs,
      pendingQueueCount: pendingQueueCount ?? this.pendingQueueCount,
      lastChecked: lastChecked ?? this.lastChecked,
    );
  }
}

class NetworkNotifier extends StateNotifier<NetworkState> {
  Timer? _periodicCheckTimer;

  NetworkNotifier()
      : super(NetworkState(lastChecked: DateTime.now())) {
    // Only start periodic ping in real runtime, not in unit tests
    if (!const bool.fromEnvironment('flutter.test')) {
      _startMonitoring();
    }
  }

  void _startMonitoring() {
    _periodicCheckTimer?.cancel();
    _periodicCheckTimer = Timer.periodic(const Duration(seconds: 45), (_) {
      checkConnectivity();
    });
  }

  @override
  void dispose() {
    _periodicCheckTimer?.cancel();
    super.dispose();
  }

  void setOfflineManually(bool offline) {
    state = state.copyWith(
      status: offline ? SyncStatus.offline : SyncStatus.online,
      lastChecked: DateTime.now(),
    );
  }

  void setSlowNetworkManually(bool slow) {
    state = state.copyWith(isSlow: slow);
  }

  void updatePendingQueueCount(int count) {
    state = state.copyWith(pendingQueueCount: count);
  }

  Future<bool> checkConnectivity() async {
    final sw = Stopwatch()..start();
    try {
      final res = await http
          .get(Uri.parse('https://dns.google/resolve?name=example.com'))
          .timeout(const Duration(seconds: 4));
      sw.stop();
      final latency = sw.elapsedMilliseconds;
      final isSlow = latency > 1800; // >1.8s round trip considered slow

      state = state.copyWith(
        status: res.statusCode == 200 ? SyncStatus.online : SyncStatus.offline,
        isSlow: isSlow,
        latencyMs: latency,
        lastChecked: DateTime.now(),
      );
      return res.statusCode == 200;
    } catch (_) {
      sw.stop();
      state = state.copyWith(
        status: SyncStatus.offline,
        isSlow: false,
        latencyMs: sw.elapsedMilliseconds,
        lastChecked: DateTime.now(),
      );
      return false;
    }
  }
}

final networkProvider = StateNotifierProvider<NetworkNotifier, NetworkState>((ref) {
  return NetworkNotifier();
});

