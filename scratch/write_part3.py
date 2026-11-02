p3 = """
  Widget _buildUpgRequestCard(UpgRequest req, String supervisorName, bool isDark) {
    final bool isPending = req.isPending;
    final bool isApproved = req.isApproved;

    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isApproved
              ? const Color(0xFF10B981).withValues(alpha: 0.3)
              : (isPending
                  ? const Color(0xFFF37021).withValues(alpha: 0.3)
                  : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
          width: isPending ? 1.2 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '#${req.orderNumber}',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF2563EB),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        req.customerName,
                        style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: (isApproved
                          ? const Color(0xFF10B981)
                          : (isPending ? const Color(0xFFF37021) : const Color(0xFFDC2626)))
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  req.status.toUpperCase(),
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: isApproved
                        ? const Color(0xFF10B981)
                        : (isPending ? const Color(0xFFF37021) : const Color(0xFFDC2626)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Row(
            children: [
              const Icon(Icons.headset_mic_outlined, size: 12, color: Color(0xFF64748B)),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  'Rep: ${req.closerName} (${req.closerCode}) • Phone: ${req.customerPhone}',
                  style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Comparison box
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Original Order', style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF64748B))),
                          Text(
                            '${req.originalProduct} (${req.originalQuantity}x)',
                            style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w500),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Text(
                      _currency.format(req.originalAmount),
                      style: GoogleFonts.jetBrainsMono(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 4),
                  child: Divider(height: 1),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.arrow_upward_rounded, size: 11, color: Color(0xFF10B981)),
                              const SizedBox(width: 2),
                              Text('Proposed UPG', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF10B981))),
                            ],
                          ),
                          Text(
                            '${req.upgradedProduct} (${req.upgradedQuantity}x)',
                            style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.bold),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          _currency.format(req.upgradedAmount),
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF10B981),
                          ),
                        ),
                        Text(
                          '+${_currency.format(req.upsellDelta)} (+${req.upsellPercentage.toStringAsFixed(0)}%)',
                          style: GoogleFonts.jetBrainsMono(fontSize: 9.5, fontWeight: FontWeight.w600, color: const Color(0xFF10B981)),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          if (req.reason.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'Notes: \"${req.reason}\"',
                style: GoogleFonts.inter(fontSize: 10.5, fontStyle: FontStyle.italic, color: const Color(0xFF64748B)),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),

          if (isPending) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00522A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.check_circle_rounded, size: 15),
                    label: const Text(
                      'Approve UPG',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                    onPressed: () async {
                      final res = await ref.read(salesSupervisorProvider.notifier).approveUpgRequest(
                        upgId: req.id,
                        supervisorName: supervisorName,
                      );
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            backgroundColor: res['success'] == true ? const Color(0xFF10B981) : const Color(0xFFDC2626),
                            content: Text(res['message']?.toString() ?? 'UPG processed.'),
                          ),
                        );
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFDC2626),
                      side: const BorderSide(color: Color(0xFFDC2626)),
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.cancel_outlined, size: 14),
                    label: const Text(
                      'Decline',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5),
                    ),
                    onPressed: () => _showRejectPrompt(context, req, supervisorName),
                  ),
                ),
              ],
            ),
          ] else if (req.approvedBy != null) ...[
            Text(
              'Authorized by ${req.approvedBy} on ${DateFormat(\"dd MMM yyyy, hh:mm a\").format(req.approvedAt ?? req.createdAt)}',
              style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF10B981)),
            ),
          ],
        ],
      ),
    );
  }

  void _showRejectPrompt(BuildContext context, UpgRequest req, String supervisorName) {
    final reasonController = TextEditingController(text: 'Customer declined larger package upon review.');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Decline UPG Request', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Specify reason for declining upgrade on #${req.orderNumber}:', style: GoogleFonts.inter(fontSize: 12)),
            const SizedBox(height: 8),
            TextField(
              controller: reasonController,
              maxLines: 2,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Reason for rejection...',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626), foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              final res = await ref.read(salesSupervisorProvider.notifier).rejectUpgRequest(
                upgId: req.id,
                reason: reasonController.text.trim(),
                supervisorName: supervisorName,
              );
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: const Color(0xFFDC2626),
                    content: Text(res['message']?.toString() ?? 'UPG request declined.'),
                  ),
                );
              }
            },
            child: const Text('Confirm Decline'),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 1: SUPERVISEES LEADERBOARD (PILLAR 2)
  // ==========================================
  Widget _buildLeaderboardTab(SalesSupervisorState state, bool isDark) {
    final ranked = state.rankedSupervisees;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            border: Border(bottom: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Rank Supervisees by:',
                style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.bold),
              ),
              Row(
                children: [
                  _buildSortPill('Orders Closed', 'orders', isDark),
                  const SizedBox(width: 6),
                  _buildSortPill('Revenue', 'revenue', isDark),
                  const SizedBox(width: 6),
                  _buildSortPill('Conversion %', 'conversion', isDark),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: ranked.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.people_outline_rounded, size: 48, color: Colors.grey),
                      const SizedBox(height: 12),
                      Text('No Supervisees Registered', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15)),
                      const SizedBox(height: 4),
                      const Text('Closers attached to this merchant will appear in the leaderboard.', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: ranked.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final item = ranked[index];
                    final rank = index + 1;
                    return _buildLeaderboardCard(item, rank, isDark);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildSortPill(String title, String value, bool isDark) {
    final state = ref.watch(salesSupervisorProvider);
    final isSelected = state.leaderboardSort == value;

    return GestureDetector(
      onTap: () => ref.read(salesSupervisorProvider.notifier).setLeaderboardSort(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF2563EB)
              : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9)),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }

  Widget _buildLeaderboardCard(SuperviseePerformance item, int rank, bool isDark) {
    final closer = item.closer;

    Color rankColor;
    String rankEmoji;
    if (rank == 1) {
      rankColor = const Color(0xFFF59E0B);
      rankEmoji = '🥇 #1';
    } else if (rank == 2) {
      rankColor = const Color(0xFF94A3B8);
      rankEmoji = '🥈 #2';
    } else if (rank == 3) {
      rankColor = const Color(0xFFD97706);
      rankEmoji = '🥉 #3';
    } else {
      rankColor = const Color(0xFF64748B);
      rankEmoji = '#$rank';
    }

    return InkWell(
      onTap: () => SuperviseeDetailModal.show(context, performance: item, isDark: isDark),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: rank == 1
                ? const Color(0xFFF59E0B).withValues(alpha: 0.35)
                : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            width: rank == 1 ? 1.4 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: rankColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: Text(
                rankEmoji,
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: rankColor,
                ),
              ),
            ),
            const SizedBox(width: 10),
            UserAvatarWidget(fullName: closer.fullName, radius: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          closer.fullName,
                          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF37021).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          closer.closerCode,
                          style: GoogleFonts.jetBrainsMono(fontSize: 8.5, fontWeight: FontWeight.bold, color: const Color(0xFFF37021)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${item.totalOrders} Orders • ${_currency.format(item.totalRevenue)}',
                    style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(
                    '${item.conversionRate.toStringAsFixed(1)}% Conv',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF10B981),
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Tap details →',
                  style: GoogleFonts.inter(fontSize: 9.5, color: const Color(0xFF94A3B8)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // TAB 2: MY SALES DESK (PILLAR 1: FULL CLOSER)
  // ==========================================
  Widget _buildMySalesDeskTab(SalesSupervisorState state, bool isDark) {
    final user = ref.read(authProvider).user;
    final leads = state.leads;

    List<CustomerLead> filteredLeads = leads;
    if (_leadStatusFilter != 'all') {
      filteredLeads = leads.where((l) => l.status.toLowerCase().contains(_leadStatusFilter)).toList();
    }

    return Column(
      children: [
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
                      _buildLeadPill('All Leads (${leads.length})', 'all', isDark),
                      const SizedBox(width: 6),
                      _buildLeadPill('New (${leads.where((l) => l.status.toLowerCase().contains(\"new\")).length})', 'new', isDark),
                      const SizedBox(width: 6),
                      _buildLeadPill('Confirmed (${leads.where((l) => l.status.toLowerCase().contains(\"confirmed\")).length})', 'confirmed', isDark),
                      const SizedBox(width: 6),
                      _buildLeadPill('Follow-up (${leads.where((l) => l.status.toLowerCase().contains(\"back\") || l.status.toLowerCase().contains(\"follow\")).length})', 'back', isDark),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: filteredLeads.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.headset_mic_outlined, size: 44, color: Colors.grey),
                      const SizedBox(height: 10),
                      Text('No customer leads matching filter', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14)),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: filteredLeads.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final lead = filteredLeads[index];
                    return _buildLeadCard(lead, user?.fullName ?? 'Supervisor', user?.closerCode ?? 'SUP-01', isDark);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildLeadPill(String title, String value, bool isDark) {
    final isSelected = _leadStatusFilter == value;
    return GestureDetector(
      onTap: () => setState(() => _leadStatusFilter = value),
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

  Widget _buildLeadCard(CustomerLead lead, String closerName, String closerCode, bool isDark) {
    final phone = lead.customerPhone;
    final bool isConfirmed = lead.status.toLowerCase().contains('confirmed') || lead.status.toLowerCase().contains('order');

    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  lead.customerName,
                  style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: (isConfirmed ? const Color(0xFF10B981) : const Color(0xFF2563EB)).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  lead.status.replaceAll('_', ' ').toUpperCase(),
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: isConfirmed ? const Color(0xFF10B981) : const Color(0xFF2563EB),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            '${lead.productName} • ${lead.deliveryState.isNotEmpty ? lead.deliveryState : \"Nigeria\"}',
            style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              if (phone.isNotEmpty) ...[
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF10B981),
                    side: const BorderSide(color: Color(0xFF10B981)),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
                  ),
                  icon: const Icon(Icons.phone_rounded, size: 14),
                  label: const Text('Call', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  onPressed: () => launchUrl(Uri.parse('tel:$phone')),
                ),
                const SizedBox(width: 6),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF2563EB),
                    side: const BorderSide(color: Color(0xFF2563EB)),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
                  ),
                  icon: const Icon(Icons.chat_rounded, size: 14),
                  label: const Text('WhatsApp', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  onPressed: () => launchUrl(Uri.parse('https://wa.me/234${phone.replaceAll(RegExp(r\"[^0-9]\"), \"\")}')),
                ),
              ],
              const Spacer(),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF37021),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
                ),
                icon: const Icon(Icons.shopping_cart_checkout_rounded, size: 14),
                label: const Text('Convert Order', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => ClientConvertLeadModal(lead: lead),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
"""
with open("lib/features/client_portal/presentation/pages/merchant_sales_supervisor_page.dart", "a", encoding="utf-8") as f:
    f.write(p3)
print("Part 3 written")
