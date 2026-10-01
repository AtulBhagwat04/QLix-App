import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/widgets/qlix_button.dart';
import '../../../../core/widgets/qlix_text_field.dart';
import '../../domain/entities/user_profile.dart';
import '../blocs/profile_bloc.dart';
import '../blocs/profile_event.dart';
import '../blocs/profile_state.dart';
import '../widgets/profile_app_bar.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  late final TextEditingController _newPasswordController;
  late final TextEditingController _confirmPasswordController;

  bool _isInitialized = false;
  bool _changePasswordEnabled = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _emailController = TextEditingController();
    _newPasswordController = TextEditingController();
    _confirmPasswordController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _populateFields(UserProfile profile) {
    if (!_isInitialized) {
      _nameController.text = profile.fullName;
      _emailController.text = profile.email;
      _isInitialized = true;
    }
  }

  void _handleSave(UserProfile currentProfile) {
    if (!_formKey.currentState!.validate()) return;

    final newName = _nameController.text.trim();
    final newPassword = _newPasswordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    // 1. Check if name was modified
    if (newName != currentProfile.fullName) {
      final updated = currentProfile.copyWith(fullName: newName);
      context.read<ProfileBloc>().add(UpdateProfileRequested(updated));
    }

    // 2. Check if password is being updated
    if (_changePasswordEnabled && newPassword.isNotEmpty) {
      if (newPassword != confirmPassword) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Passwords do not match'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
      context.read<ProfileBloc>().add(
        ChangePasswordRequested(newPassword: newPassword),
      );
    } else if (newName == currentProfile.fullName && !_changePasswordEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No changes to save'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final cardBorder = isDark
        ? const Color(0xFF334155)
        : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? Colors.white : AppColors.textPrimaryLight;
    final textSub = isDark
        ? const Color(0xFF94A3B8)
        : AppColors.textSecondaryLight;
    final formMaxWidth = AppSizes.maxFormWidth(context);

    return BlocConsumer<ProfileBloc, ProfileState>(
      listener: (context, state) {
        if (state is ProfileLoaded) {
          if (state.successMessage != null) {
            if (_changePasswordEnabled) {
              setState(() {
                _changePasswordEnabled = false;
                _newPasswordController.clear();
                _confirmPasswordController.clear();
              });
            }
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(
                      Icons.check_circle_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(state.successMessage!)),
                  ],
                ),
                backgroundColor: AppColors.success,
                behavior: SnackBarBehavior.floating,
              ),
            );
          } else if (state.errorMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.errorMessage!),
                backgroundColor: AppColors.error,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        }
      },
      builder: (context, state) {
        UserProfile profile = const UserProfile(
          id: 'host',
          fullName: 'Alex Johnson',
          email: 'alex@qlix.com',
        );

        bool isSaving = false;

        if (state is ProfileLoaded) {
          profile = state.profile;
          isSaving = state.isSaving;
          _populateFields(profile);
        } else if (state is ProfileInitial) {
          context.read<ProfileBloc>().add(LoadProfile());
        }

        final displayName = _nameController.text.isNotEmpty
            ? _nameController.text
            : profile.fullName;

        final initials = displayName.trim().isNotEmpty
            ? displayName
                  .trim()
                  .split(' ')
                  .where((w) => w.isNotEmpty)
                  .map((e) => e[0])
                  .take(2)
                  .join()
                  .toUpperCase()
            : 'A';

        return Scaffold(
          backgroundColor: isDark
              ? const Color(0xFF0F172A)
              : const Color(0xFFF8F9FD),
          appBar: ProfileAppBar(
            title: 'Edit Profile',
            subtitle: 'Personal details & security',
            actions: [],
          ),
          body: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: AppSizes.pageHorizontalPadding(context),
                vertical: 24,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: formMaxWidth),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ── Hero Profile Card ──────────────────────────────
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: cardBorder, width: 1),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(
                                alpha: isDark ? 0.0 : 0.03,
                              ),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Stack(
                              children: [
                                Container(
                                  width: 72,
                                  height: 72,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: const LinearGradient(
                                      colors: [
                                        Color(0xFF6366F1),
                                        Color(0xFF8B5CF6),
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.primary.withValues(
                                          alpha: 0.25,
                                        ),
                                        blurRadius: 12,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    initials,
                                    style: const TextStyle(
                                      fontSize: 26,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                Positioned(
                                  right: 0,
                                  bottom: 0,
                                  child: Container(
                                    width: 24,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: AppColors.primary,
                                      border: Border.all(
                                        color: cardBg,
                                        width: 2,
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.camera_alt_rounded,
                                      size: 13,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    displayName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      color: textPrimary,
                                      letterSpacing: -0.3,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    profile.email,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w500,
                                      color: textSub,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withValues(
                                        alpha: 0.09,
                                      ),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text(
                                      'Host Account  •  Active',
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // ── Account Details Card ────────────────────────────
                      _buildSectionHeader(
                        'Account Details',
                        Icons.badge_outlined,
                        textPrimary,
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: cardBorder, width: 1),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildInputLabel('Full Name', textPrimary),
                            const SizedBox(height: 8),
                            QlixTextField(
                              controller: _nameController,
                              hintText: 'Enter your full name',
                              prefixIcon: Icons.person_outline_rounded,
                              onChanged: (_) => setState(() {}),
                              validator: (val) {
                                if (val == null || val.trim().length < 2) {
                                  return 'Please enter a valid full name';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 18),

                            _buildInputLabel('Email Address', textPrimary),
                            const SizedBox(height: 8),
                            QlixTextField(
                              controller: _emailController,
                              readOnly: true,
                              prefixIcon: Icons.mail_outline_rounded,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // ── Password & Security Card ────────────────────────
                      _buildSectionHeader(
                        'Password & Security',
                        Icons.lock_outline_rounded,
                        textPrimary,
                      ),
                      const SizedBox(height: 10),
                      Container(
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: _changePasswordEnabled
                                ? AppColors.primary.withValues(alpha: 0.35)
                                : cardBorder,
                            width: _changePasswordEnabled ? 1.5 : 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: _changePasswordEnabled
                                  ? AppColors.primary.withValues(alpha: 0.04)
                                  : Colors.black.withValues(
                                      alpha: isDark ? 0.0 : 0.02,
                                    ),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: Padding(
                            padding: const EdgeInsets.all(18),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                InkWell(
                                  borderRadius: BorderRadius.circular(12),
                                  onTap: () {
                                    setState(() {
                                      _changePasswordEnabled =
                                          !_changePasswordEnabled;
                                      if (!_changePasswordEnabled) {
                                        _newPasswordController.clear();
                                        _confirmPasswordController.clear();
                                      }
                                    });
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 4,
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 38,
                                          height: 38,
                                          decoration: BoxDecoration(
                                            color: AppColors.primary.withValues(
                                              alpha: 0.1,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                          ),
                                          child: const Icon(
                                            Icons.key_rounded,
                                            size: 18,
                                            color: AppColors.primary,
                                          ),
                                        ),
                                        const SizedBox(width: 14),
                                        Expanded(
                                          child: Text(
                                            'Change Password',
                                            style: TextStyle(
                                              fontSize: 14.5,
                                              fontWeight: FontWeight.w700,
                                              color: textPrimary,
                                            ),
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: _changePasswordEnabled
                                                ? (isDark
                                                    ? Colors.white.withValues(
                                                        alpha: 0.06,
                                                      )
                                                    : const Color(0xFFF1F5F9))
                                                : AppColors.primary.withValues(
                                                    alpha: 0.08,
                                                  ),
                                            borderRadius: BorderRadius.circular(
                                              20,
                                            ),
                                            border: Border.all(
                                              color: _changePasswordEnabled
                                                  ? cardBorder
                                                  : AppColors.primary
                                                      .withValues(alpha: 0.25),
                                              width: 1,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                _changePasswordEnabled
                                                    ? 'Cancel'
                                                    : 'Change',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                  color: _changePasswordEnabled
                                                      ? textSub
                                                      : AppColors.primary,
                                                ),
                                              ),
                                              const SizedBox(width: 4),
                                              AnimatedRotation(
                                                turns: _changePasswordEnabled
                                                    ? 0.5
                                                    : 0.0,
                                                duration: const Duration(
                                                  milliseconds: 200,
                                                ),
                                                child: Icon(
                                                  Icons.keyboard_arrow_down_rounded,
                                                  size: 16,
                                                  color: _changePasswordEnabled
                                                      ? textSub
                                                      : AppColors.primary,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),

                            // Expandable password fields
                            AnimatedCrossFade(
                              firstChild: const SizedBox.shrink(),
                              secondChild: Padding(
                                padding: const EdgeInsets.only(top: 18),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Divider(
                                      height: 1,
                                      color: isDark
                                          ? Colors.white.withValues(alpha: 0.08)
                                          : const Color(0xFFF1F5F9),
                                    ),
                                    const SizedBox(height: 18),

                                    _buildInputLabel(
                                      'New Password',
                                      textPrimary,
                                    ),
                                    const SizedBox(height: 8),
                                    QlixTextField(
                                      controller: _newPasswordController,
                                      isPassword: true,
                                      hintText:
                                          'Enter new password (min. 6 characters)',
                                      prefixIcon: Icons.lock_outline_rounded,
                                      onChanged: (_) => setState(() {}),
                                      validator: (val) {
                                        if (!_changePasswordEnabled) {
                                          return null;
                                        }
                                        if (val == null || val.length < 6) {
                                          return 'Password must be at least 6 characters';
                                        }
                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: 18),

                                    _buildInputLabel(
                                      'Confirm New Password',
                                      textPrimary,
                                    ),
                                    const SizedBox(height: 8),
                                    QlixTextField(
                                      controller: _confirmPasswordController,
                                      isPassword: true,
                                      hintText: 'Confirm new password',
                                      prefixIcon: Icons.lock_reset_rounded,
                                      onChanged: (_) => setState(() {}),
                                      validator: (val) {
                                        if (!_changePasswordEnabled) {
                                          return null;
                                        }
                                        if (val !=
                                            _newPasswordController.text) {
                                          return 'Passwords do not match';
                                        }
                                        return null;
                                      },
                                    ),

                                    // Password Match helper
                                    if (_newPasswordController
                                            .text
                                            .isNotEmpty &&
                                        _confirmPasswordController
                                            .text
                                            .isNotEmpty) ...[
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          Icon(
                                            _newPasswordController.text ==
                                                    _confirmPasswordController
                                                        .text
                                                ? Icons.check_circle_rounded
                                                : Icons.cancel_rounded,
                                            size: 14,
                                            color:
                                                _newPasswordController.text ==
                                                    _confirmPasswordController
                                                        .text
                                                ? AppColors.success
                                                : AppColors.error,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            _newPasswordController.text ==
                                                    _confirmPasswordController
                                                        .text
                                                ? 'Passwords match'
                                                : 'Passwords do not match',
                                            style: TextStyle(
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.w600,
                                              color:
                                                  _newPasswordController.text ==
                                                      _confirmPasswordController
                                                          .text
                                                  ? AppColors.success
                                                  : AppColors.error,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              crossFadeState: _changePasswordEnabled
                                  ? CrossFadeState.showSecond
                                  : CrossFadeState.showFirst,
                              duration: const Duration(milliseconds: 240),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                      const SizedBox(height: 32),

                      // ── Primary Save Button ─────────────────────────────
                      QlixButton.primary(
                        text: 'Save Changes',
                        isLoading: isSaving,
                        height: 52,
                        borderRadius: 16,
                        onPressed: isSaving ? null : () => _handleSave(profile),
                      ),
                    ],
                  ).animate().fade(duration: 300.ms).slideY(begin: 0.02, end: 0),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color textColor) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.w800,
            color: textColor,
            letterSpacing: -0.2,
          ),
        ),
      ],
    );
  }

  Widget _buildInputLabel(String label, Color textColor) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: textColor,
      ),
    );
  }
}
