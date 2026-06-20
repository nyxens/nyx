import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import '../models/chat_message.dart';
import '../models/conversation.dart';

/// Handles all local SQLite persistence.
///
/// Memory strategy:
///   - The conversations list only stores metadata (id, title, timestamps).
///   - Message rows are fetched only when a conversation is opened.
///   - When a conversation is closed its [messages] list is set to null,
///     returning that memory to the pool.
///   - Messages are capped at [kMaxStoredMessagesPerConversation] rows;
///     older rows are pruned on save so the DB doesn't grow unboundedly.
///   - The LLM context window is built from the most recent
///     [kContextWindowSize] messages, not the full history.
class StorageService {
  static const int kMaxStoredMessagesPerConversation = 200;
  static const int kContextWindowSize = 20; // messages fed to the LLM

  static const String _dbName = 'nyx.db';
  static const int _dbVersion = 1;

  Database? _db;

  // ── Init ──────────────────────────────────────────────────────────────────

  Future<void> init() async {
    final dbPath = p.join(await getDatabasesPath(), _dbName);
    _db = await openDatabase(
      dbPath,
      version: _dbVersion,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE conversations (
        id         TEXT PRIMARY KEY,
        title      TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE messages (
        id              TEXT PRIMARY KEY,
        conversation_id TEXT NOT NULL,
        text            TEXT NOT NULL,
        is_user         INTEGER NOT NULL,
        created_at      INTEGER NOT NULL,
        FOREIGN KEY (conversation_id)
          REFERENCES conversations (id)
          ON DELETE CASCADE
      )
    ''');

    // Index for fast per-conversation message lookups.
    await db.execute('''
      CREATE INDEX idx_messages_conv
        ON messages (conversation_id, created_at)
    ''');
  }

  Database get _database {
    assert(_db != null, 'StorageService.init() must be called first');
    return _db!;
  }

  // ── Conversations ─────────────────────────────────────────────────────────

  /// Returns all conversations, newest first. Messages are NOT loaded.
  Future<List<Conversation>> loadConversations() async {
    final rows = await _database.query(
      'conversations',
      orderBy: 'updated_at DESC',
    );
    return rows.map(Conversation.fromMap).toList();
  }

  Future<void> saveConversation(Conversation conv) async {
    await _database.insert(
      'conversations',
      conv.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateConversationTitle(
      String convId, String title) async {
    await _database.update(
      'conversations',
      {
        'title': title,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [convId],
    );
  }

  Future<void> deleteConversation(String convId) async {
    await _database.delete(
      'conversations',
      where: 'id = ?',
      whereArgs: [convId],
    );
    // Messages cascade-delete via FK.
  }

  // ── Messages ──────────────────────────────────────────────────────────────

  /// Loads all messages for a conversation (called when opening it).
  Future<List<ChatMessage>> loadMessages(String convId) async {
    final rows = await _database.query(
      'messages',
      where: 'conversation_id = ?',
      whereArgs: [convId],
      orderBy: 'created_at ASC',
    );
    return rows.map(ChatMessage.fromMap).toList();
  }

  /// Appends a single message and prunes old rows if needed.
  Future<void> saveMessage(ChatMessage msg) async {
    await _database.insert(
      'messages',
      msg.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    // Update parent conversation's updated_at timestamp.
    await _database.update(
      'conversations',
      {'updated_at': DateTime.now().millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [msg.conversationId],
    );

    await _pruneMessages(msg.conversationId);
  }

  /// Updates the text of an existing message (used after streaming finishes).
  Future<void> updateMessageText(String msgId, String text) async {
    await _database.update(
      'messages',
      {'text': text},
      where: 'id = ?',
      whereArgs: [msgId],
    );
  }

  /// Removes oldest messages beyond the cap.
  Future<void> _pruneMessages(String convId) async {
    final count = Sqflite.firstIntValue(await _database.rawQuery(
      'SELECT COUNT(*) FROM messages WHERE conversation_id = ?',
      [convId],
    ))!;

    if (count > kMaxStoredMessagesPerConversation) {
      final excess = count - kMaxStoredMessagesPerConversation;
      await _database.rawDelete('''
        DELETE FROM messages
        WHERE id IN (
          SELECT id FROM messages
          WHERE conversation_id = ?
          ORDER BY created_at ASC
          LIMIT ?
        )
      ''', [convId, excess]);
    }
  }

  // ── LLM context window ────────────────────────────────────────────────────

  /// Returns the last [kContextWindowSize] messages formatted as a
  /// prompt-ready list for the LLM.  Only text is included; streaming
  /// flags are stripped.
  ///
  /// This is intentionally separate from [loadMessages] so the UI can
  /// show the full visible history while the LLM only processes recent turns.
  Future<List<Map<String, String>>> buildContextWindow(
      String convId) async {
    final rows = await _database.rawQuery('''
      SELECT text, is_user FROM messages
      WHERE conversation_id = ?
      ORDER BY created_at DESC
      LIMIT ?
    ''', [convId, kContextWindowSize]);

    // Reverse so oldest is first (chronological for the LLM).
    return rows.reversed
        .map((r) => {
              'role': (r['is_user'] as int) == 1 ? 'user' : 'assistant',
              'content': r['text'] as String,
            })
        .toList();
  }

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  Future<void> close() async => await _db?.close();
}