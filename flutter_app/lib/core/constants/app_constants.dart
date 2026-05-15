class AppConstants {
  static const String appName = 'DADA-AI';
  static const String apiBaseUrl = 'https://privseai.com';
  static const String wsBaseUrl = 'wss://privseai.com';
  static const int maxHistoryMessages = 200;
  static const Duration wsReconnectDelay = Duration(seconds: 5);
  static const Duration wsPingInterval = Duration(seconds: 30);
  static const String defaultAIUrl = 'http://localhost:8080';
}
