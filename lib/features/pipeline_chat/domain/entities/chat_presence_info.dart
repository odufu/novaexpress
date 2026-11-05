class ChatPresenceInfo {
  final String senderId;
  final String senderName;
  final String senderRole;
  final String status; // 'typing' | 'recording_voice_note' | 'idle'
  final DateTime timestamp;

  const ChatPresenceInfo({
    required this.senderId,
    required this.senderName,
    required this.senderRole,
    required this.status,
    required this.timestamp,
  });

  bool get isTyping => status == 'typing';
  bool get isRecording => status == 'recording_voice_note';
  bool get isActive => isTyping || isRecording;
  String get displayRole => formatRole(senderRole);

  String get displayLabel {
    final roleLabel = formatRole(senderRole);
    if (isRecording) {
      return '$roleLabel is recording audio...';
    } else if (isTyping) {
      return '$roleLabel is typing...';
    }
    return '';
  }

  static String formatRole(String role) {
    final r = role.toLowerCase().trim();
    if (r.contains('rider') || r.contains('delivery_agent') || r.contains('pda') || r.contains('driver')) {
      return 'Rider';
    }
    if (r.contains('closer') || r.contains('telesales')) {
      return 'Closer';
    }
    if (r.contains('marketer')) {
      return 'Digital Marketer';
    }
    if (r.contains('client') || r.contains('merchant')) {
      return 'Merchant';
    }
    if (r.contains('dispatcher') || r.contains('operations')) {
      return 'Dispatch Ops';
    }
    if (r.contains('finance')) {
      return 'Finance Ops';
    }
    if (r.contains('stock') || r.contains('inventory')) {
      return 'Stock Ops';
    }
    if (r.contains('accountant')) {
      return 'Accountant';
    }
    if (r.contains('manager') || r.contains('supervisor')) {
      return 'DC Supervisor';
    }
    return 'Someone';
  }

  factory ChatPresenceInfo.fromJson(Map<String, dynamic> json) {
    return ChatPresenceInfo(
      senderId: json['sender_id']?.toString() ?? '',
      senderName: json['sender_name']?.toString() ?? 'Participant',
      senderRole: json['sender_role']?.toString() ?? 'user',
      status: json['status']?.toString() ?? 'idle',
      timestamp: DateTime.tryParse(json['timestamp']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'sender_id': senderId,
      'sender_name': senderName,
      'sender_role': senderRole,
      'status': status,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}
