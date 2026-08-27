import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

final processReturnsSelectedDCProvider = StateProvider.autoDispose<String>((ref) => 'Wuse Distribution Center');

class ProcessReturnsSelectedItemsNotifier extends StateNotifier<Set<String>> {
  ProcessReturnsSelectedItemsNotifier() : super({'RET-001', 'RET-002'});

  void toggle(String id) {
    if (state.contains(id)) {
      state = state.where((item) => item != id).toSet();
    } else {
      state = {...state, id};
    }
  }

  void clear() {
    state = {};
  }
}

final processReturnsSelectedItemsProvider = StateNotifierProvider.autoDispose<
    ProcessReturnsSelectedItemsNotifier, Set<String>>((ref) {
  return ProcessReturnsSelectedItemsNotifier();
});

class ProcessReturnsPage extends ConsumerWidget {
  const ProcessReturnsPage({super.key});

  static const List<Map<String, dynamic>> _returnItems = [
    {
      'id': 'RET-001',
      'orderId': 'NX-849202',
      'productName': 'Respira Detox Tea',
      'quantity': 2,
      'reason': 'Customer unavailable / rescheduled',
      'timestamp': 'Today, 11:30 AM',
    },
    {
      'id': 'RET-002',
      'orderId': 'NX-849205',
      'productName': 'Grazer Herbal Tea',
      'quantity': 1,
      'reason': 'Customer refused package at doorstep',
      'timestamp': 'Yesterday, 04:15 PM',
    },
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final authState = ref.watch(authProvider);
    final selectedDC = ref.watch(processReturnsSelectedDCProvider);
    final selectedItems = ref.watch(processReturnsSelectedItemsProvider);

    final user = authState.user;
    final agentName = user != null && user.firstName.isNotEmpty ? '${user.firstName} ${user.lastName}' : 'John Okafor';

    final totalReturnUnits = _returnItems
        .where((item) => selectedItems.contains(item['id']))
        .fold(0, (sum, item) => sum + (item['quantity'] as int));

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: theme.colorScheme.onSurface),
          onPressed: () => context.pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Process DC Returns',
              style: GoogleFonts.inter(
                color: theme.colorScheme.onSurface,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'Agent: $agentName',
              style: GoogleFonts.inter(
                color: const Color(0xFF64748B),
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Return Destination Selector
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Return Destination Hub',
                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: selectedDC,
                    decoration: InputDecoration(
                      isDense: true,
                      prefixIcon: const Icon(Icons.warehouse_rounded, color: AppColors.primary),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'Wuse Distribution Center', child: Text('Wuse Distribution Center')),
                      DropdownMenuItem(value: 'Garki Distribution Center', child: Text('Garki Distribution Center')),
                      DropdownMenuItem(value: 'Kubwa Distribution Center', child: Text('Kubwa Distribution Center')),
                      DropdownMenuItem(value: 'Ikeja Distribution Center', child: Text('Ikeja Distribution Center')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        ref.read(processReturnsSelectedDCProvider.notifier).state = val;
                      }
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Return Items List
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Items Awaiting Return (${_returnItems.length})',
                  style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                Text(
                  'Select items to return',
                  style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                ),
              ],
            ),
            const SizedBox(height: 12),

            ..._returnItems.map((item) {
              final isChecked = selectedItems.contains(item['id']);

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: InkWell(
                  onTap: () {
                    ref.read(processReturnsSelectedItemsProvider.notifier).toggle(item['id'] as String);
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isChecked ? AppColors.primary : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                        width: isChecked ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Checkbox(
                          value: isChecked,
                          activeColor: AppColors.primary,
                          onChanged: (_) {
                            ref.read(processReturnsSelectedItemsProvider.notifier).toggle(item['id'] as String);
                          },
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    item['productName'] as String,
                                    style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    '-${item['quantity']} Units',
                                    style: GoogleFonts.jetBrainsMono(
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFFE11D48),
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Order ${item['orderId']} • ${item['reason']}',
                                style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                item['timestamp'] as String,
                                style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
            const SizedBox(height: 24),

            // Submit Return Handover
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: selectedItems.isEmpty
                    ? null
                    : () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Return manifest generated! Handed over $totalReturnUnits units to $selectedDC.',
                              style: GoogleFonts.inter(color: Colors.white),
                            ),
                            backgroundColor: const Color(0xFF16A34A),
                          ),
                        );
                        context.pop();
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(
                  'Confirm Return Handover ($totalReturnUnits Units)',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
