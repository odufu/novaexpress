/// Role of sender in conversation
enum ChatSenderRole {
  client,
  closer,
  marketer,
  dcManager,
  deliveryAgent,
  system,
}

/// Message types including automated pipeline events
enum ChatMessageType {
  text,
  statusChange,
  riderAssigned,
  productChanged,
  ownershipTransferred,
  deliveryCompleted,
  deliveryFailed,
  rescheduled,
  voiceNote,
  fileAttachment,
  image,
}

/// A message or automated milestone in the Order Conversation
class OrderConversationMessageEntity {
  final String id;
  final String conversationId;
  final String orderId;

  final String? senderId;
  final String senderName;
  final String? senderAvatarUrl;
  final ChatSenderRole senderRole;
  final ChatMessageType messageType;
  final String messageBody;
  final Map<String, dynamic> metadata;

  final bool readByClient;
  final bool readByDc;
  final bool readByRider;

  final DateTime createdAt;

  const OrderConversationMessageEntity({
    required this.id,
    required this.conversationId,
    required this.orderId,
    this.senderId,
    required this.senderName,
    this.senderAvatarUrl,
    required this.senderRole,
    this.messageType = ChatMessageType.text,
    required this.messageBody,
    this.metadata = const {},
    this.readByClient = false,
    this.readByDc = false,
    this.readByRider = false,
    required this.createdAt,
  });

  bool get isSystem => senderRole == ChatSenderRole.system;

  bool get isStatusEvent =>
      messageType != ChatMessageType.text &&
      messageType != ChatMessageType.voiceNote &&
      messageType != ChatMessageType.fileAttachment &&
      messageType != ChatMessageType.image;

  bool get isVoiceNote =>
      messageType == ChatMessageType.voiceNote ||
      metadata['type'] == 'voice_note' ||
      metadata['audio_url'] != null;

  String? get voiceNoteUrl => metadata['audio_url']?.toString();

  int get voiceNoteDuration =>
      (metadata['duration_seconds'] as num?)?.toInt() ??
      (metadata['duration'] as num?)?.toInt() ??
      0;

  bool get isFileAttachment =>
      messageType == ChatMessageType.fileAttachment ||
      metadata['type'] == 'file_attachment';

  bool get isImage =>
      messageType == ChatMessageType.image ||
      metadata['type'] == 'image' ||
      (isFileAttachment &&
          (metadata['mime_type']?.toString().startsWith('image/') == true ||
              metadata['file_name']?.toString().toLowerCase().endsWith('.png') == true ||
              metadata['file_name']?.toString().toLowerCase().endsWith('.jpg') == true ||
              metadata['file_name']?.toString().toLowerCase().endsWith('.jpeg') == true ||
              metadata['file_name']?.toString().toLowerCase().endsWith('.webp') == true));

  String? get fileUrl =>
      metadata['file_url']?.toString() ?? metadata['image_url']?.toString();

  String? get fileName => metadata['file_name']?.toString();

  int? get fileSize => (metadata['file_size'] as num?)?.toInt();

  String? get fileMimeType => metadata['mime_type']?.toString();
}

typedef OrderConversationMessage = OrderConversationMessageEntity;
