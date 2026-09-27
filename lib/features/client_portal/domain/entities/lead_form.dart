class LeadForm {
  final String id;
  final String clientId;
  final String? marketerId;
  final String productId;
  final String productName;
  final String formTitle;
  final String formSlug;
  final String description;
  final List<Map<String, dynamic>> packages;
  final String redirectUrl;
  final String pixelId;
  final String capiToken;
  final String testEventCode;
  final Map<String, dynamic> fieldOptions;
  final Map<String, dynamic> appearance;
  final bool isActive;
  final int totalViews;
  final int totalSubmissions;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const LeadForm({
    required this.id,
    required this.clientId,
    this.marketerId,
    required this.productId,
    required this.productName,
    required this.formTitle,
    required this.formSlug,
    this.description = '',
    this.packages = const [],
    this.redirectUrl = '',
    this.pixelId = '',
    this.capiToken = '',
    this.testEventCode = '',
    this.fieldOptions = const {},
    this.appearance = const {},
    this.isActive = true,
    this.totalViews = 0,
    this.totalSubmissions = 0,
    this.createdAt,
    this.updatedAt,
  });

  double get conversionRate => totalViews > 0
      ? ((totalSubmissions / totalViews) * 100).clamp(0.0, 100.0)
      : (totalSubmissions > 0 ? 100.0 : 0.0);

  String get title => formTitle;
  int get totalOrdersBooked => totalSubmissions;
  int get totalOrdersDelivered => (totalSubmissions * 0.7).toInt();
  String get buttonText => appearance['button_text']?.toString() ?? 'CLAIM YOUR ORDER (PAY ON DELIVERY)';

  factory LeadForm.fromJson(Map<String, dynamic> json) {
    return LeadForm(
      id: json['id']?.toString() ?? '',
      clientId: json['client_id']?.toString() ?? '',
      marketerId: json['marketer_id']?.toString(),
      productId: json['product_id']?.toString() ?? '',
      productName: json['product_name']?.toString() ?? 'Product',
      formTitle: json['form_title']?.toString() ?? 'Campaign Order Form',
      formSlug: json['form_slug']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      packages: (json['packages'] as List?)?.map((e) => Map<String, dynamic>.from(e as Map)).toList() ?? const [],
      redirectUrl: json['redirect_url']?.toString() ?? '',
      pixelId: json['pixel_id']?.toString() ?? '',
      capiToken: json['capi_token']?.toString() ?? '',
      testEventCode: json['test_event_code']?.toString() ?? '',
      fieldOptions: json['field_options'] != null ? Map<String, dynamic>.from(json['field_options'] as Map) : const {},
      appearance: json['appearance'] != null ? Map<String, dynamic>.from(json['appearance'] as Map) : const {},
      isActive: json['is_active'] == true || json['is_active'] == 'true' || json['is_active'] == 1,
      totalViews: (json['total_views'] as num?)?.toInt() ?? 0,
      totalSubmissions: (json['total_submissions'] as num?)?.toInt() ?? 0,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'client_id': clientId,
      'marketer_id': marketerId,
      'product_id': productId,
      'product_name': productName,
      'form_title': formTitle,
      'form_slug': formSlug,
      'description': description,
      'packages': packages,
      'redirect_url': redirectUrl,
      'pixel_id': pixelId,
      'capi_token': capiToken,
      'test_event_code': testEventCode,
      'field_options': fieldOptions,
      'appearance': appearance,
      'is_active': isActive,
      'total_views': totalViews,
      'total_submissions': totalSubmissions,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  LeadForm copyWith({
    String? id,
    String? clientId,
    String? marketerId,
    String? productId,
    String? productName,
    String? formTitle,
    String? formSlug,
    String? description,
    List<Map<String, dynamic>>? packages,
    String? redirectUrl,
    String? pixelId,
    String? capiToken,
    String? testEventCode,
    Map<String, dynamic>? fieldOptions,
    Map<String, dynamic>? appearance,
    bool? isActive,
    int? totalViews,
    int? totalSubmissions,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return LeadForm(
      id: id ?? this.id,
      clientId: clientId ?? this.clientId,
      marketerId: marketerId ?? this.marketerId,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      formTitle: formTitle ?? this.formTitle,
      formSlug: formSlug ?? this.formSlug,
      description: description ?? this.description,
      packages: packages ?? this.packages,
      redirectUrl: redirectUrl ?? this.redirectUrl,
      pixelId: pixelId ?? this.pixelId,
      capiToken: capiToken ?? this.capiToken,
      testEventCode: testEventCode ?? this.testEventCode,
      fieldOptions: fieldOptions ?? this.fieldOptions,
      appearance: appearance ?? this.appearance,
      isActive: isActive ?? this.isActive,
      totalViews: totalViews ?? this.totalViews,
      totalSubmissions: totalSubmissions ?? this.totalSubmissions,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
