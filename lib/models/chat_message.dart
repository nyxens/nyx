/// A single chat turn.
class ChatMessage {
  final String id;
  final String conversationId;
  String text;
  final bool isUser;
  bool streaming;
  final DateTime createdAt;

  ChatMessage({
    required this.id,
    required this.conversationId,
    required this.text,
    required this.isUser,
    this.streaming = false,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  // ── SQLite serialisation ──────────────────────────────────────────────────

  Map<String, dynamic> toMap() => {
        'id': id,
        'conversation_id': conversationId,
        'text': text,
        'is_user': isUser ? 1 : 0,
        'created_at': createdAt.millisecondsSinceEpoch,
      };

  factory ChatMessage.fromMap(Map<String, dynamic> m) => ChatMessage(
        id: m['id'] as String,
        conversationId: m['conversation_id'] as String,
        text: m['text'] as String,
        isUser: (m['is_user'] as int) == 1,
        createdAt:
            DateTime.fromMillisecondsSinceEpoch(m['created_at'] as int),
      );
}