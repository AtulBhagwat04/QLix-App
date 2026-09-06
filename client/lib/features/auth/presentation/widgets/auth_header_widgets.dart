import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_images.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/constants/app_animations.dart';
import '../../../../core/constants/app_sizes.dart';

/// Top branding illustration used in login and signup screens with responsive scaling
class AuthTopIllustration extends StatelessWidget {
  const AuthTopIllustration({super.key});

  @override
  Widget build(BuildContext context) {
    final double boxWidth = context.rSize(180, minScale: 0.85, maxScale: 1.2);
    final double boxHeight = context.rSize(140, minScale: 0.85, maxScale: 1.2);
    final double blobWidth = context.rSize(140, minScale: 0.85, maxScale: 1.2);
    final double blobHeight = context.rSize(120, minScale: 0.85, maxScale: 1.2);
    final double logoSize = context.rSize(76, minScale: 0.85, maxScale: 1.2);

    return SizedBox(
      width: boxWidth,
      height: boxHeight,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          // 1. Organic soft background blob
          Positioned(
            child: Container(
              width: blobWidth,
              height: blobHeight,
              decoration: BoxDecoration(
                color: AppColors.primarySoft.withValues(alpha: 0.85),
                borderRadius: const BorderRadius.all(Radius.elliptical(85, 70)),
              ),
            ),
          ).animate().scale(
            duration: AppDurations.extraSlow,
            curve: AppCurves.bounce,
          ),

          // 2. Main Logo (QLix brand image asset)
          Positioned(
            child: Container(
              width: logoSize,
              height: logoSize,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(context.rSize(20)),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryGlow,
                    blurRadius: context.rSize(20),
                    offset: Offset(0, context.rSize(10)),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(context.rSize(20)),
                child: Image.asset(
                  AppImages.appLogo,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF8B5CF6), Color(0xFF3B82F6)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      'Q',
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ).animate().scale(
            begin: const Offset(0.7, 0.7),
            duration: AppDurations.slow,
            curve: AppCurves.bounce,
          ),

          // 3. Scattered decorations (crosses, circles)
          Positioned(
            left: context.rSize(10),
            top: context.rSize(20),
            child: Text(
              '×',
              style: TextStyle(
                color: AppColors.purpleAccent,
                fontSize: context.rSize(22),
                fontWeight: FontWeight.bold,
              ),
            ).animate(onPlay: (c) => c.repeat(reverse: true)).slideY(
              begin: 0,
              end: -0.15,
              duration: const Duration(milliseconds: 1500),
            ),
          ),
          Positioned(
            left: context.rSize(8),
            bottom: context.rSize(30),
            child: Container(
              width: context.rSize(8),
              height: context.rSize(8),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.purpleAccent,
                  width: 1.5,
                ),
              ),
            ).animate(onPlay: (c) => c.repeat(reverse: true)).slideY(
              begin: 0,
              end: 0.15,
              duration: const Duration(milliseconds: 1800),
            ),
          ),
          Positioned(
            right: context.rSize(12),
            top: context.rSize(40),
            child: Container(
              width: context.rSize(7),
              height: context.rSize(7),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.purpleAccent,
                  width: 1.5,
                ),
              ),
            ).animate(onPlay: (c) => c.repeat(reverse: true)).slideY(
              begin: 0,
              end: -0.2,
              duration: const Duration(milliseconds: 1600),
            ),
          ),
          Positioned(
            right: context.rSize(16),
            bottom: context.rSize(18),
            child: Text(
              '×',
              style: TextStyle(
                color: AppColors.purpleAccent,
                fontSize: context.rSize(18),
                fontWeight: FontWeight.bold,
              ),
            ).animate(onPlay: (c) => c.repeat(reverse: true)).slideY(
              begin: 0,
              end: 0.15,
              duration: const Duration(milliseconds: 2000),
            ),
          ),
        ],
      ),
    );
  }
}

/// Tab Switcher for toggling between Login and Sign Up
class AuthTabSwitcher extends StatelessWidget {
  final bool isLogin;

  const AuthTabSwitcher({super.key, required this.isLogin});

  @override
  Widget build(BuildContext context) {
    final indicatorWidth = context.wPct(25).clamp(80.0, 120.0);

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () {
                  if (!isLogin) {
                    context.go('/login');
                  }
                },
                behavior: HitTestBehavior.opaque,
                child: Column(
                  children: [
                    Text(
                      AppStrings.login,
                      style: TextStyle(
                        fontSize: context.rSize(15),
                        fontWeight: isLogin ? FontWeight.bold : FontWeight.w600,
                        color: isLogin
                            ? AppColors.primary
                            : AppColors.textPlaceholder,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      height: 2.5,
                      width: indicatorWidth,
                      decoration: BoxDecoration(
                        color: isLogin
                            ? AppColors.primary
                            : Colors.transparent,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(2),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: GestureDetector(
                onTap: () {
                  if (isLogin) {
                    context.go('/signup');
                  }
                },
                behavior: HitTestBehavior.opaque,
                child: Column(
                  children: [
                    Text(
                      AppStrings.signUp,
                      style: TextStyle(
                        fontSize: context.rSize(15),
                        fontWeight: !isLogin ? FontWeight.bold : FontWeight.w600,
                        color: !isLogin
                            ? AppColors.primary
                            : AppColors.textPlaceholder,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      height: 2.5,
                      width: indicatorWidth,
                      decoration: BoxDecoration(
                        color: !isLogin
                            ? AppColors.primary
                            : Colors.transparent,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(2),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        Container(height: 1, color: AppColors.divider),
      ],
    );
  }
}
