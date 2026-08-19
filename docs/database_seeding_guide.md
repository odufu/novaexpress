# Supabase Database Seeding & Schema Integrity Guide

## Overview
This document defines the strict relational dependency rules and operational procedures for seeding real data into the NovaExpress Supabase PostgreSQL database (`https://oygtaeriljuelhshfvkv.supabase.co`).

---

## 1. Table Dependency Hierarchy & Insertion Sequence

To preserve PostgreSQL foreign key constraints (`FOREIGN KEY REFERENCES`), records MUST be seeded in the exact sequential order listed below:

```
[Level 1] companies
   │
   ├──► [Level 2] distribution_centers
   │       │
   │       ├──► [Level 3] users
   │       │       │
   │       │       └──► [Level 4] delivery_agents
   │       │               │
   │       │               ├──► [Level 5] products
   │       │               │       │
   │       │               │       └──► [Level 6] orders & order_items
   │       │               │               │
   │       │               │               ├──► [Level 7] cash_remittances
   │       │               │               ├──► [Level 8] rider_transactions
   │       │               │               ├──► [Level 9] notifications
   │       │               │               └──► [Level 10] stock_transfer_requests
```

---

## 2. Standard UUID Allocations for Testing & Live Environments

| Table | Entity Name | Primary Key (UUID) | Dependency Foreign Keys |
| :--- | :--- | :--- | :--- |
| `companies` | NovaExpress Logistics Limited | `11111111-1111-4111-8111-111111111111` | N/A |
| `distribution_centers` | Wuse Distribution Center | `22222222-2222-4222-8222-222222222222` | `company_id: 11111111-1111-4111-8111-111111111111` |
| `users` | Emeka Rider (PDA) | `a1111111-1111-4111-8111-111111111111` | `company_id`, `distribution_center_id` |
| `delivery_agents` | PDA-7000 | `b1111111-1111-4111-8111-111111111111` | `user_id`, `distribution_center_id` |

---

## 3. Data Integrity Rules

1. **Zero Hardcoded Local Fallbacks**: Remote datasources must query Supabase PostgreSQL tables directly. Local mock fallback lists are prohibited.
2. **Order Reconciliation**: Delivered Cash POD orders automatically generate records in `cash_remittances` and `rider_transactions` upon confirmation via the stored procedure `confirm_delivery_pod()`.
3. **Financial Entitlement Alignment**:
   $$\text{To Remit} = \text{Cash Collected} - \text{Commission} - \text{Transport} - \text{Approved Remittances}$$
4. **DC Expansion Ready**: Distribution Center (DC) inventory, stock intake, and agent management operations will consume the same `distribution_centers`, `products`, `orders`, and `cash_remittances` schema tables.
