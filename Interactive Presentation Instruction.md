# NoveXPS Interactive Presentation Hub (React + Vite)

The interactive presentation has been built as a standalone **React + Vite** single-page application inside [`presentations/`](file:///c:/PROJECT/NoveXPS/presentations).

## Accessing the Presentation
- **Live React Dev Server**: [http://localhost:5173](http://localhost:5173) (Running on Vite with live hot-reloading)
- **Local Network**: [http://192.168.1.10:5173](http://192.168.1.10:5173)
- **Root Launcher**: [`presentation.html`](file:///c:/PROJECT/NoveXPS/presentation.html)
- **In-App Launcher**: Click `Open Interactive System Presentation` from the Flutter web login screen or the top app bar slideshow icon in the DC Console.

---

## What is Included (From Single Entry Point)

### 1. Executive Summary & Problem-Solution Canvas
- Nigeria logistics challenges (POD cash leakage, sub-hub data leaks, stock blindspots, driver turnover) vs. NoveXPS architectural countermeasures.
- 4 Live KPI metrics (100% Sub-DC Isolation, 2-in-1 Dual Inventory, 3-Way Payment Reconciliation, 87% Quota Optimization).

### 2. The 4-Quadrant Operational Matrix & Business Rules (BR-001 to BR-024)
- **Quadrant 1**: Client Package • Non-POD (Pure last-mile courier)
- **Quadrant 2**: Client Package • Pay on Delivery (Pre-labeled with doorstep collection)
- **Quadrant 3**: Distributed Inventory • Non-POD (Prepaid bulk stock fulfillment)
- **Quadrant 4**: Distributed Inventory • Pay on Delivery (Core e-commerce powerhouse)
- **Master Business Rules (BR-001 to BR-024)**: Searchable with live category filters and `Ctrl+K` modal.

### 3. Multi-Role Architecture & Features
- **HQ Central Executive**: National DC network, inter-DC stock rebalancing, enterprise rate governance, central treasury.
- **DC Operations Supervisor**: Sub-DC zero-state isolation, saddlebag custody, remittance verification, QC restock desk.
- **Dispatch Rider / PDA**: Turn-by-turn navigation, Monnify virtual account display, "My Balance" ledger, doorstep photo/signature POD.
- **Enterprise Client / Merchant**: SKU catalog management, package bundle pricing, CSV bulk order ingestion, COD settlement ledger.

### 4. End-to-End Operational Lifecycle & Flowcharts
- Interactive SVG flowcharts for Order Lifecycle (Ingestion $\rightarrow$ DC Scoping $\rightarrow$ Saddlebag Custody $\rightarrow$ Doorstep Arrival $\rightarrow$ Remittance Audit).
- Inter-DC Stock Rebalancing flow with in-transit escrow tracking.
- Returns, Exchanges, and QC restock workflow.

### 5. Payments & Financial Engineering
- Physical COD limits (₦50,000 max hold per rider).
- **Monnify Dynamic Virtual Accounts**: USSD/Bank transfer directly to company bank with **zero cash liability** for riders and automated credit to "My Balance".
- **Paystack Card & POS** terminals.
- Cryptographic tamper-evident remittance receipts with SHA-256 digital signature hashes.

### 6. Cloud Costing, Server Charges & Maintenance
- Transparent OpEx table: Supabase Pro ($25/mo), compute add-ons ($10-$160/mo), Supavisor connection pooling, storage ($0.021/GB), gateway fees (Monnify 0.75% cap ₦200, Paystack 1.5%), SMS alerts (Termii ₦3.50).
- Scale projections: 1k, 10k, and 50k orders/day (showing server cost dropping to ₦0.38 per delivery).

### 7. Current Operational Challenges & Architectural Countermeasures
- Physical Cash Leakage $\rightarrow$ Monnify Dynamic Accounts.
- Sub-Hub Data Cross-Talk $\rightarrow$ Sub-DC Zero-State Scoping.
- Cellular Dead Zones $\rightarrow$ Dual-layer local cache (Hive + SharedPreferences).
- Regional Stock Depletion $\rightarrow$ Inter-DC stock transfers with escrow.
- Driver Turnover $\rightarrow$ Configuration-driven compensation locked at order creation.

### 8. Live Interactive ROI & Profit Calculator
- Reactive sliders for Daily Orders, DCs, Active Riders, AOV, and Direct Transfer %.
- Instant real-time calculation of GMV, Platform Delivery Revenue, Rider Payouts, Cloud Server Costs, Gateway Fees, and Net Operating Margin % / Profit in ₦.

### 9. Technical Stack & Verification
- Flutter Clean Architecture, Riverpod 2.x, Supabase PostgreSQL 15, Hive offline cache, 21/21 passing test suites.
