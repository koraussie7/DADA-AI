import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

class HybridAIService extends ChangeNotifier {
  final String _baseUrl = 'https://muhantube.com';
  final http.Client _client;

  HybridAIService() : _client = http.Client();

  Future<String> process(String prompt, {String model = 'gemini-2.5-flash', List<String>? images}) async {
    try {
      final body = {
        'model': model,
        'messages': [
          {
            'role': 'user',
            'content': prompt,
            if (images != null && images.isNotEmpty) 'images': images,
          }
        ],
        'stream': false,
        'max_tokens': 4096,
        'temperature': 0.7,
      };

      final response = await _client
          .post(
            Uri.parse('$_baseUrl/ai/chat'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 120));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['choices']?[0]?['message']?['content']?.toString().trim() ?? '(no response)';
      }
      return '(AI error: ${response.statusCode})';
    } catch (e) {
      debugPrint('[HybridAI] Error: $e');
      return '(error: $e)';
    }
  }

  Future<Map<String, dynamic>> codeAssist({
    required String prompt,
    String mode = 'auto',
    String? systemPrompt,
  }) async {
    try {
      final body = {
        'messages': [
          if (systemPrompt != null) {'role': 'system', 'content': systemPrompt},
          {'role': 'user', 'content': prompt},
        ],
        'mode': mode,
        'max_tokens': 4096,
      };

      final response = await _client
          .post(
            Uri.parse('$_baseUrl/ai/code-assist'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 120));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'reply': data['reply']?.toString().trim() ?? '(no response)',
          'mode': data['mode'] ?? mode,
          'provider': data['provider'] ?? 'local',
        };
      }
      return {'reply': '(error: ${response.statusCode})', 'mode': mode};
    } catch (e) {
      debugPrint('[HybridAI] Code assist error: $e');
      return {'reply': '(error: $e)', 'mode': mode};
    }
  }

  @override
  void dispose() {
    _client.close();
    super.dispose();
  }
}
