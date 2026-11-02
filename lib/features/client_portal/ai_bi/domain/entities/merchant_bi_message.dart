import 'package:flutter/material.dart';

enum MerchantBISender {
  user,
  ai,
  system,
}

enum BIChartType {
  donut,
  trend,
  flowchart,
  metricCards,
  mermaid,
}

class ChartSliceItem {
  final String label;
  final double value;
  final String formattedValue;
  final String colorHex;

  const ChartSliceItem({
    required this.label,
    required this.value,
    required this.formattedValue,
    required this.colorHex,
  });

  Color get color {
    final hex = colorHex.replaceAll('#', '');
    if (hex.length == 6) {
      return Color(int.parse('FF$hex', radix: 16));
    } else if (hex.length == 8) {
      return Color(int.parse(hex, radix: 16));
    }
    return const Color(0xFF10B981);
  }

  Map<String, dynamic> toJson() => {
        'label': label,
        'value': value,
        'formattedValue': formattedValue,
        'colorHex': colorHex,
      };

  factory ChartSliceItem.fromJson(Map<String, dynamic> json) => ChartSliceItem(
        label: json['label'] as String? ?? '',
        value: (json['value'] as num?)?.toDouble() ?? 0.0,
        formattedValue: json['formattedValue'] as String? ?? '',
        colorHex: json['colorHex'] as String? ?? '#10B981',
      );
}

class TrendBarItem {
  final String label;
  final double value;
  final String formattedValue;
  final String? subtitle;
  final String colorHex;

  const TrendBarItem({
    required this.label,
    required this.value,
    required this.formattedValue,
    this.subtitle,
    required this.colorHex,
  });

  Color get color {
    final hex = colorHex.replaceAll('#', '');
    if (hex.length == 6) {
      return Color(int.parse('FF$hex', radix: 16));
    }
    return const Color(0xFF6366F1);
  }

  Map<String, dynamic> toJson() => {
        'label': label,
        'value': value,
        'formattedValue': formattedValue,
        'subtitle': subtitle,
        'colorHex': colorHex,
      };

  factory TrendBarItem.fromJson(Map<String, dynamic> json) => TrendBarItem(
        label: json['label'] as String? ?? '',
        value: (json['value'] as num?)?.toDouble() ?? 0.0,
        formattedValue: json['formattedValue'] as String? ?? '',
        subtitle: json['subtitle'] as String?,
        colorHex: json['colorHex'] as String? ?? '#6366F1',
      );
}

class FlowchartNode {
  final String id;
  final String stepNumber;
  final String title;
  final String description;
  final String nodeType; // 'start', 'process', 'decision', 'success', 'warning', 'end'
  final String? iconName;
  final String? tag;

  const FlowchartNode({
    required this.id,
    required this.stepNumber,
    required this.title,
    required this.description,
    this.nodeType = 'process',
    this.iconName,
    this.tag,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'stepNumber': stepNumber,
        'title': title,
        'description': description,
        'nodeType': nodeType,
        'iconName': iconName,
        'tag': tag,
      };

  factory FlowchartNode.fromJson(Map<String, dynamic> json) => FlowchartNode(
        id: json['id'] as String? ?? '',
        stepNumber: json['stepNumber'] as String? ?? '1',
        title: json['title'] as String? ?? '',
        description: json['description'] as String? ?? '',
        nodeType: json['nodeType'] as String? ?? 'process',
        iconName: json['iconName'] as String?,
        tag: json['tag'] as String?,
      );
}

class FlowchartConnection {
  final String fromId;
  final String toId;
  final String? label;

  const FlowchartConnection({
    required this.fromId,
    required this.toId,
    this.label,
  });

  Map<String, dynamic> toJson() => {
        'fromId': fromId,
        'toId': toId,
        'label': label,
      };

  factory FlowchartConnection.fromJson(Map<String, dynamic> json) =>
      FlowchartConnection(
        fromId: json['fromId'] as String? ?? '',
        toId: json['toId'] as String? ?? '',
        label: json['label'] as String?,
      );
}

class MetricBadgeItem {
  final String label;
  final String value;
  final String? changeLabel;
  final bool? isPositive;
  final String iconName;

  const MetricBadgeItem({
    required this.label,
    required this.value,
    this.changeLabel,
    this.isPositive,
    this.iconName = 'trending_up',
  });

  Map<String, dynamic> toJson() => {
        'label': label,
        'value': value,
        'changeLabel': changeLabel,
        'isPositive': isPositive,
        'iconName': iconName,
      };

  factory MetricBadgeItem.fromJson(Map<String, dynamic> json) => MetricBadgeItem(
        label: json['label'] as String? ?? '',
        value: json['value'] as String? ?? '',
        changeLabel: json['changeLabel'] as String?,
        isPositive: json['isPositive'] as bool?,
        iconName: json['iconName'] as String? ?? 'trending_up',
      );
}

class MerchantBIChartPayload {
  final BIChartType type;
  final String title;
  final String? subtitle;
  final String? totalLabel;
  final String? totalValue;
  final List<ChartSliceItem>? slices;
  final List<TrendBarItem>? bars;
  final List<FlowchartNode>? flowchartNodes;
  final List<FlowchartConnection>? flowchartConnections;
  final List<MetricBadgeItem>? metricBadges;
  final String? mermaidCode;

  const MerchantBIChartPayload({
    required this.type,
    required this.title,
    this.subtitle,
    this.totalLabel,
    this.totalValue,
    this.slices,
    this.bars,
    this.flowchartNodes,
    this.flowchartConnections,
    this.metricBadges,
    this.mermaidCode,
  });

  Map<String, dynamic> toJson() => {
        'type': type.name,
        'title': title,
        'subtitle': subtitle,
        'totalLabel': totalLabel,
        'totalValue': totalValue,
        'slices': slices?.map((s) => s.toJson()).toList(),
        'bars': bars?.map((b) => b.toJson()).toList(),
        'flowchartNodes': flowchartNodes?.map((n) => n.toJson()).toList(),
        'flowchartConnections':
            flowchartConnections?.map((c) => c.toJson()).toList(),
        'metricBadges': metricBadges?.map((m) => m.toJson()).toList(),
        'mermaidCode': mermaidCode,
      };

  factory MerchantBIChartPayload.fromJson(Map<String, dynamic> json) {
    final typeStr = json['type'] as String? ?? 'metricCards';
    final chartType = BIChartType.values.firstWhere(
      (e) => e.name == typeStr,
      orElse: () => BIChartType.metricCards,
    );

    return MerchantBIChartPayload(
      type: chartType,
      title: json['title'] as String? ?? '',
      subtitle: json['subtitle'] as String?,
      totalLabel: json['totalLabel'] as String?,
      totalValue: json['totalValue'] as String?,
      slices: (json['slices'] as List<dynamic>?)
          ?.map((e) => ChartSliceItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      bars: (json['bars'] as List<dynamic>?)
          ?.map((e) => TrendBarItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      flowchartNodes: (json['flowchartNodes'] as List<dynamic>?)
          ?.map((e) => FlowchartNode.fromJson(e as Map<String, dynamic>))
          .toList(),
      flowchartConnections: (json['flowchartConnections'] as List<dynamic>?)
          ?.map((e) => FlowchartConnection.fromJson(e as Map<String, dynamic>))
          .toList(),
      metricBadges: (json['metricBadges'] as List<dynamic>?)
          ?.map((e) => MetricBadgeItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      mermaidCode: json['mermaidCode'] as String?,
    );
  }
}

class MerchantBIMessage {
  final String id;
  final String chatId;
  final String clientId;
  final MerchantBISender sender;
  final String content;
  final MerchantBIChartPayload? chartPayload;
  final List<String> quickPrompts;
  final DateTime createdAt;

  const MerchantBIMessage({
    required this.id,
    required this.chatId,
    required this.clientId,
    required this.sender,
    required this.content,
    this.chartPayload,
    this.quickPrompts = const [],
    required this.createdAt,
  });

  bool get isUser => sender == MerchantBISender.user;
  bool get isAI => sender == MerchantBISender.ai;

  Map<String, dynamic> toJson() => {
        'id': id,
        'chat_id': chatId,
        'client_id': clientId,
        'sender': sender.name,
        'content': content,
        'chart_payload': chartPayload?.toJson(),
        'quick_prompts': quickPrompts,
        'created_at': createdAt.toIso8601String(),
      };

  factory MerchantBIMessage.fromJson(Map<String, dynamic> json) {
    final senderStr = json['sender'] as String? ?? 'user';
    final sender = MerchantBISender.values.firstWhere(
      (s) => s.name == senderStr,
      orElse: () => MerchantBISender.user,
    );

    return MerchantBIMessage(
      id: json['id'] as String? ?? 'msg-${DateTime.now().millisecondsSinceEpoch}',
      chatId: json['chat_id'] as String? ?? '',
      clientId: json['client_id'] as String? ?? '',
      sender: sender,
      content: json['content'] as String? ?? '',
      chartPayload: json['chart_payload'] != null
          ? MerchantBIChartPayload.fromJson(
              json['chart_payload'] as Map<String, dynamic>)
          : null,
      quickPrompts: (json['quick_prompts'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

