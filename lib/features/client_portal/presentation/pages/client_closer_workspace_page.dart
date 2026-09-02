import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../../../core/widgets/product_image_widget.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../dc_console/presentation/providers/product_catalog_provider.dart';
import '../../domain/entities/client_closer.dart';
import '../../domain/entities/customer_lead.dart';
import '../providers/client_portal_provider.dart';
import '../widgets/client_convert_lead_modal.dart';

class ClientCloserWorkspacePage extends ConsumerWidget {
  const ClientCloserWorkspacePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(clientPortalProvider);
    final user = ref.watch(authProvider).user;
    final themeMode = ref.watch(themeProvider);
    final isDark = themeMode == ThemeMode.dark ||
        (themeMode == ThemeMode.system &&
            MediaQuery.of(context).platformBrightness == Brightness.dark);
    final currencyFormatter = NumberFormat.currency(symbol: '₦', decimalDigits: 0);

    // Identify current closer profile
    final currentCloser = state.closers.firstWhere(
      (c) => c.id == user?.closerId || c.email == user?.email,
      orElse: () => state.closers.isNotEmpty
          ? state.closers.first
          : const ClientCloser(
              id: '44444444-4444-4444-8444-444444444444',
              clientId: '33333333-3333-4333-8333-333333333333',
              closerCode: 'CLS-NOVA-001',
              fullName: 'Amaka Chioma',
              email: 'closer.amaka@novacale.ng',
              phone: '08021122334',
              dailyCallTarget: 50,
            ),
    );

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
              // Closer Profile & Daily Mission Banner
              _buildMissionBanner(context, currentCloser, state, currencyFormatter, isDark),
              const SizedBox(height: 20),

              // Pipeline Filter Tabs & Search Toolbar (Responsive)
              _buildFilterToolbar(context, ref, state, isDark),
              const SizedBox(height: 16),

              // Leads Pipeline List
              if (state.filteredLeads.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(40),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF151D36) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark ? const Color(0xFF2E3D6B) : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.assignment_turned_in_rounded,
                          size: 44,
                          color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No customer leads matching current filter.',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: state.filteredLeads.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final lead = state.filteredLeads[index];
                    return _buildLeadCard(context, ref, lead, currencyFormatter, isDark);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMissionBanner(
    BuildContext context,
    ClientCloser currentCloser,
    ClientPortalState state,
    NumberFormat currencyFormatter,
    bool isDark,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF001738), Color(0xFF0A2E5C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF001738).withValues(alpha: 0.35),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
        border: Border.all(color: const Color(0xFF1A3B66)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Avatar, Name & Commission Badge
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 10,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF37021).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFF37021).withValues(alpha: 0.5)),
                    ),
                    child: const Icon(Icons.headset_mic_rounded, color: Color(0xFFF37021), size: 24),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${currentCloser.fullName} (${currentCloser.closerCode})',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        '${state.clientProfile.companyName} • Telesales Closer Desk',
                        style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8)),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF37021).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFF37021).withValues(alpha: 0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.stars_rounded, color: Color(0xFFFBBF24), size: 16),
                    const SizedBox(width: 6),
                    Text(
                      'Commission: ${currencyFormatter.format(currentCloser.totalEarnedCommission)}',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Divider(color: Color(0xFF1A3B66), height: 1),
          const SizedBox(height: 16),

          // Responsive Stats KPIs
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 600;
              if (isWide) {
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: _buildCloserStatItem('Leads Assigned', '${currentCloser.totalLeadsAssigned}', Icons.contacts_rounded)),
                    Expanded(child: _buildCloserStatItem('Orders Booked', '${currentCloser.totalOrdersBooked}', Icons.shopping_bag_rounded)),
                    Expanded(child: _buildCloserStatItem('Conversion Rate', '${currentCloser.conversionRate.toStringAsFixed(0)}%', Icons.trending_up_rounded)),
                    Expanded(child: _buildCloserStatItem('Delivered (POD)', '${currentCloser.totalOrdersDelivered}', Icons.verified_rounded)),
                  ],
                );
              } else {
                return GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 2.3,
                  children: [
                    _buildCloserStatItem('Leads Assigned', '${currentCloser.totalLeadsAssigned}', Icons.contacts_rounded),
                    _buildCloserStatItem('Orders Booked', '${currentCloser.totalOrdersBooked}', Icons.shopping_bag_rounded),
                    _buildCloserStatItem('Conversion Rate', '${currentCloser.conversionRate.toStringAsFixed(0)}%', Icons.trending_up_rounded),
                    _buildCloserStatItem('Delivered (POD)', '${currentCloser.totalOrdersDelivered}', Icons.verified_rounded),
                  ],
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCloserStatItem(String label, String value, IconData icon) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: const Color(0xFFF37021), size: 18),
        const SizedBox(width: 8),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                label,
                style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF94A3B8)),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFilterToolbar(
    BuildContext context,
    WidgetRef ref,
    ClientPortalState state,
    bool isDark,
  ) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isCompact = screenWidth < 768;

    final searchField = SizedBox(
      height: 40,
      child: TextField(
        onChanged: (v) => ref.read(clientPortalProvider.notifier).setSearchQuery(v),
        style: GoogleFonts.inter(fontSize: 13, color: isDark ? Colors.white : const Color(0xFF0F172A)),
        decoration: InputDecoration(
          hintText: 'Search customer name, phone...',
          hintStyle: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8)),
          prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFF94A3B8)),
          filled: true,
          fillColor: isDark ? const Color(0xFF151D36) : Colors.white,
          contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 10),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: isDark ? const Color(0xFF2E3D6B) : const Color(0xFFE2E8F0)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: isDark ? const Color(0xFF2E3D6B) : const Color(0xFFE2E8F0)),
          ),
        ),
      ),
    );

    final filterTabs = SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildTabFilter(ref, 'all', 'All Leads (${state.leads.length})', state.selectedLeadStatusFilter, isDark),
          const SizedBox(width: 8),
          _buildTabFilter(ref, 'new_lead', 'New (${state.newLeadsCount})', state.selectedLeadStatusFilter, isDark),
          const SizedBox(width: 8),
          _buildTabFilter(ref, 'calling', 'In Progress (${state.callingLeadsCount})', state.selectedLeadStatusFilter, isDark),
          const SizedBox(width: 8),
          _buildTabFilter(ref, 'confirmed', 'Confirmed (${state.confirmedLeadsCount})', state.selectedLeadStatusFilter, isDark),
          const SizedBox(width: 8),
          _buildTabFilter(ref, 'order_created', 'Orders Created (${state.orderCreatedLeadsCount})', state.selectedLeadStatusFilter, isDark),
        ],
      ),
    );

    if (isCompact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          searchField,
          const SizedBox(height: 10),
          filterTabs,
        ],
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(child: filterTabs),
        const SizedBox(width: 16),
        SizedBox(width: 240, child: searchField),
      ],
    );
  }

  Widget _buildTabFilter(
    WidgetRef ref,
    String status,
    String label,
    String currentStatus,
    bool isDark,
  ) {
    final isSelected = currentStatus == status;
    return InkWell(
      onTap: () => ref.read(clientPortalProvider.notifier).setLeadStatusFilter(status),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFF37021)
              : (isDark ? const Color(0xFF151D36) : Colors.white),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? const Color(0xFFF37021)
                : (isDark ? const Color(0xFF2E3D6B) : const Color(0xFFE2E8F0)),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected
                ? Colors.white
                : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569)),
          ),
        ),
      ),
    );
  }

  Widget _buildLeadCard(
    BuildContext context,
    WidgetRef ref,
    CustomerLead lead,
    NumberFormat formatter,
    bool isDark,
  ) {
    Color statusColor;
    String statusLabel;
    switch (lead.status) {
      case 'new_lead':
        statusColor = const Color(0xFF3B82F6);
        statusLabel = 'NEW LEAD';
        break;
      case 'calling':
        statusColor = const Color(0xFFF59E0B);
        statusLabel = 'IN PROGRESS';
        break;
      case 'call_back':
        statusColor = const Color(0xFF8B5CF6);
        statusLabel = 'CALL BACK';
        break;
      case 'confirmed':
        statusColor = const Color(0xFF10B981);
        statusLabel = 'CONFIRMED';
        break;
      case 'order_created':
        statusColor = const Color(0xFF059669);
        statusLabel = 'ORDER ROUTED';
        break;
      default:
        statusColor = const Color(0xFF64748B);
        statusLabel = lead.status.toUpperCase();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF151D36) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF2E3D6B) : const Color(0xFFE2E8F0),
        ),
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
          // Top Row: Name, Status & Location
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFF37021).withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.person_rounded, color: Color(0xFFF37021), size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lead.customerName,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${lead.deliveryLga}, ${lead.deliveryState}',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  statusLabel,
                  style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: statusColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Details Ribbon: Product Deal & Address
          Builder(
            builder: (context) {
              final catalog = ref.watch(productCatalogProvider);
              final matchedProd = catalog.findProductByName(lead.productInterest);

              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0B1021) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isDark ? const Color(0xFF1E294A) : const Color(0xFFF1F5F9),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        ProductImageWidget(
                          imageUrl: matchedProd?.imageUrl,
                          width: 26,
                          height: 26,
                          borderRadius: 6,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${lead.productInterest} (${lead.packageInterest})',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : const Color(0xFF334155),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    if (lead.customerAddress.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.place_outlined, size: 14, color: Color(0xFF94A3B8)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              lead.customerAddress,
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              );
            },
          ),

          if (lead.callNotes != null && lead.callNotes!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Call Notes: "${lead.callNotes}"',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontStyle: FontStyle.italic,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 14),

          // Action Toolbar: Responsive Wrap for Mobile/Tablet/Desktop
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // Phone Call
              OutlinedButton.icon(
                onPressed: () async {
                  ref.read(clientPortalProvider.notifier).updateLeadStatus(lead.id, 'calling');
                  final uri = Uri.parse('tel:${lead.customerPhone}');
                  if (await canLaunchUrl(uri)) await launchUrl(uri);
                },
                icon: const Icon(Icons.phone_in_talk_rounded, size: 15, color: Color(0xFF2563EB)),
                label: Text(
                  lead.customerPhone,
                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF2563EB)),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFFBFDBFE)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                ),
              ),

              // WhatsApp
              OutlinedButton.icon(
                onPressed: () async {
                  final cleanPhone = lead.customerPhone.replaceAll(RegExp(r'[^\d]'), '');
                  final waPhone = cleanPhone.startsWith('0') ? '234${cleanPhone.substring(1)}' : cleanPhone;
                  final uri = Uri.parse('https://wa.me/$waPhone?text=Hello%20${Uri.encodeComponent(lead.customerName)},%20regarding%20your%20order%20for%20${Uri.encodeComponent(lead.productInterest)}');
                  if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
                },
                icon: const Icon(Icons.chat_rounded, size: 15, color: Color(0xFF10B981)),
                label: Text(
                  'WhatsApp',
                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF10B981)),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFFA7F3D0)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                ),
              ),

              // Status Dropdown
              if (!lead.isOrderCreated)
                PopupMenuButton<String>(
                  tooltip: 'Update Call Status',
                  onSelected: (val) => ref.read(clientPortalProvider.notifier).updateLeadStatus(lead.id, val),
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(value: 'new_lead', child: Text('New Lead')),
                    const PopupMenuItem(value: 'calling', child: Text('In Progress (Calling)')),
                    const PopupMenuItem(value: 'call_back', child: Text('Call Back Requested')),
                    const PopupMenuItem(value: 'confirmed', child: Text('Confirmed')),
                    const PopupMenuItem(value: 'rejected', child: Text('Rejected / Not Interested')),
                  ],
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0B1021) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isDark ? const Color(0xFF2E3D6B) : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.edit_note_rounded,
                          size: 15,
                          color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Status',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // Convert to Order / Dispatched Pill
              if (lead.isOrderCreated)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 15),
                      const SizedBox(width: 6),
                      Text(
                        'Order Dispatched',
                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF10B981)),
                      ),
                    ],
                  ),
                )
              else
                ElevatedButton.icon(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => ClientConvertLeadModal(lead: lead),
                    );
                  },
                  icon: const Icon(Icons.flash_on_rounded, size: 15, color: Colors.white),
                  label: Text(
                    'Convert to Order',
                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
