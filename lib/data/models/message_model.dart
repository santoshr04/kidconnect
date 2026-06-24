/// Chat message model
class MessageModel {
  final String id;
  final String senderId;
  final String receiverId;
  final String senderName;
  final String content;
  final DateTime timestamp;
  final bool isRead;
  final MessageType type;

  const MessageModel({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.senderName,
    required this.content,
    required this.timestamp,
    this.isRead = false,
    this.type = MessageType.text,
  });
}

enum MessageType { text, image, file }

/// Chat conversation preview
class ConversationModel {
  final String id;
  final String otherUserId;
  final String otherUserName;
  final String? otherUserAvatar;
  final String lastMessage;
  final DateTime lastMessageTime;
  final int unreadCount;
  final bool isOnline;

  const ConversationModel({
    required this.id,
    required this.otherUserId,
    required this.otherUserName,
    this.otherUserAvatar,
    required this.lastMessage,
    required this.lastMessageTime,
    this.unreadCount = 0,
    this.isOnline = false,
  });
}
