import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_theme.dart';

class Ios18FloatingTabBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onTabSelected;

  const Ios18FloatingTabBar({
    super.key,
    required this.selectedIndex,
    required this.onTabSelected,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final tabs = [
      _TabItem(
        icon: Icons.grid_view_rounded,
        activeIcon: Icons.grid_view_rounded,
        label: 'Dashboard',
      ),
      _TabItem(
        icon: Icons.receipt_long_outlined,
        activeIcon: Icons.receipt_long_rounded,
        label: 'Activity',
      ),
      _TabItem(
        icon: Icons.auto_awesome_outlined,
        activeIcon: Icons.auto_awesome_rounded,
        label: 'AI & Waste',
      ),
      _TabItem(
        icon: Icons.tune_rounded,
        activeIcon: Icons.tune_rounded,
        label: 'Settings',
      ),
    ];

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.only(left: 20, right: 20, bottom: 12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: Container(
              height: 68,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF1C1C1E).withOpacity(0.85)
                    : Colors.white.withOpacity(0.82),
                borderRadius: BorderRadius.circular(32),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withOpacity(0.12)
                      : Colors.white.withOpacity(0.75),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 28,
                    offset: const Offset(0, 10),
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: List.generate(tabs.length, (index) {
                  final isSelected = selectedIndex == index;
                  final tab = tabs[index];

                  return Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        HapticFeedback.lightImpact();
                        onTabSelected(index);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 260),
                        curve: Curves.easeOutCubic,
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppTheme.primaryColor.withOpacity(0.12)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            AnimatedScale(
                              scale: isSelected ? 1.08 : 1.0,
                              duration: const Duration(milliseconds: 200),
                              child: Icon(
                                isSelected ? tab.activeIcon : tab.icon,
                                size: 23,
                                color: isSelected
                                    ? AppTheme.primaryColor
                                    : (isDark
                                        ? Colors.white54
                                        : const Color(0xFF8E8E93)),
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              tab.label,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.w500,
                                color: isSelected
                                    ? AppTheme.primaryColor
                                    : (isDark
                                        ? Colors.white54
                                        : const Color(0xFF8E8E93)),
                                letterSpacing: -0.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TabItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  _TabItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}
