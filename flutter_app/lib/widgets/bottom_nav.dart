import 'package:flutter/material.dart';
import '../screens/reward_screen.dart';
import '../screens/live_commerce_screen.dart';
import '../screens/home_screen.dart';
import '../screens/loops_screen.dart';
import '../screens/contacts_screen.dart';
import '../screens/settings_screen.dart';

class MainBottomNav extends StatefulWidget {
  const MainBottomNav({super.key});

  @override
  State<MainBottomNav> createState() => _MainBottomNavState();
}

class _MainBottomNavState extends State<MainBottomNav> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const HomeScreen(),
    const LoopsScreen(),
    const ContactsScreen(),
    const RewardScreen(),
    const SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.95),
          border: Border(top: BorderSide(color: Colors.white.withOpacity(0.1), width: 1)),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          backgroundColor: Colors.transparent,
          selectedItemColor: Colors.deepPurpleAccent,
          unselectedItemColor: Colors.grey,
          type: BottomNavigationBarType.fixed,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: '홈'),
            BottomNavigationBarItem(icon: Icon(Icons.play_circle_filled), label: 'Loops'),
            BottomNavigationBarItem(icon: Icon(Icons.people_alt), label: '연락처'),
            BottomNavigationBarItem(icon: Icon(Icons.card_giftcard), label: 'Reward'),
            BottomNavigationBarItem(icon: Icon(Icons.settings), label: '설정'),
          ],
        ),
      ),
    );
  }
}
