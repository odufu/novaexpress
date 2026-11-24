import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_theme.dart';
import '../providers/auth_provider.dart';

final loginObscurePasswordProvider = StateProvider.autoDispose<bool>((ref) => true);
final loginRememberMeProvider = StateProvider.autoDispose<bool>((ref) => true);

class _DevAccountOption {
  final String name;
  final String code;
  final String roleBadge;
  final String email;
  final String password;
  final String portalRoute;
  final IconData icon;
  final Color roleColor;
  final String category;

  const _DevAccountOption({
    required this.name,
    required this.code,
    required this.roleBadge,
    required this.email,
    required this.password,
    required this.portalRoute,
    required this.icon,
    required this.roleColor,
    required this.category,
  });
}

const List<_DevAccountOption> _devTestAccounts = [
  // ==========================================
  // UNIT 1: NovaXpress Warehousing
  // 1. General Admin
  // 2. DC/Warehouse Admin
  // 3. Stock Ops / Inventory Manager
  // 4. Agents / External Logistics
  // ==========================================
  _DevAccountOption(
    name: 'Joel Emerald (General Admin)',
    code: 'ADMIN-HQ-01',
    roleBadge: 'GENERAL ADMIN',
    email: 'emeraldcodelines@gmail.com',
    password: '@EmeraldXpress2026',
    portalRoute: '/admin (Warehousing General Governance & Hubs)',
    icon: Icons.admin_panel_settings_rounded,
    roleColor: Color(0xFFE11D48),
    category: 'Unit 1: Warehousing',
  ),
  _DevAccountOption(
    name: 'Balikis Popoola (Super Admin)',
    code: 'ADMIN-HQ-03',
    roleBadge: 'SUPER ADMIN',
    email: 'popoolabalikis37@gmail.com',
    password: '302382',
    portalRoute: '/admin (Warehousing General Governance & Hubs)',
    icon: Icons.admin_panel_settings_rounded,
    roleColor: Color(0xFFE11D48),
    category: 'Unit 1: Warehousing',
  ),
  _DevAccountOption(
    name: 'Damilare Ajani (Super Admin & Master Stock Controller)',
    code: 'ADMIN-HQ-04',
    roleBadge: 'SUPER ADMIN',
    email: 'damieajani@gmail.com',
    password: 'Password123!',
    portalRoute: '/agent-daily-sales (Holistic Daily Sales & Multi-Merchant Stock)',
    icon: Icons.inventory_2_rounded,
    roleColor: Color(0xFFE11D48),
    category: 'Unit 1: Warehousing',
  ),
  _DevAccountOption(
    name: 'NovaXpress Warehouses Admin',
    code: 'NX-ADM-01',
    roleBadge: 'WAREHOUSE ADMIN',
    email: 'admin@novaxpress.ng',
    password: 'AdminPass123!',
    portalRoute: '/admin (Multi-hub Inventory & Agent Approvals)',
    icon: Icons.security_rounded,
    roleColor: Color(0xFFBE123C),
    category: 'Unit 1: Warehousing',
  ),
  _DevAccountOption(
    name: 'Ahmed Bello (DC/Warehouse Admin)',
    code: 'DC-MGR-WUSE-01',
    roleBadge: 'DC ADMIN',
    email: 'dc.supervisor@novaxpress.ng',
    password: 'Password123!',
    portalRoute: '/dc (Central Command DC & Regional Hubs)',
    icon: Icons.apartment_rounded,
    roleColor: Color(0xFF1E3A8A),
    category: 'Unit 1: Warehousing',
  ),
  _DevAccountOption(
    name: 'Joel Stock (Stock Ops & Inventory)',
    code: 'STK-WUSE-01',
    roleBadge: 'STOCK OPS',
    email: 'joelstock@novaxpress.ng',
    password: 'joelstock@novaxpress.ng',
    portalRoute: '/stock-ops (DC Warehouse Shelves & Custody)',
    icon: Icons.inventory_2_rounded,
    roleColor: Color(0xFF0284C7),
    category: 'Unit 1: Warehousing',
  ),
  _DevAccountOption(
    name: 'Ani Willis Ami (DC Stock Ops)',
    code: 'STK-ABJ-02',
    roleBadge: 'STOCK OPS',
    email: 'aniwillisami22@gmail.com',
    password: 'password@123',
    portalRoute: '/stock-ops (DC Warehouse Shelves & Custody)',
    icon: Icons.inventory_2_rounded,
    roleColor: Color(0xFF0284C7),
    category: 'Unit 1: Warehousing',
  ),
  _DevAccountOption(
    name: 'GIG Logistics (3PL Agent Consumer)',
    code: '3PL-GIG-01',
    roleBadge: '3PL AGENT',
    email: 'gig.operations@novaxpress.ng',
    password: 'Password123!',
    portalRoute: '/logistics-partner (3PL Agent Console)',
    icon: Icons.alt_route_rounded,
    roleColor: Color(0xFF8B5CF6),
    category: 'Unit 1: Warehousing',
  ),
  _DevAccountOption(
    name: 'Speedaf Express (3PL Agent Consumer)',
    code: '3PL-SPD-02',
    roleBadge: '3PL AGENT',
    email: 'speedaf.operations@novaxpress.ng',
    password: 'Password123!',
    portalRoute: '/logistics-partner (3PL Delivery Console)',
    icon: Icons.share_location_rounded,
    roleColor: Color(0xFF6366F1),
    category: 'Unit 1: Warehousing',
  ),

  // ==========================================
  // UNIT 2: NovaXpress Logistics
  // 1. Dispatch Ops
  // 2. Finance Ops
  // 3. Accountant
  // 4. Logistics Admin / Fleet Command
  // ==========================================
  _DevAccountOption(
    name: 'Abigail Kooyon (Dispatch Ops)',
    code: 'OPS-CMD-01-159',
    roleBadge: 'DISPATCH OPS',
    email: 'abigail.kooyon@novaxpress.net',
    password: 'CDV8pRxC#b',
    portalRoute: '/ops (WhatsApp Intake & Live Smart Dispatch)',
    icon: Icons.warehouse_rounded,
    roleColor: Color(0xFF059669),
    category: 'Unit 2: Logistics',
  ),
  _DevAccountOption(
    name: 'Joel Finance (Finance Ops & Cashier)',
    code: 'FIN-WUSE-01',
    roleBadge: 'FINANCE OPS',
    email: 'joelfinance@gmail.com',
    password: 'joelfinance@gmail.com',
    portalRoute: '/finance-ops (DC Cash Desk & Remittance Clearance)',
    icon: Icons.account_balance_wallet_rounded,
    roleColor: Color(0xFFD97706),
    category: 'Unit 2: Logistics',
  ),
  _DevAccountOption(
    name: 'Joel Account (Logistics Accountant)',
    code: 'ACC-HQ-01',
    roleBadge: 'ACCOUNTANT',
    email: 'joelaccount@gmail.com',
    password: 'joelaccount@gmail.com',
    portalRoute: '/accountant (Logistics Station Reconciliation)',
    icon: Icons.account_balance_rounded,
    roleColor: Color(0xFF7C3AED),
    category: 'Unit 2: Logistics',
  ),
  _DevAccountOption(
    name: 'NovaXpress Logistics Admin',
    code: 'NX-LOG-01',
    roleBadge: 'LOGISTICS ADMIN',
    email: 'logistics.admin@novaxpress.ng',
    password: 'LogisticsAdmin123!',
    portalRoute: '/logistics-admin (Fleet Command, Custody & WhatsApp)',
    icon: Icons.local_shipping_rounded,
    roleColor: Color(0xFFF97316),
    category: 'Unit 2: Logistics',
  ),
  _DevAccountOption(
    name: 'Simon Tazha (Field Courier)',
    code: 'RDR-682',
    roleBadge: 'FIELD RIDER',
    email: 'simon.tazha@novaxpress.ng',
    password: 'SimonPass123!',
    portalRoute: '/ (Rider PDA • PIN: 1234)',
    icon: Icons.two_wheeler_rounded,
    roleColor: Color(0xFF7C3AED),
    category: 'Unit 2: Logistics',
  ),
  _DevAccountOption(
    name: 'Oladele Omowaye (Field Courier)',
    code: 'RDR-501',
    roleBadge: 'FIELD RIDER',
    email: 'oladele.omowaye@novaxpress.ng',
    password: 'omowaye123456',
    portalRoute: '/ (Rider PDA • PIN: 1234)',
    icon: Icons.two_wheeler_rounded,
    roleColor: Color(0xFF7C3AED),
    category: 'Unit 2: Logistics',
  ),
  _DevAccountOption(
    name: 'Uche Okafor (Field Courier)',
    code: 'RDR-502',
    roleBadge: 'FIELD RIDER',
    email: 'uche.okafor@novaxpress.ng',
    password: 'RiderPass123!',
    portalRoute: '/ (Rider PDA • PIN: 1234)',
    icon: Icons.two_wheeler_rounded,
    roleColor: Color(0xFF7C3AED),
    category: 'Unit 2: Logistics',
  ),

  // ==========================================
  // UNIT 3: Merchants
  // 1. Admin
  // 2. List of their agents they are using
  // 3. Finance (for remittance)
  // 4. Accountant
  // ==========================================
  _DevAccountOption(
    name: 'Novacare Merchant Admin',
    code: 'CLIENT-NOVACARE',
    roleBadge: 'MERCHANT ADMIN',
    email: 'novacare@novaxpress.net',
    password: 'novacare@novaxpress.net',
    portalRoute: '/client (Novacare Multi-Hub Stock & Agents)',
    icon: Icons.storefront_rounded,
    roleColor: Color(0xFFD97706),
    category: 'Unit 3: Merchants',
  ),
  _DevAccountOption(
    name: 'Shop11 Merchant Admin',
    code: 'CLIENT-SHOP11',
    roleBadge: 'MERCHANT ADMIN',
    email: 'shop11@novaxpress.net',
    password: 'Shop11Pass123!',
    portalRoute: '/client (Shop11 Multi-Hub Stock & Agents)',
    icon: Icons.shopping_bag_rounded,
    roleColor: Color(0xFFEA580C),
    category: 'Unit 3: Merchants',
  ),
  _DevAccountOption(
    name: 'Joel Supervisor (Merchant Sales Rep Lead)',
    code: 'SUP-SALES-01',
    roleBadge: 'SALES SUP',
    email: 'joelsupervisor@novaxpress.ng',
    password: 'joelsupervisor@novaxpress.ng',
    portalRoute: '/sales-supervisor (Merchant Closers Supervisor)',
    icon: Icons.verified_user_rounded,
    roleColor: Color(0xFFF37021),
    category: 'Unit 3: Merchants',
  ),
  _DevAccountOption(
    name: 'Prestige Godwin Uto (Head Closer)',
    code: 'CLS-NOVA-106',
    roleBadge: 'CLOSER AGENT',
    email: 'prestige.godwin@novaxpress.net',
    password: 'Closer123!',
    portalRoute: '/closer (Shorp 11 Telesales)',
    icon: Icons.headset_mic_rounded,
    roleColor: Color(0xFF4F46E5),
    category: 'Unit 3: Merchants',
  ),
  _DevAccountOption(
    name: 'Ojo Modupeolami (Closer Agent)',
    code: 'CLS-NOVA-103',
    roleBadge: 'CLOSER AGENT',
    email: 'ojo.modupeolami@novaxpress.ng',
    password: 'ojo.modupeolami@novaxpress.ng',
    portalRoute: '/closer (Telesales Portal)',
    icon: Icons.headset_mic_rounded,
    roleColor: Color(0xFF4F46E5),
    category: 'Unit 3: Merchants',
  ),
  _DevAccountOption(
    name: 'Adewole Ibukun (Closer Agent)',
    code: 'CLS-NOVA-104',
    roleBadge: 'CLOSER AGENT',
    email: 'adewole.ibukun@novaxpress.ng',
    password: 'Closer123!',
    portalRoute: '/closer (Telesales Portal)',
    icon: Icons.headset_mic_rounded,
    roleColor: Color(0xFF4F46E5),
    category: 'Unit 3: Merchants',
  ),
  _DevAccountOption(
    name: 'Chioma Marketer (Merchant Marketing)',
    code: 'MKT-NOVA-01',
    roleBadge: 'MARKETER',
    email: 'chioma.marketing@novaxpress.ng',
    password: 'Marketing123!',
    portalRoute: '/marketer (Leads & Campaigns)',
    icon: Icons.campaign_rounded,
    roleColor: Color(0xFF0284C7),
    category: 'Unit 3: Merchants',
  ),
  _DevAccountOption(
    name: 'Samuel Accountant (Merchant Accountant)',
    code: 'ACC-NOVA-001',
    roleBadge: 'MERCHANT ACC',
    email: 'accountant@novacare.com',
    password: 'Password123!',
    portalRoute: '/merchant-settlements (Settlements & 10PM Remittances)',
    icon: Icons.receipt_long_rounded,
    roleColor: Color(0xFF0D9488),
    category: 'Unit 3: Merchants',
  ),
  _DevAccountOption(
    name: 'Amaka Obi (Novacare Stock Keeper)',
    code: 'STK-NOVACARE-01',
    roleBadge: 'STOCK KEEPER',
    email: 'inventory@novacare.com',
    password: 'Password123!',
    portalRoute: '/merchant-inventory (Inbounds, QC Inspection & Agent Daily Sales)',
    icon: Icons.inventory_rounded,
    roleColor: Color(0xFF0284C7),
    category: 'Unit 3: Merchants',
  ),
  _DevAccountOption(
    name: 'Tari Ebi (Shop Eleven Stock Keeper)',
    code: 'STK-SHOP11-01',
    roleBadge: 'STOCK KEEPER',
    email: 'shop11.stock@novaxpress.net',
    password: 'Password123!',
    portalRoute: '/merchant-inventory (Shop Eleven Inbounds & Agent Balancing)',
    icon: Icons.inventory_rounded,
    roleColor: Color(0xFF0284C7),
    category: 'Unit 3: Merchants',
  ),
  _DevAccountOption(
    name: 'Folashade Ade (Leafora Essence Admin)',
    code: 'CLIENT-LEAFORA',
    roleBadge: 'MERCHANT ADMIN',
    email: 'leafora@novaxpress.net',
    password: 'Password123!',
    portalRoute: '/client (Leafora Essence Multi-Hub Stock & Agents)',
    icon: Icons.spa_rounded,
    roleColor: Color(0xFF10B981),
    category: 'Unit 3: Merchants',
  ),
  _DevAccountOption(
    name: 'Babatunde Adeleke (Lagos DC Hub Head)',
    code: 'DC-MGR-LAG-01',
    roleBadge: 'DC HUB HEAD',
    email: 'lagos.ops@novaxpress.ng',
    password: 'Password123!',
    portalRoute: '/dc (Lagos Central DC • Ikeja Hub)',
    icon: Icons.apartment_rounded,
    roleColor: Color(0xFF1E3A8A),
    category: 'Unit 1: Warehousing',
  ),
  _DevAccountOption(
    name: 'Emeka Nwosu (Lagos DC Stock Admin)',
    code: 'STK-LAG-01',
    roleBadge: 'DC STOCK OPS',
    email: 'stock.master@novaxpress.ng',
    password: 'Password123!',
    portalRoute: '/stock-ops (Lagos DC Shelves & Custody)',
    icon: Icons.inventory_2_rounded,
    roleColor: Color(0xFF0284C7),
    category: 'Unit 1: Warehousing',
  ),
  _DevAccountOption(
    name: 'Fatima Garba (Lagos DC Finance Officer)',
    code: 'FIN-LAG-01',
    roleBadge: 'DC CASHIER',
    email: 'remittance@novaxpress.ng',
    password: 'Password123!',
    portalRoute: '/dc-finance (Lagos DC Cash Remittance)',
    icon: Icons.payments_rounded,
    roleColor: Color(0xFF059669),
    category: 'Unit 2: Logistics',
  ),
  _DevAccountOption(
    name: 'NovaXpress Fleet (Internal Logistics)',
    code: 'NX-ABJ-01',
    roleBadge: 'INTERNAL FLEET',
    email: 'logistics@novaxpress.ng',
    password: 'Password123!',
    portalRoute: '/logistics-partner (NovaXpress Internal Fleet)',
    icon: Icons.local_shipping_rounded,
    roleColor: Color(0xFFF97316),
    category: 'Unit 2: Logistics',
  ),
];

class LoginForm extends ConsumerStatefulWidget {
  const LoginForm({super.key});

  @override
  ConsumerState<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends ConsumerState<LoginForm> {
  final _formKey = GlobalKey<FormState>();
  final _agentIdController = TextEditingController();
  final _passwordController = TextEditingController();
  _DevAccountOption? _selectedDevAccount;
  String _selectedDevCategory = 'All';

  /// Set to true to show Dev Pilot Fast-Login Dropdown during active development.
  /// Set to false for live production builds (app.novaxpressng.com).
  static const bool _enableDevPilotAccountSelector = false;

  static const List<String> _devCategories = [
    'All',
    'Unit 1: Warehousing',
    'Unit 2: Logistics',
    'Unit 3: Merchants',
  ];

  @override
  void dispose() {
    _agentIdController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _selectDevAccount(_DevAccountOption account) {
    setState(() {
      _selectedDevAccount = account;
      _agentIdController.text = account.email;
      _passwordController.text = account.password;
    });
  }

  void _clearDevAccount() {
    setState(() {
      _selectedDevAccount = null;
      _agentIdController.clear();
      _passwordController.clear();
    });
  }

  void _submit() async {
    debugPrint('[AUTH_UI] 🚀 Single unified login submitted. Running validation...');
    if (_formKey.currentState!.validate()) {
      final email = _agentIdController.text.trim();
      final password = _passwordController.text;
      final rememberMe = ref.read(loginRememberMeProvider);
      debugPrint('[AUTH_UI] 📝 Form valid. Dispatching login request for: "$email", RememberMe=$rememberMe');

      final success = await ref.read(authProvider.notifier).login(email, password);

      debugPrint('[AUTH_UI] 🎯 authProvider.login() completed -> success: $success');
      if (!success && mounted) {
        return;
      }

      if (success && mounted) {
        final authUser = ref.read(authProvider).user;
        if (authUser == null) return;

        debugPrint(
            '[AUTH_UI] 🔑 User authenticated successfully: "${authUser.email}", Role: "${authUser.role}", Name: "${authUser.fullName}"');

        try {
          final targetRoute = authUser.homeConsoleRoute;
          debugPrint('[AUTH_UI] 🚀 Directing ${authUser.roleDescription} to designated console: $targetRoute');
          context.go(targetRoute);
        } catch (routerErr) {
          debugPrint('[AUTH_UI] ℹ️ Router navigation notice ($routerErr)');
        }
      }
    } else {
      debugPrint('[AUTH_UI] ⚠️ Form validation failed. Missing required fields.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final obscurePassword = ref.watch(loginObscurePasswordProvider);
    final rememberMe = ref.watch(loginRememberMeProvider);

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Development Fast-Login Dropdown (Toggled off for live production cPanel build)
          if (_enableDevPilotAccountSelector) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 20),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _selectedDevAccount != null
                    ? _selectedDevAccount!.roleColor.withValues(alpha: 0.4)
                    : const Color(0xFFE2E8F0),
                width: 1.4,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFFCD34D)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.flash_on_rounded, size: 13, color: Color(0xFFD97706)),
                          const SizedBox(width: 4),
                          Text(
                            'DEV PILOT LOGIN',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF92400E),
                              letterSpacing: 0.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Test Role Selector',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF475569),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (_selectedDevAccount != null)
                      InkWell(
                        onTap: _clearDevAccount,
                        borderRadius: BorderRadius.circular(4),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.close_rounded, size: 13, color: Color(0xFF64748B)),
                              const SizedBox(width: 2),
                              Text(
                                'Clear',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),

                // Category Filter Pills
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _devCategories.map((cat) {
                      final isSelected = _selectedDevCategory == cat;
                      final count = cat == 'All'
                          ? _devTestAccounts.length
                          : _devTestAccounts.where((a) => a.category == cat).length;
                      return Padding(
                        padding: const EdgeInsets.only(right: 6, bottom: 8),
                        child: InkWell(
                          onTap: () {
                            setState(() {
                              _selectedDevCategory = cat;
                            });
                          },
                          borderRadius: BorderRadius.circular(20),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
                            decoration: BoxDecoration(
                              color: isSelected ? const Color(0xFF0F172A) : Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isSelected ? const Color(0xFF0F172A) : const Color(0xFFCBD5E1),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  cat,
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                    color: isSelected ? Colors.white : const Color(0xFF475569),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? Colors.white.withValues(alpha: 0.2)
                                        : const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '$count',
                                    style: GoogleFonts.jetBrainsMono(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.bold,
                                      color: isSelected ? Colors.white : const Color(0xFF64748B),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 4),

                Builder(builder: (context) {
                  final displayedAccounts = _selectedDevCategory == 'All'
                      ? _devTestAccounts
                      : _devTestAccounts.where((a) => a.category == _selectedDevCategory).toList();

                  final effectiveAccount = displayedAccounts.contains(_selectedDevAccount)
                      ? _selectedDevAccount
                      : null;

                  return DropdownButtonFormField<_DevAccountOption>(
                    key: const Key('dev_pilot_account_dropdown'),
                    value: effectiveAccount,
                    isExpanded: true,
                    icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF64748B)),
                    hint: Row(
                      children: [
                        const Icon(Icons.touch_app_outlined, size: 16, color: Color(0xFF94A3B8)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Choose test role to auto-populate...',
                            style: GoogleFonts.inter(
                              fontSize: 12.5,
                              color: const Color(0xFF64748B),
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFF0F172A), width: 1.5),
                      ),
                    ),
                    selectedItemBuilder: (BuildContext context) {
                      return displayedAccounts.map((acc) {
                        return Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: acc.roleColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                acc.roleBadge,
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: acc.roleColor,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${acc.name} (${acc.code})',
                                style: GoogleFonts.inter(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF0F172A),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        );
                      }).toList();
                    },
                    items: displayedAccounts.map((acc) {
                      return DropdownMenuItem<_DevAccountOption>(
                        value: acc,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 15,
                                backgroundColor: acc.roleColor.withValues(alpha: 0.12),
                                child: Icon(acc.icon, size: 16, color: acc.roleColor),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            acc.name,
                                            style: GoogleFonts.inter(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: const Color(0xFF0F172A),
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: acc.roleColor.withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            acc.roleBadge,
                                            style: GoogleFonts.inter(
                                              fontSize: 9.5,
                                              fontWeight: FontWeight.w800,
                                              color: acc.roleColor,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${acc.email} • ${acc.portalRoute}',
                                      style: GoogleFonts.inter(
                                        fontSize: 11,
                                        color: const Color(0xFF64748B),
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                    onChanged: (selected) {
                      if (selected != null) {
                        _selectDevAccount(selected);
                      }
                    },
                  );
                }),
                if (_selectedDevAccount != null) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Filled: ${_selectedDevAccount!.email}',
                          style: GoogleFonts.inter(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF059669),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _selectedDevAccount!.roleColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        onPressed: authState.isLoading ? null : _submit,
                        icon: const Icon(Icons.flash_on_rounded, size: 14),
                        label: Text(
                          'Quick Sign In',
                          style: GoogleFonts.inter(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],

          if (authState.errorMessage != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: AppColors.danger.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded, color: AppColors.danger, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      authState.errorMessage!,
                      style: const TextStyle(color: AppColors.danger, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Email / Agent ID Field
          const Text(
            'Account Email or Agent ID',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13.5,
              color: Color(0xFF181C1E),
            ),
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: _agentIdController,
            style: const TextStyle(color: Color(0xFF181C1E), fontSize: 14),
            decoration: InputDecoration(
              hintText: 'e.g. name@novaxpress.ng or PDA-7000',
              hintStyle: const TextStyle(color: Color(0xFF75777E), fontSize: 13.5),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              prefixIcon: const Icon(Icons.badge_outlined, color: Color(0xFF64748B), size: 20),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.navy, width: 2),
              ),
            ),
            validator: (val) {
              if (val == null || val.trim().isEmpty) return 'Please enter your account email or agent ID';
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Password Field
          const Text(
            'Password',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13.5,
              color: Color(0xFF181C1E),
            ),
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: _passwordController,
            obscureText: obscurePassword,
            style: const TextStyle(color: Color(0xFF181C1E), fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Enter your password',
              hintStyle: const TextStyle(color: Color(0xFF75777E), fontSize: 13.5),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              prefixIcon: const Icon(Icons.lock_outline_rounded, color: Color(0xFF64748B), size: 20),
              suffixIcon: IconButton(
                icon: Icon(
                  obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                  color: const Color(0xFF64748B),
                  size: 20,
                ),
                onPressed: () {
                  ref.read(loginObscurePasswordProvider.notifier).state = !obscurePassword;
                },
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.navy, width: 2),
              ),
            ),
            validator: (val) {
              if (val == null || val.isEmpty) return 'Please enter your password';
              return null;
            },
          ),
          const SizedBox(height: 12),

          // Remember Me & Forgot Password Row
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              InkWell(
                onTap: () {
                  ref.read(loginRememberMeProvider.notifier).state = !rememberMe;
                },
                borderRadius: BorderRadius.circular(4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: Checkbox(
                        value: rememberMe,
                        activeColor: AppColors.orange,
                        side: const BorderSide(color: Color(0xFFCBD5E1), width: 1.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                        onChanged: (val) {
                          ref.read(loginRememberMeProvider.notifier).state = val ?? true;
                        },
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'Remember me',
                      style: TextStyle(
                        color: Color(0xFF475569),
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => context.push('/forgot-password'),
                child: const Text(
                  'Forgot Password?',
                  style: TextStyle(
                    color: AppColors.navy,
                    fontWeight: FontWeight.bold,
                    fontSize: 12.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),

          // Single Unified Sign In Button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F172A),
                foregroundColor: Colors.white,
                elevation: 2,
                shadowColor: const Color(0xFF0F172A).withValues(alpha: 0.3),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: authState.isLoading ? null : _submit,
              child: authState.isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Sign In to Assigned Workspace',
                            style: GoogleFonts.inter(
                              fontSize: 14.5,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.3,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.arrow_forward_rounded, size: 18),
                        ],
                      ),
                    ),
            ),
          ),

          const SizedBox(height: 16),
          Row(
            children: [
              const Expanded(child: Divider(color: Color(0xFFCBD5E1))),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text(
                  'NEW TO NOVAXPRESS?',
                  style: GoogleFonts.inter(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF64748B),
                    letterSpacing: 0.6,
                  ),
                ),
              ),
              const Expanded(child: Divider(color: Color(0xFFCBD5E1))),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: OutlinedButton(
              key: const Key('login_create_account_btn'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white
                    : const Color(0xFF0F172A),
                side: BorderSide(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFF475569)
                      : const Color(0xFFCBD5E1),
                  width: 1.3,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: authState.isLoading
                  ? null
                  : () {
                      final router = GoRouter.maybeOf(context);
                      if (router != null) {
                        router.go('/register');
                      }
                    },
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.person_add_alt_1_rounded, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'Create Account (All Roles)',
                      style: GoogleFonts.inter(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
