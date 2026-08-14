import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/message_model.dart';

class MessageRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference get _messages => _db.collection('messages');

  Stream<List<MessageModel>> streamThread(String threadId) {
    return _messages.where('threadId', isEqualTo: threadId).orderBy('timestamp', descending: false).snapshots().map((snap) => snap.docs.map((d) => MessageModel.fromDoc(d)).toList());
  }

  Future<void> sendMessage(String threadId, String senderId, String text) async {
    final msg = {
      'threadId': threadId,
      'senderId': senderId,
      'text': text,
      'timestamp': FieldValue.serverTimestamp(),
    };
    await _messages.add(msg);
  }
}
