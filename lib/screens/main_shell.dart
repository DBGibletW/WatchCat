import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'about_screen.dart';
import 'feed_screen.dart';
import 'upload_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;
  int _feedScrollToTopSignal = 0;

  void _onTabSelected(int index) {
    if (_currentIndex == index) return;
    setState(() => _currentIndex = index);
  }

  void _onUploadCompleted() {
    setState(() {
      _currentIndex = 0;
      _feedScrollToTopSignal++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0E),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          FeedScreen(
            isTabActive: _currentIndex == 0,
            scrollToTopSignal: _feedScrollToTopSignal,
          ),
          UploadScreen(
            isTabActive: _currentIndex == 1,
            onUploadSuccess: _onUploadCompleted,
          ),
          const AboutScreen(),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF0E0E14),
          border: Border(
            top: BorderSide(color: Color(0xFF222230), width: 1),
          ),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 62,
            child: Row(
              children: [
                _BottomNavItem(
                  icon: LucideIcons.house,
                  label: 'Ana Sayfa',
                  isActive: _currentIndex == 0,
                  onTap: () => _onTabSelected(0),
                ),
                _BottomNavItem(
                  icon: LucideIcons.plus,
                  label: 'Yükle',
                  isActive: _currentIndex == 1,
                  onTap: () => _onTabSelected(1),
                ),
                _BottomNavItem(
                  icon: LucideIcons.info,
                  label: 'Hakkında',
                  isActive: _currentIndex == 2,
                  onTap: () => _onTabSelected(2),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomNavItem extends StatelessWidget {
  const _BottomNavItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const activeColor = Color(0xFFFF6B4A);
    const inactiveColor = Color(0xFF8E8EA0);
    final color = isActive ? activeColor : inactiveColor;

    return Expanded(
      child: InkWell(
        onTap: onTap,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 22,
              color: color,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 11.5,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
