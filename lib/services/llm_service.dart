class LLMService {

  Future<String> generateResponse(String prompt) async {

    await Future.delayed(
      const Duration(seconds: 1),
    );

    return "Interesting. Tell me more.";
  }

}