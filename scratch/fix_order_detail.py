path = 'lib/features/orders/presentation/pages/order_detail_page.dart'
with open(path, 'r', encoding='utf-8') as f:
    lines = f.readlines()

new_lines = [
    '                    final riderTag = (order.deliveryAgentName != null && order.deliveryAgentName!.isNotEmpty)\n',
    "                        ? '${order.deliveryAgentName} (${order.deliveryAgentCode ?? \"\"})'\n",
    "                        : 'Rider';\n",
    '                    final existingNotes = (order.deliveryNotes != null && order.deliveryNotes!.isNotEmpty)\n',
    "                        ? '${order.deliveryNotes} | '\n",
    "                        : '';\n",
    '                    final unassigned = order.copyWith(\n',
    "                      status: 'ready',\n",
    '                      clearAssignment: true,\n',
    "                      deliveryNotes: '$existingNotes[RIDER REJECTED] $riderTag rejected assignment: $finalReason. Returned to DC queue.',\n",
    '                    );\n',
    '                    await ref.read(ordersProvider.notifier).updateOrder(unassigned);\n',
    '                    if (context.mounted) {\n',
    '                      ScaffoldMessenger.of(context).showSnackBar(\n',
    '                        SnackBar(\n',
    '                          backgroundColor: const Color(0xFFEF4444),\n',
    "                          content: Text('Order rejected ($finalReason) and returned to DC queue.'),\n",
    '                        ),\n',
    '                      );\n',
    '                    }\n',
    '                  },\n',
]

lines[234:261] = new_lines

with open(path, 'w', encoding='utf-8') as f:
    f.writelines(lines)

print('Successfully replaced lines in order_detail_page.dart')

