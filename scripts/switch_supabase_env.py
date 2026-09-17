#!/usr/bin/env python3
"""
NovaExpress Supabase Environment Switcher
Allows instantaneous switching between Supabase accounts/projects, or registering new accounts.
"""

import sys
import os
import re
import argparse
import json
import io

if sys.platform == "win32":
    try:
        sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")
        sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding="utf-8", errors="replace")
    except Exception:
        pass

CONSTANTS_FILE = os.path.join("lib", "core", "constants", "supabase_constants.dart")
ENV_DOC_FILE = "supabase_environments.md"

def load_environments():
    envs = {}
    if os.path.exists(ENV_DOC_FILE):
        with open(ENV_DOC_FILE, "r", encoding="utf-8") as f:
            content = f.read()
        
        sections = content.split("## ")
        for sec in sections[1:]:
            lines = sec.strip().split("\n")
            header = lines[0].strip()
            url_match = re.search(r"Project URL\**:\s*`?(https://[^\s`]+)`?", sec)
            anon_match = re.search(r"Anon Public Key\**:\s*```(?:text)?\s*([a-zA-Z0-9_\-\.]+)\s*```", sec)
            service_match = re.search(r"Service Role Key\**:\s*```(?:text)?\s*([a-zA-Z0-9_\-\.]+)\s*```", sec)
            
            ref_match = re.search(r"Project Reference\**:\s*`?([a-zA-Z0-9_\-]+)`?", sec)
            
            if url_match and anon_match and service_match:
                name_clean = header.split("(")[0].replace("1.", "").replace("2.", "").replace("3.", "").strip()
                ref = ref_match.group(1) if ref_match else ""
                envs[name_clean.lower().replace(" ", "_")] = {
                    "display_name": header,
                    "ref": ref,
                    "url": url_match.group(1),
                    "anon_key": anon_match.group(1),
                    "service_key": service_match.group(1)
                }
    return envs

def switch_to_environment(target_url, target_anon, target_service, env_name="Custom"):
    if not os.path.exists(CONSTANTS_FILE):
        print(f"❌ Error: {CONSTANTS_FILE} not found.")
        sys.exit(1)

    with open(CONSTANTS_FILE, "r", encoding="utf-8") as f:
        code = f.read()

    # Update _defaultUrl, _defaultAnonKey, _defaultServiceRoleKey
    code = re.sub(
        r"static const String _defaultUrl = [^;]+;",
        f"static const String _defaultUrl = '{target_url}';",
        code
    )
    code = re.sub(
        r"static const String _defaultAnonKey = [^;]+;",
        f"static const String _defaultAnonKey =\n      '{target_anon}';",
        code
    )
    code = re.sub(
        r"static const String _defaultServiceRoleKey = [^;]+;",
        f"static const String _defaultServiceRoleKey =\n      '{target_service}';",
        code
    )

    with open(CONSTANTS_FILE, "w", encoding="utf-8") as f:
        f.write(code)

    print(f"✅ Successfully switched active Supabase project to: {env_name} ({target_url})")
    print(f"   Flutter app will now connect to this Supabase backend.")

def main():
    parser = argparse.ArgumentParser(description="NovaExpress Supabase Environment Switcher")
    parser.add_argument("--list", action="store_true", help="List all saved Supabase environments")
    parser.add_argument("--switch", type=str, help="Switch to a known environment by key or name")
    parser.add_argument("--set", action="store_true", help="Set active Supabase environment using explicit credentials")
    parser.add_argument("--name", type=str, default="New Environment", help="Environment display name")
    parser.add_argument("--url", type=str, help="Supabase Project URL (e.g. https://xyz.supabase.co)")
    parser.add_argument("--anon-key", type=str, help="Supabase Anon Key")
    parser.add_argument("--service-key", type=str, help="Supabase Service Role Key")

    args = parser.parse_args()

    envs = load_environments()

    if args.list:
        print("\n============================================================")
        print("📋 SAVED SUPABASE ENVIRONMENTS")
        print("============================================================")
        for k, v in envs.items():
            print(f"• Key: '{k}'")
            print(f"  Title: {v['display_name']}")
            print(f"  URL:   {v['url']}\n")
        return

    if args.switch:
        target = args.switch.lower().replace(" ", "_")
        matched = None
        for k in envs:
            if target in k:
                matched = envs[k]
                break
        if matched:
            switch_to_environment(matched["url"], matched["anon_key"], matched["service_key"], matched["display_name"])
        else:
            print(f"❌ Unknown environment '{args.switch}'. Use --list to see available environments.")
        return

    if args.url and args.anon_key and args.service_key:
        switch_to_environment(args.url, args.anon_key, args.service_key, args.name)
        # Also append to supabase_environments.md if not already present
        if os.path.exists(ENV_DOC_FILE):
            with open(ENV_DOC_FILE, "r", encoding="utf-8") as f:
                doc = f.read()
            if args.url not in doc:
                ref = args.url.replace("https://", "").replace(".supabase.co", "")
                append_text = f"\n---\n\n## {args.name}\n"
                append_text += f"* **Status**: Active / Custom\n"
                append_text += f"* **Project Reference**: `{ref}`\n"
                append_text += f"* **Project URL**: `{args.url}`\n"
                append_text += f"* **Anon Public Key**:\n  ```text\n  {args.anon_key}\n  ```\n"
                append_text += f"* **Service Role Key**:\n  ```text\n  {args.service_key}\n  ```\n"
                with open(ENV_DOC_FILE, "a", encoding="utf-8") as f:
                    f.write(append_text)
                print(f"📝 Added '{args.name}' to {ENV_DOC_FILE} for future reference.")
        return

    parser.print_help()

if __name__ == "__main__":
    main()
