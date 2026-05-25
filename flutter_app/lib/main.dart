import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'services/dating_service.dart';
import 'services/food_delivery_service.dart';
import 'services/location_service.dart';
import 'services/osm_location_service.dart';
import 'services/p2p_service.dart';
import 'services/chat_service.dart';
import 'services/liberty_bridge.dart';
import 'services/hyperspace_service.dart';
import 'services/hyperspace_pod_service.dart';
import 'services/hyperspace_payment_service.dart';
import 'services/hyperspace_earnings_service.dart';
import 'services/isek_service.dart';
import 'services/isek_fusion_service.dart';
import 'services/agixt_service.dart';
import 'services/agixt_fusion_service.dart';
import 'services/supplier_service.dart';
import 'services/stt_service.dart';
import 'services/tts_service.dart';
import 'services/auth_service.dart';
import 'screens/isek_explorer_screen.dart';
import 'screens/agixt_agents_screen.dart';
import 'screens/dating/auth_screen.dart';
import 'screens/dating/discover_screen.dart';
import 'screens/dating/matches_screen.dart';
import 'screens/dating/explore_screen.dart';
import 'screens/food_request_screen.dart';
import 'services/taxi_service.dart';
import 'services/massage_service.dart';
import 'screens/taxi_request_screen.dart';
import 'screens/massage_request_screen.dart';
import 'screens/maplibre_map_screen.dart';
import 'screens/hotel_request_screen.dart';
import 'screens/business_dashboard_screen.dart';
import 'screens/admin_point_approval_screen.dart';
import 'screens/blockchain_dashboard_screen.dart';
import 'screens/hyperspace_ai_chat_screen.dart';
import 'screens/hyperspace_pod_screen.dart';
import 'screens/hyperspace_earnings_screen.dart';
import 'screens/hyperspace_wallet_screen.dart';
import 'screens/create_group_screen.dart';
import 'screens/group_info_screen.dart';
import 'screens/wallet_login_screen.dart';
import 'screens/wallet_screen.dart';
import 'screens/chat_list_screen.dart';
import 'screens/ds_screen.dart';
import 'screens/reward_screen.dart';
import 'screens/contacts_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/signup_screen.dart';
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
        ChangeNotifierProvider(create: (_) => P2PService()),
        ChangeNotifierProvider(create: (_) => ChatService()),
        ChangeNotifierProvider(create: (_) => DatingService()),
        ChangeNotifierProvider(create: (_) {
          final svc = FoodDeliveryService();
          svc.loadMenu();
          return svc;
        }),
        ChangeNotifierProvider(create: (_) => TaxiService()),
        ChangeNotifierProvider(create: (_) => MassageService()),
        ChangeNotifierProvider(create: (_) => LocationService()),
        ChangeNotifierProvider(create: (_) => OsmLocationService()),
        ChangeNotifierProvider(create: (ctx) => LibertyBridge(
          ctx.read<P2PService>(),
          ctx.read<ChatService>(),
        )),
        ChangeNotifierProvider(create: (_) => HyperspaceService()),
        ChangeNotifierProvider(create: (_) => HyperspacePodService()),
        ChangeNotifierProvider(create: (_) => HyperspacePaymentService()),
        ChangeNotifierProvider(create: (_) => HyperspaceEarningsService()),
        ChangeNotifierProvider(create: (_) => ISEKService()),
        ChangeNotifierProvider(create: (_) => ISEKFusionService()),
        ChangeNotifierProvider(create: (_) => AGiXTService()),
        ChangeNotifierProvider(create: (_) => AGiXTFusionService()),
        ChangeNotifierProvider(create: (_) => SupplierService()),
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => SttService()..initialize()),
        ChangeNotifierProvider(create: (_) => TtsService()..initialize()),
        ChangeNotifierProvider(create: (_) => ValueNotifier<ThemeMode>(ThemeMode.dark)),
      ],
      child: Consumer<ValueNotifier<ThemeMode>>(
        builder: (context, themeNotifier, _) => MaterialApp(
          title: 'DADA-AI',
          debugShowCheckedModeBanner: false,
          theme: _buildLightTheme(),
          darkTheme: _buildDarkTheme(),
          themeMode: themeNotifier.value,
          home: const MainScreen(),
          onGenerateRoute: (settings) {
            if (settings.name == '/group/info') {
              return MaterialPageRoute(
                builder: (_) => GroupInfoScreen(groupId: settings.arguments as String),
                settings: settings,
              );
            }
            return null;
          },
          routes: {
          '/auth': (_) => const AuthScreen(),
          '/discover': (_) => const DiscoverScreen(),
          '/matches': (_) => const MatchesScreen(),
          '/explore': (_) => const ExploreScreen(),
          '/food/request': (_) => const FoodRequestScreen(),
          '/taxi/request': (_) => const TaxiRequestScreen(),
          '/massage/request': (_) => const MassageRequestScreen(),
          '/hotel/request': (_) => const HotelRequestScreen(),
          '/isek/explorer': (_) => const ISEKExplorerScreen(),
          '/agixt/agents': (_) => const AGiXTAgentsScreen(),
          '/supplier/dashboard': (_) => const BusinessDashboardScreen(),
          '/admin/point': (_) => const AdminPointApprovalScreen(),
          '/blockchain/dashboard': (_) => const BlockchainDashboard(),
          '/hyperspace/chat': (_) => const HyperspaceAIChatScreen(),
          '/hyperspace/pod': (_) => const HyperspacePodScreen(),
          '/hyperspace/earnings': (_) => const HyperspaceEarningsScreen(),
          '/hyperspace/wallet': (_) => const HyperspaceWalletScreen(),
          '/chat/list': (_) => const ChatListScreen(),
          '/group/create': (_) => const CreateGroupScreen(),
          '/auth/wallet-login': (_) => const WalletLoginScreen(),
          '/ds/dashboard': (_) => const DSScreen(),
          '/reward': (_) => const RewardScreen(),
          '/wallet': (_) => const WalletScreen(),
          '/contacts': (_) => const ContactsScreen(),
          '/settings': (_) => const SettingsScreen(),
          '/auth/signup': (_) => const SignupScreen(),
          '/map/vector': (_) => const MaplibreMapScreen(),
        },
      ),
      ),
    );
  }

  ThemeData _buildDarkTheme() {
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

  ThemeData _buildLightTheme() {
    const primaryColor = Color(0xFFF02C56);
    return ThemeData(
      brightness: Brightness.light,
      primaryColor: primaryColor,
      scaffoldBackgroundColor: const Color(0xFFF8F9FA),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: Colors.black87,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
      ),
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        brightness: Brightness.light,
        primary: primaryColor,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        indicatorColor: const Color(0xFFF02C56).withValues(alpha: 0.2),
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        labelTextStyle: WidgetStateProperty.all(
          const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Colors.black54),
        ),
      ),
      useMaterial3: true,
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  @override
  void initState() {
    super.initState();
    // Start Hyperspace node polling
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<HyperspaceService>().startPolling();
    });
  }

  @override
  void dispose() {
    // Polling is stopped in HyperspaceService.dispose()
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return const MainBottomNav();
  }
}
