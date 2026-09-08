import 'package:flutter/material.dart';
import '../../config/assets.dart';
import '../models/feature_item.dart';

/// Single source of truth for all 6 NovaXpress capabilities.
/// Section 1 and Section 25 of docs/presentation.md.
class PresentationFeatures {
  PresentationFeatures._();

  static const FeatureItem orders = FeatureItem(
    id: 'orders',
    title: 'Orders',
    category: 'LOGISTICS DISPATCH & POD',
    subtitle: 'Unified Last-Mile Ingestion & Doorstep Proof-of-Delivery',
    description:
        'Create, track, and manage your shipments with turn-by-turn routing, sub-DC zero-state isolation, and tamper-proof doorstep signature verification.',
    benefits: [
      'Multi-source CSV, API & Manual Order Ingestion',
      'Sub-DC Isolation eliminating cross-hub data leakage',
      'Real-time Rider Saddlebag custody tracking',
      'Doorstep Photo & Signature Proof-of-Delivery (POD)',
    ],
    keyMetric: '99.4%',
    metricLabel: 'Doorstep Success Rate',
    iconAsset: AppAssets.ordersIcon,
    heroAsset: AppAssets.ordersHero,
    fallbackIcon: Icons.local_shipping_rounded,
    accentColor: Color(0xFFFF7A00),
  );

  static const FeatureItem scaling = FeatureItem(
    id: 'scaling',
    title: 'Scaling',
    category: 'INFRASTRUCTURE & FLEET EXPANSION',
    subtitle: 'Elastic High-Throughput Fulfillment Network',
    description:
        'Seamlessly scale from single-hub operations to nationwide distribution across 774 LGAs with automated routing and dynamic driver compensation rules.',
    benefits: [
      'Automated 2-Tier LGA-to-DC distribution routing',
      'Custom compensation & allowance governance',
      'Elastic multi-hub infrastructure supporting 50k+ daily shipments',
      'Low cloud footprint (₦0.38/delivery at scale)',
    ],
    keyMetric: '50k+',
    metricLabel: 'Daily Orders Scalability',
    iconAsset: AppAssets.scalingIcon,
    heroAsset: AppAssets.scalingHero,
    fallbackIcon: Icons.trending_up_rounded,
    accentColor: Color(0xFFFF9800),
  );

  static const FeatureItem structure = FeatureItem(
    id: 'structure',
    title: 'Structure',
    category: 'ENTERPRISE DC GOVERNANCE',
    subtitle: 'Sub-DC Architecture & Role Fortification',
    description:
        'Enforce strict operational hierarchy between Central HQ, Distribution Centers, and Mobile Dispatch Units with cryptographic security boundaries.',
    benefits: [
      'Sub-DC Zero-State Data Scoping preventing blindspots',
      'Granular HQ Treasury, DC Supervisor, and Rider RBAC',
      'Warehouse bin slotting & quarantine shelf management',
      'Fail-safe offline local cache sync (Hive + Storage)',
    ],
    keyMetric: '100%',
    metricLabel: 'Hub Scoping Isolation',
    iconAsset: AppAssets.structureIcon,
    heroAsset: AppAssets.structureHero,
    fallbackIcon: Icons.hub_rounded,
    accentColor: Color(0xFF00E5FF),
  );

  static const FeatureItem payments = FeatureItem(
    id: 'payments',
    title: 'Payments',
    category: 'FINANCIAL RECONCILIATION & GATEWAYS',
    subtitle: 'Dynamic Virtual Accounts & POS Settlement',
    description:
        'Eliminate driver cash leakage through instant Monnify dynamic virtual accounts, Paystack card collection, and POS terminal transaction linking.',
    benefits: [
      'Dynamic Monnify Virtual Accounts with zero cash liability',
      'Direct doorstep Paystack card & POS reconciliation',
      'Automated transfer fee & terminal charge absorption',
      '₦50,000 maximum physical cash custody protection',
    ],
    keyMetric: '₦0',
    metricLabel: 'Rider Cash Leakage Risk',
    iconAsset: AppAssets.paymentsIcon,
    heroAsset: AppAssets.paymentsHero,
    fallbackIcon: Icons.account_balance_wallet_rounded,
    accentColor: Color(0xFF10B981),
  );

  static const FeatureItem remitance = FeatureItem(
    id: 'remitance', // Stored as remitance for label fidelity, configurable for future change
    title: 'Remitance',
    category: 'CRYPTOGRAPHIC AUDITING',
    subtitle: 'Tamper-Evident SHA-256 Remittance Ledgers',
    description:
        'Deliver complete financial integrity through 3-way automated matching, SHA-256 cryptographic audit receipts, and instantaneous custody clearing.',
    benefits: [
      '3-Way Automated Payment Matching Engine',
      'Cryptographic SHA-256 digital signature receipts',
      'Instantaneous DC cash custody balance clearing',
      'Transparent merchant payout ledger tracking',
    ],
    keyMetric: '100%',
    metricLabel: 'Cryptographic Audit Match',
    iconAsset: AppAssets.remitanceIcon,
    heroAsset: AppAssets.remitanceHero,
    fallbackIcon: Icons.verified_rounded,
    accentColor: Color(0xFFFF7A00),
  );

  static const FeatureItem sock = FeatureItem(
    id: 'sock', // Stored as sock for label fidelity, configurable for future change to stock
    title: 'Sock',
    category: '2-IN-1 DUAL INVENTORY ENGINE',
    subtitle: 'Warehouse Bulk & Mobile Saddlebag Sync',
    description:
        'Revolutionary 2-in-1 dual inventory system synchronizing warehouse bulk shelves with real-time rider saddlebag custody and multi-DC rebalancing.',
    benefits: [
      '2-in-1 Dual Inventory: Bulk Shelf + Mobile Saddlebag',
      'Inter-DC stock transfer escrow with QR scan intake',
      'Reverse logistics & QC restock desk workflows',
      'Automated low-stock threshold alerts & forecasting',
    ],
    keyMetric: '0',
    metricLabel: 'Inventory Blindspots',
    iconAsset: AppAssets.sockIcon,
    heroAsset: AppAssets.sockHero,
    fallbackIcon: Icons.inventory_2_rounded,
    accentColor: Color(0xFF6366F1),
  );

  /// Ordered list of all 6 capabilities in orbital sequence
  static const List<FeatureItem> all = [
    orders,
    scaling,
    structure,
    payments,
    remitance,
    sock,
  ];

  /// Find a feature by its identifier
  static FeatureItem findById(String id) {
    return all.firstWhere(
      (f) => f.id == id,
      orElse: () => orders,
    );
  }
}
