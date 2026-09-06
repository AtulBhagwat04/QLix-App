import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_icons.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/widgets/qlix_button.dart';
import '../../../../core/widgets/qlix_text_field.dart';
import '../../../../core/network/network_settings_dialog.dart';
import '../blocs/auth_bloc.dart';
import '../widgets/auth_header_widgets.dart';

class HostLoginScreen extends StatefulWidget {
  const HostLoginScreen({super.key});

  @override
  State<HostLoginScreen> createState() => _HostLoginScreenState();
}

class _HostLoginScreenState extends State<HostLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _rememberMe = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _onLoginPressed() {
    if (_formKey.currentState!.validate()) {
      context.read<AuthBloc>().add(
        LoginRequested(
          _emailController.text.trim(),
          _passwordController.text,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final double horizontalPadding = AppSizes.pageHorizontalPadding(context);
    final double formMaxWidth = AppSizes.maxFormWidth(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Scrollable Content Area with max form width constraint
          Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding,
                vertical: context.hPct(2.5).clamp(16.0, 32.0),
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: formMaxWidth),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(height: context.hPct(2).clamp(12.0, 24.0)),

                    // Top illustration (Responsive scale)
                    const AuthTopIllustration(),
                    SizedBox(height: context.hPct(1.5).clamp(10.0, 18.0)),

                    // Title and Subtitle
                    Text(
                          AppStrings.welcomeBack,
                          style: AppTextStyles.titleLarge.copyWith(
                            fontSize: context.rSize(24, minScale: 0.9, maxScale: 1.15),
                          ),
                        )
                        .animate()
                        .fadeIn(duration: 400.ms)
                        .slideY(begin: 0.1, end: 0),
                    const SizedBox(height: 6),

                    Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            AppStrings.welcomeSubtitle,
                            style: AppTextStyles.subtitle.copyWith(
                              fontSize: context.rSize(13, minScale: 0.9, maxScale: 1.1),
                            ),
                            textAlign: TextAlign.center,
                          ),
                        )
                        .animate()
                        .fadeIn(delay: 100.ms, duration: 400.ms)
                        .slideY(begin: 0.1, end: 0),
                    SizedBox(height: context.hPct(3).clamp(16.0, 28.0)),

                    // Tab switcher (Login / Sign Up)
                    const AuthTabSwitcher(
                      isLogin: true,
                    ).animate().fadeIn(delay: 120.ms, duration: 300.ms),
                    SizedBox(height: context.hPct(2.5).clamp(16.0, 24.0)),

                    // Login Form Card
                    Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Email field
                          QlixTextField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            hintText: AppStrings.emailHint,
                            prefixIcon: AppIcons.email,
                            validator: (v) => v == null || !v.contains('@')
                                ? AppStrings.validEmailError
                                : null,
                          ).animate().fadeIn(delay: 140.ms, duration: 300.ms),
                          const SizedBox(height: AppSizes.space16),

                          // Password field
                          QlixTextField(
                            controller: _passwordController,
                            isPassword: true,
                            hintText: AppStrings.passwordHint,
                            prefixIcon: AppIcons.lock,
                            validator: (v) => v == null || v.length < 6
                                ? AppStrings.passwordLengthError
                                : null,
                            onFieldSubmitted: (_) => _onLoginPressed(),
                          ).animate().fadeIn(delay: 160.ms, duration: 300.ms),
                          const SizedBox(height: AppSizes.space16),

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
                                      activeColor: AppColors.primary,
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
                                    AppStrings.rememberMe,
                                    style: AppTextStyles.bodyMedium,
                                  ),
                                ],
                              ),
                              GestureDetector(
                                onTap: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: const Text(
                                        AppStrings.forgotPasswordDev,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(
                                          AppSizes.radiusInput,
                                        ),
                                      ),
                                    ),
                                  );
                                },
                                child: Text(
                                  AppStrings.forgotPassword,
                                  style: AppTextStyles.bodyMedium.copyWith(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ).animate().fadeIn(delay: 180.ms, duration: 300.ms),
                          SizedBox(height: context.hPct(2.5).clamp(16.0, 24.0)),

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
                              return QlixButton.primary(
                                text: AppStrings.login,
                                height: context.rSize(48, minScale: 0.9, maxScale: 1.15),
                                isLoading: state is AuthLoading,
                                onPressed: _onLoginPressed,
                              );
                            },
                          )
                              .animate()
                              .fadeIn(delay: 200.ms, duration: 400.ms)
                              .slideY(begin: 0.1, end: 0),
                        ],
                      ),
                    ),
                    SizedBox(height: context.hPct(2.5).clamp(16.0, 24.0)),

                    // Bottom switch link
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          AppStrings.dontHaveAccount,
                          style: AppTextStyles.bodyMedium,
                        ),
                        GestureDetector(
                          onTap: () => context.go('/signup'),
                          child: Text(
                            AppStrings.signUp,
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ).animate().fadeIn(delay: 260.ms, duration: 300.ms),
                    const SizedBox(height: AppSizes.space12),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            right: 16,
            child: IconButton(
              icon: const Icon(
                AppIcons.serverSettings,
                color: AppColors.textMuted,
                size: AppSizes.iconMedium,
              ),
              tooltip: AppStrings.serverSettings,
              onPressed: () => showNetworkSettingsDialog(context),
            ),
          ),
        ],
      ),
    );
  }
}
