import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../domain/entities/merchant_bi_message.dart';

/// Official Mermaid diagram parser and interactive visual renderer for NovaBI
class MerchantBIMermaidWidget extends StatefulWidget {
  final MerchantBIChartPayload payload;
  final bool isDark;
  final String? rawMermaidCode;

  const MerchantBIMermaidWidget({
    super.key,
    required this.payload,
    required this.isDark,
    this.rawMermaidCode,
  });

  @override
  State<MerchantBIMermaidWidget> createState() => _MerchantBIMermaidWidgetState();
}

class _MerchantBIMermaidWidgetState extends State<MerchantBIMermaidWidget> {
  bool _showRawCode = false;
  bool _isCopied = false;

  String get _effectiveCode {
    if (widget.rawMermaidCode != null && widget.rawMermaidCode!.trim().isNotEmpty) {
      return widget.rawMermaidCode!.trim();
    }
    if (widget.payload.mermaidCode != null && widget.payload.mermaidCode!.trim().isNotEmpty) {
      return widget.payload.mermaidCode!.trim();
    }
    return '''flowchart TD
  A[Order Placed & Booked] --> B[DC Dispatch Handover]
  B --> C{Delivery Confirmed?}
  C -->|Yes| D[Cash Settled & Remitted]
  C -->|No| E[Returned to Hub]''';
  }

  void _copyCode() {
    Clipboard.setData(ClipboardData(text: _effectiveCode));
    setState(() => _isCopied = true);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text(
              'Mermaid diagram code copied to clipboard',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _isCopied = false);
    });
  }

  void _openFullscreenModal() {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: widget.isDark ? const Color(0xFF0F172A) : Colors.white,
        insetPadding: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: double.infinity,
          height: MediaQuery.of(ctx).size.height * 0.85,
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Modal Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.payload.title.isNotEmpty
                              ? widget.payload.title
                              : 'Mermaid Diagram Canvas',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: widget.isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'Pinch or scroll to zoom • Drag to pan canvas',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: widget.isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
              const Divider(height: 20),
              // Zoomable & Pannable Canvas
              Expanded(
                child: InteractiveViewer(
                  boundaryMargin: const EdgeInsets.all(80),
                  minScale: 0.4,
                  maxScale: 3.5,
                  child: Center(
                    child: SingleChildScrollView(
                      child: _buildVisualDiagram(isExpanded: true),
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

  @override
  Widget build(BuildContext context) {
    final title = widget.payload.title.isNotEmpty
        ? widget.payload.title
        : 'Process Architecture Diagram';
    final subtitle = widget.payload.subtitle ?? 'NovaBI Official Mermaid Illustration';

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: widget.isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: widget.isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Header Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 10, 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              title,
                              style: GoogleFonts.inter(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: widget.isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF8B5CF6).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(5),
                              border: Border.all(
                                color: const Color(0xFF8B5CF6).withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.account_tree_rounded,
                                  size: 10,
                                  color: Color(0xFF8B5CF6),
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  'MERMAID',
                                  style: GoogleFonts.inter(
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF8B5CF6),
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: widget.isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ],
                  ),
                ),
                // Action Buttons
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Code / Diagram View Toggle
                    IconButton(
                      tooltip: _showRawCode ? 'Show Visual Diagram' : 'View Mermaid Code',
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.all(4),
                      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                      icon: Icon(
                        _showRawCode ? Icons.schema_rounded : Icons.code_rounded,
                        size: 16,
                        color: const Color(0xFF8B5CF6),
                      ),
                      onPressed: () => setState(() => _showRawCode = !_showRawCode),
                    ),
                    // Copy Code Button
                    IconButton(
                      tooltip: 'Copy Mermaid Code',
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.all(4),
                      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                      icon: Icon(
                        _isCopied ? Icons.check_rounded : Icons.copy_rounded,
                        size: 15,
                        color: _isCopied
                            ? const Color(0xFF10B981)
                            : (widget.isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                      ),
                      onPressed: _copyCode,
                    ),
                    // Fullscreen Canvas Button
                    IconButton(
                      tooltip: 'Fullscreen Canvas',
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.all(4),
                      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                      icon: Icon(
                        Icons.fullscreen_rounded,
                        size: 18,
                        color: widget.isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                      onPressed: _openFullscreenModal,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // 2. Diagram Body (Visual or Raw Code)
          Padding(
            padding: const EdgeInsets.all(12),
            child: _showRawCode ? _buildRawCodeView() : _buildVisualDiagram(),
          ),
        ],
      ),
    );
  }

  /// Builds raw syntax view with copy button and code styling
  Widget _buildRawCodeView() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: widget.isDark ? const Color(0xFF0B1120) : const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: widget.isDark ? const Color(0xFF1E293B) : const Color(0xFF334155),
        ),
      ),
      child: SelectableText(
        _effectiveCode,
        style: GoogleFonts.jetBrainsMono(
          fontSize: 11.5,
          color: const Color(0xFFE2E8F0),
          height: 1.45,
        ),
      ),
    );
  }

  /// Parses Mermaid code and builds high-fidelity visual connected nodes
  Widget _buildVisualDiagram({bool isExpanded = false}) {
    final parsed = _MermaidParser.parse(_effectiveCode);

    if (parsed.isSequenceDiagram) {
      return _buildSequenceDiagramView(parsed, isExpanded);
    }

    return _buildFlowchartDiagramView(parsed, isExpanded);
  }

  Widget _buildFlowchartDiagramView(_ParsedMermaid parsed, bool isExpanded) {
    if (parsed.nodes.isEmpty) {
      return _buildFallbackEmptyView();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (int i = 0; i < parsed.nodes.length; i++) ...[
          _buildNodeCard(parsed.nodes[i], i, parsed.nodes.length, isExpanded),
          if (i < parsed.nodes.length - 1)
            _buildConnector(
              label: i < parsed.edges.length ? parsed.edges[i].label : null,
              edgeType: i < parsed.edges.length ? parsed.edges[i].edgeType : 'solid',
            ),
        ],
      ],
    );
  }

  Widget _buildSequenceDiagramView(_ParsedMermaid parsed, bool isExpanded) {
    final participants = parsed.participants;
    final messages = parsed.sequenceMessages;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Participant Header Pills
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: participants.map((actor) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.25),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.person_pin_rounded, color: Colors.white, size: 14),
                  const SizedBox(width: 5),
                  Text(
                    actor,
                    style: GoogleFonts.inter(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        // Sequence Messages
        for (int i = 0; i < messages.length; i++) ...[
          _buildSequenceMessageRow(messages[i], i + 1),
          if (i < messages.length - 1) const SizedBox(height: 8),
        ],
      ],
    );
  }

  Widget _buildSequenceMessageRow(_SequenceMessage msg, int step) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: widget.isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: widget.isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFF8B5CF6).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '$step',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF8B5CF6),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      msg.from,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF6366F1),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Icon(
                        msg.isDotted ? Icons.east_outlined : Icons.arrow_forward_rounded,
                        size: 13,
                        color: widget.isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                      ),
                    ),
                    Text(
                      msg.to,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF10B981),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  msg.message,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: widget.isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNodeCard(
    _MermaidNode node,
    int index,
    int total,
    bool isExpanded,
  ) {
    final color = _resolveNodeAccent(node.shape, index, total);
    final isDecision = node.shape == _NodeShape.decision;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: widget.isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(isDecision ? 8 : 12),
        border: Border.all(
          color: color.withValues(alpha: 0.45),
          width: isDecision ? 1.5 : 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: widget.isDark ? 0.2 : 0.03),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Step & Shape Badge
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(isDecision ? 6 : 8),
              border: Border.all(color: color.withValues(alpha: 0.3)),
            ),
            child: Center(
              child: Icon(
                _resolveNodeIcon(node.shape, node.label),
                size: 16,
                color: color,
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Step ${index + 1}',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                    if (isDecision) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'DECISION',
                          style: GoogleFonts.inter(
                            fontSize: 8,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFFF59E0B),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  node.label,
                  style: GoogleFonts.inter(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: widget.isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConnector({String? label, required String edgeType}) {
    return Column(
      children: [
        Container(
          width: 2,
          height: 10,
          color: widget.isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
        ),
        if (label != null && label.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: widget.isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
                color: widget.isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
              ),
            ),
          ),
          Container(
            width: 2,
            height: 10,
            color: widget.isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
          ),
        ] else ...[
          Icon(
            Icons.arrow_downward_rounded,
            size: 14,
            color: widget.isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
          ),
        ],
      ],
    );
  }

  Widget _buildFallbackEmptyView() {
    return Container(
      padding: const EdgeInsets.all(16),
      alignment: Alignment.center,
      child: Text(
        'Rendering illustration...',
        style: GoogleFonts.inter(
          fontSize: 12,
          color: widget.isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
        ),
      ),
    );
  }

  Color _resolveNodeAccent(_NodeShape shape, int index, int total) {
    if (shape == _NodeShape.decision) return const Color(0xFFF59E0B);
    if (shape == _NodeShape.database) return const Color(0xFF0D9488);
    if (index == 0) return const Color(0xFF3B82F6);
    if (index == total - 1) return const Color(0xFF10B981);
    return const Color(0xFF6366F1);
  }

  IconData _resolveNodeIcon(_NodeShape shape, String label) {
    final lower = label.toLowerCase();
    if (shape == _NodeShape.decision || lower.contains('?')) {
      return Icons.help_outline_rounded;
    }
    if (shape == _NodeShape.database || lower.contains('database') || lower.contains('stock')) {
      return Icons.storage_rounded;
    }
    if (lower.contains('dispatch') || lower.contains('rider') || lower.contains('transit')) {
      return Icons.local_shipping_rounded;
    }
    if (lower.contains('settle') || lower.contains('cash') || lower.contains('payout') || lower.contains('pay')) {
      return Icons.payments_rounded;
    }
    if (lower.contains('order') || lower.contains('book')) {
      return Icons.receipt_long_rounded;
    }
    if (lower.contains('qc') || lower.contains('inspect') || lower.contains('verify')) {
      return Icons.fact_check_rounded;
    }
    if (lower.contains('return') || lower.contains('failed')) {
      return Icons.replay_rounded;
    }
    return Icons.check_circle_outline_rounded;
  }
}

enum _NodeShape { box, rounded, pill, database, decision, circle }

class _MermaidNode {
  final String id;
  final String label;
  final _NodeShape shape;

  const _MermaidNode({
    required this.id,
    required this.label,
    required this.shape,
  });
}

class _MermaidEdge {
  final String fromId;
  final String toId;
  final String? label;
  final String edgeType;

  const _MermaidEdge({
    required this.fromId,
    required this.toId,
    this.label,
    this.edgeType = 'solid',
  });
}

class _SequenceMessage {
  final String from;
  final String to;
  final String message;
  final bool isDotted;

  const _SequenceMessage({
    required this.from,
    required this.to,
    required this.message,
    this.isDotted = false,
  });
}

class _ParsedMermaid {
  final bool isSequenceDiagram;
  final List<_MermaidNode> nodes;
  final List<_MermaidEdge> edges;
  final List<String> participants;
  final List<_SequenceMessage> sequenceMessages;

  const _ParsedMermaid({
    this.isSequenceDiagram = false,
    this.nodes = const [],
    this.edges = const [],
    this.participants = const [],
    this.sequenceMessages = const [],
  });
}

class _MermaidParser {
  static _ParsedMermaid parse(String code) {
    final lines = code
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty && !l.startsWith('%%'))
        .toList();

    if (lines.isEmpty) return const _ParsedMermaid();

    final firstLine = lines.first.toLowerCase();
    if (firstLine.contains('sequencediagram')) {
      return _parseSequence(lines.sublist(1));
    }

    return _parseFlowchart(lines);
  }

  static _ParsedMermaid _parseSequence(List<String> lines) {
    final participants = <String>{};
    final messages = <_SequenceMessage>[];

    final arrowRegex = RegExp(r'^(.+?)(->>|-->>|->|-->)(.+?):(.*)$');
    final participantRegex = RegExp(r'^participant\s+(.+?)(?:as\s+(.+))?$');

    for (final line in lines) {
      final partMatch = participantRegex.firstMatch(line);
      if (partMatch != null) {
        final name = (partMatch.group(2) ?? partMatch.group(1)!).trim();
        participants.add(name);
        continue;
      }

      final arrowMatch = arrowRegex.firstMatch(line);
      if (arrowMatch != null) {
        final from = arrowMatch.group(1)!.trim();
        final arrow = arrowMatch.group(2)!.trim();
        final to = arrowMatch.group(3)!.trim();
        final text = arrowMatch.group(4)!.trim();

        participants.add(from);
        participants.add(to);

        messages.add(
          _SequenceMessage(
            from: from,
            to: to,
            message: text,
            isDotted: arrow.contains('--'),
          ),
        );
      }
    }

    return _ParsedMermaid(
      isSequenceDiagram: true,
      participants: participants.toList(),
      sequenceMessages: messages,
    );
  }

  static _ParsedMermaid _parseFlowchart(List<String> lines) {
    final nodesMap = <String, _MermaidNode>{};
    final edges = <_MermaidEdge>[];

    // Regex to match edge line: NodeA -->|Label| NodeB or NodeA --> NodeB
    final edgeRegex = RegExp(r'(.+?)(-->|-\.->|==>|---|--)(?:\|(.*?)\|)?(.+)');

    for (final line in lines) {
      if (line.startsWith('graph') ||
          line.startsWith('flowchart') ||
          line.startsWith('subgraph') ||
          line.startsWith('end')) {
        continue;
      }

      final match = edgeRegex.firstMatch(line);
      if (match != null) {
        final leftStr = match.group(1)!.trim();
        final arrow = match.group(2)!.trim();
        final edgeLabel = match.group(3)?.trim();
        final rightStr = match.group(4)!.trim();

        final leftNode = _parseSingleNode(leftStr);
        final rightNode = _parseSingleNode(rightStr);

        if (leftNode != null) _addOrUpdateNode(nodesMap, leftNode);
        if (rightNode != null) _addOrUpdateNode(nodesMap, rightNode);

        if (leftNode != null && rightNode != null) {
          edges.add(
            _MermaidEdge(
              fromId: leftNode.id,
              toId: rightNode.id,
              label: edgeLabel,
              edgeType: arrow.contains('-.') ? 'dotted' : (arrow.contains('==') ? 'thick' : 'solid'),
            ),
          );
        }
      } else {
        final single = _parseSingleNode(line);
        if (single != null) {
          nodesMap[single.id] = single;
        }
      }
    }

    // Preserve order
    return _ParsedMermaid(
      isSequenceDiagram: false,
      nodes: nodesMap.values.toList(),
      edges: edges,
    );
  }

  static void _addOrUpdateNode(Map<String, _MermaidNode> map, _MermaidNode node) {
    if (!map.containsKey(node.id)) {
      map[node.id] = node;
    } else {
      final existing = map[node.id]!;
      if (node.label != node.id && existing.label == existing.id) {
        map[node.id] = node;
      }
    }
  }

  static _MermaidNode? _parseSingleNode(String raw) {
    final str = raw.trim();
    if (str.isEmpty) return null;

    // Decision: ID{Label}
    final decisionMatch = RegExp(r'^([a-zA-Z0-9_\-]+)\s*\{(.*?)\}$').firstMatch(str);
    if (decisionMatch != null) {
      return _MermaidNode(
        id: decisionMatch.group(1)!,
        label: decisionMatch.group(2)!.trim(),
        shape: _NodeShape.decision,
      );
    }

    // Database / Cylinder: ID[(Label)]
    final dbMatch = RegExp(r'^([a-zA-Z0-9_\-]+)\s*\[\((.*?)\)\]$').firstMatch(str);
    if (dbMatch != null) {
      return _MermaidNode(
        id: dbMatch.group(1)!,
        label: dbMatch.group(2)!.trim(),
        shape: _NodeShape.database,
      );
    }

    // Pill / Stadium: ID([Label])
    final pillMatch = RegExp(r'^([a-zA-Z0-9_\-]+)\s*\(\[(.*?)\]\)$').firstMatch(str);
    if (pillMatch != null) {
      return _MermaidNode(
        id: pillMatch.group(1)!,
        label: pillMatch.group(2)!.trim(),
        shape: _NodeShape.pill,
      );
    }

    // Rounded Box: ID(Label)
    final roundedMatch = RegExp(r'^([a-zA-Z0-9_\-]+)\s*\((.*?)\)$').firstMatch(str);
    if (roundedMatch != null) {
      return _MermaidNode(
        id: roundedMatch.group(1)!,
        label: roundedMatch.group(2)!.trim(),
        shape: _NodeShape.rounded,
      );
    }

    // Rect Box: ID[Label]
    final boxMatch = RegExp(r'^([a-zA-Z0-9_\-]+)\s*\[(.*?)\]$').firstMatch(str);
    if (boxMatch != null) {
      return _MermaidNode(
        id: boxMatch.group(1)!,
        label: boxMatch.group(2)!.trim(),
        shape: _NodeShape.box,
      );
    }

    // Raw Identifier without brackets
    final idMatch = RegExp(r'^([a-zA-Z0-9_\-]+)$').firstMatch(str);
    if (idMatch != null) {
      final val = idMatch.group(1)!;
      return _MermaidNode(id: val, label: val, shape: _NodeShape.box);
    }

    return null;
  }
}
