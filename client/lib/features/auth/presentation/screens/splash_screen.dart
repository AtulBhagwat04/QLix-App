import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/storage/secure_storage.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';

class HostSplashWidget extends StatefulWidget {
  const HostSplashWidget({super.key});

  @override
  State<HostSplashWidget> createState() => _HostSplashWidgetState();
}

class _HostSplashWidgetState extends State<HostSplashWidget>
    with TickerProviderStateMixin {
  late AnimationController _loadingController;
  late Animation<double> _progressAnimation;
  late AnimationController _loopController;

  @override
  void initState() {
    super.initState();

    // Controller for the progress bar loading (2.5 seconds)
    _loadingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    );

    _progressAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _loadingController, curve: Curves.easeInOutSine),
    );

    // Repeating loop controller for continuous subtle UI movements (twinkling, floating, pulsing)
    _loopController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4000),
    )..repeat();

    // Trigger redirection when progress animation completes
    _loadingController.forward().then((_) {
      _handleRedirection();
    });
  }

  Future<void> _handleRedirection() async {
    if (!mounted) return;

    // Temporarily force onboarding redirection for design/preview phase
    if (mounted) {
      context.go('/onboarding');
    }
  }

  @override
  void dispose() {
    _loadingController.dispose();
    _loopController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Stack(
        children: [
          // 1. Light Gradient Background
          Container(
            width: size.width,
            height: size.height,
            color: const Color(0xFFF8F9FD),
          ),
          // Decorative soft background glow behind the logo
          Positioned(
            top: size.height * 0.25,
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

          // 2. Glowing Starfield (Subtle twinkling stars animated by repeating controller)
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _loopController,
              builder: (context, child) {
                return CustomPaint(
                  painter: _StarsPainter(pulse: _loopController.value),
                );
              },
            ),
          ),

          // 4. Floating Speech Bubbles (Desynchronized gentle floating motions)
          AnimatedBuilder(
            animation: _loopController,
            builder: (context, child) {
              final val = _loopController.value * 2 * math.pi;
              final offset1 = Offset(0, 7 * math.sin(val));
              final offset2 = Offset(0, 6 * math.cos(val + 1.2));
              final offset3 = Offset(0, 6.5 * math.sin(val + 2.4));
              final offset4 = Offset(0, 7 * math.cos(val + 3.6));

              return Stack(
                children: [
                  // Top-Left (Purple, chart icon)
                  Positioned(
                    left: size.width * 0.10,
                    top: size.height * 0.18,
                    child: Transform.translate(
                      offset: offset1,
                      child: const _FloatingBubble(
                        icon: Icons.insert_chart_rounded,
                        bubbleColor: Color(0xFF8B5CF6),
                        tailOnLeft: true,
                      ),
                    ),
                  ),
                  // Top-Right (Blue, question mark icon)
                  Positioned(
                    right: size.width * 0.14,
                    top: size.height * 0.16,
                    child: Transform.translate(
                      offset: offset2,
                      child: const _FloatingBubble(
                        icon: Icons.help_outline_rounded,
                        bubbleColor: Color(0xFF3B82F6),
                        tailOnLeft: true,
                      ),
                    ),
                  ),
                  // Middle-Right (Pink, heart icon)
                  Positioned(
                    right: size.width * 0.10,
                    top: size.height * 0.32,
                    child: Transform.translate(
                      offset: offset3,
                      child: const _FloatingBubble(
                        icon: Icons.favorite_rounded,
                        bubbleColor: Color(0xFFEC4899),
                        tailOnLeft: true,
                      ),
                    ),
                  ),
                  // Lower-Left (Orange/Yellow, thumbs up icon)
                  Positioned(
                    left: size.width * 0.08,
                    top: size.height * 0.45,
                    child: Transform.translate(
                      offset: offset4,
                      child: const _FloatingBubble(
                        icon: Icons.thumb_up_rounded,
                        bubbleColor: Color(0xFFF59E0B),
                        tailOnLeft: false,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),

          // 5. App Logo (Center Vector Drawing with Pulse Scale & Glowing shadow animation)
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedBuilder(
                  animation: _loopController,
                  builder: (context, child) {
                    final pulseScale =
                        1.0 +
                        0.03 * math.sin(_loopController.value * 2 * math.pi);
                    return Transform.scale(
                      scale: pulseScale,
                      child: SizedBox(
                        width: 130,
                        height: 130,
                        child: CustomPaint(
                          painter: _LogoPainter(pulse: _loopController.value),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 36),

                // QLix text (Q in slate-black, Lix with brand gradient)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Q',
                      style: TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0F172A),
                        letterSpacing: -1.5,
                      ),
                    ),
                    ShaderMask(
                      shaderCallback: (bounds) => const LinearGradient(
                        colors: [Color(0xFF8B5CF6), Color(0xFF3B82F6)],
                      ).createShader(bounds),
                      child: const Text(
                        'Lix',
                        style: TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: -1.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Slogan text
                RichText(
                  text: const TextSpan(
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF475569),
                      letterSpacing: 0.2,
                    ),
                    children: [
                      TextSpan(text: 'Engage Every Audience '),
                      TextSpan(
                        text: 'Live',
                        style: TextStyle(
                          color: Color(0xFF3B82F6),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 6. Loader and loading text (Bottom)
          Positioned(
            left: 0,
            right: 0,
            bottom: size.height * 0.06,
            child: Column(
              children: [
                // Custom Capsule progress indicator
                Container(
                  width: 170,
                  height: 6,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  alignment: Alignment.centerLeft,
                  child: AnimatedBuilder(
                    animation: _progressAnimation,
                    builder: (context, child) {
                      return Container(
                        width: 170 * _progressAnimation.value,
                        height: 6,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(3),
                          gradient: const LinearGradient(
                            colors: [Color(0xFF8B5CF6), Color(0xFF06B6D4)],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF06B6D4).withOpacity(0.25),
                              blurRadius: 6,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Loading amazing experiences...',
                  style: TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// -------------------------------------------------------------
// Stars Painter
// -------------------------------------------------------------
class _StarsPainter extends CustomPainter {
  final double pulse;

  _StarsPainter({required this.pulse});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFF6366F1);
    final rand = math.Random(101); // Seeded random to keep stars static

    for (int i = 0; i < 70; i++) {
      final x = rand.nextDouble() * size.width;
      final y = rand.nextDouble() * size.height;
      final radius = rand.nextDouble() * 1.5 + 0.5;

      // Twinkle individual star based on loop value and its index phase
      final phase = rand.nextDouble() * 2 * math.pi;
      final twinkleOpacity =
          ((math.sin(pulse * 2 * math.pi + phase) * 0.04 + 0.05).clamp(
            0.01,
            0.12,
          ));

      paint.color = const Color(0xFF6366F1).withOpacity(twinkleOpacity);
      canvas.drawCircle(Offset(x, y), radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _StarsPainter oldDelegate) =>
      oldDelegate.pulse != pulse;
}

// -------------------------------------------------------------

// -------------------------------------------------------------
// Floating Glassmorphic Bubble
// -------------------------------------------------------------
class _FloatingBubble extends StatelessWidget {
  final IconData icon;
  final Color bubbleColor;
  final bool tailOnLeft;

  const _FloatingBubble({
    required this.icon,
    required this.bubbleColor,
    required this.tailOnLeft,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: CustomPaint(
        painter: _SpeechBubbleBorderPainter(
          color: bubbleColor.withOpacity(0.4),
          tailOnLeft: tailOnLeft,
        ),
        child: ClipPath(
          clipper: _SpeechBubbleClipper(tailOnLeft: tailOnLeft),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 7, sigmaY: 7),
            child: Container(
              width: 48,
              height: 48,
              color: Colors.white.withOpacity(0.85),
              child: Center(
                child: Container(
                  margin: const EdgeInsets.only(
                    bottom: 5,
                  ), // Account for tail height
                  child: Icon(
                    icon,
                    size: 22,
                    color: bubbleColor,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SpeechBubbleClipper extends CustomClipper<Path> {
  final bool tailOnLeft;

  _SpeechBubbleClipper({required this.tailOnLeft});

  @override
  Path getClip(Size size) {
    final path = Path();
    final w = size.width;
    final h = size.height;
    final r = 12.0; // standard border radius
    final tailH = 6.0;

    // Draw main bubble rounded rect
    path.moveTo(r, 0);
    path.lineTo(w - r, 0);
    path.quadraticBezierTo(w, 0, w, r);
    path.lineTo(w, h - tailH - r);
    path.quadraticBezierTo(w, h - tailH, w - r, h - tailH);

    // Draw tail
    if (tailOnLeft) {
      path.lineTo(w * 0.40, h - tailH);
      path.lineTo(w * 0.25, h);
      path.lineTo(w * 0.22, h - tailH);
    } else {
      path.lineTo(w * 0.78, h - tailH);
      path.lineTo(w * 0.75, h);
      path.lineTo(w * 0.60, h - tailH);
    }

    path.lineTo(r, h - tailH);
    path.quadraticBezierTo(0, h - tailH, 0, h - tailH - r);
    path.lineTo(0, r);
    path.quadraticBezierTo(0, 0, r, 0);
    path.close();

    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class _SpeechBubbleBorderPainter extends CustomPainter {
  final Color color;
  final bool tailOnLeft;

  _SpeechBubbleBorderPainter({required this.color, required this.tailOnLeft});

  @override
  void paint(Canvas canvas, Size size) {
    final clipper = _SpeechBubbleClipper(tailOnLeft: tailOnLeft);
    final path = clipper.getClip(size);

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [color.withOpacity(0.95), color.withOpacity(0.3)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _SpeechBubbleBorderPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.tailOnLeft != tailOnLeft;
  }
}

// -------------------------------------------------------------
// Logo Vector Painter (Gradient "D" shape with Play cutout)
// -------------------------------------------------------------
class _LogoPainter extends CustomPainter {
  final double pulse;

  _LogoPainter({required this.pulse});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // 1. Draw outer glowing drop shadow (opacity pulses softly)
    final shadowOpacity = (0.12 + 0.05 * math.sin(pulse * 2 * math.pi)).clamp(
      0.05,
      0.22,
    );
    final shadowPaint = Paint()
      ..color = const Color(0xFF6366F1).withOpacity(shadowOpacity)
      ..imageFilter = ImageFilter.blur(sigmaX: 12, sigmaY: 12);

    final outerD = Path()
      ..moveTo(w * 0.22, h * 0.15)
      ..lineTo(w * 0.22, h * 0.82)
      ..cubicTo(w * 0.22, h * 0.90, w * 0.32, h * 0.95, w * 0.48, h * 0.95)
      ..cubicTo(w * 0.85, h * 0.95, w * 0.95, h * 0.75, w * 0.95, h * 0.55)
      ..cubicTo(w * 0.95, h * 0.35, w * 0.85, h * 0.15, w * 0.48, h * 0.15)
      ..lineTo(w * 0.22, h * 0.15)
      ..close();

    canvas.drawPath(outerD, shadowPaint);

    // 2. Draw Main D logo body with Play cutout using difference fill
    final mainPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFFC084FC), // Bright violet/purple
          Color(0xFF3B82F6), // Indigo/blue
          Color(0xFF06B6D4), // Cyan highlight
        ],
      ).createShader(Rect.fromLTWH(0, 0, w, h));

    final playCutout = Path()
      ..moveTo(w * 0.46, h * 0.36)
      ..lineTo(w * 0.46, h * 0.68)
      ..lineTo(w * 0.72, h * 0.52)
      ..close();

    final logoBody = Path.combine(PathOperation.difference, outerD, playCutout);
    canvas.drawPath(logoBody, mainPaint);

    // 3. Draw bottom-left Ribbon Fold Overlay
    final foldPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFF3B82F6), // Matches main body
          Color(0xFF1E3A8A), // Dark shadow tone for overlap depth
        ],
      ).createShader(Rect.fromLTWH(w * 0.22, h * 0.60, w * 0.28, h * 0.35));

    final foldPath = Path()
      ..moveTo(w * 0.22, h * 0.82)
      ..cubicTo(w * 0.22, h * 0.90, w * 0.32, h * 0.95, w * 0.48, h * 0.95)
      ..lineTo(w * 0.38, h * 0.80)
      ..cubicTo(w * 0.30, h * 0.80, w * 0.25, h * 0.75, w * 0.22, h * 0.68)
      ..close();

    canvas.drawPath(foldPath, foldPaint);
  }

  @override
  bool shouldRepaint(covariant _LogoPainter oldDelegate) =>
      oldDelegate.pulse != pulse;
}
