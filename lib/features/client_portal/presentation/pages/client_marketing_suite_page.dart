import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../domain/entities/client_marketer.dart';
import '../../domain/entities/lead_form.dart';
import '../../../orders/domain/entities/order.dart';
import '../providers/client_portal_provider.dart';
import '../widgets/client_form_builder_modal.dart';
import '../widgets/client_form_embed_modal.dart';
import '../widgets/client_onboard_marketer_modal.dart';
import '../widgets/client_edit_marketer_profile_modal.dart';
import '../widgets/client_marketer_detail_modal.dart';
import '../../../../core/widgets/user_avatar_widget.dart';

class ClientMarketingSuitePage extends ConsumerStatefulWidget {
  const ClientMarketingSuitePage({super.key});

  @override
  ConsumerState<ClientMarketingSuitePage> createState() => _ClientMarketingSuitePageState();
}

class _ClientMarketingSuitePageState extends ConsumerState<ClientMarketingSuitePage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(clientPortalProvider);
    final themeMode = ref.watch(themeProvider);
    final isDark = themeMode == ThemeMode.dark ||
        (themeMode == ThemeMode.system &&
            MediaQuery.of(context).platformBrightness == Brightness.dark);
    final currencyFormatter = NumberFormat.currency(symbol: '₦', decimalDigits: 0);

    final forms = state.leadForms;
    final marketers = state.marketers;

    final filteredForms = _searchQuery.isEmpty
        ? forms
        : forms.where((f) =>
            f.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            f.productName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            f.formSlug.toLowerCase().contains(_searchQuery.toLowerCase())).toList();

    final filteredMarketers = _searchQuery.isEmpty
        ? marketers
        : marketers.where((m) =>
            m.fullName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            m.email.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            m.marketerCode.toLowerCase().contains(_searchQuery.toLowerCase())).toList();

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : const Color(0xFFF8FAFC),
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(clientPortalProvider.notifier).loadClientData();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Header
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                runSpacing: 10,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        children: [
                          Text(
                            'Digital Marketing & Ad Ingestion Suite',
                            style: GoogleFonts.inter(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              '${forms.length} Forms • ${marketers.length} Marketers',
                              style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF10B981)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Create landing page checkout forms, Meta CAPI tracking, and auto-route orders to dedicated closers',
                        style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                      ),
                    ],
                  ),

                  // Actions
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => ClientOnboardMarketerModal.show(context),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF10B981),
                          side: const BorderSide(color: Color(0xFF10B981)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        ),
                        icon: const Icon(Icons.person_add_alt_1_rounded, size: 16),
                        label: Text('Onboard Marketer', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700)),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton.icon(
                        onPressed: () => ClientFormBuilderModal.show(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        ),
                        icon: const Icon(Icons.add_rounded, size: 16),
                        label: Text('Create Lead Form', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // KPI Stats Grid
              _buildKpiMetrics(state, forms, marketers, currencyFormatter, isDark),
              const SizedBox(height: 20),

              // Tabs
              Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    TabBar(
                      controller: _tabController,
                      indicatorColor: const Color(0xFF10B981),
                      labelColor: const Color(0xFF10B981),
                      unselectedLabelColor: const Color(0xFF64748B),
                      labelStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700),
                      tabs: [
                        Tab(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.assignment_outlined, size: 16),
                              const SizedBox(width: 8),
                              Text('Campaign Lead Forms (${forms.length})'),
                            ],
                          ),
                        ),
                        Tab(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.people_alt_outlined, size: 16),
                              const SizedBox(width: 8),
                              Text('Digital Marketers Team (${marketers.length})'),
                            ],
                          ),
                        ),
                        Tab(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.insights_rounded, size: 16, color: Color(0xFF10B981)),
                              const SizedBox(width: 8),
                              const Text('Live Pipeline & Closer Analytics'),
                              const SizedBox(width: 6),
                              Container(
                                width: 7,
                                height: 7,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF10B981),
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 1),

                    // Tab View Container
                    SizedBox(
                      height: 720,
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _buildFormsList(filteredForms, isDark),
                          _buildMarketersList(filteredMarketers, currencyFormatter, isDark),
                          _buildLivePipelineReportTab(state, isDark, currencyFormatter),
                        ],
                      ),
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

  Widget _buildKpiMetrics(
    ClientPortalState state,
    List<LeadForm> forms,
    List<ClientMarketer> marketers,
    NumberFormat currencyFormatter,
    bool isDark,
  ) {
    int totalSubmissions = 0;
    int totalBooked = 0;
    int totalDelivered = 0;
    for (final f in forms) {
      totalSubmissions += f.totalSubmissions;
      totalBooked += f.totalOrdersBooked;
      totalDelivered += f.totalOrdersDelivered;
    }

    final double overallConversion = totalSubmissions > 0 ? ((totalDelivered / totalSubmissions) * 100) : 0.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isRow = constraints.maxWidth >= 768;
        final kpis = [
          _buildKpiCard('Total Lead Forms', '${forms.length}', 'Active Landing Pages', Icons.assignment_rounded, const Color(0xFF6366F1), isDark),
          _buildKpiCard('Leads Ingested', '$totalSubmissions', 'Form checkouts submitted', Icons.how_to_reg_rounded, const Color(0xFF0EA5E9), isDark),
          _buildKpiCard('Orders Booked', '$totalBooked', 'Telesales closer confirmed', Icons.phone_callback_rounded, const Color(0xFFF59E0B), isDark),
          _buildKpiCard('Delivered & Paid', '$totalDelivered', '${overallConversion.toStringAsFixed(1)}% Conversion Rate', Icons.verified_rounded, const Color(0xFF10B981), isDark),
        ];

        return isRow
            ? Row(
                children: kpis.map((k) => Expanded(child: Padding(padding: const EdgeInsets.only(right: 12), child: k))).toList(),
              )
            : Wrap(
                spacing: 12,
                runSpacing: 12,
                children: kpis.map((k) => SizedBox(width: (constraints.maxWidth - 12) / 2, child: k)).toList(),
              );
      },
    );
  }

  Widget _buildKpiCard(String label, String value, String sub, IconData icon, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF64748B))),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 16),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(value, style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w800, color: isDark ? Colors.white : const Color(0xFF0F172A))),
          const SizedBox(height: 2),
          Text(sub, style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8))),
        ],
      ),
    );
  }

  Widget _buildFormsList(List<LeadForm> forms, bool isDark) {
    if (forms.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.assignment_late_outlined, size: 48, color: const Color(0xFF94A3B8).withValues(alpha: 0.6)),
            const SizedBox(height: 12),
            Text('No Lead Forms created yet', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: const Color(0xFF64748B))),
            const SizedBox(height: 4),
            Text('Create high-converting landing page forms to begin capturing ad traffic', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8))),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => ClientFormBuilderModal.show(context),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
              icon: const Icon(Icons.add_rounded, size: 16, color: Colors.white),
              label: Text('Create First Form', style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: Colors.white)),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: forms.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final form = forms[index];
        final conversion = form.totalSubmissions > 0
            ? ((form.totalOrdersDelivered / form.totalSubmissions) * 100).toStringAsFixed(1)
            : '0.0';

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isRow = constraints.maxWidth >= 600;
              final formInfo = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: (form.isActive ? const Color(0xFF10B981) : const Color(0xFF94A3B8)).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          form.isActive ? 'ACTIVE' : 'PAUSED',
                          style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: form.isActive ? const Color(0xFF10B981) : const Color(0xFF94A3B8)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          form.title,
                          style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 12,
                    runSpacing: 4,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.inventory_2_outlined, size: 14, color: Color(0xFF6366F1)),
                          const SizedBox(width: 4),
                          Text(form.productName, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF6366F1))),
                        ],
                      ),
                      Text('•', style: GoogleFonts.inter(color: const Color(0xFF94A3B8))),
                      Text('${form.packages.length} Offer Packages', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B))),
                      if (form.pixelId.isNotEmpty) ...[
                        Text('•', style: GoogleFonts.inter(color: const Color(0xFF94A3B8))),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.radar_rounded, size: 14, color: Color(0xFF0EA5E9)),
                            const SizedBox(width: 4),
                            Text('Pixel: ${form.pixelId}', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF0EA5E9))),
                          ],
                        ),
                      ],
                    ],
                  ),
                ],
              );

              final statsAndActions = Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('${form.totalSubmissions} Leads', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF0F172A))),
                      Text('${form.totalOrdersDelivered} dlvd ($conversion%)', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF10B981))),
                    ],
                  ),
                  const SizedBox(width: 16),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF10B981),
                      side: const BorderSide(color: Color(0xFF10B981)),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    ),
                    icon: const Icon(Icons.code_rounded, size: 14),
                    label: Text('Get Embed', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700)),
                    onPressed: () => ClientFormEmbedModal.show(context, form: form),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 18, color: Color(0xFF6366F1)),
                    tooltip: 'Edit Form',
                    onPressed: () => ClientFormBuilderModal.show(context, existingForm: form),
                  ),
                ],
              );

              return isRow
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(child: formInfo),
                        const SizedBox(width: 14),
                        statsAndActions,
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        formInfo,
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            statsAndActions,
                          ],
                        ),
                      ],
                    );
            },
          ),
        );
      },
    );
  }

  Widget _buildMarketersList(List<ClientMarketer> marketers, NumberFormat currencyFormatter, bool isDark) {
    if (marketers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_search_rounded, size: 48, color: const Color(0xFF94A3B8).withValues(alpha: 0.6)),
            const SizedBox(height: 12),
            Text('No Digital Marketers in Team', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: const Color(0xFF64748B))),
            const SizedBox(height: 4),
            Text('Onboard media buyers and digital marketers to scale your marketing campaigns', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8))),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => ClientOnboardMarketerModal.show(context),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
              icon: const Icon(Icons.person_add_rounded, size: 16, color: Colors.white),
              label: Text('Onboard First Marketer', style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: Colors.white)),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: marketers.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final marketer = marketers[index];
        final conversion = marketer.totalLeadsGenerated > 0
            ? ((marketer.totalOrdersDelivered / marketer.totalLeadsGenerated) * 100).toStringAsFixed(1)
            : '0.0';

        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => ClientMarketerDetailModal.show(context, marketer: marketer),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  UserAvatarWidget(
                    avatarUrl: marketer.avatarUrl,
                    fullName: marketer.fullName,
                    radius: 20,
                  ),
                  const SizedBox(width: 14),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              marketer.fullName,
                              style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                            ),
                            const SizedBox(width: 8),
                            if (marketer.isSupervisor)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF6366F1).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.shield_rounded, size: 10, color: Color(0xFF6366F1)),
                                    const SizedBox(width: 3),
                                    Text(
                                      'SUPERVISOR',
                                      style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w800, color: const Color(0xFF6366F1)),
                                    ),
                                  ],
                                ),
                              )
                            else
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10B981).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  marketer.marketerCode,
                                  style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: const Color(0xFF10B981)),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${marketer.email} • ${marketer.phone}',
                          style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                        ),
                        if (!marketer.isSupervisor && marketer.supervisorName != null && marketer.supervisorName!.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              const Icon(Icons.subdirectory_arrow_right_rounded, size: 12, color: Color(0xFF6366F1)),
                              const SizedBox(width: 4),
                              Text(
                                'Supervised by ${marketer.supervisorName}',
                                style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w600, color: const Color(0xFF6366F1)),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Stats
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        marketer.commissionModel == 'per_form_submission'
                            ? 'Comm: ${currencyFormatter.format(marketer.effectiveCommissionPerSubmission)}/Form'
                            : 'Comm: ${currencyFormatter.format(marketer.effectiveCommissionPerDelivery)}/Delivery',
                        style: GoogleFonts.inter(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: marketer.commissionModel == 'per_form_submission' ? const Color(0xFF10B981) : const Color(0xFF0284C7),
                        ),
                      ),
                      Text(
                        'Budget: ${currencyFormatter.format(marketer.dailyAdSpendBudget)}/day',
                        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF0EA5E9)),
                      ),
                      Text(
                        '${marketer.totalLeadsGenerated} Leads • ${marketer.totalOrdersDelivered} dlvd ($conversion%)',
                        style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                      ),
                      if (marketer.totalCommissionEarned > 0)
                        Text(
                          'Earned: ${currencyFormatter.format(marketer.totalCommissionEarned)}',
                          style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF10B981)),
                        ),
                    ],
                  ),
                  const SizedBox(width: 12),

                  // Edit profile icon
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 18, color: Color(0xFF6366F1)),
                    tooltip: 'Edit Profile & Details',
                    onPressed: () => ClientEditMarketerProfileModal.show(context, marketer: marketer),
                  ),
                  const SizedBox(width: 4),

                  // Status switch
                  Switch.adaptive(
                    value: marketer.isActive,
                    activeColor: const Color(0xFF10B981),
                    onChanged: (val) async {
                      await ref.read(clientPortalProvider.notifier).updateMarketerStatus(marketer.id, val);
                    },
                  ),
                  const SizedBox(width: 4),

                  // Navigation Chevron
                  const Icon(Icons.chevron_right_rounded, size: 20, color: Color(0xFF94A3B8)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLivePipelineReportTab(ClientPortalState state, bool isDark, NumberFormat currencyFormatter) {
    final orders = state.orders;
    final closers = state.closers;

    final totalOrders = orders.length;
    final confirmedCount = orders.where((o) => o.status != 'new' && o.status != 'unconfirmed').length;
    final dispatchedCount = orders.where((o) => o.status == 'assigned' || o.status == 'in_transit' || o.status == 'pending_dispatch').length;
    final deliveredCount = orders.where((o) => o.status == 'delivered').length;

    final closerConfirmationRate = totalOrders > 0 ? (confirmedCount / totalOrders * 100) : 0.0;
    final deliveryFulfillmentRate = confirmedCount > 0 ? (deliveredCount / confirmedCount * 100) : 0.0;

    // Regional Breakdown (State + LGA)
    final Map<String, List<OrderEntity>> lgaGroups = {};
    for (final o in orders) {
      final stateName = o.deliveryState.isNotEmpty ? o.deliveryState : 'Other';
      final lgaName = (o.lga?.isNotEmpty == true) ? o.lga! : (o.deliveryCity.isNotEmpty ? o.deliveryCity : 'Central');
      final key = '$stateName - $lgaName';
      lgaGroups.putIfAbsent(key, () => []).add(o);
    }
    final sortedLgas = lgaGroups.entries.toList()
      ..sort((a, b) => b.value.length.compareTo(a.value.length));

    // Live Activity Stream
    final recentOrders = [...orders]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final liveStream = recentOrders.take(10).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 1. Live Socket Replication Active Banner
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? [const Color(0xFF064E3B), const Color(0xFF065F46)]
                  : [const Color(0xFFECFDF5), const Color(0xFFD1FAE5)],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.sensors_rounded, color: Color(0xFF10B981), size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'LIVE REALTIME PIPELINE ACTIVE',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                            color: isDark ? const Color(0xFF34D399) : const Color(0xFF047857),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Color(0xFF10B981),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Replicating lead form checkouts, phone confirmations, DC dispatches, and rider cash deliveries via Supabase WebSockets.',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: isDark ? const Color(0xFFA7F3D0) : const Color(0xFF065F46),
                      ),
                    ),
                  ],
                ),
              ),
              OutlinedButton.icon(
                onPressed: () async {
                  await ref.read(clientPortalProvider.notifier).loadClientData();
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF10B981),
                  side: const BorderSide(color: Color(0xFF10B981)),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                ),
                icon: const Icon(Icons.sync_rounded, size: 14),
                label: Text('Sync Now', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 2. End-to-End Funnel Progression
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Full Operational Funnel & Conversion Velocity',
                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: isDark ? Colors.white : const Color(0xFF0F172A)),
              ),
              const SizedBox(height: 14),
              LayoutBuilder(
                builder: (context, constraints) {
                  final isRow = constraints.maxWidth >= 600;
                  final funnelSteps = [
                    _buildFunnelCard('1. Ingested Leads', '$totalOrders', 'From ad checkout forms', const Color(0xFF0EA5E9), isDark),
                    _buildFunnelCard('2. Closer Confirmed', '$confirmedCount', '${closerConfirmationRate.toStringAsFixed(1)}% Closer Conv', const Color(0xFFF59E0B), isDark),
                    _buildFunnelCard('3. Dispatched to DC', '$dispatchedCount', 'Routed by State & LGA', const Color(0xFF8B5CF6), isDark),
                    _buildFunnelCard('4. Delivered COD', '$deliveredCount', '${deliveryFulfillmentRate.toStringAsFixed(1)}% Logistics Conv', const Color(0xFF10B981), isDark),
                  ];
                  return isRow
                      ? Row(children: funnelSteps.map((s) => Expanded(child: Padding(padding: const EdgeInsets.only(right: 8), child: s))).toList())
                      : Column(children: funnelSteps.map((s) => Padding(padding: const EdgeInsets.only(bottom: 8), child: s)).toList());
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 3. Sales Closers Realtime Performance Leaderboard
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Sales Closer Live Leaderboard (${closers.length} Closers)',
                    style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                  ),
                  Text(
                    'Product-Attached Telesales',
                    style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (closers.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Center(
                    child: Text('No active closers onboarded yet.', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8))),
                  ),
                )
              else
                ...closers.map((c) {
                  final cOrders = orders.where((o) => o.closerId == c.id).toList();
                  final cConfirmed = cOrders.where((o) => o.status != 'new' && o.status != 'unconfirmed').length;
                  final cDelivered = cOrders.where((o) => o.status == 'delivered').length;
                  final cConv = cOrders.isNotEmpty ? ((cConfirmed / cOrders.length) * 100) : 0.0;
                  final cRev = cOrders.where((o) => o.status == 'delivered').fold<double>(0.0, (sum, o) => sum + o.totalAmount);

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                          child: Text(
                            c.fullName.isNotEmpty ? c.fullName[0].toUpperCase() : 'C',
                            style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: const Color(0xFFF59E0B)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    c.fullName,
                                    style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      c.closerCode,
                                      style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFFF59E0B)),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${c.assignedProductIds.length} Products Attached • ${c.phone}',
                                style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '${cOrders.length} Leads • $cConfirmed Confirmed (${cConv.toStringAsFixed(0)}%)',
                              style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 12, color: const Color(0xFF10B981)),
                            ),
                            Text(
                              '$cDelivered Delivered • ${currencyFormatter.format(cRev)} COD',
                              style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 4. Regional Nigerian Logistics Hotspots (State & LGA)
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Top Regional Logistics Hotspots (State & LGA Fulfillment)',
                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: isDark ? Colors.white : const Color(0xFF0F172A)),
              ),
              const SizedBox(height: 12),
              if (sortedLgas.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Center(
                    child: Text('No regional order data yet.', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8))),
                  ),
                )
              else
                ...sortedLgas.take(6).map((entry) {
                  final groupOrders = entry.value;
                  final dlvd = groupOrders.where((o) => o.status == 'delivered').length;
                  final rate = groupOrders.isNotEmpty ? ((dlvd / groupOrders.length) * 100) : 0.0;
                  final rev = groupOrders.where((o) => o.status == 'delivered').fold<double>(0.0, (s, o) => s + o.totalAmount);

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        const Icon(Icons.location_on_rounded, size: 16, color: Color(0xFF0EA5E9)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            entry.key,
                            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                          ),
                        ),
                        Text(
                          '${groupOrders.length} Leads • $dlvd Delivered (${rate.toStringAsFixed(0)}%) • ${currencyFormatter.format(rev)}',
                          style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  );
                }),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 5. Live Orders Activity Stream Ticker
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Live Operational Event Stream',
                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: isDark ? Colors.white : const Color(0xFF0F172A)),
              ),
              const SizedBox(height: 12),
              if (liveStream.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Center(
                    child: Text('No orders in stream yet.', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8))),
                  ),
                )
              else
                ...liveStream.map((o) {
                  Color statusColor = const Color(0xFFF59E0B);
                  if (o.status == 'delivered') statusColor = const Color(0xFF10B981);
                  if (o.status == 'assigned' || o.status == 'in_transit') statusColor = const Color(0xFF0EA5E9);
                  if (o.status == 'cancelled') statusColor = const Color(0xFFEF4444);

                  return Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Text(
                          o.orderNumber,
                          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${o.customerName} • ${o.deliveryState} (${(o.lga?.isNotEmpty == true) ? o.lga : o.deliveryCity})',
                            style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            o.status.toUpperCase(),
                            style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: statusColor),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          currencyFormatter.format(o.totalAmount),
                          style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                        ),
                      ],
                    ),
                  );
                }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFunnelCard(String title, String count, String subtitle, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
          const SizedBox(height: 4),
          Text(count, style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800, color: isDark ? Colors.white : const Color(0xFF0F172A))),
          const SizedBox(height: 2),
          Text(subtitle, style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF64748B))),
        ],
      ),
    );
  }
}
