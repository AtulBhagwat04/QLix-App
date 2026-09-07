import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/network/socket_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/session.dart';
import '../blocs/session_bloc.dart';
import 'session_qr_dialog.dart';

class SessionMenuSheet extends StatelessWidget {
  final Session session;

  const SessionMenuSheet({
    super.key,
    required this.session,
  });

  static void show(BuildContext context, Session session) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      elevation: 0,
      builder: (ctx) => SessionMenuSheet(session: session),
    );
  }

  void _shareSessionInvite(String code) {
    SharePlus.instance.share(
      ShareParams(
        text:
            'Join my QLix interactive session using code: $code\nOr join online at: ${SocketClient.serverUrl}/session/$code',
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Session'),
        content: const Text(
          'Are you sure you want to delete this session? All votes and Q&A will be permanently lost.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              context.read<SessionBloc>().add(
                    DeleteSessionRequested(session.id),
                  );
              Navigator.pop(ctx);
            },
            child: const Text(
              'Delete',
              style: TextStyle(
                color: AppColors.error,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AppDecoration.glassWrapper(
      context: context,
      borderRadius: 24,
      blur: 24,
      opacity: isDark ? 0.85 : 0.95,
      child: Container(
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          session.displayTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: isDark
                                ? Colors.white
                                : AppColors.textPrimaryLight,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Code: ${session.accessCode}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 12),
              _MenuActionTile(
                icon: Icons.settings_remote_rounded,
                color: AppColors.primary,
                label: 'Control Room',
                description: 'Manage active polls and Q&A questions',
                onTap: () {
                  Navigator.pop(context);
                  context.push('/session/control/${session.id}');
                },
              ),
              _MenuActionTile(
                icon: Icons.present_to_all_rounded,
                color: AppColors.purpleAccent,
                label: 'Presenter Mode',
                description: 'Project visual presentation to users',
                onTap: () {
                  Navigator.pop(context);
                  context.push('/presenter/${session.accessCode}');
                },
              ),
              _MenuActionTile(
                icon: Icons.analytics_rounded,
                color: AppColors.secondary,
                label: 'Session Analytics',
                description: 'View participants and vote report',
                onTap: () {
                  Navigator.pop(context);
                  context.push('/analytics/${session.id}');
                },
              ),
              _MenuActionTile(
                icon: Icons.share_rounded,
                color: AppColors.info,
                label: 'Share Invite',
                description: 'Copy and share join link',
                onTap: () {
                  Navigator.pop(context);
                  _shareSessionInvite(session.accessCode);
                },
              ),
              _MenuActionTile(
                icon: Icons.qr_code_2_rounded,
                color: isDark ? Colors.white70 : AppColors.textSecondaryLight,
                label: 'QR Code',
                description: 'Show QR code for offline scan',
                onTap: () {
                  Navigator.pop(context);
                  SessionQrDialog.show(context, session.accessCode);
                },
              ),
              _MenuActionTile(
                icon: Icons.delete_outline_rounded,
                color: AppColors.error,
                label: 'Delete Session',
                description: 'Permanently remove all session data',
                onTap: () {
                  Navigator.pop(context);
                  _showDeleteConfirmation(context);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuActionTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String description;
  final VoidCallback onTap;

  const _MenuActionTile({
    required this.icon,
    required this.color,
    required this.label,
    required this.description,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color:
                          isDark ? Colors.white : AppColors.textPrimaryLight,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark
                          ? Colors.white54
                          : AppColors.textSecondaryLight,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: isDark ? Colors.white24 : Colors.black26,
            ),
          ],
        ),
      ),
    );
  }
}
