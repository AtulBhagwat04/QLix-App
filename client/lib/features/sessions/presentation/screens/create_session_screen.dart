import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_icons.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/widgets/qlix_button.dart';
import '../../../../core/widgets/qlix_card.dart';
import '../../../../core/widgets/qlix_text_field.dart';
import '../blocs/session_bloc.dart';

class CreateSessionScreen extends StatefulWidget {
  const CreateSessionScreen({super.key});

  @override
  State<CreateSessionScreen> createState() => _CreateSessionScreenState();
}

class _CreateSessionScreenState extends State<CreateSessionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  bool _qaModeration = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      context.read<SessionBloc>().add(
        CreateSessionRequested(
          title: _titleController.text.trim(),
          description: _descController.text.trim(),
          settings: {'qaModeration': _qaModeration},
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          AppStrings.createNewSession,
          style: AppTextStyles.titleMedium,
        ),
      ),
      body: BlocListener<SessionBloc, SessionState>(
        listener: (context, state) {
          if (state is SessionCreateSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text(AppStrings.sessionCreatedSuccess),
                backgroundColor: AppColors.success,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSizes.radiusInput),
                ),
              ),
            );
            context.pop();
            context.read<SessionBloc>().add(LoadSessions());
          } else if (state is SessionFailure) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
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
            padding: EdgeInsets.symmetric(
              horizontal: AppSizes.pageHorizontalPadding(context),
              vertical: AppSizes.space24,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: AppSizes.maxFormWidth(context),
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Session Details',
                      style: AppTextStyles.titleLarge,
                    ),
                const SizedBox(height: 8),
                const Text(
                  'Set up your room where users can participate in live polls and quiz games.',
                  style: AppTextStyles.subtitle,
                ),
                const SizedBox(height: 28),

                // Session Title Input
                QlixTextField(
                  controller: _titleController,
                  labelText: AppStrings.sessionTitleLabel,
                  hintText: AppStrings.sessionTitleHint,
                  prefixIcon: AppIcons.poll,
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'Enter a session title'
                      : null,
                ),
                const SizedBox(height: AppSizes.space20),

                // Session Description Input
                QlixTextField(
                  controller: _descController,
                  maxLines: 3,
                  labelText: AppStrings.sessionDescLabel,
                  hintText: AppStrings.sessionDescHint,
                  prefixIcon: Icons.description_outlined,
                ),
                const SizedBox(height: AppSizes.space28),
                const Divider(color: AppColors.divider),
                const SizedBox(height: AppSizes.space20),

                const Text(
                  'Feature Settings',
                  style: AppTextStyles.headlineMedium,
                ),
                const SizedBox(height: AppSizes.space16),

                // Visual moderation card toggle
                QlixCard(
                  onTap: () {
                    setState(() {
                      _qaModeration = !_qaModeration;
                    });
                  },
                  borderColor: _qaModeration
                      ? AppColors.primary
                      : AppColors.border,
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: _qaModeration
                              ? AppColors.primarySoft
                              : Colors.grey.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.admin_panel_settings_rounded,
                          color: _qaModeration
                              ? AppColors.primary
                              : Colors.grey,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: AppSizes.space16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              AppStrings.qaModerationLabel,
                              style: AppTextStyles.bodyLarge,
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              AppStrings.qaModerationSubtitle,
                              style: AppTextStyles.caption,
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: _qaModeration,
                        activeThumbColor: AppColors.primary,
                        onChanged: (val) {
                          setState(() {
                            _qaModeration = val;
                          });
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSizes.space48),

                // Submit Button
                BlocBuilder<SessionBloc, SessionState>(
                  builder: (context, state) {
                    return QlixButton.primary(
                      text: AppStrings.createSession,
                      isLoading: state is SessionLoading,
                      onPressed: _submit,
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  ),
);
  }
}
