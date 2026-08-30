import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/storage/secure_storage.dart';
import '../../../../core/storage/cache_manager.dart';
import '../../../../core/network/socket_client.dart';
import '../../../../core/network/api_client.dart';
import '../../../auth/presentation/blocs/auth_bloc.dart';
import '../blocs/session_bloc.dart';

class HostDashboardScreen extends StatefulWidget {
  const HostDashboardScreen({super.key});

  @override
  State<HostDashboardScreen> createState() => _HostDashboardScreenState();
}

class _HostDashboardScreenState extends State<HostDashboardScreen> {
  int? _currentTab = 0;
  String _hostName = 'Alex';
  String _hostEmail = 'alex@qlix.com';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  List<Map<String, dynamic>> _lastSessions = [];
  Map<String, dynamic>? _lastStats;

  @override
  void initState() {
    super.initState();
    _searchFocusNode.addListener(() {
      if (mounted) setState(() {});
    });
    _lastSessions = sl<CacheManager>().getCachedSessions();
    _lastStats = sl<CacheManager>().getCachedOverviewStats();
    _loadHostProfile();
    context.read<SessionBloc>().add(LoadSessions());
  }

  @override
  void dispose() {
    _searchFocusNode.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadHostProfile() async {
    try {
      final secureStorage = sl<SecureStorageService>();
      final token = await secureStorage.getAccessToken();
      if (token != null) {
        final payload = _decodeJwt(token);
        setState(() {
          if (payload['name'] != null) {
            _hostName = payload['name'] as String;
          }
          if (payload['email'] != null) {
            _hostEmail = payload['email'] as String;
          }
        });
      }
    } catch (_) {
      // Keep default
    }
  }

  Map<String, dynamic> _decodeJwt(String token) {
    final parts = token.split('.');
    if (parts.length != 3) {
      throw Exception('Invalid token');
    }
    final payload = parts[1];
    var normalized = base64Url.normalize(payload);
    final resp = utf8.decode(base64Url.decode(normalized));
    return json.decode(resp) as Map<String, dynamic>;
  }

  void _shareSessionInvite(String code) {
    Share.share(
      'Join my QLix interactive session using code: $code\nOr join online at: ${SocketClient.serverUrl}/session/$code',
    );
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final date = DateTime.parse(dateStr).toLocal();
      final months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      return '${months[date.month - 1]} ${date.day}, ${date.year}';
    } catch (_) {
      return dateStr;
    }
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
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: QrImageView(
                      data: 'http://${ApiClient.defaultHost}:3000/session/$code',
                      version: QrVersions.auto,
                      size: 200,
                      gapless: false,
                      foregroundColor: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Code: $code',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Scan to join the session instantly.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.4,
                      fontWeight: FontWeight.w500,
                      color: isDark
                          ? Colors.white60
                          : AppColors.textSecondaryLight,
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
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
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

  void _showSessionMenu(BuildContext context, Map<String, dynamic> session) {
    final title = session['title'] as String? ?? 'Session';
    final code = session['access_code'] as String? ?? '';
    final sessionId = session['id'] as String? ?? '';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      elevation: 0,
      builder: (ctx) {
        return AppDecoration.glassWrapper(
          context: ctx,
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
                              title,
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
                              'Code: $code',
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
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 12),
                  _buildMenuActionTile(
                    context: ctx,
                    icon: Icons.settings_remote_rounded,
                    color: AppColors.primary,
                    label: 'Control Room',
                    description: 'Manage active polls and Q&A questions',
                    onTap: () {
                      Navigator.pop(ctx);
                      context.push('/session/control/$sessionId');
                    },
                  ),
                  _buildMenuActionTile(
                    context: ctx,
                    icon: Icons.present_to_all_rounded,
                    color: AppColors.purpleAccent,
                    label: 'Presenter Mode',
                    description: 'Project visual presentation to users',
                    onTap: () {
                      Navigator.pop(ctx);
                      context.push('/presenter/$code');
                    },
                  ),
                  _buildMenuActionTile(
                    context: ctx,
                    icon: Icons.analytics_rounded,
                    color: AppColors.secondary,
                    label: 'Session Analytics',
                    description: 'View participants and vote report',
                    onTap: () {
                      Navigator.pop(ctx);
                      context.push('/analytics/$sessionId');
                    },
                  ),
                  _buildMenuActionTile(
                    context: ctx,
                    icon: Icons.share_rounded,
                    color: AppColors.info,
                    label: 'Share Invite',
                    description: 'Copy and share join link',
                    onTap: () {
                      Navigator.pop(ctx);
                      _shareSessionInvite(code);
                    },
                  ),
                  _buildMenuActionTile(
                    context: ctx,
                    icon: Icons.qr_code_2_rounded,
                    color: isDark
                        ? Colors.white70
                        : AppColors.textSecondaryLight,
                    label: 'QR Code',
                    description: 'Show QR code for offline scan',
                    onTap: () {
                      Navigator.pop(ctx);
                      _showQrDialog(context, code);
                    },
                  ),
                  _buildMenuActionTile(
                    context: ctx,
                    icon: Icons.delete_outline_rounded,
                    color: AppColors.error,
                    label: 'Delete Session',
                    description: 'Permanently remove all session data',
                    onTap: () {
                      Navigator.pop(ctx);
                      _showDeleteConfirmation(context, sessionId);
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMenuActionTile({
    required BuildContext context,
    required IconData icon,
    required Color color,
    required String label,
    required String description,
    required VoidCallback onTap,
  }) {
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
                      color: isDark ? Colors.white : AppColors.textPrimaryLight,
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

  void _showDeleteConfirmation(BuildContext context, String sessionId) {
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
                DeleteSessionRequested(sessionId),
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

  Widget _buildLogoIcon() {
    return Container(
      width: 44,
      height: 44,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: AppColors.primaryGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 3.5,
              height: 14,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(1.5),
              ),
            ),
            const SizedBox(width: 3),
            Container(
              width: 3.5,
              height: 22,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(1.5),
              ),
            ),
            const SizedBox(width: 3),
            Container(
              width: 3.5,
              height: 16,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(1.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        //_buildLogoIcon(),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hello, $_hostName! 👋',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : AppColors.textPrimaryLight,
                  letterSpacing: -0.8,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Ready to create engaging sessions?',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                ),
              ),
            ],
          ),
        ),
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : const Color(0xFFEEF2F6),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: Icon(
                  Icons.notifications_none_rounded,
                  size: 24,
                  color: isDark ? Colors.white : AppColors.textPrimaryLight,
                ),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('No new notifications')),
                  );
                },
              ),
            ),
            Positioned(
              right: 0,
              top: 0,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                child: const Center(
                  child: Text(
                    '3',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      height: 1.0,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickActionCards() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.surfaceDark.withValues(alpha: 0.4)
            : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: () => context.push('/session/create'),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 16,
                  horizontal: 12,
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.add_rounded,
                        color: AppColors.primary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Create',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                              color: isDark
                                  ? Colors.white
                                  : AppColors.textPrimaryLight,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 3),
                          const Text(
                            'New Session',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Container(
            width: 1,
            height: 48,
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : const Color(0xFFE2E8F0),
          ),
          Expanded(
            child: InkWell(
              onTap: () => context.push('/'),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 16,
                  horizontal: 12,
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.secondary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.qr_code,
                        color: AppColors.secondary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Join',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                              color: isDark
                                  ? Colors.white
                                  : AppColors.textPrimaryLight,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 3),
                          const Text(
                            'Live Session',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewSection(
    Map<String, dynamic>? stats,
    List<dynamic> sessions,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final totalSessions = stats?['totalSessions'] ?? sessions.length;
    final totalParticipants =
        stats?['totalParticipants'] ??
        sessions.fold<int>(
          0,
          (sum, s) => sum + (s['participant_count'] as int? ?? 0),
        );
    final totalResponses = stats?['totalResponses'] ?? 0;
    final totalQuizzes =
        stats?['totalQuizzes'] ??
        sessions.fold<int>(0, (sum, s) => sum + (s['poll_count'] as int? ?? 0));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Overview',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : AppColors.textPrimaryLight,
                letterSpacing: -0.5,
              ),
            ),
            TextButton(
              onPressed: () {
                if (sessions.isNotEmpty) {
                  context.push('/analytics/${sessions.first['id']}');
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('No sessions available to view analytics'),
                    ),
                  );
                }
              },
              child: const Row(
                children: [
                  Text(
                    'View Analytics',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                  ),
                  SizedBox(width: 4),
                  Icon(Icons.arrow_forward_rounded, size: 14),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.4,
          children: [
            _buildOverviewCard(
              value: '$totalSessions',
              label: 'Sessions',
              icon: Icons.forum_rounded,
              color: AppColors.primary,
              onTap: () {
                setState(() {
                  _currentTab = 1;
                });
              },
            ),
            _buildOverviewCard(
              value: '$totalParticipants',
              label: 'Participants',
              icon: Icons.people_alt_rounded,
              color: AppColors.success,
              onTap: () {
                if (sessions.isNotEmpty) {
                  context.push('/analytics/${sessions.first['id']}');
                }
              },
            ),
            _buildOverviewCard(
              value: '$totalResponses',
              label: 'Responses',
              icon: Icons.chat_bubble_rounded,
              color: AppColors.warning,
              onTap: () {
                if (sessions.isNotEmpty) {
                  context.push('/analytics/${sessions.first['id']}');
                }
              },
            ),
            _buildOverviewCard(
              value: '$totalQuizzes',
              label: 'Quizzes',
              icon: Icons.bar_chart_rounded,
              color: AppColors.secondary,
              onTap: () {
                if (sessions.isNotEmpty) {
                  context.push('/analytics/${sessions.first['id']}');
                }
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildOverviewCard({
    required String value,
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        splashColor: color.withValues(alpha: 0.12),
        highlightColor: color.withValues(alpha: 0.06),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: isDark
                ? AppColors.surfaceDark.withValues(alpha: 0.4)
                : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : const Color(0xFFE2E8F0),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.015),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: color, size: 20),
                  ),
                  Icon(
                    Icons.arrow_outward_rounded,
                    size: 14,
                    color: isDark ? Colors.white30 : Colors.grey.shade400,
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: isDark ? Colors.white : AppColors.textPrimaryLight,
                      letterSpacing: -0.5,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecentSessionsSection(List<dynamic> sessions) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bool showAll = (_currentTab ?? 0) == 1;
    List<dynamic> targetSessions;
    if (!showAll) {
      // Show all recent sessions (active, draft, and ended) on the home tab
      targetSessions = sessions.take(5).toList();
    } else {
      targetSessions = sessions;
    }

    if (_searchQuery.isNotEmpty && showAll) {
      targetSessions = sessions.where((s) {
        final title = (s['title'] as String? ?? '').toLowerCase();
        return title.contains(_searchQuery.toLowerCase());
      }).toList();
    }

    final liveSessions = showAll
        ? targetSessions.where((s) => s['state'] == 'active').toList()
        : <dynamic>[];
    final draftSessions = showAll
        ? targetSessions
              .where((s) => s['state'] != 'active' && s['state'] != 'ended')
              .toList()
        : <dynamic>[];
    final completedSessions = targetSessions
        .where((s) => s['state'] == 'ended')
        .toList();

    if (targetSessions.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                showAll ? 'All Sessions' : 'Recent Sessions',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : AppColors.textPrimaryLight,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Column(
                children: [
                  Icon(
                    Icons.event_busy_rounded,
                    size: 48,
                    color: Colors.grey.withValues(alpha: 0.4),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _searchQuery.isNotEmpty
                        ? 'No matches found'
                        : 'No sessions yet',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: Colors.grey,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              showAll ? 'All Sessions' : 'Recent Sessions',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : AppColors.textPrimaryLight,
                letterSpacing: -0.5,
              ),
            ),
            if (!showAll)
              TextButton(
                onPressed: () {
                  setState(() {
                    _currentTab = 1;
                  });
                },
                child: const Text(
                  'View All',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (liveSessions.isNotEmpty) ...[
          _buildSessionGroup(
            title: 'Live Sessions',
            count: liveSessions.length,
            sessions: liveSessions,
            headerColor: AppColors.success,
            isDark: isDark,
          ),
          const SizedBox(height: 16),
        ],
        if (draftSessions.isNotEmpty) ...[
          _buildSessionGroup(
            title: 'Draft Sessions',
            count: draftSessions.length,
            sessions: draftSessions,
            headerColor: AppColors.primary,
            isDark: isDark,
          ),
          const SizedBox(height: 16),
        ],
        if (completedSessions.isNotEmpty) ...[
          _buildSessionGroup(
            title: 'Completed Sessions',
            count: completedSessions.length,
            sessions: completedSessions,
            headerColor: Colors.grey,
            isDark: isDark,
            showGroupHeader: showAll,
          ),
        ],
      ],
    );
  }

  Widget _buildSessionGroup({
    required String title,
    required int count,
    required List<dynamic> sessions,
    required Color headerColor,
    required bool isDark,
    bool showGroupHeader = true,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showGroupHeader)
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 14,
                  decoration: BoxDecoration(
                    color: headerColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: isDark
                        ? Colors.white70
                        : AppColors.textSecondaryLight,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$count',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white60 : Colors.grey.shade700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        Container(
          decoration: BoxDecoration(
            color: isDark
                ? AppColors.surfaceDark.withValues(alpha: 0.4)
                : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : const Color(0xFFE2E8F0),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.015),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: sessions.asMap().entries.map((entry) {
              final idx = entry.key;
              final session = entry.value;
              final sessionTitle = session['title'] as String? ?? 'Untitled';
              final createdAt = session['created_at'] as String?;
              final pCount = session['participant_count'] as int? ?? 0;
              final state = session['state'] as String? ?? 'draft';
              final isLive = state == 'active';

              final tile = Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    final sessionId = session['id']?.toString();
                    if (sessionId != null && sessionId.isNotEmpty) {
                      if (isLive) {
                        context.push('/live/$sessionId');
                      } else {
                        context.push('/analytics/$sessionId');
                      }
                    }
                  },
                  borderRadius: BorderRadius.vertical(
                    top: idx == 0 ? const Radius.circular(16) : Radius.zero,
                    bottom: idx == sessions.length - 1
                        ? const Radius.circular(16)
                        : Radius.zero,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isLive
                                ? AppColors.primary.withValues(alpha: 0.08)
                                : AppColors.primary.withValues(alpha: 0.04),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            isLive
                                ? Icons.sensors_rounded
                                : Icons.forum_rounded,
                            color: isLive
                                ? AppColors.primary
                                : AppColors.primary.withValues(alpha: 0.6),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                sessionTitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                  color: isDark
                                      ? Colors.white
                                      : AppColors.textPrimaryLight,
                                  letterSpacing: -0.3,
                                ),
                              ),
                              const SizedBox(height: 4),
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                physics: const BouncingScrollPhysics(),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.calendar_today_outlined,
                                      size: 11,
                                      color: isDark
                                          ? Colors.white38
                                          : Colors.grey.shade500,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      _formatDate(createdAt),
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: isDark
                                            ? Colors.white38
                                            : Colors.grey.shade500,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      '•',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: isDark
                                            ? Colors.white38
                                            : Colors.grey.shade400,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Icon(
                                      Icons.people_outline_rounded,
                                      size: 13,
                                      color: isDark
                                          ? Colors.white38
                                          : Colors.grey.shade500,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '$pCount',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: isDark
                                            ? Colors.white38
                                            : Colors.grey.shade500,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          visualDensity: VisualDensity.compact,
                          icon: Icon(
                            Icons.more_vert_rounded,
                            color: isDark
                                ? Colors.white38
                                : Colors.grey.shade500,
                            size: 20,
                          ),
                          onPressed: () => _showSessionMenu(context, session),
                        ),
                      ],
                    ),
                  ),
                ),
              );

              if (idx < sessions.length - 1) {
                return Column(
                  children: [
                    tile,
                    Divider(
                      height: 1,
                      thickness: 1,
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.06)
                          : const Color(0xFFF1F5F9),
                    ),
                  ],
                );
              }
              return tile;
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildHomeTab(Map<String, dynamic>? stats, List<dynamic> sessions) {
    return RefreshIndicator(
      onRefresh: () async {
        context.read<SessionBloc>().add(LoadSessions());
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 36),
        child:
            Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 16),
                    _buildQuickActionCards(),
                    const SizedBox(height: 20),
                    _buildOverviewSection(stats, sessions),
                    const SizedBox(height: 20),
                    _buildRecentSessionsSection(sessions),
                  ],
                )
                .animate()
                .fade(duration: 400.ms)
                .slideY(begin: 0.05, end: 0, curve: Curves.easeOutCubic),
      ),
    );
  }

  Widget _buildSessionsTab(List<dynamic> sessions) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return RefreshIndicator(
      onRefresh: () async {
        context.read<SessionBloc>().add(LoadSessions());
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 36),
        child:
            Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'My Sessions',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: isDark
                            ? Colors.white
                            : AppColors.textPrimaryLight,
                        letterSpacing: -0.8,
                      ),
                    ),
                    const SizedBox(height: 16),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      height: 48,
                      decoration: BoxDecoration(
                        color: isDark
                            ? (_searchFocusNode.hasFocus
                                  ? Colors.white.withValues(alpha: 0.07)
                                  : Colors.white.withValues(alpha: 0.04))
                            : (_searchFocusNode.hasFocus
                                  ? const Color(0xFFF8FAFC)
                                  : const Color(0xFFF1F5F9)),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: _searchFocusNode.hasFocus
                              ? AppColors.primary.withValues(alpha: 0.45)
                              : (isDark
                                    ? Colors.white.withValues(alpha: 0.08)
                                    : const Color(0xFFE2E8F0)),
                          width: 1.2,
                        ),
                        boxShadow: _searchFocusNode.hasFocus
                            ? [
                                BoxShadow(
                                  color: AppColors.primary.withValues(
                                    alpha: 0.06,
                                  ),
                                  blurRadius: 8,
                                  spreadRadius: 1,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : [],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: TextField(
                          controller: _searchController,
                          focusNode: _searchFocusNode,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: isDark
                                ? Colors.white
                                : AppColors.textPrimaryLight,
                          ),
                          onChanged: (val) {
                            setState(() {
                              _searchQuery = val;
                            });
                          },
                          decoration: InputDecoration(
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 13,
                            ),
                            hintText: 'Search sessions by title...',
                            hintStyle: TextStyle(
                              fontSize: 14,
                              color: isDark
                                  ? Colors.white38
                                  : Colors.grey.shade400,
                            ),
                            prefixIcon: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 200),
                              child: Icon(
                                Icons.search_rounded,
                                key: ValueKey(_searchFocusNode.hasFocus),
                                size: 20,
                                color: _searchFocusNode.hasFocus
                                    ? AppColors.primary
                                    : (isDark
                                          ? Colors.white38
                                          : Colors.grey.shade500),
                              ),
                            ),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    icon: Icon(
                                      Icons.clear_rounded,
                                      size: 18,
                                      color: isDark
                                          ? Colors.white38
                                          : Colors.grey.shade500,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _searchQuery = '';
                                        _searchController.clear();
                                      });
                                    },
                                  )
                                : null,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                          ),
                        ),
                      ),
                    ),
                    if (_searchQuery.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.filter_list_rounded,
                              size: 14,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Filtering by: "$_searchQuery"',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isDark
                                    ? Colors.white70
                                    : AppColors.textSecondaryLight,
                              ),
                            ),
                            const Spacer(),
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  _searchQuery = '';
                                  _searchController.clear();
                                });
                              },
                              child: const Text(
                                'Clear filter',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    _buildRecentSessionsSection(sessions),
                  ],
                )
                .animate()
                .fade(duration: 400.ms)
                .slideY(begin: 0.05, end: 0, curve: Curves.easeOutCubic),
      ),
    );
  }

  Widget _buildAnalyticsTab(
    Map<String, dynamic>? stats,
    List<dynamic> sessions,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final totalSessions = stats?['totalSessions'] ?? sessions.length;
    final totalParticipants =
        stats?['totalParticipants'] ??
        sessions.fold<int>(
          0,
          (sum, s) => sum + (s['participant_count'] as int? ?? 0),
        );
    final totalResponses = stats?['totalResponses'] ?? 0;

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 36),
      child:
          Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Host Reports',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: isDark ? Colors.white : AppColors.textPrimaryLight,
                      letterSpacing: -0.8,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'View aggregate performance across all sessions you have hosted.',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: _buildReportCard(
                          label: 'Avg Participants',
                          value: totalSessions > 0
                              ? (totalParticipants / totalSessions)
                                    .toStringAsFixed(1)
                              : '0',
                          icon: Icons.group_rounded,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildReportCard(
                          label: 'Avg Responses',
                          value: totalSessions > 0
                              ? (totalResponses / totalSessions)
                                    .toStringAsFixed(1)
                              : '0',
                          icon: Icons.poll_rounded,
                          color: AppColors.secondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Detailed Session Analytics',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : AppColors.textPrimaryLight,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (sessions.isEmpty)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 36),
                        child: Text(
                          'Create a session to gather report details',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    )
                  else
                    ...sessions.map((s) {
                      final id = s['id'] as String? ?? '';
                      final title = s['title'] as String? ?? 'Untitled';
                      final participants = s['participant_count'] as int? ?? 0;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppColors.surfaceDark.withValues(alpha: 0.4)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.08)
                                : const Color(0xFFE2E8F0),
                          ),
                        ),
                        child: ListTile(
                          title: Text(
                            title,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            '$participants participants joined',
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 12,
                            ),
                          ),
                          trailing: Container(
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.08),
                              shape: BoxShape.circle,
                            ),
                            child: IconButton(
                              icon: const Icon(
                                Icons.arrow_forward_rounded,
                                color: AppColors.primary,
                                size: 18,
                              ),
                              onPressed: () => context.push('/analytics/$id'),
                            ),
                          ),
                        ),
                      );
                    }),
                ],
              )
              .animate()
              .fade(duration: 400.ms)
              .slideY(begin: 0.05, end: 0, curve: Curves.easeOutCubic),
    );
  }

  Widget _buildReportCard({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.surfaceDark.withValues(alpha: 0.4)
            : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : AppColors.textPrimaryLight,
                  letterSpacing: -1.0,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.grey,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileTab() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final initials = _hostName.isNotEmpty
        ? _hostName.split(' ').map((e) => e[0]).take(2).join().toUpperCase()
        : 'A';

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
      child:
          Column(
                children: [
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.primary, width: 2),
                      ),
                      child: CircleAvatar(
                        radius: 48,
                        backgroundColor: AppColors.primary.withValues(
                          alpha: 0.1,
                        ),
                        child: Text(
                          initials,
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            color: AppColors.primary,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    _hostName,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: isDark ? Colors.white : AppColors.textPrimaryLight,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _hostEmail,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.grey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 36),
                  const Divider(),
                  const SizedBox(height: 16),
                  _buildProfileItem(
                    icon: Icons.account_circle_outlined,
                    title: 'Account Settings',
                    onTap: () {},
                  ),
                  _buildProfileItem(
                    icon: Icons.lock_outline_rounded,
                    title: 'Security',
                    onTap: () {},
                  ),
                  _buildProfileItem(
                    icon: Icons.help_outline_rounded,
                    title: 'Help & FAQ',
                    onTap: () {},
                  ),
                  const SizedBox(height: 40),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.error,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 36,
                        vertical: 16,
                      ),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: () {
                      context.read<AuthBloc>().add(LogoutRequested());
                      context.go('/');
                    },
                    icon: const Icon(Icons.logout_rounded, size: 18),
                    label: const Text(
                      'Log Out',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              )
              .animate()
              .fade(duration: 400.ms)
              .slideY(begin: 0.05, end: 0, curve: Curves.easeOutCubic),
    );
  }

  Widget _buildProfileItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ListTile(
      leading: Icon(icon, color: AppColors.primary),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: isDark ? Colors.white : AppColors.textPrimaryLight,
        ),
      ),
      trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey),
      onTap: onTap,
    );
  }

  Widget _buildTabBody(Map<String, dynamic>? stats, List<dynamic> sessions) {
    switch (_currentTab ?? 0) {
      case 0:
        return _buildHomeTab(stats, sessions);
      case 1:
        return _buildSessionsTab(sessions);
      case 2:
        return _buildAnalyticsTab(stats, sessions);
      case 3:
        return _buildProfileTab();
      default:
        return _buildHomeTab(stats, sessions);
    }
  }

  Widget _buildOfflineBanner(BuildContext context, String? message) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFFEF2F2),
        border: Border(
          bottom: BorderSide(
            color: isDark
                ? Colors.redAccent.withValues(alpha: 0.3)
                : const Color(0xFFFCA5A5),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.redAccent.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.wifi_off_rounded,
              color: Colors.redAccent,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Server Offline Mode',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF991B1B),
                  ),
                ),
                Text(
                  message ??
                      'Unable to connect to server. Displaying offline data.',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.white70 : const Color(0xFFB91C1C),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          TextButton.icon(
            style: TextButton.styleFrom(
              backgroundColor: AppColors.primary.withValues(alpha: 0.1),
              foregroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            onPressed: () {
              context.read<SessionBloc>().add(LoadSessions());
            },
            icon: const Icon(Icons.refresh_rounded, size: 14),
            label: const Text(
              'Retry',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyStateView(bool isDark) {
    return RefreshIndicator(
      onRefresh: () async {
        context.read<SessionBloc>().add(LoadSessions());
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(),
            const SizedBox(height: 60),
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.event_busy_rounded,
                    size: 72,
                    color: Colors.grey.withValues(alpha: 0.3),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'No sessions created yet',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Create a session to engage your audience.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                    ),
                  ),
                  const SizedBox(height: 28),
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppSizes.radiusPill),
                      gradient: const LinearGradient(
                        colors: AppColors.primaryGradient,
                      ),
                    ),
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 16,
                        ),
                      ),
                      onPressed: () => context.push('/session/create'),
                      icon: const Icon(Icons.add_rounded),
                      label: const Text(
                        'Create Session',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
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
      backgroundColor: isDark
          ? AppColors.backgroundDark
          : const Color(0xFFF8FAFC),
      body: SafeArea(
        child: BlocBuilder<SessionBloc, SessionState>(
          builder: (context, state) {
            List<Map<String, dynamic>> sessions = _lastSessions;
            Map<String, dynamic>? stats = _lastStats;
            bool isOffline = false;
            String? errorMsg;

            if (state is SessionLoading && _lastSessions.isEmpty) {
              return const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              );
            }

            if (state is SessionsLoaded) {
              _lastSessions = state.sessions;
              if (state.stats != null) {
                _lastStats = state.stats;
              }
              sessions = _lastSessions;
              stats = _lastStats;
              isOffline = state.isOffline;
              errorMsg = state.errorMessage;
            } else if (state is SessionFailure) {
              isOffline = true;
              errorMsg = state.message;
            }

            return Column(
              children: [
                if (isOffline) _buildOfflineBanner(context, errorMsg),
                Expanded(
                  child: (sessions.isEmpty && (_currentTab ?? 0) == 0)
                      ? _buildEmptyStateView(isDark)
                      : _buildTabBody(stats, sessions),
                ),
              ],
            );
          },
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : const Color(0xFFE2E8F0),
              width: 1,
            ),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentTab ?? 0,
          onTap: (index) {
            setState(() {
              _currentTab = index;
            });
          },
          type: BottomNavigationBarType.fixed,
          selectedItemColor: AppColors.primary,
          unselectedItemColor: Colors.grey,
          elevation: 0,
          backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
          selectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 11,
          ),
          unselectedLabelStyle: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home_rounded),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.layers_outlined),
              activeIcon: Icon(Icons.layers_rounded),
              label: 'Sessions',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.analytics_outlined),
              activeIcon: Icon(Icons.analytics_rounded),
              label: 'Analytics',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline_rounded),
              activeIcon: Icon(Icons.person_rounded),
              label: 'Profile',
            ),
          ],
        ),
      ),
      floatingActionButton: (_currentTab ?? 0) == 1
          ? Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(15),
                gradient: const LinearGradient(
                  colors: AppColors.primaryGradient,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.3),
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
                label: const Text(
                  'Create Room',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            )
          : null,
    );
  }
}

class _PulseDot extends StatefulWidget {
  const _PulseDot();

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
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
                color: AppColors.success.withValues(
                  alpha: 0.4 * _ctrl.value + 0.1,
                ),
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

class SparklinePainter extends CustomPainter {
  final List<double> data;
  final Color color;

  SparklinePainter(this.data, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final path = Path();
    final fillPath = Path();

    final double stepX = size.width / (data.length - 1);

    // Find min and max to scale
    double maxVal = data.reduce((a, b) => a > b ? a : b);
    double minVal = data.reduce((a, b) => a < b ? a : b);
    if (maxVal == minVal) {
      maxVal += 1;
      minVal -= 1;
    }
    final double range = maxVal - minVal;

    double getY(double val) {
      return size.height - ((val - minVal) / range) * size.height;
    }

    path.moveTo(0, getY(data[0]));
    fillPath.moveTo(0, size.height);
    fillPath.lineTo(0, getY(data[0]));

    for (int i = 0; i < data.length - 1; i++) {
      final x1 = i * stepX;
      final y1 = getY(data[i]);
      final x2 = (i + 1) * stepX;
      final y2 = getY(data[i + 1]);

      final cx = (x1 + x2) / 2;

      path.cubicTo(cx, y1, cx, y2, x2, y2);
      fillPath.cubicTo(cx, y1, cx, y2, x2, y2);
    }

    fillPath.lineTo(size.width, size.height);
    fillPath.close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        colors: [color.withValues(alpha: 0.25), color.withValues(alpha: 0.0)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;

    canvas.drawPath(fillPath, fillPaint);

    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(covariant SparklinePainter oldDelegate) =>
      oldDelegate.data != data || oldDelegate.color != color;
}
