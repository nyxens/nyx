import 'package:flutter/material.dart';

import '../models/chat_message.dart';
import '../widgets/liquid_background.dart';
import 'chat_content.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final controller = TextEditingController();
  final inputFocusNode = FocusNode();
  final scrollController = ScrollController();

  final List<ChatMessage> messages = [];

  bool isThinking = false;
  bool shouldAutoScroll = true;

  @override
  void initState() {
    super.initState();

    scrollController.addListener(() {
      if (!scrollController.hasClients) return;

      final distance =
          scrollController.position.maxScrollExtent -
              scrollController.offset;

      shouldAutoScroll = distance < 150;
    });
  }

  Future<void> sendMessage() async {
    if (isThinking) return;

    final text = controller.text.trim();

    if (text.isEmpty) return;

    inputFocusNode.unfocus();

    setState(() {
      messages.add(
        ChatMessage(
          text: text,
          isUser: true,
        ),
      );

      isThinking = true;
    });

    controller.clear();

    smallScrollDown();

    await Future.delayed(
      const Duration(milliseconds: 600),
    );

    final assistantMessage = ChatMessage(
      text: "",
      isUser: false,
      streaming: true,
    );

    setState(() {
      messages.add(assistantMessage);
    });

    scrollDown();

    const response =
        "Interesting. Tell me more about that.";

    final words = response.split(" ");

    for (final word in words) {
      await Future.delayed(
        const Duration(milliseconds: 80),
      );

      if (!mounted) return;

      setState(() {
        assistantMessage.text +=
            assistantMessage.text.isEmpty
                ? word
                : " $word";
      });

      // scrollDown();
    }

    // Bubble materializes
    setState(() {
      assistantMessage.streaming = false;
    });

    await Future.delayed(
      const Duration(milliseconds: 250),
    );

    if (!mounted) return;

    // Remove thinking indicator
    setState(() {
      isThinking = false;
    });

    // Smooth final glide to bottom
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!scrollController.hasClients) return;
      if (!shouldAutoScroll) return;

      // scrollController.animateTo(
      //   scrollController.position.maxScrollExtent - 20,
      //   duration: const Duration(
      //     milliseconds: 500,
      //   ),
      //   curve: Curves.easeOutQuart,
      // );
    });
  }
  void smallScrollDown() {
    if (!scrollController.hasClients) return;

    final pos = scrollController.position;

    final target = (pos.pixels + 50)
        .clamp(
          0.0,
          pos.maxScrollExtent,
        );

    scrollController.animateTo(
      target,
      duration: const Duration(
        milliseconds: 600,
      ),
      curve: Curves.easeOutCubic,
    );
  }
  void scrollDown() {
    if (!shouldAutoScroll) return;

    Future.delayed(
      const Duration(milliseconds: 80),
      () {
        if (!mounted) return;
        if (!scrollController.hasClients) return;

        scrollController.animateTo(
          scrollController.position.maxScrollExtent,
          duration: const Duration(
            milliseconds: 500,
          ),
          curve: Curves.easeOutQuart,
        );
      },
    );
  }

  @override
  void dispose() {
    inputFocusNode.dispose();
    controller.dispose();
    scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: MediaQuery.of(context).viewInsets.bottom == 0,
      onPopInvokedWithResult: (_, __) {
        FocusScope.of(context).unfocus();
      },
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        body: Stack(
          children: [
            const Positioned.fill(
              child: LiquidBackground(
                child: SizedBox(),
              ),
            ),

            ChatContent(
              controller: controller,
              focusNode: inputFocusNode,
              scrollController: scrollController,
              messages: messages,
              isThinking: isThinking,
              send: sendMessage,
            ),
          ],
        ),
      ),
    );
  }
}