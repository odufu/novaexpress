import os

# 1. Update orders_provider.dart
path1 = 'lib/features/orders/presentation/providers/orders_provider.dart'
with open(path1, 'r', encoding='utf-8') as f:
    text = f.read()

target1 = "status: 'in_transit',\n              deliveryAgentId: riderId,"
repl1 = "status: 'dispatch_assigned',\n              deliveryAgentId: riderId,"

# Handle CRLF if needed
if target1 not in text and target1.replace('\n', '\r\n') in text:
    target1 = target1.replace('\n', '\r\n')
    repl1 = repl1.replace('\n', '\r\n')

target2 = "clearAssignment: true,\n              status: 'pending_dispatch',"
repl2 = "clearAssignment: true,\n              status: 'ready',"
if target2 not in text and target2.replace('\n', '\r\n') in text:
    target2 = target2.replace('\n', '\r\n')
    repl2 = repl2.replace('\n', '\r\n')

assert target1 in text, 'target1 not found in orders_provider.dart'
assert target2 in text, 'target2 not found in orders_provider.dart'

text = text.replace(target1, repl1, 1).replace(target2, repl2, 1)

with open(path1, 'w', encoding='utf-8') as f:
    f.write(text)
print('orders_provider.dart patched successfully')

# 2. Update orders_remote_datasource.dart
path2 = 'lib/features/orders/data/datasources/orders_remote_datasource.dart'
with open(path2, 'r', encoding='utf-8') as f:
    text = f.read()

target3 = "'delivery_agent_id': validRiderUuid,\n          'assigned_agent_id': validRiderUuid,\n          'status': 'in_transit',"
repl3 = "'delivery_agent_id': validRiderUuid,\n          'assigned_agent_id': validRiderUuid,\n          'status': 'dispatch_assigned',"
if target3 not in text and target3.replace('\n', '\r\n') in text:
    target3 = target3.replace('\n', '\r\n')
    repl3 = repl3.replace('\n', '\r\n')

target4 = "'delivery_agent_id': null,\n        'assigned_agent_id': null,\n        'status': 'pending_dispatch',"
repl4 = "'delivery_agent_id': null,\n        'assigned_agent_id': null,\n        'status': 'ready',"
if target4 not in text and target4.replace('\n', '\r\n') in text:
    target4 = target4.replace('\n', '\r\n')
    repl4 = repl4.replace('\n', '\r\n')

assert target3 in text, 'target3 not found in orders_remote_datasource.dart'
assert target4 in text, 'target4 not found in orders_remote_datasource.dart'

text = text.replace(target3, repl3, 1).replace(target4, repl4, 1)

with open(path2, 'w', encoding='utf-8') as f:
    f.write(text)
print('orders_remote_datasource.dart patched successfully')

