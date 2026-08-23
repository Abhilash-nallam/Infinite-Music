import 'package:flutter/material.dart';
import '../widgets/mini_player.dart';
import 'home_screen.dart';
import 'search_screen.dart';
import 'library_screen.dart';
import 'profile_screen.dart';

/// Main application shell. Secondary screens are created lazily so plugins
/// used only by those screens cannot run during app startup.
class RootShell extends StatefulWidget {
  const RootShell({super.key});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  int _index = 0;
  final List<Widget?> _screens = List<Widget?>.filled(4, null);

  Widget _currentScreen() {
    final existing = _screens[_index];
    if (existing != null) return existing;

    final screen = switch (_index) {
      0 => const HomeScreen(),
      1 => const SearchScreen(),
      2 => const LibraryScreen(),
      3 => const ProfileScreen(),
      _ => const HomeScreen(),
    };
    _screens[_index] = screen;
    return screen;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Expanded(child: _currentScreen()),
          const MiniPlayer(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        backgroundColor: Colors.transparent,
        elevation: 0,
        height: 70,
        indicatorColor: const Color(0x337C3AED),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.search_rounded),
            label: 'Search',
          ),
          NavigationDestination(
            icon: Icon(Icons.library_music_outlined),
            selectedIcon: Icon(Icons.library_music_rounded),
            label: 'Library',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
