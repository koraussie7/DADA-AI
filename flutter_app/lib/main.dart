import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'core/theme/app_theme.dart';
import 'widgets/bottom_nav.dart';
import 'services/wallet_service.dart';
import 'services/commerce_service.dart';
import 'services/chat_service.dart';
import 'services/loops_service.dart';
import 'services/hybrid_ai_service.dart';
import 'services/leaderboard_service.dart';
import 'services/p2p_service.dart';
import 'services/opencode_service.dart';
import 'bloc/chat_bloc.dart';
import 'screens/loops_player_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => WalletService()),
        ChangeNotifierProvider(create: (_) => CommerceService()),
        ChangeNotifierProvider(create: (_) => ChatService()),
        ChangeNotifierProvider(create: (_) => LoopsService()),
        ChangeNotifierProvider(create: (_) => HybridAIService()),
        Provider(create: (_) => LeaderboardService()),
        Provider(create: (_) => P2PService()),
        Provider(create: (_) => OpenCodeService()),
      ],
      child: BlocProvider(
        create: (_) => ChatBloc(),
        child: const MyApp(),
      ),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DADA-AI',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const MainBottomNav(),
      onGenerateRoute: (settings) {
        if (settings.name == '/loops/player') {
          final args = settings.arguments;
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
        }
        return null;
      },
    );
  }
}
