import 'package:appmobie/screens/cv_analysis_screen.dart';
import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'notifications_screen.dart';
import 'settings_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});
  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _index = 0;

  final _tabs = const [
    HomeScreen(),
    NotificationsScreen(),
    SettingsScreen(),
    CvAnalysisScreen(),
  ];
  final _titles = ['Trang chủ', 'Thông báo', 'Cài đặt', 'Phân tích cv'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_titles[_index]), centerTitle: true),
      body: _tabs[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            label: 'Trang chủ',
          ),
          NavigationDestination(
            icon: Icon(Icons.notifications_none),
            label: 'Thông báo',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            label: 'Cài đặt',
          ),
          NavigationDestination(
            icon: Icon(Icons.info_outline),
            label: 'Phân tích cv',
          ),
        ],
      ),
    );
  }
}
