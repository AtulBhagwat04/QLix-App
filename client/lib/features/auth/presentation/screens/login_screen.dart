import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/network/network_settings_dialog.dart';
import '../blocs/auth_bloc.dart';

class HostLoginScreen extends StatefulWidget {
  const HostLoginScreen({super.key});

  @override
  State<HostLoginScreen> createState() => _HostLoginScreenState();
}

class _HostLoginScreenState extends State<HostLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _rememberMe = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Scrollable Content Area
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSizes.space24,
                vertical: 20,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 24),

                  // Top illustration (organic blob logo from reference)
                  _buildTopIllustration(),
                  const SizedBox(height: 16),

                  // Title and Subtitle
                  const Text(
                        'Welcome Back!',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                          letterSpacing: -0.5,
                        ),
                      )
                      .animate()
                      .fadeIn(duration: 400.ms)
                      .slideY(begin: 0.1, end: 0),
                  const SizedBox(height: 6),

                  const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 24),
                        child: Text(
                          'Login to continue and join live sessions.',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF64748B),
                            height: 1.4,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      )
                      .animate()
                      .fadeIn(delay: 100.ms, duration: 400.ms)
                      .slideY(begin: 0.1, end: 0),
                  const SizedBox(height: 28),

                  // Tab switcher (Login / Sign Up)
                  _buildTabs(context, true)
                      .animate()
                      .fadeIn(delay: 120.ms, duration: 300.ms),
                  const SizedBox(height: 24),

                  // Login Form Card
                  Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Email field
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          style: const TextStyle(
                            color: AppColors.textPrimaryLight,
                            fontSize: 14.5,
                            fontWeight: FontWeight.w600,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Email address',
                            hintStyle: const TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 14.5,
                              fontWeight: FontWeight.normal,
                            ),
                            prefixIcon: const Icon(
                              Icons.mail_outline_rounded,
                              color: Color(0xFF6366F1),
                              size: 20,
                            ),
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 16,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderSide: const BorderSide(
                                color: Color(0xFFEEF2FF),
                                width: 1.5,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: const BorderSide(
                                color: Color(0xFF6366F1),
                                width: 2.0,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            errorBorder: OutlineInputBorder(
                              borderSide: const BorderSide(
                                color: AppColors.error,
                                width: 1.5,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            focusedErrorBorder: OutlineInputBorder(
                              borderSide: const BorderSide(
                                color: AppColors.error,
                                width: 2.0,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          validator: (v) => v == null || !v.contains('@')
                              ? 'Enter a valid email'
                              : null,
                        )
                        .animate()
                        .fadeIn(delay: 140.ms, duration: 300.ms),
                        const SizedBox(height: 16),

                        // Password field
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          style: const TextStyle(
                            color: AppColors.textPrimaryLight,
                            fontSize: 14.5,
                            fontWeight: FontWeight.w600,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Password',
                            hintStyle: const TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 14.5,
                              fontWeight: FontWeight.normal,
                            ),
                            prefixIcon: const Icon(
                              Icons.lock_outline_rounded,
                              color: Color(0xFF6366F1),
                              size: 20,
                            ),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                                color: const Color(0xFF94A3B8),
                                size: 20,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                            ),
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 16,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderSide: const BorderSide(
                                color: Color(0xFFEEF2FF),
                                width: 1.5,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: const BorderSide(
                                color: Color(0xFF6366F1),
                                width: 2.0,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            errorBorder: OutlineInputBorder(
                              borderSide: const BorderSide(
                                color: AppColors.error,
                                width: 1.5,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            focusedErrorBorder: OutlineInputBorder(
                              borderSide: const BorderSide(
                                color: AppColors.error,
                                width: 2.0,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          validator: (v) => v == null || v.length < 6
                              ? 'Password must be at least 6 characters'
                              : null,
                        )
                        .animate()
                        .fadeIn(delay: 160.ms, duration: 300.ms),
                        const SizedBox(height: 16),

                        // Remember me & Forgot password
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: Checkbox(
                                    value: _rememberMe,
                                    onChanged: (val) {
                                      setState(() {
                                        _rememberMe = val ?? false;
                                      });
                                    },
                                    activeColor: const Color(0xFF6366F1),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    side: const BorderSide(
                                      color: Color(0xFFCBD5E1),
                                      width: 1.5,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'Remember me',
                                  style: TextStyle(
                                    color: Color(0xFF64748B),
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            GestureDetector(
                              onTap: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: const Text(
                                      'Password reset functionality is under development.',
                                      style: TextStyle(fontWeight: FontWeight.w600),
                                    ),
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                );
                              },
                              child: const Text(
                                'Forgot password?',
                                style: TextStyle(
                                  color: Color(0xFF6366F1),
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        )
                        .animate()
                        .fadeIn(delay: 180.ms, duration: 300.ms),
                        const SizedBox(height: 24),

                        // Login Button
                        BlocConsumer<AuthBloc, AuthState>(
                          listener: (context, state) {
                            if (state is Authenticated) {
                              context.go('/dashboard');
                            } else if (state is AuthFailure) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(state.message),
                                  backgroundColor: AppColors.error,
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(
                                      AppSizes.radiusInput,
                                    ),
                                  ),
                                ),
                              );
                            }
                          },
                          builder: (context, state) {
                            if (state is AuthLoading) {
                              return const Center(
                                child: CircularProgressIndicator(
                                  color: Color(0xFF6366F1),
                                ),
                              );
                            }

                            return _AnimatedScaleButton(
                              onPressed: () {
                                if (_formKey.currentState!.validate()) {
                                  context.read<AuthBloc>().add(
                                    LoginRequested(
                                      _emailController.text.trim(),
                                      _passwordController.text,
                                    ),
                                  );
                                }
                              },
                              child: Container(
                                height: 48,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF6366F1),
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF6366F1).withValues(
                                        alpha: 0.2,
                                      ),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                alignment: Alignment.center,
                                child: const Text(
                                  'Login',
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
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Bottom switch link
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Don\'t have an account? ',
                        style: TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 13.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      GestureDetector(
                        onTap: () => context.go('/signup'),
                        child: const Text(
                          'Sign up',
                          style: TextStyle(
                            color: Color(0xFF6366F1),
                            fontWeight: FontWeight.bold,
                            fontSize: 13.5,
                          ),
                        ),
                      ),
                    ],
                  )
                  .animate()
                  .fadeIn(delay: 260.ms, duration: 300.ms),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),

        ],
      ),
    );
  }

  // Tab Header Selector Row
  Widget _buildTabs(BuildContext context, bool isLogin) {
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
                      'Login',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: isLogin ? FontWeight.bold : FontWeight.w600,
                        color: isLogin ? const Color(0xFF6366F1) : const Color(0xFF94A3B8),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      height: 2.5,
                      width: 100,
                      decoration: BoxDecoration(
                        color: isLogin ? const Color(0xFF6366F1) : Colors.transparent,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(2)),
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
                      'Sign Up',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: !isLogin ? FontWeight.bold : FontWeight.w600,
                        color: !isLogin ? const Color(0xFF6366F1) : const Color(0xFF94A3B8),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      height: 2.5,
                      width: 100,
                      decoration: BoxDecoration(
                        color: !isLogin ? const Color(0xFF6366F1) : Colors.transparent,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(2)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        Container(
          height: 1,
          color: const Color(0xFFE2E8F0),
        ),
      ],
    );
  }

  // Premium high-fidelity custom logo representing reference design
  Widget _buildTopIllustration() {
    return SizedBox(
      width: 180,
      height: 140,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          // 1. Organic soft background blob
          Positioned(
            child: Container(
              width: 140,
              height: 120,
              decoration: BoxDecoration(
                color: const Color(0xFFEEF2FF).withValues(alpha: 0.85),
                borderRadius: const BorderRadius.all(Radius.elliptical(85, 70)),
              ),
            ),
          ).animate().scale(duration: 800.ms, curve: Curves.easeOutBack),

          // 2. Main Logo (gradient rounded square)
          Positioned(
            child: Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF8B5CF6), Color(0xFF6366F1)],
                  begin: Alignment.bottomLeft,
                  end: Alignment.topRight,
                ),
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.35),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: const Icon(
                Icons.how_to_reg_rounded,
                color: Colors.white,
                size: 44,
              ),
            ),
          )
          .animate()
          .scale(
            begin: const Offset(0.7, 0.7),
            duration: 600.ms,
            curve: Curves.easeOutBack,
          ),

          // 3. Scattered decorations (crosses, circles)
          // Top-Left Cross
          Positioned(
            left: 10,
            top: 20,
            child: const Text(
              '×',
              style: TextStyle(
                color: Color(0xFF8B5CF6),
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            )
            .animate(onPlay: (c) => c.repeat(reverse: true))
            .slideY(begin: 0, end: -0.15, duration: 1500.ms),
          ),
          // Left Circle
          Positioned(
            left: 8,
            bottom: 30,
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF8B5CF6), width: 1.5),
              ),
            )
            .animate(onPlay: (c) => c.repeat(reverse: true))
            .slideY(begin: 0, end: 0.15, duration: 1800.ms),
          ),
          // Right Circle
          Positioned(
            right: 12,
            top: 40,
            child: Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF8B5CF6), width: 1.5),
              ),
            )
            .animate(onPlay: (c) => c.repeat(reverse: true))
            .slideY(begin: 0, end: -0.2, duration: 1600.ms),
          ),
          // Bottom-Right Cross
          Positioned(
            right: 16,
            bottom: 18,
            child: const Text(
              '×',
              style: TextStyle(
                color: Color(0xFF8B5CF6),
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            )
            .animate(onPlay: (c) => c.repeat(reverse: true))
            .slideY(begin: 0, end: 0.15, duration: 2000.ms),
          ),
        ],
      ),
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
