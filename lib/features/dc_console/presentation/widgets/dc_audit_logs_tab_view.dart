import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../domain/entities/dc_audit_log_item.dart';
import '../../domain/entities/distribution_center.dart';
import '../providers/dc_audit_logs_provider.dart';

class DCAuditLogsTabView extends ConsumerStatefulWidget {
  final DistributionCenter? officerDc;
  final bool isDark;

  const DCAuditLogsTabView({
    super.key,
    this.officerDc,
    required this.isDark,
  });

  @override
  ConsumerState<DCAuditLogsTabView> createState() => _DCAuditLogsTabViewState();
}

class _DCAuditLogsTabViewState extends ConsumerState<DCAuditLogsTabView> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(dcAuditLogsProvider.notifier).loadLogs(dcId: widget.officerDc?.id);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auditState = ref.watch(dcAuditLogsProvider);
    final isDark = widget.isDark;
    final dcName = widget.officerDc?.name ?? 'Distribution Center';

    return RefreshIndicator(
      onRefresh: () async {
        await ref.read(dcAuditLogsProvider.notifier).loadLogs(dcId: widget.officerDc?.id);
      },
      color: const Color(0xFF0D9488),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 120),
        children: [
          // 1. Station Audit Trail Header Card
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF151D36) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? const Color(0xFF2E3D6B) : const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D9488).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.manage_history_rounded, color: Color(0xFF0D9488), size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'DC Audit Trail & Activity Logs',
                        style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        'Scoped live activity trail for $dcName',
                        style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh_rounded, size: 20),
                  tooltip: 'Reload audit logs',
                  onPressed: () {
                    ref.read(dcAuditLogsProvider.notifier).loadLogs(dcId: widget.officerDc?.id);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // 2. Responsive 4-Column Quick KPIs
          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  label: 'Total Logs',
                  count: auditState.totalCount,
                  color: const Color(0xFF0D9488),
                  isDark: isDark,
                  onTap: () => ref.read(dcAuditLogsProvider.notifier).setFilter('all'),
                  isActive: auditState.activeFilter == 'all',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMetricTile(
                  label: 'Remittance',
                  count: auditState.remittancesCount,
                  color: const Color(0xFFF59E0B),
                  isDark: isDark,
                  onTap: () => ref.read(dcAuditLogsProvider.notifier).setFilter('remittance'),
                  isActive: auditState.activeFilter == 'remittance',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMetricTile(
                  label: 'Delivered',
                  count: auditState.deliveriesCount,
                  color: const Color(0xFF10B981),
                  isDark: isDark,
                  onTap: () => ref.read(dcAuditLogsProvider.notifier).setFilter('delivery'),
                  isActive: auditState.activeFilter == 'delivery',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMetricTile(
                  label: 'Exceptions',
                  count: auditState.failuresCount,
                  color: const Color(0xFFEF4444),
                  isDark: isDark,
                  onTap: () => ref.read(dcAuditLogsProvider.notifier).setFilter('failure'),
                  isActive: auditState.activeFilter == 'failure',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 3. Search Bar (Search by Account: who performed the action)
          Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(24),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                Icon(
                  Icons.person_search_rounded,
                  size: 20,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) {
                      ref.read(dcAuditLogsProvider.notifier).setSearchQuery(val);
                    },
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                    decoration: InputDecoration(
                      hintText: 'Search by account name (e.g. Oladele, Joel), role, ref...',
                      hintStyle: GoogleFonts.inter(
                        fontSize: 12,
                        color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                      ),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 11),
                      border: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      enabledBorder: InputBorder.none,
                    ),
                  ),
                ),
                if (_searchController.text.isNotEmpty)
                  InkWell(
                    onTap: () {
                      _searchController.clear();
                      ref.read(dcAuditLogsProvider.notifier).setSearchQuery('');
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(
                        Icons.clear_rounded,
                        size: 16,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // 4. Action Type Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('All Logs', 'all', auditState.totalCount, auditState.activeFilter),
                _buildFilterChip('Remittances', 'remittance', auditState.remittancesCount, auditState.activeFilter),
                _buildFilterChip('Deliveries', 'delivery', auditState.deliveriesCount, auditState.activeFilter),
                _buildFilterChip('Failures', 'failure', auditState.failuresCount, auditState.activeFilter),
                _buildFilterChip('Stock', 'stock', auditState.stockCount, auditState.activeFilter),
                _buildFilterChip('Dispatch', 'dispatch', auditState.dispatchCount, auditState.activeFilter),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // 5. Audit Log Cards List
          if (auditState.isLoading && auditState.logs.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(40),
                child: CircularProgressIndicator(color: Color(0xFF0D9488)),
              ),
            )
          else if (auditState.filteredLogs.isEmpty)
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF151D36) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDark ? const Color(0xFF2E3D6B) : const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  Icon(Icons.assignment_late_outlined, size: 40, color: const Color(0xFF64748B).withValues(alpha: 0.6)),
                  const SizedBox(height: 12),
                  Text(
                    'No Audit Logs Found',
                    style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _searchController.text.isNotEmpty
                        ? 'No logs matched account query "${_searchController.text}".'
                        : 'No events have been recorded in this category for $dcName.',
                    style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          else
            ...auditState.filteredLogs.map((log) => _buildLogCard(log, isDark)),
        ],
      ),
    );
  }

  Widget _buildMetricTile({
    required String label,
    required int count,
    required Color color,
    required bool isDark,
    required VoidCallback onTap,
    required bool isActive,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(
          color: isActive
              ? color.withValues(alpha: isDark ? 0.25 : 0.12)
              : (isDark ? const Color(0xFF151D36) : Colors.white),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isActive ? color : (isDark ? const Color(0xFF2E3D6B) : const Color(0xFFE2E8F0)),
            width: isActive ? 1.5 : 1.0,
          ),
        ),
        child: Column(
          children: [
            Text(
              '$count',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 9.5,
                fontWeight: FontWeight.w600,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, String value, int count, String currentFilter) {
    final isSelected = currentFilter == value;
    final isDark = widget.isDark;

    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        selected: isSelected,
        label: Text('$label ($count)'),
        labelStyle: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          color: isSelected
              ? Colors.white
              : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569)),
        ),
        backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
        selectedColor: const Color(0xFF0D9488),
        checkmarkColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        side: BorderSide.none,
        onSelected: (_) {
          ref.read(dcAuditLogsProvider.notifier).setFilter(value);
        },
      ),
    );
  }

  Widget _buildLogCard(DCAuditLogItem log, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF151D36) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? const Color(0xFF2E3D6B) : const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: Action Type Pill, Timestamp, and Icon
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: log.color.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: Icon(log.icon, size: 16, color: log.color),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: log.color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        log.actionTypeLabel.toUpperCase(),
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: log.color,
                        ),
                      ),
                    ),
                    if (log.referenceId != null && log.referenceId!.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          log.referenceId!,
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF64748B),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Text(
                DateFormat('dd MMM, hh:mm a').format(log.createdAt),
                style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF94A3B8)),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Title
          Text(
            log.title,
            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 3),

          // Description Message
          Text(
            log.message,
            style: GoogleFonts.inter(
              fontSize: 11.5,
              color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
              height: 1.35,
            ),
          ),
          const SizedBox(height: 8),

          // Bottom Info: Actor (Who performed the action)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.person_rounded, size: 12, color: log.color),
                    const SizedBox(width: 4),
                    Text(
                      '${log.actorName} • ${log.actorRole}',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white70 : const Color(0xFF334155),
                      ),
                    ),
                  ],
                ),
              ),
              if (log.actionRoute != null && log.actionRoute!.isNotEmpty)
                Text(
                  'Scope: ${log.dcName.isNotEmpty ? log.dcName : "Hub"}',
                  style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF64748B)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
