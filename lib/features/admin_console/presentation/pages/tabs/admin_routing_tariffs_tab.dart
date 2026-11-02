import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../../core/helpers/formatters.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/widgets/nova_tooltip.dart';
import '../../../domain/entities/admin_models.dart';
import '../../providers/admin_console_provider.dart';
import '../../widgets/admin_filter_header.dart';
import '../../widgets/admin_metric_card.dart';

class AdminRoutingTariffsTab extends ConsumerWidget {
  const AdminRoutingTariffsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(adminConsoleProvider);
    final notifier = ref.read(adminConsoleProvider.notifier);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final tariffs = state.filteredTariffs;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Metrics Row
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 900;
              final crossAxisCount = isWide ? 4 : (constraints.maxWidth >= 600 ? 2 : 1);

              return GridView.count(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: isWide ? 2.3 : 2.5,
                children: const [
                  AdminMetricCard(
                    title: 'Active States',
                    value: '36 + FCT',
                    icon: Icons.map_outlined,
                    iconColor: Color(0xFF3B82F6),
                    subtitle: 'nationwide coverage',
                    tooltip: 'All states mapped to specific regional distribution gateways',
                  ),
                  AdminMetricCard(
                    title: 'Base Intra-State',
                    value: '₦2,000 - ₦2,500',
                    icon: Icons.local_shipping_outlined,
                    iconColor: Color(0xFF10B981),
                    subtitle: 'doorstep delivery',
                    tooltip: 'Standard intra-city last mile delivery rate before weight multipliers',
                  ),
                  AdminMetricCard(
                    title: 'PDA Commission',
                    value: '₦1,000 - ₦1,200',
                    icon: Icons.monetization_on_outlined,
                    iconColor: AppColors.orange,
                    subtitle: 'per delivered order',
                    tooltip: 'Commission awarded to private dispatch agents using personal bikes',
                  ),
                  AdminMetricCard(
                    title: 'Cold Chain',
                    value: '+20% to +30%',
                    icon: Icons.ac_unit_rounded,
                    iconColor: Color(0xFF0EA5E9),
                    subtitle: 'temperature surcharge',
                    tooltip: 'Surcharge applied for IoT temperature monitored pharmaceutical parcels',
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 20),

          // Filters
          AdminFilterHeader(
            searchHint: 'Search state or assigned hub name...',
            searchValue: state.searchQuery,
            onSearchChanged: notifier.setSearchQuery,
            onClearSearch: () => notifier.setSearchQuery(''),
            count: tariffs.length,
            countLabel: 'State Routes',
          ),
          const SizedBox(height: 16),

          // High Density Data Table
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                width: 1,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minWidth: MediaQuery.of(context).size.width - 290),
                  child: DataTable(
                    horizontalMargin: 16,
                    columnSpacing: 18,
                    headingRowHeight: 46,
                    dataRowMinHeight: 52,
                    dataRowMaxHeight: 56,
                    headingRowColor: WidgetStateProperty.all(
                      isDark ? const Color(0xFF1E293B).withValues(alpha: 0.7) : const Color(0xFFF8FAFC),
                    ),
                    columns: [
                      DataColumn(
                        label: Row(
                          children: [
                            Text('State Zone', style: _headerStyle(isDark)),
                            const SizedBox(width: 4),
                            const NovaInfoIcon(message: 'Nigerian State and assigned managing hub'),
                          ],
                        ),
                      ),
                      DataColumn(
                        label: Text('Assigned Hub', style: _headerStyle(isDark)),
                      ),
                      DataColumn(
                        label: Text('Intra Base', style: _headerStyle(isDark)),
                      ),
                      DataColumn(
                        label: Text('Inter Base', style: _headerStyle(isDark)),
                      ),
                      DataColumn(
                        label: Text('SLA Days', style: _headerStyle(isDark)),
                      ),
                      DataColumn(
                        label: Text('Cold Chain %', style: _headerStyle(isDark)),
                      ),
                      DataColumn(
                        label: Text('PDA Comm.', style: _headerStyle(isDark)),
                      ),
                      DataColumn(
                        label: Text('Fuel Allow.', style: _headerStyle(isDark)),
                      ),
                      DataColumn(
                        label: Align(
                          alignment: Alignment.centerRight,
                          child: Text('Edit', style: _headerStyle(isDark)),
                        ),
                      ),
                    ],
                    rows: tariffs.map((t) {
                      return DataRow(
                        cells: [
                          DataCell(
                            Text(
                              t.stateName,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                            ),
                          ),
                          DataCell(
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFF3B82F6).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                t.assignedHubName,
                                style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w600, color: const Color(0xFF3B82F6)),
                              ),
                            ),
                          ),
                          DataCell(
                            Text(
                              CurrencyFormatter.formatNaira(t.intraStateBaseRate),
                              style: GoogleFonts.jetBrainsMono(fontSize: 12),
                            ),
                          ),
                          DataCell(
                            Text(
                              CurrencyFormatter.formatNaira(t.interStateBaseRate),
                              style: GoogleFonts.jetBrainsMono(fontSize: 12),
                            ),
                          ),
                          DataCell(
                            Text(
                              '${t.slaDeliveryDays} ${t.slaDeliveryDays == 1 ? 'day' : 'days'}',
                              style: GoogleFonts.inter(fontSize: 12),
                            ),
                          ),
                          DataCell(
                            Text(
                              '+${t.coldChainSurchargePct.toInt()}%',
                              style: GoogleFonts.jetBrainsMono(fontSize: 12, color: const Color(0xFF0EA5E9)),
                            ),
                          ),
                          DataCell(
                            Text(
                              CurrencyFormatter.formatNaira(t.pdaCommission),
                              style: GoogleFonts.jetBrainsMono(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.orange),
                            ),
                          ),
                          DataCell(
                            Text(
                              CurrencyFormatter.formatNaira(t.dailyFuelAllowance),
                              style: GoogleFonts.jetBrainsMono(fontSize: 12, color: const Color(0xFF10B981)),
                            ),
                          ),
                          DataCell(
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 16, color: Color(0xFF3B82F6)),
                              onPressed: () => _openTariffEditModal(context, ref, t),
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  TextStyle _headerStyle(bool isDark) {
    return GoogleFonts.inter(
      fontSize: 12,
      fontWeight: FontWeight.w700,
      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
    );
  }

  void _openTariffEditModal(BuildContext context, WidgetRef ref, AdminRoutingTariff tariff) {
    final intraController = TextEditingController(text: tariff.intraStateBaseRate.toInt().toString());
    final interController = TextEditingController(text: tariff.interStateBaseRate.toInt().toString());
    final pdaController = TextEditingController(text: tariff.pdaCommission.toInt().toString());
    final fuelController = TextEditingController(text: tariff.dailyFuelAllowance.toInt().toString());

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Edit Tariffs: ${tariff.stateName}',
                    style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  _buildModalField(intraController, 'Intra-State Delivery Rate (₦)', isDark),
                  const SizedBox(height: 12),
                  _buildModalField(interController, 'Inter-State Delivery Rate (₦)', isDark),
                  const SizedBox(height: 12),
                  _buildModalField(pdaController, 'PDA Rider Commission (₦)', isDark),
                  const SizedBox(height: 12),
                  _buildModalField(fuelController, 'Daily Rider Fuel Allowance (₦)', isDark),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text('Cancel', style: GoogleFonts.inter()),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () {
                          final updated = tariff.copyWith(
                            intraStateBaseRate: double.tryParse(intraController.text) ?? tariff.intraStateBaseRate,
                            interStateBaseRate: double.tryParse(interController.text) ?? tariff.interStateBaseRate,
                            pdaCommission: double.tryParse(pdaController.text) ?? tariff.pdaCommission,
                            dailyFuelAllowance: double.tryParse(fuelController.text) ?? tariff.dailyFuelAllowance,
                          );
                          ref.read(adminConsoleProvider.notifier).updateRoutingTariff(updated);
                          Navigator.of(context).pop();
                        },
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.orange, foregroundColor: Colors.white),
                        child: Text('Save Rates', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildModalField(TextEditingController controller, String label, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8))),
        const SizedBox(height: 5),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          style: GoogleFonts.jetBrainsMono(fontSize: 13, color: isDark ? Colors.white : const Color(0xFF0F172A)),
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          ),
        ),
      ],
    );
  }
}
