import 'package:flutter/material.dart';
import '../config/features.dart';
import '../models/feature_item.dart';

/// Ecosystem presentation state as prescribed in Section 23 of docs/presentation.md
class EcosystemState {
  final String? hoveredFeatureId;
  final String? focusedFeatureId;
  final String? selectedFeatureId;
  final bool isTransitioning;
  final double transitionProgress;
  final FeatureItem? activePresentationFeature;
  final bool isLightMode;

  const EcosystemState({
    this.hoveredFeatureId,
    this.focusedFeatureId,
    this.selectedFeatureId,
    this.isTransitioning = false,
    this.transitionProgress = 0.0,
    this.activePresentationFeature,
    this.isLightMode = true,
  });

  bool get isInPresentationMode => activePresentationFeature != null && !isTransitioning;

  EcosystemState copyWith({
    String? hoveredFeatureId,
    bool clearHovered = false,
    String? focusedFeatureId,
    bool clearFocused = false,
    String? selectedFeatureId,
    bool clearSelected = false,
    bool? isTransitioning,
    double? transitionProgress,
    FeatureItem? activePresentationFeature,
    bool clearPresentation = false,
    bool? isLightMode,
  }) {
    return EcosystemState(
      hoveredFeatureId: clearHovered ? null : (hoveredFeatureId ?? this.hoveredFeatureId),
      focusedFeatureId: clearFocused ? null : (focusedFeatureId ?? this.focusedFeatureId),
      selectedFeatureId: clearSelected ? null : (selectedFeatureId ?? this.selectedFeatureId),
      isTransitioning: isTransitioning ?? this.isTransitioning,
      transitionProgress: transitionProgress ?? this.transitionProgress,
      activePresentationFeature: clearPresentation
          ? null
          : (activePresentationFeature ?? this.activePresentationFeature),
      isLightMode: isLightMode ?? this.isLightMode,
    );
  }
}

/// Centralized Controller managing hover, selection, depth perception, navigation, and theme mode
class EcosystemController extends ChangeNotifier {
  EcosystemState _state = const EcosystemState();

  EcosystemState get state => _state;

  /// Toggle between Dark Mode and Light Mode
  void toggleThemeMode() {
    _state = _state.copyWith(isLightMode: !_state.isLightMode);
    notifyListeners();
  }

  /// Set theme mode explicitly
  void setThemeMode(bool isLight) {
    if (_state.isLightMode == isLight) return;
    _state = _state.copyWith(isLightMode: isLight);
    notifyListeners();
  }

  void setHovered(String? featureId) {
    if (_state.isTransitioning || _state.isInPresentationMode) return;
    if (_state.hoveredFeatureId == featureId) return;

    _state = _state.copyWith(
      hoveredFeatureId: featureId,
      clearHovered: featureId == null,
    );
    notifyListeners();
  }

  void setFocused(String? featureId) {
    if (_state.focusedFeatureId == featureId) return;
    _state = _state.copyWith(
      focusedFeatureId: featureId,
      clearFocused: featureId == null,
    );
    notifyListeners();
  }

  /// Begin the cinematic multi-phase transition into a feature presentation (Section 14)
  void startSelectionTransition(String featureId) {
    if (_state.isTransitioning) return;
    final feature = PresentationFeatures.findById(featureId);

    _state = _state.copyWith(
      selectedFeatureId: featureId,
      isTransitioning: true,
      transitionProgress: 0.0,
      activePresentationFeature: feature,
    );
    notifyListeners();
  }

  void updateTransitionProgress(double progress) {
    _state = _state.copyWith(transitionProgress: progress);
    notifyListeners();
  }

  void completeSelectionTransition() {
    _state = _state.copyWith(
      isTransitioning: false,
      transitionProgress: 1.0,
    );
    notifyListeners();
  }

  /// Return from presentation mode back to the orbiting ecosystem (preserves theme mode)
  void returnToEcosystem() {
    _state = EcosystemState(isLightMode: _state.isLightMode);
    notifyListeners();
  }

  /// Cycle to next/previous feature when inside presentation mode (ArrowLeft / ArrowRight)
  void cycleFeature({required bool forward}) {
    if (_state.activePresentationFeature == null) return;
    const all = PresentationFeatures.all;
    final currentIndex = all.indexWhere((f) => f.id == _state.activePresentationFeature!.id);
    if (currentIndex == -1) return;

    final nextIndex = forward
        ? (currentIndex + 1) % all.length
        : (currentIndex - 1 + all.length) % all.length;

    _state = _state.copyWith(
      activePresentationFeature: all[nextIndex],
      selectedFeatureId: all[nextIndex].id,
    );
    notifyListeners();
  }

  /// Direct jump to feature tab
  void selectFeature(FeatureItem feature) {
    _state = _state.copyWith(
      activePresentationFeature: feature,
      selectedFeatureId: feature.id,
    );
    notifyListeners();
  }
}
