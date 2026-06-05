import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/storage/secure_storage.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _completeOnboarding() async {
    final secureStorage = sl<SecureStorageService>();
    await secureStorage.saveHasSeenOnboarding(true);
    if (mounted) {
      context.go('/');
    }
  }

  void _nextPage() {
    if (_currentPage < 2) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOutCubic,
      );
    } else {
      _completeOnboarding();
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(
        0xFFF8F9FD,
      ), // Clean off-white/light blue background
      body: Stack(
        children: [
          // 1. Soft Circular Gradient behind illustrations (Brand Purple tint)
          Positioned(
            top: size.height * 0.15,
            left: size.width * 0.1,
            right: size.width * 0.1,
            height: size.height * 0.4,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF6366F1).withOpacity(0.08),
                    const Color(0xFF6366F1).withOpacity(0.0),
                  ],
                ),
              ),
            ),
          ),

          // 2. Subtle decorative dots/circles in background
          Positioned.fill(
            child: CustomPaint(painter: _BackgroundDotsPainter(seed: 42)),
          ),

          // 3. Skip Button (Top Right - Purple)
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            right: 20,
            child: TextButton(
              onPressed: _completeOnboarding,
              child: const Text(
                'Skip',
                style: TextStyle(
                  color: Color(0xFF6366F1), // brand purple
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

          // 4. PageView Content
          Positioned.fill(
            child: PageView(
              controller: _pageController,
              onPageChanged: (page) {
                setState(() {
                  _currentPage = page;
                });
              },
              children: [
                _buildSlide1(size),
                _buildSlide2(size),
                _buildSlide3(size),
              ],
            ),
          ),

          // 5. Footer (Dot Indicators & Action Button)
          Positioned(
            left: 0,
            right: 0,
            bottom: MediaQuery.of(context).padding.bottom + 32,
            child: Column(
              children: [
                // Page Indicator Dots (Purple active, light gray inactive)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    3,
                    (index) => AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.symmetric(horizontal: 5),
                      height: 8,
                      width: _currentPage == index ? 24 : 8,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        color: _currentPage == index
                            ? const Color(0xFF6366F1)
                            : const Color(0xFF6366F1).withOpacity(0.2),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Compact Action Button
                Container(
                  width: 220,
                  height: 48,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF6366F1).withOpacity(0.35),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: _nextPage,
                    child: Text(
                      _currentPage == 2 ? 'Get Started' : 'Next',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // SLIDE 1: Create Live Polls
  // ==========================================
  Widget _buildSlide1(Size size) {
    final isSmallScreen = size.height < 720;
    final bottomOffset = isSmallScreen ? 15.0 : 25.0;
    final phoneMarginBottom = isSmallScreen ? 20.0 : 30.0;

    return _buildSlideLayout(
      titleText: 'Create Live Polls',
      description:
          'Ask questions, run polls and get instant feedback from your audience.',
      illustration: Stack(
        alignment: Alignment.center,
        children: [
          // Width-only SizedBox to spread floating items horizontally
          SizedBox(width: size.width),

          // Base shadow glow under the phone
          Positioned(
            bottom: bottomOffset,
            child: Container(
              width: 195,
              height: 10,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(100),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF6366F1).withOpacity(0.12),
                    blurRadius: 16,
                    spreadRadius: 2,
                  ),
                ],
              ),
            ),
          ).animate().fadeIn(duration: 800.ms),

          // Phone Mockup (Light Mode Bezel & Details)
          Container(
            width: 240,
            margin: EdgeInsets.only(bottom: phoneMarginBottom),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: const Color(0xFFE2E8F0), width: 3),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(14.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Phone Status/Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Live Poll',
                        style: TextStyle(
                          color: Color(0xFF64748B), // Slate 500
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEE2E2), // light red 100
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: const Color(0xFFFCA5A5),
                            width: 0.5,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 4,
                              height: 4,
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 3),
                            const Text(
                              'LIVE',
                              style: TextStyle(
                                color: Colors.red,
                                fontSize: 7.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: isSmallScreen ? 10 : 16),

                  // Poll Question
                  const Text(
                    'What feature do you like the most?',
                    style: TextStyle(
                      color: Color(0xFF1E293B), // Slate 800
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                      height: 1.3,
                    ),
                  ),
                  SizedBox(height: isSmallScreen ? 12 : 20),

                  // Options Column (fixed 8px gap between every item)
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildMiniPollOption('Real-time Polls', 0.45, [
                        const Color(0xFF8B5CF6),
                        const Color(0xFF6366F1),
                      ]),
                      const SizedBox(height: 8),
                      _buildMiniPollOption('Q&A', 0.28, [
                        const Color(0xFF3B82F6),
                        const Color(0xFF60A5FA),
                      ]),
                      const SizedBox(height: 8),
                      _buildMiniPollOption('Live Quizzes', 0.17, [
                        const Color(0xFF10B981),
                        const Color(0xFF34D399),
                      ]),
                      const SizedBox(height: 8),
                      _buildMiniPollOption('Analytics', 0.10, [
                        const Color(0xFFF59E0B),
                        const Color(0xFFFBBF24),
                      ]),
                    ],
                  ),
                ],
              ),
            ),
          ).animate().scale(
            duration: 600.ms,
            curve: Curves.easeOutBack,
            begin: const Offset(0.8, 0.8),
          ),

          // Floating bubbles surrounding the phone (Light glassmorphism style)
          // 1. Chart Bubble (Top Left) - Medium-Large
          Positioned(
            left: 10,
            top: 45,
            child:
                _buildFloatingGlassBubble(
                      icon: Icons.insert_chart_rounded,
                      color: const Color(0xFF6366F1),
                      size: 50,
                      iconSize: 24,
                    )
                    .animate(onPlay: (c) => c.repeat(reverse: true))
                    .slideY(
                      begin: 0,
                      end: 0.15,
                      duration: 1600.ms,
                      curve: Curves.easeInOut,
                    ),
          ),

          // 2. Crowd count indicator bubble (Middle Right)
          Positioned(
            right: 16,
            bottom: 90,
            child:
                _buildTextGlassBubble(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.people_alt_rounded,
                            size: 14,
                            color: Color(0xFF6366F1),
                          ),
                          const SizedBox(width: 4),
                          const Text(
                            '200+',
                            style: TextStyle(
                              color: Color(0xFF1E293B),
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    )
                    .animate(onPlay: (c) => c.repeat(reverse: true))
                    .slideY(
                      begin: 0,
                      end: -0.15,
                      duration: 1800.ms,
                      curve: Curves.easeInOut,
                    ),
          ),
        ],
      ),
    );
  }

  // Mini Option Builder for Slide 1 Phone
  Widget _buildMiniPollOption(
    String label,
    double percentage,
    List<Color> colors,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Color(0xFF475569),
                  fontSize: 8.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '${(percentage * 100).toInt()}%',
                style: const TextStyle(
                  color: Color(0xFF1E293B),
                  fontSize: 8.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            height: 6,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9), // Slate 100 background
              borderRadius: BorderRadius.circular(3),
            ),
            alignment: Alignment.centerLeft,
            child:
                FractionallySizedBox(
                      widthFactor: percentage,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(3),
                          gradient: LinearGradient(
                            colors: colors,
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                        ),
                      ),
                    )
                    .animate(delay: 300.ms)
                    .fadeIn(duration: 400.ms)
                    .scale(
                      begin: const Offset(0, 1),
                      duration: 800.ms,
                      curve: Curves.easeOutCubic,
                    ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // SLIDE 2: Manage Q&A
  // ==========================================
  Widget _buildSlide2(Size size) {
    final isSmallScreen = size.height < 720;
    final phoneMarginBottom = isSmallScreen ? 20.0 : 30.0;

    return _buildSlideLayout(
      titleText: 'Manage Q&A',
      description:
          'Let your audience ask questions and upvote the ones that matter most.',
      illustration: Stack(
        alignment: Alignment.center,
        children: [
          // Width-only SizedBox to spread floating items horizontally
          SizedBox(width: size.width),

          // Outer background Q&A layout container
              Container(
                width: 240,
                margin: EdgeInsets.only(bottom: phoneMarginBottom),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: const Color(0xFFE2E8F0), width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: EdgeInsets.only(
                        left: 6,
                        bottom: isSmallScreen ? 8 : 12,
                      ),
                      child: const Text(
                        'Top Questions',
                        style: TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Question 1
                        _buildMiniQaCard(
                              avatarGradient: const [
                                Color(0xFFF43F5E),
                                Color(0xFFEC4899),
                              ],
                              name: 'Shubham Kale',
                              question: 'What is the pricing of QLix?',
                              upvoteCount: 32,
                              chevronColor: const Color(0xFF6366F1),
                              statusText: 'Approved',
                              statusColor: const Color(0xFF10B981),
                              statusBgColor: const Color(0xFFD1FAE5),
                              timeText: '2m ago',
                            )
                            .animate()
                            .fadeIn(duration: 400.ms)
                            .slideX(begin: -0.1),

                        const SizedBox(height: 8),

                        // Question 2 (Anonymous)
                        _buildMiniQaCard(
                              avatarGradient: const [
                                Color(0xFF475569),
                                Color(0xFF64748B),
                              ],
                              name: 'Anonymous',
                              question:
                                  'Will the recording be available later?',
                              upvoteCount: 18,
                              statusText: 'Approved',
                              statusColor: const Color(0xFF10B981),
                              statusBgColor: const Color(0xFFD1FAE5),
                              chevronColor: const Color(0xFF6366F1),
                              timeText: 'Just now',
                            )
                            .animate(delay: 200.ms)
                            .fadeIn(duration: 400.ms)
                            .slideX(begin: 0.1),

                        // Question 3 (Shown only on standard screen to prevent overflow)
                        if (!isSmallScreen) ...[
                          const SizedBox(height: 8),
                          _buildMiniQaCard(
                                avatarGradient: const [
                                  Color(0xFF3B82F6),
                                  Color(0xFF06B6D4),
                                ],
                                name: 'Akshay Gorade',
                                question: 'Can you share the resources?',
                                upvoteCount: 7,
                                statusText: 'Pending',
                                statusColor: const Color(0xFFD97706),
                                statusBgColor: const Color(0xFFFEF3C7),
                                chevronColor: const Color(0xFF94A3B8),
                              )
                              .animate(delay: 400.ms)
                              .fadeIn(duration: 400.ms)
                              .slideX(begin: -0.1),
                        ],
                      ],
                    ),
                    SizedBox(height: isSmallScreen ? 8 : 12),
                    // Mock Input Bar
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: const [
                          Expanded(
                            child: Text(
                              'Ask a question...',
                              style: TextStyle(
                                color: Color(0xFF94A3B8),
                                fontSize: 9.5,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          Icon(
                            Icons.send_rounded,
                            size: 12,
                            color: Color(0xFF6366F1),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Floating indicators/decorations (All premium glass bubbles)
              // 1. Question Answer bubble (Top Left) - Large
              Positioned(
                left: 0,
                top: 0,
                child:
                    _buildFloatingGlassBubble(
                          icon: Icons.question_answer_rounded,
                          color: const Color(0xFF6366F1), // Purple
                          size: 45,
                          iconSize: 22,
                        )
                        .animate(onPlay: (c) => c.repeat(reverse: true))
                        .slideY(
                          begin: 0,
                          end: 0.12,
                          duration: 1600.ms,
                          curve: Curves.easeInOut,
                        ),
              ),

              // 2. Task Alt (Checkmark) bubble (Top Right) - Medium
              Positioned(
                right: 10,
                bottom: 40,
                child:
                    _buildFloatingGlassBubble(
                          icon: Icons.task_alt_rounded,
                          color: const Color(0xFF10B981), // Emerald Green
                          size: 40,
                          iconSize: 18,
                        )
                        .animate(onPlay: (c) => c.repeat(reverse: true))
                        .slideY(
                          begin: 0,
                          end: -0.12,
                          duration: 1800.ms,
                          curve: Curves.easeInOut,
                        ),
              ),
        ],
      ),
    );
  }

  // Mini Q&A Card Widget for Slide 2
  Widget _buildMiniQaCard({
    required List<Color> avatarGradient,
    required String name,
    required String question,
    required int upvoteCount,
    String? statusText,
    Color? statusColor,
    Color? statusBgColor,
    required Color chevronColor,
    String? timeText,
  }) {
    final isSmallScreen = MediaQuery.of(context).size.height < 720;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 10,
        vertical: isSmallScreen ? 6 : 10,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Author Row
          Row(
            children: [
              Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(colors: avatarGradient),
                ),
                child: const Icon(Icons.person, size: 10, color: Colors.white),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        color: Color(0xFF1E293B),
                        fontSize: 8.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (timeText != null)
                      Text(
                        timeText,
                        style: const TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 7,
                        ),
                      ),
                  ],
                ),
              ),
              Icon(
                Icons.keyboard_arrow_up_rounded,
                size: 14,
                color: chevronColor,
              ),
              const SizedBox(width: 2),
              Text(
                '$upvoteCount',
                style: TextStyle(
                  color: chevronColor,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Question Text
          Text(
            question,
            style: const TextStyle(
              color: Color(0xFF475569),
              fontSize: 8.5,
              height: 1.3,
            ),
          ),

          // Status Badge Row
          if (statusText != null) ...[
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerRight,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: statusBgColor ?? const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: (statusColor ?? Colors.grey).withOpacity(0.3),
                    width: 0.5,
                  ),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 7,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ==========================================
  // SLIDE 3: Run Interactive Quizzes
  // ==========================================
  Widget _buildSlide3(Size size) {
    final isSmallScreen = size.height < 720;
    final phoneMarginBottom = isSmallScreen ? 20.0 : 30.0;
    final podium2ndHeight = isSmallScreen ? 40.0 : 65.0;
    final podium1stHeight = isSmallScreen ? 55.0 : 85.0;
    final podium3rdHeight = isSmallScreen ? 30.0 : 50.0;

    return _buildSlideLayout(
      titleText: 'Run Interactive Quizzes',
      description:
          'Make learning and events more engaging with fun quizzes and leaderboards.',
      illustration: Stack(
        alignment: Alignment.center,
        children: [
          // Width-only SizedBox to spread floating items horizontally
          SizedBox(width: size.width),

          // Leaderboard Container
          Container(
            width: 240,
            margin: EdgeInsets.only(bottom: phoneMarginBottom),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: const Color(0xFFE2E8F0), width: 3),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              children: [
                const Text(
                  'Live Quiz Leaderboard',
                  style: TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: isSmallScreen ? 10 : 16),

                // Podium layout (1st, 2nd, 3rd)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // 2nd Place
                    _buildPodiumBlock(
                      height: podium2ndHeight,
                      label: '2',
                      score: '2,100',
                      blockColor: const Color(0xFFEEF2F6),
                      textColor: const Color(0xFF6366F1),
                      avatarGradient: const [
                        Color(0xFFC084FC),
                        Color(0xFF6366F1),
                      ],
                    ).animate().fadeIn(duration: 400.ms).scaleY(begin: 0),

                    const SizedBox(width: 8),

                    // 1st Place (taller, crown on top)
                    _buildPodiumBlock(
                          height: podium1stHeight,
                          label: '1',
                          score: '2,450',
                          blockColor: const Color(0xFFFEF3C7),
                          textColor: const Color(0xFFD97706),
                          avatarGradient: const [
                            Color(0xFFFBBF24),
                            Color(0xFFD97706),
                          ],
                          hasCrown: true,
                        )
                        .animate(delay: 200.ms)
                        .fadeIn(duration: 500.ms)
                        .scaleY(begin: 0),

                    const SizedBox(width: 8),

                    // 3rd Place
                    _buildPodiumBlock(
                          height: podium3rdHeight,
                          label: '3',
                          score: '1,850',
                          blockColor: const Color(0xFFE0F2FE),
                          textColor: const Color(0xFF0284C7),
                          avatarGradient: const [
                            Color(0xFF38BDF8),
                            Color(0xFF0284C7),
                          ],
                        )
                        .animate(delay: 400.ms)
                        .fadeIn(duration: 400.ms)
                        .scaleY(begin: 0),
                  ],
                ),
                SizedBox(height: isSmallScreen ? 10 : 16),

                // Bottom list players (fixed 4px gap rows, consistent dividers)
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildPlayerRow('Mahesh Thombare', '1,650', const [
                      Color(0xFFEF4444),
                      Color(0xFFEC4899),
                    ]),
                    const SizedBox(height: 4),
                    const Divider(color: Color(0xFFF1F5F9), height: 1),
                    const SizedBox(height: 4),
                    _buildPlayerRow('Richa Sharma', '1,430', const [
                      Color(0xFF10B981),
                      Color(0xFF3B82F6),
                    ]),
                    const SizedBox(height: 4),
                    const Divider(color: Color(0xFFF1F5F9), height: 1),
                    const SizedBox(height: 4),
                    _buildPlayerRow('Atul Bhagwat', '1,210', const [
                      Color(0xFFF59E0B),
                      Color(0xFFEC4899),
                    ], isYou: true),
                    if (!isSmallScreen) ...[
                      const SizedBox(height: 4),
                      const Divider(color: Color(0xFFF1F5F9), height: 1),
                      const SizedBox(height: 4),
                      _buildPlayerRow('Pratika Rawal', '1,050', const [
                        Color(0xFF3B82F6),
                        Color(0xFF06B6D4),
                      ]),
                    ],
                  ],
                ),
              ],
            ),
          ),

          // Floating indicators/decorations (All premium glass bubbles)
          // 1. Trophy/Events Bubble (Top Left) - Large
          Positioned(
            right: 10,
            top: 5,
            child:
                _buildFloatingGlassBubble(
                      icon: Icons.emoji_events_rounded,
                      color: const Color(0xFFF59E0B), // Gold/Amber
                      size: 48,
                      iconSize: 22,
                    )
                    .animate(onPlay: (c) => c.repeat(reverse: true))
                    .slideY(
                      begin: 0,
                      end: 0.12,
                      duration: 1600.ms,
                      curve: Curves.easeInOut,
                    ),
          ),

          // 4. Achievement/Star Bubble (Bottom Right) - Medium
          Positioned(
            left: 20,
            bottom: 20,
            child:
                _buildFloatingGlassBubble(
                      icon: Icons.workspace_premium_rounded,
                      color: const Color(0xFF8B5CF6), // Purple
                      size: 40,
                      iconSize: 18,
                    )
                    .animate(onPlay: (c) => c.repeat(reverse: true))
                    .slideY(
                      begin: 0,
                      end: -0.15,
                      duration: 1400.ms,
                      curve: Curves.easeInOut,
                    ),
          ),
        ],
      ),
    );
  }

  // Builder for Podium vertical block inside Leaderboard
  Widget _buildPodiumBlock({
    required double height,
    required String label,
    required String score,
    required Color blockColor,
    required Color textColor,
    required List<Color> avatarGradient,
    bool hasCrown = false,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // User avatar above block
        Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            if (hasCrown)
              const Positioned(
                top: -14,
                child: Icon(
                  Icons.workspace_premium_rounded,
                  color: Color(0xFFFBBF24),
                  size: 16,
                ),
              ),
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.5),
                gradient: LinearGradient(colors: avatarGradient),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(Icons.person, size: 12, color: Colors.white),
            ),
          ],
        ),
        const SizedBox(height: 6),

        // Podium Block
        Container(
          width: 50,
          height: height,
          decoration: BoxDecoration(
            color: blockColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
            boxShadow: [
              BoxShadow(
                color: blockColor.withOpacity(0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: textColor,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                score,
                style: TextStyle(
                  color: textColor.withOpacity(0.8),
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Player Row widget for Slide 3 List
  Widget _buildPlayerRow(
    String name,
    String score,
    List<Color> avatarGradient, {
    bool isYou = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 5.0, horizontal: 8.0),
      decoration: isYou
          ? BoxDecoration(
              color: const Color(0xFF6366F1).withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: const Color(0xFF6366F1).withOpacity(0.3),
                width: 1,
              ),
            )
          : null,
      child: Row(
        children: [
          Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(colors: avatarGradient),
            ),
            child: const Icon(Icons.person, size: 10, color: Colors.white),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Row(
              children: [
                Text(
                  name,
                  style: TextStyle(
                    color: isYou
                        ? const Color(0xFF6366F1)
                        : const Color(0xFF1E293B),
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (isYou) ...[
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 1.5,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'YOU',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 6,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Text(
            score,
            style: TextStyle(
              color: isYou ? const Color(0xFF6366F1) : const Color(0xFF64748B),
              fontSize: 9,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // UTILS & SHARED WIDGETS
  // ==========================================

  // Slide Layout wrapper
  Widget _buildSlideLayout({
    required String titleText,
    required String description,
    required Widget illustration,
  }) {
    final mediaQuery = MediaQuery.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          SizedBox(
            height: mediaQuery.padding.top + 70.0,
          ), // Pushes cards and floating icons down from the top status area
          Expanded(child: Center(child: illustration)),
          const SizedBox(height: 20),
          // Title
          Text(
            titleText,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A), // Slate 900
            ),
          ),
          const SizedBox(height: 10),
          // Description
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              description,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF64748B), // Slate 500
                fontSize: 13,
                fontWeight: FontWeight.normal,
                height: 1.45,
              ),
            ),
          ),
          SizedBox(
            height: mediaQuery.padding.bottom + 130.0,
          ), // Aligns description text precisely 40-60px above bottom footer buttons
        ],
      ),
    );
  }

  // Floating Glass Bubble with Icon (Styled for Light Mode Glassmorphism)
  Widget _buildFloatingGlassBubble({
    required IconData icon,
    required Color color,
    double size = 38,
    double? iconSize,
  }) {
    final computedIconSize = iconSize ?? (size * 0.42);
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipOval(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: Container(
            width: size,
            height: size,
            color: Colors.white.withOpacity(0.85),
            child: Center(
              child: Icon(icon, size: computedIconSize, color: color),
            ),
          ),
        ),
      ),
    );
  }

  // Floating Glass Bubble with Custom Child (Styled for Light Mode Glassmorphism)
  Widget _buildTextGlassBubble({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            color: Colors.white.withOpacity(0.85),
            child: child,
          ),
        ),
      ),
    );
  }
}

// -------------------------------------------------------------
// Background Decorative Dots Painter (for subtle light mode detailing)
// -------------------------------------------------------------
class _BackgroundDotsPainter extends CustomPainter {
  final int seed;

  _BackgroundDotsPainter({required this.seed});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFF6366F1);
    final rand = math.Random(seed);

    for (int i = 0; i < 25; i++) {
      final x = rand.nextDouble() * size.width;
      final y = rand.nextDouble() * size.height;
      final radius = rand.nextDouble() * 2.0 + 0.5;
      final opacity = rand.nextDouble() * 0.08 + 0.02; // Very subtle dots

      paint.color = const Color(0xFF6366F1).withOpacity(opacity);
      canvas.drawCircle(Offset(x, y), radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
