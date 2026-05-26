import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'core/theme/app_theme.dart';
import 'core/constants/app_constants.dart';
import 'core/localization/app_localizations.dart';
import 'core/localization/language_provider.dart';
import 'widgets/bottom_nav.dart';
import 'services/wallet_service.dart';
import 'services/commerce_service.dart';
import 'services/chat_service.dart';
import 'services/loops_service.dart';
import 'services/hybrid_ai_service.dart';
import 'services/leaderboard_service.dart';
import 'services/p2p_service.dart';
import 'services/opencode_service.dart';
import 'services/liberty_bridge.dart';
import 'services/group_chat_service.dart';
import 'services/voice_service.dart';
import 'services/speech_service.dart';
import 'services/p2p_inference_service.dart';
import 'services/video_call_service.dart';
import 'bloc/chat_bloc.dart';
import 'screens/loops_player_screen.dart';
import 'screens/chat_screen.dart';
import 'screens/chat_list_screen.dart';
import 'screens/contacts_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/live_commerce_screen.dart';
import 'screens/leaderboard_screen.dart';
import 'screens/reward_screen.dart';
import 'screens/loops_screen.dart';
import 'screens/loops_list_screen.dart';
import 'screens/create_group_screen.dart';
import 'screens/group_info_screen.dart';
import 'screens/commerce_catalog_screen.dart';
import 'screens/commerce_cart_screen.dart';
import 'screens/video_call_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LanguageProvider()..loadSavedLocale()),
        ChangeNotifierProvider(create: (_) => WalletService()),
        ChangeNotifierProvider(create: (_) => CommerceService()),
        ChangeNotifierProvider(create: (context) {
          final cs = ChatService();
          cs.loadHistory();
          cs.attachP2P(context.read<P2PService>());
          return cs;
        }),
        ChangeNotifierProvider(create: (_) => LoopsService()),
        ChangeNotifierProvider(create: (_) => HybridAIService()),
        Provider(create: (_) => LeaderboardService()),
        ChangeNotifierProvider(create: (_) => P2PService()),
        Provider(create: (_) => OpenCodeService()),
        ChangeNotifierProvider(create: (_) => GroupChatService()),
        ChangeNotifierProvider(create: (_) => VoiceService()),
        ChangeNotifierProvider(create: (_) => SpeechService()),
        ChangeNotifierProvider(create: (context) => P2PInferenceService(context.read<P2PService>())),
        ChangeNotifierProvider(create: (context) => VideoCallService(context.read<P2PService>())),
        ChangeNotifierProvider(create: (context) {
          final bridge = LibertyBridge(
            context.read<P2PService>(),
            context.read<ChatService>(),
          );
          bridge.init(peerName: 'liberty_user');
          return bridge;
        }),
        ChangeNotifierProvider(create: (_) => ValueNotifier<ThemeMode>(ThemeMode.dark)),
      ],
      child: BlocProvider(
        create: (context) => ChatBloc(context.read<ChatService>()),
        child: const MyApp(),
      ),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeMode = context.watch<ValueNotifier<ThemeMode>>().value;
    final langProvider = context.watch<LanguageProvider>();

    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      locale: langProvider.locale,
      supportedLocales: const [Locale('en'), Locale('ko')],
      localizationsDelegates: const [
        AppLocalizationsDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      localeResolutionCallback: langProvider.resolutionCallback,
      initialRoute: '/',
      onGenerateRoute: (settings) {
        final args = settings.arguments;

        switch (settings.name) {
          case '/':
            return MaterialPageRoute(builder: (_) => const MainBottomNav());

          case '/splash':
            return MaterialPageRoute(builder: (_) => const SplashScreen());

          case '/chat':
            return MaterialPageRoute(
              builder: (_) => const ChatScreen(peerId: 'default', peerName: 'Chat'),
            );

          case '/chat-list':
            return MaterialPageRoute(builder: (_) => const ChatListScreen());

          case '/contacts':
            return MaterialPageRoute(builder: (_) => const ContactsScreen());

          case '/settings':
            return MaterialPageRoute(builder: (_) => const SettingsScreen());

          case '/leaderboard':
            return MaterialPageRoute(builder: (_) => const LeaderboardScreen());

          case '/live-commerce':
            return MaterialPageRoute(builder: (_) => const LiveCommerceScreen());

          case '/reward':
            return MaterialPageRoute(builder: (_) => const RewardScreen());

          case '/loops':
            return MaterialPageRoute(builder: (_) => const LoopsScreen());

          case '/loops/list':
            return MaterialPageRoute(builder: (_) => const LoopsListScreen());

          case '/loops/player':
            if (args is LoopVideo) {
              return MaterialPageRoute(
                builder: (_) => LoopsPlayerScreen(videoIndex: 0, video: args),
              );
            }
            if (args is int) {
              return MaterialPageRoute(
                builder: (_) => LoopsPlayerScreen(videoIndex: args),
              );
            }
            return MaterialPageRoute(
              builder: (_) => LoopsPlayerScreen(videoIndex: 0),
            );

          case '/group/create':
            return MaterialPageRoute(builder: (_) => const CreateGroupScreen());

          case '/group/info':
            if (args is String) {
              return MaterialPageRoute(
                builder: (_) => GroupInfoScreen(groupId: args),
              );
            }
            return MaterialPageRoute(builder: (_) => const MainBottomNav());

          case '/commerce/catalog':
            return MaterialPageRoute(builder: (_) => const CommerceCatalogScreen());

          case '/commerce/cart':
            return MaterialPageRoute(builder: (_) => const CommerceCartScreen());

          case '/video-call':
            return MaterialPageRoute(builder: (_) => const VideoCallScreen());

          default:
            return MaterialPageRoute(builder: (_) => const MainBottomNav());
        }
      },
    );
  }
}
