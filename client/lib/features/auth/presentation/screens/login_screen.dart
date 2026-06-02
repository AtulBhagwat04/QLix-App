import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/theme/app_theme.dart';
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

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
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

            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // SaaS Platform Branding Logo
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
                        Icons.bolt_rounded,
                        size: 56,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                       'QLix Engagement',
                       style: TextStyle(
                         fontSize: 32,
                         fontWeight: FontWeight.w900,
                         color: isDark ? Colors.white : AppColors.textPrimaryLight,
                         letterSpacing: -1.0,
                       ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Log in to host live polling and quizzes',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                      ),
                    ),
                    const SizedBox(height: 36),

                    // Glassmorphism Card Wrapper
                    AppDecoration.glassWrapper(
                      context: context,
                      opacity: isDark ? 0.03 : 0.05,
                      child: Container(
                        padding: const EdgeInsets.all(28),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              TextFormField(
                                controller: _emailController,
                                style: TextStyle(color: isDark ? Colors.white : AppColors.textPrimaryLight),
                                decoration: const InputDecoration(
                                  labelText: 'Email Address',
                                  prefixIcon: Icon(Icons.email_rounded),
                                ),
                                validator: (v) => v == null || !v.contains('@') ? 'Enter a valid email' : null,
                              ),
                              const SizedBox(height: 20),
                              TextFormField(
                                controller: _passwordController,
                                obscureText: true,
                                style: TextStyle(color: isDark ? Colors.white : AppColors.textPrimaryLight),
                                decoration: const InputDecoration(
                                  labelText: 'Password',
                                  prefixIcon: Icon(Icons.lock_rounded),
                                ),
                                validator: (v) => v == null || v.length < 6 ? 'Password must be at least 6 characters' : null,
                              ),
                              const SizedBox(height: 32),
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
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSizes.radiusInput)),
                                      ),
                                    );
                                  }
                                },
                                builder: (context, state) {
                                  if (state is AuthLoading) {
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
                                        padding: const EdgeInsets.symmetric(vertical: 16),
                                      ),
                                      onPressed: () {
                                        if (_formKey.currentState!.validate()) {
                                          context.read<AuthBloc>().add(
                                            LoginRequested(_emailController.text.trim(), _passwordController.text),
                                          );
                                        }
                                      },
                                      child: const Text(
                                        'Sign In',
                                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
 
                    const SizedBox(height: 32),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Don\'t have a host account? ',
                          style: TextStyle(color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
                        ),
                        GestureDetector(
                          onTap: () => context.go('/signup'),
                          child: const Text(
                            'Sign Up',
                            style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    GestureDetector(
                      onTap: () => context.go('/'),
                      child: Text(
                        'Join a session as Participant',
                        style: TextStyle(
                          color: isDark ? Colors.white60 : AppColors.textSecondaryLight, 
                          decoration: TextDecoration.underline,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
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

