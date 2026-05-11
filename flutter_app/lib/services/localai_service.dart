import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class LocalAIService {
  String _baseUrl;
  final http.Client _client;
  bool _lastHealth = false;

  LocalAIService({String baseUrl = 'http://185.55.243.225:8081'})
      : _baseUrl = baseUrl,
        _client = http.Client();

  String get baseUrl => _baseUrl;
  set baseUrl(String url) => _baseUrl = url;

  Future<String> generate(String prompt) async {
    try {
      final response = await _client
          .post(
            Uri.parse('$_baseUrl/v1/chat/completions'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'model': 'gemma-4-e2b-it',
              'messages': [{'role': 'user', 'content': prompt}],
              'stream': false,
              'max_tokens': 2048,
              'temperature': 0.7,
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['choices']?[0]?['message']?['content']?.toString().trim() ?? '(no response)';
      } else {
        return 'Error: ${response.statusCode}';
      }
    } on SocketException {
      return 'Server not reachable';
    } catch (e) {
      debugPrint('AI error: $e');
      return '(error)';
    }
  }

  Future<String> generateMultimodal(String text, List<String> imagesBase64) async {
    try {
      final List<Map<String, dynamic>> content = [
        {'type': 'text', 'text': text}
      ];
      for (final img in imagesBase64) {
        content.add({
          'type': 'image_url',
          'image_url': {'url': 'data:image/jpeg;base64,$img'}
        });
      }

      final response = await _client
          .post(
            Uri.parse('$_baseUrl/v1/chat/completions'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'model': 'gemma-4-e2b-it',
              'messages': [{'role': 'user', 'content': content}],
              'max_tokens': 4096,
              'temperature': 0.7,
            }),
          )
          .timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['choices']?[0]?['message']?['content']?.toString().trim() ?? '(no response)';
      } else {
        return 'Error: ${response.statusCode}';
      }
    } on SocketException {
      return 'Server not reachable';
    } catch (e) {
      debugPrint('Multimodal error: $e');
      return '(error)';
    }
  }

  Future<bool> health() async {
    try {
      final response = await _client
          .get(Uri.parse('$_baseUrl/healthz'))
          .timeout(const Duration(seconds: 5));
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
