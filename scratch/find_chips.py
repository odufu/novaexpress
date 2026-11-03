with open('lib/features/client_portal/presentation/pages/closer_mobile_portal_page.dart', 'r', encoding='utf-8') as f:
    text = f.read()

start_marker = "_buildFilterChip('all'"
idx = text.find(start_marker)
print('Found at', idx)
print(repr(text[idx:idx+800]))

