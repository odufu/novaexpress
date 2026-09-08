import 'package:flutter/material.dart';
import '../models/workflow_models.dart';

/// Single source of truth for the 7 NovaXpress Operational Workflow Domains.
class PresentationWorkflowData {
  PresentationWorkflowData._();

  // ===========================================================================
  // 1. GENERAL STRUCTURE (Order Types Q1-Q4 & System Hierarchy)
  // ===========================================================================
  static const WorkflowDomain generalStructure = WorkflowDomain(
    id: 'general_structure',
    title: 'General Structure & Operational Matrix',
    shortTitle: 'Structure',
    subtitle: 'Enterprise 4-Quadrant Fulfillment & Regional Sub-DC Isolation',
    overview:
        'NovaXpress operates on a multi-tier governance model: HQ Central Command provisions and audits; Distribution Centers (DCs) enforce isolated regional operations; Enterprise Clients ingest bulk shipments; and Dispatch Riders execute last-mile doorstep deliveries under strict cryptographic boundaries.',
    icon: Icons.hub_rounded,
    accentColor: Color(0xFFEA580C),
    activeRoles: [
      WorkflowRole.hq,
      WorkflowRole.dcAdmin,
      WorkflowRole.client,
      WorkflowRole.rider,
    ],
    keyMetrics: {
      'Isolation': '100% Sub-DC Scoping',
      'Matrix': '4 Quadrant Fulfillment',
      'Architecture': 'Zero-State Sub-Hubs',
      'Audit Trail': 'Cryptographic Ledgers',
    },
    nodes: [
      WorkflowNode(
        id: 'struct-1',
        stepNumber: 1,
        title: 'HQ Central Governance & National Vault',
        description:
            'HQ sets company-wide commission rates, registers regional distribution hubs, and audits national liquidity.',
        role: WorkflowRole.hq,
        nodeType: FlowNodeType.start,
        icon: Icons.account_balance_rounded,
        ruleReference: 'BR-015',
        technicalDetails: [
          'Provisions new DC hubs with RFC4122 v4 UUIDs',
          'Enforces immutable rate locking on historical delivery charges',
          'Supervises national inter-hub stock rebalancing',
        ],
      ),
      WorkflowNode(
        id: 'struct-2',
        stepNumber: 2,
        title: 'Regional Sub-DC Zero-State Isolation',
        description:
            'Each DC operates within an isolated tenant partition. Hub supervisors only see local riders, local stock, and local cash starting at ₦0.00.',
        role: WorkflowRole.dcAdmin,
        nodeType: FlowNodeType.process,
        icon: Icons.security_rounded,
        ruleReference: 'BR-005',
        technicalDetails: [
          'Supabase Row-Level Security scopes queries to hub_id',
          'Local warehouse rack binning and quarantine shelf management',
          'Zero data bleed across distinct regional distribution hubs',
        ],
      ),
      WorkflowNode(
        id: 'struct-3',
        stepNumber: 3,
        title: 'Enterprise Client Relationship & Ingestion',
        description:
            'Clients maintain verified corporate accounts with registered brands, SKU catalogs, and automated daily order intake.',
        role: WorkflowRole.client,
        nodeType: FlowNodeType.process,
        icon: Icons.business_rounded,
        ruleReference: 'BR-001',
        technicalDetails: [
          'Bulk CSV order parsing with automated phone sanitization',
          'Pre-allocated SKU bundles and discounted pricing tiers',
          'Dedicated corporate settlement account routing',
        ],
      ),
      WorkflowNode(
        id: 'struct-4',
        stepNumber: 4,
        title: '4-Quadrant Fulfillment Classification',
        description:
            'Every incoming order is mapped to one of 4 strict quadrants: Q1 (Client Package Non-POD), Q2 (Client Package POD), Q3 (Distributed Stock Non-POD), Q4 (Distributed Stock POD).',
        role: WorkflowRole.system,
        nodeType: FlowNodeType.decision,
        icon: Icons.grid_view_rounded,
        ruleReference: 'BR-002',
        technicalDetails: [
          'Q1: Merchant parcel • Prepaid • Zero doorstep cash liability',
          'Q2: Merchant parcel • COD Cash / Transfer collection',
          'Q3: DC warehouse bulk shelf • Prepaid fulfillment',
          'Q4: DC warehouse bulk shelf • COD Cash / Transfer collection',
        ],
      ),
      WorkflowNode(
        id: 'struct-5',
        stepNumber: 5,
        title: 'Mobile Dispatch Unit Custody Execution',
        description:
            'Riders receive digital manifests, verify custody handshakes, record doorstep signatures, and clear daily accounts.',
        role: WorkflowRole.rider,
        nodeType: FlowNodeType.end,
        icon: Icons.delivery_dining_rounded,
        ruleReference: 'BR-010',
        technicalDetails: [
          'GPS-tracked turn-by-turn route optimization',
          'Direct customer WhatsApp communication links',
          'Instant commission and fuel allowance credit to "My Balance"',
        ],
      ),
    ],
    mermaidSpec: MermaidSpec(
      diagramType: 'graph TD',
      description: 'System Architectural Hierarchy & 4-Quadrant Matrix',
      code: '''graph TD
    HQ([🏛️ 1. Central HQ Governance]) --> DC1[🏢 2. Sub-DC Lagos Hub]
    HQ --> DC2[🏢 2. Sub-DC Abuja Hub]
    HQ --> DC3[🏢 2. Sub-DC Kano Hub]
    
    subgraph Regional DC Hub Isolation
      DC1 --> W1[(📦 Local Warehouse Racks)]
      DC1 --> R1[🛵 Assigned Active Riders]
      DC1 --> V1[💵 Local Cash Vault ₦0.00]
    end
    
    CL([💼 3. Enterprise Client Portal]) --> INGEST[📋 Order Ingestion Engine]
    INGEST --> MATRIX{4-Quadrant Matrix}
    
    MATRIX -->|Q1: Client Pkg / Prepaid| Q1F[Doorstep POD Only]
    MATRIX -->|Q2: Client Pkg / COD| Q2F[Doorstep Cash/VA Collection]
    MATRIX -->|Q3: DC Stock / Prepaid| Q3F[Shelf Pick -> Doorstep POD]
    MATRIX -->|Q4: DC Stock / COD| Q4F[Shelf Pick -> Cash/VA Handover]
    
    Q1F --> DISPATCH[🏍️ Rider Saddlebag Custody]
    Q2F --> DISPATCH
    Q3F --> DISPATCH
    Q4F --> DISPATCH''',
    ),
    operationalRules: [
      OperationalRule(
        id: 'BR-001',
        category: 'Client',
        rule: 'Every delivery belongs to a verified enterprise client.',
        operationalImpact: 'Prevents untracked shipments and orphaned parcels.',
      ),
      OperationalRule(
        id: 'BR-002',
        category: 'Fulfillment',
        rule: 'Every delivery has a fulfillment type (Client Package or Distributed Inventory).',
        operationalImpact: 'Dictates whether stock is picked from DC shelves or received pre-packaged.',
      ),
      OperationalRule(
        id: 'BR-003',
        category: 'Payment',
        rule: 'Every delivery has a payment type (POD or Non-POD).',
        operationalImpact: 'Dictates whether financial collection is required at doorstep.',
      ),
      OperationalRule(
        id: 'BR-015',
        category: 'Security',
        rule: 'Agents cannot alter rates or compensation parameters.',
        operationalImpact: 'Enforces cryptographic rate immutability.',
      ),
    ],
  );

  // ===========================================================================
  // 2. CREATING RIDERS (Onboarding, KYC, Vehicle, Zone, Compensation)
  // ===========================================================================
  static const WorkflowDomain creatingRiders = WorkflowDomain(
    id: 'creating_riders',
    title: 'Rider & PDA Personnel Onboarding',
    shortTitle: 'Creating Riders',
    subtitle: 'KYC Verification, Vehicle Allocation & Dynamic Compensation Models',
    overview:
        'The rider onboarding workflow registers field personnel with national identity verification, assigns vehicle assets, bounds operational delivery zones to regional sub-DCs, and selects contractual compensation structures (Commission + Fuel Allowance vs Monthly Salary).',
    icon: Icons.two_wheeler_rounded,
    accentColor: Color(0xFFEA580C),
    activeRoles: [
      WorkflowRole.dcAdmin,
      WorkflowRole.hq,
      WorkflowRole.rider,
      WorkflowRole.system,
    ],
    keyMetrics: {
      'Setup Time': '< 3 Minutes',
      'KYC Security': '100% ID Verified',
      'Compensation': 'Commission / Salary',
      'Ledger Init': '₦0.00 Starting Balance',
    },
    nodes: [
      WorkflowNode(
        id: 'rider-1',
        stepNumber: 1,
        title: 'Open DC Personnel Console',
        description:
            'DC Supervisor opens the "Add New Personnel / Rider" modal within their isolated regional dashboard.',
        role: WorkflowRole.dcAdmin,
        nodeType: FlowNodeType.start,
        icon: Icons.person_add_rounded,
        technicalDetails: [
          'Scoper binds new rider strictly to current distribution hub (dc_id)',
          'Automated validation checks against duplicate phone or email',
        ],
      ),
      WorkflowNode(
        id: 'rider-2',
        stepNumber: 2,
        title: 'KYC Document & Bio Verification',
        description:
            'Capture full legal name, phone, emergency guarantor contact, and upload National ID (NIN) / Driver’s License.',
        role: WorkflowRole.dcAdmin,
        nodeType: FlowNodeType.process,
        icon: Icons.badge_rounded,
        ruleReference: 'BR-011',
        technicalDetails: [
          'Encrypted document upload to Supabase Private Storage',
          'NIN biometric validation and identity verification',
        ],
      ),
      WorkflowNode(
        id: 'rider-3',
        stepNumber: 3,
        title: 'Vehicle Allocation & Operational Zone',
        description:
            'Select vehicle type (Motorcycle, Cargo Van, Trike), plate number, and assign specific delivery zones / LGAs.',
        role: WorkflowRole.dcAdmin,
        nodeType: FlowNodeType.process,
        icon: Icons.directions_bike_rounded,
        technicalDetails: [
          'Limits dispatch manifest to specific regional neighborhood clusters',
          'Vehicle capacity parameters loaded into route balancer',
        ],
      ),
      WorkflowNode(
        id: 'rider-4',
        stepNumber: 4,
        title: 'Compensation Contract Selection',
        description:
            'Select contractual model: Option A (Commission + Transport Allowance per successful delivery) or Option B (Fixed Monthly Salary).',
        role: WorkflowRole.dcAdmin,
        nodeType: FlowNodeType.decision,
        icon: Icons.payments_rounded,
        ruleReference: 'BR-010',
        technicalDetails: [
          'Model A: e.g. ₦1,000 commission + ₦1,500 fuel per delivery',
          'Model B: Fixed monthly base with ₦0 per-delivery commission',
          'Rate parameter locked at creation time to prevent retroactive tampering',
        ],
      ),
      WorkflowNode(
        id: 'rider-5',
        stepNumber: 5,
        title: 'UUID Provisioning & Mobile App Handshake',
        description:
            'System generates unique RFC4122 v4 UUID, initializes "My Balance" ledger (₦0.00), and sends SMS invite with temporary login PIN.',
        role: WorkflowRole.system,
        nodeType: FlowNodeType.end,
        icon: Icons.key_rounded,
        ruleReference: 'BR-013',
        technicalDetails: [
          'Generates rider auth account in Supabase Auth',
          'Initializes personal earnings ledger at ₦0.00',
          'Sets physical cash custody ceiling to ₦50,000 max',
        ],
      ),
    ],
    mermaidSpec: MermaidSpec(
      diagramType: 'graph TD',
      description: 'End-to-End Rider Creation & Onboarding Flow',
      code: '''graph TD
    A([🏢 1. DC Admin Opens Add Rider Console]) --> B[📋 2. Enter Profile & KYC Info]
    B --> C[📄 3. Upload NIN & Driver's License]
    C --> D[🏍️ 4. Assign Vehicle & Zone LGAs]
    D --> E{5. Select Compensation Structure}
    
    E -->|Commission Based| F[💰 Set ₦/Delivery Comm + Fuel Allowance]
    E -->|Salary Based| G[💼 Set Fixed Monthly Base - ₦0 Comm]
    
    F --> H[⚡ 6. Auto-Generate UUID & Supabase Auth]
    G --> H
    
    H --> I[📱 7. Dispatch SMS Mobile App Login PIN]
    I --> J([🎉 8. Rider Logs In - Starts at ₦0 Balance])''',
    ),
    operationalRules: [
      OperationalRule(
        id: 'BR-010',
        category: 'Compensation',
        rule: 'Delivery personnel compensation is configuration-driven (Commission + Transport).',
        operationalImpact: 'Supports flexible fleet contracts across different vehicle types.',
      ),
      OperationalRule(
        id: 'BR-011',
        category: 'Personnel',
        rule: 'PDA and Rider compensation may differ based on vehicle and contractual terms.',
        operationalImpact: 'Enables custom compensation tiers per distribution hub.',
      ),
      OperationalRule(
        id: 'BR-012',
        category: 'Personnel',
        rule: 'Salary-based personnel may have no per-delivery commission.',
        operationalImpact: 'Guarantees salary agreements do not duplicate commission payouts.',
      ),
      OperationalRule(
        id: 'BR-013',
        category: 'Earnings',
        rule: 'Commission-based personnel accumulate earnings in their personal "My Balance" ledger.',
        operationalImpact: 'Maintains an auditable, real-time balance for driver withdrawals.',
      ),
    ],
  );

  // ===========================================================================
  // 3. CREATING PRODUCTS (Client Company Attachment, SKU, Pricing, Barcodes)
  // ===========================================================================
  static const WorkflowDomain creatingProducts = WorkflowDomain(
    id: 'creating_products',
    title: 'Product Catalog & SKU Creation',
    shortTitle: 'Creating Products',
    subtitle: 'Company Attachment Dropdown, Package Bundles & Stock Racks',
    overview:
        'When creating a product, it must be attached to an already registered enterprise client company via a dedicated dropdown selector. The catalog manager defines SKU codes, package bundle pricing tiers, barcode identifiers, storage requirements, and initializes regional warehouse stock quotas.',
    icon: Icons.inventory_rounded,
    accentColor: Color(0xFFEA580C),
    activeRoles: [
      WorkflowRole.client,
      WorkflowRole.dcAdmin,
      WorkflowRole.hq,
      WorkflowRole.system,
    ],
    keyMetrics: {
      'Linkage': 'Direct Company Attachment',
      'SKU Standard': 'GS1 Compliant',
      'Bundles': 'Multi-Tier Pricing',
      'Sync Speed': '< 500ms Multi-DC',
    },
    nodes: [
      WorkflowNode(
        id: 'prod-1',
        stepNumber: 1,
        title: 'Select Registered Client Company',
        description:
            'DC Supervisor or Client selects the parent merchant from the authoritative company dropdown (e.g. Grazer Wellness, Respira Pharma, Alpha Health).',
        role: WorkflowRole.client,
        nodeType: FlowNodeType.start,
        icon: Icons.business_center_rounded,
        ruleReference: 'BR-001',
        technicalDetails: [
          'Fetches verified active merchants from companies table',
          'Locks product ownership strictly to selected corporate entity',
        ],
      ),
      WorkflowNode(
        id: 'prod-2',
        stepNumber: 2,
        title: 'Define SKU, Name & Category',
        description:
            'Enter unique SKU code (e.g. GZ-TEA-001), product title, formulation category, and unit physical weight.',
        role: WorkflowRole.dcAdmin,
        nodeType: FlowNodeType.process,
        icon: Icons.qr_code_scanner_rounded,
        technicalDetails: [
          'Enforces unique index across client company catalog',
          'Stores dimensions and handling specs (Fragile, Cold Chain)',
        ],
      ),
      WorkflowNode(
        id: 'prod-3',
        stepNumber: 3,
        title: 'Configure Package Bundles & Pricing Tiers',
        description:
            'Setup retail package bundles with tiered unit economics (e.g. Single Pack @ ₦12,500; Twin Pack + Bonus Balm @ ₦22,000; Family Pack @ ₦40,000).',
        role: WorkflowRole.client,
        nodeType: FlowNodeType.process,
        icon: Icons.sell_rounded,
        ruleReference: 'BR-006',
        technicalDetails: [
          'Pre-defines order bundle line items for instant checkout',
          'Sets baseline client logistics fulfillment fee per tier',
        ],
      ),
      WorkflowNode(
        id: 'prod-4',
        stepNumber: 4,
        title: 'Media Asset & Barcode Generation',
        description:
            'Upload high-resolution packaging photo and auto-generate GS1-compliant 1D/2D barcodes for warehouse scanners.',
        role: WorkflowRole.system,
        nodeType: FlowNodeType.process,
        icon: Icons.photo_library_rounded,
        technicalDetails: [
          'Automated image compression to WebP via Supabase Storage',
          'Barcode vector generation for printable shelf labels',
        ],
      ),
      WorkflowNode(
        id: 'prod-5',
        stepNumber: 5,
        title: 'Initial DC Warehouse Allocation',
        description:
            'Assign initial stock quantities to regional DC bulk shelves (Lagos, Abuja, Kano) with low-stock threshold triggers.',
        role: WorkflowRole.dcAdmin,
        nodeType: FlowNodeType.end,
        icon: Icons.shelves,
        ruleReference: 'BR-008',
        technicalDetails: [
          'Creates inventory_records ledger rows bound to dc_id and product_id',
          'Configures automated re-order notification alert threshold',
        ],
      ),
    ],
    mermaidSpec: MermaidSpec(
      diagramType: 'graph TD',
      description: 'Product Creation & Client Association Flow',
      code: '''graph TD
    A([💼 1. Open Create Product Modal]) --> B[🏢 2. Select Company from Dropdown]
    B --> C[🏷️ 3. Enter Name, SKU & Weight]
    C --> D[💰 4. Configure Package Tiers & Bundles]
    D --> E[📸 5. Upload Image & Generate Barcode]
    E --> F[📦 6. Assign Initial Stock to Regional DC]
    F --> G([✅ 7. Product Active across Order Ingestion])''',
    ),
    operationalRules: [
      OperationalRule(
        id: 'BR-001',
        category: 'Client',
        rule: 'Every delivery belongs to a client.',
        operationalImpact: 'Guarantees every product is tied to a verified commercial entity.',
      ),
      OperationalRule(
        id: 'BR-006',
        category: 'Billing',
        rule: 'Successful deliveries generate client logistics charges.',
        operationalImpact: 'Product pricing bundles establish fulfillment charge formulas.',
      ),
      OperationalRule(
        id: 'BR-008',
        category: 'Inventory',
        rule: 'Failed distributed-inventory deliveries require physical stock return.',
        operationalImpact: 'Ensures products maintain trackable inventory lifecycle.',
      ),
    ],
  );

  // ===========================================================================
  // 4. STOCK MOVEMENTS & CUSTODIES (Clarified from "Sock" in UI)
  // ===========================================================================
  static const WorkflowDomain stockMovements = WorkflowDomain(
    id: 'stock_movements',
    title: 'Stock Movements & Custodies',
    shortTitle: 'Stock & Custodies',
    subtitle: '2-in-1 Dual Inventory: Bulk Warehouse Shelf to Mobile Saddlebag Sync',
    overview:
        'Formerly mistook for "sock" in the prototype UI, Stock Movements & Custodies governs the 2-in-1 Dual Inventory Engine. Physical stock transitions seamlessly between bulk warehouse racks, mobile rider saddlebags (via secure PIN handover), inter-DC transfer escrow, and the QC return desk.',
    icon: Icons.inventory_2_rounded,
    accentColor: Color(0xFFEA580C),
    activeRoles: [
      WorkflowRole.dcAdmin,
      WorkflowRole.rider,
      WorkflowRole.hq,
      WorkflowRole.system,
    ],
    keyMetrics: {
      'System Type': '2-in-1 Dual Inventory',
      'Custody Tracking': 'Real-Time Saddlebag PIN',
      'Blindspots': '0 In-Transit Escrow',
      'Returns QC': 'Mandatory Physical Inspection',
    },
    nodes: [
      WorkflowNode(
        id: 'stock-1',
        stepNumber: 1,
        title: 'Bulk Warehouse Inward & Bin Slotting',
        description:
            'Supplier or merchant delivers bulk stock. DC team performs barcode count, inspects seals, and logs items into local bin racks.',
        role: WorkflowRole.dcAdmin,
        nodeType: FlowNodeType.start,
        icon: Icons.move_to_inbox_rounded,
        technicalDetails: [
          'Creates verified intake ledger entry with batch expiry dates',
          'Increments DC local shelf balance in real time',
        ],
      ),
      WorkflowNode(
        id: 'stock-2',
        stepNumber: 2,
        title: 'Saddlebag Handover with Security PIN',
        description:
            'When assigning orders, warehouse stock moves from "Bulk Shelf" to "Rider Saddlebag Custody" authenticated by the rider’s 4-digit security PIN.',
        role: WorkflowRole.dcAdmin,
        nodeType: FlowNodeType.process,
        icon: Icons.pin_drop_rounded,
        ruleReference: 'BR-009',
        technicalDetails: [
          'Decrements bulk warehouse count and increments rider custody ledger',
          'Rider becomes legally and financially accountable for mobile units',
        ],
      ),
      WorkflowNode(
        id: 'stock-3',
        stepNumber: 3,
        title: 'Inter-DC Stock Rebalancing Escrow',
        description:
            'HQ initiates inventory transfer from surplus hubs (e.g. Lagos) to low-stock hubs (e.g. Kano) under secure transit escrow status.',
        role: WorkflowRole.hq,
        nodeType: FlowNodeType.process,
        icon: Icons.local_shipping_rounded,
        technicalDetails: [
          'Stock moves into "In-Transit Escrow" state with dispatch manifest',
          'Destination DC performs physical barcode scan on arrival to complete transfer',
        ],
      ),
      WorkflowNode(
        id: 'stock-4',
        stepNumber: 4,
        title: 'Reverse Logistics & QC Restock Desk',
        description:
            'Cancelled or rejected packages returned by riders are inspected at the DC QC desk. Verified intact units are restored to inventory; damaged items are quarantined.',
        role: WorkflowRole.dcAdmin,
        nodeType: FlowNodeType.end,
        icon: Icons.published_with_changes_rounded,
        ruleReference: 'BR-009',
        technicalDetails: [
          'Mandatory supervisor sign-off before restoring shelf inventory count',
          'Generates loss prevention incident report for damaged stock',
        ],
      ),
    ],
    mermaidSpec: MermaidSpec(
      diagramType: 'graph TD',
      description: 'Dual Inventory Shelf-to-Saddlebag & Escrow Workflow',
      code: '''graph TD
    subgraph Primary DC Warehouse
      A[🏭 Bulk Merchant Delivery] --> B[📦 Log into Bulk Shelf Racks]
      B --> C{Order Dispatched?}
    end
    
    subgraph Mobile Rider Custody
      C -->|Yes| D[🔒 Enter 4-Digit Handover PIN]
      D --> E[🏍️ Stock Transferred to Saddlebag Custody]
      E --> F{Doorstep Outcome}
      F -->|Delivered| G[✅ Stock Converted to Cash / POD]
      F -->|Failed / Cancelled| H[↩️ Package Returned to DC]
    end
    
    subgraph QC Restock Desk
      H --> I[🔍 Supervisor QC Physical Inspection]
      I -->|Intact Seal| J[📦 Restock to Bulk Warehouse]
      I -->|Damaged / Compromised| K[⚠️ Move to Quarantine Vault]
    end''',
    ),
    operationalRules: [
      OperationalRule(
        id: 'BR-008',
        category: 'Inventory',
        rule: 'Failed distributed-inventory deliveries require physical stock return.',
        operationalImpact: 'Prevents rider inventory leakage on unfulfilled shipments.',
      ),
      OperationalRule(
        id: 'BR-009',
        category: 'Inventory',
        rule: 'Returned stock must be physically verified by the receiving DC before inventory is restored.',
        operationalImpact: 'Maintains high product quality and prevents restocking counterfeit items.',
      ),
      OperationalRule(
        id: 'BR-019',
        category: 'Inventory',
        rule: 'Inventory discrepancies require mandatory resolution before close-of-day.',
        operationalImpact: 'Enforces daily zero-discrepancy inventory balancing.',
      ),
    ],
  );

  // ===========================================================================
  // 5. REMITTANCE (Physical Cash Vault, Monnify, Reconciliation, SHA-256 Receipts)
  // ===========================================================================
  static const WorkflowDomain remittance = WorkflowDomain(
    id: 'remittance',
    title: 'Financial Remittance & Reconciliation Engine',
    shortTitle: 'Remittance',
    subtitle: 'Zero-Discrepancy 3-Way Matching & SHA-256 Cryptographic Receipts',
    overview:
        'Remittance audits every naira collected across all field routes. Physical Cash on Delivery (COD) is remitted to the DC Vault; direct customer bank transfers clear via Monnify with zero cash liability; and close-of-day balances are sealed with tamper-evident SHA-256 cryptographic signatures.',
    icon: Icons.verified_rounded,
    accentColor: Color(0xFFEA580C),
    activeRoles: [
      WorkflowRole.rider,
      WorkflowRole.dcAdmin,
      WorkflowRole.hq,
      WorkflowRole.system,
    ],
    keyMetrics: {
      'Reconciliation': '3-Way Automated Match',
      'Signatures': 'SHA-256 Cryptographic Hash',
      'Vault Ceiling': '₦50,000 Cash Limit',
      'Variance Visibility': 'Real-Time DC Alerts',
    },
    nodes: [
      WorkflowNode(
        id: 'rem-1',
        stepNumber: 1,
        title: 'Doorstep Cash Collection Ledgering',
        description:
            'When customers pay cash at doorstep, the rider confirms the collection on their mobile PDA, immediately increasing their physical cash holding ledger.',
        role: WorkflowRole.rider,
        nodeType: FlowNodeType.start,
        icon: Icons.payments_rounded,
        ruleReference: 'BR-004',
        technicalDetails: [
          'PDA warns rider when total cash holding approaches ₦50,000 threshold',
          'Enforces mandatory remittance when limit is reached',
        ],
      ),
      WorkflowNode(
        id: 'rem-2',
        stepNumber: 2,
        title: 'Physical Cash Vault Handover',
        description:
            'At close of shift, the rider presents physical currency notes to the DC Cashier / Supervisor for dual count verification.',
        role: WorkflowRole.dcAdmin,
        nodeType: FlowNodeType.process,
        icon: Icons.point_of_sale_rounded,
        ruleReference: 'BR-005',
        technicalDetails: [
          'Supervisor verifies physical bills against digital manifest totals',
          'Separate deduction logic for POS terminal gateway charges',
        ],
      ),
      WorkflowNode(
        id: 'rem-3',
        stepNumber: 3,
        title: '3-Way Automated Reconciliation',
        description:
            'The engine matches physical stock dispatched against confirmed POD orders, recorded cash in hand, and direct Monnify transfers.',
        role: WorkflowRole.system,
        nodeType: FlowNodeType.process,
        icon: Icons.compare_arrows_rounded,
        ruleReference: 'BR-018',
        technicalDetails: [
          'Formula: Dispatched Units = Delivered Orders + Verified Returns',
          'Formula: Remitted Cash = Total COD Collected - Approved Expenses',
          'Flags any variance > ₦0.00 instantly on DC dashboard',
        ],
      ),
      WorkflowNode(
        id: 'rem-4',
        stepNumber: 4,
        title: 'Cryptographic SHA-256 Digital Receipt',
        description:
            'Upon successful zero-variance verification, the system computes an immutable SHA-256 cryptographic hash and issues a signed digital receipt to the rider.',
        role: WorkflowRole.system,
        nodeType: FlowNodeType.end,
        icon: Icons.fingerprint_rounded,
        ruleReference: 'BR-020',
        technicalDetails: [
          'Hash combines timestamp, rider_id, amount, order_ids, and supervisor_id',
          'Clears rider cash liability to ₦0.00 and pushes receipt to mobile PDA',
        ],
      ),
    ],
    mermaidSpec: MermaidSpec(
      diagramType: 'sequenceDiagram',
      description: 'End-of-Day Remittance & SHA-256 Clearance Protocol',
      code: '''sequenceDiagram
    autonumber
    actor Rider as 🛵 Dispatch Rider
    participant App as 📱 Rider Mobile App
    participant DC as 🏢 DC Supervisor Vault
    participant System as ⚡ Reconciliation Engine
    participant HQ as 🏛️ HQ Central Treasury

    Rider->>DC: Hand over physical paper cash (e.g. ₦45,000)
    DC->>App: Verify manifest order numbers against collected bills
    DC->>System: Submit "Physical Remittance Received"
    System->>System: Execute 3-Way Match (Stock Out = PODs + Returns)
    System->>System: Compute SHA-256 Cryptographic Signature Hash
    System->>App: Push Tamper-Proof Digital Receipt to Rider
    System->>DC: Clear Rider Cash Liability to ₦0.00
    System->>HQ: Sync Cleared Batch to National Treasury Ledger
    Note over Rider,HQ: Status: 100% Cleared • Zero Cash Variance''',
    ),
    operationalRules: [
      OperationalRule(
        id: 'BR-004',
        category: 'POD',
        rule: 'POD deliveries require physical collection tracking.',
        operationalImpact: 'Enforces live ledgering of all doorstep cash receipts.',
      ),
      OperationalRule(
        id: 'BR-005',
        category: 'Remittance',
        rule: 'POD collections require reconciliation at the host DC.',
        operationalImpact: 'Prevents riders leaving shift without accounting for funds.',
      ),
      OperationalRule(
        id: 'BR-017',
        category: 'Remittance',
        rule: 'Remittances require verification by DC Operations Manager before clearing rider status.',
        operationalImpact: 'Dual custody control: rider and supervisor must agree.',
      ),
      OperationalRule(
        id: 'BR-020',
        category: 'Security',
        rule: 'Every important financial and inventory action must be cryptographically auditable.',
        operationalImpact: 'Guarantees receipts cannot be forged or altered retroactively.',
      ),
    ],
  );

  // ===========================================================================
  // 6. ORDERS (Client Create -> Closest DC -> Assign -> Deliver -> 2 Branches)
  // ===========================================================================
  static const WorkflowDomain orders = WorkflowDomain(
    id: 'orders',
    title: 'Order Dispatch & Doorstep Delivery Lifecycle',
    shortTitle: 'Orders',
    subtitle: 'LGA Smart Routing & The Two Post-Delivery Settlement Branches',
    overview:
        'A comprehensive end-to-end journey: The enterprise client creates an order; the intelligent routing engine routes it to the closest DC based on the recipient’s LGA; the DC supervisor assigns it to an available rider; the rider delivers; upon success, it splits into two branches: Cash on Delivery (accumulating to Remittance) or Direct Payment (Monnify/Paystack with zero cash liability).',
    icon: Icons.local_shipping_rounded,
    accentColor: Color(0xFFEA580C),
    activeRoles: [
      WorkflowRole.client,
      WorkflowRole.system,
      WorkflowRole.dcAdmin,
      WorkflowRole.rider,
      WorkflowRole.customer,
    ],
    keyMetrics: {
      'Routing': 'Autonomous Closest-DC LGA Match',
      'Doorstep Success': '99.4% Fulfillment Rate',
      'Branch A': 'Cash Remittance Vault Pathway',
      'Branch B': 'Instant Monnify Direct Transfer',
    },
    nodes: [
      WorkflowNode(
        id: 'ord-1',
        stepNumber: 1,
        title: 'Client Creates Order',
        description:
            'Enterprise merchant uploads orders via Web Portal, Bulk CSV, or REST API. System validates recipient phone and address.',
        role: WorkflowRole.client,
        nodeType: FlowNodeType.start,
        icon: Icons.post_add_rounded,
        ruleReference: 'BR-001',
        technicalDetails: [
          'Sanitizes 234 phone numbers and detects duplicate customer submissions',
          'Assigns unique order tracking number (e.g. NX-8491)',
        ],
      ),
      WorkflowNode(
        id: 'ord-2',
        stepNumber: 2,
        title: 'Intelligent Routing to Closest DC',
        description:
            'Routing algorithm parses the destination State and LGA, automatically routing the shipment to the nearest regional DC hub.',
        role: WorkflowRole.system,
        nodeType: FlowNodeType.process,
        icon: Icons.alt_route_rounded,
        technicalDetails: [
          'Matches receiver LGA against 774 Nigerian LGAs in geo-registry',
          'Routes order directly to local DC manifest (e.g. Kano Central Hub)',
        ],
      ),
      WorkflowNode(
        id: 'ord-3',
        stepNumber: 3,
        title: 'DC Admin Assigns to Available Rider',
        description:
            'DC Supervisor inspects incoming hub manifest, checks warehouse shelf availability, and assigns the package to an active rider in that zone.',
        role: WorkflowRole.dcAdmin,
        nodeType: FlowNodeType.process,
        icon: Icons.person_pin_circle_rounded,
        technicalDetails: [
          'Balances daily route capacity across active fleet personnel',
          'Stock moves from bulk rack to rider saddlebag custody with security PIN',
        ],
      ),
      WorkflowNode(
        id: 'ord-4',
        stepNumber: 4,
        title: 'Rider Delivers Package to Doorstep',
        description:
            'Rider follows turn-by-turn GPS navigation, contacts customer via one-tap WhatsApp call, arrives at doorstep, and captures delivery signature.',
        role: WorkflowRole.rider,
        nodeType: FlowNodeType.process,
        icon: Icons.where_to_vote_rounded,
        technicalDetails: [
          'Captures GPS arrival coordinates and recipient digital signature',
          'Transitions order state to "Arrived at Doorstep"',
        ],
      ),
      WorkflowNode(
        id: 'ord-5',
        stepNumber: 5,
        title: 'Delivery Success: Two Settlement Branches',
        description:
            'Upon successful handover, payment follows one of two distinct operational branches based on customer method.',
        role: WorkflowRole.system,
        nodeType: FlowNodeType.decision,
        icon: Icons.call_split_rounded,
        ruleReference: 'BR-003',
        technicalDetails: [
          'Branch A: Cash on Delivery (Physical currency collected)',
          'Branch B: Direct Payment (Dynamic Monnify Virtual Account / Paystack)',
        ],
        branches: [
          WorkflowBranch(
            id: 'branch-cash',
            label: 'Branch A: Cash on Delivery (COD)',
            condition: 'Customer pays physical cash at doorstep',
            destinationTitle: 'Accumulates to Remittance Vault',
            badgeText: 'Cash Custody Liability',
            accentColor: Color(0xFFEA580C),
            details: [
              'Rider collects physical naira banknotes from recipient',
              'Rider marks "Cash Paid" on mobile PDA with collected amount',
              'Cash accumulates into rider’s active cash custody ledger',
              'Rider remits physical cash to DC Vault at end of shift',
              'DC Supervisor audits count and issues SHA-256 receipt',
            ],
          ),
          WorkflowBranch(
            id: 'branch-direct',
            label: 'Branch B: Direct Payment (Monnify / Paystack)',
            condition: 'Customer pays via Dynamic Virtual Bank Transfer or Card',
            destinationTitle: 'Zero Cash Liability Settlement',
            badgeText: 'Instant Automated Webhook',
            accentColor: Color(0xFF0F172A),
            details: [
              'PDA generates dynamic order-specific virtual bank account (Wema Bank)',
              'Customer transfers funds directly to NovaXpress corporate bank',
              'Instant webhook verifies payment with 100% zero cash liability for rider',
              'Rider commission & fuel allowance credit automatically to "My Balance"',
              'Zero physical cash to remit at DC vault at end of day',
            ],
          ),
        ],
      ),
    ],
    mermaidSpec: MermaidSpec(
      diagramType: 'graph TD',
      description: 'End-to-End Order Dispatch & The Two Success Branches',
      code: '''graph TD
    A([💼 1. Client Creates Order]) --> B[🗺️ 2. Smart Routing to Closest DC by LGA]
    B --> C[🏢 3. DC Admin Assigns to Available Rider]
    C --> D[📦 4. Stock Loaded into Rider Saddlebag]
    D --> E[🏍️ 5. Rider Navigates to Doorstep via GPS]
    E --> F{6. Successful Handover & Payment}
    
    F -->|Branch A: Physical Cash| G[💵 Customer Pays Cash]
    G --> H[📋 Amount Logged into Rider Custody Ledger]
    H --> I[🏦 End of Day: Remit Cash to DC Vault]
    I --> J[🔏 Supervisor Issues SHA-256 Receipt]
    
    F -->|Branch B: Direct Transfer| K[🏦 Customer Transfers via Monnify Virtual Acct]
    K --> L[⚡ Instant Webhook Verification]
    L --> M[🛡️ ZERO Cash Liability for Rider]
    M --> N[💰 Comm + Fuel Auto-Credited to 'My Balance']
    
    J --> END([🎉 Complete Order Fulfillment])
    N --> END''',
    ),
    operationalRules: [
      OperationalRule(
        id: 'BR-003',
        category: 'Payment',
        rule: 'Every delivery has a payment type (POD or Non-POD).',
        operationalImpact: 'Determines whether payment branch A or B is engaged.',
      ),
      OperationalRule(
        id: 'BR-021',
        category: 'Payments',
        rule: 'Direct bank transfer orders generate dynamic, order-specific Monnify virtual accounts.',
        operationalImpact: 'Guarantees direct transfers are 100% auto-reconciled.',
      ),
      OperationalRule(
        id: 'BR-022',
        category: 'Liability',
        rule: 'Direct transfers do not place cash in rider physical custody (zero cash liability).',
        operationalImpact: 'Eliminates robbery and cash theft risks on field routes.',
      ),
      OperationalRule(
        id: 'BR-023',
        category: 'Earnings',
        rule: 'For Monnify direct transfers, rider commission and transport allowance accumulate automatically into "My Balance".',
        operationalImpact: 'Guarantees drivers are paid immediately upon doorstep confirmation.',
      ),
    ],
  );

  // ===========================================================================
  // 7. SCALING (Creating More DCs, Riders, Clients, Products)
  // ===========================================================================
  static const WorkflowDomain scaling = WorkflowDomain(
    id: 'scaling',
    title: 'Enterprise Scaling & Fleet Expansion',
    shortTitle: 'Scaling',
    subtitle: 'Creating DCs, Riders, Clients, Products & Elastic Fulfillment',
    overview:
        'Scaling NovaXpress requires no complex architectural rewrites. The system scales horizontally across 4 core dimensions: Provisioning new Distribution Centers, expanding the rider fleet, onboarding corporate enterprise merchants, and hosting unlimited product SKU catalogs at a low cloud footprint of ₦0.38 per delivery.',
    icon: Icons.trending_up_rounded,
    accentColor: Color(0xFFEA580C),
    activeRoles: [
      WorkflowRole.hq,
      WorkflowRole.dcAdmin,
      WorkflowRole.client,
      WorkflowRole.system,
    ],
    keyMetrics: {
      'Cloud Cost': '₦0.38 / Delivery at Scale',
      'Hub Throughput': '50k+ Daily Shipments',
      'Coverage': '774 Nigerian LGAs',
      'Concurrency': '10,000+ Active Mobile Sockets',
    },
    nodes: [
      WorkflowNode(
        id: 'scale-1',
        stepNumber: 1,
        title: 'Scaling Distribution Centers (DCs)',
        description:
            'HQ provisions new regional hubs (e.g. Port Harcourt, Ibadan, Nnewi) with instant RFC4122 v4 UUID tenant isolation and automated coverage mapping.',
        role: WorkflowRole.hq,
        nodeType: FlowNodeType.start,
        icon: Icons.add_business_rounded,
        technicalDetails: [
          'Automatic geographic routing table updates for covered LGAs',
          'Zero data migration required for existing distribution hubs',
        ],
      ),
      WorkflowNode(
        id: 'scale-2',
        stepNumber: 2,
        title: 'Scaling the Rider Fleet',
        description:
            'Rapid mobile onboarding via digital KYC and bulk motorcycle fleet allocation allows DCs to expand from 5 to 100+ active riders seamlessly.',
        role: WorkflowRole.dcAdmin,
        nodeType: FlowNodeType.process,
        icon: Icons.electric_moped_rounded,
        technicalDetails: [
          'Low bandwidth mobile app optimized for low-end Android devices',
          'Realtime WebSocket connection pooling with 30s heartbeat',
        ],
      ),
      WorkflowNode(
        id: 'scale-3',
        stepNumber: 3,
        title: 'Scaling Enterprise Clients',
        description:
            'Self-service client portal with bulk CSV order ingestion, webhooks, and automated weekly corporate bank account settlements.',
        role: WorkflowRole.client,
        nodeType: FlowNodeType.process,
        icon: Icons.diversity_3_rounded,
        technicalDetails: [
          'Asynchronous background job worker handles 10,000 CSV rows in < 4s',
          'Enterprise API access keys with granular permission scoping',
        ],
      ),
      WorkflowNode(
        id: 'scale-4',
        stepNumber: 4,
        title: 'Scaling Product SKU Catalogs',
        description:
            'Host thousands of client SKUs across multi-hub warehouses with automated stock rebalancing alerts and intelligent cross-DC fulfillment.',
        role: WorkflowRole.system,
        nodeType: FlowNodeType.end,
        icon: Icons.all_inclusive_rounded,
        technicalDetails: [
          'PostgreSQL partitioned tables for high-frequency inventory events',
          'Inter-DC transfer escrow preserves absolute inventory integrity',
        ],
      ),
    ],
    mermaidSpec: MermaidSpec(
      diagramType: 'graph TD',
      description: '4-Pillar Elastic Scaling Architecture',
      code: '''graph TD
    SCALE([🚀 NovaXpress National Scaling]) --> P1[🏢 Pillar 1: Regional DCs]
    SCALE --> P2[🛵 Pillar 2: Active Fleet]
    SCALE --> P3[💼 Pillar 3: Enterprise Clients]
    SCALE --> P4[📦 Pillar 4: Product SKUs]
    
    P1 -->|Add New Hub| DCN[Auto-Provision New Sub-DC UUID]
    DCN --> MAP[Update LGA Routing Directory]
    
    P2 -->|Add Riders| RDN[Mobile KYC + Zone Assignment]
    RDN --> CONCUR[Supavisor 10k Active Sockets]
    
    P3 -->|Add Clients| CLN[Self-Service Merchant Portal]
    CLN --> CSV[Bulk CSV Engine: 10k Orders in 4s]
    
    P4 -->|Add SKUs| SKUN[Multi-Hub Warehouse Allocation]
    SKUN --> ESCROW[Inter-DC Stock Rebalancing]
    
    MAP --> RES([⚡ 50k+ Deliveries/Day @ ₦0.38 Cloud Cost])
    CONCUR --> RES
    CSV --> RES
    ESCROW --> RES''',
    ),
    operationalRules: [
      OperationalRule(
        id: 'BR-014',
        category: 'Audit',
        rule: 'Historical transactions retain the rate that was applied when the transaction occurred (immutable rate lock).',
        operationalImpact: 'Allows scaling rate adjustments without corrupting past ledgers.',
      ),
      OperationalRule(
        id: 'BR-024',
        category: 'Payout',
        rule: 'Riders can request payout of accrued "My Balance" to their personal bank accounts, subject to DC Finance approval.',
        operationalImpact: 'Enables high driver retention through rapid liquid payouts.',
      ),
    ],
  );

  // ===========================================================================
  // 0. INTRO & SYSTEM OVERVIEW (End-to-End Operating Pipeline)
  // ===========================================================================
  static const WorkflowDomain introDomain = WorkflowDomain(
    id: 'intro',
    title: 'NovaXpress Logistics Ecosystem',
    shortTitle: 'Intro',
    subtitle: 'Autonomous Regional Routing & Cryptographic Clearing Platform',
    overview:
        'NovaXpress combines automated proximity-based LGA order routing, dual-custody warehouse and mobile saddlebag inventory with 4-digit PIN verification, direct multi-channel digital settlements, and cryptographic SHA-256 vault receipts.',
    icon: Icons.auto_awesome_rounded,
    accentColor: Color(0xFFEA580C),
    activeRoles: [
      WorkflowRole.hq,
      WorkflowRole.dcAdmin,
      WorkflowRole.rider,
      WorkflowRole.client,
      WorkflowRole.customer,
      WorkflowRole.system,
    ],
    keyMetrics: {
      'Daily Volume': '10,000+ Shipments',
      'Unit Cost': '₦0.38 / Delivery',
      'Fulfillment': '99.4% Doorstep Success',
      'Clearing': 'T+0 Instant Monnify',
    },
    nodes: [
      WorkflowNode(
        id: 'intro-1',
        stepNumber: 1,
        title: 'Enterprise Merchant Order Placement',
        description:
            'Merchants ingest orders via automated REST API, bulk CSV import, or client portal with instant SKU inventory verification.',
        role: WorkflowRole.client,
        nodeType: FlowNodeType.start,
        icon: Icons.storefront_rounded,
        ruleReference: 'BR-001',
        technicalDetails: [
          'RFC4122 v4 UUID assigned to every order',
          'Merchant company association validated via catalog registry',
          'Instant inventory hold placed on local DC shelf',
        ],
      ),
      WorkflowNode(
        id: 'intro-2',
        stepNumber: 2,
        title: 'Smart Proximity Routing to Closest Sub-DC',
        description:
            'System automatically parses receiver LGA and assigns fulfillment to the nearest regional distribution center in zero-state isolation.',
        role: WorkflowRole.system,
        nodeType: FlowNodeType.process,
        icon: Icons.route_rounded,
        ruleReference: 'BR-005',
        technicalDetails: [
          'Spatial distance algorithm calculates fastest hub polygon',
          'Sub-DC supervisor alerted in real-time dispatch queue',
        ],
      ),
      WorkflowNode(
        id: 'intro-3',
        stepNumber: 3,
        title: 'Rider Dual-Custody Saddlebag Handover',
        description:
            'Warehouse supervisor hands physical package to dispatch rider with 4-digit OTP PIN handshake, transferring custody from shelf to saddlebag.',
        role: WorkflowRole.dcAdmin,
        nodeType: FlowNodeType.process,
        icon: Icons.two_wheeler_rounded,
        ruleReference: 'BR-011',
        technicalDetails: [
          'Two-party cryptographic PIN verification prevents phantom dispatch',
          'Rider mobile PDA enters turn-by-turn turn route',
        ],
      ),
      WorkflowNode(
        id: 'intro-4',
        stepNumber: 4,
        title: 'Doorstep Settlement: Cash vs Direct Payment',
        description:
            'Customer receives shipment and settles either via physical cash (accruing to rider vault remittance) or dynamic Monnify virtual account.',
        role: WorkflowRole.customer,
        nodeType: FlowNodeType.decision,
        icon: Icons.payments_rounded,
        ruleReference: 'BR-018',
        technicalDetails: [
          'Branch A: Cash on Delivery logged into physical custody ledger',
          'Branch B: Direct bank transfer triggers instant webhook and clears cash liability',
        ],
        branches: [
          WorkflowBranch(
            id: 'intro-branch-cash',
            badgeText: 'BRANCH A',
            label: 'Cash on Delivery (COD)',
            condition: 'Customer hands physical cash to rider',
            destinationTitle: 'Accumulates to Remittance Vault',
            accentColor: Color(0xFFF59E0B),
            details: [
              'Rider collects physical cash from customer',
              'Logged into rider cash custody ledger',
              'Remitted to DC vault at end of shift',
            ],
          ),
          WorkflowBranch(
            id: 'intro-branch-direct',
            badgeText: 'BRANCH B',
            label: 'Direct Payment (Monnify / Paystack)',
            condition: 'Customer transfers to dynamic virtual account',
            destinationTitle: 'Zero Cash Liability Settlement',
            accentColor: Color(0xFF10B981),
            details: [
              'Instant webhook verifies bank transfer',
              'Zero cash liability for field dispatch driver',
              'Commission paid directly to driver balance',
            ],
          ),
        ],
      ),
      WorkflowNode(
        id: 'intro-5',
        stepNumber: 5,
        title: 'End-of-Day 3-Way Reconciliation & SHA-256 Receipt',
        description:
            'Supervisor audits delivered orders, returned stock, and remitted cash, generating an immutable cryptographic digital signature.',
        role: WorkflowRole.hq,
        nodeType: FlowNodeType.end,
        icon: Icons.verified_user_rounded,
        ruleReference: 'BR-021',
        technicalDetails: [
          'Stock Out == Delivered PODs + Returned Units',
          'SHA-256 digital certificate issued to rider mobile PDA',
        ],
      ),
    ],
    mermaidSpec: MermaidSpec(
      diagramType: 'graph TD',
      description: 'End-to-end NovaXpress logistics and clearing pipeline.',
      code: '''graph TD
    A([💼 1. Enterprise Client Order]) --> B[🗺️ 2. Smart Routing to Closest DC]
    B --> C[📦 3. Rider Saddlebag Custody & PIN]
    C --> D{4. Doorstep Settlement}
    D -->|Branch A: Physical Cash| E[💵 Cash Remittance to DC Vault]
    D -->|Branch B: Direct Pay| F[⚡ Monnify Zero Liability Transfer]
    E --> G([🔏 5. SHA-256 Digital Receipt])
    F --> G''',
    ),
    operationalRules: [
      OperationalRule(
        id: 'BR-001',
        category: 'Routing',
        rule: 'Orders must route strictly to the geographically nearest DC hub based on recipient LGA coordinates.',
        operationalImpact: 'Prevents inter-hub delivery delays and fuel waste.',
      ),
      OperationalRule(
        id: 'BR-018',
        category: 'Settlement',
        rule: 'Cash on Delivery requires daily physical vault remittance; Direct payments clear instantly with zero driver cash liability.',
        operationalImpact: 'Eliminates revenue leakage and protects drivers.',
      ),
    ],
  );

  /// All 7 operational workflow domains in order
  static const List<WorkflowDomain> allDomains = [
    generalStructure,
    creatingRiders,
    creatingProducts,
    stockMovements,
    remittance,
    orders,
    scaling,
  ];

  /// Find domain by its identifier
  static WorkflowDomain findById(String id) {
    return allDomains.firstWhere(
      (d) => d.id == id,
      orElse: () => generalStructure,
    );
  }

  /// Map 6 core features to matching workflow domain
  static WorkflowDomain domainForFeature(String featureId) {
    switch (featureId) {
      case 'orders':
        return orders;
      case 'structure':
        return generalStructure;
      case 'sock':
        return stockMovements;
      case 'remitance':
      case 'payments':
        return remittance;
      case 'scaling':
        return scaling;
      default:
        return generalStructure;
    }
  }
}
