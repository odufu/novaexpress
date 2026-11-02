p1 = """import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../../../core/widgets/user_avatar_widget.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../dc_console/presentation/widgets/dc_staff_profile_settings_tab.dart';
import '../../../orders/domain/entities/order.dart';
import '../../domain/entities/client_closer.dart';
import '../../domain/entities/customer_lead.dart';
import '../../domain/entities/upg_request.dart';
import '../providers/client_portal_provider.dart';
import '../providers/sales_supervisor_provider.dart';
import '../widgets/client_convert_lead_modal.dart';
import '../widgets/client_order_tracking_modal.dart';
import '../widgets/request_upg_modal.dart';
import '../widgets/supervisee_detail_modal.dart';

class MerchantSalesSupervisorPage extends ConsumerStatefulWidget {
  const MerchantSalesSupervisorPage({super.key});

  @override
  ConsumerState<MerchantSalesSupervisorPage> createState() =>
      _MerchantSalesSupervisorPageState();
}

class _MerchantSalesSupervisorPageState
    extends ConsumerState<MerchantSalesSupervisorPage> {
  final _currency = NumberFormat.currency(symbol: '₦', decimalDigits: 0);
  int _activeTab = 0; // 0: UPG Queue, 1: Leaderboard, 2: My Sales Desk, 3: Profile
  String _leadStatusFilter = 'all';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  void _loadData() {
    final user = ref.read(authProvider).user;
    final clientId = user?.clientId;
    ref.read(salesSupervisorProvider.notifier).loadSupervisorData(clientId: clientId);
    ref.read(clientPortalProvider.notifier).loadClientData();
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeProvider);
    final isDark = themeMode == ThemeMode.dark ||
        (themeMode == ThemeMode.system &&
            MediaQuery.of(context).platformBrightness == Brightness.dark);

    final supervisorState = ref.watch(salesSupervisorProvider);
    final user = ref.watch(authProvider).user;
    final pendingUpgCount = supervisorState.pendingUpgRequests.length;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B132B) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
        elevation: 0.5,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sales Rep Supervisor Console',
              style: GoogleFonts.inter(fontSize: 16.5, fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              '${user?.clientCompanyName ?? \"Merchant Hub\"} • Telesales & UPG Operations',
              style: GoogleFonts.inter(
                fontSize: 11,
                color: const Color(0xFFF37021),
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh Operations',
            icon: const Icon(Icons.refresh_rounded, size: 21),
            onPressed: _loadData,
          ),
          const SizedBox(width: 4),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F172A) : Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
              blurRadius: 14,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: BottomNavigationBar(
            currentIndex: _activeTab,
            onTap: (index) => setState(() => _activeTab = index),
            backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
            selectedItemColor: const Color(0xFFF37021),
            unselectedItemColor: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
            type: BottomNavigationBarType.fixed,
            selectedLabelStyle: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.bold),
            unselectedLabelStyle: GoogleFonts.inter(fontSize: 10.5),
            items: [
              BottomNavigationBarItem(
                icon: Badge(
                  isLabelVisible: pendingUpgCount > 0,
                  label: Text('$pendingUpgCount'),
                  backgroundColor: const Color(0xFFF37021),
                  child: const Icon(Icons.verified_user_rounded),
                ),
                label: 'UPG Queue',
              ),
              BottomNavigationBarItem(
                icon: Badge(
                  isLabelVisible: supervisorState.closers.isNotEmpty,
                  label: Text('${supervisorState.closers.length}'),
                  backgroundColor: const Color(0xFF2563EB),
                  child: const Icon(Icons.leaderboard_rounded),
                ),
                label: 'Leaderboard',
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.headset_mic_rounded),
                label: 'Sales Desk',
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.person_outline_rounded),
                label: 'Profile',
              ),
            ],
          ),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Column(
            children: [
              if (_activeTab != 3)
                _buildKpiGrid(supervisorState, isDark),
              Expanded(
                child: _buildActiveTabBody(supervisorState, isDark),
              ),
            ],
          ),
        ),
      ),
    );
  }
"""
with open("lib/features/client_portal/presentation/pages/merchant_sales_supervisor_page.dart", "w", encoding="utf-8") as f:
    f.write(p1)
print("Part 1 written")
