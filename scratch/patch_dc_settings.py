import re

file_path = 'lib/features/dc_console/presentation/pages/dc_settings_page.dart'
with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Add _companyAccounts field
target_field = '  late TextEditingController _accountNameController;'
replace_field = '''  late TextEditingController _accountNameController;
  List<CompanyBankAccount> _companyAccounts = [];'''
assert target_field in content, "target_field not found"
content = content.replace(target_field, replace_field, 1)

# 2. In initState, initialize _companyAccounts
target_init = '    _accountNameController = TextEditingController(text: settings.settlementAccountName);'
replace_init = '''    _accountNameController = TextEditingController(text: settings.settlementAccountName);
    _companyAccounts = List<CompanyBankAccount>.from(settings.companyBankAccounts);
    if (_companyAccounts.isEmpty) {
      _companyAccounts.add(CompanyBankAccount(
        id: 'cba-01',
        bankName: settings.settlementBankName,
        accountNumber: settings.settlementAccountNumber,
        accountName: settings.settlementAccountName,
        isDefault: true,
      ));
    }'''
assert target_init in content, "target_init not found"
content = content.replace(target_init, replace_init, 1)

# 3. In _saveSettings, sync and pass companyBankAccounts
target_save = '''          settlementBankName: _bankNameController.text.trim(),
          settlementAccountNumber: _accountNumberController.text.trim(),
          settlementAccountName: _accountNameController.text.trim(),
          autoReconcileWebhooks: draft.autoReconcile,'''

replace_save = '''          settlementBankName: _bankNameController.text.trim(),
          settlementAccountNumber: _accountNumberController.text.trim(),
          settlementAccountName: _accountNameController.text.trim(),
          autoReconcileWebhooks: draft.autoReconcile,
          companyBankAccounts: _companyAccounts,'''
assert target_save in content, "target_save not found"
content = content.replace(target_save, replace_save, 1)

# 4. In _resetDefaults
target_reset = '''      _merchantGracePeriod = true;
    });'''
replace_reset = '''      _merchantGracePeriod = true;
      _companyAccounts = List<CompanyBankAccount>.from(defaults.companyBankAccounts);
    });'''
assert target_reset in content, "target_reset not found"
content = content.replace(target_reset, replace_reset, 1)

# 5. Add dialog and expand _buildSettlementBankTab
target_tab = '''  // ==========================================
  // TAB 4: SETTLEMENT ACCOUNTS
  // ==========================================
  Widget _buildSettlementBankTab(bool isDark, bool isMobile) {
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 4),
      children: [
        Container(
          padding: EdgeInsets.all(isMobile ? 16 : 22),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'DC Corporate Settlement Bank Account',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Designated corporate bank account for Paystack transfers & POS terminal settlements.',
                style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
              ),
              const SizedBox(height: 18),
              _buildStyledCurrencyInput(
                label: 'Receiving Bank Name',
                controller: _bankNameController,
                hint: 'Titan Trust Bank',
                prefix: '',
                isDark: isDark,
              ),
              const SizedBox(height: 12),
              _buildStyledCurrencyInput(
                label: 'Settlement Account Number (NUBAN)',
                controller: _accountNumberController,
                hint: '0098234123',
                prefix: '',
                isDark: isDark,
              ),
              const SizedBox(height: 12),
              _buildStyledCurrencyInput(
                label: 'Account Name',
                controller: _accountNameController,
                hint: 'NovaXpress Logistics Limited',
                prefix: '',
                isDark: isDark,
              ),
            ],
          ),
        ),
      ],
    );
  }'''

replace_tab = '''  void _showAddCompanyAccountDialog(bool isDark) {
    final bankController = TextEditingController();
    final numberController = TextEditingController();
    final nameController = TextEditingController(text: _accountNameController.text.trim().isNotEmpty ? _accountNameController.text.trim() : 'NovaXpress Logistics Limited');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Add Company Receiving Bank',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Riders will be able to display this account to customers when they pay directly to the company at delivery.',
                style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
              ),
              const SizedBox(height: 16),
              _buildStyledCurrencyInput(
                label: 'Bank Name',
                controller: bankController,
                hint: 'e.g. Zenith Bank, GTBank, Moniepoint',
                prefix: '',
                isDark: isDark,
              ),
              const SizedBox(height: 12),
              _buildStyledCurrencyInput(
                label: 'Account Number (10 digits NUBAN)',
                controller: numberController,
                hint: 'e.g. 1029384756',
                prefix: '',
                isDark: isDark,
              ),
              const SizedBox(height: 12),
              _buildStyledCurrencyInput(
                label: 'Account Name',
                controller: nameController,
                hint: 'NovaXpress Logistics Limited',
                prefix: '',
                isDark: isDark,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final bank = bankController.text.trim();
              final num = numberController.text.trim();
              final name = nameController.text.trim();
              if (bank.isEmpty || num.length < 10) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a valid bank name and 10-digit NUBAN account number.')),
                );
                return;
              }
              setState(() {
                _companyAccounts.add(CompanyBankAccount(
                  id: 'cba-${DateTime.now().millisecondsSinceEpoch}',
                  bankName: bank,
                  accountNumber: num,
                  accountName: name.isNotEmpty ? name : 'NovaXpress Logistics Limited',
                  isDefault: _companyAccounts.isEmpty,
                ));
              });
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Added $bank ($num) to company accounts.')),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00522A),
              foregroundColor: Colors.white,
            ),
            child: const Text('Add Account'),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 4: SETTLEMENT ACCOUNTS
  // ==========================================
  Widget _buildSettlementBankTab(bool isDark, bool isMobile) {
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 4),
      children: [
        // Primary Settlement Account Card
        Container(
          padding: EdgeInsets.all(isMobile ? 16 : 22),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Primary Corporate Settlement Bank Account',
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Primary corporate bank account for merchant payouts & POS terminal settlements.',
                          style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDCFCE7),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFF86EFAC)),
                    ),
                    child: Text(
                      'DEFAULT',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF16A34A),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _buildStyledCurrencyInput(
                label: 'Receiving Bank Name',
                controller: _bankNameController,
                hint: 'Titan Trust Bank',
                prefix: '',
                isDark: isDark,
              ),
              const SizedBox(height: 12),
              _buildStyledCurrencyInput(
                label: 'Settlement Account Number (NUBAN)',
                controller: _accountNumberController,
                hint: '0098234123',
                prefix: '',
                isDark: isDark,
              ),
              const SizedBox(height: 12),
              _buildStyledCurrencyInput(
                label: 'Account Name',
                controller: _accountNameController,
                hint: 'NovaXpress Logistics Limited',
                prefix: '',
                isDark: isDark,
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // Multi-Account Direct Company Transfer Card
        Container(
          padding: EdgeInsets.all(isMobile ? 16 : 22),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Corporate Accounts for Direct Customer Payments',
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Accounts available to riders when customers pay directly to the company at delivery.',
                          style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _showAddCompanyAccountDialog(isDark),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00522A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.add_rounded, size: 16),
                    label: const Text('Add Account', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (_companyAccounts.isEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(
                      'No additional company accounts configured. Tap "Add Account" to add more.',
                      style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8)),
                    ),
                  ),
                )
              else
                ...List.generate(_companyAccounts.length, (idx) {
                  final acc = _companyAccounts[idx];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: acc.isDefault
                            ? const Color(0xFF10B981)
                            : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                        width: acc.isDefault ? 1.5 : 1.0,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: acc.isDefault
                                ? const Color(0xFF10B981).withValues(alpha: 0.15)
                                : const Color(0xFF0284C7).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.account_balance_rounded,
                            size: 18,
                            color: acc.isDefault ? const Color(0xFF10B981) : const Color(0xFF0284C7),
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
                                    acc.bankName,
                                    style: GoogleFonts.inter(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.bold,
                                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                                    ),
                                  ),
                                  if (acc.isDefault) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFDCFCE7),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        'DEFAULT',
                                        style: GoogleFonts.jetBrainsMono(
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.bold,
                                          color: const Color(0xFF16A34A),
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${acc.accountNumber} • ${acc.accountName}',
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 11.5,
                                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (!acc.isDefault) ...[
                          TextButton(
                            onPressed: () {
                              setState(() {
                                for (int i = 0; i < _companyAccounts.length; i++) {
                                  _companyAccounts[i] = _companyAccounts[i].copyWith(isDefault: i == idx);
                                }
                                _bankNameController.text = acc.bankName;
                                _accountNumberController.text = acc.accountNumber;
                                _accountNameController.text = acc.accountName;
                              });
                            },
                            child: const Text('Make Default', style: TextStyle(fontSize: 11)),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFEF4444)),
                            tooltip: 'Delete Account',
                            onPressed: () {
                              setState(() {
                                _companyAccounts.removeAt(idx);
                              });
                            },
                          ),
                        ],
                      ],
                    ),
                  );
                }),
            ],
          ),
        ),
      ],
    );
  }'''
assert target_tab in content, "target_tab not found"
content = content.replace(target_tab, replace_tab, 1)

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)

print("SUCCESS: dc_settings_page.dart patched successfully!")

