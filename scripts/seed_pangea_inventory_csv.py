#!/usr/bin/env python3
"""
Seed Pangea Inventory CSV
Parses 'Stock Balance_Novacare Ltd_2026-09-07_2026-09-13___Currency - Query Report.csv'
and generates SQL insert batches for public.client_stock_balances and products.
"""

import csv
import os
import sys

CSV_PATH = "Stock Balance_Novacare Ltd_2026-09-07_2026-09-13___Currency - Query Report.csv"
OUTPUT_SQL = "supabase/migrations/20260920110000_seed_pangea_stock_balances.sql"
CLIENT_ID = "33333333-3333-4333-8333-333333333333"

def escape_sql(s):
    if s is None:
        return ""
    return str(s).replace("'", "''").strip()

def run():
    if not os.path.exists(CSV_PATH):
        print(f"File {CSV_PATH} not found!")
        return

    with open(CSV_PATH, encoding="utf-8") as f:
        reader = list(csv.DictReader(f))

    print(f"Total CSV rows: {len(reader)}")

    # Deduplicate by (item_name, warehouse)
    unique_rows = {}
    item_totals = {}

    for row in reader:
        item_name = row.get("Item Name", "").strip()
        warehouse = row.get("Warehouse", "").strip()
        if not item_name or not warehouse:
            continue

        key = (item_name, warehouse)
        try:
            bal_qty = float(row.get("Balance Qty", 0) or 0)
            bal_val = float(row.get("Balance Value", 0) or 0)
            open_qty = float(row.get("Opening Qty", 0) or 0)
            open_val = float(row.get("Opening Value", 0) or 0)
            in_qty = float(row.get("In Qty", 0) or 0)
            in_val = float(row.get("In Value", 0) or 0)
            out_qty = float(row.get("Out Qty", 0) or 0)
            out_val = float(row.get("Out Value", 0) or 0)
            rate = float(row.get("Valuation Rate", 0) or 0)
            reserved = float(row.get("Reserved Stock", 0) or 0)
            uom = row.get("Stock UOM", "Nos").strip() or "Nos"
            group = row.get("Item Group", "Novacare").strip() or "Novacare"
            company = row.get("Company", "Novacare Ltd").strip() or "Novacare Ltd"
        except ValueError:
            continue

        unique_rows[key] = {
            "item_name": item_name,
            "warehouse": warehouse,
            "stock_uom": uom,
            "item_group": group,
            "company": company,
            "opening_qty": open_qty,
            "opening_value": open_val,
            "in_qty": in_qty,
            "in_value": in_val,
            "out_qty": out_qty,
            "out_value": out_val,
            "balance_qty": bal_qty,
            "balance_value": bal_val,
            "valuation_rate": rate,
            "reserved_stock": reserved
        }

        if item_name not in item_totals:
            item_totals[item_name] = {"qty": 0.0, "val": 0.0, "rate": rate}
        item_totals[item_name]["qty"] += bal_qty
        item_totals[item_name]["val"] += bal_val

    print(f"Unique stock balance positions: {len(unique_rows)}")
    print(f"Unique items: {len(item_totals)}")

    with open(OUTPUT_SQL, "w", encoding="utf-8") as out:
        out.write("-- ============================================================================\n")
        out.write("-- PANGEA SUITE STOCK BALANCES SEED (NOVACARE LTD)\n")
        out.write(f"-- Export Date: 2026-09-13 | Total Balance Positions: {len(unique_rows)}\n")
        out.write("-- ============================================================================\n\n")

        # Update or Insert Products catalog items
        out.write("-- 1. Synchronize master products catalog with Pangea Suite valuation rates\n")
        for item, data in item_totals.items():
            sku = "SKU-" + "".join(word[0].upper() for word in item.split() if word)[:6]
            if len(sku) < 5:
                sku = f"SKU-{item[:4].upper()}"
            out.write(f"""
INSERT INTO public.products (company_id, client_id, sku, name, category, stock_quantity, available_count, base_price, is_active)
VALUES ('11111111-1111-4111-8111-111111111111', '{CLIENT_ID}', '{sku}', '{escape_sql(item)}', 'Health & Wellness', {int(data['qty'])}, {int(data['qty'])}, {data['rate']}, true)
ON CONFLICT (name) DO UPDATE SET
    stock_quantity = EXCLUDED.stock_quantity,
    available_count = EXCLUDED.available_count,
    base_price = CASE WHEN products.base_price <= 0 THEN EXCLUDED.base_price ELSE products.base_price END,
    client_id = EXCLUDED.client_id;
""")

        out.write("\n-- 2. Insert Stock Balance records across all 108 warehouses\n")
        # Batch insert in chunks of 50
        rows_list = list(unique_rows.values())
        chunk_size = 50
        for i in range(0, len(rows_list), chunk_size):
            chunk = rows_list[i:i + chunk_size]
            out.write("""
INSERT INTO public.client_stock_balances (
    client_id, item_code, item_name, item_group, warehouse, stock_uom,
    opening_qty, opening_value, in_qty, in_value, out_qty, out_value,
    balance_qty, balance_value, valuation_rate, reserved_stock, company
) VALUES\n""")
            value_lines = []
            for r in chunk:
                sku = "SKU-" + "".join(word[0].upper() for word in r['item_name'].split() if word)[:6]
                value_lines.append(
                    f"    ('{CLIENT_ID}', '{sku}', '{escape_sql(r['item_name'])}', '{escape_sql(r['item_group'])}', "
                    f"'{escape_sql(r['warehouse'])}', '{escape_sql(r['stock_uom'])}', {r['opening_qty']}, {r['opening_value']}, "
                    f"{r['in_qty']}, {r['in_value']}, {r['out_qty']}, {r['out_value']}, {r['balance_qty']}, {r['balance_value']}, "
                    f"{r['valuation_rate']}, {r['reserved_stock']}, '{escape_sql(r['company'])}')"
                )
            out.write(",\n".join(value_lines))
            out.write("""
ON CONFLICT (client_id, item_code, warehouse) DO UPDATE SET
    opening_qty = EXCLUDED.opening_qty,
    opening_value = EXCLUDED.opening_value,
    in_qty = EXCLUDED.in_qty,
    in_value = EXCLUDED.in_value,
    out_qty = EXCLUDED.out_qty,
    out_value = EXCLUDED.out_value,
    balance_qty = EXCLUDED.balance_qty,
    balance_value = EXCLUDED.balance_value,
    valuation_rate = EXCLUDED.valuation_rate,
    reserved_stock = EXCLUDED.reserved_stock,
    updated_at = NOW();\n\n""")

    print(f"Generated seed migration SQL at: {OUTPUT_SQL}")

if __name__ == "__main__":
    run()
