import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../config/assets.dart';
import '../config/theme.dart';
import '../config/workflow_data.dart';
import '../controllers/ecosystem_controller.dart';
import '../models/feature_item.dart';
import '../models/workflow_models.dart';
import '../widgets/interactive_flowchart.dart';

/// Presentation Flow item representing a section/flow in the left carousel.
class PresentationFlowItem {
  final String id;
  final String stepBadge;
  final String flowLabel;
  final String title;
  final String summary;
  final WorkflowDomain domain;
  final IconData icon;
  final Color accentColor;

  const PresentationFlowItem({
    required this.id,
    required this.stepBadge,
    required this.flowLabel,
    required this.title,
    required this.summary,
    required this.domain,
    required this.icon,
    required this.accentColor,
  });
}

/// Uncluttered, Modern Feature Details Presentation Screen.
/// Left: Vertical animated card carousel with step badges, titles, and right pointer notch.
/// Right: Stage Container with Title, Simple Flow Diagram (Left Inner), and Explainer Highlights (Right Inner).
class FeaturePresentationScreen extends StatefulWidget {
  final FeatureItem feature;
  final EcosystemController controller;

  const FeaturePresentationScreen({
    super.key,
    required this.feature,
    required this.controller,
  });

  @override
  State<FeaturePresentationScreen> createState() => _FeaturePresentationScreenState();
}

class _FeaturePresentationScreenState extends State<FeaturePresentationScreen>
    with SingleTickerProviderStateMixin {
  late final ScrollController _carouselScrollController;
  late final AnimationController _stageAnimController;
  late final Animation<double> _stageFadeAnim;

  late List<PresentationFlowItem> _flows;
  late int _selectedFlowIndex;

  // Selected node and branch inside the active flow for the Explainer Highlights panel
  WorkflowNode? _selectedNode;
  WorkflowBranch? _selectedBranch;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
    _carouselScrollController = ScrollController();

    _stageAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );

    _stageFadeAnim = CurvedAnimation(
      parent: _stageAnimController,
      curve: Curves.easeOutCubic,
    );

    _initFlowItems();
    _initSelectionForFeature(widget.feature.id);
    _stageAnimController.forward();
  }

  void _initFlowItems() {
    _flows = [
      const PresentationFlowItem(
        id: 'intro',
        stepBadge: '1',
        flowLabel: 'INTRO',
        title: 'System Architecture',
        summary: 'National fulfillment & multi-tier command matrix',
        domain: PresentationWorkflowData.introDomain,
        icon: Icons.auto_awesome_rounded,
        accentColor: PresentationTheme.brightOrange,
      ),
      const PresentationFlowItem(
        id: 'structure',
        stepBadge: '2',
        flowLabel: 'FLOW 1',
        title: 'Structure & Matrix',
        summary: '4-Quadrant fulfillment & Sub-DC zero-state isolation',
        domain: PresentationWorkflowData.generalStructure,
        icon: Icons.hub_rounded,
        accentColor: Color(0xFF00E5FF),
      ),
      const PresentationFlowItem(
        id: 'riders',
        stepBadge: '3',
        flowLabel: 'FLOW 2',
        title: 'Creating Riders',
        summary: 'KYC verification, vehicle allocation & zone routing',
        domain: PresentationWorkflowData.creatingRiders,
        icon: Icons.badge_rounded,
        accentColor: Color(0xFF38BDF8),
      ),
      const PresentationFlowItem(
        id: 'products',
        stepBadge: '4',
        flowLabel: 'FLOW 3',
        title: 'Creating Products',
        summary: 'Merchant company attachment & SKU pricing tiers',
        domain: PresentationWorkflowData.creatingProducts,
        icon: Icons.inventory_2_rounded,
        accentColor: Color(0xFFA855F7),
      ),
      const PresentationFlowItem(
        id: 'sock',
        stepBadge: '5',
        flowLabel: 'FLOW 4',
        title: 'Stock & Custodies',
        summary: 'Warehouse bulk shelf ↔ rider saddlebag PIN custody',
        domain: PresentationWorkflowData.stockMovements,
        icon: Icons.swap_horiz_rounded,
        accentColor: Color(0xFF34D399),
      ),
      const PresentationFlowItem(
        id: 'remitance',
        stepBadge: '6',
        flowLabel: 'FLOW 5',
        title: 'Remittance Clearing',
        summary: 'Physical cash vault clearing & SHA-256 digital receipts',
        domain: PresentationWorkflowData.remittance,
        icon: Icons.account_balance_wallet_rounded,
        accentColor: Color(0xFFFBBF24),
      ),
      const PresentationFlowItem(
        id: 'orders',
        stepBadge: '7',
        flowLabel: 'FLOW 6',
        title: 'Orders Lifecycle',
        summary: 'Doorstep dispatch & 2 settlement branches (Cash vs Direct)',
        domain: PresentationWorkflowData.orders,
        icon: Icons.local_shipping_rounded,
        accentColor: Color(0xFFFF6D00),
      ),
      const PresentationFlowItem(
        id: 'scaling',
        stepBadge: '8',
        flowLabel: 'FLOW 7',
        title: 'Network Scaling',
        summary: 'Elastic multi-DC hub expansion & high-throughput routing',
        domain: PresentationWorkflowData.scaling,
        icon: Icons.trending_up_rounded,
        accentColor: Color(0xFFF43F5E),
      ),
    ];
  }

  void _initSelectionForFeature(String featureId) {
    int index = _flows.indexWhere((f) => f.id == featureId);
    if (index < 0) {
      if (featureId == 'payments') {
        index = _flows.indexWhere((f) => f.id == 'remitance');
      } else {
        index = 0;
      }
    }
    _selectedFlowIndex = index >= 0 ? index : 0;
    _updateSelectedNodeForCurrentFlow();
  }

  void _updateSelectedNodeForCurrentFlow() {
    final domain = _flows[_selectedFlowIndex].domain;
    if (domain.nodes.isNotEmpty) {
      _selectedNode = domain.nodes.first;
      _selectedBranch = (_selectedNode!.branches != null && _selectedNode!.branches!.isNotEmpty)
          ? _selectedNode!.branches!.first
          : null;
    } else {
      _selectedNode = null;
      _selectedBranch = null;
    }
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(covariant FeaturePresentationScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onControllerChanged);
      widget.controller.addListener(_onControllerChanged);
    }
    if (oldWidget.feature.id != widget.feature.id) {
      _selectFlowById(widget.feature.id);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    _carouselScrollController.dispose();
    _stageAnimController.dispose();
    super.dispose();
  }

  void _selectFlowIndex(int index) {
    if (index < 0 || index >= _flows.length) return;
    if (_selectedFlowIndex == index) return;

    setState(() {
      _selectedFlowIndex = index;
      _updateSelectedNodeForCurrentFlow();
    });

    _stageAnimController.reset();
    _stageAnimController.forward();

    // Auto-scroll the carousel so selected card is in view
    if (_carouselScrollController.hasClients) {
      final double targetOffset = (index * 96.0) - 120.0;
      _carouselScrollController.animateTo(
        targetOffset.clamp(0.0, _carouselScrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _selectFlowById(String id) {
    int index = _flows.indexWhere((f) => f.id == id);
    if (index < 0 && id == 'payments') {
      index = _flows.indexWhere((f) => f.id == 'remitance');
    }
    if (index >= 0) {
      _selectFlowIndex(index);
    }
  }

  void _selectPreviousFlow() {
    if (_selectedFlowIndex > 0) {
      _selectFlowIndex(_selectedFlowIndex - 1);
    }
  }

  void _selectNextFlow() {
    if (_selectedFlowIndex < _flows.length - 1) {
      _selectFlowIndex(_selectedFlowIndex + 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isLight = widget.controller.state.isLightMode;
    final currentFlow = _flows[_selectedFlowIndex];

    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.escape): () {
          widget.controller.returnToEcosystem();
        },
        const SingleActivator(LogicalKeyboardKey.arrowUp): _selectPreviousFlow,
        const SingleActivator(LogicalKeyboardKey.arrowDown): _selectNextFlow,
        const SingleActivator(LogicalKeyboardKey.arrowLeft): _selectPreviousFlow,
        const SingleActivator(LogicalKeyboardKey.arrowRight): _selectNextFlow,
        const SingleActivator(LogicalKeyboardKey.keyT): () {
          widget.controller.toggleThemeMode();
        },
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          backgroundColor: isLight ? PresentationTheme.lightBackground : PresentationTheme.deepNavy,
          body: Stack(
            children: [
              // 1. Ambient Background Gradient
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(0.6, -0.3),
                      radius: 1.4,
                      colors: isLight
                          ? [
                              const Color(0xFFEFF6FF),
                              PresentationTheme.lightSurface,
                              PresentationTheme.lightBackground,
                            ]
                          : const [
                              Color(0xFF0D2554),
                              PresentationTheme.primaryNavy,
                              PresentationTheme.deepNavy,
                            ],
                    ),
                  ),
                ),
              ),

              SafeArea(
                child: Column(
                  children: [
                    // 2. Top Header Bar with Prominent "BACK TO MAIN" and Theme Toggle
                    _buildTopHeaderBar(isLight, currentFlow),

                    // 3. Main Split Stage Layout: Left Carousel + Right Two-Column Stage
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Left Section: Carousel with Up/Down Arrows & Cards
                            SizedBox(
                              width: 320,
                              child: _buildVerticalCarousel(isLight),
                            ),

                            const SizedBox(width: 8),

                            // Right Section: Framed Stage Container (Flow Diagram + Explainer Highlights)
                            Expanded(
                              child: FadeTransition(
                                opacity: _stageFadeAnim,
                                child: _buildRightStageContainer(isLight, currentFlow),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Top Bar with "BACK TO MAIN" in the center, logo on the left, and theme switch on the right.
  Widget _buildTopHeaderBar(bool isLight, PresentationFlowItem currentFlow) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: isLight ? Colors.white : PresentationTheme.deepNavy.withValues(alpha: 0.9),
        border: Border(
          bottom: BorderSide(
            color: isLight ? const Color(0xFFE2E8F0) : Colors.white.withValues(alpha: 0.08),
            width: 1.0,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left: Brand Logo + Feature Crumb
          Row(
            children: [
              Image.asset(
                AppAssets.logo,
                height: 28,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Text(
                  'NovaXpress',
                  style: PresentationTheme.titleMediumThemed(isLight).copyWith(
                    fontWeight: FontWeight.bold,
                    color: PresentationTheme.novaOrange,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Container(
                width: 1,
                height: 18,
                color: isLight ? const Color(0xFFCBD5E1) : Colors.white.withValues(alpha: 0.15),
              ),
              const SizedBox(width: 14),
              Text(
                'SYSTEM PRESENTATION',
                style: PresentationTheme.codeMonoThemed(isLight).copyWith(
                  fontSize: 10.5,
                  letterSpacing: 0.8,
                  color: isLight ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),

          // Center: Authoritative "BACK TO MAIN" Button (Esc)
          OutlinedButton.icon(
            onPressed: () => widget.controller.returnToEcosystem(),
            icon: Icon(
              Icons.grid_view_rounded,
              size: 14,
              color: isLight ? const Color(0xFF0F172A) : Colors.white,
            ),
            label: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'BACK TO MAIN',
                  style: PresentationTheme.codeMonoThemed(isLight).copyWith(
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                    color: isLight ? const Color(0xFF0F172A) : Colors.white,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isLight ? const Color(0xFFE2E8F0) : Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Ecosystem (Esc)',
                    style: PresentationTheme.codeMonoThemed(isLight).copyWith(
                      fontSize: 9.5,
                      color: isLight ? const Color(0xFF475569) : const Color(0xFF94A3B8),
                    ),
                  ),
                ),
              ],
            ),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              backgroundColor: isLight
                  ? const Color(0xFFF1F5F9)
                  : Colors.white.withValues(alpha: 0.08),
              side: BorderSide(
                color: isLight
                    ? const Color(0xFFCBD5E1)
                    : Colors.white.withValues(alpha: 0.22),
                width: 1.2,
              ),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
          ),

          // Right: Flow Indicator & Theme Toggle
          Row(
            children: [
              // Active flow counter pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: currentFlow.accentColor.withValues(alpha: isLight ? 0.12 : 0.15),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: currentFlow.accentColor.withValues(alpha: isLight ? 0.4 : 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(currentFlow.icon, size: 12, color: currentFlow.accentColor),
                    const SizedBox(width: 6),
                    Text(
                      '${_selectedFlowIndex + 1} of ${_flows.length}',
                      style: PresentationTheme.codeMonoThemed(isLight).copyWith(
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        color: currentFlow.accentColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),

              // Sun/Moon Theme Toggle Button
              IconButton(
                onPressed: () => widget.controller.toggleThemeMode(),
                tooltip: isLight ? 'Switch to Dark Mode (T)' : 'Switch to Light Mode (T)',
                style: IconButton.styleFrom(
                  backgroundColor: isLight
                      ? const Color(0xFFF1F5F9)
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
            ],
          ),
        ],
      ),
    );
  }

  /// Left vertical animated carousel of cards with up/down arrows and right-pointing notch
  Widget _buildVerticalCarousel(bool isLight) {
    return Column(
      children: [
        // Up Navigation Arrow
        MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: _selectPreviousFlow,
            child: Container(
              height: 28,
              width: double.infinity,
              alignment: Alignment.center,
              margin: const EdgeInsets.only(bottom: 6),
              decoration: BoxDecoration(
                color: isLight ? Colors.white : Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isLight ? const Color(0xFFE2E8F0) : Colors.white.withValues(alpha: 0.08),
                ),
              ),
              child: Icon(
                Icons.keyboard_arrow_up_rounded,
                size: 20,
                color: _selectedFlowIndex > 0
                    ? (isLight ? const Color(0xFF0F172A) : Colors.white)
                    : (isLight ? const Color(0xFFCBD5E1) : Colors.white.withValues(alpha: 0.2)),
              ),
            ),
          ),
        ),

        // Scrollable List of Cards
        Expanded(
          child: ListView.builder(
            controller: _carouselScrollController,
            itemCount: _flows.length,
            padding: const EdgeInsets.symmetric(vertical: 4),
            itemBuilder: (context, index) {
              final flow = _flows[index];
              final bool isSelected = index == _selectedFlowIndex;

              return _buildCarouselCard(flow, index, isSelected, isLight);
            },
          ),
        ),

        // Down Navigation Arrow
        MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: _selectNextFlow,
            child: Container(
              height: 28,
              width: double.infinity,
              alignment: Alignment.center,
              margin: const EdgeInsets.only(top: 6),
              decoration: BoxDecoration(
                color: isLight ? Colors.white : Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isLight ? const Color(0xFFE2E8F0) : Colors.white.withValues(alpha: 0.08),
                ),
              ),
              child: Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 20,
                color: _selectedFlowIndex < _flows.length - 1
                    ? (isLight ? const Color(0xFF0F172A) : Colors.white)
                    : (isLight ? const Color(0xFFCBD5E1) : Colors.white.withValues(alpha: 0.2)),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCarouselCard(
    PresentationFlowItem flow,
    int index,
    bool isSelected,
    bool isLight,
  ) {
    final Color badgeBg = isSelected
        ? (isLight ? const Color(0xFFEA580C) : flow.accentColor)
        : (isLight ? const Color(0xFFF1F5F9) : Colors.white.withValues(alpha: 0.1));
    final Color badgeTextColor = isSelected
        ? Colors.white
        : (isLight ? const Color(0xFF0F172A) : Colors.white);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _selectFlowIndex(index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: EdgeInsets.only(
            top: 4,
            bottom: 4,
            left: isSelected ? 0 : 8,
            right: isSelected ? 0 : 8,
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // The Card Box
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: isLight
                      ? Colors.white
                      : (isSelected
                          ? PresentationTheme.primaryNavy.withValues(alpha: 0.6)
                          : Colors.white.withValues(alpha: 0.03)),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected
                        ? (isLight ? const Color(0xFF0F172A) : flow.accentColor)
                        : (isLight ? const Color(0xFFCBD5E1) : Colors.white.withValues(alpha: 0.1)),
                    width: isSelected ? 2.2 : 1.2,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: isLight
                                ? const Color(0xFF0F172A).withValues(alpha: 0.12)
                                : flow.accentColor.withValues(alpha: 0.3),
                            blurRadius: 14,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : (isLight
                          ? [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.02),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : null),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Step Number Circle Badge (Crisp & High Contrast)
                    Container(
                      width: 28,
                      height: 28,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: badgeBg,
                        border: isSelected
                            ? null
                            : Border.all(
                                color: isLight ? const Color(0xFFCBD5E1) : Colors.white.withValues(alpha: 0.15),
                              ),
                      ),
                      child: Text(
                        flow.stepBadge,
                        style: PresentationTheme.codeMonoThemed(isLight).copyWith(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: badgeTextColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Title & Summary Explainer
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                flow.flowLabel,
                                style: PresentationTheme.codeMonoThemed(isLight).copyWith(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: isSelected
                                      ? (isLight ? const Color(0xFFEA580C) : flow.accentColor)
                                      : (isLight ? const Color(0xFF475569) : const Color(0xFF94A3B8)),
                                ),
                              ),
                              Icon(
                                flow.icon,
                                size: 13,
                                color: isSelected
                                    ? (isLight ? const Color(0xFFEA580C) : flow.accentColor)
                                    : (isLight ? const Color(0xFF64748B) : Colors.white.withValues(alpha: 0.3)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            flow.title,
                            style: PresentationTheme.titleMediumThemed(isLight).copyWith(
                              fontSize: 14.5,
                              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w700,
                              color: isSelected
                                  ? (isLight ? const Color(0xFF0F172A) : Colors.white)
                                  : (isLight ? const Color(0xFF1E293B) : const Color(0xFFCBD5E1)),
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            flow.summary,
                            style: (isLight ? PresentationTheme.bodySmallThemed(true) : PresentationTheme.bodySmall).copyWith(
                              fontSize: 11.5,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                              color: isLight
                                  ? (isSelected ? const Color(0xFF334155) : const Color(0xFF64748B))
                                  : const Color(0xFF94A3B8),
                              height: 1.35,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Right-pointing Triangle Notch on Active Card (connecting into right stage)
              if (isSelected)
                Positioned(
                  right: -10,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: CustomPaint(
                      size: const Size(10, 20),
                      painter: _ActiveCardPointerPainter(
                        color: isLight ? Colors.white : flow.accentColor,
                        borderColor: isLight ? const Color(0xFF0F172A) : flow.accentColor,
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

  /// Right Stage Container: Top Header ("TITLLE") + Left Inner Box (Flow Diagram) + Right Inner Box (Explainer Highlights)
  Widget _buildRightStageContainer(bool isLight, PresentationFlowItem flow) {
    return Container(
      decoration: BoxDecoration(
        color: isLight ? Colors.white : PresentationTheme.primaryNavy.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isLight
              ? const Color(0xFFCBD5E1)
              : flow.accentColor.withValues(alpha: 0.25),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: isLight
                ? Colors.black.withValues(alpha: 0.04)
                : Colors.black.withValues(alpha: 0.35),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Stage Top Header: "TITLLE" in wireframe
          _buildStageHeader(isLight, flow),

          Divider(
            height: 1,
            color: isLight ? const Color(0xFFE2E8F0) : Colors.white.withValues(alpha: 0.08),
          ),

          // 2. Side-by-Side Content: Simple Flow Diagram (Left) + Explainer Highlights (Right)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Left Inner Box: "Simple Flow Diagram resides Here"
                  Expanded(
                    flex: 6,
                    child: _buildFlowDiagramBox(isLight, flow),
                  ),

                  const SizedBox(width: 16),

                  // Right Inner Box: "Explainer highlights stays here"
                  Expanded(
                    flex: 5,
                    child: _buildExplainerHighlightsBox(isLight, flow),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStageHeader(bool isLight, PresentationFlowItem flow) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: isLight ? const Color(0xFFF8FAFC) : Colors.white.withValues(alpha: 0.02),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Title + Subtitle
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 10,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: isLight ? const Color(0xFF0F172A) : flow.accentColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                        border: isLight
                            ? null
                            : Border.all(color: flow.accentColor.withValues(alpha: 0.4)),
                      ),
                      child: Text(
                        flow.domain.subtitle.toUpperCase(),
                        style: PresentationTheme.codeMonoThemed(isLight).copyWith(
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          color: isLight ? Colors.white : flow.accentColor,
                        ),
                      ),
                    ),
                    Text(
                      '${flow.domain.nodes.length} WORKFLOW STEPS',
                      style: PresentationTheme.codeMonoThemed(isLight).copyWith(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isLight ? const Color(0xFF475569) : const Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  flow.domain.title,
                  style: PresentationTheme.titleLargeThemed(isLight).copyWith(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: isLight ? const Color(0xFF0F172A) : Colors.white,
                  ),
                ),
              ],
            ),
          ),

          // Active Role Badges (Monochromatic Slates)
          Wrap(
            spacing: 6,
            children: flow.domain.activeRoles.map((role) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: isLight ? const Color(0xFFF1F5F9) : Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isLight ? const Color(0xFFCBD5E1) : Colors.white.withValues(alpha: 0.15),
                    width: 1.0,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      role.icon,
                      size: 13,
                      color: isLight ? const Color(0xFF475569) : Colors.white,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      role.label,
                      style: PresentationTheme.codeMonoThemed(isLight).copyWith(
                        fontSize: 10.5,
                        color: isLight ? const Color(0xFF0F172A) : Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  /// Left Inner Box: "Simple Flow Diagram resides Here"
  Widget _buildFlowDiagramBox(bool isLight, PresentationFlowItem flow) {
    return Container(
      decoration: BoxDecoration(
        color: isLight ? const Color(0xFFF8FAFC) : const Color(0xFF070E1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isLight ? const Color(0xFFE2E8F0) : Colors.white.withValues(alpha: 0.08),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InteractiveFlowchart(
        key: ValueKey('flow-${flow.domain.id}'),
        domain: flow.domain,
        isLightMode: isLight,
        showInternalInspector: false,
        onNodeSelected: (node) {
          setState(() {
            _selectedNode = node;
            _selectedBranch = (node.branches != null && node.branches!.isNotEmpty)
                ? node.branches!.first
                : null;
          });
        },
        onBranchSelected: (branch) {
          setState(() {
            _selectedBranch = branch;
          });
        },
      ),
    );
  }

  /// Right Inner Box: "Explainer highlights stays here"
  Widget _buildExplainerHighlightsBox(bool isLight, PresentationFlowItem flow) {
    final node = _selectedNode ?? (flow.domain.nodes.isNotEmpty ? flow.domain.nodes.first : null);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isLight ? Colors.white : const Color(0xFF091427),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isLight ? const Color(0xFFCBD5E1) : Colors.white.withValues(alpha: 0.08),
          width: 1.2,
        ),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Explainer Header Card
            Row(
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  size: 18,
                  color: Color(0xFFEA580C),
                ),
                const SizedBox(width: 8),
                Text(
                  'EXPLAINER HIGHLIGHTS',
                  style: PresentationTheme.codeMonoThemed(isLight).copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: isLight ? const Color(0xFF0F172A) : Colors.white,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // 2. Current Node Details
            if (node != null) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isLight ? const Color(0xFFF8FAFC) : Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isLight ? const Color(0xFFCBD5E1) : Colors.white.withValues(alpha: 0.1),
                    width: 1.2,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: isLight ? const Color(0xFF0F172A) : flow.accentColor,
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Text(
                            'STEP ${node.stepNumber}',
                            style: PresentationTheme.codeMonoThemed(isLight).copyWith(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        if (node.ruleReference != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: isLight ? const Color(0xFFF1F5F9) : Colors.white.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(5),
                              border: Border.all(
                                color: isLight ? const Color(0xFFCBD5E1) : Colors.white.withValues(alpha: 0.15),
                              ),
                            ),
                            child: Text(
                              node.ruleReference!,
                              style: PresentationTheme.codeMonoThemed(isLight).copyWith(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isLight ? const Color(0xFF0F172A) : Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      node.title,
                      style: PresentationTheme.titleMediumThemed(isLight).copyWith(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: isLight ? const Color(0xFF0F172A) : Colors.white,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      node.description,
                      style: (isLight ? PresentationTheme.bodySmallThemed(true) : PresentationTheme.bodySmall).copyWith(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: isLight ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                        height: 1.45,
                      ),
                    ),
                    if (node.technicalDetails.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      ...node.technicalDetails.map((tech) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 5),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '▪ ',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isLight ? const Color(0xFF0F172A) : const Color(0xFFEA580C),
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  tech,
                                  style: PresentationTheme.codeMonoThemed(isLight).copyWith(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: isLight ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],

            // 3. Two Settlement Branches Highlights (for Orders or when branches exist)
            if (node?.branches != null && node!.branches!.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isLight ? const Color(0xFFF8FAFC) : Colors.black.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isLight ? const Color(0xFFCBD5E1) : Colors.white.withValues(alpha: 0.12),
                    width: 1.2,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.account_balance_wallet_rounded, size: 16, color: Color(0xFFEA580C)),
                        const SizedBox(width: 6),
                        Text(
                          'TWO SUCCESSFUL OUTCOME BRANCHES:',
                          style: PresentationTheme.codeMonoThemed(isLight).copyWith(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isLight ? const Color(0xFF0F172A) : const Color(0xFFEA580C),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ...node.branches!.map((b) {
                      final isSelected = _selectedBranch?.id == b.id;
                      final isCash = b.id == 'branch-cash';

                      final Color branchBorder = isCash
                          ? const Color(0xFFEA580C)
                          : (isLight ? const Color(0xFF0F172A) : Colors.white);
                      final Color branchBg = isCash
                          ? const Color(0xFFEA580C).withValues(alpha: isLight ? 0.12 : 0.2)
                          : (isLight ? const Color(0xFF0F172A).withValues(alpha: 0.08) : Colors.white.withValues(alpha: 0.12));
                      final Color badgeColor = isCash
                          ? const Color(0xFFEA580C)
                          : (isLight ? const Color(0xFF0F172A) : Colors.white);

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isSelected ? branchBg : (isLight ? Colors.white : Colors.transparent),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSelected
                                ? branchBorder
                                : (isLight ? const Color(0xFFCBD5E1) : Colors.white.withValues(alpha: 0.12)),
                            width: isSelected ? 1.8 : 1.0,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${b.badgeText}: ${b.label}',
                              style: PresentationTheme.codeMonoThemed(isLight).copyWith(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: badgeColor,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              b.destinationTitle,
                              style: (isLight ? PresentationTheme.bodySmallThemed(true) : PresentationTheme.bodySmall).copyWith(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: isLight ? const Color(0xFF0F172A) : Colors.white,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              b.condition,
                              style: (isLight ? PresentationTheme.bodySmallThemed(true) : PresentationTheme.bodySmall).copyWith(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: isLight ? const Color(0xFF475569) : const Color(0xFF94A3B8),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],

            // 4. Key Metrics Grid
            Text(
              'KEY OPERATIONAL METRICS',
              style: PresentationTheme.codeMonoThemed(isLight).copyWith(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: isLight ? const Color(0xFF475569) : const Color(0xFF94A3B8),
                letterSpacing: 0.6,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: flow.domain.keyMetrics.entries.map((m) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isLight ? const Color(0xFFF8FAFC) : Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isLight ? const Color(0xFFCBD5E1) : Colors.white.withValues(alpha: 0.1),
                      width: 1.2,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        m.key.toUpperCase(),
                        style: PresentationTheme.codeMonoThemed(isLight).copyWith(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isLight ? const Color(0xFF475569) : const Color(0xFF94A3B8),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        m.value,
                        style: PresentationTheme.codeMonoThemed(isLight).copyWith(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFFEA580C),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // 5. Governing Business Rules
            Text(
              'GOVERNING BUSINESS RULES',
              style: PresentationTheme.codeMonoThemed(isLight).copyWith(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: isLight ? const Color(0xFF475569) : const Color(0xFF94A3B8),
                letterSpacing: 0.6,
              ),
            ),
            const SizedBox(height: 8),
            ...flow.domain.operationalRules.map((rule) {
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isLight ? const Color(0xFFF8FAFC) : Colors.white.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isLight ? const Color(0xFFCBD5E1) : Colors.white.withValues(alpha: 0.08),
                    width: 1.2,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          rule.id,
                          style: PresentationTheme.codeMonoThemed(isLight).copyWith(
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                            color: isLight ? const Color(0xFF0F172A) : Colors.white,
                          ),
                        ),
                        Text(
                          rule.category,
                          style: PresentationTheme.codeMonoThemed(isLight).copyWith(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: isLight ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      rule.rule,
                      style: (isLight ? PresentationTheme.bodySmallThemed(true) : PresentationTheme.bodySmall).copyWith(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isLight ? const Color(0xFF0F172A) : Colors.white,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Impact: ${rule.operationalImpact}',
                      style: (isLight ? PresentationTheme.bodySmallThemed(true) : PresentationTheme.bodySmall).copyWith(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: isLight ? const Color(0xFF475569) : const Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

/// Custom painter for the right-pointing triangle notch on the active carousel card
class _ActiveCardPointerPainter extends CustomPainter {
  final Color color;
  final Color borderColor;

  _ActiveCardPointerPainter({
    required this.color,
    required this.borderColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, size.height / 2)
      ..lineTo(0, size.height)
      ..close();

    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, fillPaint);

    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final borderPath = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, size.height / 2)
      ..lineTo(0, size.height);
    canvas.drawPath(borderPath, borderPaint);
  }

  @override
  bool shouldRepaint(covariant _ActiveCardPointerPainter oldDelegate) =>
      color != oldDelegate.color || borderColor != oldDelegate.borderColor;
}
