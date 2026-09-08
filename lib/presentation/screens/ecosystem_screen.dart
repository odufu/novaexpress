import 'package:flutter/material.dart';
import '../../config/assets.dart';
import '../config/constants.dart';
import '../config/features.dart';
import '../config/theme.dart';
import '../controllers/ecosystem_controller.dart';
import '../models/feature_item.dart';
import '../models/spatial_node.dart';
import '../painters/cinematic_background_painter.dart';
import '../painters/orbit_painter.dart';
import '../painters/particle_painter.dart';
import '../widgets/central_core.dart';
import '../widgets/feature_platform.dart';
import '../widgets/feature_tooltip.dart';

/// Ecosystem command center screen.
/// Section 2, 4, 10, 14 of docs/presentation.md.
class EcosystemScreen extends StatefulWidget {
  final EcosystemController controller;

  const EcosystemScreen({
    super.key,
    required this.controller,
  });

  @override
  State<EcosystemScreen> createState() => _EcosystemScreenState();
}

class _EcosystemScreenState extends State<EcosystemScreen> with TickerProviderStateMixin {
  // Continuous breathing and floating tickers
  late final AnimationController _breathingController;
  late final AnimationController _floatingController;
  late final AnimationController _pulseController;

  // Selection / Camera Zoom Transition controller
  late final AnimationController _transitionController;

  // Ambient particles
  late final List<AmbientParticle> _particles;

  @override
  void initState() {
    super.initState();
    _particles = ParticlePainter.generate(45);

    _breathingController = AnimationController(
      vsync: this,
      duration: PresentationConstants.coreBreathingDuration,
    )..repeat();

    _floatingController = AnimationController(
      vsync: this,
      duration: PresentationConstants.platformFloatDuration,
    )..repeat();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();

    _transitionController = AnimationController(
      vsync: this,
      duration: PresentationConstants.selectionTransitionDuration,
    );

    _transitionController.addListener(() {
      widget.controller.updateTransitionProgress(_transitionController.value);
    });

    _transitionController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.controller.completeSelectionTransition();
      }
    });

    widget.controller.addListener(_onControllerStateChanged);
  }

  void _onControllerStateChanged() {
    final state = widget.controller.state;
    if (state.isTransitioning && !_transitionController.isAnimating && _transitionController.value == 0.0) {
      _transitionController.forward();
    } else if (!state.isTransitioning && state.activePresentationFeature == null && _transitionController.value > 0.0) {
      _transitionController.reset();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerStateChanged);
    _breathingController.dispose();
    _floatingController.dispose();
    _pulseController.dispose();
    _transitionController.dispose();
    super.dispose();
  }

  void _onFeatureSelect(String featureId) {
    widget.controller.startSelectionTransition(featureId);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        widget.controller,
        _breathingController,
        _floatingController,
        _pulseController,
      ]),
      builder: (context, child) {
        final state = widget.controller.state;

        final isLight = state.isLightMode;

        return Scaffold(
          backgroundColor: PresentationTheme.bg(isLight),
          body: LayoutBuilder(
            builder: (context, constraints) {
              final Size viewportSize = Size(constraints.maxWidth, constraints.maxHeight);
              final Offset coreCenter = Offset(viewportSize.width / 2, viewportSize.height / 2);

              // Calculate resolved platform centers for orbital line connections
              final Map<String, Offset> platformCenters = {};
              for (final node in SpatialNode.defaultNodes) {
                platformCenters[node.featureId] = node.resolvePosition(viewportSize);
              }

              // Identify hovered feature for tooltip display
              FeatureItem? hoveredFeature;
              Offset? hoveredCenter;
              if (state.hoveredFeatureId != null) {
                hoveredFeature = PresentationFeatures.findById(state.hoveredFeatureId!);
                hoveredCenter = platformCenters[state.hoveredFeatureId!];
              }

              return Stack(
                fit: StackFit.expand,
                children: [
                  // 1. Cinematic Background & Technical Grid
                  RepaintBoundary(
                    child: CustomPaint(
                      size: viewportSize,
                      painter: CinematicBackgroundPainter(
                        transitionProgress: state.transitionProgress,
                        isLightMode: isLight,
                      ),
                    ),
                  ),

                  // 2. Ambient Particles
                  RepaintBoundary(
                    child: CustomPaint(
                      size: viewportSize,
                      painter: ParticlePainter(
                        animationValue: _floatingController.value,
                        particles: _particles,
                        isLightMode: isLight,
                      ),
                    ),
                  ),

                  // 3. Glowing Orbital Rings & Photon Connector Paths
                  RepaintBoundary(
                    child: CustomPaint(
                      size: viewportSize,
                      painter: OrbitPainter(
                        platformCenters: platformCenters,
                        coreCenter: coreCenter,
                        hoveredFeatureId: state.hoveredFeatureId,
                        selectedFeatureId: state.selectedFeatureId,
                        pulseValue: _pulseController.value,
                        transitionProgress: state.transitionProgress,
                        isLightMode: isLight,
                      ),
                    ),
                  ),

                  // 4. Central NovaXpress Command Core (Section 5)
                  CentralCore(
                    state: state,
                    breathingValue: _breathingController.value,
                    viewportSize: viewportSize,
                    onTap: () {
                      // Tapping core resets hover / selection
                      widget.controller.setHovered(null);
                    },
                  ),

                  // 5. Six Orbiting 3D Feature Platforms (Section 4 & 6)
                  ...SpatialNode.defaultNodes.map((node) {
                    final feature = PresentationFeatures.findById(node.featureId);
                    return FeaturePlatform(
                      key: ValueKey(node.featureId),
                      feature: feature,
                      node: node,
                      state: state,
                      floatAnimationValue: _floatingController.value,
                      viewportSize: viewportSize,
                      onHoverChanged: (id) => widget.controller.setHovered(id),
                      onSelect: (id) => _onFeatureSelect(id),
                    );
                  }),

                  // 6. Dynamic Glassmorphic Tooltip HUD Card (Section 11)
                  if (hoveredFeature != null && hoveredCenter != null && !state.isTransitioning)
                    FeatureTooltip(
                      feature: hoveredFeature,
                      platformCenter: hoveredCenter,
                      viewportSize: viewportSize,
                      onExploreTap: () => _onFeatureSelect(hoveredFeature!.id),
                      isLightMode: isLight,
                    ),

                  // 7. Top Branding & Title Header Bar
                  Positioned(
                    top: 24,
                    left: 32,
                    right: 32,
                    child: Opacity(
                      opacity: (1.0 - (state.transitionProgress * 2.0)).clamp(0.0, 1.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Authoritative Logo + Title
                          Row(
                            children: [
                              Image.asset(
                                AppAssets.logo,
                                height: 32,
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) => Text(
                                  'NovaXpress',
                                  style: PresentationTheme.titleLargeThemed(isLight).copyWith(
                                    fontSize: 22,
                                    color: PresentationTheme.novaOrange,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Container(
                                width: 1,
                                height: 20,
                                color: isLight ? const Color(0xFFCBD5E1) : Colors.white.withValues(alpha: 0.15),
                              ),
                              const SizedBox(width: 16),
                              Text(
                                'Interactive System Presentation',
                                style: PresentationTheme.bodySmallThemed(isLight).copyWith(
                                  color: isLight ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ],
                          ),

                          // Feature Menu Pills with synchronized hover highlights
                          if (viewportSize.width > 980)
                            Row(
                              children: PresentationFeatures.all.map((feature) {
                                final bool isHovered = state.hoveredFeatureId == feature.id;
                                final String displayLabel = feature.id == 'sock'
                                    ? 'Stock & Custodies'
                                    : feature.title;

                                return MouseRegion(
                                  cursor: SystemMouseCursors.click,
                                  onEnter: (_) => widget.controller.setHovered(feature.id),
                                  onExit: (_) => widget.controller.setHovered(null),
                                  child: GestureDetector(
                                    onTap: () => _onFeatureSelect(feature.id),
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 180),
                                      margin: const EdgeInsets.symmetric(horizontal: 4),
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                      decoration: BoxDecoration(
                                        color: isHovered
                                            ? feature.accentColor.withValues(alpha: isLight ? 0.14 : 0.22)
                                            : (isLight ? Colors.white : Colors.white.withValues(alpha: 0.04)),
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: isHovered
                                              ? feature.accentColor
                                              : (isLight ? const Color(0xFFE2E8F0) : Colors.white.withValues(alpha: 0.08)),
                                        ),
                                        boxShadow: isLight
                                            ? [
                                                BoxShadow(
                                                  color: Colors.black.withValues(alpha: 0.04),
                                                  blurRadius: 6,
                                                  offset: const Offset(0, 2),
                                                ),
                                              ]
                                            : null,
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            feature.fallbackIcon,
                                            size: 12,
                                            color: isHovered
                                                ? feature.accentColor
                                                : (isLight ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            displayLabel,
                                            style: PresentationTheme.codeMonoThemed(isLight).copyWith(
                                              fontSize: 10.5,
                                              color: isHovered
                                                  ? feature.accentColor
                                                  : (isLight ? const Color(0xFF1E293B) : const Color(0xFFCBD5E1)),
                                              fontWeight: isHovered ? FontWeight.bold : FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),

                          // Theme Toggle & Live HUD indicator
                          Row(
                            children: [
                              // Sun/Moon Theme Toggle
                              IconButton(
                                onPressed: () => widget.controller.toggleThemeMode(),
                                tooltip: isLight ? 'Switch to Dark Mode (T)' : 'Switch to Light Mode (T)',
                                style: IconButton.styleFrom(
                                  backgroundColor: isLight
                                      ? Colors.white
                                      : Colors.white.withValues(alpha: 0.06),
                                  side: BorderSide(
                                    color: isLight
                                        ? const Color(0xFFCBD5E1)
                                        : Colors.white.withValues(alpha: 0.14),
                                  ),
                                  padding: const EdgeInsets.all(8),
                                ),
                                icon: Icon(
                                  isLight ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                                  size: 16,
                                  color: isLight ? const Color(0xFF334155) : PresentationTheme.brightOrange,
                                ),
                              ),
                              const SizedBox(width: 12),

                              // Live HUD indicator
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                decoration: BoxDecoration(
                                  color: isLight ? Colors.white : PresentationTheme.primaryNavy.withValues(alpha: 0.6),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: PresentationTheme.novaOrange.withValues(alpha: isLight ? 0.45 : 0.3),
                                  ),
                                  boxShadow: isLight
                                      ? [
                                          BoxShadow(
                                            color: Colors.black.withValues(alpha: 0.04),
                                            blurRadius: 8,
                                          ),
                                        ]
                                      : null,
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 7,
                                      height: 7,
                                      decoration: const BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: PresentationTheme.brightOrange,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'COMMAND ECOSYSTEM ACTIVE',
                                      style: PresentationTheme.codeMonoThemed(isLight).copyWith(
                                        fontSize: 10,
                                        color: isLight ? const Color(0xFF0F172A) : PresentationTheme.brightOrange,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  // 8. Bottom Navigation Guidance Helper
                  Positioned(
                    bottom: 20,
                    left: 0,
                    right: 0,
                    child: Opacity(
                      opacity: (1.0 - (state.transitionProgress * 2.0)).clamp(0.0, 1.0),
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: isLight
                                ? Colors.white.withValues(alpha: 0.88)
                                : Colors.black.withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isLight
                                  ? const Color(0xFFE2E8F0)
                                  : Colors.white.withValues(alpha: 0.08),
                            ),
                            boxShadow: isLight
                                ? [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.06),
                                      blurRadius: 10,
                                      offset: const Offset(0, 2),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Text(
                            'Hover over any platform to inspect • Click to launch feature presentation',
                            style: PresentationTheme.bodySmallThemed(isLight).copyWith(
                              fontSize: 11.5,
                              color: isLight ? const Color(0xFF475569) : const Color(0xFF94A3B8),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}
