import 'package:flutter/material.dart';
import '../../core/constants/colors.dart';
import 'home_screen.dart';
import 'library_screen.dart';
import 'status_saver_screen.dart';
import '../../data/services/ad_service.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  final List<Widget> _pages = [
    const HomeScreen(),
    const StatusSaverScreen(),
    const LibraryScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          Expanded(child: _pages[_currentIndex]),
          SafeArea(
            top: false,
            child: AdService().buildBannerAd(),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        backgroundColor: Colors.black,
        selectedItemColor: AppColors.neonPurple,
        unselectedItemColor: Colors.grey,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
        unselectedLabelStyle: const TextStyle(fontSize: 11),
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.downloading_rounded),
            label: 'Downloader',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble_outline_rounded),
            label: 'Status Saver',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.folder_copy_rounded),
            label: 'Library',
          ),
        ],
      ),
    );
  }
}
