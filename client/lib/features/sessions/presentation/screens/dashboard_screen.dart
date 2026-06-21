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

  @override
  void initState() {
    super.initState();
    _loadHostProfile();
    context.read<SessionBloc>().add(LoadSessions());
  }

  @override
  void dispose() {
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
    Share.share('Join my QLix interactive session using code: $code\nOr join online at: http://localhost:3000/session/$code');
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final date = DateTime.parse(dateStr).toLocal();
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
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
                                color: isDark ? Colors.white : AppColors.textPrimaryLight,
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
                    color: isDark ? Colors.white70 : AppColors.textSecondaryLight,
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
                color: color.withOpacity(0.1),
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
                      color: isDark ? Colors.white54 : AppColors.textSecondaryLight,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, size: 20, color: isDark ? Colors.white24 : Colors.black26),
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
  }

  Widget _buildLogoIcon() {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: AppColors.primaryGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Center(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(width: 4, height: 14, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(1.5))),
            const SizedBox(width: 3),
            Container(width: 4, height: 22, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(1.5))),
            const SizedBox(width: 3),
            Container(width: 4, height: 16, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(1.5))),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        _buildLogoIcon(),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hello, $_hostName! 👋',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : AppColors.textPrimaryLight,
                  letterSpacing: -0.8,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Ready to create engaging sessions?',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                ),
              ),
            ],
          ),
        ),
        Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withOpacity(0.05) : const Color(0xFFF1F5F9),
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
              right: 2,
              top: 2,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: AppColors.accent,
                  shape: BoxShape.circle,
                ),
                child: const Text(
                  '3',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
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
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark.withOpacity(0.4) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.08) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
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
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.add_rounded,
                        color: AppColors.primary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Create Session',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                              color: isDark ? Colors.white : AppColors.textPrimaryLight,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 3),
                          const Text(
                            'Start a live poll or quiz',
                            style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.w500),
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
            color: isDark ? Colors.white.withOpacity(0.08) : const Color(0xFFE2E8F0),
          ),
          Expanded(
            child: InkWell(
              onTap: () => context.push('/'),
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.secondary.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.login_rounded,
                        color: AppColors.secondary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Join Session',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                              color: isDark ? Colors.white : AppColors.textPrimaryLight,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 3),
                          const Text(
                            'Enter code to join',
                            style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.w500),
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

  Widget _buildOverviewSection(Map<String, dynamic>? stats, List<dynamic> sessions) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final totalSessions = stats?['totalSessions'] ?? sessions.length;
    final totalParticipants = stats?['totalParticipants'] ?? sessions.fold<int>(0, (sum, s) => sum + (s['participant_count'] as int? ?? 0));
    final totalResponses = stats?['totalResponses'] ?? 0;
    final totalQuizzes = stats?['totalQuizzes'] ?? sessions.fold<int>(0, (sum, s) => sum + (s['poll_count'] as int? ?? 0));

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
                    const SnackBar(content: Text('No sessions available to view analytics')),
                  );
                }
              },
              child: const Row(
                children: [
                  Text('View Analytics', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                  SizedBox(width: 4),
                  Icon(Icons.arrow_forward_rounded, size: 14),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: [
              _buildOverviewCard(
                value: '$totalSessions',
                label: 'Sessions',
                sublabel: 'Total sessions',
                icon: Icons.meeting_room_outlined,
                color: AppColors.primary,
              ),
              const SizedBox(width: 12),
              _buildOverviewCard(
                value: '$totalParticipants',
                label: 'Participants',
                sublabel: 'Total participants',
                icon: Icons.people_outline_rounded,
                color: AppColors.success,
              ),
              const SizedBox(width: 12),
              _buildOverviewCard(
                value: '$totalResponses',
                label: 'Responses',
                sublabel: 'Total responses',
                icon: Icons.insert_comment_outlined,
                color: AppColors.warning,
              ),
              const SizedBox(width: 12),
              _buildOverviewCard(
                value: '$totalQuizzes',
                label: 'Quizzes',
                sublabel: 'Total quizzes',
                icon: Icons.emoji_events_outlined,
                color: AppColors.secondary,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOverviewCard({
    required String value,
    required String label,
    required String sublabel,
    required IconData icon,
    required Color color,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: 130,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark.withOpacity(0.4) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.08) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.01),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 18),
          Text(
            value,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : AppColors.textPrimaryLight,
              letterSpacing: -1.0,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white70 : AppColors.textPrimaryLight,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            sublabel,
            style: const TextStyle(
              fontSize: 10,
              color: Colors.grey,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentSessionsSection(List<dynamic> sessions) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final bool showAll = (_currentTab ?? 0) == 1;
    List<dynamic> displaySessions = showAll ? sessions : sessions.take(3).toList();

    if (_searchQuery.isNotEmpty && showAll) {
      displaySessions = sessions.where((s) {
        final title = (s['title'] as String? ?? '').toLowerCase();
        return title.contains(_searchQuery.toLowerCase());
      }).toList();
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
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : AppColors.textPrimaryLight,
                letterSpacing: -0.3,
              ),
            ),
            if (!showAll)
              TextButton(
                onPressed: () {
                  setState(() {
                    _currentTab = 1;
                  });
                },
                child: const Text('View All', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (displaySessions.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Column(
                children: [
                  Icon(Icons.event_busy_rounded, size: 48, color: Colors.grey.withOpacity(0.4)),
                  const SizedBox(height: 12),
                  Text(
                    _searchQuery.isNotEmpty ? 'No matches found' : 'No sessions yet',
                    style: const TextStyle(fontWeight: FontWeight.w800, color: Colors.grey, fontSize: 14),
                  ),
                ],
              ),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: displaySessions.length,
            itemBuilder: (context, index) {
              final session = displaySessions[index];
              final code = session['access_code'] as String? ?? '';
              final title = session['title'] as String? ?? 'Untitled';
              final createdAt = session['created_at'] as String?;
              final pCount = session['participant_count'] as int? ?? 0;
              final state = session['state'] as String? ?? 'draft';

              Color statusBg;
              Color statusText;
              String statusLabel = 'Draft';
              bool isLive = false;

              switch (state) {
                case 'active':
                  statusBg = const Color(0xFFD1FAE5); // Emerald-100
                  statusText = const Color(0xFF065F46); // Emerald-800
                  statusLabel = 'Live';
                  isLive = true;
                  break;
                case 'ended':
                  statusBg = const Color(0xFFDBEAFE); // Blue-100
                  statusText = const Color(0xFF1E40AF); // Blue-800
                  statusLabel = 'Completed';
                  break;
                default:
                  statusBg = const Color(0xFFF3F4F6); // Grey-100
                  statusText = const Color(0xFF4B5563); // Grey-600
                  statusLabel = 'Draft';
              }

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.surfaceDark.withOpacity(0.4) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? Colors.white.withOpacity(0.08) : const Color(0xFFE2E8F0),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.015),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  leading: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isLive ? AppColors.primary.withOpacity(0.08) : AppColors.primary.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      isLive ? Icons.sensors_rounded : Icons.forum_rounded,
                      color: isLive ? AppColors.primary : AppColors.primary.withOpacity(0.6),
                      size: 22,
                    ),
                  ),
                  title: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: isDark ? Colors.white : AppColors.textPrimaryLight,
                      letterSpacing: -0.3,
                    ),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Created on ${_formatDate(createdAt)} • $pCount participants',
                      style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w500),
                    ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: statusBg,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isLive) ...[
                              const _PulseDot(),
                              const SizedBox(width: 6),
                            ],
                            Text(
                              statusLabel,
                              style: TextStyle(
                                color: statusText,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.more_vert_rounded, color: Colors.grey),
                        onPressed: () => _showSessionMenu(context, session),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildQuickActionsGrid() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Quick Actions',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: isDark ? Colors.white : AppColors.textPrimaryLight,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 4,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.0,
          children: [
            _buildGridActionCard(
              icon: Icons.layers_rounded,
              color: AppColors.primary,
              label: 'My Sessions',
              onTap: () {
                setState(() {
                  _currentTab = 1;
                });
              },
            ),
            _buildGridActionCard(
              icon: Icons.people_rounded,
              color: AppColors.success,
              label: 'Participants',
              onTap: () {
                _showParticipantsOverview();
              },
            ),
            _buildGridActionCard(
              icon: Icons.pie_chart_rounded,
              color: AppColors.secondary,
              label: 'Reports',
              onTap: () {
                setState(() {
                  _currentTab = 2;
                });
              },
            ),
            _buildGridActionCard(
              icon: Icons.settings_rounded,
              color: AppColors.warning,
              label: 'Settings',
              onTap: () {
                _showSettingsDialog();
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildGridActionCard({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark.withOpacity(0.4) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? Colors.white.withOpacity(0.08) : const Color(0xFFE2E8F0),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.01),
              blurRadius: 10,
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white70 : AppColors.textPrimaryLight,
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showParticipantsOverview() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      elevation: 0,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return AppDecoration.glassWrapper(
          context: ctx,
          borderRadius: 24,
          blur: 24,
          opacity: isDark ? 0.85 : 0.95,
          child: Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'All Attendees Info',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : AppColors.textPrimaryLight,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(),
                const SizedBox(height: 16),
                const Text(
                  'This section aggregates all participants that have joined your sessions. Engage with them live by sharing your session code!',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, height: 1.4, color: Colors.grey, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Back to Dashboard'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Dashboard Settings', style: TextStyle(fontWeight: FontWeight.w900)),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.palette_outlined, color: AppColors.primary),
                title: Text('App Theme', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('Set theme preferences'),
              ),
              ListTile(
                leading: Icon(Icons.volume_up_outlined, color: AppColors.secondary),
                title: Text('Sound Effects', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('Tones for votes and triggers'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(),
            const SizedBox(height: 24),
            _buildQuickActionCards(),
            const SizedBox(height: 28),
            _buildOverviewSection(stats, sessions),
            const SizedBox(height: 28),
            _buildRecentSessionsSection(sessions),
            const SizedBox(height: 28),
            _buildQuickActionsGrid(),
          ],
        ).animate().fade(duration: 400.ms).slideY(begin: 0.05, end: 0, curve: Curves.easeOutCubic),
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'My Sessions',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : AppColors.textPrimaryLight,
                letterSpacing: -0.8,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _searchController,
              onChanged: (val) {
                setState(() {
                  _searchQuery = val;
                });
              },
              decoration: InputDecoration(
                hintText: 'Search sessions by title...',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _searchQuery.isNotEmpty 
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded),
                      onPressed: () {
                        setState(() {
                          _searchQuery = '';
                          _searchController.clear();
                        });
                      },
                    )
                  : null,
              ),
            ),
            const SizedBox(height: 20),
            _buildRecentSessionsSection(sessions),
          ],
        ).animate().fade(duration: 400.ms).slideY(begin: 0.05, end: 0, curve: Curves.easeOutCubic),
      ),
    );
  }

  Widget _buildAnalyticsTab(Map<String, dynamic>? stats, List<dynamic> sessions) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final totalSessions = stats?['totalSessions'] ?? sessions.length;
    final totalParticipants = stats?['totalParticipants'] ?? sessions.fold<int>(0, (sum, s) => sum + (s['participant_count'] as int? ?? 0));
    final totalResponses = stats?['totalResponses'] ?? 0;
    
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 36),
      child: Column(
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
            style: TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _buildReportCard(
                  label: 'Avg Participants',
                  value: totalSessions > 0 ? (totalParticipants / totalSessions).toStringAsFixed(1) : '0',
                  icon: Icons.group_rounded,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildReportCard(
                  label: 'Avg Responses',
                  value: totalSessions > 0 ? (totalResponses / totalSessions).toStringAsFixed(1) : '0',
                  icon: Icons.poll_rounded,
                  color: AppColors.secondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            'Detailed Session Analytics',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : AppColors.textPrimaryLight,
            ),
          ),
          const SizedBox(height: 12),
          if (sessions.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 36),
                child: Text('Create a session to gather report details', style: TextStyle(color: Colors.grey)),
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
                  color: isDark ? AppColors.surfaceDark.withOpacity(0.4) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? Colors.white.withOpacity(0.08) : const Color(0xFFE2E8F0),
                  ),
                ),
                child: ListTile(
                  title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('$participants participants joined', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  trailing: Container(
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.08),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_forward_rounded, color: AppColors.primary, size: 18),
                      onPressed: () => context.push('/analytics/$id'),
                    ),
                  ),
                ),
              );
            }),
        ],
      ).animate().fade(duration: 400.ms).slideY(begin: 0.05, end: 0, curve: Curves.easeOutCubic),
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
        color: isDark ? AppColors.surfaceDark.withOpacity(0.4) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.08) : const Color(0xFFE2E8F0),
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
                  color: color.withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileTab() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final initials = _hostName.isNotEmpty ? _hostName.split(' ').map((e) => e[0]).take(2).join().toUpperCase() : 'A';
    
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
      child: Column(
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
                backgroundColor: AppColors.primary.withOpacity(0.1),
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
            style: const TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.w500),
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
              padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 16),
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: () {
              context.read<AuthBloc>().add(LogoutRequested());
              context.go('/');
            },
            icon: const Icon(Icons.logout_rounded, size: 18),
            label: const Text('Log Out', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ).animate().fade(duration: 400.ms).slideY(begin: 0.05, end: 0, curve: Curves.easeOutCubic),
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : const Color(0xFFF8FAFC),
      body: SafeArea(
        child: BlocBuilder<SessionBloc, SessionState>(
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
              final stats = state.stats;

              if (sessions.isEmpty && (_currentTab ?? 0) == 0) {
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
                              Icon(Icons.event_busy_rounded, size: 72, color: Colors.grey.withOpacity(0.3)),
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
                      ],
                    ),
                  ),
                );
              }

              return _buildTabBody(stats, sessions);
            }

            return const SizedBox.shrink();
          },
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: isDark ? Colors.white.withOpacity(0.06) : const Color(0xFFE2E8F0),
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
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11),
          unselectedLabelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
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
      floatingActionButton: (_currentTab ?? 0) == 0 || (_currentTab ?? 0) == 1
          ? Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(15),
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
