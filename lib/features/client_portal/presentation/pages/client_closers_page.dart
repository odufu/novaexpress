import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../domain/entities/client_closer.dart';
import '../providers/client_portal_provider.dart';
import '../widgets/client_onboard_closer_modal.dart';

class ClientClosersPage extends ConsumerWidget {
  const ClientClosersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(clientPortalProvider);
    final themeMode = ref.watch(themeProvider);
    final isDark = themeMode == ThemeMode.dark ||
        (themeMode == ThemeMode.system &&
            MediaQuery.of(context).platformBrightness == Brightness.dark);
    final currencyFormatter = NumberFormat.currency(symbol: '₦', decimalDigits: 0);
    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth >= 850;

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : const Color(0xFFF8FAFC),
      body: RefreshIndicator(
        onRefresh: () => ref.read(clientPortalProvider.notifier).loadClientData(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Responsive Header Bar
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                runSpacing: 10,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Telesales & Closers Team',
                            style: GoogleFonts.inter(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF37021).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              '${state.totalClosersCount} / ${state.clientProfile.closerLimit} Closers',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFFF37021),
                              ),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        'Manage, onboard closers and monitor individual telesales conversion rates',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                  ElevatedButton.icon(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (ctx) => const ClientOnboardCloserModal(),
                      );
                    },
                    icon: const Icon(Icons.person_add_alt_1_rounded, size: 16, color: Colors.white),
                    label: Text(
                      'Onboard Closer',
                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF37021),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      elevation: 0,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Performance KPI Cards
              LayoutBuilder(
                builder: (context, constraints) {
                  final isKpiWide = constraints.maxWidth >= 900;
                  final isKpiMedium = constraints.maxWidth >= 550;
                  final crossAxisCount = isKpiWide ? 4 : (isKpiMedium ? 2 : 1);
                  return GridView.count(
                    crossAxisCount: crossAxisCount,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: isKpiWide ? 2.2 : (isKpiMedium ? 2.3 : 3.0),
                    children: [
                      _buildKpiCard(
                        title: 'Active Closers',
                        value: '${state.activeClosersCount}',
                        subtitle: 'Max Limit: ${state.clientProfile.closerLimit}',
                        icon: Icons.people_alt_rounded,
                        color: const Color(0xFFF37021),
                        isDark: isDark,
                      ),
                      _buildKpiCard(
                        title: 'Total Leads Assigned',
                        value: '${state.totalLeadsCount}',
                        subtitle: '${state.newLeadsCount} Uncalled Leads',
                        icon: Icons.contact_phone_rounded,
                        color: const Color(0xFF0EA5E9),
                        isDark: isDark,
                      ),
                      _buildKpiCard(
                        title: 'Leads Confirmed & Booked',
                        value: '${state.confirmedLeadsCount}',
                        subtitle: 'Conversion: ${state.overallCloserConversionRate.toStringAsFixed(1)}%',
                        icon: Icons.check_circle_outline_rounded,
                        color: const Color(0xFF10B981),
                        isDark: isDark,
                      ),
                      _buildKpiCard(
                        title: 'Closer Revenue Generated',
                        value: currencyFormatter.format(state.totalCloserRevenue),
                        subtitle: 'From Delivered Orders',
                        icon: Icons.account_balance_wallet_rounded,
                        color: const Color(0xFFF59E0B),
                        isDark: isDark,
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 20),

              // Closers Performance Leaderboard Container
              Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF151D36) : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: isDark ? const Color(0xFF2E3D6B) : const Color(0xFFE2E8F0)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Toolbar Header
                    Padding(
                      padding: const EdgeInsets.all(14),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final isHeaderWide = constraints.maxWidth >= 550;
                          return isHeaderWide
                              ? Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(Icons.leaderboard_rounded, color: Color(0xFFF37021), size: 18),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Closer Leaderboard & Team Performance',
                                          style: GoogleFonts.inter(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                                          ),
                                        ),
                                      ],
                                    ),
                                    SizedBox(width: 220, child: _buildSearchField(ref, isDark)),
                                  ],
                                )
                              : Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(Icons.leaderboard_rounded, color: Color(0xFFF37021), size: 18),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Closer Leaderboard',
                                          style: GoogleFonts.inter(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    _buildSearchField(ref, isDark),
                                  ],
                                );
                        },
                      ),
                    ),
                    Divider(height: 1, color: isDark ? const Color(0xFF2E3D6B) : const Color(0xFFE2E8F0)),

                    // Closers Roster List
                    if (state.topClosersLeaderboard.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(40),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(Icons.people_outline_rounded, size: 44, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                              const SizedBox(height: 10),
                              Text('No closers onboarded yet.', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: isDark ? Colors.white : const Color(0xFF64748B))),
                            ],
                          ),
                        ),
                      )
                    else if (isWide)
                      // Desktop Wide Table
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: state.topClosersLeaderboard.length,
                        separatorBuilder: (_, __) => Divider(height: 1, color: isDark ? const Color(0xFF2E3D6B) : const Color(0xFFF1F5F9)),
                        itemBuilder: (context, index) {
                          final closer = state.topClosersLeaderboard[index];
                          return _buildCloserTableRow(closer, index + 1, currencyFormatter, isDark);
                        },
                      )
                    else
                      // Mobile & Tablet Responsive Cards
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: state.topClosersLeaderboard.length,
                        separatorBuilder: (_, __) => Divider(height: 1, color: isDark ? const Color(0xFF2E3D6B) : const Color(0xFFF1F5F9)),
                        itemBuilder: (context, index) {
                          final closer = state.topClosersLeaderboard[index];
                          return _buildCloserMobileCard(closer, index + 1, currencyFormatter, isDark);
                        },
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchField(WidgetRef ref, bool isDark) {
    return SizedBox(
      height: 36,
      child: TextField(
        onChanged: (v) => ref.read(clientPortalProvider.notifier).setSearchQuery(v),
        style: GoogleFonts.inter(fontSize: 12, color: isDark ? Colors.white : const Color(0xFF0F172A)),
        decoration: InputDecoration(
          hintText: 'Search closer by name or code...',
          hintStyle: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8)),
          prefixIcon: const Icon(Icons.search_rounded, size: 16, color: Color(0xFF94A3B8)),
          filled: true,
          fillColor: isDark ? const Color(0xFF0B1021) : const Color(0xFFF8FAFC),
          contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 8),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: isDark ? const Color(0xFF2E3D6B) : const Color(0xFFE2E8F0)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: isDark ? const Color(0xFF2E3D6B) : const Color(0xFFE2E8F0)),
          ),
        ),
      ),
    );
  }

  Widget _buildCloserTableRow(
    ClientCloser closer,
    int rank,
    NumberFormat currencyFormatter,
    bool isDark,
  ) {
    final isTop = rank == 1;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          // Rank
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isTop ? const Color(0xFFF37021) : (isDark ? const Color(0xFF0B1021) : const Color(0xFFF1F5F9)),
              shape: BoxShape.circle,
            ),
            child: Text(
              '#$rank',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: isTop ? Colors.white : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569)),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Closer Name & Code
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        closer.fullName,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF37021).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        closer.closerCode,
                        style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: const Color(0xFFF37021)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${closer.email} • ${closer.phone}',
                  style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          // Assigned Leads
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Leads Assigned', style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF94A3B8))),
                const SizedBox(height: 2),
                Text(
                  '${closer.totalLeadsAssigned} Leads',
                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? Colors.white : const Color(0xFF334155)),
                ),
              ],
            ),
          ),

          // Booked Orders
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Orders Booked', style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF94A3B8))),
                const SizedBox(height: 2),
                Text(
                  '${closer.totalOrdersBooked} Booked',
                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF10B981)),
                ),
              ],
            ),
          ),

          // Conversion Rate
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Conversion', style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF94A3B8))),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: closer.conversionRate / 100,
                          backgroundColor: isDark ? const Color(0xFF0B1021) : const Color(0xFFE2E8F0),
                          valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFF37021)),
                          minHeight: 5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${closer.conversionRate.toStringAsFixed(0)}%',
                      style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFFF37021)),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Commission
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('Commission', style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF94A3B8))),
                const SizedBox(height: 2),
                Text(
                  currencyFormatter.format(closer.totalEarnedCommission),
                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCloserMobileCard(
    ClientCloser closer,
    int rank,
    NumberFormat currencyFormatter,
    bool isDark,
  ) {
    final isTop = rank == 1;

    return Container(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 26,
                    height: 26,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isTop ? const Color(0xFFF37021) : (isDark ? const Color(0xFF0B1021) : const Color(0xFFF1F5F9)),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '#$rank',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: isTop ? Colors.white : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    closer.fullName,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFF37021).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  closer.closerCode,
                  style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: const Color(0xFFF37021)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Stats Bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${closer.totalLeadsAssigned} Leads Assigned',
                style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8)),
              ),
              Text(
                '${closer.totalOrdersBooked} Booked (${closer.conversionRate.toStringAsFixed(0)}%)',
                style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF10B981)),
              ),
              Text(
                currencyFormatter.format(closer.totalEarnedCommission),
                style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFFF37021)),
              ),
            ],
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF151D36) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? const Color(0xFF2E3D6B) : const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF94A3B8)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 1),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF94A3B8)),
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
