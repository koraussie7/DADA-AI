import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class LocalAIService {
  final String _baseUrl = 'https://muhantube.com';
  final http.Client _client;
  bool _lastHealth = false;
  String _selectedModel = 'gemini-2.5-flash';
  List<ModelInfo> _availableModels = [];

  /// Default AI endpoint — configure via constructor or setter.
  /// In production, override with your server's address.
  LocalAIService({String baseUrl = 'http://localhost:8081'})
      : _baseUrl = baseUrl,
        _client = http.Client();

  String get selectedModel => _selectedModel;
  List<ModelInfo> get availableModels => List.unmodifiable(_availableModels);

  void selectModel(String modelId) {
    _selectedModel = modelId;
    debugPrint('[LocalAI] Model selected: $modelId');
  }

  Future<void> fetchModels() async {
    try {
      final response = await _client
          .get(Uri.parse('$_baseUrl/ai/models'))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final list = data['data'] as List? ?? [];
        _availableModels = list.map((m) => ModelInfo(
          id: m['id'] as String? ?? 'unknown',
          provider: m['provider'] as String? ?? 'local',
        )).toList();
      }
    } catch (e) {
      debugPrint('[LocalAI] Failed to fetch models: $e');
    }
  }

  Future<String> generate(String prompt, {String? model, List<String>? images}) async {
    final useModel = model ?? _selectedModel;
    try {
      final body = {
        'model': useModel,
        'messages': [{'role': 'user', 'content': prompt}],
        'stream': false,
        'max_tokens': 4096,
        'temperature': 0.7,
      };
      if (images != null && images.isNotEmpty) {
        body['messages'] = [{
          'role': 'user',
          'content': prompt,
          'images': images,
        }];
      }

      final response = await _client
          .post(
            Uri.parse('$_baseUrl/ai/chat'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 120));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data.containsKey('error')) {
          return 'Error: ${data['error']}';
        }
        return data['choices']?[0]?['message']?['content']?.toString().trim() ?? '(no response)';
      } else {
        final body = response.body;
        try {
          final err = jsonDecode(body);
          return 'Error: ${err['error'] ?? response.statusCode}';
        } catch (_) {
          return 'Error: ${response.statusCode}';
        }
      }
    } catch (e) {
      debugPrint('[LocalAI] AI error: $e');
      return '(error: ${e.toString().replaceFirst(RegExp(r'^.+Exception: '), '')})';
    }
  }

  Future<bool> health() async {
    try {
      final response = await _client
          .get(Uri.parse('$_baseUrl/health'))
          .timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _lastHealth = data['status'] == 'healthy';
        return _lastHealth;
      }
      _lastHealth = false;
      return false;
    } catch (_) {
      _lastHealth = false;
      return false;
    }
  }

  void dispose() {
    _client.close();
  }
}

class ModelInfo {
  final String id;
  final String provider;

  ModelInfo({required this.id, required this.provider});

  bool get isGemini => provider == 'google';
  bool get isLocalAI => provider == 'local';

  String get displayName {
    if (isGemini) return 'Gemini ${id.replaceAll('gemini-', '').replaceAll('-', ' ').replaceAll('pro', 'Pro').replaceAll('flash', 'Flash')}';
    return id;
  }
}
