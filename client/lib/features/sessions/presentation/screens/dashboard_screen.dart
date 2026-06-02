import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../auth/presentation/blocs/auth_bloc.dart';
import '../blocs/session_bloc.dart';

class HostDashboardScreen extends StatefulWidget {
  const HostDashboardScreen({super.key});

  @override
  State<HostDashboardScreen> createState() => _HostDashboardScreenState();
}

class _HostDashboardScreenState extends State<HostDashboardScreen> {
  @override
  void initState() {
    super.initState();
    context.read<SessionBloc>().add(LoadSessions());
  }

  void _shareSessionInvite(String code) {
    Share.share('Join my QLix interactive session using code: $code\nOr join online at: http://localhost:3000/session/$code');
  }

  void _showQrDialog(BuildContext context, String code) {
    showDialog(
      context: context,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: AppDecoration.glassWrapper(
            context: context,
            borderRadius: AppSizes.radiusCard,
            blur: 24,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Session QR Code',
                    style: TextStyle(
                      fontSize: 20, 
                      fontWeight: FontWeight.w800, 
                      color: isDark ? Colors.white : AppColors.textPrimaryLight,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(AppSizes.radiusCard),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: QrImageView(
                      data: 'http://localhost:3000/session/$code',
                      version: QrVersions.auto,
                      size: 200,
                      gapless: false,
                      foregroundColor: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Code: $code',
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: AppColors.primary),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Participants can scan this QR code with their phone camera or the QLix scanner to join instantly.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12, 
                      height: 1.4,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white60 : AppColors.textSecondaryLight,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        ),
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Close'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDashboardStats(List<dynamic> sessions) {
    final total = sessions.length;
    final active = sessions.where((s) => s['state'] == 'active').length;
    final ended = sessions.where((s) => s['state'] == 'ended').length;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Expanded(child: _buildStatCard('Total Rooms', '$total', Icons.meeting_room_rounded, AppColors.primary)),
          const SizedBox(width: 12),
          Expanded(child: _buildStatCard('Live Active', '$active', Icons.sensors_rounded, AppColors.success, pulse: active > 0)),
          const SizedBox(width: 12),
          Expanded(child: _buildStatCard('Completed', '$ended', Icons.check_circle_outline_rounded, Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color, {bool pulse = false}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AppDecoration.glassWrapper(
      context: context,
      opacity: isDark ? 0.03 : 0.05,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: color, size: 20),
                if (pulse)
                  const _PulseDot()
              ],
            ),
            const SizedBox(height: 12),
            Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, height: 1.0)),
            const SizedBox(height: 4),
            Text(
              label, 
              style: TextStyle(
                fontSize: 10, 
                fontWeight: FontWeight.bold, 
                color: isDark ? Colors.white.withOpacity(0.5) : Colors.black45,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Host Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Sign Out',
            onPressed: () {
              context.read<AuthBloc>().add(LogoutRequested());
              context.go('/');
            },
          ),
        ],
      ),
      body: BlocBuilder<SessionBloc, SessionState>(
        builder: (context, state) {
          if (state is SessionLoading) {
            return const Center(child: CircularProgressIndicator(color: AppColors.primary));
          }

          if (state is SessionFailure) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Error: ${state.message}', style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                    onPressed: () => context.read<SessionBloc>().add(LoadSessions()),
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          if (state is SessionsLoaded) {
            final sessions = state.sessions;

            if (sessions.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.event_busy_rounded, size: 72, color: isDark ? Colors.white24 : Colors.black12),
                      const SizedBox(height: 20),
                      const Text('No sessions created yet', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text(
                        'Create your first session to start engaging your audience', 
                        textAlign: TextAlign.center,
                        style: TextStyle(color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
                      ),
                      const SizedBox(height: 28),
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(AppSizes.radiusPill),
                          gradient: const LinearGradient(colors: AppColors.primaryGradient),
                        ),
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                          ),
                          onPressed: () => context.push('/session/create'),
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('Create Session', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            return RefreshIndicator(
              onRefresh: () async {
                context.read<SessionBloc>().add(LoadSessions());
              },
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: sessions.length + 1,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return _buildDashboardStats(sessions);
                  }

                  final session = sessions[index - 1];
                  final code = session['access_code'] as String;
                  final sessionId = session['id'] as String;
                  final status = session['state'] as String;

                  Color statusColor;
                  switch (status) {
                    case 'active':
                      statusColor = AppColors.success;
                      break;
                    case 'ended':
                      statusColor = AppColors.error;
                      break;
                    default:
                      statusColor = AppColors.warning;
                  }

                  return Card(
                    clipBehavior: Clip.antiAlias,
                    margin: const EdgeInsets.only(bottom: 16),
                    child: IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Left color indicator bar
                          Container(
                            width: 6,
                            color: statusColor,
                          ),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: statusColor.withOpacity(0.12),
                                          borderRadius: BorderRadius.circular(AppSizes.radiusBadge),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            if (status == 'active') ...[
                                              const _PulseDot(),
                                              const SizedBox(width: 6),
                                            ],
                                            Text(
                                              status.toUpperCase(),
                                              style: TextStyle(
                                                color: statusColor, 
                                                fontSize: 10, 
                                                fontWeight: FontWeight.w800, 
                                                letterSpacing: 0.5,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Row(
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.qr_code_2_rounded, size: 20),
                                            onPressed: () => _showQrDialog(context, code),
                                            tooltip: 'Session QR Code',
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.share_rounded, size: 20),
                                            onPressed: () => _shareSessionInvite(code),
                                            tooltip: 'Invite Link',
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 20),
                                            onPressed: () {
                                              showDialog(
                                                context: context,
                                                builder: (ctx) => AlertDialog(
                                                  title: const Text('Delete Session'),
                                                  content: const Text('Are you sure you want to delete this session? All votes and Q&A will be permanently lost.'),
                                                  actions: [
                                                    TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                                                    TextButton(
                                                      onPressed: () {
                                                        context.read<SessionBloc>().add(DeleteSessionRequested(sessionId));
                                                        Navigator.pop(ctx);
                                                      },
                                                      child: const Text('Delete', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold)),
                                                    ),
                                                  ],
                                                ),
                                              );
                                            },
                                            tooltip: 'Delete Session',
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    session['title'] as String,
                                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.3),
                                  ),
                                  if (session['description'] != null && (session['description'] as String).isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      session['description'] as String,
                                      style: TextStyle(
                                        fontSize: 13, 
                                        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                  const SizedBox(height: 16),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: AppColors.primary.withOpacity(0.08),
                                          borderRadius: BorderRadius.circular(AppSizes.radiusBadge),
                                        ),
                                        child: Row(
                                          children: [
                                            const Icon(Icons.key_rounded, size: 14, color: AppColors.primary),
                                            const SizedBox(width: 6),
                                            Text(
                                              'CODE: $code',
                                              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: AppColors.primary),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  const Divider(height: 1),
                                  const SizedBox(height: 12),
                                  // Toolbar Row
                                  Row(
                                    children: [
                                      Expanded(
                                        child: OutlinedButton.icon(
                                          onPressed: () => context.push('/session/control/$sessionId'),
                                          icon: const Icon(Icons.settings_remote_rounded, size: 16),
                                          label: const Text('Control', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: AppColors.primary,
                                            side: const BorderSide(color: AppColors.primary, width: 1.0),
                                            padding: const EdgeInsets.symmetric(vertical: 12),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSizes.radiusButton)),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: OutlinedButton.icon(
                                          onPressed: () => context.push('/presenter/$code'),
                                          icon: const Icon(Icons.present_to_all_rounded, size: 16),
                                          label: const Text('Presenter', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: AppColors.purpleAccent,
                                            side: const BorderSide(color: AppColors.purpleAccent, width: 1.0),
                                            padding: const EdgeInsets.symmetric(vertical: 12),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSizes.radiusButton)),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: OutlinedButton.icon(
                                          onPressed: () => context.push('/analytics/$sessionId'),
                                          icon: const Icon(Icons.analytics_rounded, size: 16),
                                          label: const Text('Analytics', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: AppColors.secondary,
                                            side: const BorderSide(color: AppColors.secondary, width: 1.0),
                                            padding: const EdgeInsets.symmetric(vertical: 12),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSizes.radiusButton)),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            );
          }

          return const SizedBox.shrink();
        },
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppSizes.radiusPill),
          gradient: const LinearGradient(colors: AppColors.primaryGradient),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.3),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: FloatingActionButton.extended(
          backgroundColor: Colors.transparent,
          elevation: 0,
          onPressed: () => context.push('/session/create'),
          icon: const Icon(Icons.add_rounded, color: Colors.white),
          label: const Text('Create Room', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        ),
      ),
    );
  }
}

// Micro-animation pulsing dot
class _PulseDot extends StatefulWidget {
  const _PulseDot();

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        return Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.success,
            boxShadow: [
              BoxShadow(
                color: AppColors.success.withOpacity(0.4 * _ctrl.value + 0.1),
                blurRadius: 6.0 * _ctrl.value + 2.0,
                spreadRadius: 2.5 * _ctrl.value,
              ),
            ],
          ),
        );
      },
    );
  }
}

