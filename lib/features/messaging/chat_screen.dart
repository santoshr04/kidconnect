import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/message_model.dart';
import '../../data/repositories/message_repository.dart';
import '../auth/providers/auth_provider.dart';

class ChatThreadScreen extends ConsumerStatefulWidget {
  final String threadId; // e.g. teacherId_parentId
  final String otherName;
  const ChatThreadScreen({required this.threadId, required this.otherName, super.key});

  @override
  ConsumerState<ChatThreadScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatThreadScreen> {
  final _repo = MessageRepository();
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final userId = auth.currentUser?.id ?? 'unknown';

    return Scaffold(
      appBar: AppBar(title: Text(widget.otherName), backgroundColor: AppColors.background, elevation: 0),
      body: Column(children: [
        Expanded(
          child: StreamBuilder<List<MessageModel>>(
            stream: _repo.streamThread(widget.threadId),
            builder: (context, snap) {
              if (!snap.hasData) return const Center(child: CircularProgressIndicator());
              final msgs = snap.data!;
              return ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: msgs.length,
                itemBuilder: (context, i) {
                  final m = msgs[i];
                  final mine = m.senderId == userId;
                  return Align(
                    alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(color: mine ? AppColors.primary : AppColors.surfaceVariant, borderRadius: BorderRadius.circular(12)),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(m.text, style: TextStyle(color: mine ? Colors.white : AppColors.textPrimary)),
                        const SizedBox(height: 4),
                        Text((m.timestamp as Timestamp).toDate().toLocal().toString().split('.').first, style: TextStyle(fontSize: 10, color: AppColors.textTertiary)),
                      ]),
                    ),
                  );
                },
              );
            },
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(children: [
              Expanded(child: TextField(controller: _controller, decoration: const InputDecoration(hintText: 'Message...', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)))),
              const SizedBox(width: 8),
                  ElevatedButton(
                onPressed: () async {
                  final text = _controller.text.trim();
                  if (text.isEmpty) return;
                      await _repo.sendMessage(widget.threadId, userId, text);
                  _controller.clear();
                },
                child: const Icon(Icons.send),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}
