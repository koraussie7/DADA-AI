import 'package:flutter/material.dart';

class AppLocalizations {
  final Locale locale;
  AppLocalizations(this.locale);

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static AppLocalizations? maybeOf(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  String get appName => _t('appName');
  String get trendingNow => _t('trendingNow');
  String get trendingHashtag => _t('trendingHashtag');
  String get trendingLoops => _t('trendingLoops');
  String get sendMessage => _t('sendMessage');
  String get aiServerOffline => _t('aiServerOffline');
  String get liveLabel => _t('liveLabel');
  String get watching => _t('watching');
  String get buyNow => _t('buyNow');
  String get chatWithHermes => _t('chatWithHermes');
  String get fullCatalog => _t('fullCatalog');
  String get featuredProducts => _t('featuredProducts');
  String get items => _t('items');
  String get purchaseInitiated => _t('purchaseInitiated');
  String get analyzingStream => _t('analyzingStream');
  String get hermesAI => _t('hermesAI');
  String get settings => _t('settings');
  String get appearance => _t('appearance');
  String get theme => _t('theme');
  String get darkMode => _t('darkMode');
  String get lightMode => _t('lightMode');
  String get p2pNetwork => _t('p2pNetwork');
  String get connectedPeers => _t('connectedPeers');
  String get peersConnected => _t('peersConnected');
  String get online => _t('online');
  String get offline => _t('offline');
  String get connectToServer => _t('connectToServer');
  String get connecting => _t('connecting');
  String get tapToConnect => _t('tapToConnect');
  String get endToEndEncryption => _t('endToEndEncryption');
  String get messageStorage => _t('messageStorage');
  String get aiSettings => _t('aiSettings');
  String get aiAssistant => _t('aiAssistant');
  String get aiServerUrl => _t('aiServerUrl');
  String get about => _t('about');
  String get version => _t('version');
  String get docs => _t('docs');
  String get language => _t('language');
  String get myNode => _t('myNode');
  String get peerId => _t('peerId');
  String get cancel => _t('cancel');
  String get save => _t('save');
  String get search => _t('search');
  String get home => _t('home');
  String get chat => _t('chat');
  String get loops => _t('loops');
  String get commerce => _t('commerce');
  String get live => _t('live');
  String get profile => _t('profile');

  String _t(String key) {
    return _strings[locale.languageCode]?[key] ?? _strings['en']![key]!;
  }

  static const Map<String, Map<String, String>> _strings = {
    'en': {
      'appName': 'DADA-AI',
      'trendingNow': '\u{1F525} Trending Now',
      'trendingHashtag': '#dancechallenge',
      'trendingLoops': 'Trending Loops',
      'sendMessage': 'Send a message',
      'aiServerOffline': 'AI server offline',
      'liveLabel': 'LIVE',
      'watching': 'watching',
      'buyNow': 'Buy Now',
      'chatWithHermes': 'Chat with Hermes',
      'fullCatalog': 'Full Catalog',
      'featuredProducts': 'Featured Products',
      'items': 'items',
      'purchaseInitiated': 'Purchase initiated',
      'analyzingStream': 'Analyzing stream...',
      'hermesAI': 'Hermes AI',
      'settings': 'Settings',
      'appearance': 'Appearance',
      'theme': 'Theme',
      'darkMode': 'Dark Mode',
      'lightMode': 'Light Mode',
      'p2pNetwork': 'P2P Network',
      'connectedPeers': 'Connected Peers',
      'peersConnected': 'peers connected',
      'online': 'Online',
      'offline': 'Offline',
      'connectToServer': 'Connect to Server',
      'connecting': 'Connecting...',
      'tapToConnect': 'Tap to connect',
      'endToEndEncryption': 'End-to-End Encryption',
      'messageStorage': 'Message Storage',
      'aiSettings': 'AI Settings',
      'aiAssistant': 'AI Assistant',
      'aiServerUrl': 'AI Server URL',
      'about': 'About',
      'version': 'Version',
      'docs': 'Docs',
      'language': 'Language',
      'myNode': 'My Node',
      'peerId': 'Peer ID',
      'cancel': 'Cancel',
      'save': 'Save',
      'search': 'Search',
      'home': 'Home',
      'chat': 'Chat',
      'loops': 'Loops',
      'commerce': 'Commerce',
      'live': 'Live',
      'profile': 'Profile',
    },
    'ko': {
      'appName': 'DADA-AI',
      'trendingNow': '\u{1F525} \uC778\uAE30 \uAE09\uC0C1\uC2B9',
      'trendingHashtag': '#\uB304\uC2A4\uCC4C\uB9B4\uC9C0',
      'trendingLoops': '\uC778\uAE30 Loops',
      'sendMessage': '\uBA54\uC2DC\uC9C0 \uBCF4\uB0B4\uAE30',
      'aiServerOffline': 'AI \uC11C\uBC84 \uC624\uD504\uB77C\uC778',
      'liveLabel': '\uB77C\uC774\uBE0C',
      'watching': '\uC2DC\uCCAD \uC911',
      'buyNow': '\uAD6C\uB9E4\uD558\uAE30',
      'chatWithHermes': 'Hermes\uC640 \uCC44\uD305',
      'fullCatalog': '\uC804\uCCB4 \uCE74\uD0C8\uB85C\uADF8',
      'featuredProducts': '\uCD94\uCC9C \uC0C1\uD488',
      'items': '\uAC1C \uC0C1\uD488',
      'purchaseInitiated': '\uAD6C\uB9E4 \uC9C4\uD589 \uC911',
      'analyzingStream': '\uC2A4\uD2B8\uB9BC \uBD84\uC11D \uC911...',
      'hermesAI': 'Hermes AI',
      'settings': '\uC124\uC815',
      'appearance': '\uBAA8\uC591',
      'theme': '\uD14C\uB9C8',
      'darkMode': '\uB2E4\uD06C \uBAA8\uB4DC',
      'lightMode': '\uB77C\uC774\uD2B8 \uBAA8\uB4DC',
      'p2pNetwork': 'P2P \uB124\uD2B8\uC6CC\uD06C',
      'connectedPeers': '\uC811\uC18D\uB41C \uD53C\uC5B4',
      'peersConnected': '\uAC1C \uD53C\uC5B4 \uC811\uC18D \uC911',
      'online': '\uC628\uB77C\uC778',
      'offline': '\uC624\uD504\uB77C\uC778',
      'connectToServer': '\uC11C\uBC84 \uC5F0\uACB0',
      'connecting': '\uC5F0\uACB0 \uC911...',
      'tapToConnect': '\uD0ED\uD558\uC5EC \uC5F0\uACB0',
      'endToEndEncryption': '\uC885\uB2E8 \uC554\uD638\uD654',
      'messageStorage': '\uBA54\uC2DC\uC9C0 \uC800\uC7A5',
      'aiSettings': 'AI \uC124\uC815',
      'aiAssistant': 'AI \uC5B4\uC2DC\uC2A4\uD134\uD2B8',
      'aiServerUrl': 'AI \uC11C\uBC84 URL',
      'about': '\uC815\uBCF4',
      'version': '\uBC84\uC804',
      'docs': '\uBB38\uC11C',
      'language': '\uC5B8\uC5B4',
      'myNode': '\uB0B4 \uB178\uB4DC',
      'peerId': '\uD53C\uC5B4 ID',
      'cancel': '\uCDE8\uC18C',
      'save': '\uC800\uC7A5',
      'search': '\uAC80\uC0C9',
      'home': '\uD648',
      'chat': '\uCC44\uD305',
      'loops': 'Loops',
      'commerce': '\uC1FC\uD551',
      'live': '\uB77C\uC774\uBE0C',
      'profile': '\uD504\uB85C\uD544',
    },
  };
}

class AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => ['en', 'ko'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) => Future.value(AppLocalizations(locale));

  @override
  bool shouldReload(AppLocalizationsDelegate old) => false;
}
