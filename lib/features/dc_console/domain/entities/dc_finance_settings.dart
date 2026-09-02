class DCFinanceSettings {
  final String posChargeMode; // 'dynamic' (tiered) or 'flat'
  final double posFlatRate; // e.g. 350.0
  final double posTierAmount; // e.g. 5000.0
  final double posTierFee; // e.g. 100.0
  final double posMaxCapFee; // e.g. 1500.0
  final bool isPosFeeReimbursable; // true: company reimburses / rider retains fee
  final double paystackDirectFeePercent; // e.g. 1.5%
  final double paystackFeeCap; // e.g. 2000.0
  final double defaultCommissionRate; // e.g. 1000.0
  final double defaultTransportAllowance; // e.g. 1500.0
  final double defaultFailedStipend; // e.g. 500.0
  final String settlementBankName; // 'Titan Trust Bank'
  final String settlementAccountNumber; // '0098234123'
  final String settlementAccountName; // 'NovaExpress Logistics Limited'
  final bool autoReconcileWebhooks; // true

  const DCFinanceSettings({
    this.posChargeMode = 'dynamic',
    this.posFlatRate = 350.0,
    this.posTierAmount = 5000.0,
    this.posTierFee = 100.0,
    this.posMaxCapFee = 1500.0,
    this.isPosFeeReimbursable = true,
    this.paystackDirectFeePercent = 1.5,
    this.paystackFeeCap = 2000.0,
    this.defaultCommissionRate = 1000.0,
    this.defaultTransportAllowance = 1500.0,
    this.defaultFailedStipend = 500.0,
    this.settlementBankName = 'Titan Trust Bank',
    this.settlementAccountNumber = '0098234123',
    this.settlementAccountName = 'NovaExpress Logistics Limited',
    this.autoReconcileWebhooks = true,
  });

  /// Computes POS transfer fee for an amount based on current settings
  double computePosFee(double amount) {
    if (amount <= 0) return posChargeMode == 'flat' ? posFlatRate : 0.0;
    if (posChargeMode == 'flat') {
      return posFlatRate;
    } else {
      final tier = posTierAmount > 0 ? posTierAmount : 5000.0;
      final steps = (amount / tier).ceil();
      final fee = steps * (posTierFee > 0 ? posTierFee : 100.0);
      return fee.clamp(posTierFee, posMaxCapFee);
    }
  }

  /// Computes Paystack fee for an amount based on current settings
  double computePaystackFee(double amount) {
    if (amount <= 0) return 0.0;
    final fee = amount * (paystackDirectFeePercent / 100.0);
    return fee.clamp(100.0, paystackFeeCap);
  }

  DCFinanceSettings copyWith({
    String? posChargeMode,
    double? posFlatRate,
    double? posTierAmount,
    double? posTierFee,
    double? posMaxCapFee,
    bool? isPosFeeReimbursable,
    double? paystackDirectFeePercent,
    double? paystackFeeCap,
    double? defaultCommissionRate,
    double? defaultTransportAllowance,
    double? defaultFailedStipend,
    String? settlementBankName,
    String? settlementAccountNumber,
    String? settlementAccountName,
    bool? autoReconcileWebhooks,
  }) {
    return DCFinanceSettings(
      posChargeMode: posChargeMode ?? this.posChargeMode,
      posFlatRate: posFlatRate ?? this.posFlatRate,
      posTierAmount: posTierAmount ?? this.posTierAmount,
      posTierFee: posTierFee ?? this.posTierFee,
      posMaxCapFee: posMaxCapFee ?? this.posMaxCapFee,
      isPosFeeReimbursable: isPosFeeReimbursable ?? this.isPosFeeReimbursable,
      paystackDirectFeePercent: paystackDirectFeePercent ?? this.paystackDirectFeePercent,
      paystackFeeCap: paystackFeeCap ?? this.paystackFeeCap,
      defaultCommissionRate: defaultCommissionRate ?? this.defaultCommissionRate,
      defaultTransportAllowance: defaultTransportAllowance ?? this.defaultTransportAllowance,
      defaultFailedStipend: defaultFailedStipend ?? this.defaultFailedStipend,
      settlementBankName: settlementBankName ?? this.settlementBankName,
      settlementAccountNumber: settlementAccountNumber ?? this.settlementAccountNumber,
      settlementAccountName: settlementAccountName ?? this.settlementAccountName,
      autoReconcileWebhooks: autoReconcileWebhooks ?? this.autoReconcileWebhooks,
    );
  }

  double get defaultFailedDeliveryAllowance => defaultFailedStipend;

  factory DCFinanceSettings.fromJson(Map<String, dynamic> json) {
    return DCFinanceSettings(
      posChargeMode: json['pos_charge_mode']?.toString() ?? json['posChargeMode'] ?? 'dynamic',
      posFlatRate: (json['pos_flat_rate'] as num?)?.toDouble() ?? (json['posFlatRate'] as num?)?.toDouble() ?? 350.0,
      posTierAmount: (json['pos_tier_amount'] as num?)?.toDouble() ?? (json['posTierAmount'] as num?)?.toDouble() ?? 5000.0,
      posTierFee: (json['pos_tier_fee'] as num?)?.toDouble() ?? (json['posTierFee'] as num?)?.toDouble() ?? 100.0,
      posMaxCapFee: (json['pos_max_cap_fee'] as num?)?.toDouble() ?? (json['posMaxCapFee'] as num?)?.toDouble() ?? 1500.0,
      isPosFeeReimbursable: json['is_pos_fee_reimbursable'] ?? json['isPosFeeReimbursable'] ?? true,
      paystackDirectFeePercent: (json['paystack_direct_fee_percent'] as num?)?.toDouble() ?? 1.5,
      paystackFeeCap: (json['paystack_fee_cap'] as num?)?.toDouble() ?? 2000.0,
      defaultCommissionRate: (json['default_commission_rate'] as num?)?.toDouble() ?? (json['defaultCommissionRate'] as num?)?.toDouble() ?? 1000.0,
      defaultTransportAllowance: (json['default_transport_allowance'] as num?)?.toDouble() ?? (json['defaultTransportAllowance'] as num?)?.toDouble() ?? 1500.0,
      defaultFailedStipend: (json['default_failed_delivery_allowance'] as num?)?.toDouble() ?? (json['default_failed_stipend'] as num?)?.toDouble() ?? (json['defaultFailedStipend'] as num?)?.toDouble() ?? 500.0,
      settlementBankName: json['settlement_bank_name']?.toString() ?? 'Titan Trust Bank',
      settlementAccountNumber: json['settlement_account_number']?.toString() ?? '0098234123',
      settlementAccountName: json['settlement_account_name']?.toString() ?? 'NovaExpress Logistics Limited',
      autoReconcileWebhooks: json['auto_reconcile_webhooks'] ?? json['autoReconcileWebhooks'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'pos_charge_mode': posChargeMode,
      'pos_flat_rate': posFlatRate,
      'pos_tier_amount': posTierAmount,
      'pos_tier_fee': posTierFee,
      'pos_max_cap_fee': posMaxCapFee,
      'is_pos_fee_reimbursable': isPosFeeReimbursable,
      'paystack_direct_fee_percent': paystackDirectFeePercent,
      'paystack_fee_cap': paystackFeeCap,
      'default_commission_rate': defaultCommissionRate,
      'default_transport_allowance': defaultTransportAllowance,
      'default_failed_delivery_allowance': defaultFailedStipend,
      'default_failed_stipend': defaultFailedStipend,
      'settlement_bank_name': settlementBankName,
      'settlement_account_number': settlementAccountNumber,
      'settlement_account_name': settlementAccountName,
      'auto_reconcile_webhooks': autoReconcileWebhooks,
    };
  }
}
