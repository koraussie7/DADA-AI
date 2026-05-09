import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class LocalAIService {
  String _baseUrl;
  final http.Client _client;
  bool _lastHealth = false;

  LocalAIService({String baseUrl = 'http://localhost:8080'})
      : _baseUrl = baseUrl,
        _client = http.Client();

  String get baseUrl => _baseUrl;

  set baseUrl(String url) => _baseUrl = url;

  Future<String> generate(String prompt) async {
    try {
      final response = await _client
          .post(
            Uri.parse('$_baseUrl/v1/completions'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'model': 'gemma-2-2b-it',
              'prompt': _buildPrompt(prompt),
              'stream': false,
              'max_tokens': 1024,
              'temperature': 0.7,
              'top_p': 0.9,
              'repeat_penalty': 1.1,
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['choices']?[0]?['text']?.toString().trim() ?? '(no response)';
      } else {
        return 'Error: ${response.statusCode}';
      }
    } on SocketException {
      return '서버에 연결할 수 없습니다 (LocalAI)';
    } on http.ClientException {
      return '네트워크 오류';
    } catch (e) {
      debugPrint('LocalAI error: $e');
      return '(응답 없음)';
    }
  }

  String _buildPrompt(String userMessage) {
    return '''<start_of_turn>user
$userMessage<end_of_turn>
<start_of_turn>model
''';
  }

  Future<bool> health() async {
    try {
      final response = await _client
          .get(Uri.parse('$_baseUrl/healthz'))
          .timeout(const Duration(seconds: 3));
      _lastHealth = response.statusCode == 200;
      return _lastHealth;
    } catch (_) {
      _lastHealth = false;
      return false;
    }
  }

  void dispose() {
    _client.close();
  }
}
