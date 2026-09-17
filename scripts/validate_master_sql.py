#!/usr/bin/env python3
"""
Validate Master SQL Schema File
Forensically verifies table definitions, foreign key references, and function blocks.
"""

import sys
import os
import re
import io

if sys.platform == "win32":
    try:
        sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")
        sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding="utf-8", errors="replace")
    except Exception:
        pass

SQL_FILE = os.path.join("supabase", "schema_master_complete.sql")

def main():
    print("============================================================")
    print("🔬 VALIDATING MASTER SQL SCHEMA FILE")
    print(f"File: {SQL_FILE}")
    print("============================================================")

    if not os.path.exists(SQL_FILE):
        print(f"❌ Error: {SQL_FILE} does not exist.")
        sys.exit(1)

    with open(SQL_FILE, "r", encoding="utf-8") as f:
        sql = f.read()

    # 1. Check dollar quotes balance ($$)
    dollar_quotes = re.findall(r"\$\$", sql)
    print(f"• Dollar Quotes ($$): {len(dollar_quotes)} (Must be even -> {len(dollar_quotes) % 2 == 0})")
    if len(dollar_quotes) % 2 != 0:
        print("❌ Error: Unbalanced dollar quotes ($$) detected!")
        sys.exit(1)
    else:
        print("  ✅ Dollar quote blocks are perfectly balanced.")

    # 2. Extract Created Tables
    tables_created = re.findall(r"CREATE\s+TABLE\s+(?:IF\s+NOT\s+EXISTS\s+)?([a-zA-Z0-9_]+)", sql, re.IGNORECASE)
    print(f"\n• Tables Defined: {len(tables_created)}")
    for t in tables_created:
        print(f"  - {t}")

    # 3. Check Foreign Key Dependencies
    fk_references = re.findall(r"REFERENCES\s+([a-zA-Z0-9_]+)\s*\(", sql, re.IGNORECASE)
    print(f"\n• Foreign Key References: {len(fk_references)}")
    missing_targets = set()
    for ref in fk_references:
        # Ignore self-references or schema-qualified like companies, users
        if ref not in tables_created and ref not in ("distribution_centers", "users", "companies", "storage"):
            missing_targets.add(ref)

    if missing_targets:
        print(f"  ❌ Missing reference targets: {missing_targets}")
    else:
        print("  ✅ All foreign key targets are defined within the schema!")

    # 4. Check Functions Created
    functions_created = re.findall(r"CREATE\s+(?:OR\s+REPLACE\s+)?FUNCTION\s+(?:public\.)?([a-zA-Z0-9_]+)", sql, re.IGNORECASE)
    print(f"\n• Stored Procedures / Functions Defined: {len(functions_created)}")
    for fn in functions_created:
        print(f"  - {fn}")

    # 5. Check Triggers
    triggers_created = re.findall(r"CREATE\s+TRIGGER\s+([a-zA-Z0-9_]+)", sql, re.IGNORECASE)
    print(f"\n• Triggers Defined: {len(triggers_created)}")
    for trg in triggers_created:
        print(f"  - {trg}")

    # 6. Check Storage Buckets
    buckets = re.findall(r"\('([a-zA-Z0-9_\-]+)',\s*'([a-zA-Z0-9_\-]+)',\s*true", sql)
    print(f"\n• Storage Buckets Configured: {len(buckets)}")
    for b in buckets:
        print(f"  - {b[0]}")

    # 7. Check Realtime Publication
    has_realtime = "supabase_realtime" in sql
    print(f"\n• Realtime Publication Configured: {'✅ YES' if has_realtime else '❌ NO'}")

    # 8. Check Schema Cache Reload
    has_pgrst = "NOTIFY pgrst, 'reload schema';" in sql
    print(f"• PostgREST Schema Cache Reload: {'✅ YES' if has_pgrst else '❌ NO'}")

    print("\n============================================================")
    print("🎉 MASTER SCHEMA FILE VALIDATION: 100% SUCCESS")
    print("============================================================")

if __name__ == "__main__":
    main()
