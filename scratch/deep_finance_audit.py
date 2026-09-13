import json
import sys
import urllib.request
import urllib.error

sys.stdout.reconfigure(encoding='utf-8')

SUPABASE_URL = "https://qpcafevjsrbauweuiiyq.supabase.co"
SERVICE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFwY2FmZXZqc3JiYXV3ZXVpaXlxIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4ODc4NjM2NCwiZXhwIjoyMTA0MzYyMzY0fQ.RM1BJWKYWnhI7kkDVACqAxDj8U9shpWxQX8h8_K7UiU"

headers = {
    "apikey": SERVICE_KEY,
    "Authorization": f"Bearer {SERVICE_KEY}",
    "Content-Type": "application/json",
    "Prefer": "count=exact"
}

def get_openapi():
    req = urllib.request.Request(f"{SUPABASE_URL}/rest/v1/?apikey={SERVICE_KEY}", headers={"apikey": SERVICE_KEY})
    with urllib.request.urlopen(req) as resp:
        return json.loads(resp.read().decode('utf-8'))

def query_table(table, params="select=*&limit=5"):
    url = f"{SUPABASE_URL}/rest/v1/{table}?{params}"
    req = urllib.request.Request(url, headers=headers)
    try:
        with urllib.request.urlopen(req) as resp:
            content_range = resp.headers.get("Content-Range")
            total_count = content_range.split("/")[-1] if content_range and "/" in content_range else "unknown"
            rows = json.loads(resp.read().decode('utf-8'))
            return {"count": total_count, "rows": rows, "error": None}
    except urllib.error.HTTPError as e:
        body = e.read().decode('utf-8')
        return {"count": 0, "rows": [], "error": f"HTTP {e.code}: {body}"}
    except Exception as e:
        return {"count": 0, "rows": [], "error": str(e)}

def main():
    out_file = "scratch/deep_finance_audit_output.txt"
    with open(out_file, "w", encoding="utf-8") as out:
        out.write("=================================================================\n")
        out.write("1. REMOTE SUPABASE FINANCIAL SCHEMA INSPECTION (qpcafevjsrbauweuiiyq)\n")
        out.write("=================================================================\n\n")

        spec = get_openapi()
        defs = spec.get("definitions", {})
        paths = spec.get("paths", {})

        target_tables = [
            "remittances",
            "rider_transactions",
            "client_settlements",
            "dc_finance_settings",
            "delivery_agents",
            "clients",
            "orders",
            "companies",
            "payment_gateways"
        ]

        for table in target_tables:
            table_def = defs.get(table)
            if not table_def:
                out.write(f"TABLE: public.{table} NOT FOUND IN OPENAPI!\n\n")
                continue
            
            props = table_def.get("properties", {})
            required = table_def.get("required", [])
            out.write(f"TABLE: public.{table} ({len(props)} columns)\n")
            for col_name, col_meta in sorted(props.items()):
                col_type = col_meta.get("type", col_meta.get("format", "unknown"))
                col_format = col_meta.get("format", "")
                is_req = "NOT NULL" if col_name in required else "NULLABLE"
                default_val = f" DEFAULT {col_meta.get('default')}" if "default" in col_meta else ""
                fk_desc = f" [FK: {col_meta.get('description')}]" if col_meta.get("description") and "Foreign Key" in col_meta.get("description") else ""
                out.write(f"   {col_name:<30}: {col_type:<16} | {is_req}{default_val}{fk_desc}\n")
            out.write("\n")

        out.write("=================================================================\n")
        out.write("2. REMOTE SUPABASE FINANCIAL DATA & LIVE ROWS AUDIT\n")
        out.write("=================================================================\n\n")

        for table in target_tables:
            data = query_table(table, params="select=*&limit=5")
            if data["error"]:
                out.write(f"[TABLE {table}] ERROR: {data['error']}\n\n")
            else:
                out.write(f"[TABLE {table}] Total Rows in DB: {data['count']}\n")
                for i, row in enumerate(data["rows"], 1):
                    out.write(f"   Row {i}: {row}\n")
                out.write("\n")

        out.write("=================================================================\n")
        out.write("3. REMOTE FINANCIAL RPCs DETAILED PARAMETERS & RETURNS\n")
        out.write("=================================================================\n\n")

        finance_rpcs = [
            "calculate_remittance_transfer_fee",
            "fn_approve_cash_remittance",
            "fn_calculate_merchant_asset_custody",
            "fn_generate_merchant_daily_settlement",
            "update_driver_compensation",
            "decrement_driver_entitlement",
            "confirm_delivery_pod",
            "log_delivery_failure"
        ]

        for path_name, path_meta in sorted(paths.items()):
            if "/rpc/" in path_name:
                rpc_name = path_name.replace("/rpc/", "")
                post_op = path_meta.get("post", {})
                params = post_op.get("parameters", [])
                
                # Check if this RPC is in finance list or relates to money/payout/remittance/driver
                if rpc_name in finance_rpcs or any(k in rpc_name.lower() for k in ["remit", "settle", "pay", "fee", "driver", "finance"]):
                    out.write(f"RPC: {rpc_name}\n")
                    for p in params:
                        schema = p.get("schema", {})
                        out.write(f"   Arg: {p.get('name')} -> {json.dumps(schema)}\n")
                    responses = post_op.get("responses", {})
                    out.write(f"   Return 200: {json.dumps(responses.get('200', {}).get('schema', {}))}\n\n")

    print(f"Deep finance audit completed. Output written to {out_file}")

if __name__ == "__main__":
    main()
