import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'client_portal_layout.dart';
import 'finance/client_expenses_view.dart';
import 'finance/client_payouts_view.dart';
import 'finance/client_profits_view.dart';
import 'finance/client_remittance_view.dart';

/// Clean finance section host widget that switches between the 4 dedicated finance views
/// without duplicate top pill bars.
class ClientFinancePage extends ConsumerWidget {
  const ClientFinancePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeTab = ref.watch(clientActiveTabProvider);

    switch (activeTab) {
      case 'finance_expenses':
        return const ClientExpensesView();
      case 'finance_profits':
        return const ClientProfitsView();
      case 'finance_payouts':
        return const ClientPayoutsView();
      case 'finance_remittance':
      case 'finance':
      default:
        return const ClientRemittanceView();
    }
  }
}
