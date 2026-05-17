import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'services/dating_service.dart';
import 'services/food_delivery_service.dart';
import 'screens/dating/auth_screen.dart';
import 'screens/dating/discover_screen.dart';
import 'screens/dating/matches_screen.dart';
import 'screens/dating/explore_screen.dart';
import 'screens/food_request_screen.dart';
import 'screens/food_bid_screen.dart';
import 'screens/food_confirm_screen.dart';
import 'services/taxi_service.dart';
import 'services/massage_service.dart';
import 'screens/taxi_request_screen.dart';
import 'screens/taxi_bid_screen.dart';
import 'screens/taxi_confirm_screen.dart';
import 'screens/massage_request_screen.dart';
import 'screens/massage_bid_screen.dart';
import 'screens/massage_confirm_screen.dart';
import 'screens/hotel_request_screen.dart';
import 'widgets/bottom_nav.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);
  runApp(const LibertyReachApp());
}

class LibertyReachApp extends StatelessWidget {
  const LibertyReachApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => DatingService()),
        ChangeNotifierProvider(create: (_) {
          final svc = FoodDeliveryService();
          svc.loadMenu();
          return svc;
        }),
        ChangeNotifierProvider(create: (_) => TaxiService()),
        ChangeNotifierProvider(create: (_) => MassageService()),
      ],
      child: MaterialApp(
        title: 'DADA-AI',
        debugShowCheckedModeBanner: false,
        theme: _buildTheme(),
        home: const MainScreen(),
        routes: {
          '/auth': (_) => const AuthScreen(),
          '/discover': (_) => const DiscoverScreen(),
          '/matches': (_) => const MatchesScreen(),
          '/explore': (_) => const ExploreScreen(),
          '/food/request': (_) => const FoodRequestScreen(),
          '/taxi/request': (_) => const TaxiRequestScreen(),
          '/massage/request': (_) => const MassageRequestScreen(),
          '/hotel/request': (_) => const HotelRequestScreen(),
        },
      ),
    );
  }

  ThemeData _buildTheme() {
    const primaryColor = Color(0xFFF02C56);
    return ThemeData(
      brightness: Brightness.dark,
      primaryColor: primaryColor,
      scaffoldBackgroundColor: const Color(0xFF020617),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF0F172A),
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
      ),
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        brightness: Brightness.dark,
        primary: primaryColor,
        surface: const Color(0xFF0F172A),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: const Color(0xFF0F172A),
        indicatorColor: const Color(0xFFF02C56).withValues(alpha: 0.2),
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        labelTextStyle: WidgetStateProperty.all(
          const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Color(0xFF94A3B8)),
        ),
      ),
      useMaterial3: true,
    );
  }
}

class MainScreen extends StatelessWidget {
  const MainScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const MainBottomNav();
  }
}
