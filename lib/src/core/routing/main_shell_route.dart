import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';
import '../../features/cart/application/cart_provider.dart';
import '../../features/tracking/application/tracking_provider.dart';

class MainShellRoute extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;

  const MainShellRoute({
    super.key,
    required this.navigationShell,
  });

  void _onTap(int index) {
    HapticFeedback.selectionClick();
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cartCount = ref.watch(cartProvider.select((s) => s.totalItemCount));
    final hasActiveOrder = ref.watch(orderTrackingProvider.select((s) => s.hasActiveOrder));
    final currentIndex = navigationShell.currentIndex;

    return Scaffold(
      backgroundColor: AppColors.background,
      extendBody: false,
      body: navigationShell,
      bottomNavigationBar: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.96),
              border: const Border(
                top: BorderSide(color: AppColors.border, width: 0.8),
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0C000000),
                  blurRadius: 20,
                  offset: Offset(0, -4),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Container(
                height: 62,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildNavItem(
                      index: 0,
                      currentIndex: currentIndex,
                      label: 'Menü',
                      icon: CupertinoIcons.book,
                      activeIcon: CupertinoIcons.book_fill,
                    ),
                    _buildNavItem(
                      index: 1,
                      currentIndex: currentIndex,
                      label: 'Sepetim',
                      icon: CupertinoIcons.bag,
                      activeIcon: CupertinoIcons.bag_fill,
                      badgeCount: cartCount,
                    ),
                    _buildNavItem(
                      index: 2,
                      currentIndex: currentIndex,
                      label: 'Takip',
                      icon: CupertinoIcons.flame,
                      activeIcon: CupertinoIcons.flame_fill,
                      showLiveDot: hasActiveOrder,
                    ),
                    _buildNavItem(
                      index: 3,
                      currentIndex: currentIndex,
                      label: 'Fırsatlar',
                      icon: CupertinoIcons.ticket,
                      activeIcon: CupertinoIcons.ticket_fill,
                    ),
                    _buildNavItem(
                      index: 4,
                      currentIndex: currentIndex,
                      label: 'Hesabım',
                      icon: CupertinoIcons.person_crop_circle,
                      activeIcon: CupertinoIcons.person_crop_circle_fill,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required int currentIndex,
    required String label,
    required IconData icon,
    required IconData activeIcon,
    int badgeCount = 0,
    bool showLiveDot = false,
  }) {
    final isSelected = index == currentIndex;

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _onTap(index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                padding: EdgeInsets.symmetric(
                  horizontal: isSelected ? 16 : 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primaryLight
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                  border: isSelected
                      ? Border.all(
                          color: AppColors.primary.withValues(alpha: 0.25),
                          width: 0.8,
                        )
                      : null,
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(
                      isSelected ? activeIcon : icon,
                      color: isSelected ? AppColors.primary : AppColors.textSecondary,
                      size: 21,
                    ),
                    if (badgeCount > 0)
                      Positioned(
                        top: -6,
                        right: -11,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5.5, vertical: 1.5),
                          decoration: BoxDecoration(
                            gradient: AppColors.primaryGradient,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.white, width: 1.2),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withValues(alpha: 0.45),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Text(
                            badgeCount > 99 ? '99+' : badgeCount.toString(),
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      )
                    else if (showLiveDot)
                      Positioned(
                        top: -3,
                        right: -5,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981),
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.background, width: 1.2),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF10B981).withValues(alpha: 0.6),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 3),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 180),
                style: isSelected
                    ? GoogleFonts.plusJakartaSans(
                        color: AppColors.primary,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.1,
                      )
                    : GoogleFonts.plusJakartaSans(
                        color: AppColors.textMuted,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                      ),
                child: Text(label),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
