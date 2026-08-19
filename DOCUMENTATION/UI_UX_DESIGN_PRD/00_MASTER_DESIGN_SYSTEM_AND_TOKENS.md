# 🎨 NoveXPS Master Design System, Style Guide & UI Tokens for UI/UX Designers

This document defines the overarching design system, visual identity, color tokens, typography scales, spacing units, and component patterns for the entire **NovaExpress Logistics Management System (NoveXPS)** across Mobile (PDA), Tablet (DC Terminals), and Desktop Web (HQ / Admin Portals).

---

## 🌈 Brand Identity & Color Palette

### 1. Primary & Brand Colors
* **Primary Brand Navy**: `#0F172A` (Slate 900) — Dominant header, sidebar, and primary CTA background.
* **Primary Accent Blue**: `#2563EB` (Blue 600) — Primary interactive buttons, active tab indicators, links.
* **Secondary Indigo**: `#4F46E5` (Indigo 600) — Highlighting executive analytics, super-admin badges.
* **Logistics Emerald**: `#059669` (Emerald 600) — Successful delivery states, confirmed handovers, verified payments.

### 2. Semantic & Status Colors
* **Success Green**: `#10B981` (Emerald 500) | Light Tint: `#ECFDF5` — Delivered, Verified Remittance, Reconciled Audit.
* **Warning Amber / Yellow**: `#F59E0B` (Amber 500) | Light Tint: `#FFFBEB` — Pending Pickup, Rescheduled/Callback, Low Stock ($\le 5$).
* **Critical Danger Red**: `#EF4444` (Red 500) | Light Tint: `#FEF2F2` — Failed Delivery, Rejected Remittance, Discrepancy Flag, Frozen Account.
* **Info Cyan / Sky**: `#0EA5E9` (Sky 500) | Light Tint: `#F0F9FF` — In Transit, Assigned Lead, Monnify Webhook Waiting.
* **Awaiting Return Purple**: `#8B5CF6` (Purple 500) | Light Tint: `#F5F3FF` — Failed goods awaiting DC return.

### 3. Neutral Surface & Text Hierarchy
* **Background Light**: `#F8FAFC` (Slate 50) — General app background.
* **Surface Card**: `#FFFFFF` (Pure White) — Elevated container cards, modals, table rows.
* **Border Neutral**: `#E2E8F0` (Slate 200) — Standard input borders, card outlines.
* **Text Primary**: `#0F172A` (Slate 900) — Headings, key figures, values.
* **Text Secondary**: `#64748B` (Slate 500) — Labels, helper text, timestamps.
* **Text Muted**: `#94A3B8` (Slate 400) — Placeholder text, disabled controls.

---

## 🔤 Typography & Font Hierarchy

* **Primary Font Family**: `Inter` / `Plus Jakarta Sans`
* **Monospace Font Family (for Order IDs, Codes, Tracking Numbers)**: `JetBrains Mono` / `Roboto Mono`

| Style Token | Size / Line Height | Weight | Usage |
|---|---|:---:|---|
| **Display Heading 1** | `32px / 40px` | Bold (700) | Executive KPI hero cards, welcome headers |
| **Heading 2** | `24px / 32px` | SemiBold (600) | Page titles, major modal headers |
| **Heading 3** | `18px / 26px` | SemiBold (600) | Section titles, card headings |
| **Body Large (Emphasis)** | `16px / 24px` | Medium (500) | Order total price, customer names, status titles |
| **Body Regular** | `14px / 20px` | Regular (400) | Standard body copy, form labels, table cells |
| **Caption / Subtitle** | `12px / 16px` | Regular / Medium | Timestamp, SKU codes, vehicle status badges |
| **Micro Monospace** | `11px / 14px` | SemiBold (600) | Tracking numbers (`TRK-8924`), PIN codes (`HND-9921`) |

---

## 📐 Spacing, Elevation & Layout Grid

* **Base Grid Unit**: `4px` (`4`, `8`, `12`, `16`, `20`, `24`, `32`, `40`, `48`, `64px`).
* **Corner Radius**:
  * Buttons & Inputs: `8px` (`rounded-lg`)
  * Cards & Modals: `16px` (`rounded-2xl`)
  * Badges & Tags: `9999px` (`rounded-full`)
* **Elevations (Box Shadows)**:
  * Low (Cards): `0 1px 3px rgba(0,0,0,0.05), 0 1px 2px rgba(0,0,0,0.03)`
  * Medium (Hover/Dropdowns): `0 4px 6px -1px rgba(0,0,0,0.07), 0 2px 4px -1px rgba(0,0,0,0.04)`
  * High (Modals/Slide-overs): `0 20px 25px -5px rgba(0,0,0,0.1), 0 10px 10px -5px rgba(0,0,0,0.04)`

---

## 🧩 Reusable Component Design Patterns

### 1. Status Badges & Pills
```
[ 🟢 Delivered ]    [ 🟡 In Transit ]    [ 🔴 Failed ]    [ 🟣 Awaiting Return ]
```

### 2. Key Action Buttons (48px Touch Targets on Mobile)
* **Primary Action**: Solid Primary Accent Blue (`#2563EB`) with bold white text.
* **Secondary Action**: White surface with Slate 200 border and Slate 800 text.
* **Destructive Action**: Crimson Red (`#EF4444`) with white text.
* **Floating Action Button (FAB)**: Primary Blue elevated circle for quick actions (+ New Order, + Scan).

### 3. Metric Hero Cards
Elevated white card with:
* Top Left: Metric Title & Icon (e.g. "My Balance" / "COD Cash in Custody").
* Center: Bold Large Naira Currency Value (`₦55,000.00`).
* Bottom: Trend indicator (+12% today) or actionable trigger button.

### 4. Empty States & Loading Skeletons
* Clean custom vector illustrations with reassuring copy and a clear primary action button.
* Pulsing shimmer skeleton loaders during PostgREST / Edge Function network calls.
