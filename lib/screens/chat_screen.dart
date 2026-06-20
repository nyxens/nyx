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