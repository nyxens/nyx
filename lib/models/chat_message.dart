class ChatMessage {
  String text;
  final bool isUser;
  bool streaming;
  ChatMessage({
    required this.text,
    required this.isUser,
    this.streaming = false,
  });
}