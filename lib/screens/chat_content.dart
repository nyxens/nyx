import 'dart:ui';

import 'package:flutter/material.dart';

import '../models/chat_message.dart';
import '../widgets/animated_input_bar.dart';
import '../widgets/empty_state.dart';
import '../widgets/message_bubble.dart';
import '../widgets/nyx_header.dart';

class ChatContent extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final ScrollController scrollController;
  final List<ChatMessage> messages;
  final bool isThinking;
  final VoidCallback send;

  const ChatContent({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.scrollController,
    required this.messages,
    required this.isThinking,
    required this.send,
  });

  @override
  State<ChatContent> createState() => _ChatContentState();
}

class _ChatContentState extends State<ChatContent>
    with WidgetsBindingObserver {
  double _lastInset = 0;
  bool showScrollButton = false;

  @override
  void initState() {
    super.initState();

    widget.scrollController.addListener(() {
      if (!widget.scrollController.hasClients) return;

      final pos = widget.scrollController.position;

      final distanceFromBottom =
          pos.maxScrollExtent - pos.pixels;

      final visible = distanceFromBottom > 50;

      if (visible != showScrollButton) {
        setState(() {
          showScrollButton = visible;
        });
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final inset = MediaQuery.of(context).viewInsets.bottom;

    // if (inset > _lastInset) {
    //   WidgetsBinding.instance.addPostFrameCallback((_) {
    //     if (!widget.scrollController.hasClients) return;

    //     final pos = widget.scrollController.position;

    //     if ((pos.maxScrollExtent - pos.pixels) < 300) {
    //       widget.scrollController.animateTo(
    //         pos.maxScrollExtent - 30 ,
    //         duration: const Duration(
    //           milliseconds: 100,
    //         ),
    //         curve: Curves.easeOutQuart,
    //       );
    //     }
    //   });
    // }
    _lastInset = inset;
  }

  @override
  Widget build(BuildContext context) {
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;

    return SafeArea(
      child: Stack(
        children: [
          Column(
            children: [
              const SizedBox(
                height: 105,
              ),
              Expanded(
                child: widget.messages.isEmpty
                    ? const EmptyState()
                    : ListView.builder(
                        controller: widget.scrollController,
                        physics: const BouncingScrollPhysics(),
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.manual,
                        padding: EdgeInsets.only(
                          top: 35,
                          bottom: keyboardHeight > 0
                              ? keyboardHeight + 110
                              : 100,
                        ),
                        itemCount: widget.messages.length,
                        itemBuilder: (context, index) {
                          return MessageBubble(
                            message: widget.messages[index],
                          );
                        },
                      ),
              ),
            ],
          ),

          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Center(
              child: NyxHeader(),
            ),
          ),

          Positioned(
            right: 20,
            bottom: keyboardHeight + 110,
            child: IgnorePointer(
              ignoring: !showScrollButton,
              child: AnimatedScale(
                duration: const Duration(
                  milliseconds: 200,
                ),
                curve: Curves.easeOut,
                scale: showScrollButton ? 1 : .7,
                child: AnimatedOpacity(
                  duration: const Duration(
                    milliseconds: 200,
                  ),
                  opacity: showScrollButton ? 1 : 0,
                  child: GestureDetector(
                    onTap: () {
                      widget.scrollController.animateTo(
                        widget.scrollController.position.maxScrollExtent,
                        duration: const Duration(
                          milliseconds: 500,
                        ),
                        curve: Curves.easeOutQuart,
                      );
                    },
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(100),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(
                          sigmaX: 20,
                          sigmaY: 20,
                        ),
                        child: Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(.03),
                            borderRadius: BorderRadius.circular(100),
                            border: Border.all(
                              color: Colors.white.withOpacity(.06),
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

          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: AnimatedPadding(
              duration: const Duration(
                milliseconds: 220,
              ),
              curve: Curves.easeOutCubic,
              padding: EdgeInsets.only(
                bottom: keyboardHeight,
              ),
              child: AnimatedInputBar(
                controller: widget.controller,
                focusNode: widget.focusNode,
                send: widget.send,
                busy: widget.isThinking,
              ),
            ),
          ),
        ],
      ),
    );
  }
}