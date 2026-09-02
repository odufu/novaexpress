import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../client_portal/domain/entities/client_profile.dart';
import '../providers/dc_console_provider.dart';
import '../widgets/dc_onboard_client_modal.dart';

class DCClientsPage extends ConsumerWidget {
  const DCClientsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(dcConsoleProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final totalClients = state.clients.length;
    final enterpriseClients = state.clients.where((c) => c.isEnterprise).length;
    final standardClients = totalClients - enterpriseClients;
    final totalClosersCapacity = state.clients.fold(0, (sum, c) => sum + (c.isEnterprise ? c.closerLimit : 0));

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B1120) : const Color(0xFFF8FAFC),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Section: Header & Action
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Clients & Enterprise Merchants',
                          style: GoogleFonts.inter(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0D9488).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'Grand DC Directory',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF0D9488),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Manage enterprise accounts with 200+ telesales closers and single merchant partners',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => const DCOnboardClientModal(),
                    );
                  },
                  icon: const Icon(Icons.add_business_rounded, size: 18, color: Colors.white),
                  label: Text(
                    'Register Client',
                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0D9488),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Summary KPI Cards
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 900;
                return GridView.count(
                  crossAxisCount: isWide ? 4 : 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: isWide ? 2.1 : 1.8,
                  children: [
                    _buildKpiCard(
                      title: 'Total Registered Clients',
                      value: '$totalClients',
                      subtitle: 'Platform Merchants',
                      icon: Icons.store_mall_directory_rounded,
                      color: const Color(0xFF0D9488),
                      isDark: isDark,
                    ),
                    _buildKpiCard(
                      title: 'Enterprise Clients',
                      value: '$enterpriseClients',
                      subtitle: 'Multi-Closer Teams',
                      icon: Icons.corporate_fare_rounded,
                      color: const Color(0xFF6366F1),
                      isDark: isDark,
                    ),
                    _buildKpiCard(
                      title: 'Single Merchants',
                      value: '$standardClients',
                      subtitle: 'Direct Sellers',
                      icon: Icons.shopping_bag_rounded,
                      color: const Color(0xFF0EA5E9),
                      isDark: isDark,
                    ),
                    _buildKpiCard(
                      title: 'Total Closer Capacity',
                      value: '$totalClosersCapacity Closers',
                      subtitle: 'Across Enterprise Clients',
                      icon: Icons.headset_mic_rounded,
                      color: const Color(0xFFF59E0B),
                      isDark: isDark,
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 28),

            // Directory Table Container
            Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Filter Toolbar
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            _buildFilterTab(ref, 'all', 'All Clients ($totalClients)', state.clientFilter, isDark),
                            const SizedBox(width: 8),
                            _buildFilterTab(ref, 'enterprise', 'Enterprise Tier ($enterpriseClients)', state.clientFilter, isDark),
                            const SizedBox(width: 8),
                            _buildFilterTab(ref, 'standard', 'Standard ($standardClients)', state.clientFilter, isDark),
                          ],
                        ),
                        SizedBox(
                          width: 260,
                          height: 38,
                          child: TextField(
                            onChanged: (v) => ref.read(dcConsoleProvider.notifier).setSearchQuery(v),
                            style: GoogleFonts.inter(fontSize: 13, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                            decoration: InputDecoration(
                              hintText: 'Search client by name or code...',
                              hintStyle: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8)),
                              prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFF94A3B8)),
                              filled: true,
                              fillColor: isDark ? const Color(0xFF0B1120) : const Color(0xFFF8FAFC),
                              contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 10),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Divider(height: 1, color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),

                  // Clients List
                  if (state.filteredClients.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(40),
                      child: Center(
                        child: Column(
                          children: [
                            const Icon(Icons.domain_disabled_rounded, size: 48, color: Color(0xFF94A3B8)),
                            const SizedBox(height: 12),
                            Text('No clients match current filter.', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: const Color(0xFF64748B))),
                          ],
                        ),
                      ),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: state.filteredClients.length,
                      separatorBuilder: (_, __) => Divider(height: 1, color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9)),
                      itemBuilder: (context, index) {
                        final client = state.filteredClients[index];
                        return _buildClientRow(client, isDark);
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterTab(WidgetRef ref, String key, String label, String activeFilter, bool isDark) {
    final isSelected = activeFilter == key;
    return InkWell(
      onTap: () => ref.read(dcConsoleProvider.notifier).setClientFilter(key),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0D9488) : (isDark ? const Color(0xFF0B1120) : const Color(0xFFF8FAFC)),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isSelected ? const Color(0xFF0D9488) : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? Colors.white : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569)),
          ),
        ),
      ),
    );
  }

  Widget _buildClientRow(ClientProfile client, bool isDark) {
    final isEnterprise = client.isEnterprise;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      child: Row(
        children: [
          // Icon Avatar
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isEnterprise
                  ? const Color(0xFF6366F1).withValues(alpha: 0.12)
                  : const Color(0xFF0D9488).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isEnterprise ? Icons.corporate_fare_rounded : Icons.storefront_rounded,
              color: isEnterprise ? const Color(0xFF6366F1) : const Color(0xFF0D9488),
              size: 22,
            ),
          ),
          const SizedBox(width: 14),

          // Company Name & Code
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      client.companyName,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF64748B).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        client.code,
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  '${client.contactPerson} • ${client.email}',
                  style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8)),
                ),
              ],
            ),
          ),

          // Tier Badge
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Service Tier', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8))),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isEnterprise
                        ? const Color(0xFF6366F1).withValues(alpha: 0.12)
                        : const Color(0xFF0D9488).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    isEnterprise ? 'ENTERPRISE' : 'STANDARD',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isEnterprise ? const Color(0xFF6366F1) : const Color(0xFF0D9488),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Closers Capacity
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Telesales Closers', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8))),
                const SizedBox(height: 2),
                Text(
                  isEnterprise ? '${client.closerLimit} Closer Seats' : 'Direct Merchant',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isEnterprise ? const Color(0xFF6366F1) : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),

          // Location
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Depot State', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8))),
                const SizedBox(height: 2),
                Text(
                  '${client.city}, ${client.state.split(" ").first}',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF334155),
                  ),
                ),
              ],
            ),
          ),

          // Status Indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 6, height: 6, decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle)),
                const SizedBox(width: 6),
                Text(
                  'Active',
                  style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF10B981)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF94A3B8)),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
