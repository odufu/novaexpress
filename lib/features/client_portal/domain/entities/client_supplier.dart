/// Client Supplier / Vendor Entity
/// Represents raw product manufacturers, packaging printers, and logistics freight haulers.
class ClientSupplier {
  final String id;
  final String clientId;
  final String supplierName;
  final String category;
  final String contactPerson;
  final String email;
  final String phone;
  final String address;
  final String city;
  final String country;
  final List<String> suppliedProducts;
  final String paymentTerms; // 'Immediate', 'Net 15', 'Net 30', '50% Advance', 'Custom'
  final int leadTimeDays;
  final String bankName;
  final String accountNumber;
  final String accountName;
  final String notes;
  final bool isActive;
  final DateTime createdAt;

  String get name => supplierName;
  String get bankAccountNumber => accountNumber;

  const ClientSupplier({
    required this.id,
    required this.clientId,
    required this.supplierName,
    this.category = 'General',
    this.contactPerson = '',
    this.email = '',
    this.phone = '',
    this.address = '',
    this.city = 'Abuja',
    this.country = 'Nigeria',
    this.suppliedProducts = const [],
    this.paymentTerms = 'Immediate',
    this.leadTimeDays = 7,
    this.bankName = '',
    this.accountNumber = '',
    this.accountName = '',
    this.notes = '',
    this.isActive = true,
    required this.createdAt,
  });

  factory ClientSupplier.fromJson(Map<String, dynamic> json) {
    List<String> productsList = [];
    if (json['supplied_products'] is List) {
      productsList = (json['supplied_products'] as List).map((e) => e.toString()).toList();
    }

    return ClientSupplier(
      id: json['id']?.toString() ?? '',
      clientId: json['client_id']?.toString() ?? '',
      supplierName: json['supplier_name']?.toString() ?? json['name']?.toString() ?? 'Supplier',
      category: json['category']?.toString() ?? 'General',
      contactPerson: json['contact_person']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      phone: json['phone']?.toString() ?? json['phone_number']?.toString() ?? '',
      address: json['address']?.toString() ?? '',
      city: json['city']?.toString() ?? 'Abuja',
      country: json['country']?.toString() ?? 'Nigeria',
      suppliedProducts: productsList,
      paymentTerms: json['payment_terms']?.toString() ?? 'Immediate',
      leadTimeDays: (json['lead_time_days'] as num?)?.toInt() ?? 7,
      bankName: json['bank_name']?.toString() ?? '',
      accountNumber: json['account_number']?.toString() ?? '',
      accountName: json['account_name']?.toString() ?? '',
      notes: json['notes']?.toString() ?? '',
      isActive: json['is_active'] == null || json['is_active'] == true || json['is_active'] == 1,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now() : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'client_id': clientId,
      'supplier_name': supplierName,
      'category': category,
      'contact_person': contactPerson,
      'email': email,
      'phone': phone,
      'address': address,
      'city': city,
      'country': country,
      'supplied_products': suppliedProducts,
      'payment_terms': paymentTerms,
      'lead_time_days': leadTimeDays,
      'bank_name': bankName,
      'account_number': accountNumber,
      'account_name': accountName,
      'notes': notes,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
    };
  }

  ClientSupplier copyWith({
    String? id,
    String? clientId,
    String? supplierName,
    String? category,
    String? contactPerson,
    String? email,
    String? phone,
    String? address,
    String? city,
    String? country,
    List<String>? suppliedProducts,
    String? paymentTerms,
    int? leadTimeDays,
    String? bankName,
    String? accountNumber,
    String? accountName,
    String? notes,
    bool? isActive,
    DateTime? createdAt,
  }) {
    return ClientSupplier(
      id: id ?? this.id,
      clientId: clientId ?? this.clientId,
      supplierName: supplierName ?? this.supplierName,
      category: category ?? this.category,
      contactPerson: contactPerson ?? this.contactPerson,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      city: city ?? this.city,
      country: country ?? this.country,
      suppliedProducts: suppliedProducts ?? this.suppliedProducts,
      paymentTerms: paymentTerms ?? this.paymentTerms,
      leadTimeDays: leadTimeDays ?? this.leadTimeDays,
      bankName: bankName ?? this.bankName,
      accountNumber: accountNumber ?? this.accountNumber,
      accountName: accountName ?? this.accountName,
      notes: notes ?? this.notes,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
