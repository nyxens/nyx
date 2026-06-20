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