import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../config/theme.dart';
import '../models/workflow_models.dart';

/// Interactive hardware-accelerated Flutter Flowchart visualizer.
/// Renders workflow steps, animated photon connectors, role badges,
/// decision diamonds with branches (Cash vs Direct Payment),
/// and includes a Mermaid Syntax Code inspection drawer/tab.
/// Supports both Dark and Light modes.
class InteractiveFlowchart extends StatefulWidget {
  final WorkflowDomain domain;
  final ValueChanged<WorkflowNode>? onNodeSelected;
  final ValueChanged<WorkflowBranch>? onBranchSelected;
  final bool isLightMode;
  final bool showInternalInspector;

  const InteractiveFlowchart({
    super.key,
    required this.domain,
    this.onNodeSelected,
    this.onBranchSelected,
    this.isLightMode = false,
    this.showInternalInspector = true,
  });

  @override
  State<InteractiveFlowchart> createState() => _InteractiveFlowchartState();
}

class _InteractiveFlowchartState extends State<InteractiveFlowchart>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  WorkflowNode? _selectedNode;
  WorkflowBranch? _selectedBranch;
  bool _showMermaidCode = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();

    if (widget.domain.nodes.isNotEmpty) {
      _selectedNode = widget.domain.nodes.first;
      _selectedBranch = (_selectedNode!.branches != null && _selectedNode!.branches!.isNotEmpty)
          ? _selectedNode!.branches!.first
          : null;
    }
  }

  @override
  void didUpdateWidget(covariant InteractiveFlowchart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.domain.id != widget.domain.id) {
      _selectedNode = widget.domain.nodes.isNotEmpty ? widget.domain.nodes.first : null;
      _selectedBranch = (_selectedNode?.branches != null && _selectedNode!.branches!.isNotEmpty)
          ? _selectedNode!.branches!.first
          : null;
      _showMermaidCode = false;
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLight = widget.isLightMode;

    return Container(
      decoration: BoxDecoration(
        color: isLight ? Colors.white : PresentationTheme.deepNavy.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isLight
              ? const Color(0xFFE2E8F0)
              : widget.domain.accentColor.withValues(alpha: 0.25),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: isLight ? Colors.black.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.4),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Flowchart Header & Mermaid Code Toggle
          _buildFlowchartHeader(),

          Divider(height: 1, color: isLight ? const Color(0xFFE2E8F0) : const Color(0xFF1E293B)),

          // 2. Main Content: Flowchart Canvas OR Mermaid Syntax Viewer
          Expanded(
            child: _showMermaidCode ? _buildMermaidViewer() : _buildVisualFlowchart(),
          ),
        ],
      ),
    );
  }

  Widget _buildFlowchartHeader() {
    final isLight = widget.isLightMode;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isLight ? const Color(0xFFF8FAFC) : Colors.white.withValues(alpha: 0.02),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Row 1: Header title + Visual/Mermaid toggle
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: isLight ? const Color(0xFF0F172A) : widget.domain.accentColor,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(widget.domain.icon, size: 14, color: Colors.white),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'OPERATIONAL FLOWCHART',
                    style: PresentationTheme.codeMonoThemed(isLight).copyWith(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: isLight ? const Color(0xFF0F172A) : Colors.white,
                      letterSpacing: 0.6,
                    ),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildHeaderToggleButton(
                    label: 'Visual',
                    icon: Icons.account_tree_rounded,
                    isActive: !_showMermaidCode,
                    onTap: () => setState(() => _showMermaidCode = false),
                  ),
                  const SizedBox(width: 6),
                  _buildHeaderToggleButton(
                    label: 'Mermaid Code',
                    icon: Icons.code_rounded,
                    isActive: _showMermaidCode,
                    onTap: () => setState(() => _showMermaidCode = true),
                  ),
                ],
              ),
            ],
          ),

          if (!_showMermaidCode) ...[
            const SizedBox(height: 10),
            // Row 2: Step Jump Stepper Pills (each node has an equal wide click target)
            Row(
              children: widget.domain.nodes.map((node) {
                final bool isSelected = _selectedNode?.id == node.id;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          setState(() {
                            _selectedNode = node;
                            _selectedBranch = (node.branches != null && node.branches!.isNotEmpty)
                                ? node.branches!.first
                                : null;
                          });
                          widget.onNodeSelected?.call(node);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(vertical: 7),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? (isLight ? const Color(0xFF0F172A) : widget.domain.accentColor)
                                : (isLight ? Colors.white : Colors.white.withValues(alpha: 0.05)),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: isSelected
                                  ? (isLight ? const Color(0xFF0F172A) : widget.domain.accentColor)
                                  : (isLight ? const Color(0xFFCBD5E1) : Colors.white.withValues(alpha: 0.12)),
                              width: isSelected ? 1.5 : 1.0,
                            ),
                          ),
                          child: Text(
                            'Step ${node.stepNumber}',
                            style: PresentationTheme.codeMonoThemed(isLight).copyWith(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isSelected
                                  ? Colors.white
                                  : (isLight ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHeaderToggleButton({
    required String label,
    required IconData icon,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    final isLight = widget.isLightMode;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          color: isActive
              ? (isLight ? const Color(0xFF0F172A) : widget.domain.accentColor)
              : (isLight ? Colors.white : Colors.white.withValues(alpha: 0.04)),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isActive
                ? (isLight ? const Color(0xFF0F172A) : widget.domain.accentColor)
                : (isLight ? const Color(0xFFCBD5E1) : Colors.white.withValues(alpha: 0.12)),
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 14,
              color: isActive ? Colors.white : (isLight ? const Color(0xFF475569) : const Color(0xFF94A3B8)),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: PresentationTheme.codeMonoThemed(isLight).copyWith(
                fontSize: 11.5,
                fontWeight: FontWeight.bold,
                color: isActive ? Colors.white : (isLight ? const Color(0xFF334155) : const Color(0xFF94A3B8)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVisualFlowchart() {
    final isLight = widget.isLightMode;

    if (!widget.showInternalInspector) {
      return _buildFlowCanvas();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isWide = constraints.maxWidth > 800;

        if (isWide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left: Scrollable Interactive Flow Canvas
              Expanded(
                flex: 7,
                child: _buildFlowCanvas(),
              ),

              // Divider
              Container(width: 1, color: isLight ? const Color(0xFFE2E8F0) : const Color(0xFF1E293B)),

              // Right: Step Inspector Detail Sheet
              Expanded(
                flex: 5,
                child: _buildStepInspector(),
              ),
            ],
          );
        } else {
          // Compact vertical layout
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildFlowCanvas(shrinkWrap: true),
                const SizedBox(height: 16),
                _buildStepInspector(),
              ],
            ),
          );
        }
      },
    );
  }

  Widget _buildFlowCanvas({bool shrinkWrap = false}) {
    final nodes = widget.domain.nodes;

    final content = Column(
      children: [
        for (int i = 0; i < nodes.length; i++) ...[
          _buildNodeCard(nodes[i]),
          if (i < nodes.length - 1) _buildConnector(nodes[i]),
        ],
      ],
    );

    if (shrinkWrap) return content;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: content,
    );
  }

  Widget _buildNodeCard(WorkflowNode node) {
    final isLight = widget.isLightMode;
    final bool isSelected = _selectedNode?.id == node.id;
    final bool hasBranches = node.branches != null && node.branches!.isNotEmpty;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          setState(() {
            _selectedNode = node;
            _selectedBranch = (node.branches != null && node.branches!.isNotEmpty)
                ? node.branches!.first
                : null;
          });
          widget.onNodeSelected?.call(node);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.symmetric(vertical: 5),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isLight
                ? Colors.white
                : (isSelected
                    ? PresentationTheme.primaryNavy.withValues(alpha: 0.7)
                    : PresentationTheme.primaryNavy.withValues(alpha: 0.4)),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? (isLight ? const Color(0xFF0F172A) : widget.domain.accentColor)
                  : (isLight ? const Color(0xFFCBD5E1) : Colors.white.withValues(alpha: 0.1)),
              width: isSelected ? 2.0 : 1.2,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: isLight
                          ? const Color(0xFF0F172A).withValues(alpha: 0.12)
                          : widget.domain.accentColor.withValues(alpha: 0.25),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : (isLight
                    ? [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Row: Step Badge + Role Tag + Rule Reference
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      // Step Number Badge (Crisp Circle)
                      Container(
                        width: 28,
                        height: 28,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isSelected
                              ? (isLight ? const Color(0xFF0F172A) : widget.domain.accentColor)
                              : (isLight ? const Color(0xFFF1F5F9) : Colors.white.withValues(alpha: 0.1)),
                          border: isSelected
                              ? null
                              : Border.all(
                                  color: isLight ? const Color(0xFFCBD5E1) : Colors.white.withValues(alpha: 0.15),
                                ),
                        ),
                        child: Text(
                          '${node.stepNumber}',
                          style: PresentationTheme.codeMonoThemed(isLight).copyWith(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isSelected
                                ? Colors.white
                                : (isLight ? const Color(0xFF0F172A) : Colors.white),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),

                      // Monochromatic Role Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(
                          color: isLight ? const Color(0xFFF1F5F9) : Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: isLight ? const Color(0xFFCBD5E1) : Colors.white.withValues(alpha: 0.15),
                            width: 1.0,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              node.role.icon,
                              size: 13,
                              color: isLight ? const Color(0xFF475569) : Colors.white,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              node.role.label,
                              style: PresentationTheme.codeMonoThemed(isLight).copyWith(
                                fontSize: 10.5,
                                color: isLight ? const Color(0xFF0F172A) : Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  // Rule Tag (e.g. BR-003)
                  if (node.ruleReference != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isLight ? const Color(0xFFF1F5F9) : Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: isLight ? const Color(0xFFCBD5E1) : Colors.white.withValues(alpha: 0.15),
                        ),
                      ),
                      child: Text(
                        node.ruleReference!,
                        style: PresentationTheme.codeMonoThemed(isLight).copyWith(
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          color: isLight ? const Color(0xFF0F172A) : const Color(0xFFCBD5E1),
                        ),
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 12),

              // Title & Icon
              Row(
                children: [
                  Icon(
                    node.icon,
                    size: 18,
                    color: isSelected
                        ? (isLight ? const Color(0xFFEA580C) : widget.domain.accentColor)
                        : (isLight ? const Color(0xFF0F172A) : Colors.white),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      node.title,
                      style: PresentationTheme.titleMediumThemed(isLight).copyWith(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: isLight ? const Color(0xFF0F172A) : Colors.white,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 6),

              // Description (Bold & Clear for Projector)
              Text(
                node.description,
                style: PresentationTheme.bodyMediumThemed(isLight).copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isLight ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                  height: 1.45,
                ),
              ),

              // If node has branches (e.g. Orders Cash vs Direct Payment), render the branch choices!
              if (hasBranches) ...[
                const SizedBox(height: 14),
                _buildBranchesSection(node),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBranchesSection(WorkflowNode node) {
    final isLight = widget.isLightMode;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isLight ? const Color(0xFFF8FAFC) : Colors.black.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isLight ? const Color(0xFFCBD5E1) : Colors.white.withValues(alpha: 0.12),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.call_split_rounded, size: 15, color: Color(0xFFEA580C)),
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
          Row(
            children: node.branches!.map((branch) {
              final bool isBranchSelected = _selectedBranch?.id == branch.id;
              final bool isCash = branch.id == 'branch-cash';

              final Color activeBorderColor = isCash
                  ? const Color(0xFFEA580C)
                  : (isLight ? const Color(0xFF0F172A) : Colors.white);
              final Color activeBgColor = isCash
                  ? const Color(0xFFEA580C).withValues(alpha: isLight ? 0.12 : 0.22)
                  : (isLight ? const Color(0xFF0F172A).withValues(alpha: 0.08) : Colors.white.withValues(alpha: 0.12));
              final Color badgeColor = isCash
                  ? const Color(0xFFEA580C)
                  : (isLight ? const Color(0xFF0F172A) : Colors.white);

              return Expanded(
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      setState(() {
                        _selectedNode = node;
                        _selectedBranch = branch;
                      });
                      widget.onBranchSelected?.call(branch);
                    },
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isBranchSelected ? activeBgColor : (isLight ? Colors.white : Colors.white.withValues(alpha: 0.03)),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isBranchSelected ? activeBorderColor : (isLight ? const Color(0xFFCBD5E1) : Colors.white.withValues(alpha: 0.15)),
                          width: isBranchSelected ? 1.8 : 1.0,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                            decoration: BoxDecoration(
                              color: badgeColor.withValues(alpha: isLight ? 0.14 : 0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              branch.badgeText,
                              style: PresentationTheme.codeMonoThemed(isLight).copyWith(
                                fontSize: 9.5,
                                color: badgeColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            branch.label,
                            style: PresentationTheme.titleMediumThemed(isLight).copyWith(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: isLight ? const Color(0xFF0F172A) : Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            branch.condition,
                            style: PresentationTheme.bodySmallThemed(isLight).copyWith(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isLight ? const Color(0xFF334155) : const Color(0xFF94A3B8),
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildConnector(WorkflowNode node) {
    final isLight = widget.isLightMode;

    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final double pulseY = _pulseController.value;

        return SizedBox(
          height: 32,
          child: Center(
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Static Connector Line
                Container(
                  width: 2,
                  height: 32,
                  color: isLight ? const Color(0xFFCBD5E1) : Colors.white.withValues(alpha: 0.15),
                ),
                // Moving Photon Pulse
                Positioned(
                  top: pulseY * 26,
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: widget.domain.accentColor,
                      boxShadow: [
                        BoxShadow(
                          color: widget.domain.accentColor,
                          blurRadius: 6,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  ),
                ),
                // Downward Arrow Head at bottom
                Positioned(
                  bottom: 0,
                  child: Icon(
                    Icons.arrow_drop_down_rounded,
                    size: 16,
                    color: isLight ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStepInspector() {
    final isLight = widget.isLightMode;
    final node = _selectedNode;
    final branch = _selectedBranch;

    if (node == null) {
      return Container(
        padding: const EdgeInsets.all(24),
        alignment: Alignment.center,
        child: Text(
          'Select any step to view deep operational mechanics',
          style: PresentationTheme.bodySmallThemed(isLight),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Inspector Header Tag
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'OPERATIONAL SPECIFICATION',
                style: PresentationTheme.codeMonoThemed(isLight).copyWith(
                  fontSize: 10.5,
                  color: widget.domain.accentColor,
                  letterSpacing: 0.6,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: node.role.badgeColor.withValues(alpha: isLight ? 0.12 : 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Step ${node.stepNumber} of ${widget.domain.nodes.length}',
                  style: PresentationTheme.codeMonoThemed(isLight).copyWith(
                    fontSize: 10,
                    color: node.role.badgeColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Step Title
          Text(
            node.title,
            style: PresentationTheme.titleLargeThemed(isLight).copyWith(fontSize: 20),
          ),
          const SizedBox(height: 8),

          // Role Responsibility Tag
          Row(
            children: [
              Icon(node.role.icon, size: 14, color: node.role.badgeColor),
              const SizedBox(width: 6),
              Text(
                'Responsible Actor: ${node.role.label}',
                style: PresentationTheme.bodySmallThemed(isLight).copyWith(
                  fontSize: 12,
                  color: node.role.badgeColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Overview Text
          Text(
            node.description,
            style: PresentationTheme.bodyMediumThemed(isLight).copyWith(fontSize: 13.5, height: 1.5),
          ),
          const SizedBox(height: 20),

          // Technical Execution Details
          Text(
            'SYSTEM & TECHNICAL PROTOCOLS:',
            style: PresentationTheme.codeMonoThemed(isLight).copyWith(
              fontSize: 10,
              color: isLight ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 10),
          ...node.technicalDetails.map((detail) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: widget.domain.accentColor,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      detail,
                      style: PresentationTheme.bodySmallThemed(isLight).copyWith(
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),

          // If a branch is selected, show branch deep dive!
          if (branch != null) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: branch.accentColor.withValues(alpha: isLight ? 0.1 : 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: branch.accentColor.withValues(alpha: 0.4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.check_circle_rounded, size: 14, color: branch.accentColor),
                      const SizedBox(width: 6),
                      Text(
                        branch.label,
                        style: PresentationTheme.titleMediumThemed(isLight).copyWith(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: branch.accentColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    branch.destinationTitle,
                    style: PresentationTheme.bodySmallThemed(isLight).copyWith(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: isLight ? const Color(0xFF0F172A) : Colors.white,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ...branch.details.map((d) => Padding(
                        padding: const EdgeInsets.only(bottom: 5.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.arrow_right_rounded, size: 14, color: branch.accentColor),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                d,
                                style: PresentationTheme.bodySmallThemed(isLight).copyWith(
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )),
                ],
              ),
            ),
          ],

          // Operational Rule Callout if present
          if (node.ruleReference != null) ...[
            const SizedBox(height: 20),
            _buildRuleCallout(node.ruleReference!),
          ],
        ],
      ),
    );
  }

  Widget _buildRuleCallout(String ruleId) {
    final isLight = widget.isLightMode;

    final rule = widget.domain.operationalRules.firstWhere(
      (r) => r.id == ruleId,
      orElse: () => OperationalRule(
        id: ruleId,
        category: 'Governance',
        rule: 'Standard operational protocol enforced by DC and HQ.',
        operationalImpact: 'Enforces system integrity.',
      ),
    );

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isLight ? const Color(0xFFF8FAFC) : Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isLight ? const Color(0xFFE2E8F0) : Colors.white.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.gavel_rounded, size: 13, color: PresentationTheme.novaOrange),
              const SizedBox(width: 6),
              Text(
                '${rule.id} • ${rule.category.toUpperCase()} RULE',
                style: PresentationTheme.codeMonoThemed(isLight).copyWith(
                  fontSize: 10,
                  color: PresentationTheme.novaOrange,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            rule.rule,
            style: PresentationTheme.bodySmallThemed(isLight).copyWith(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: isLight ? const Color(0xFF0F172A) : Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Impact: ${rule.operationalImpact}',
            style: PresentationTheme.bodySmallThemed(isLight).copyWith(
              fontSize: 10.5,
              color: isLight ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMermaidViewer() {
    final isLight = widget.isLightMode;
    final spec = widget.domain.mermaidSpec;

    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Mermaid Header Info
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: isLight ? const Color(0xFF0F172A) : widget.domain.accentColor,
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(
                        spec.diagramType,
                        style: PresentationTheme.codeMonoThemed(isLight).copyWith(
                          fontSize: 11,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        spec.description,
                        style: PresentationTheme.titleMediumThemed(isLight).copyWith(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: isLight ? const Color(0xFF0F172A) : Colors.white,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),

              // Copy Button
              OutlinedButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: spec.code));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Mermaid diagram code copied to clipboard!'),
                      backgroundColor: isLight ? const Color(0xFF0F172A) : widget.domain.accentColor,
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
                icon: Icon(
                  Icons.copy_rounded,
                  size: 14,
                  color: isLight ? const Color(0xFF0F172A) : Colors.white,
                ),
                label: Text(
                  'Copy Mermaid',
                  style: PresentationTheme.codeMonoThemed(isLight).copyWith(
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                    color: isLight ? const Color(0xFF0F172A) : Colors.white,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                    color: isLight ? const Color(0xFFCBD5E1) : Colors.white.withValues(alpha: 0.25),
                    width: 1.2,
                  ),
                  backgroundColor: isLight ? Colors.white : Colors.white.withValues(alpha: 0.06),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Code Container (Monochromatic & High Contrast)
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: isLight ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isLight ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                  width: 1.2,
                ),
              ),
              child: SingleChildScrollView(
                child: SelectableText(
                  spec.code,
                  style: PresentationTheme.codeMonoThemed(isLight).copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isLight ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                    height: 1.55,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
