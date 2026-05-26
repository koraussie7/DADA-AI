class AppConstants {
  AppConstants._();

  static const String appName = 'DADA-AI';
  static const String apiBaseUrl = 'https://privseai.com';
  static const String wsBaseUrl = 'wss://privseai.com';
  static const int maxHistoryMessages = 200;
  static const Duration wsReconnectDelay = Duration(seconds: 5);
  static const Duration wsPingInterval = Duration(seconds: 30);
  static const String defaultAIUrl = 'http://localhost:8080';
  static const bool isLocalDev = true;

  // UI Strings
  static const String trendingLabel = '\u{1F525} Trending Now';
  static const String trendingHashtag = '#dancechallenge';
  static const String trendingLoops = 'Trending Loops';
  static const String sendMessage = 'Send a message';
  static const String aiServerOffline = 'AI server offline';
  static const String liveLabel = 'LIVE';
  static const String watching = 'watching';
  static const String buyNow = 'Buy Now';
  static const String chatWithHermes = 'Chat with Hermes';
  static const String fullCatalog = 'Full Catalog';
  static const String featuredProducts = 'Featured Products';
  static const String items = 'items';
  static const String purchaseInitiated = 'Purchase initiated';
  static const String analyzingStream = 'Analyzing stream...';
  static const String hermesAI = 'Hermes AI';
}
