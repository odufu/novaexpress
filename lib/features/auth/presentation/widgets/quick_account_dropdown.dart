import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class QuickAccountOption {
  final String roleKey;
  final String title;
  final String personName;
  final String badge;
  final String email;
  final String password;
  final IconData icon;
  final Color themeColor;
  final bool isSecondary;

  const QuickAccountOption({
    required this.roleKey,
    required this.title,
    required this.personName,
    required this.badge,
    required this.email,
    required this.password,
    required this.icon,
    required this.themeColor,
    this.isSecondary = false,
  });
}

class QuickAccountDropdown extends StatefulWidget {
  final String? selectedRoleKey;
  final ValueChanged<QuickAccountOption> onAccountSelected;
  final void Function(QuickAccountOption)? onInstantLogin;

  const QuickAccountDropdown({
    super.key,
    required this.selectedRoleKey,
    required this.onAccountSelected,
    this.onInstantLogin,
  });

  static const List<QuickAccountOption> primaryAccounts = [
    QuickAccountOption(
      roleKey: 'dc_manager',
      title: 'Grand DC Operations Supervisor',
      personName: 'Ahmed Bello',
      badge: 'Grand Console (HQ)',
      email: 'dc.supervisor@novaxpress.ng',
      password: 'Password123!',
      icon: Icons.warehouse_rounded,
      themeColor: Color(0xFF1E3A8A),
    ),
  ];

  static const List<QuickAccountOption> secondaryAccounts = [
    QuickAccountOption(
      roleKey: 'sales_supervisor',
      title: 'Merchant Sales Rep Supervisor',
      personName: 'Joel Supervisor (Novacare)',
      badge: 'Supervisor (/sales-supervisor)',
      email: 'joelsupervisor@novaxpress.ng',
      password: 'joelsupervisor@novaxpress.ng',
      icon: Icons.verified_user_rounded,
      themeColor: Color(0xFFF37021),
      isSecondary: true,
    ),
    QuickAccountOption(
      roleKey: 'dc_finance_admin',
      title: 'DC Finance & Remittances Officer',
      personName: 'Joel Finance',
      badge: 'Finance (/finance-ops)',
      email: 'joelfinance@gmail.com',
      password: 'joelfinance@gmail.com',
      icon: Icons.account_balance_wallet_rounded,
      themeColor: Color(0xFFD97706),
      isSecondary: true,
    ),
    QuickAccountOption(
      roleKey: 'dc_stock_admin',
      title: 'DC Stock & Inventory Officer',
      personName: 'Joel Stock',
      badge: 'Stock (/stock-ops)',
      email: 'joelstock@novaxpress.ng',
      password: 'joelstock@novaxpress.ng',
      icon: Icons.inventory_2_rounded,
      themeColor: Color(0xFF0284C7),
      isSecondary: true,
    ),
    QuickAccountOption(
      roleKey: 'general_accountant',
      title: 'National General Accountant',
      personName: 'Joel Account',
      badge: 'Accountant (/accountant)',
      email: 'joelaccount@gmail.com',
      password: 'joelaccount@gmail.com',
      icon: Icons.account_balance_rounded,
      themeColor: Color(0xFF7C3AED),
      isSecondary: true,
    ),
    QuickAccountOption(
      roleKey: 'client',
      title: 'Novacare Merchant Partner',
      personName: 'Joel Odufu / Novacare',
      badge: 'Merchant Portal',
      email: 'novacare@novaxpress.net',
      password: 'novacare@novaxpress.net',
      icon: Icons.storefront_rounded,
      themeColor: Color(0xFFD97706),
      isSecondary: true,
    ),
    QuickAccountOption(
      roleKey: 'closer',
      title: 'Head Sales Closer (Shorp 11)',
      personName: 'Prestige Godwin Uto',
      badge: 'Telesales',
      email: 'prestige.godwin@novaxpress.net',
      password: 'Closer123!',
      icon: Icons.headset_mic_rounded,
      themeColor: Color(0xFF4F46E5),
      isSecondary: true,
    ),
    QuickAccountOption(
      roleKey: 'dc_operations',
      title: 'DC Dispatch Operations Officer',
      personName: 'Abigail Kooyon',
      badge: 'Station Ops',
      email: 'abigail.kooyon@novaxpress.net',
      password: 'CDV8pRxC#b',
      icon: Icons.alt_route_rounded,
      themeColor: Color(0xFF059669),
      isSecondary: true,
    ),
    QuickAccountOption(
      roleKey: 'delivery_agent',
      title: 'Fleet Delivery Courier / Rider',
      personName: 'Oladele Omowaye',
      badge: 'Field Courier',
      email: 'oladele.omowaye@novaxpress.ng',
      password: 'omowaye123456',
      icon: Icons.two_wheeler_rounded,
      themeColor: Color(0xFF7C3AED),
      isSecondary: true,
    ),
  ];

  static List<QuickAccountOption> get allAccounts => [
        ...primaryAccounts,
        ...secondaryAccounts,
      ];

  @override
  State<QuickAccountDropdown> createState() => _QuickAccountDropdownState();
}

class _QuickAccountDropdownState extends State<QuickAccountDropdown> with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  late AnimationController _animController;
  late Animation<double> _expandAnimation;
  late Animation<double> _chevronAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _expandAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.fastOutSlowIn,
    );
    _chevronAnimation = Tween<double>(begin: 0.0, end: 0.5).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _toggleDropdown() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _animController.forward();
      } else {
        _animController.reverse();
      }
    });
  }

  void _selectAccount(QuickAccountOption acc) {
    widget.onAccountSelected(acc);
    setState(() {
      _isExpanded = false;
      _animController.reverse();
    });
  }

  @override
  Widget build(BuildContext context) {
    final allAccs = QuickAccountDropdown.allAccounts;
    final selectedAcc = allAccs.where((a) => a.roleKey == widget.selectedRoleKey).firstOrNull ??
        QuickAccountDropdown.primaryAccounts.first;

    final themeColor = selectedAcc.themeColor;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _isExpanded ? themeColor.withValues(alpha: 0.6) : const Color(0xFFE2E8F0),
          width: _isExpanded ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: _isExpanded ? themeColor.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.02),
            blurRadius: _isExpanded ? 12 : 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header & Trigger Bar
          InkWell(
            onTap: _toggleDropdown,
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Label Bar
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(3.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEA580C).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: const Icon(Icons.flash_on_rounded, size: 12, color: Color(0xFFEA580C)),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'QUICK ACCOUNT SELECTOR',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                            color: const Color(0xFF64748B),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: _isExpanded ? themeColor.withValues(alpha: 0.12) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          _isExpanded ? 'Tap to Close' : 'Switch Role',
                          style: GoogleFonts.inter(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                            color: _isExpanded ? themeColor : const Color(0xFF64748B),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Selected Account Representation
                  Row(
                    children: [
                      // Role Icon Container
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: themeColor.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: themeColor.withValues(alpha: 0.25),
                            width: 1,
                          ),
                        ),
                        child: Icon(selectedAcc.icon, size: 18, color: themeColor),
                      ),
                      const SizedBox(width: 10),

                      // Account Details
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Wrap(
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 6,
                              runSpacing: 2,
                              children: [
                                Text(
                                  selectedAcc.title,
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF0F172A),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: themeColor.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    selectedAcc.badge,
                                    style: GoogleFonts.inter(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                      color: themeColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${selectedAcc.personName} • ${selectedAcc.email}',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: const Color(0xFF64748B),
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),

                      // Animated Chevron
                      RotationTransition(
                        turns: _chevronAnimation,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            shape: BoxShape.circle,
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: const Icon(
                            Icons.keyboard_arrow_down_rounded,
                            size: 18,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Animated Expanded Dropdown Panel
          SizeTransition(
            sizeFactor: _expandAnimation,
            axisAlignment: -1.0,
            child: Container(
              decoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(color: Color(0xFFF1F5F9), width: 1.2),
                ),
                color: Color(0xFFFAFAFA),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(13)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Section: Primary Roles
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 6, top: 2),
                    child: Text(
                      'PRIMARY OPERATIONAL ROLES',
                      style: GoogleFonts.inter(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.4,
                        color: const Color(0xFF94A3B8),
                      ),
                    ),
                  ),
                  ...QuickAccountDropdown.primaryAccounts.map((acc) {
                    final isCurrent = acc.roleKey == selectedAcc.roleKey;
                    return _buildAccountItem(acc, isCurrent);
                  }),

                  const SizedBox(height: 6),
                  const Divider(height: 1, color: Color(0xFFE2E8F0)),
                  const SizedBox(height: 6),

                  // Section: Alternate Test Accounts
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 6),
                    child: Text(
                      'ALTERNATE DEMO ACCOUNTS',
                      style: GoogleFonts.inter(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.4,
                        color: const Color(0xFF94A3B8),
                      ),
                    ),
                  ),
                  ...QuickAccountDropdown.secondaryAccounts.map((acc) {
                    final isCurrent = acc.roleKey == selectedAcc.roleKey;
                    return _buildAccountItem(acc, isCurrent);
                  }),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountItem(QuickAccountOption acc, bool isSelected) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: isSelected ? acc.themeColor.withValues(alpha: 0.08) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: () => _selectAccount(acc),
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected ? acc.themeColor : const Color(0xFFE2E8F0),
                width: isSelected ? 1.4 : 0.8,
              ),
            ),
            child: Row(
              children: [
                // Icon
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: acc.themeColor.withValues(alpha: isSelected ? 0.2 : 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(acc.icon, size: 15, color: acc.themeColor),
                ),
                const SizedBox(width: 10),

                // Name & Email
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 6,
                        runSpacing: 2,
                        children: [
                          Text(
                            acc.title,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w700,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: acc.themeColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              acc.badge,
                              style: GoogleFonts.inter(
                                fontSize: 8.5,
                                fontWeight: FontWeight.bold,
                                color: acc.themeColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 1),
                      Text(
                        '${acc.personName} • ${acc.email}',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          color: const Color(0xFF64748B),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 6),
                // Indicator
                Icon(
                  isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                  color: isSelected ? acc.themeColor : const Color(0xFFCBD5E1),
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
