import 'package:flutter/material.dart';

/// Enum representing the actor executing a workflow step
enum WorkflowRole {
  hq('HQ Command', Color(0xFF0F172A), Icons.account_balance_rounded),
  dcAdmin('DC Supervisor', Color(0xFF1E293B), Icons.warehouse_rounded),
  rider('Dispatch Rider', Color(0xFF334155), Icons.delivery_dining_rounded),
  client('Merchant Client', Color(0xFF475569), Icons.storefront_rounded),
  customer('End Customer', Color(0xFF0F172A), Icons.person_rounded),
  system('Automated System', Color(0xFF64748B), Icons.memory_rounded);

  final String label;
  final Color badgeColor;
  final IconData icon;

  const WorkflowRole(this.label, this.badgeColor, this.icon);
}

/// Type of node in an interactive flowchart
enum FlowNodeType {
  start,
  process,
  decision,
  branchCash,
  branchDirect,
  end,
}

/// Represents a branch path leading from a decision node
class WorkflowBranch {
  final String id;
  final String label;
  final String condition;
  final String destinationTitle;
  final String badgeText;
  final Color accentColor;
  final List<String> details;

  const WorkflowBranch({
    required this.id,
    required this.label,
    required this.condition,
    required this.destinationTitle,
    required this.badgeText,
    required this.accentColor,
    required this.details,
  });
}

/// Represents an individual step/node in a workflow
class WorkflowNode {
  final String id;
  final int stepNumber;
  final String title;
  final String description;
  final WorkflowRole role;
  final FlowNodeType nodeType;
  final IconData icon;
  final List<String> technicalDetails;
  final List<WorkflowBranch>? branches;
  final String? ruleReference; // e.g. BR-004, BR-021

  const WorkflowNode({
    required this.id,
    required this.stepNumber,
    required this.title,
    required this.description,
    required this.role,
    this.nodeType = FlowNodeType.process,
    required this.icon,
    required this.technicalDetails,
    this.branches,
    this.ruleReference,
  });
}

/// Mermaid diagram specification for technical inspection
class MermaidSpec {
  final String diagramType; // e.g. graph TD, sequenceDiagram
  final String code;
  final String description;

  const MermaidSpec({
    required this.diagramType,
    required this.code,
    required this.description,
  });
}

/// Operational rule mapping
class OperationalRule {
  final String id; // e.g. BR-001
  final String category;
  final String rule;
  final String operationalImpact;

  const OperationalRule({
    required this.id,
    required this.category,
    required this.rule,
    required this.operationalImpact,
  });
}

/// Complete definition of one of the 7 operational subtab domains
class WorkflowDomain {
  final String id;
  final String title;
  final String shortTitle;
  final String subtitle;
  final String overview;
  final IconData icon;
  final Color accentColor;
  final List<WorkflowRole> activeRoles;
  final List<WorkflowNode> nodes;
  final MermaidSpec mermaidSpec;
  final List<OperationalRule> operationalRules;
  final Map<String, String> keyMetrics;

  const WorkflowDomain({
    required this.id,
    required this.title,
    required this.shortTitle,
    required this.subtitle,
    required this.overview,
    required this.icon,
    required this.accentColor,
    required this.activeRoles,
    required this.nodes,
    required this.mermaidSpec,
    required this.operationalRules,
    required this.keyMetrics,
  });
}
