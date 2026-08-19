# 🗄️ Admin Workflow 06: Database Schema Migrations, Edge Microservices & Infrastructure Maintenance

This document details the operational workflow for executing PostgreSQL schema migrations, PostgREST schema cache reloads, deploying TypeScript/Deno Edge Functions, database query performance indexing, and connection pool management.

---

## 🎯 Overview & Objectives

* **Primary Goal**: Maintain high-availability, low-latency database infrastructure, deploy idempotent DDL schema migrations, publish Edge Function microservices with zero downtime, and manage PostgreSQL connection pooling.
* **Primary Actors**: Super Administrator, Principal Database Engineer, DevOps Lead, Supabase CLI.
* **Infrastructure**: Supabase PostgreSQL 15+, Supabase Edge Runtime, PostgREST API Engine, PgBouncer / Supavisor.

---

## 📊 Detailed Workflow Diagram

```mermaid
sequenceDiagram
    autonumber
    actor Admin as 👑 Super Admin
    participant CLI as Supabase CLI (v2.65.2+)
    participant Edge_Host as Supabase Edge Runtime
    participant DB as Remote Supabase PostgreSQL (oygtaeriljuelhshfvkv)
    participant API as PostgREST API Engine

    Note over Admin,DB: 1. Schema Migration Deployment
    Admin->>CLI: Executes "supabase db push"
    CLI->>DB: Applies DDL Migrations (20260819180000_full_schema_pda_system.sql)
    DB-->>CLI: Migration Applied Successfully (All Tables & Procedures Live)
    
    CLI->>DB: Executes "SELECT pg_notify('pgrst', 'reload schema');"
    DB->>API: Notifies PostgREST Engine -> Refreshes API Schema Cache
    
    Note over Admin,Edge_Host: 2. Edge Function Microservices Deployment
    Admin->>CLI: Executes "supabase functions deploy confirm-delivery-pod"
    CLI->>Edge_Host: Bundles TypeScript assets & deploys Edge Function
    Edge_Host-->>CLI: Deployed Function: confirm-delivery-pod (ACTIVE, v1)
    
    CLI-->>Admin: Infrastructure Updated with Zero Operational Downtime
```

---

## 📑 Step-by-Step Execution Sequence

### Step 1: Idempotent Migration Script Authoring & Review
1. All database migrations are authored in `supabase/migrations/` using UTC timestamp prefixes (e.g. `20260819180000_full_schema_pda_system.sql`).
2. Best practices enforced:
   * Use `CREATE TABLE IF NOT EXISTS`.
   * Use `ALTER TABLE IF EXISTS ... ADD COLUMN IF NOT EXISTS`.
   * Use `gen_random_uuid()` for all UUID primary keys.
   * Add `DROP POLICY IF EXISTS` before creating RLS policies.

### Step 2: Migration Push Execution
1. Super Admin executes database migration via Supabase CLI:
   ```bash
   # Push pending migrations to linked remote project
   supabase db push
   ```
2. Supabase CLI connects to remote PostgreSQL instance (`oygtaeriljuelhshfvkv`), executes pending SQL files in sequential order, and updates `supabase_migrations.schema_migrations`.

### Step 3: PostgREST Schema Cache Reload
1. Whenever new columns or tables are added, the API layer must reload its schema cache to prevent `PGRST204 (Column not found)` errors:
   ```sql
   SELECT pg_notify('pgrst', 'reload schema');
   ```

### Step 4: Edge Functions Deployment
1. Super Admin deploys all backend microservices to Supabase Edge Runtime:
   ```bash
   supabase functions deploy confirm-delivery-pod
   supabase functions deploy log-delivery-failure
   supabase functions deploy request-balance-payout
   supabase functions deploy monnify-webhook
   supabase functions deploy submit-cash-remittance
   supabase functions deploy request-stock-transfer
   ```
2. Edge Runtime compiles TypeScript code, injects encrypted environment secrets, and exposes instant global endpoints.

---

## 🛑 Infrastructure Health & Maintenance Commands

| Maintenance Task | Command / Tool | Execution Frequency |
|---|---|:---:|
| **Check Migration Status** | `supabase migration list` | Pre-deployment |
| **Verify Active Edge Functions** | `supabase functions list` | Post-deployment |
| **Connection Pool Health** | Monitor PgBouncer active pool clients ($\le 100$) | Continuous |
| **Index Vacuum & Analyze** | `VACUUM ANALYZE orders, agent_inventory;` | Weekly |
