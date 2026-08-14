import 'package:cloud_firestore/cloud_firestore.dart';

class MessageModel {
  final String id;
  final String threadId; // e.g. teacherId_parentId
  final String senderId;
  final String text;
  final Timestamp timestamp;

  MessageModel({required this.id, required this.threadId, required this.senderId, required this.text, required this.timestamp});

  Map<String, dynamic> toMap() => {
        'threadId': threadId,
        'senderId': senderId,
        'text': text,
        'timestamp': timestamp,
      };

  factory MessageModel.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return MessageModel(
      id: doc.id,
      threadId: data['threadId'] as String? ?? '',
      senderId: data['senderId'] as String? ?? '',
      text: data['text'] as String? ?? '',
      timestamp: data['timestamp'] as Timestamp? ?? Timestamp.now(),
    );
  }
}
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
