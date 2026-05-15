import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/chat_list_screen.dart';
import 'screens/chat_screen.dart';
import 'screens/contacts_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/leaderboard_screen.dart';
import 'screens/loops_screen.dart';
import 'screens/loops_player_screen.dart';

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
    return MaterialApp(
      title: 'Liberty Reach',
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(),
      home: const MainScreen(),
      onGenerateRoute: _onGenerateRoute,
    );
  }

  ThemeData _buildTheme() {
    const primaryColor = Color(0xFFFEE500);
    return ThemeData(
      brightness: Brightness.light,
      primaryColor: primaryColor,
      scaffoldBackgroundColor: const Color(0xFFF5F5F5),
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
      ),
      useMaterial3: true,
    );
  }

  Route<dynamic>? _onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case '/loops/player':
        final args = settings.arguments;
        int index = 0;
        if (args is int) {
          index = args;
        } else if (args is Map<String, dynamic>) {
          index = args['index'] as int? ?? 0;
        }
        return MaterialPageRoute(
          builder: (_) => LoopsPlayerScreen(videoIndex: index),
        );
    }
    return null;
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    ChatListScreen(),
    LoopsScreen(),
    LeaderboardScreen(),
    ContactsScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        backgroundColor: Colors.white,
        indicatorColor: const Color(0xFFFEE500).withOpacity(0.3),
        shadowColor: Colors.black12,
        surfaceTintColor: Colors.transparent,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.chat_outlined),
            selectedIcon: Icon(Icons.chat),
            label: 'Chat',
          ),
          NavigationDestination(
            icon: Icon(Icons.local_fire_department_outlined),
            selectedIcon: Icon(Icons.local_fire_department),
            label: 'Loops',
          ),
          NavigationDestination(
            icon: Icon(Icons.emoji_events_outlined),
            selectedIcon: Icon(Icons.emoji_events),
            label: 'Ranking',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people),
            label: 'Contacts',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
