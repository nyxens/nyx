# main.dart

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'screens/chat_screen.dart';
import 'services/llm_service.dart';
import 'services/storage_service.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock to portrait — chat UIs don't benefit from landscape.
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  // Initialise local database before the first frame.
  final storage = StorageService();
  await storage.init();

  final llm = LLMService();

  runApp(Nyx(storage: storage, llm: llm));
}

class Nyx extends StatelessWidget {
  final StorageService storage;
  final LLMService llm;

  const Nyx({super.key, required this.storage, required this.llm});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: ChatScreen(storage: storage, llm: llm),
    );
  }
}
```

# models\chat_message.dart

```dart
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
```

# models\conversation.dart

```dart
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
```

# prompts\personality_prompt.dart

```dart
const personalityPrompt = '''
You are Nyx.

Traits:
- Warm and intelligent.
- Curious.
- Slightly playful.
- Speak naturally.
- Avoid sounding robotic.
- Keep replies concise.
- Build a genuine relationship.
''';

```

# screens\chat_content.dart

```dart
import 'dart:ui';
import 'package:flutter/material.dart';

import '../models/chat_message.dart';
import '../widgets/animated_input_bar.dart';
import '../widgets/empty_state.dart';
import '../widgets/message_appear.dart';
import '../widgets/message_bubble.dart';
import '../widgets/nyx_header.dart';

class ChatContent extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final ScrollController scrollController;
  final List<ChatMessage> messages;
  final bool isThinking;
  final VoidCallback send;
  final VoidCallback? onMenuTap;
  final VoidCallback? onNewChat;

  const ChatContent({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.scrollController,
    required this.messages,
    required this.isThinking,
    required this.send,
    this.onMenuTap,
    this.onNewChat,
  });

  @override
  State<ChatContent> createState() => _ChatContentState();
}

class _ChatContentState extends State<ChatContent> {
  bool _showScrollButton = false;
  double _lastKeyboardInset = 0;

  @override
  void initState() {
    super.initState();
    widget.scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    widget.scrollController.removeListener(_onScroll);
    super.dispose();
  }

  void _onScroll() {
    if (!widget.scrollController.hasClients) return;
    final pos = widget.scrollController.position;
    final dist = pos.maxScrollExtent - pos.pixels;
    final visible = dist > 80;
    if (visible != _showScrollButton) {
      setState(() => _showScrollButton = visible);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final inset = MediaQuery.of(context).viewInsets.bottom;

    if (inset > _lastKeyboardInset &&
        widget.scrollController.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !widget.scrollController.hasClients) return;
        final pos = widget.scrollController.position;
        if ((pos.maxScrollExtent - pos.pixels) < 300) {
          widget.scrollController.animateTo(
            pos.maxScrollExtent,
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic,
          );
        }
      });
    }

    _lastKeyboardInset = inset;
  }

  void _scrollToBottom() {
    if (!widget.scrollController.hasClients) return;
    // Delay by one frame so the maxScrollExtent is perfectly accurate
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !widget.scrollController.hasClients) return;
      widget.scrollController.animateTo(
        widget.scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutQuart,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final keyboardInset = MediaQuery.of(context).viewInsets.bottom;
    const inputBarHeight = 76.0;
    const headerHeight = 105.0;

    return SafeArea(
      child: Stack(
        children: [
          // ── Message list ───────────────────────────────────────────────
          Column(
            children: [
              const SizedBox(height: headerHeight),
                      Expanded(
                        child: widget.messages.isEmpty
                            ? AnimatedPadding(
                                // Matches the speed of the keyboard and our input bar
                                duration: const Duration(milliseconds: 250),
                                curve: Curves.easeOutCubic,
                                padding: EdgeInsets.only(bottom: keyboardInset),
                                child: const EmptyState(),
                              )
                            : ListView.builder(
                                controller: widget.scrollController,
                                // Change this so the user can easily swipe down to close the keyboard
                                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                                physics: const BouncingScrollPhysics(
                                  parent: AlwaysScrollableScrollPhysics(),
                                ),
                        // Remove the bottom padding here, keep only top
                        padding: const EdgeInsets.only(top: 35),
                        itemCount: widget.messages.length + 1, // +1 for our animated spacer
                        itemBuilder: (context, index) {
                          // Add the spacer at the very end
                          if (index == widget.messages.length) {
                            return AnimatedContainer(
                              duration: const Duration(milliseconds: 250),
                              curve: Curves.easeOutCubic,
                              height: keyboardInset > 0
                                  ? keyboardInset + inputBarHeight + 60
                                  : inputBarHeight + 30,
                            );
                          }
                          return MessageAppear(
                            key: ValueKey(widget.messages[index].id),
                            child: MessageBubble(
                              message: widget.messages[index],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),

          // ── Header ────────────────────────────────────────────────────
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: NyxHeader(
              active: widget.isThinking,
              onMenuTap: widget.onMenuTap,
              onNewChat: widget.onNewChat,
            ),
          ),

          // ── Scroll-to-bottom button ────────────────────────────────────
          AnimatedPositioned(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            right: 20,
            bottom: keyboardInset + inputBarHeight + 24,
            child: IgnorePointer(
              ignoring: !_showScrollButton,
              child: AnimatedScale(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutBack,
                scale: _showScrollButton ? 1.0 : 0.6,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: _showScrollButton ? 1.0 : 0.0,
                  child: GestureDetector(
                    onTap: _scrollToBottom,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(100),
                      child: BackdropFilter(
                        filter:
                            ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                        child: Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(.05),
                            borderRadius: BorderRadius.circular(100),
                            border: Border.all(
                              color: Colors.white.withOpacity(.10),
                            ),
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.keyboard_arrow_down_rounded,
                              color: Colors.white70,
                              size: 26,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ── Input bar ─────────────────────────────────────────────────
          AnimatedPositioned(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            left: 0,
            right: 0,
            bottom: keyboardInset,
            child: AnimatedInputBar(
              controller: widget.controller,
              focusNode: widget.focusNode,
              send: widget.send,
              busy: widget.isThinking,
            ),
          ),
        ],
      ),
    );
  }
}
```

# screens\chat_screen.dart

```dart
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../models/chat_message.dart';
import '../models/conversation.dart';
import '../prompts/personality_prompt.dart';
import '../services/llm_service.dart';
import '../services/storage_service.dart';
import '../widgets/history_drawer.dart';
import '../widgets/liquid_background.dart';
import 'chat_content.dart';

class ChatScreen extends StatefulWidget {
  final StorageService storage;
  final LLMService llm;

  const ChatScreen({
    super.key,
    required this.storage,
    required this.llm,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen>
    with SingleTickerProviderStateMixin {
  static const _uuid = Uuid();

  // ── Controllers ───────────────────────────────────────────────────────────
  final _textController = TextEditingController();
  final _inputFocusNode = FocusNode();
  final _scrollController = ScrollController();

  // ── Drawer animation ──────────────────────────────────────────────────────
  late final AnimationController _drawerController;
  late final Animation<Offset> _drawerSlide;
  late final Animation<double> _drawerFade;
  bool _drawerOpen = false;

  // ── State ─────────────────────────────────────────────────────────────────
  List<Conversation> _conversations = [];
  Conversation? _activeConversation;
  bool _isThinking = false;
  bool _shouldAutoScroll = true;

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();

    _drawerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _drawerSlide = Tween<Offset>(
      begin: const Offset(-1, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
        parent: _drawerController, curve: Curves.easeOutCubic));
    _drawerFade = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(
            parent: _drawerController, curve: Curves.easeOut));

    _scrollController.addListener(_onScroll);
    _loadConversations();
  }

  @override
  void dispose() {
    _textController.dispose();
    _inputFocusNode.dispose();
    _scrollController.dispose();
    _drawerController.dispose();
    super.dispose();
  }

  // ── Scroll ────────────────────────────────────────────────────────────────

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final dist = _scrollController.position.maxScrollExtent -
        _scrollController.offset;
    _shouldAutoScroll = dist < 150;
  }

  void _scrollToBottom({bool force = false}) {
    if (!force && !_shouldAutoScroll) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: force ? const Duration(milliseconds: 420) : const Duration(milliseconds: 80),
        curve: force ? Curves.easeOutQuart : Curves.linear,
      );
    });
  }

  void _smallScrollDown() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    _scrollController.animateTo(
      (pos.pixels + 80).clamp(0.0, pos.maxScrollExtent),
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
    );
  }

  // ── Drawer ────────────────────────────────────────────────────────────────

  void _openDrawer() {
    _inputFocusNode.unfocus();
    setState(() => _drawerOpen = true);
    _drawerController.forward();
  }

  void _closeDrawer() {
    _drawerController.reverse().then((_) {
      if (mounted) setState(() => _drawerOpen = false);
    });
  }

  // ── Conversation management ───────────────────────────────────────────────

  Future<void> _loadConversations() async {
    final convs = await widget.storage.loadConversations();
    setState(() => _conversations = convs);
  }

  /// Creates a fresh conversation and makes it active.
  Future<void> _startNewConversation() async {
    // Unload messages from the previous active conversation to free memory.
    _activeConversation?.messages = null;

    final now = DateTime.now();
    final conv = Conversation(
      id: _uuid.v4(),
      title: 'New conversation',
      createdAt: now,
      updatedAt: now,
      messages: [],
    );

    await widget.storage.saveConversation(conv);

    setState(() {
      _conversations.insert(0, conv);
      _activeConversation = conv;
      _isThinking = false;
    });

    _textController.clear();
    // Scroll to top for fresh chat.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0);
      }
    });
  }

  /// Opens an existing conversation, lazily loading its messages.
  Future<void> _openConversation(Conversation conv) async {
    // Unload previous to free memory.
    _activeConversation?.messages = null;

    // Load messages only if not already in memory.
    if (conv.messages == null) {
      final msgs = await widget.storage.loadMessages(conv.id);
      conv.messages = msgs;
    }

    setState(() {
      _activeConversation = conv;
      _isThinking = false;
    });

    _textController.clear();
    _scrollToBottom(force: true);
  }

  Future<void> _deleteConversation(Conversation conv) async {
    await widget.storage.deleteConversation(conv.id);

    setState(() {
      _conversations.remove(conv);
      if (_activeConversation?.id == conv.id) {
        _activeConversation = null;
      }
    });
  }

  // ── Auto-title ────────────────────────────────────────────────────────────

  /// Sets the conversation title from the first user message.
  Future<void> _autoTitle(Conversation conv, String firstMessage) async {
    final title = firstMessage.length > 40
        ? '${firstMessage.substring(0, 38)}…'
        : firstMessage;

    conv.title = title;
    await widget.storage.updateConversationTitle(conv.id, title);

    setState(() {}); // rebuild drawer tile
  }

  // ── Send ──────────────────────────────────────────────────────────────────

  Future<void> _sendMessage() async {
    if (_isThinking) return;

    final text = _textController.text.trim();
    if (text.isEmpty) return;

    // ── 1. Close keyboard & wait for retreat ──────────────────────────────
    // If the keyboard is open, close it and wait for the animation to finish
    // (Flutter's keyboard animation takes roughly 250ms, so we wait 300ms to be safe)
    if (_inputFocusNode.hasFocus) {
      _inputFocusNode.unfocus();
      await Future.delayed(const Duration(milliseconds: 300));
    }

    // Create a conversation if there isn't one active.
    if (_activeConversation == null) {
      await _startNewConversation();
    }

    final conv = _activeConversation!;
    final isFirstMessage = conv.loadedMessages.isEmpty;

    // ── 2. User bubble ────────────────────────────────────────────────────
    final userMsg = ChatMessage(
      id: _uuid.v4(),
      conversationId: conv.id,
      text: text,
      isUser: true,
    );

    setState(() {
      conv.messages!.add(userMsg);
      _isThinking = true;
    });

    _textController.clear();
    _scrollToBottom(force: true);

    // Persist user message.
    await widget.storage.saveMessage(userMsg);

    // Auto-title on first message.
    if (isFirstMessage) await _autoTitle(conv, text);

    await Future.delayed(const Duration(milliseconds: 350));
    // ── 3. Build context window for LLM ───────────────────────────────────
    final context = await widget.storage.buildContextWindow(conv.id);

    // ── 4. Assistant bubble ───────────────────────────────────────────────
    final assistantMsg = ChatMessage(
      id: _uuid.v4(),
      conversationId: conv.id,
      text: '',
      isUser: false,
      streaming: true,
    );

    setState(() {
      _isThinking = false;
      conv.messages!.add(assistantMsg);
    });

    _scrollToBottom(force: true);

    // ── 5. Stream tokens ──────────────────────────────────────────────────
    final stream = widget.llm.streamResponse(
      userMessage: text,
      context: context,
      systemPrompt: personalityPrompt,
    );

    await for (final chunk in stream) {
      if (!mounted) return;
      setState(() => assistantMsg.text += chunk);
      _scrollToBottom();
    }

    // ── 6. Finalise ───────────────────────────────────────────────────────
    setState(() => assistantMsg.streaming = false);

    // Persist the complete assistant message.
    await widget.storage.saveMessage(assistantMsg);

    _scrollToBottom();
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final messages = _activeConversation?.loadedMessages ?? [];

    return PopScope(
      canPop: !_drawerOpen &&
          MediaQuery.of(context).viewInsets.bottom == 0,
      onPopInvokedWithResult: (_, __) {
        if (_drawerOpen) {
          _closeDrawer();
        } else {
          FocusScope.of(context).unfocus();
        }
      },
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        body: Stack(
          children: [
            // ── Background ───────────────────────────────────────────────
            const Positioned.fill(
              child: LiquidBackground(child: SizedBox()),
            ),

            // ── Chat ─────────────────────────────────────────────────────
            ChatContent(
              controller: _textController,
              focusNode: _inputFocusNode,
              scrollController: _scrollController,
              messages: messages,
              isThinking: _isThinking,
              send: _sendMessage,
              onMenuTap: _openDrawer,
              onNewChat: _startNewConversation,
            ),

            // ── Drawer scrim ─────────────────────────────────────────────
            if (_drawerOpen)
              FadeTransition(
                opacity: _drawerFade,
                child: GestureDetector(
                  onTap: _closeDrawer,
                  child: Container(
                    color: Colors.black.withOpacity(.45),
                  ),
                ),
              ),

            // ── Drawer panel ─────────────────────────────────────────────
            if (_drawerOpen)
              Positioned(
                top: 0,
                left: 0,
                bottom: 0,
                child: SlideTransition(
                  position: _drawerSlide,
                  child: HistoryDrawer(
                    conversations: _conversations,
                    activeConversationId: _activeConversation?.id,
                    onSelect: _openConversation,
                    onNewChat: () {
                      _closeDrawer();
                      _startNewConversation();
                    },
                    onDelete: _deleteConversation,
                    onClose: _closeDrawer,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
```

# services\llm_service.dart

```dart
/// Interface for local LLM inference.
///
/// The app runs 100 % offline.  This service is a stub that simulates
/// streaming responses.  When you integrate a real model (e.g. Gemma 3
/// via `flutter_gemma`, `llama.cpp` FFI, or MediaPipe LLM Inference API)
/// replace [_simulatedStream] with the model's token stream.
///
/// The [Stream<String>] contract: each event is one token / word chunk.
/// The caller accumulates them into the message bubble in real time.
///
/// Memory note: context is passed in from StorageService.buildContextWindow()
/// so this service itself holds no history state.
class LLMService {
  // ── Public API ────────────────────────────────────────────────────────────

  /// Returns a stream of token chunks for a given user prompt and context.
  ///
  /// [context] is a list of recent turns in chronological order:
  ///   [{'role': 'user'|'assistant', 'content': '...'}]
  ///
  /// [systemPrompt] is the personality/instruction prefix.
  Stream<String> streamResponse({
    required String userMessage,
    required List<Map<String, String>> context,
    required String systemPrompt,
  }) {
    // ── Stub ──────────────────────────────────────────────────────────────
    // Replace the body of this method with your real model call.
    //
    // flutter_gemma example (once the package is added):
    //
    //   final gemma = FlutterGemma.instance;
    //   return gemma.streamResponse(
    //     message: userMessage,
    //     history: context,
    //   );
    //
    // MediaPipe LLM Inference example:
    //
    //   final session = await LlmInference.createFromOptions(...);
    //   return session.generateResponseStream(
    //     _buildPromptString(systemPrompt, context, userMessage),
    //   );

    return _simulatedStream(userMessage);
  }

  // ── Simulation ────────────────────────────────────────────────────────────

  Stream<String> _simulatedStream(String input) async* {
    // Short think delay before first token.
    await Future.delayed(const Duration(milliseconds: 400));

    const replies = [
      "That's a fascinating point. I've been thinking about that too.",
      "Interesting — tell me more about what you mean by that.",
      "Good question. Let me think through this carefully for you.",
      "I understand. Here's how I see it:",
    ];

    final reply = replies[input.length % replies.length];

    for (final word in reply.split(' ')) {
      await Future.delayed(const Duration(milliseconds: 70));
      yield '$word ';
    }
  }

  // ── Prompt formatting (for models that need a single string) ──────────────

  /// Builds a plain-text prompt string from context + new user message.
  /// Useful for models that don't accept a structured message list.
  String buildPromptString(
    String systemPrompt,
    List<Map<String, String>> context,
    String userMessage,
  ) {
    final buffer = StringBuffer();
    buffer.writeln('<system>$systemPrompt</system>');
    for (final turn in context) {
      final role = turn['role'] == 'user' ? 'User' : 'Nyx';
      buffer.writeln('$role: ${turn['content']}');
    }
    buffer.writeln('User: $userMessage');
    buffer.writeln('Nyx:');
    return buffer.toString();
  }
}
```

# services\prompt_service.dart

```dart

```

# services\storage_service.dart

```dart
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
```

# theme\app_theme.dart

```dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static ThemeData dark = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,

    scaffoldBackgroundColor: const Color(0xff090B10),

    splashFactory: NoSplash.splashFactory,

    colorScheme: const ColorScheme.dark(
      primary: Color(0xff9A7CFF),
      secondary: Color(0xffB388FF),
      surface: Color(0xff111318),
    ),

    textTheme: GoogleFonts.interTextTheme(
      ThemeData.dark().textTheme,
    ).apply(
      bodyColor: Colors.white,
      displayColor: Colors.white,
    ),

    dividerColor: Colors.white10,

    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
    ),
  );
}
```

# widgets\animated_input_bar.dart

```dart
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';

class AnimatedInputBar extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback send;
  final bool busy;

  const AnimatedInputBar({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.send,
    required this.busy,
  });

  @override
  State<AnimatedInputBar> createState() => _AnimatedInputBarState();
}

class _AnimatedInputBarState extends State<AnimatedInputBar>
    with SingleTickerProviderStateMixin {
  // Spinner animation for the "busy" state.
  late final AnimationController _spinController;

  // Tracks whether there is text — used to show/hide the send button.
  bool _hasText = false;

  @override
  void initState() {
    super.initState();

    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    widget.controller.addListener(_onTextChanged);
    _hasText = widget.controller.text.isNotEmpty;
  }

  void _onTextChanged() {
    final has = widget.controller.text.trim().isNotEmpty;
    if (has != _hasText) setState(() => _hasText = has);
  }

  @override
  void didUpdateWidget(AnimatedInputBar oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Start / stop the spinner based on busy state.
    if (widget.busy && !_spinController.isAnimating) {
      _spinController.repeat();
    } else if (!widget.busy && _spinController.isAnimating) {
      _spinController.stop();
    }
  }

  @override
  void dispose() {
    _spinController.dispose();
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
          child: Container(
            constraints: const BoxConstraints(minHeight: 60),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(32),
              color: Colors.white.withOpacity(.035),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _iconButton(
                    icon: Icons.add,
                    onTap: widget.busy ? null : () {},
                  ),

                  const SizedBox(width: 4),

                  // ── Text field ──────────────────────────────────────────
                  Expanded(
                    child: TextField(
                      controller: widget.controller,
                      focusNode: widget.focusNode,
                      readOnly: widget.busy,
                      minLines: 1,
                      maxLines: 5,
                      cursorColor: Colors.white70,
                      textCapitalization: TextCapitalization.sentences,
                      style: const TextStyle(fontSize: 16, height: 1.45),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        isCollapsed: true,
                        hintText: 'Ask anything',
                        hintStyle: TextStyle(color: Colors.white38),
                      ),
                    ),
                  ),

                  // ── Mic / hidden placeholder ───────────────────────────
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: (widget.busy || _hasText)
                        ? const SizedBox(key: ValueKey('mic-hidden'), width: 44, height: 44)
                        : _iconButton(
                            key: const ValueKey('mic'),
                            icon: Icons.mic_none_rounded,
                            onTap: () {},
                          ),
                  ),

                  const SizedBox(width: 4),

                  // ── Send / busy button ─────────────────────────────────
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 260),
                    curve: Curves.easeOutCubic,
                    width: widget.busy ? 40 : 44,
                    height: widget.busy ? 40 : 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: widget.busy ? Colors.transparent : Colors.white,
                      border: widget.busy
                          ? Border.all(
                              color: const Color(0xff8D6CFF),
                              width: 2,
                            )
                          : null,
                    ),
                    child: Material(
                      color: Colors.transparent,
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: widget.busy
                            ? null
                            : () {
                                widget.focusNode.unfocus();
                                widget.send();
                              },
                        child: Center(
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 220),
                            transitionBuilder: (child, animation) {
                              return ScaleTransition(
                                scale: animation,
                                child: FadeTransition(
                                  opacity: animation,
                                  child: child,
                                ),
                              );
                            },
                            child: widget.busy
                                ? _SpinningIcon(
                                    key: const ValueKey('busy'),
                                    controller: _spinController,
                                  )
                                : const Icon(
                                    Icons.arrow_upward_rounded,
                                    key: ValueKey('send'),
                                    color: Colors.black,
                                    size: 22,
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _iconButton({
    Key? key,
    required IconData icon,
    VoidCallback? onTap,
  }) {
    return SizedBox(
      key: key,
      width: 44,
      height: 44,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onTap,
          child: Center(
            child: Icon(icon, size: 22, color: Colors.white54),
          ),
        ),
      ),
    );
  }
}

// ── Spinning icon extracted so its AnimationController lives outside ─────────
class _SpinningIcon extends StatelessWidget {
  final AnimationController controller;

  const _SpinningIcon({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) => Transform.rotate(
        angle: controller.value * 2 * math.pi,
        child: const Icon(
          Icons.circle_outlined,
          size: 18,
          color: Color(0xffB388FF),
        ),
      ),
    );
  }
}
```

# widgets\breathing_orb.dart

```dart
import 'package:flutter/material.dart';

class BreathingOrb extends StatefulWidget {
  final double size;

  const BreathingOrb({
    super.key,
    this.size = 18,
  });

  @override
  State<BreathingOrb> createState() =>
      _BreathingOrbState();
}

class _BreathingOrbState
    extends State<BreathingOrb>
    with SingleTickerProviderStateMixin {
  late AnimationController controller;

  @override
  void initState() {
    super.initState();

    controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
      lowerBound: .85,
      upperBound: 1,
    )..repeat(reverse: true);
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: controller,
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            colors: [
              Color(0xff7C4DFF),
              Color(0xffB388FF),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(
                0xff9A7CFF,
              ).withOpacity(.6),
              blurRadius: 20,
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }
}
```

# widgets\empty_state.dart

```dart
import 'package:flutter/material.dart';
import 'breathing_orb.dart';

class EmptyState extends StatelessWidget {
  const EmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          BreathingOrb(
            size: 42,
          ),

          SizedBox(height: 30),

          Text(
            "How can I help?",
            style: TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w600,
              letterSpacing: -.7,
            ),
          ),

          SizedBox(height: 12),

          Text(
            "Ask anything",
            style: TextStyle(
              fontSize: 15,
              color: Colors.white54,
            ),
          ),
        ],
      ),
    );
  }
}
```

# widgets\history_drawer.dart

```dart
import 'dart:ui';
import 'package:flutter/material.dart';
import '../models/conversation.dart';

class HistoryDrawer extends StatefulWidget {
  final List<Conversation> conversations;
  final String? activeConversationId;
  final void Function(Conversation) onSelect;
  final VoidCallback onNewChat;
  final void Function(Conversation) onDelete;
  final VoidCallback onClose;

  const HistoryDrawer({
    super.key,
    required this.conversations,
    required this.activeConversationId,
    required this.onSelect,
    required this.onNewChat,
    required this.onDelete,
    required this.onClose,
  });

  @override
  State<HistoryDrawer> createState() => _HistoryDrawerState();
}

class _HistoryDrawerState extends State<HistoryDrawer> {
  // ── Grouping helpers ──────────────────────────────────────────────────────

  static const _groupLabels = ['Today', 'Yesterday', 'This week', 'Earlier'];

  Map<String, List<Conversation>> _grouped() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final weekAgo = today.subtract(const Duration(days: 7));

    final groups = <String, List<Conversation>>{
      'Today': [],
      'Yesterday': [],
      'This week': [],
      'Earlier': [],
    };

    for (final c in widget.conversations) {
      final d = DateTime(
          c.updatedAt.year, c.updatedAt.month, c.updatedAt.day);
      if (!d.isBefore(today)) {
        groups['Today']!.add(c);
      } else if (!d.isBefore(yesterday)) {
        groups['Yesterday']!.add(c);
      } else if (!d.isBefore(weekAgo)) {
        groups['This week']!.add(c);
      } else {
        groups['Earlier']!.add(c);
      }
    }
    return groups;
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final groups = _grouped();
    final safeTop = MediaQuery.of(context).padding.top;

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 32, sigmaY: 32),
        child: Container(
          width: 300,
          height: double.infinity,
          decoration: BoxDecoration(
            color: const Color(0xff090B10).withOpacity(.82),
            border: Border(
              right: BorderSide(
                color: Colors.white.withOpacity(.07),
              ),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(height: safeTop + 12),

              // ── Header ─────────────────────────────────────────────────
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    // Close button
                    _HeaderButton(
                      icon: Icons.menu_open_rounded,
                      onTap: widget.onClose,
                    ),
                    const SizedBox(width: 10),
                    ShaderMask(
                      shaderCallback: (b) =>
                          const LinearGradient(colors: [
                        Color(0xffEAE4FF),
                        Color(0xffB388FF),
                      ]).createShader(b),
                      child: const Text(
                        'Nyx',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          letterSpacing: .2,
                        ),
                      ),
                    ),
                    const Spacer(),
                    // New chat button
                    _HeaderButton(
                      icon: Icons.edit_outlined,
                      onTap: widget.onNewChat,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // ── Conversation list ───────────────────────────────────────
              Expanded(
                child: widget.conversations.isEmpty
                    ? _EmptyHistory()
                    : ListView(
                        padding:
                            const EdgeInsets.only(bottom: 24),
                        children: [
                          for (final label in _groupLabels)
                            if ((groups[label] ?? []).isNotEmpty) ...[
                              _GroupLabel(label: label),
                              for (final conv
                                  in groups[label]!)
                                _ConversationTile(
                                  conversation: conv,
                                  isActive: conv.id ==
                                      widget.activeConversationId,
                                  onTap: () {
                                    widget.onSelect(conv);
                                    widget.onClose();
                                  },
                                  onDelete: () =>
                                      widget.onDelete(conv),
                                ),
                            ],
                        ],
                      ),
              ),

              // ── Footer ─────────────────────────────────────────────────
              _DrawerFooter(),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _HeaderButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _HeaderButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 38,
      height: 38,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Center(
            child: Icon(icon, size: 20, color: Colors.white60),
          ),
        ),
      ),
    );
  }
}

class _GroupLabel extends StatelessWidget {
  final String label;
  const _GroupLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Row(
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: Colors.white38,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.white.withOpacity(.08),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConversationTile extends StatefulWidget {
  final Conversation conversation;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _ConversationTile({
    required this.conversation,
    required this.isActive,
    required this.onTap,
    required this.onDelete,
  });

  @override
  State<_ConversationTile> createState() => _ConversationTileState();
}

class _ConversationTileState extends State<_ConversationTile> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onLongPress: () => _showDeleteDialog(context),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            // Give the active tile a beautiful soft purple glow
            color: widget.isActive
                ? const Color(0xff8D6CFF).withOpacity(.12)
                : _hovering
                    ? Colors.white.withOpacity(.04)
                    : Colors.transparent,
            border: Border.all(
              color: widget.isActive
                  ? const Color(0xff8D6CFF).withOpacity(.25)
                  : Colors.transparent,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: widget.onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                child: Row(
                  children: [
                    Icon(
                      Icons.chat_bubble_outline_rounded,
                      size: 16,
                      color: widget.isActive
                          ? const Color(0xffB388FF)
                          : Colors.white30,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.conversation.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          color: widget.isActive ? Colors.white : Colors.white70,
                          fontWeight: widget.isActive ? FontWeight.w500 : FontWeight.w400,
                        ),
                      ),
                    ),
                    if (_hovering || widget.isActive)
                      GestureDetector(
                        onTap: () => _showDeleteDialog(context),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.black26,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Icon(
                            Icons.delete_outline_rounded,
                            size: 14,
                            color: Colors.white54,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
  void _showDeleteDialog(BuildContext context) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black.withOpacity(0.6),
      transitionDuration: const Duration(milliseconds: 350),
      pageBuilder: (context, animation, secondaryAnimation) {
        return Center(
          child: Material(
            color: Colors.transparent,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: const Color(0xff1A1B22).withOpacity(0.65),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.1),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.4),
                          blurRadius: 30,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // ── Animated Icon Container ──
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: const Color.fromARGB(255, 146, 16, 233).withOpacity(0.1),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color.fromARGB(255, 146, 16, 233).withOpacity(0.2),
                            ),
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.delete_sweep_rounded,
                              color: const Color.fromARGB(255, 146, 16, 233),
                              size: 28,
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 20),
                        
                        const Text(
                          'Delete conversation?',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.5,
                          ),
                        ),
                        
                        const SizedBox(height: 10),
                        
                        const Text(
                          'This action cannot be undone. Are you sure you want to permanently remove this chat?',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white54,
                            fontSize: 14,
                            height: 1.4,
                          ),
                        ),
                        
                        const SizedBox(height: 28),
                        
                        // ── Action Buttons ──
                        Row(
                          children: [
                            Expanded(
                              child: _GlassDialogButton(
                                text: 'Cancel',
                                onTap: () => Navigator.pop(context),
                                isDestructive: false,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _GlassDialogButton(
                                text: 'Delete',
                                onTap: () {
                                  Navigator.pop(context);
                                  widget.onDelete();
                                },
                                isDestructive: true,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
      
      // ── Custom Pop-in Animation ──
      transitionBuilder: (context, anim, secondaryAnim, child) {
        return ScaleTransition(
          scale: Tween<double>(begin: 0.9, end: 1.0).animate(
            CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
          ),
          child: FadeTransition(
            opacity: Tween<double>(begin: 0.0, end: 1.0).animate(
              CurvedAnimation(parent: anim, curve: Curves.easeOut),
            ),
            child: child,
          ),
        );
      },
    );
  }
}
class _EmptyHistory extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.history_rounded,
              size: 36, color: Colors.white12),
          const SizedBox(height: 12),
          const Text(
            'No conversations yet',
            style: TextStyle(
              color: Colors.white24,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

// ── 3. Upgraded Footer Control Pill ─────────────────────────────────────────
class _DrawerFooter extends StatefulWidget {
  @override
  State<_DrawerFooter> createState() => _DrawerFooterState();
}

class _DrawerFooterState extends State<_DrawerFooter> with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 8, 16, MediaQuery.of(context).padding.bottom + 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(.03),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(.08)),
            ),
            child: Row(
              children: [
                // Glowing Status Dot
                AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    return Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xff4ADE80), // Emerald green
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xff4ADE80).withOpacity(_pulseController.value * 0.6),
                            blurRadius: 8,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(width: 12),
                
                // System Info
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Nyx Engine',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.2,
                        ),
                      ),
                      Text(
                        'Local Inference Ready',
                        style: TextStyle(
                          color: Colors.white38,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Placeholder Settings Button
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () {
                      // TODO: Open settings sheet
                    },
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(.05),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.tune_rounded,
                        size: 16,
                        color: Colors.white70,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GlassDialogButton extends StatelessWidget {
  final String text;
  final VoidCallback onTap;
  final bool isDestructive;

  const _GlassDialogButton({
    required this.text,
    required this.onTap,
    required this.isDestructive,
  });

  @override
  Widget build(BuildContext context) {
    final baseColor = isDestructive ? const Color.fromARGB(255, 146, 16, 233) : Colors.white;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: baseColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: baseColor.withOpacity(0.2),
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          text,
          style: TextStyle(
            color: baseColor,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
```

# widgets\intelligence_orb.dart

```dart
import 'dart:math';
import 'package:flutter/material.dart';

class IntelligenceOrb extends StatefulWidget {
  final double size;
  final bool active;

  const IntelligenceOrb({
    super.key,
    this.size = 54,
    this.active = false,
  });

  @override
  State<IntelligenceOrb> createState() =>
      _IntelligenceOrbState();
}

class _IntelligenceOrbState extends State<IntelligenceOrb>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller;

  @override
  void initState() {
    super.initState();

    controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) {
        final t = controller.value * 2 * pi;

        final pulse = widget.active
            ? 1 + .07 * sin(t * 2)
            : 1 + .03 * sin(t);

        return Transform.scale(
          scale: pulse,
          child: SizedBox(
            width: widget.size,
            height: widget.size,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // outer glow
                Container(
                  width: widget.size,
                  height: widget.size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(
                          0xff8D6CFF,
                        ).withOpacity(
                          widget.active ? .45 : .25,
                        ),
                        blurRadius:
                            widget.active ? 40 : 25,
                      ),
                    ],
                  ),
                ),

                // middle layer
                Container(
                  width: widget.size * .7,
                  height: widget.size * .7,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        Colors.white.withOpacity(.95),
                        const Color(
                          0xffBBA8FF,
                        ),
                        const Color(
                          0xff7A5BFF,
                        ),
                      ],
                    ),
                  ),
                ),

                // core
                Container(
                  width: widget.size * .25,
                  height: widget.size * .25,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.white
                            .withOpacity(.9),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                ),

                // orbiting particles
                ...List.generate(3, (i) {
                  final angle =
                      t + i * (2 * pi / 3);

                  return Transform.translate(
                    offset: Offset(
                      cos(angle) *
                          widget.size *
                          .45,
                      sin(angle) *
                          widget.size *
                          .45,
                    ),
                    child: Container(
                      width: 4,
                      height: 4,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white
                            .withOpacity(.8),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }
}
```

# widgets\liquid_background.dart

```dart
import 'dart:math';
import 'package:flutter/material.dart';

class LiquidBackground extends StatefulWidget {
  final Widget child;

  const LiquidBackground({
    super.key,
    required this.child,
  });

  @override
  State<LiquidBackground> createState() => _LiquidBackgroundState();
}

class _LiquidBackgroundState extends State<LiquidBackground>
    with SingleTickerProviderStateMixin {
  // Using AnimationController instead of Timer.periodic means the animation
  // is vsync-aligned (no wasted frames, no battery drain when off-screen).
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      // A longer duration feels organic; value goes 0→1 and we wrap it in sin/cos.
      duration: const Duration(seconds: 30),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Stack(
        children: [
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (_, __) => CustomPaint(
                // phase goes 0 → 2π continuously.
                painter: MeshPainter(_controller.value * 2 * pi),
              ),
            ),
          ),

          // Subtle dark overlay to keep text readable.
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                color: const Color(0xff090B10).withOpacity(.14),
              ),
            ),
          ),

          // Vignette gradient — heavier at the bottom where UI lives.
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      const Color(0xff090B10).withOpacity(.05),
                      Colors.transparent,
                      const Color(0xff090B10).withOpacity(.15),
                      const Color(0xff090B10).withOpacity(.55),
                      const Color(0xff090B10),
                    ],
                    stops: const [0, .15, .6, .85, 1],
                  ),
                ),
              ),
            ),
          ),

          widget.child,
        ],
      ),
    );
  }
}

class MeshPainter extends CustomPainter {
  final double p; // phase in radians (0 → 2π)

  MeshPainter(this.p);

  @override
  void paint(Canvas canvas, Size size) {
    _drawGlow(
      canvas,
      Offset(
        size.width * (.22 + .05 * sin(p * .7)),
        size.height * (.15 + .04 * cos(p * .9)),
      ),
      240,
      const Color(0xff8D6CFF).withOpacity(.18),
    );

    _drawGlow(
      canvas,
      Offset(
        size.width * (.82 + .04 * cos(p * .55)),
        size.height * (.24 + .06 * sin(p * .8)),
      ),
      210,
      Colors.indigo.withOpacity(.14),
    );

    _drawGlow(
      canvas,
      Offset(
        size.width * (.30 + .07 * sin(p * .45)),
        size.height * (.72 + .04 * cos(p * .65)),
      ),
      190,
      Colors.blue.withOpacity(.12),
    );

    _drawGlow(
      canvas,
      Offset(
        size.width * (.76 + .05 * cos(p * .6)),
        size.height * (.62 + .05 * sin(p * .7)),
      ),
      170,
      Colors.deepPurpleAccent.withOpacity(.10),
    );
  }

  void _drawGlow(Canvas canvas, Offset center, double radius, Color color) {
    final rect = Rect.fromCircle(center: center, radius: radius);
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [color, color.withOpacity(.35), Colors.transparent],
      ).createShader(rect);
    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(covariant MeshPainter oldDelegate) =>
      oldDelegate.p != p;
}
```

# widgets\message_appear.dart

```dart
import 'package:flutter/material.dart';

/// Wraps a new message bubble with a subtle fade + upward slide entrance.
/// Each bubble gets its own controller so they animate independently.
class MessageAppear extends StatefulWidget {
  final Widget child;

  const MessageAppear({
    super.key,
    required this.child,
  });

  @override
  State<MessageAppear> createState() => _MessageAppearState();
}

class _MessageAppearState extends State<MessageAppear>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );

    _opacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        // Fade in quickly, done by 60 % of the duration.
        curve: const Interval(0, 0.6, curve: Curves.easeOut),
      ),
    );

    _slide = Tween<Offset>(
      begin: const Offset(0, .12), // 12 % of the widget height
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutCubic,
      ),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(
        position: _slide,
        child: widget.child,
      ),
    );
  }
}
```

# widgets\message_bubble.dart

```dart
import 'package:flutter/material.dart';
import '../models/chat_message.dart';

class MessageBubble extends StatelessWidget {
  final ChatMessage message;

  const MessageBubble({
    super.key,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    const textStyle = TextStyle(
      fontSize: 16,
      height: 1.55,
      color: Colors.white,
      leadingDistribution: TextLeadingDistribution.even,
    );

    if (message.isUser) {
      final radius =
          message.text.length < 40 ? 999.0 : 28.0;

      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          constraints: const BoxConstraints(
            maxWidth: 300,
          ),
          margin: const EdgeInsets.fromLTRB(
            80,
            8,
            15,
            8,
          ),
          padding: const EdgeInsets.fromLTRB(
            18,
            15,
            18,
            13,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            gradient: const LinearGradient(
              colors: [
                Color(0xff9A7CFF),
                Color(0xff6E53FF),
              ],
            ),
          ),
          child: Text(
            message.text,
            style: textStyle,
          ),
        ),
      );
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: AnimatedContainer(
        duration: const Duration(
          milliseconds: 400,
        ),
        curve: Curves.easeOutCubic,
        constraints: const BoxConstraints(
          maxWidth: 340,
        ),
        margin: const EdgeInsets.fromLTRB(
          15,
          8,
          50,
          8,
        ),

        // Top slightly larger than bottom for visual centering
        padding: const EdgeInsets.fromLTRB(
          18,
          15,
          18,
          13,
        ),

        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          color: Colors.white.withOpacity(
            message.streaming ? 0 : .03,
          ),
          border: Border.all(
            color: const Color(
              0xff8D6CFF,
            ).withOpacity(
              message.streaming ? 0 : .08,
            ),
          ),
        ),

        child: RichText(
          text: TextSpan(
            style: textStyle,
            children: [
              TextSpan(
                text: message.text,
              ),

              if (message.streaming)
                WidgetSpan(
                  alignment:
                      PlaceholderAlignment.baseline,
                  baseline: TextBaseline.alphabetic,
                  child: _BlinkingCursor(),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BlinkingCursor extends StatefulWidget {
  const _BlinkingCursor();

  @override
  State<_BlinkingCursor> createState() =>
      _BlinkingCursorState();
}

class _BlinkingCursorState
    extends State<_BlinkingCursor>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller;

  @override
  void initState() {
    super.initState();

    controller = AnimationController(
      vsync: this,
      duration: const Duration(
        milliseconds: 700,
      ),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: controller,
      child: const Text(
        "|",
        style: TextStyle(
          fontSize: 16,
          height: 1.55,
          color: Colors.white70,
          fontWeight: FontWeight.w300,
        ),
      ),
    );
  }
}
```

# widgets\nyx_header.dart

```dart
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';

class NyxHeader extends StatefulWidget {
  final bool active;
  final VoidCallback? onMenuTap;
  final VoidCallback? onNewChat;

  const NyxHeader({
    super.key,
    this.active = false,
    this.onMenuTap,
    this.onNewChat,
  });

  @override
  State<NyxHeader> createState() => _NyxHeaderState();
}

class _NyxHeaderState extends State<NyxHeader>
    with TickerProviderStateMixin {
  late final AnimationController inner;
  late final AnimationController middle;
  late final AnimationController outer;

  @override
  void initState() {
    super.initState();
    inner = AnimationController(vsync: this,
        duration: const Duration(seconds: 10))
      ..repeat();
    middle = AnimationController(vsync: this,
        duration: const Duration(seconds: 16))
      ..repeat();
    outer = AnimationController(vsync: this,
        duration: const Duration(seconds: 24))
      ..repeat();
  }

  @override
  void dispose() {
    inner.dispose();
    middle.dispose();
    outer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // ── Menu button (left) ──────────────────────────────────────────
          _GlassIconButton(
            icon: Icons.menu_rounded,
            onTap: widget.onMenuTap,
          ),

          // ── Orb + name pill (centre) ────────────────────────────────────
          ClipRRect(
            borderRadius: BorderRadius.circular(100),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(.025),
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(
                      color: Colors.white.withOpacity(.05)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 36,
                      height: 36,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          AnimatedBuilder(
                            animation: outer,
                            builder: (_, __) => Transform(
                              alignment: Alignment.center,
                              transform: Matrix4.identity()
                                ..rotateZ(outer.value * 2 * math.pi)
                                ..rotateX(.95),
                              child:
                                  _ring(const Color(0xff6A4CFF), 32, 1.3),
                            ),
                          ),
                          AnimatedBuilder(
                            animation: middle,
                            builder: (_, __) => Transform(
                              alignment: Alignment.center,
                              transform: Matrix4.identity()
                                ..rotateZ(-middle.value * 2 * math.pi)
                                ..rotateX(.45),
                              child:
                                  _ring(const Color(0xff8D6CFF), 28, 1.5),
                            ),
                          ),
                          AnimatedBuilder(
                            animation: inner,
                            builder: (_, __) => Transform(
                              alignment: Alignment.center,
                              transform: Matrix4.identity()
                                ..rotateZ(inner.value * 2 * math.pi)
                                ..rotateX(-.65),
                              child:
                                  _ring(const Color(0xffB388FF), 24, 1.8),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    ShaderMask(
                      shaderCallback: (bounds) =>
                          const LinearGradient(colors: [
                        Color(0xffEAE4FF),
                        Color(0xffB388FF),
                      ]).createShader(bounds),
                      child: const Text(
                        'Nyx',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          letterSpacing: .3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── New chat button (right) ─────────────────────────────────────
          _GlassIconButton(
            icon: Icons.edit_outlined,
            onTap: widget.onNewChat,
          ),
        ],
      ),
    );
  }

  Widget _ring(Color color, double size, double width) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
            color: color.withOpacity(.95), width: width),
      ),
    );
  }
}

class _GlassIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _GlassIconButton({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(.04),
            borderRadius: BorderRadius.circular(14),
            border:
                Border.all(color: Colors.white.withOpacity(.07)),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: onTap,
              child: Center(
                child: Icon(icon, size: 20, color: Colors.white60),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
```

# widgets\typing_indicator.dart

```dart
import 'package:flutter/material.dart';

class TypingIndicator extends StatelessWidget {
  const TypingIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(
        left: 24,
        top: 10,
        bottom: 15,
      ),
      child: Row(
        children: [
          Icon(
            Icons.auto_awesome,
            size: 12,
            color: Color(0xffB388FF),
          ),
          SizedBox(width: 8),
          Text(
            "Nyx is thinking",
            style: TextStyle(
              fontSize: 13,
              color: Colors.white54,
            ),
          ),
        ],
      ),
    );
  }
}
```

