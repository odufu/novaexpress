/**
 * Centralized Domain Data for NoveXPS Master Interactive Presentation
 * Includes Mermaid Diagram Specifications for all Operational Roles & Workflows
 */

export const PRESENTATION_SLIDES = [
  { id: 'hero', title: 'Executive Overview & Brand Canvas' },
  { id: 'workflows', title: 'Mermaid Operational Role Workflows' },
  { id: 'matrix', title: 'Operational Matrix & Rules (BR 1-24)' },
  { id: 'roles', title: 'Multi-Role Architecture & Features' },
  { id: 'payments', title: 'Payments & Remittance Engineering' },
  { id: 'costing', title: 'Cloud Costing & Server Charges' },
  { id: 'challenges', title: 'Current Challenges & Solutions' },
  { id: 'calculator', title: 'Live Dynamic ROI Calculator' },
  { id: 'tech', title: 'Technical Stack & Verification' },
];

export const EXECUTIVE_STATS = [
  {
    value: '100%',
    label: 'Sub-DC Data Isolation',
    sublabel: 'Zero-State Regional Scoping',
    color: 'emerald',
    icon: 'ShieldCheck',
  },
  {
    value: '2-in-1',
    label: 'Dual Inventory Fulfillment',
    sublabel: 'Distributed Stock + Client Parcels',
    color: 'cyan',
    icon: 'Layers',
  },
  {
    value: '3-Way',
    label: 'Payment Reconciliation',
    sublabel: 'COD Cash • POS • Monnify Virtual Acct',
    color: 'amber',
    icon: 'CreditCard',
  },
  {
    value: '87%',
    label: 'Quota Reduction',
    sublabel: '30s Heartbeat + Push Channels',
    color: 'purple',
    icon: 'Zap',
  },
];

export const OPERATIONAL_MATRIX = [
  {
    id: 'quadrant-1',
    fulfillment: 'Client Package',
    payment: 'Non-POD (Prepaid)',
    badgeColor: 'cyan',
    title: 'Client Package • Non-POD',
    description: 'Merchant supplies pre-packed, pre-paid parcels. NovaExpress acts as pure last-mile courier. Zero cash collected at doorstep.',
    steps: ['Merchant Prep', 'DC Hub Ingestion', 'Rider Route Assignment', 'Doorstep POD Signature'],
    settlement: 'Platform fee billed to merchant monthly. Zero rider cash liability.',
  },
  {
    id: 'quadrant-2',
    fulfillment: 'Client Package',
    payment: 'POD (Pay on Delivery)',
    badgeColor: 'amber',
    title: 'Client Package • Pay on Delivery',
    description: 'Client provides pre-labeled parcel, but rider must collect payment (Cash or Monnify Direct Transfer) before handing over package.',
    steps: ['Package Ingestion', 'Rider Manifest Delivery', 'Doorstep Cash / Monnify Virtual Account', 'Daily DC Remittance'],
    settlement: 'Rider remits collected cash to DC Vault. Monnify transfers auto-credit merchant ledger.',
  },
  {
    id: 'quadrant-3',
    fulfillment: 'Distributed Inventory',
    payment: 'Non-POD (Prepaid)',
    badgeColor: 'purple',
    title: 'Distributed Inventory • Non-POD',
    description: 'Merchant supplies bulk stock (Grazer Tea, Respira, Alpha Man) stored across regional DCs. Orders pick and fulfill directly from local warehouse.',
    steps: ['Bulk DC Inward Scan', 'Order Creation & SKU Picking', 'Saddlebag Custody PIN', 'Prepaid Doorstep Delivery'],
    settlement: 'Stock decrements in real time from DC inventory. Fulfill fee charged to client account.',
  },
  {
    id: 'quadrant-4',
    fulfillment: 'Distributed Inventory',
    payment: 'POD (Pay on Delivery)',
    badgeColor: 'emerald',
    title: 'Distributed Inventory • Pay on Delivery',
    description: 'The core e-commerce powerhouse: Order fulfilled from local DC inventory, delivered to customer doorstep, payment collected via Cash or Dynamic Virtual Account.',
    steps: ['Warehouse Stock Pick', 'Rider Custody Handover', 'Doorstep Collection (COD/Transfer)', 'DC Reconcile & Restock QC'],
    settlement: 'Full 3-way reconciliation: Physical stock, cash holding, and merchant net payout.',
  },
];

export const BUSINESS_RULES = [
  { id: 'BR-001', category: 'Client', text: 'Every delivery belongs to a client.' },
  { id: 'BR-002', category: 'Order', text: 'Every delivery has a fulfillment type (Client Package or Distributed Inventory).' },
  { id: 'BR-003', category: 'Payment', text: 'Every delivery has a payment type (POD or Non-POD).' },
  { id: 'BR-004', category: 'POD', text: 'POD deliveries require physical collection tracking.' },
  { id: 'BR-005', category: 'Remittance', text: 'POD collections require reconciliation at the host DC.' },
  { id: 'BR-006', category: 'Billing', text: 'Successful deliveries generate client logistics charges.' },
  { id: 'BR-007', category: 'Billing', text: 'Failed deliveries may generate client charges according to the client agreement.' },
  { id: 'BR-008', category: 'Inventory', text: 'Failed distributed-inventory deliveries require physical stock return.' },
  { id: 'BR-009', category: 'Inventory', text: 'Returned stock must be physically verified by the receiving DC before inventory is restored.' },
  { id: 'BR-010', category: 'Compensation', text: 'Delivery personnel compensation is configuration-driven (Commission + Transport).' },
  { id: 'BR-011', category: 'Personnel', text: 'PDA and Rider compensation may differ based on vehicle and contractual terms.' },
  { id: 'BR-012', category: 'Personnel', text: 'Salary-based personnel may have no per-delivery commission.' },
  { id: 'BR-013', category: 'Earnings', text: 'Commission-based personnel accumulate earnings in their personal "My Balance" ledger.' },
  { id: 'BR-014', category: 'Audit', text: 'Historical transactions retain the rate that was applied when the transaction occurred (immutable rate lock).' },
  { id: 'BR-015', category: 'Security', text: 'Agents cannot alter rates or compensation parameters.' },
  { id: 'BR-016', category: 'Financial', text: 'POS fees are separate financial transactions and do not deduct from order collection value.' },
  { id: 'BR-017', category: 'Remittance', text: 'Remittances require verification by DC Operations Manager before clearing rider status.' },
  { id: 'BR-018', category: 'Audit', text: 'Financial variances must be immediately visible in real time on the DC dashboard.' },
  { id: 'BR-019', category: 'Inventory', text: 'Inventory discrepancies require mandatory resolution before close-of-day.' },
  { id: 'BR-020', category: 'Security', text: 'Every important financial and inventory action must be cryptographically auditable.' },
  { id: 'BR-021', category: 'Payments', text: 'Direct bank transfer orders generate dynamic, order-specific Monnify virtual accounts.' },
  { id: 'BR-022', category: 'Liability', text: 'Direct transfers to the company account do not place cash in the rider physical custody (zero cash liability).' },
  { id: 'BR-023', category: 'Earnings', text: 'For Monnify direct transfers, rider commission and transport allowance accumulate automatically into "My Balance".' },
  { id: 'BR-024', category: 'Payout', text: 'Riders can request payout of accrued "My Balance" to their personal bank accounts, subject to DC Finance approval.' },
];

/**
 * MERMAID DIAGRAM DEFINITIONS
 */
export const MERMAID_ROLE_WORKFLOWS = {
  riderDelivery: {
    id: 'diag-rider-delivery',
    title: 'Rider Delivery Lifecycle',
    subtitle: 'From App Login to Doorstep Collection & Payout Request',
    badge: 'Dispatch Operations',
    actor: 'Dispatch Rider / PDA',
    chart: `graph TD
    A([📱 1. Login to Rider App]) --> B[📦 2. Open Delivery Manifest]
    B --> C[🔍 3. Inspect First Order in Sequence]
    C --> D[💬 4. Tap to Contact via WhatsApp / Phone Call]
    D --> E[🏍️ 5. Start Delivery Route - Capture GPS Telemetry]
    E --> F{6. Customer Doorstep Handover}
    F -->|Cash on Delivery| G[💵 Collect Physical Cash & Sign POD]
    F -->|Bank Transfer| H[🏦 Generate Dynamic Monnify Virtual Acct]
    H --> I[⚡ Customer Transfers Funds Directly to Bank]
    I --> J[✓ Automated Webhook Verification - Zero Cash Liability]
    G --> K[📋 7. Remit Collected Cash to DC Vault]
    J --> L[💰 8. Comm + Fuel Credited to 'My Balance']
    L --> M([💳 9. Request Instant Payout to Bank Account])
    style A fill:#006C4C,stroke:#004D36,color:#fff
    style D fill:#FFF4EB,stroke:#F37021,color:#0F172A
    style H fill:#E6F4EA,stroke:#006C4C,color:#0F172A
    style M fill:#F37021,stroke:#D6560B,color:#fff`,
  },

  remittanceFlow: {
    id: 'diag-remittance',
    title: 'Digital Remittance & Settlement Machine',
    subtitle: 'Real-time Fund Clearance via Paystack / Monnify',
    badge: 'Cashless Vault Clearing',
    actor: 'Rider & Finance Desk',
    chart: `sequenceDiagram
    autonumber
    actor Rider as 🛵 Dispatch Rider
    participant App as 📱 Rider Mobile App
    participant Gateway as 💳 Paystack / Monnify Gateway
    participant Supabase as ⚡ Supabase Edge & DB
    participant DCManager as 🏢 DC Finance Manager

    Rider->>App: Login & Open Remittance Tab
    App->>Rider: Display Total Cash On Hand to Remit (e.g. ₦45,000)
    Rider->>App: Click "Initiate Digital Remittance"
    App->>Gateway: Request Dynamic Virtual Remittance Account
    Gateway-->>App: Return Dedicated Virtual Account (Wema Bank #82910...)
    Rider->>Gateway: Transfer Funds via USSD / Mobile Banking
    Gateway->>Supabase: Dispatch Instant Webhook (Status: Success)
    Supabase->>App: Realtime Event - Remittance Confirmed
    Supabase->>DCManager: Mark Cash Holding Cleared in DC Ledger
    DCManager->>Supabase: Generate Cryptographic SHA-256 Receipt
    Supabase-->>App: Push Tamper-Evident Receipt Badge to Rider
    note over Rider,DCManager: Status: 100% Cleared • Zero Cash Discrepancy`,
  },

  restockingFlow: {
    id: 'diag-restocking',
    title: 'DC Stock Restocking & Inter-Hub Transfer',
    subtitle: 'National Hub-and-Spoke Inventory Replenishment',
    badge: 'Inventory Architecture',
    actor: 'Warehouse & HQ Logistics',
    chart: `graph LR
    subgraph S1 [Primary Depot - Lagos HQ]
      A[🏭 Bulk Merchant Inward] --> B[🔍 Barcode Scan & Count]
      B --> C[(📦 DC Shelf Inventory)]
    end
    
    subgraph S2 [Inter-DC Transfer Escrow]
      C -->|Low Stock Alert in Kano| D[🚚 Create Transfer Manifest]
      D --> E[🔒 Stock Escrow - In-Transit Status]
    end

    subgraph S3 [Regional Hub - Kano DC]
      E --> F[📥 Vehicle Arrival & Physical Inspection]
      F --> G{QC Passed?}
      G -->|Yes| H[(✅ Accepted into Local Inventory)]
      G -->|Damaged| I[⚠️ Flag Discrepancy to HQ]
    end
    style A fill:#006C4C,stroke:#004D36,color:#fff
    style E fill:#FFF4EB,stroke:#F37021,color:#0F172A
    style H fill:#E6F4EA,stroke:#006C4C,color:#0F172A`,
  },

  reconciliationFlow: {
    id: 'diag-reconciliation',
    title: 'Close-of-Day Stock & Cash Reconciliation',
    subtitle: 'Zero-Discrepancy Daily Audit Protocol',
    badge: 'Loss Prevention & Audit',
    actor: 'DC Operations Supervisor',
    chart: `graph TD
    A([🕒 Close-of-Day Audit Initiated]) --> B[📦 Count Physical Warehouse Stock]
    A --> C[🛵 Retrieve Rider Saddlebag Custody Ledger]
    B --> D[📊 Compute Total Dispatched vs Delivered]
    C --> D
    D --> E{Check Returns & Damaged Stock}
    E --> F[🔍 Match with Delivered POD Orders]
    F --> G{Discrepancy Detected?}
    G -->|Zero Variance| H[✅ Reconcile Cleared - Issue Daily Sign-Off]
    G -->|Shortage Found| I[⚠️ Lock Rider Account & Require Investigation]
    H --> J[🔒 Generate Cryptographic Batch Record]
    J --> K([🏦 Sync Clean Daily Ledger to HQ Treasury])
    style A fill:#006C4C,stroke:#004D36,color:#fff
    style H fill:#E6F4EA,stroke:#006C4C,color:#0F172A
    style I fill:#FEF2F2,stroke:#E11D48,color:#991B1B
    style K fill:#F37021,stroke:#D6560B,color:#fff`,
  },

  dcSupervisorFlow: {
    id: 'diag-dc-supervisor',
    title: 'DC Operations Supervisor Full Workflow',
    subtitle: 'Isolated Sub-Hub Daily Management',
    badge: 'Hub Operations',
    actor: 'DC Manager',
    chart: `graph TD
    A([🏢 1. Login to DC Console]) --> B[📋 2. Review Sub-DC Order Manifest]
    B --> C[🛵 3. Balance Workloads & Assign to Active Fleet]
    C --> D[📦 4. Hand Over Stock Packages with Saddlebag PIN]
    D --> E[📡 5. Live Telemetry - Track Active Deliveries]
    E --> F[💵 6. Receive Rider Cash Remittances & Verify Transfers]
    F --> G[🔏 7. Generate Tamper-Evident SHA-256 Receipt]
    G --> H[🔍 8. QC Desk: Verify Customer Returns & Restock]
    H --> I([📊 9. Daily Close: Export Sub-DC Audit Ledger])
    style A fill:#006C4C,stroke:#004D36,color:#fff
    style G fill:#E6F4EA,stroke:#006C4C,color:#0F172A
    style I fill:#F37021,stroke:#D6560B,color:#fff`,
  },

  hqExecutiveFlow: {
    id: 'diag-hq-executive',
    title: 'HQ Central Command & National Governance',
    subtitle: 'National Liquidity & Multi-Hub Oversight',
    badge: 'Executive Governance',
    actor: 'HQ Leadership',
    chart: `graph TD
    A([🏛️ 1. Login to HQ Command Center]) --> B[🗺️ 2. National Hub Network Directory]
    B --> C[📦 3. Monitor Cross-DC Stock Volumes]
    C --> D[🚚 4. Authorize Inter-DC Rebalancing Transfers]
    D --> E[💰 5. Audit Central National Remittance Batches]
    E --> F[🏦 6. Verify Monnify Corporate Direct Bank Transfers]
    F --> G[💳 7. One-Click Approval for Rider Payout Claims]
    G --> H([📈 8. Review Enterprise Client Delivery SLA Metrics])
    style A fill:#006C4C,stroke:#004D36,color:#fff
    style G fill:#E6F4EA,stroke:#006C4C,color:#0F172A
    style H fill:#F37021,stroke:#D6560B,color:#fff`,
  },

  clientMerchantFlow: {
    id: 'diag-client-merchant',
    title: 'Enterprise Client / Merchant Workflow',
    subtitle: 'Fulfillment Intake to Corporate Settlement',
    badge: 'Merchant Portal',
    actor: 'E-Commerce Merchant',
    chart: `graph TD
    A([💼 1. Login to Client Merchant Portal]) --> B[📑 2. Upload Daily Orders via Bulk CSV]
    B --> C[🏷️ 3. Select SKU Bundles & Pricing Tiers]
    C --> D[📦 4. NovaExpress Regional DCs Fulfill Orders]
    D --> E[📍 5. Real-Time Telemetry Tracking of Doorstep POD]
    E --> F[💵 6. NovaExpress Collects COD / Virtual Bank Transfer]
    F --> G[📊 7. Live Audit of Accrued Remittance Balances]
    G --> H([🏦 8. Weekly Automated Corporate Bank Settlement])
    style A fill:#006C4C,stroke:#004D36,color:#fff
    style E fill:#E6F4EA,stroke:#006C4C,color:#0F172A
    style H fill:#F37021,stroke:#D6560B,color:#fff`,
  },
};

export const ROLE_DETAILS = {
  hq: {
    title: 'Headquarters Central Executive',
    badge: 'National Governance',
    icon: 'Building2',
    description: 'Central command authority overseeing national logistics, multi-hub expansion, inter-DC stock rebalancing, and centralized treasury settlement.',
    features: [
      {
        title: 'National Hub Network Management',
        desc: 'Register new regional DCs (Lagos, Abuja, Kano, Kaduna, Nnewi). Provision supervisor credentials with automated RFC4122 v4 UUID assignment.',
      },
      {
        title: 'Inter-DC Stock Rebalancing Engine',
        desc: 'Dispatch bulk inventory transfers from primary hubs to regional sub-hubs with escrow tracking and transit manifests.',
      },
      {
        title: 'Enterprise Rate Governance',
        desc: 'Define standard commission tiers (₦1,000/deliv), fuel allowances (₦1,500/deliv), POS fee rules, and client billing agreements.',
      },
      {
        title: 'Central Treasury & Bank Disbursements',
        desc: 'Audit all national remittance batches, verify Monnify collections, and disburse rider accrued earnings via bulk bank transfer.',
      },
    ],
    mockupCode: `// hq_national_governance_stream.dart
final nationalMetrics = ref.watch(hqTreasuryProvider);
print("HQ Total National Liquidity: ₦\${nationalMetrics.vaultBalance}");
print("Active DC Network: 6 Hubs (Lagos, Abuja, PH, Kano, Kaduna, Nnewi)");
print("Inter-DC Restock Escrow: 500x Respira (Lagos -> Kano)");
print("Pending Rider Payouts: 14 claims (₦35,000) [APPROVED]");`,
  },
  dc: {
    title: 'DC Operations Supervisor',
    badge: 'Regional Hub Scoping',
    icon: 'Warehouse',
    description: 'Ground operations manager responsible for warehouse stock custody, driver manifest balancing, POD cash verification, and tamper-evident remittance receipts.',
    features: [
      {
        title: 'Sub-DC Zero-State Isolation',
        desc: 'Complete data boundary: Sub-DC supervisors only see local riders, local orders, and local cash (starting at ₦0.00, never inheriting global data).',
      },
      {
        title: 'Saddlebag Custody & Gate PIN',
        desc: 'Handover warehouse products to riders with digital custody PINs. System tracks stock moving from shelf to saddlebag.',
      },
      {
        title: 'Remittance Verification & SHA-256 Receipts',
        desc: 'Accept daily physical cash handover from returning riders. Match against delivered POD orders and generate digital tamper-evident receipts.',
      },
      {
        title: 'QC Returns & Restock Desk',
        desc: 'Inspect rejected or cancelled packages returned by riders before approving inventory restock into warehouse racks.',
      },
    ],
    mockupCode: `// dc_operations_console.dart
final dcRoster = ref.watch(dcConsoleProvider);
print("Active Hub: Kano Central Depot (DC-KAN-01)");
print("Local Inventory: 140x Respira | 85x Grazer Tea");
print("Daily Remittance Received: ₦25,000 (Rider Mustapha)");
print("Cryptographic Hash: SHA256-a8f9c2d14b8e7... [VERIFIED]");`,
  },
  rider: {
    title: 'Dispatch Rider & PDA',
    badge: 'Last-Mile Telemetry',
    icon: 'Bike',
    description: 'Field delivery agent equipped with mobile-first turn-by-turn navigation, WhatsApp customer location links, Monnify virtual accounts, and real-time earnings ledger.',
    features: [
      {
        title: 'Turn-by-Turn Manifest & WhatsApp Direct',
        desc: 'View assigned orders, launch one-tap WhatsApp customer location chat, and record GPS doorstep arrival telemetry.',
      },
      {
        title: 'Monnify Dynamic Virtual Account Display',
        desc: 'Generate order-specific virtual bank accounts on demand. Customer transfers funds directly to company bank with zero cash handling.',
      },
      {
        title: '"My Balance" Ledger & Payout Requests',
        desc: 'Earn commission + transport allowance instantly upon delivery. Request direct bank payout to personal account anytime.',
      },
      {
        title: 'Doorstep Digital Signature & Photo POD',
        desc: 'Capture recipient signature and package photo at doorstep, syncing instantly to merchant portal.',
      },
    ],
    mockupCode: `// rider_mobile_pda_portal.dart
print("Order #NX-8491 -> Chief Emmanuel (Wuse II)");
print("Payment: Monnify Transfer (Wema Bank 8291048201)");
print("GPS Telemetry: 9.0765° N, 7.3986° E (Doorstep Verified)");
print("Accrued to My Balance: +₦2,500 (Commission + Fuel)");`,
  },
  client: {
    title: 'Enterprise Client / Merchant',
    badge: 'Merchant Portal',
    icon: 'Store',
    description: 'E-commerce merchants and pharmaceutical brands utilizing NoveXPS for distributed inventory warehousing, bulk dispatch, and automated remittance settlement.',
    features: [
      {
        title: 'Product SKU Catalog & Package Bundles',
        desc: 'Manage SKUs, product package tiers (1 Bottle, 2 Bottles + Free Balm), and track live stock counts across all 6 Nigerian regional DCs.',
      },
      {
        title: 'CSV Bulk Order Ingestion',
        desc: 'Upload hundreds of daily delivery orders via CSV. Auto-cleans phone numbers, resolves states to local DCs, and detects duplicates.',
      },
      {
        title: 'Real-Time Delivery & COD Settlement Ledger',
        desc: 'Live tracking of order progress and accrued COD collections. Direct automated disbursements to corporate bank accounts.',
      },
      {
        title: 'Delivery Performance Analytics',
        desc: 'Monitor delivery success rate (averaging 89.4%), return rates by state, and customer fulfillment times.',
      },
    ],
    mockupCode: `// client_portal_merchant_analytics.dart
print("Merchant: Grazer Wellness Enterprise Ltd");
print("National Stock: 1,420 units across 6 DCs");
print("Accrued Net COD Balance: ₦3,480,000");
print("Overall Delivery Success Rate: 89.4% (Industry Leading)");`,
  },
};

export const SERVER_COSTING_DATA = [
  {
    category: 'Database & Auth',
    provider: 'Supabase Pro Tier (Postgres 15)',
    unitUsd: '$25.00 / mo',
    unitNgn: '₦38,750',
    description: 'Shared 8GB RAM compute, 100k Monthly Active Users, daily WAL automated backups, 7-day Point-in-Time Recovery.',
  },
  {
    category: 'Database Compute Add-on',
    provider: 'Supabase Micro / Small Add-on',
    unitUsd: '$10 - $60 / mo',
    unitNgn: '₦15,500 - ₦93,000',
    description: 'Dedicated 2-core CPU + 4GB RAM. Supavisor connection pooler handles 10,000 concurrent mobile & web connections.',
  },
  {
    category: 'Realtime WebSocket Channels',
    provider: 'Supabase Realtime Engine',
    unitUsd: 'Included in Pro',
    unitNgn: '₦0 (Zero Extra)',
    description: '30s heartbeat optimization reduced REST polling by 87%, remaining safely under Pro quota while keeping instant WebSocket pushes.',
  },
  {
    category: 'Blob Storage & CDN',
    provider: 'Supabase Storage (S3 API)',
    unitUsd: '$0.021 / GB',
    unitNgn: '100GB Included',
    description: 'Compresses product images, rider license documents, proof-of-delivery signatures, and PDF remittance receipts.',
  },
  {
    category: 'Dynamic Virtual Accounts',
    provider: 'Monnify / TeamApt Gateway',
    unitUsd: '0.75% (Cap ₦200)',
    unitNgn: 'Per Transfer',
    description: 'Only charged on successful bank transfers. Capped at ₦200 even for ₦100,000 orders. Zero monthly maintenance charge.',
  },
  {
    category: 'Card & POS Processing',
    provider: 'Paystack Payment Gateway',
    unitUsd: '1.5% (Cap ₦2,000)',
    unitNgn: 'Per Card Txn',
    description: 'Standard domestic card fee. Dedicated POS terminals available with ₦0 monthly fee for active merchants.',
  },
  {
    category: 'Customer SMS Alerts',
    provider: 'Termii Messaging API',
    unitUsd: '₦3.50 / SMS',
    unitNgn: 'Pay-as-you-go',
    description: 'Outbound delivery alerts sent to customer: "Rider is 5 mins away with your Grazer Tea package".',
  },
];

export const CURRENT_CHALLENGES_DATA = [
  {
    id: 'ch-1',
    title: 'Physical Cash on Delivery (COD) Leakage',
    category: 'Financial Risk',
    challenge: 'Dispatch riders collecting high volumes of cash face robbery hazards, delayed physical remittances, and temptation to "borrow" cash for personal emergencies before close-of-day.',
    solution: 'NoveXPS Monnify Dynamic Virtual Accounts generate unique Wema/Sterling bank accounts per order. Customers pay directly to company bank account, completely removing cash from rider custody (BR-021 & BR-022).',
    impact: '100% elimination of cash shrinkage for bank transfer orders, reducing rider physical cash holding by over 45%.',
    icon: 'Banknote',
  },
  {
    id: 'ch-2',
    title: 'Sub-Hub Data Cross-Talk & Privacy Leaks',
    category: 'Multi-Tenant Security',
    challenge: 'When expanding to regional hubs (Kano, Kaduna, Nnewi), supervisors could previously see other distribution centers’ cash remittances, driver rosters, and order histories.',
    solution: 'Engineered strict Sub-DC Zero-State Scoping. Non-primary DCs boot with clean ₦0.00 ledgers, scoped strictly to their own distribution_center_id, with hidden national switcher navigation.',
    impact: 'Strict multi-hub isolation, zero unauthorized cross-hub visibility, and seamless branch expansion.',
    icon: 'ShieldAlert',
  },
  {
    id: 'ch-3',
    title: 'Intermittent Cellular Connectivity & Dead Zones',
    category: 'Infrastructure',
    challenge: 'In suburban and rural delivery zones across Nigeria, cellular data regularly drops, causing app freezing, lost proof-of-delivery photos, and failed order status updates.',
    solution: 'Dual-layer local cache architecture (Hive + SharedPreferences). Orders, manifests, and stock allocations are cached locally. Status transitions store offline and sync automatically upon network reconnection.',
    impact: 'Riders deliver seamlessly without cellular data; zero order loss during field drop-offs.',
    icon: 'WifiOff',
  },
  {
    id: 'ch-4',
    title: 'Regional Inventory Depletion & Stock Blindspots',
    category: 'Supply Chain',
    challenge: 'Fast-moving products (Respira, Grazer Tea) sell out in northern hubs like Kano while inventory sits idle in Lagos, resulting in cancelled customer orders.',
    solution: 'Inter-DC Stock Transfer Architecture with Escrow Tracking. HQ can dispatch stock between hubs with automatic quantity decrement, in-transit status, and QC verification scan on arrival.',
    impact: 'National inventory balance, reduced stockouts, and accelerated fulfillment times across Nigeria.',
    icon: 'PackageCheck',
  },
  {
    id: 'ch-5',
    title: 'Driver Turnover & Disputed Compensation',
    category: 'Human Operations',
    challenge: 'Riders often dispute fuel allowances and commission payouts, leading to strikes, delivery delays, and high fleet attrition.',
    solution: 'Configuration-driven compensation rules (BR-010 to BR-015) locked at order creation. Real-time "My Balance" ledger accrues earnings instantly. Riders click "Request Payout" for bank transfer with DC approval.',
    impact: 'Complete financial transparency, zero commission disputes, and industry-leading rider retention.',
    icon: 'Users',
  },
];
