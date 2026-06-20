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