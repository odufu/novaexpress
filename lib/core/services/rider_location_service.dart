import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class RiderLocationState {
  final double latitude;
  final double longitude;
  final double accuracyMeters;
  final bool isTracking;
  final bool isGpsLocked;
  final DateTime? lastRecordedAt;
  final String locationLabel;

  const RiderLocationState({
    this.latitude = 9.0765, // Wuse 2 default
    this.longitude = 7.4832,
    this.accuracyMeters = 4.5,
    this.isTracking = false,
    this.isGpsLocked = true,
    this.lastRecordedAt,
    this.locationLabel = 'Wuse 2, Abuja Central',
  });

  RiderLocationState copyWith({
    double? latitude,
    double? longitude,
    double? accuracyMeters,
    bool? isTracking,
    bool? isGpsLocked,
    DateTime? lastRecordedAt,
    String? locationLabel,
  }) {
    return RiderLocationState(
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      accuracyMeters: accuracyMeters ?? this.accuracyMeters,
      isTracking: isTracking ?? this.isTracking,
      isGpsLocked: isGpsLocked ?? this.isGpsLocked,
      lastRecordedAt: lastRecordedAt ?? this.lastRecordedAt,
      locationLabel: locationLabel ?? this.locationLabel,
    );
  }
}

class RiderLocationNotifier extends StateNotifier<RiderLocationState> {
  Timer? _telemetryTimer;

  RiderLocationNotifier() : super(RiderLocationState(lastRecordedAt: DateTime.now()));

  /// Starts live periodic GPS telemetry updates
  void startTracking({
    required String agentId,
    required Future<void> Function(double lat, double lng) broadcastCallback,
    Duration interval = const Duration(seconds: 30),
  }) {
    _telemetryTimer?.cancel();
    state = state.copyWith(isTracking: true, isGpsLocked: true);

    // Initial broadcast
    broadcastCallback(state.latitude, state.longitude);

    _telemetryTimer = Timer.periodic(interval, (_) async {
      if (!state.isTracking) return;
      state = state.copyWith(lastRecordedAt: DateTime.now());
      try {
        await broadcastCallback(state.latitude, state.longitude);
      } catch (e) {
        debugPrint('[RIDER_LOCATION_SERVICE] Telemetry broadcast notice: $e');
      }
    });
  }

  /// Stops tracking
  void stopTracking() {
    _telemetryTimer?.cancel();
    state = state.copyWith(isTracking: false);
  }

  /// Updates current coordinates manually (e.g. from GPS hardware or mock pin)
  void updatePosition({
    required double latitude,
    required double longitude,
    String? label,
    double accuracy = 3.0,
  }) {
    state = state.copyWith(
      latitude: latitude,
      longitude: longitude,
      accuracyMeters: accuracy,
      isGpsLocked: true,
      lastRecordedAt: DateTime.now(),
      locationLabel: label ?? '${latitude.toStringAsFixed(4)}°, ${longitude.toStringAsFixed(4)}°',
    );
  }

  /// Quick presets for development and testing
  void setPresetLocation(String presetName) {
    switch (presetName.toLowerCase()) {
      case 'wuse':
      case 'wuse 2':
        updatePosition(latitude: 9.0765, longitude: 7.4832, label: 'Wuse 2 (Abuja)');
        break;
      case 'maitama':
        updatePosition(latitude: 9.0882, longitude: 7.4933, label: 'Maitama District (Abuja)');
        break;
      case 'garki':
        updatePosition(latitude: 9.0345, longitude: 7.4891, label: 'Garki Area 11 (Abuja)');
        break;
      case 'asokoro':
        updatePosition(latitude: 9.0435, longitude: 7.5255, label: 'Asokoro District (Abuja)');
        break;
      case 'lekki':
        updatePosition(latitude: 6.4474, longitude: 3.4839, label: 'Admiralty Way, Lekki (Lagos)');
        break;
      case 'ikeja':
        updatePosition(latitude: 6.5922, longitude: 3.3556, label: 'Ikeja GRA (Lagos)');
        break;
    }
  }

  @override
  void dispose() {
    _telemetryTimer?.cancel();
    super.dispose();
  }
}

final riderLocationProvider = StateNotifierProvider<RiderLocationNotifier, RiderLocationState>((ref) {
  return RiderLocationNotifier();
});
