p2 = """
  // ==========================================
  // RESPONSIVE 2x2 KPI GRID
  // ==========================================
  Widget _buildKpiGrid(SalesSupervisorState state, bool isDark) {
    final pendingCount = state.pendingUpgRequests.length;
    final approvedToday = state.approvedTodayCount;
    final totalUpsell = state.totalUpsellValueApproved;
    final activeSupervisees = state.closers.length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        border: Border(bottom: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildCompactKpiCard(
                  title: 'PENDING UPG QUEUE',
                  value: '$pendingCount',
                  unit: 'Requests',
                  subtitle: 'Awaiting authorization',
                  icon: Icons.pending_actions_rounded,
                  color: const Color(0xFFF37021),
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildCompactKpiCard(
                  title: 'APPROVED TODAY',
                  value: '$approvedToday',
                  unit: 'Upgrades',
                  subtitle: 'Authorized package UPGs',
                  icon: Icons.check_circle_outline_rounded,
                  color: const Color(0xFF10B981),
                  isDark: isDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildCompactKpiCard(
                  title: 'UPSELL VALUE',
                  value: _currency.format(totalUpsell),
                  unit: '',
                  subtitle: 'Incremental sales gain',
                  icon: Icons.trending_up_rounded,
                  color: const Color(0xFF2563EB),
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildCompactKpiCard(
                  title: 'ACTIVE SUPERVISEES',
                  value: '$activeSupervisees',
                  unit: 'Reps',
                  subtitle: 'In telesales team',
                  icon: Icons.people_alt_outlined,
                  color: const Color(0xFF8B5CF6),
                  isDark: isDark,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCompactKpiCard({
    required String title,
    required String value,
    required String unit,
    required String subtitle,
    required IconData icon,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : color.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : color.withValues(alpha: 0.18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(icon, size: 14, color: color),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(
                child: Text(
                  value,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (unit.isNotEmpty) ...[
                const SizedBox(width: 4),
                Text(
                  unit,
                  style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: color),
                ),
              ],
            ],
          ),
          Text(
            subtitle,
            style: GoogleFonts.inter(fontSize: 9.5, color: const Color(0xFF64748B)),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TAB ROUTER
  // ==========================================
  Widget _buildActiveTabBody(SalesSupervisorState state, bool isDark) {
    switch (_activeTab) {
      case 0:
        return _buildUpgQueueTab(state, isDark);
      case 1:
        return _buildLeaderboardTab(state, isDark);
      case 2:
        return _buildMySalesDeskTab(state, isDark);
      case 3:
        return DCStaffProfileSettingsTab(
          roleBadgeTitle: 'Merchant Sales Supervisor',
          departmentLabel: 'TELESALES & UPG GOVERNANCE',
          accentColor: const Color(0xFFF37021),
          roleIcon: Icons.verified_user_rounded,
        );
      default:
        return _buildUpgQueueTab(state, isDark);
    }
  }

  // ==========================================
  // TAB 0: UPG APPROVAL QUEUE (PILLAR 3)
  // ==========================================
  Widget _buildUpgQueueTab(SalesSupervisorState state, bool isDark) {
    final requests = state.filteredUpgRequests;
    final user = ref.read(authProvider).user;
    final supervisorName = user?.fullName.isNotEmpty == true ? user!.fullName : 'Sales Supervisor';

    return Column(
      children: [
        // Action Bar & Filter Pills (Zero Overflow)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            border: Border(bottom: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
          ),
          child: Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildUpgFilterPill('Pending (${state.pendingUpgRequests.length})', 'pending', isDark),
                      const SizedBox(width: 6),
                      _buildUpgFilterPill('Approved (${state.upgRequests.where((r) => r.isApproved).length})', 'approved', isDark),
                      const SizedBox(width: 6),
                      _buildUpgFilterPill('Rejected (${state.upgRequests.where((r) => r.isRejected).length})', 'rejected', isDark),
                      const SizedBox(width: 6),
                      _buildUpgFilterPill('All (${state.upgRequests.length})', 'all', isDark),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        // List of UPG Requests
        Expanded(
          child: requests.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.check_circle_outline_rounded, size: 48, color: Color(0xFF10B981)),
                      const SizedBox(height: 12),
                      Text(
                        state.upgFilter == 'pending'
                            ? 'All UPG Requests Cleared! 🎉'
                            : 'No UPG requests matching filter.',
                        style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        state.upgFilter == 'pending'
                            ? 'Upgrade requests submitted by sales reps will appear here.'
                            : 'Try switching to another filter tab above.',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: requests.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final req = requests[index];
                    return _buildUpgRequestCard(req, supervisorName, isDark);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildUpgFilterPill(String title, String value, bool isDark) {
    final state = ref.watch(salesSupervisorProvider);
    final isSelected = state.upgFilter == value;

    return GestureDetector(
      onTap: () => ref.read(salesSupervisorProvider.notifier).setUpgFilter(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFF37021)
              : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9)),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }
"""
with open("lib/features/client_portal/presentation/pages/merchant_sales_supervisor_page.dart", "a", encoding="utf-8") as f:
    f.write(p2)
print("Part 2 written")
