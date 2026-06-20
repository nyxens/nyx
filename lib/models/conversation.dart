import 'chat_message.dart';

/// A single conversation session.
///
/// Messages are kept separately in the DB and loaded on demand —
/// so the history list only fetches titles/timestamps, never
/// full message text, keeping memory lean.
class Conversation {
  final String id;
  String title;
  final DateTime createdAt;
  DateTime updatedAt;

  /// Populated only when this conversation is the active one.
  /// Null means "not yet loaded from DB".
  List<ChatMessage>? messages;

  Conversation({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    this.messages,
  });

  /// Returns loaded messages or empty list — never null after first load.
  List<ChatMessage> get loadedMessages => messages ?? [];

  bool get hasMessages => messages != null && messages!.isNotEmpty;

  // ── SQLite serialisation ──────────────────────────────────────────────────

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'created_at': createdAt.millisecondsSinceEpoch,
        'updated_at': updatedAt.millisecondsSinceEpoch,
      };

  factory Conversation.fromMap(Map<String, dynamic> m) => Conversation(
        id: m['id'] as String,
        title: m['title'] as String,
        createdAt:
            DateTime.fromMillisecondsSinceEpoch(m['created_at'] as int),
        updatedAt:
            DateTime.fromMillisecondsSinceEpoch(m['updated_at'] as int),
      );
}