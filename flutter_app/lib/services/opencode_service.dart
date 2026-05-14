import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class OpenCodeService {
  final String _baseUrl;
  final http.Client _client;

  OpenCodeService({String? baseUrl})
      : _baseUrl = baseUrl ?? 'https://opencode.ai/zen',
        _client = http.Client();

  Future<String> chatViaProxy({
    required String prompt,
    String? systemPrompt,
    String model = 'claude-sonnet-4',
  }) async {
    try {
      final messages = <Map<String, String>>[];
      if (systemPrompt != null) {
        messages.add({'role': 'system', 'content': systemPrompt});
      }
      messages.add({'role': 'user', 'content': prompt});

      final body = {
        'model': model,
        'messages': messages,
        'temperature': 0.7,
        'max_tokens': 4096,
      };

      final resp = await _client
          .post(
            Uri.parse('https://muhantube.com/opencode/zen'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 120));

      if (resp.statusCode != 200) {
        throw Exception('OpenCode proxy error ${resp.statusCode}: ${resp.body}');
      }

      final data = jsonDecode(resp.body);
      return data['reply'] as String? ?? data.toString();
    } catch (e) {
      debugPrint('[OpenCode] Proxy error: $e');
      rethrow;
    }
  }

  String _getApiKey() {
    // In production, load from secure storage or env
    return const String.fromEnvironment('OPENCODE_API_KEY', defaultValue: '');
  }

  void dispose() {
    _client.close();
  }
}
