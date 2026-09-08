import 'package:flutter/material.dart';

/// Data model representing a NovaXpress core capability in the presentation ecosystem.
/// Fully data-driven to allow updating titles (e.g. Remitance -> Remittance, Sock -> Stock)
/// without any architectural refactoring.
class FeatureItem {
  final String id;
  final String title;
  final String category;
  final String subtitle;
  final String description;
  final List<String> benefits;
  final String keyMetric;
  final String metricLabel;
  final String iconAsset;
  final String heroAsset;
  final IconData fallbackIcon;
  final Color accentColor;

  const FeatureItem({
    required this.id,
    required this.title,
    required this.category,
    required this.subtitle,
    required this.description,
    required this.benefits,
    required this.keyMetric,
    required this.metricLabel,
    required this.iconAsset,
    required this.heroAsset,
    required this.fallbackIcon,
    this.accentColor = const Color(0xFFFF7A00),
  });

  /// Allows creating an updated copy (e.g. updating visible title in runtime or future versions)
  FeatureItem copyWith({
    String? id,
    String? title,
    String? category,
    String? subtitle,
    String? description,
    List<String>? benefits,
    String? keyMetric,
    String? metricLabel,
    String? iconAsset,
    String? heroAsset,
    IconData? fallbackIcon,
    Color? accentColor,
  }) {
    return FeatureItem(
      id: id ?? this.id,
      title: title ?? this.title,
      category: category ?? this.category,
      subtitle: subtitle ?? this.subtitle,
      description: description ?? this.description,
      benefits: benefits ?? this.benefits,
      keyMetric: keyMetric ?? this.keyMetric,
      metricLabel: metricLabel ?? this.metricLabel,
      iconAsset: iconAsset ?? this.iconAsset,
      heroAsset: heroAsset ?? this.heroAsset,
      fallbackIcon: fallbackIcon ?? this.fallbackIcon,
      accentColor: accentColor ?? this.accentColor,
    );
  }
}
