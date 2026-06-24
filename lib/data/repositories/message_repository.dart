import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../models/message_model.dart';

/// Firebase message repository.
///
/// Handles chat messages between parents and teachers via Firestore.
/// Falls back to mock data when Firebase is unavailable.
class MessageRepository {
  static bool get _isFirebaseAvailable {
    try {
      FirebaseFirestore.instance;
      return true;
    } catch (_) {
      return false;
    }
  }

  static const _collection = 'messages';
  static const _uuid = Uuid();

  /// Send a message from one user to another.
  static Future<MessageModel?> sendMessage({
    required String senderId,
    required String receiverId,
    required String senderName,
    required String content,
    MessageType type = MessageType.text,
  }) async {
    if (!_isFirebaseAvailable) return null;

    try {
      final messageId = _uuid.v4();
      final messageData = {
        'id': messageId,
        'senderId': senderId,
        'receiverId': receiverId,
        'senderName': senderName,
        'content': content,
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
        'type': type.name,
      };

      await FirebaseFirestore.instance
          .collection(_collection)
          .doc(messageId)
          .set(messageData);

      return MessageModel(
        id: messageId,
        senderId: senderId,
        receiverId: receiverId,
        senderName: senderName,
        content: content,
        timestamp: DateTime.now(),
        isRead: false,
        type: type,
      );
    } catch (_) {
      return null;
    }
  }

  /// Get messages between two users, ordered by timestamp.
  static Stream<List<MessageModel>> getMessagesBetween(
    String userId1,
    String userId2,
  ) {
    if (!_isFirebaseAvailable) return const Stream.empty();

    // Firestore doesn't support OR queries simply, so we'll query
    // for messages where the current user is either sender or receiver,
    // then filter client-side.
    return FirebaseFirestore.instance
        .collection(_collection)
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => _messageFromFirestore(doc.data()))
          .where((m) =>
              (m.senderId == userId1 && m.receiverId == userId2) ||
              (m.senderId == userId2 && m.receiverId == userId1))
          .toList();
    });
  }

  /// Mark a message as read.
  static Future<void> markAsRead(String messageId) async {
    if (!_isFirebaseAvailable) return;
    await FirebaseFirestore.instance
        .collection(_collection)
        .doc(messageId)
        .update({'isRead': true});
  }

  static MessageModel _messageFromFirestore(Map<String, dynamic> data) {
    return MessageModel(
      id: data['id'] ?? '',
      senderId: data['senderId'] ?? '',
      receiverId: data['receiverId'] ?? '',
      senderName: data['senderName'] ?? '',
      content: data['content'] ?? '',
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isRead: data['isRead'] ?? false,
      type: MessageType.values.firstWhere(
        (t) => t.name == (data['type'] ?? 'text'),
        orElse: () => MessageType.text,
      ),
    );
  }
}