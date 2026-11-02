class MerchantBIChatSession {
  final String id;
  final String clientId;
  final String title;
  final String? lastMessage;
  final bool isPinned;
  final DateTime createdAt;
  final DateTime updatedAt;

  const MerchantBIChatSession({
    required this.id,
    required this.clientId,
    required this.title,
    this.lastMessage,
    this.isPinned = false,
    required this.createdAt,
    required this.updatedAt,
  });

  MerchantBIChatSession copyWith({
    String? id,
    String? clientId,
    String? title,
    String? lastMessage,
    bool? isPinned,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return MerchantBIChatSession(
      id: id ?? this.id,
      clientId: clientId ?? this.clientId,
      title: title ?? this.title,
      lastMessage: lastMessage ?? this.lastMessage,
      isPinned: isPinned ?? this.isPinned,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'client_id': clientId,
        'title': title,
        'last_message': lastMessage,
        'is_pinned': isPinned,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  factory MerchantBIChatSession.fromJson(Map<String, dynamic> json) =>
      MerchantBIChatSession(
        id: json['id'] as String? ?? 'session-${DateTime.now().millisecondsSinceEpoch}',
        clientId: json['client_id'] as String? ?? '',
        title: json['title'] as String? ?? 'Business Analytics',
        lastMessage: json['last_message'] as String?,
        isPinned: json['is_pinned'] as bool? ?? false,
        createdAt: json['created_at'] != null
            ? DateTime.tryParse(json['created_at'] as String) ?? DateTime.now()
            : DateTime.now(),
        updatedAt: json['updated_at'] != null
            ? DateTime.tryParse(json['updated_at'] as String) ?? DateTime.now()
            : DateTime.now(),
      );
}

