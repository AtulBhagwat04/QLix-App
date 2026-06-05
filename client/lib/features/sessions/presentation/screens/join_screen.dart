import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/storage/cache_manager.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/constants/app_sizes.dart';
import '../blocs/session_bloc.dart';

class ParticipantJoinScreen extends StatefulWidget {
  const ParticipantJoinScreen({super.key});

  @override
  State<ParticipantJoinScreen> createState() => _ParticipantJoinScreenState();
}

class _ParticipantJoinScreenState extends State<ParticipantJoinScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  final _codeFocusNode = FocusNode();
  bool _hasCodeError = false;

  @override
  void initState() {
    super.initState();
    // Do not pre-fill name; prompt the user to enter it explicitly.
  }

  @overriderem
  void dispose() {
    _codeController.dispose();
    _codeFocusNode.dispose();
    super.dispose();
  }

  void _openQRScanner() {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss QR Scanner',
      barrierColor: Colors.black.withValues(alpha: 0.5),
      transitionDuration: const Duration(milliseconds: 350),
      pageBuilder: (context, anim1, anim2) {
        return _QrScannerDialog(
          onCodeScanned: (code) {
            _codeController.text = code;
            _joinSession();
          },
        );
      },
      transitionBuilder: (context, anim1, anim2, child) {
        // Smooth scale-up and fade-in transition
        final curve = CurvedAnimation(
          parent: anim1,
          curve: Curves.easeOutCubic,
        );
        return ScaleTransition(
          scale: Tween<double>(begin: 0.92, end: 1.0).animate(curve),
          child: FadeTransition(opacity: anim1, child: child),
        );
      },
    );
  }

  void _joinSession() {
    setState(() {
      _hasCodeError = _codeController.text.trim().length != 6;
    });

    if (_hasCodeError) return;

    // Unfocus and dismiss keyboard automatically
    _codeFocusNode.unfocus();

    final code = _codeController.text.trim();
    context.read<SessionBloc>().add(
      VerifySessionCodeRequested(accessCode: code),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),
      body: Stack(
        children: [
          // 1. Decorative Soft Circular Glows
          Positioned(
            top: size.height * 0.1,
            left: size.width * 0.05,
            right: size.width * 0.05,
            height: size.height * 0.45,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.primary.withValues(alpha: 0.08),
                    AppColors.primary.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -50,
            right: -50,
            width: size.width * 0.7,
            height: size.width * 0.7,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.secondary.withValues(alpha: 0.06),
                    AppColors.secondary.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),

          // 2. Subtle background dots detailing
          Positioned.fill(
            child: CustomPaint(painter: _BackgroundDotsPainter(seed: 77)),
          ),

          // 4. Content Scroll Area
          BlocListener<SessionBloc, SessionState>(
            listener: (context, state) {
              if (state is SessionJoinSuccess) {
                final code = state.session['access_code'] as String;

                sl<CacheManager>().saveSessionParticipant(
                  sessionCode: code,
                  participantId: state.participant['id'] as String,
                  name: state.participant['name'] as String,
                );

                context.go('/session/$code');
              } else if (state is SessionVerifySuccess) {
                final code = state.session['access_code'] as String;
                _showNamePromptBottomSheet(code);
              } else if (state is SessionFailure) {
                String friendlyMessage =
                    'Unable to join. Please verify the code and try again.';
                final msg = state.message.toLowerCase();

                if (msg.contains('not found') ||
                    msg.contains('404') ||
                    msg.contains('invalid')) {
                  friendlyMessage = 'Invalid session code';
                } else if (msg.contains('ended') || msg.contains('expired')) {
                  friendlyMessage =
                      'This session has already ended. Ask your host for a new code.';
                } else if (msg.contains('connection') ||
                    msg.contains('network') ||
                    msg.contains('timeout')) {
                  friendlyMessage =
                      'Connection issue. Please check your internet connection and try again.';
                }

                Future.delayed(const Duration(seconds: 1), () {
                  if (mounted) {
                    _codeController.clear();
                  }
                });

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Row(
                      children: [
                        const Icon(
                          Icons.error_outline_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            friendlyMessage,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                    backgroundColor: AppColors.error,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppSizes.radiusInput),
                    ),
                  ),
                );
              }
            },
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSizes.space20,
                  vertical: 16,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 20),

                    // Top Card Illustration
                    _buildTopIllustration()
                        .animate()
                        .fadeIn(duration: 500.ms)
                        .scale(
                          begin: const Offset(0.8, 0.8),
                          curve: Curves.easeOutBack,
                        ),
                    const SizedBox(height: 18),

                    // Title
                    const Text(
                          'Join a Session',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimaryLight,
                            letterSpacing: -0.5,
                          ),
                        )
                        .animate()
                        .fadeIn(duration: 400.ms)
                        .slideY(begin: 0.1, end: 0),
                    const SizedBox(height: 6),

                    // Subtitle description
                    const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            'Enter the session code provided by your host to join the live session.',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.normal,
                              color: AppColors.textSecondaryLight,
                              height: 1.4,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        )
                        .animate()
                        .fadeIn(delay: 100.ms, duration: 400.ms)
                        .slideY(begin: 0.1, end: 0),
                    const SizedBox(height: 20),

                    // Card Form Panel
                    Card(
                      elevation: 0,
                      color: Colors.white,
                      shape: RoundedRectangleBorder(
                        side: const BorderSide(
                          color: Color(0xFFF1F5F9),
                          width: 1.5,
                        ),
                        borderRadius: BorderRadius.circular(
                          AppSizes.radiusCard,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20.0,
                          vertical: 20.0,
                        ),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Session Code label
                              const Text(
                                    'Session Code',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF64748B),
                                      letterSpacing: 0.2,
                                    ),
                                  )
                                  .animate()
                                  .fadeIn(delay: 100.ms, duration: 300.ms)
                                  .slideX(begin: -0.05, end: 0),
                              const SizedBox(height: 6),

                              // Premium Custom PIN Input Field
                              _PinCodeField(
                                    controller: _codeController,
                                    focusNode: _codeFocusNode,
                                    hasError: _hasCodeError,
                                    onChanged: () {
                                      setState(() {
                                        _hasCodeError = false;
                                      });
                                      if (_codeController.text.length == 6) {
                                        _joinSession();
                                      }
                                    },
                                  )
                                  .animate()
                                  .fadeIn(delay: 150.ms, duration: 400.ms)
                                  .scale(
                                    begin: const Offset(0.96, 0.96),
                                    curve: Curves.easeOutCubic,
                                  ),

                              if (_hasCodeError)
                                Padding(
                                  padding: const EdgeInsets.only(
                                    top: 10.0,
                                    left: 4.0,
                                  ),
                                  child:
                                      const Text(
                                            AppStrings.codeError,
                                            style: TextStyle(
                                              color: AppColors.error,
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          )
                                          .animate()
                                          .fadeIn(duration: 150.ms)
                                          .slideY(begin: -0.2, end: 0),
                                ),
                              const SizedBox(height: 18),

                              // Main Join Session button
                              BlocBuilder<SessionBloc, SessionState>(
                                    builder: (context, state) {
                                      if (state is SessionLoading) {
                                        return const Center(
                                          child: CircularProgressIndicator(
                                            color: AppColors.primary,
                                          ),
                                        );
                                      }

                                      return _AnimatedScaleButton(
                                        onPressed: _joinSession,
                                        child: Container(
                                          height: 48,
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            gradient: const LinearGradient(
                                              colors: AppColors.primaryGradient,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: AppColors.primary
                                                    .withValues(alpha: 0.25),
                                                blurRadius: 12,
                                                offset: const Offset(0, 4),
                                              ),
                                            ],
                                          ),
                                          alignment: Alignment.center,
                                          child: const Text(
                                            'Join Session',
                                            style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  )
                                  .animate()
                                  .fadeIn(delay: 200.ms, duration: 400.ms)
                                  .slideY(begin: 0.1, end: 0),
                              const SizedBox(height: 12),

                              // OR Divider
                              Row(
                                children: const [
                                  Expanded(
                                    child: Divider(
                                      color: Color(0xFFE2E8F0),
                                      thickness: 1.5,
                                    ),
                                  ),
                                  Padding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 16,
                                    ),
                                    child: Text(
                                      'OR',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF94A3B8),
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Divider(
                                      color: Color(0xFFE2E8F0),
                                      thickness: 1.5,
                                    ),
                                  ),
                                ],
                              ).animate().fadeIn(
                                delay: 250.ms,
                                duration: 400.ms,
                              ),
                              const SizedBox(height: 12),

                              // Scan QR Code Option inside Card
                              _AnimatedScaleButton(
                                    onPressed: _openQRScanner,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 10,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFEEF2FF),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: AppColors.primary.withValues(
                                            alpha: 0.15,
                                          ),
                                          width: 1.5,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          const Icon(
                                                Icons.qr_code_scanner_rounded,
                                                color: AppColors.primary,
                                                size: 20,
                                              )
                                              .animate(
                                                onPlay: (c) =>
                                                    c.repeat(reverse: true),
                                              )
                                              .scale(
                                                begin: const Offset(0.9, 0.9),
                                                end: const Offset(1.1, 1.1),
                                                duration: 1200.ms,
                                                curve: Curves.easeInOut,
                                              ),
                                          const SizedBox(width: 10),
                                          const Text(
                                            'Scan QR Code',
                                            style: TextStyle(
                                              fontSize: 13.5,
                                              fontWeight: FontWeight.w700,
                                              color: AppColors.primary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  )
                                  .animate()
                                  .fadeIn(delay: 300.ms, duration: 400.ms)
                                  .slideY(begin: 0.1, end: 0),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Bottom Host Link Option
                    Column(
                      children: [
                        const Text(
                          'Are you a Host?',
                          style: TextStyle(
                            fontSize: 13,
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 6),
                        InkWell(
                          onTap: () => context.go('/login'),
                          child: const Text(
                            'Login As Host',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ).animate().fadeIn(delay: 350.ms, duration: 400.ms),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopIllustration() {
    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        // Decorative background glowing gradients
        Positioned(
          left: -40,
          top: -10,
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary.withValues(alpha: 0.15),
            ),
          ).animate().scale(duration: 1.seconds, curve: Curves.easeOut),
        ),

        // Main glassmorphic illustration Card
        Transform.rotate(
          angle: -0.04,
          child: Container(
            width: 150,
            height: 96,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.6),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.06),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Overlapping high-fidelity avatars
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Avatar 1
                        Container(
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 1.5),
                            gradient: const LinearGradient(
                              colors: [Color(0xFFF43F5E), Color(0xFFEC4899)],
                            ),
                          ),
                          child: const Icon(
                            Icons.person,
                            size: 14,
                            color: Colors.white,
                          ),
                        ),
                        Transform.translate(
                          offset: const Offset(-6, 0),
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                              gradient: const LinearGradient(
                                colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                              ),
                            ),
                            child: const Icon(
                              Icons.person,
                              size: 18,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        Transform.translate(
                          offset: const Offset(-12, 0),
                          child: Container(
                            width: 26,
                            height: 26,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white,
                                width: 1.5,
                              ),
                              gradient: const LinearGradient(
                                colors: [Color(0xFF06B6D4), Color(0xFF3B82F6)],
                              ),
                            ),
                            child: const Icon(
                              Icons.person,
                              size: 14,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: 80,
                      height: 8,
                      decoration: BoxDecoration(
                        color: const Color(0xFF64748B).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        // Floating link badge
        Positioned(
          right: -10,
          bottom: 2,
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: AppColors.primaryGradient),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2.5),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.25),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(
              Icons.link_rounded,
              color: Colors.white,
              size: 18,
            ),
          ),
        ),

        // Floating interactive bubbles
        // 1. Chat Bubble (Top Left)
        Positioned(
          left: -40,
          top: 15,
          child:
              Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 6,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.chat_bubble_rounded,
                      color: AppColors.secondary,
                      size: 14,
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

        // 2. Question Mark Bubble (Top Right)
        Positioned(
          right: -36,
          top: -10,
          child:
              Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 6,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.question_mark_rounded,
                      color: AppColors.accent,
                      size: 14,
                    ),
                  )
                  .animate(onPlay: (c) => c.repeat(reverse: true))
                  .slideY(
                    begin: 0,
                    end: 0.15,
                    duration: 2200.ms,
                    curve: Curves.easeInOut,
                  ),
        ),

        // 3. Success Checkmark Bubble (Bottom Left)
        Positioned(
          left: -32,
          bottom: 0,
          child:
              Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 6,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.check_circle_rounded,
                      color: AppColors.success,
                      size: 14,
                    ),
                  )
                  .animate(onPlay: (c) => c.repeat(reverse: true))
                  .slideY(
                    begin: 0,
                    end: -0.12,
                    duration: 2000.ms,
                    curve: Curves.easeInOut,
                  ),
        ),
      ],
    );
  }

  void _showNamePromptBottomSheet(String code) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _NamePromptSheet(
          code: code,
          onJoin: (name, isAnonymous) {
            final deviceId = sl<CacheManager>().getDeviceId() ?? '';
            if (!isAnonymous) {
              sl<CacheManager>().saveLastParticipantName(name);
            }
            context.read<SessionBloc>().add(
              JoinSessionRequested(
                accessCode: code,
                deviceId: deviceId,
                name: name,
                isAnonymous: isAnonymous,
              ),
            );
          },
        );
      },
    );
  }
}

// Subtle light mode decorative background painter
class _BackgroundDotsPainter extends CustomPainter {
  final int seed;

  _BackgroundDotsPainter({required this.seed});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    final rand = math.Random(seed);

    for (int i = 0; i < 20; i++) {
      final x = rand.nextDouble() * size.width;
      final y = rand.nextDouble() * size.height;
      final radius = rand.nextDouble() * 2.0 + 0.5;
      final opacity = rand.nextDouble() * 0.08 + 0.02;

      paint.color = AppColors.primary.withValues(alpha: opacity);
      canvas.drawCircle(Offset(x, y), radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _QrScannerDialog extends StatefulWidget {
  final ValueChanged<String> onCodeScanned;

  const _QrScannerDialog({required this.onCodeScanned});

  @override
  State<_QrScannerDialog> createState() => _QrScannerDialogState();
}

class _QrScannerDialogState extends State<_QrScannerDialog> {
  final MobileScannerController _controller = MobileScannerController(
    facing: CameraFacing.back,
    torchEnabled: false,
  );
  bool _isScanned = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // 1. Full-screen MobileScanner
          Positioned.fill(
            child: MobileScanner(
              controller: _controller,
              onDetect: (capture) {
                if (_isScanned) return;
                final List<Barcode> barcodes = capture.barcodes;
                for (final barcode in barcodes) {
                  final rawValue = barcode.rawValue;
                  if (rawValue != null) {
                    // Check raw 6-digit code
                    if (rawValue.length == 6 &&
                        int.tryParse(rawValue) != null) {
                      _isScanned = true;
                      widget.onCodeScanned(rawValue);
                      Navigator.pop(context);
                      break;
                    }
                    // Check URL like http://localhost:3000/session/123456
                    final uri = Uri.tryParse(rawValue);
                    if (uri != null && uri.pathSegments.isNotEmpty) {
                      final lastSegment = uri.pathSegments.last;
                      if (lastSegment.length == 6 &&
                          int.tryParse(lastSegment) != null) {
                        _isScanned = true;
                        widget.onCodeScanned(lastSegment);
                        Navigator.pop(context);
                        break;
                      }
                    }
                  }
                }
              },
            ),
          ),
          // 2. High fidelity HUD scanner overlay (covers full screen)
          Positioned.fill(child: _ScannerOverlay(controller: _controller)),
          // 3. Floating glassmorphic top header bar
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 20,
            right: 20,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.15),
                      width: 1.0,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const SizedBox(
                        width: 36,
                      ), // Spacer to balance close button
                      const Text(
                        'Scan QR Code',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                      _AnimatedScaleButton(
                        onPressed: () => Navigator.pop(context),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Custom Painter that masks the camera view and leaves a rounded rectangle cutout
class _ScannerCutoutPainter extends CustomPainter {
  final double cutoutSize;
  final double pulse;

  _ScannerCutoutPainter({required this.cutoutSize, required this.pulse});

  @override
  void paint(Canvas canvas, Size size) {
    final left = (size.width - cutoutSize) / 2;
    final top = (size.height - cutoutSize) / 2;
    final right = left + cutoutSize;
    final bottom = top + cutoutSize;

    // 1. Draw the semi-transparent black mask overlay
    final outerRect = Rect.fromLTWH(0, 0, size.width, size.height);
    final outerPath = Path()..addRect(outerRect);

    final r = AppSizes.radiusCard;
    final cutoutRect = Rect.fromLTWH(left, top, cutoutSize, cutoutSize);
    final cutoutPath = Path()
      ..addRRect(RRect.fromRectAndRadius(cutoutRect, Radius.circular(r)));

    // Subtract the cutout path from outer path
    final maskPath = Path.combine(
      PathOperation.difference,
      outerPath,
      cutoutPath,
    );
    final maskPaint = Paint()..color = Colors.black.withValues(alpha: 0.65);
    canvas.drawPath(maskPath, maskPaint);

    // 2. Draw pulsing neon outer border
    final borderPaint = Paint()
      ..color = AppColors.primary.withValues(alpha: 0.15 + (pulse * 0.15))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawRRect(
      RRect.fromRectAndRadius(cutoutRect, Radius.circular(r)),
      borderPaint,
    );

    // 3. Draw heavy glowing corner brackets
    final double cornerLen = 22.0;
    final double thickness = 3.5;
    final cornerColor = AppColors.secondary.withValues(
      alpha: 0.6 + (pulse * 0.4),
    );

    final cornerPaint = Paint()
      ..color = cornerColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = thickness
      ..strokeCap = StrokeCap.round;

    final glowPaint = Paint()
      ..color = cornerColor.withValues(alpha: 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = thickness + 3.0
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.0);

    // Corner Paths definitions:
    // Top-Left Corner
    final tlPath = Path()
      ..moveTo(left + r + cornerLen, top)
      ..lineTo(left + r, top)
      ..arcToPoint(
        Offset(left, top + r),
        radius: Radius.circular(r),
        clockwise: false,
      )
      ..lineTo(left, top + r + cornerLen);

    // Top-Right Corner
    final trPath = Path()
      ..moveTo(right - r - cornerLen, top)
      ..lineTo(right - r, top)
      ..arcToPoint(
        Offset(right, top + r),
        radius: Radius.circular(r),
        clockwise: true,
      )
      ..lineTo(right, top + r + cornerLen);

    // Bottom-Left Corner
    final blPath = Path()
      ..moveTo(left + r + cornerLen, bottom)
      ..lineTo(left + r, bottom)
      ..arcToPoint(
        Offset(left, bottom - r),
        radius: Radius.circular(r),
        clockwise: true,
      )
      ..lineTo(left, bottom - r - cornerLen);

    // Bottom-Right Corner
    final brPath = Path()
      ..moveTo(right - r - cornerLen, bottom)
      ..lineTo(right - r, bottom)
      ..arcToPoint(
        Offset(right, bottom - r),
        radius: Radius.circular(r),
        clockwise: false,
      )
      ..lineTo(right, bottom - r - cornerLen);

    // Draw Glows first, then sharp corners
    canvas.drawPath(tlPath, glowPaint);
    canvas.drawPath(trPath, glowPaint);
    canvas.drawPath(blPath, glowPaint);
    canvas.drawPath(brPath, glowPaint);

    canvas.drawPath(tlPath, cornerPaint);
    canvas.drawPath(trPath, cornerPaint);
    canvas.drawPath(blPath, cornerPaint);
    canvas.drawPath(brPath, cornerPaint);
  }

  @override
  bool shouldRepaint(covariant _ScannerCutoutPainter oldDelegate) {
    return oldDelegate.pulse != pulse || oldDelegate.cutoutSize != cutoutSize;
  }
}

// Interactive scanning laser overlay with animation
class _ScannerOverlay extends StatefulWidget {
  final MobileScannerController controller;

  const _ScannerOverlay({required this.controller});

  @override
  State<_ScannerOverlay> createState() => _ScannerOverlayState();
}

class _ScannerOverlayState extends State<_ScannerOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _laserAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _laserAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;

        // Centered cutout dimensions
        final cutoutSize = math.min(width, height) * 0.65;
        final left = (width - cutoutSize) / 2;
        final top = (height - cutoutSize) / 2;

        return Stack(
          children: [
            // Dark vignette overlay with cutout window
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  final pulse =
                      (math.sin(_controller.value * math.pi * 2) + 1) / 2;
                  return CustomPaint(
                    painter: _ScannerCutoutPainter(
                      cutoutSize: cutoutSize,
                      pulse: pulse,
                    ),
                  );
                },
              ),
            ),

            // Pulsing Green "Ready to Scan" Pill Status at the top
            Positioned(
              top: top - 50,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.65),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.15),
                      width: 1.0,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: AppColors.success,
                              shape: BoxShape.circle,
                            ),
                          )
                          .animate(onPlay: (c) => c.repeat(reverse: true))
                          .scale(
                            begin: const Offset(0.8, 0.8),
                            end: const Offset(1.3, 1.3),
                            duration: 800.ms,
                          )
                          .fadeIn(duration: 800.ms),
                      const SizedBox(width: 8),
                      const Text(
                        'Ready to Scan',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Animated laser sweep line
            AnimatedBuilder(
              animation: _laserAnimation,
              builder: (context, child) {
                final double r = AppSizes.radiusCard;
                final double startY = top + r;
                final double endY = top + cutoutSize - r;
                final currentY =
                    startY + (_laserAnimation.value * (endY - startY));

                return Positioned(
                  top: currentY,
                  left: left + 12,
                  right: left + 12,
                  child: Container(
                    height: 3.5,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.secondary.withValues(alpha: 0.0),
                          AppColors.secondary,
                          AppColors.secondary.withValues(alpha: 0.0),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.secondary.withValues(alpha: 0.8),
                          blurRadius: 10,
                          spreadRadius: 2.5,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),

            // Glassmorphic Floating controls at the bottom of the cutout frame
            Positioned(
              top: top + cutoutSize + 24,
              left: 0,
              right: 0,
              child: ValueListenableBuilder<MobileScannerState>(
                valueListenable: widget.controller,
                builder: (context, state, child) {
                  final isTorchOn = state.torchState == TorchState.on;
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Flash/Torch Toggle
                      _AnimatedScaleButton(
                        onPressed: () => widget.controller.toggleTorch(),
                        child: Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isTorchOn
                                ? Colors.amber.withValues(alpha: 0.25)
                                : Colors.black.withValues(alpha: 0.5),
                            border: Border.all(
                              color: isTorchOn
                                  ? Colors.amber.withValues(alpha: 0.5)
                                  : Colors.white.withValues(alpha: 0.2),
                              width: 1.5,
                            ),
                            boxShadow: isTorchOn
                                ? [
                                    BoxShadow(
                                      color: Colors.amber.withValues(
                                        alpha: 0.3,
                                      ),
                                      blurRadius: 10,
                                      spreadRadius: 2,
                                    ),
                                  ]
                                : null,
                          ),
                          child: Icon(
                            isTorchOn
                                ? Icons.flash_on_rounded
                                : Icons.flash_off_rounded,
                            color: isTorchOn ? Colors.amber : Colors.white70,
                            size: 22,
                          ),
                        ),
                      ),
                      const SizedBox(width: 24),
                      // Camera Flip
                      _AnimatedScaleButton(
                        onPressed: () => widget.controller.switchCamera(),
                        child: Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.black.withValues(alpha: 0.5),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.2),
                              width: 1.5,
                            ),
                          ),
                          child: const Icon(
                            Icons.flip_camera_ios_rounded,
                            color: Colors.white70,
                            size: 22,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),

            // Instruction Text below the cutout
            Positioned(
              bottom: 24,
              left: 24,
              right: 24,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                    width: 1.0,
                  ),
                ),
                child: const Text(
                  'Position the QR code inside the frame to join the session automatically.',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _NamePromptSheet extends StatefulWidget {
  final String code;
  final void Function(String name, bool isAnonymous) onJoin;

  const _NamePromptSheet({required this.code, required this.onJoin});

  @override
  State<_NamePromptSheet> createState() => _NamePromptSheetState();
}

class _NamePromptSheetState extends State<_NamePromptSheet> {
  final _nameController = TextEditingController();
  final _focusNode = FocusNode();
  bool _isEmpty = true;

  @override
  void initState() {
    super.initState();
    final cachedName = sl<CacheManager>().getParticipantName();
    if (cachedName.isNotEmpty) {
      _nameController.text = cachedName;
      _isEmpty = false;
    }
    _nameController.addListener(_onNameChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  void _onNameChanged() {
    setState(() {
      _isEmpty = _nameController.text.trim().isEmpty;
    });
  }

  @override
  void dispose() {
    _nameController.removeListener(_onNameChanged);
    _nameController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      widget.onJoin('Anonymous', true);
    } else {
      widget.onJoin(name, false);
    }
    Navigator.pop(context);
  }

  Widget _buildAvatarPreview(String name) {
    final isAnonymous = name.trim().isEmpty;
    final String initials = isAnonymous
        ? ''
        : name
              .trim()
              .split(' ')
              .map((e) => e.isNotEmpty ? e[0].toUpperCase() : '')
              .take(2)
              .join();

    // Premium gradients
    final List<List<Color>> gradients = [
      [const Color(0xFF6366F1), const Color(0xFF8B5CF6)], // Indigo to Purple
      [const Color(0xFF06B6D4), const Color(0xFF3B82F6)], // Teal to Blue
      [const Color(0xFFF43F5E), const Color(0xFFEC4899)], // Rose to Pink
      [const Color(0xFF10B981), const Color(0xFF059669)], // Emerald to Green
      [const Color(0xFFF59E0B), const Color(0xFFD97706)], // Amber to Orange
    ];

    final gradientIndex = isAnonymous
        ? 0
        : (name.trim().hashCode.abs() % gradients.length);
    final selectedGradient = isAnonymous
        ? [const Color(0xFF94A3B8), const Color(0xFF64748B)]
        : gradients[gradientIndex];

    return Center(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: selectedGradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: selectedGradient[0].withValues(alpha: 0.25),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          transitionBuilder: (child, animation) {
            return ScaleTransition(scale: animation, child: child);
          },
          child: isAnonymous
              ? const Icon(
                  Icons.visibility_off_rounded,
                  color: Colors.white,
                  size: 32,
                  key: ValueKey('anonymous_avatar'),
                )
              : Text(
                  initials,
                  key: ValueKey('name_avatar_$initials'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : Colors.white,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppSizes.radiusCard * 1.5),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 30,
              offset: const Offset(0, -10),
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: AppSizes.barHeight,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white30 : Colors.black12,
                  borderRadius: BorderRadius.circular(AppSizes.radiusSmall),
                ),
              ),
            ),
            const SizedBox(height: 18),
            _buildAvatarPreview(_nameController.text),
            const SizedBox(height: 18),
            Text(
              'What is your name?',
              style: TextStyle(
                color: isDark ? Colors.white : AppColors.textPrimaryLight,
                fontSize: 18,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              'This name will be visible to the host and other participants.',
              style: TextStyle(
                color: isDark ? Colors.white70 : AppColors.textSecondaryLight,
                fontSize: 13,
                fontWeight: FontWeight.normal,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _nameController,
              focusNode: _focusNode,
              textCapitalization: TextCapitalization.words,
              maxLength: 25,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimaryLight,
              ),
              decoration: InputDecoration(
                counterText: '',
                hintText: 'Enter your display name',
                hintStyle: const TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 14,
                  fontWeight: FontWeight.normal,
                ),
                prefixIcon: const Icon(
                  Icons.person_outline_rounded,
                  color: AppColors.primary,
                  size: 20,
                ),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                enabledBorder: OutlineInputBorder(
                  borderSide: const BorderSide(
                    color: Color(0xFFE2E8F0),
                    width: 1.5,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: const BorderSide(
                    color: AppColors.primary,
                    width: 2.0,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onFieldSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 20),
            _AnimatedScaleButton(
              onPressed: _submit,
              child: Container(
                height: 50,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: LinearGradient(
                    colors: _isEmpty
                        ? [const Color(0xFF94A3B8), const Color(0xFF64748B)]
                        : AppColors.primaryGradient,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color:
                          (_isEmpty
                                  ? const Color(0xFF64748B)
                                  : AppColors.primary)
                              .withValues(alpha: 0.25),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 150),
                  child: Text(
                    _isEmpty ? 'Join Anonymously' : 'Join Session',
                    key: ValueKey<bool>(_isEmpty),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

// Custom 6-digit PIN code widget
class _PinCodeField extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool hasError;
  final VoidCallback onChanged;

  const _PinCodeField({
    required this.controller,
    required this.focusNode,
    required this.hasError,
    required this.onChanged,
  });

  @override
  State<_PinCodeField> createState() => _PinCodeFieldState();
}

class _PinCodeFieldState extends State<_PinCodeField> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_updateState);
    widget.focusNode.addListener(_updateState);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_updateState);
    widget.focusNode.removeListener(_updateState);
    super.dispose();
  }

  void _updateState() {
    if (mounted) {
      final text = widget.controller.text;
      if (widget.controller.selection.baseOffset != text.length ||
          widget.controller.selection.extentOffset != text.length) {
        widget.controller.selection = TextSelection.collapsed(
          offset: text.length,
        );
      }
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = widget.controller.text;
    final isFocused = widget.focusNode.hasFocus;

    return Stack(
      children: [
        // Hidden input field to capture keyboards and events
        Opacity(
          opacity: 0.0,
          child: SizedBox(
            height: 56,
            child: TextFormField(
              controller: widget.controller,
              focusNode: widget.focusNode,
              keyboardType: TextInputType.number,
              maxLength: 6,
              enableInteractiveSelection: true,
              showCursor: false,
              decoration: const InputDecoration(
                counterText: '',
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
              ),
              onChanged: (val) {
                widget.onChanged();
              },
            ),
          ),
        ),
        // Layout of visual PIN boxes
        GestureDetector(
          onTap: () {
            if (!widget.focusNode.hasFocus) {
              widget.focusNode.requestFocus();
            } else {
              widget.focusNode.unfocus();
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  widget.focusNode.requestFocus();
                }
              });
            }
          },
          behavior: HitTestBehavior.opaque,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(6, (index) {
              final digit = text.length > index ? text[index] : '';
              final isCurrent = index == text.length;
              final showCursor = isFocused && isCurrent;

              Color borderColor;
              double borderWidth;
              List<BoxShadow>? boxShadow;

              if (widget.hasError) {
                borderColor = AppColors.error;
                borderWidth = 2.0;
              } else if (showCursor) {
                borderColor = AppColors.primary;
                borderWidth = 2.2;
                boxShadow = [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ];
              } else if (digit.isNotEmpty) {
                borderColor = AppColors.primary.withValues(alpha: 0.4);
                borderWidth = 1.5;
              } else {
                borderColor = const Color(0xFFE2E8F0);
                borderWidth = 1.5;
              }

              return Expanded(
                child: Container(
                  height: 54,
                  margin: EdgeInsets.symmetric(
                    horizontal: index == 0 || index == 5 ? 0 : 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: borderColor, width: borderWidth),
                    boxShadow: boxShadow,
                  ),
                  alignment: Alignment.center,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      if (digit.isNotEmpty)
                        Text(
                          digit,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimaryLight,
                          ),
                        ).animate().scale(
                          begin: const Offset(0.7, 0.7),
                          duration: 150.ms,
                          curve: Curves.easeOutBack,
                        )
                      else if (showCursor)
                        const _BlinkingCursor()
                      else
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFF94A3B8,
                            ).withValues(alpha: 0.4),
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }
}

// Simple pulsing vertical line cursor
class _BlinkingCursor extends StatefulWidget {
  const _BlinkingCursor();

  @override
  State<_BlinkingCursor> createState() => _BlinkingCursorState();
}

class _BlinkingCursorState extends State<_BlinkingCursor>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _controller,
      child: Container(width: 2.2, height: 20, color: AppColors.primary),
    );
  }
}

// Press scaling helper button
class _AnimatedScaleButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onPressed;

  const _AnimatedScaleButton({required this.child, this.onPressed});

  @override
  State<_AnimatedScaleButton> createState() => _AnimatedScaleButtonState();
}

class _AnimatedScaleButtonState extends State<_AnimatedScaleButton> {
  double _scale = 1.0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _scale = 0.96),
      onTapUp: (_) => setState(() => _scale = 1.0),
      onTapCancel: () => setState(() => _scale = 1.0),
      onTap: widget.onPressed,
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 100),
        child: widget.child,
      ),
    );
  }
}
