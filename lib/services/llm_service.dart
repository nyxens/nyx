import 'dart:convert';
import 'package:http/http.dart' as http;

class LLMService {
  // Paste your Groq API Key here
  static const String _apiKey = String.fromEnvironment(
    'GROQ_API_KEY', 
    defaultValue: 'KEY_NOT_FOUND'
  );
  
  // We will use Meta's lightning-fast 8B model
  static const String _model = 'openai/gpt-oss-20b'; 

  Stream<String> streamResponse({
    required String userMessage,
    required List<Map<String, String>> context,
    required String systemPrompt,
  }) async* {
    
    // 1. Format the messages for the API
    final List<Map<String, dynamic>> messages = [];
    
    // Inject personality
    messages.add({'role': 'system', 'content': systemPrompt});
    
    // Inject local SQLite history
    for (final turn in context) {
      messages.add({
        'role': turn['role'] == 'user' ? 'user' : 'assistant',
        'content': turn['content'],
      });
    }
    
    // Add the current message
    messages.add({'role': 'user', 'content': userMessage});

    // 2. Set up the streaming request to Groq
    final request = http.Request(
      'POST',
      Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
    );

    request.headers.addAll({
      'Authorization': 'Bearer $_apiKey',
      'Content-Type': 'application/json',
    });

    request.body = jsonEncode({
      'model': _model,
      'messages': messages,
      'stream': true, // This tells the server to stream tokens one by one!
      'temperature': 0.7,
      'max_tokens': 1024,
    });

    // 3. Open the connection and listen to the stream
    final client = http.Client();
    try {
      final response = await client.send(request);

      // Read the stream byte by byte as it arrives from the server
      await for (final chunk in response.stream.transform(utf8.decoder)) {
        // The server sends data in chunks starting with "data: "
        final lines = chunk.split('\n');
        
        for (final line in lines) {
          if (line.startsWith('data: ') && line != 'data: [DONE]') {
            final data = line.substring(6);
            try {
              final json = jsonDecode(data);
              final delta = json['choices'][0]['delta'];
              
              // If there is new text, yield it to the UI!
              if (delta.containsKey('content')) {
                yield delta['content'] as String;
              }
            } catch (e) {
              // Ignore partial JSON chunks
            }
          }
        }
      }
    } finally {
      client.close();
    }
  }
}