with open('test/dc_sub_hub_scoping_and_zero_state_test.dart', 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace("expect(find.text('Remittances'), findsAtLeast(1));", "expect(find.text('Finance'), findsAtLeast(1));")

with open('test/dc_sub_hub_scoping_and_zero_state_test.dart', 'w', encoding='utf-8') as f:
    f.write(content)

print("Updated Remittances to Finance")

