import os

keywords = ['closer', 'sales_rep', 'telesales', 'upg', 'upsell', 'upgrade_order']
matches = {k: [] for k in keywords}

for root, dirs, files in os.walk('lib'):
    for f in files:
        if f.endswith('.dart'):
            path = os.path.join(root, f)
            with open(path, 'r', encoding='utf-8', errors='ignore') as file:
                content = file.read().lower()
                for k in keywords:
                    if k in content:
                        matches[k].append(path)

for k, v in matches.items():
    print(f"Keyword '{k}': {len(v)} files")
    for p in v[:6]:
        print(f"  {p}")
