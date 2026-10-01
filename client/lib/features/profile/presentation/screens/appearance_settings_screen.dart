import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/constants/app_colors.dart';
import '../cubits/theme_cubit.dart';
import '../widgets/appearance_theme_card.dart';
import '../widgets/profile_app_bar.dart';

class AppearanceSettingsScreen extends StatefulWidget {
  const AppearanceSettingsScreen({super.key});

  @override
  State<AppearanceSettingsScreen> createState() => _AppearanceSettingsScreenState();
}

class _AppearanceSettingsScreenState extends State<AppearanceSettingsScreen> {
  int _selectedColorIndex = 0;
  bool _hapticFeedback = true;
  bool _reducedMotion = false;
  bool _compactCards = false;

  final List<Color> _accentColors = const [
    Color(0xFF6366F1), // Electric Indigo (Brand)
    Color(0xFF06B6D4), // Ice Cyan
    Color(0xFFF43F5E), // Sunset Rose
    Color(0xFF10B981), // Emerald Green
    Color(0xFFF59E0B), // Amber Gold
  ];

  final List<String> _colorNames = const [
    'Indigo',
    'Cyan',
    'Rose',
    'Emerald',
    'Amber',
  ];

  @override
  Widget build(BuildContext context) {
    final currentThemeMode = context.watch<ThemeCubit>().state;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final cardBorder = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? Colors.white : AppColors.textPrimaryLight;
    final textSub = isDark ? const Color(0xFF94A3B8) : AppColors.textSecondaryLight;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8F9FD),
      appBar: const ProfileAppBar(
        title: 'Appearance',
        subtitle: 'Theme & interface preferences',
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Theme Mode Selection
            _buildSectionLabel('Theme Mode', textPrimary),
            const SizedBox(height: 12),
            AppearanceThemeCard(
              title: 'Light Mode',
              description: 'Crisp bright background, optimized for high visibility',
              icon: Icons.wb_sunny_outlined,
              isSelected: currentThemeMode == ThemeMode.light,
              previewBackground: const Color(0xFFF8F9FD),
              previewCardColor: Colors.white,
              previewAccent: const Color(0xFF6366F1),
              onTap: () => context.read<ThemeCubit>().setThemeMode(ThemeMode.light),
            ),
            const SizedBox(height: 12),
            AppearanceThemeCard(
              title: 'Dark Mode',
              description: 'Deep slate surfaces, gentle on your eyes in low light',
              icon: Icons.nightlight_round_outlined,
              isSelected: currentThemeMode == ThemeMode.dark,
              previewBackground: const Color(0xFF0F172A),
              previewCardColor: const Color(0xFF1E293B),
              previewAccent: const Color(0xFF818CF8),
              onTap: () => context.read<ThemeCubit>().setThemeMode(ThemeMode.dark),
            ),
            const SizedBox(height: 12),
            AppearanceThemeCard(
              title: 'System Default',
              description: 'Automatically adjust based on your device system settings',
              icon: Icons.settings_system_daydream_rounded,
              isSelected: currentThemeMode == ThemeMode.system,
              previewBackground: const Color(0xFF64748B),
              previewCardColor: Colors.white,
              previewAccent: const Color(0xFF6366F1),
              onTap: () => context.read<ThemeCubit>().setThemeMode(ThemeMode.system),
            ),
            const SizedBox(height: 28),

            // Accent Color Palette
            _buildSectionLabel('Brand Accent Color', textPrimary),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: cardBorder, width: 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: List.generate(_accentColors.length, (index) {
                      final color = _accentColors[index];
                      final isSelected = index == _selectedColorIndex;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedColorIndex = index),
                        child: Column(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isSelected
                                      ? (isDark ? Colors.white : const Color(0xFF0F172A))
                                      : Colors.transparent,
                                  width: 3,
                                ),
                                boxShadow: [
                                  if (isSelected)
                                    BoxShadow(
                                      color: color.withValues(alpha: 0.4),
                                      blurRadius: 10,
                                      offset: const Offset(0, 3),
                                    ),
                                ],
                              ),
                              child: isSelected
                                  ? const Icon(Icons.check, color: Colors.white, size: 20)
                                  : null,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _colorNames[index],
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                color: isSelected ? textPrimary : textSub,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // Interface Experience Toggles
            _buildSectionLabel('Interface Preferences', textPrimary),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: cardBorder, width: 1),
              ),
              child: Column(
                children: [
                  _buildToggleRow(
                    icon: Icons.vibration_rounded,
                    title: 'Haptic Feedback',
                    subtitle: 'Vibrate on button taps and voting interactions',
                    value: _hapticFeedback,
                    isFirst: true,
                    isLast: false,
                    isDark: isDark,
                    textPrimary: textPrimary,
                    textSub: textSub,
                    onChanged: (val) => setState(() => _hapticFeedback = val),
                  ),
                  _buildToggleRow(
                    icon: Icons.slow_motion_video_rounded,
                    title: 'Reduced Animations',
                    subtitle: 'Minimize slide and transition animations',
                    value: _reducedMotion,
                    isFirst: false,
                    isLast: false,
                    isDark: isDark,
                    textPrimary: textPrimary,
                    textSub: textSub,
                    onChanged: (val) => setState(() => _reducedMotion = val),
                  ),
                  _buildToggleRow(
                    icon: Icons.view_compact_rounded,
                    title: 'Compact Session Cards',
                    subtitle: 'Display more sessions on screen with compact layout',
                    value: _compactCards,
                    isFirst: false,
                    isLast: true,
                    isDark: isDark,
                    textPrimary: textPrimary,
                    textSub: textSub,
                    onChanged: (val) => setState(() => _compactCards = val),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // Live Preview Card
            _buildSectionLabel('Theme Live Preview', textPrimary),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: cardBorder, width: 1),
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: _accentColors[_selectedColorIndex].withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      Icons.poll_rounded,
                      color: _accentColors[_selectedColorIndex],
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Interactive Live Poll #1',
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w800,
                            color: textPrimary,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '24 participants  •  Active Now',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: textSub,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: _accentColors[_selectedColorIndex],
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Live',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ).animate().fade(duration: 350.ms).slideY(begin: 0.03, end: 0),
      ),
    );
  }

  Widget _buildSectionLabel(String label, Color textColor) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 14.5,
        fontWeight: FontWeight.w800,
        color: textColor,
      ),
    );
  }

  Widget _buildToggleRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required bool isFirst,
    required bool isLast,
    required bool isDark,
    required Color textPrimary,
    required Color textSub,
    required ValueChanged<bool> onChanged,
  }) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.09),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: AppColors.primary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                        color: textSub,
                      ),
                    ),
                  ],
                ),
              ),
              Switch.adaptive(
                value: value,
                activeTrackColor: AppColors.primary,
                onChanged: onChanged,
              ),
            ],
          ),
        ),
        if (!isLast)
          Divider(
            height: 1,
            indent: 66,
            color: isDark ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFF1F5F9),
          ),
      ],
    );
  }
}
