/// Client / Merchant Profile Entity
class ClientProfile {
  final String id;
  final String companyName;
  final String contactPerson;
  final String email;
  final String phone;
  final String address;
  final String city;
  final String state;
  final String code;
  final String tier; // 'enterprise' | 'standard_merchant'
  final int closerLimit;
  final bool isEnterprise;
  final int totalClosersCount;
  final bool isActive;
  final DateTime? createdAt;

  const ClientProfile({
    required this.id,
    required this.companyName,
    required this.contactPerson,
    required this.email,
    required this.phone,
    required this.address,
    this.city = 'Abuja',
    this.state = 'Federal Capital Territory',
    this.code = 'CLI-01',
    this.tier = 'enterprise',
    this.closerLimit = 250,
    this.isEnterprise = true,
    this.totalClosersCount = 0,
    this.isActive = true,
    this.createdAt,
  });

  factory ClientProfile.fromJson(Map<String, dynamic> json) {
    final isEnt = json['is_enterprise'] == true ||
        json['tier']?.toString().toLowerCase() == 'enterprise' ||
        (json['company_name']?.toString().toLowerCase().contains('novacale') ?? false) ||
        (json['name']?.toString().toLowerCase().contains('novacale') ?? false);

    return ClientProfile(
      id: json['id']?.toString() ?? '',
      companyName: json['company_name']?.toString() ?? json['name']?.toString() ?? 'Novacale Limited',
      contactPerson: json['contact_person']?.toString() ?? 'Dr. Chuka Okafor',
      email: json['email']?.toString() ?? 'client.novacale@novaexpress.ng',
      phone: json['phone']?.toString() ?? json['phone_number']?.toString() ?? '08034455667',
      address: json['address']?.toString() ?? 'Plot 12, Commercial Avenue, Central Business District, Abuja',
      city: json['city']?.toString() ?? 'Abuja',
      state: json['state']?.toString() ?? 'Federal Capital Territory',
      code: json['code']?.toString() ?? 'CLI-NOVACALE-01',
      tier: json['tier']?.toString() ?? (isEnt ? 'enterprise' : 'standard_merchant'),
      closerLimit: (json['closer_limit'] as num?)?.toInt() ?? (isEnt ? 250 : 0),
      isEnterprise: isEnt,
      totalClosersCount: (json['total_closers_count'] as num?)?.toInt() ?? 0,
      isActive: json['is_active'] == true || json['is_active'] == 1,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'company_name': companyName,
      'contact_person': contactPerson,
      'email': email,
      'phone': phone,
      'address': address,
      'city': city,
      'state': state,
      'code': code,
      'tier': tier,
      'closer_limit': closerLimit,
      'is_enterprise': isEnterprise,
      'total_closers_count': totalClosersCount,
      'is_active': isActive,
      'created_at': createdAt?.toIso8601String(),
    };
  }

  ClientProfile copyWith({
    String? id,
    String? companyName,
    String? contactPerson,
    String? email,
    String? phone,
    String? address,
    String? city,
    String? state,
    String? code,
    String? tier,
    int? closerLimit,
    bool? isEnterprise,
    int? totalClosersCount,
    bool? isActive,
    DateTime? createdAt,
  }) {
    return ClientProfile(
      id: id ?? this.id,
      companyName: companyName ?? this.companyName,
      contactPerson: contactPerson ?? this.contactPerson,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      city: city ?? this.city,
      state: state ?? this.state,
      code: code ?? this.code,
      tier: tier ?? this.tier,
      closerLimit: closerLimit ?? this.closerLimit,
      isEnterprise: isEnterprise ?? this.isEnterprise,
      totalClosersCount: totalClosersCount ?? this.totalClosersCount,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
