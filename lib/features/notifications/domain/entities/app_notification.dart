enum NotificationCategory {
  delivery,
  finance,
  stock,
  system,
}

class AppNotificationEntity {
  final String id;
  final String title;
  final String message;
  final NotificationCategory category;
  final DateTime createdAt;
  final bool isRead;
  final String? actionRoute;
  final Map<String, dynamic>? metadata;

  const AppNotificationEntity({
    required this.id,
    required this.title,
    required this.message,
    required this.category,
    required this.createdAt,
    this.isRead = false,
    this.actionRoute,
    this.metadata,
  });

  AppNotificationEntity copyWith({
    String? id,
    String? title,
    String? message,
    NotificationCategory? category,
    DateTime? createdAt,
    bool? isRead,
    String? actionRoute,
    Map<String, dynamic>? metadata,
  }) {
    return AppNotificationEntity(
      id: id ?? this.id,
      title: title ?? this.title,
      message: message ?? this.message,
      category: category ?? this.category,
      createdAt: createdAt ?? this.createdAt,
      isRead: isRead ?? this.isRead,
      actionRoute: actionRoute ?? this.actionRoute,
      metadata: metadata ?? this.metadata,
    );
  }

  factory AppNotificationEntity.fromJson(Map<String, dynamic> json) {
    NotificationCategory cat = NotificationCategory.system;
    final catStr = json['category']?.toString().toLowerCase() ?? 'system';
    if (catStr.contains('delivery') || catStr.contains('order')) {
      cat = NotificationCategory.delivery;
    } else if (catStr.contains('finance') || catStr.contains('remittance') || catStr.contains('payout')) {
      cat = NotificationCategory.finance;
    } else if (catStr.contains('stock') || catStr.contains('inventory')) {
      cat = NotificationCategory.stock;
    }

    return AppNotificationEntity(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Notification',
      message: json['message']?.toString() ?? '',
      category: cat,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now() : DateTime.now(),
      isRead: json['is_read'] == true,
      actionRoute: json['action_route']?.toString(),
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'message': message,
      'category': category.name,
      'created_at': createdAt.toIso8601String(),
      'is_read': isRead,
      'action_route': actionRoute,
      'metadata': metadata,
    };
  }
}
