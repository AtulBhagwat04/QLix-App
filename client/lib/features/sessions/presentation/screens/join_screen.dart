import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/storage/cache_manager.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/network/network_settings_dialog.dart';
import '../blocs/session_bloc.dart';

class ParticipantJoinScreen extends StatefulWidget {
  const ParticipantJoinScreen({super.key});

  @override
  State<ParticipantJoinScreen> createState() => _ParticipantJoinScreenState();
}

class _ParticipantJoinScreenState extends State<ParticipantJoinScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  final _nameController = TextEditingController();
  bool _isAnonymous = true;

  @override
  void initState() {
    super.initState();
    _nameController.text = sl<CacheManager>().getParticipantName();
  }

  @override
  void dispose() {
    _codeController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _openQRScanner() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;
        return Container(
          height: MediaQuery.of(context).size.height * 0.75,
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(AppSizes.radiusCard * 1.5)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 30,
                offset: const Offset(0, -10),
              )
            ],
          ),
          child: Column(
            children: [
              const SizedBox(height: AppSizes.space12),
              Container(
                width: 40,
                height: AppSizes.barHeight,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white30 : Colors.black12,
                  borderRadius: BorderRadius.circular(AppSizes.radiusSmall),
                ),
              ),
              const SizedBox(height: AppSizes.space20),
              Text(
                AppStrings.scanQrTitle,
                style: TextStyle(
                  color: isDark ? Colors.white : AppColors.textPrimaryLight,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: AppSizes.space20),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSizes.space24),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppSizes.radiusCard),
                    child: Stack(
                      children: [
                        MobileScanner(
                          onDetect: (capture) {
                            final List<Barcode> barcodes = capture.barcodes;
                            for (final barcode in barcodes) {
                              final rawValue = barcode.rawValue;
                              if (rawValue != null) {
                                // Check raw 6-digit code
                                if (rawValue.length == 6 && int.tryParse(rawValue) != null) {
                                  _codeController.text = rawValue;
                                  Navigator.pop(context);
                                  _joinSession();
                                  break;
                                }
                                // Check URL like http://localhost:3000/session/123456
                                final uri = Uri.tryParse(rawValue);
                                if (uri != null && uri.pathSegments.isNotEmpty) {
                                  final lastSegment = uri.pathSegments.last;
                                  if (lastSegment.length == 6 && int.tryParse(lastSegment) != null) {
                                    _codeController.text = lastSegment;
                                    Navigator.pop(context);
                                    _joinSession();
                                    break;
                                  }
                                }
                              }
                            }
                          },
                        ),
                        // Premium scanning laser overlay animation
                        const Positioned.fill(
                          child: _ScannerOverlay(),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSizes.space32),
            ],
          ),
        );
      },
    );
  }

  void _joinSession() {
    if (_formKey.currentState!.validate()) {
      final code = _codeController.text.trim();
      final deviceId = sl<CacheManager>().getDeviceId() ?? '';
      
      if (!_isAnonymous && _nameController.text.isNotEmpty) {
        sl<CacheManager>().saveLastParticipantName(_nameController.text);
      }

      context.read<SessionBloc>().add(
        JoinSessionRequested(
          accessCode: code,
          deviceId: deviceId,
          name: _isAnonymous ? 'Anonymous' : _nameController.text.trim(),
          isAnonymous: _isAnonymous,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: AppColors.bgGradient,
          ),
        ),
        child: Stack(
          children: [
            // Decorative background blur elements
            Positioned(
              top: -120,
              left: -80,
              child: Container(
                width: 320,
                height: 320,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary.withOpacity(isDark ? 0.15 : 0.08),
                ),
              ),
            ),
            Positioned(
              bottom: -150,
              right: -100,
              child: Container(
                width: 420,
                height: 420,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.secondary.withOpacity(isDark ? 0.12 : 0.06),
                ),
              ),
            ),
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 90.0, sigmaY: 90.0),
                child: Container(color: Colors.transparent),
              ),
            ),

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
                } else if (state is SessionFailure) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(state.message),
                      backgroundColor: AppColors.error,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSizes.radiusInput)),
                    ),
                  );
                }
              },
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: AppSizes.space24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.12),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.primary.withOpacity(0.25), 
                            width: 1.5,
                          ),
                        ),
                        child: const Icon(
                          Icons.forum_rounded,
                          size: 56,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        AppStrings.liveSession,
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          color: isDark ? Colors.white : AppColors.textPrimaryLight,
                          letterSpacing: -1.0,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        AppStrings.joinSubTitle,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 36),

                      AppDecoration.glassWrapper(
                        context: context,
                        opacity: isDark ? 0.03 : 0.05,
                        borderRadius: AppSizes.radiusCard,
                        child: Padding(
                          padding: const EdgeInsets.all(AppSizes.space24 + 4),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                TextFormField(
                                  controller: _codeController,
                                  style: AppTextStyles.inputTextStyle.copyWith(
                                    color: isDark ? Colors.white : AppColors.textPrimaryLight,
                                  ),
                                  textAlign: TextAlign.center,
                                  keyboardType: TextInputType.number,
                                  maxLength: 6,
                                  decoration: InputDecoration(
                                    counterText: '',
                                    labelText: AppStrings.accessCodeLabel,
                                    suffixIcon: IconButton(
                                      icon: const Icon(
                                        Icons.qr_code_scanner_rounded,
                                        color: AppColors.primary,
                                      ),
                                      onPressed: _openQRScanner,
                                    ),
                                  ),
                                  validator: (v) => v == null || v.trim().length != 6 ? AppStrings.codeError : null,
                                ),
                                const SizedBox(height: AppSizes.space20),

                                AnimatedSize(
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeInOut,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      if (!_isAnonymous) ...[
                                        TextFormField(
                                          controller: _nameController,
                                          style: TextStyle(color: isDark ? Colors.white : AppColors.textPrimaryLight),
                                          decoration: const InputDecoration(
                                            labelText: AppStrings.guestNameLabel,
                                            prefixIcon: Icon(Icons.person_outline),
                                          ),
                                        ),
                                        const SizedBox(height: AppSizes.space12),
                                      ],
                                    ],
                                  ),
                                ),

                                Row(
                                  children: [
                                    Checkbox(
                                      value: _isAnonymous,
                                      activeColor: AppColors.primary,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSizes.radiusSmall)),
                                      onChanged: (val) {
                                        setState(() {
                                          _isAnonymous = val ?? true;
                                        });
                                      },
                                    ),
                                    Text(
                                      'Join Anonymously',
                                      style: TextStyle(
                                        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: AppSizes.space24),

                                BlocBuilder<SessionBloc, SessionState>(
                                  builder: (context, state) {
                                    if (state is SessionLoading) {
                                      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
                                    }

                                    return Container(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(AppSizes.radiusButton),
                                        gradient: const LinearGradient(
                                          colors: AppColors.primaryGradient,
                                        ),
                                      ),
                                      child: ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.transparent,
                                          shadowColor: Colors.transparent,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(vertical: AppSizes.space16),
                                        ),
                                        onPressed: _joinSession,
                                        child: const Text(
                                          'Join Room',
                                          style: AppTextStyles.buttonText,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
 
                      const SizedBox(height: 36),
                      TextButton(
                        onPressed: () => context.go('/login'),
                        child: Text(
                          'Are you a Host? Sign In here',
                          style: TextStyle(
                            color: isDark ? Colors.white60 : AppColors.textSecondaryLight,
                            decoration: TextDecoration.underline,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              right: 16,
              child: IconButton(
                icon: const Icon(Icons.settings_outlined, color: Colors.white70),
                tooltip: 'Server Connection Settings',
                onPressed: () => showNetworkSettingsDialog(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Static scan laser overlay without animation ticker
class _ScannerOverlay extends StatelessWidget {
  const _ScannerOverlay();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Dark vignette overlay on the camera sides
        Positioned.fill(
          child: Container(
            color: Colors.black.withOpacity(0.4),
          ),
        ),
        // Cutout scanner frame
        Center(
          child: Container(
            width: 250,
            height: 250,
            decoration: BoxDecoration(
              color: Colors.transparent,
              border: Border.all(color: AppColors.secondary, width: 2.5),
              borderRadius: BorderRadius.circular(AppSizes.radiusCard),
              boxShadow: [
                BoxShadow(
                  color: AppColors.secondary.withOpacity(0.2),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

