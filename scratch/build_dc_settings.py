import json

with open('scratch/step_2651.json', 'r', encoding='utf-8') as f:
    data = json.load(f)

raw_content = data.get('CodeContent', '')
if raw_content.startswith('"') and raw_content.endswith('"'):
    content = json.loads(raw_content)
else:
    content = raw_content

lines = content.splitlines()

# 1. Remove unused import formatters.dart
lines = [l for l in lines if "import '../../../../core/helpers/formatters.dart';" not in l]

# 2. Add suffix support to _buildStyledCurrencyInput
for i, l in enumerate(lines):
    if 'Widget _buildStyledCurrencyInput({' in l:
        lines.insert(i + 6, "    String suffix = '',")
        break

for i, l in enumerate(lines):
    if 'border: InputBorder.none,' in l:
        for j in range(i, i + 10):
            if lines[j].strip() == '),' and lines[j+1].strip() == '],':
                suffix_code = [
                    '              if (suffix.isNotEmpty) ...[',
                    '                const SizedBox(width: 6),',
                    '                Text(',
                    '                  suffix,',
                    '                  style: GoogleFonts.inter(',
                    '                    fontWeight: FontWeight.bold,',
                    '                    fontSize: 13,',
                    '                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),',
                    '                  ),',
                    '                ),',
                    '              ],',
                ]
                for k, s in enumerate(suffix_code):
                    lines.insert(j + 1 + k, s)
                break
        break

# 3. Add formula banner in simulator card
formula_banner = [
    '                  // Dynamic Formula Banner (Exact Match to UI/UX Design)',
    '                  const SizedBox(height: 16),',
    '                  Container(',
    '                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),',
    '                    decoration: BoxDecoration(',
    '                      color: const Color(0xFF0F142D),',
    '                      borderRadius: BorderRadius.circular(8),',
    '                      border: Border.all(color: const Color(0xFF222B57)),',
    '                    ),',
    '                    child: Row(',
    '                      children: [',
    '                        const Icon(Icons.info_outline, color: Color(0xFF818CF8), size: 16),',
    '                        const SizedBox(width: 8),',
    '                        Text(',
    "                          'Formula: ',",
    '                          style: GoogleFonts.inter(',
    '                            fontSize: 11.5,',
    '                            fontWeight: FontWeight.w600,',
    '                            color: const Color(0xFF94A3B8),',
    '                          ),',
    '                        ),',
    '                        Expanded(',
    '                          child: SingleChildScrollView(',
    '                            scrollDirection: Axis.horizontal,',
    '                            child: RichText(',
    '                              text: TextSpan(',
    '                                style: GoogleFonts.jetBrainsMono(',
    '                                  fontSize: 11.5,',
    '                                  fontWeight: FontWeight.w600,',
    '                                  color: const Color(0xFFE2E8F0),',
    '                                ),',
    '                                children: [',
    "                                  const TextSpan(text: 'Net Vault = Gross Cash (₦'),",
    '                                  TextSpan(text: _integerFormat.format(simAmount.toInt())),',
    "                                  const TextSpan(text: ') - ['),",
    '                                  if (isReimbursable) ...[',
    "                                    const TextSpan(text: 'POS Reimbursement (₦'),",
    '                                    TextSpan(text: _integerFormat.format(posFee.toInt())),',
    "                                    const TextSpan(text: ') + '),",
    '                                  ],',
    "                                  const TextSpan(text: 'Rider Cut (₦'),",
    '                                  TextSpan(text: _integerFormat.format(riderAllowance.toInt())),',
    "                                  const TextSpan(text: ')]'),",
    '                                ],',
    '                              ),',
    '                            ),',
    '                          ),',
    '                        ),',
    '                        const SizedBox(width: 8),',
    '                        Container(',
    '                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),',
    '                          decoration: BoxDecoration(',
    '                            color: const Color(0xFF064E3B).withValues(alpha: 0.6),',
    '                            borderRadius: BorderRadius.circular(4),',
    '                            border: Border.all(color: const Color(0xFF059669)),',
    '                          ),',
    '                          child: Text(',
    "                            'Balanced Ledger',",
    '                            style: GoogleFonts.inter(',
    '                              fontSize: 10,',
    '                              fontWeight: FontWeight.w700,',
    '                              color: const Color(0xFF34D399),',
    '                            ),',
    '                          ),',
    '                        ),',
    '                      ],',
    '                    ),',
    '                  ),',
]

# Find the second occurrence of 34D399 (desktop KPI card)
count_34d399 = 0
for i in range(len(lines)):
    if 'valColor: const Color(0xFF34D399)' in lines[i]:
        count_34d399 += 1
        if count_34d399 == 2:
            for j in range(i, i + 30):
                if lines[j].strip() == '],' and lines[j+1].strip() == '],' and lines[j+2].strip() == '),' and lines[j+3].strip() == ');':
                    # Insert right after lines[j]
                    for k, item in enumerate(formula_banner):
                        lines.insert(j + 1 + k, item)
                    print(f'Inserted formula banner after line {j}')
                    break
            break

# 4. Insert Paystack Card after the Consumer
paystack_card_call = [
    '        const SizedBox(height: 16),',
    '        // 3. Paystack & Direct Gateway Charges Card (Exact UI/UX Match)',
    '        _buildPaystackGatewayChargesCard(cardBg, borderColor, isDark, isMobile),',
    '        const SizedBox(height: 24),',
]

for i in range(len(lines)):
    if 'Balanced Ledger' in lines[i]:
        for j in range(i, i + 40):
            if lines[j].strip() == 'const SizedBox(height: 16),' and lines[j+1].strip() == '],' and lines[j+2].strip() == ');':
                lines[j:j+1] = paystack_card_call
                print(f'Inserted paystack card call at line {j}')
                break
        break

# 5. Add _buildPaystackGatewayChargesCard method definition right above _buildDynamicStrategyCard
paystack_card_method_lines = '''  Widget _buildPaystackGatewayChargesCard(
    Color cardBg,
    Color borderColor,
    bool isDark,
    bool isMobile,
  ) {
    return Container(
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
                    Row(
                      children: [
                        Text(
                          'Paystack & Direct Gateway Charges',
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: isDark ? const Color(0xFF475569) : const Color(0xFFE2E8F0),
                            ),
                          ),
                          child: Text(
                            'Automated Webhook',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Gateway commission deducted on incoming card, USSD, and virtual account direct merchant collections.',
                      style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
              if (!isMobile)
                Text(
                  'Channel: Live production',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 11,
                    color: const Color(0xFF94A3B8),
                    fontWeight: FontWeight.w500,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          if (isMobile) ...[
            _buildStyledCurrencyInput(
              label: 'Direct Paystack Fee (%)',
              controller: _paystackFeePercentController,
              hint: '1.5',
              prefix: '',
              suffix: '%',
              helper: 'Standard Paystack transaction percentage for Nigeria local debit cards.',
              isDark: isDark,
            ),
            const SizedBox(height: 14),
            _buildStyledCurrencyInput(
              label: 'Paystack Max Fee Cap (₦)',
              controller: _paystackFeeCapController,
              hint: '2,000',
              prefix: '₦',
              helper: 'Fee cap ceiling applied to high volume single checkout orders.',
              isDark: isDark,
            ),
          ] else ...[
            Row(
              children: [
                Expanded(
                  child: _buildStyledCurrencyInput(
                    label: 'Direct Paystack Fee (%)',
                    controller: _paystackFeePercentController,
                    hint: '1.5',
                    prefix: '',
                    suffix: '%',
                    helper: 'Standard Paystack transaction percentage for Nigeria local debit cards.',
                    isDark: isDark,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _buildStyledCurrencyInput(
                    label: 'Paystack Max Fee Cap (₦)',
                    controller: _paystackFeeCapController,
                    hint: '2,000',
                    prefix: '₦',
                    helper: 'Fee cap ceiling applied to high volume single checkout orders.',
                    isDark: isDark,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isDark ? const Color(0xFF3B82F6).withValues(alpha: 0.3) : const Color(0xFFDBEAFE),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_rounded, color: Color(0xFF2563EB), size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Automated Paystack Split Settlements',
                        style: GoogleFonts.inter(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1E40AF),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Settlement runs automatically at 23:00 GMT+1 daily. Gateway fees are absorbed in accordance with the Merchant contract profile configured under the Merchant Billing tab.',
                        style: GoogleFonts.inter(
                          fontSize: 11.5,
                          color: isDark ? const Color(0xFFBFDBFE) : const Color(0xFF3B82F6),
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }'''.splitlines()

for i in range(len(lines)):
    if 'Widget _buildDynamicStrategyCard({' in lines[i]:
        for k, l in enumerate(paystack_card_method_lines):
            lines.insert(i + k, l)
        print(f'Inserted paystack card method at line {i}')
        break

output_path = r'c:\PROJECT\NoveXPS\lib\features\dc_console\presentation\pages\dc_settings_page.dart'
with open(output_path, 'w', encoding='utf-8') as f:
    f.write('\n'.join(lines))
print(f'Successfully written {len(lines)} lines to {output_path}!')
