import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/storage/secure_storage.dart';
import '../../domain/entities/session.dart';
import '../../domain/entities/overview_stats.dart';
import '../blocs/session_bloc.dart';
import '../widgets/dashboard_header.dart';
import '../widgets/dashboard_offline_banner.dart';
import '../widgets/home_tab_view.dart';
import '../widgets/sessions_tab_view.dart';
import '../widgets/dashboard_analytics_tab.dart';
import '../widgets/dashboard_profile_tab.dart';

class HostDashboardScreen extends StatefulWidget {
  const HostDashboardScreen({super.key});

  @override
  State<HostDashboardScreen> createState() => _HostDashboardScreenState();
}

class _HostDashboardScreenState extends State<HostDashboardScreen> {
  int _currentTab = 0;
  String _hostName = 'Alex';
  String _hostEmail = 'alex@qlix.com';

  List<Session> _lastSessions = [];
  OverviewStats? _lastStats;

  @override
  void initState() {
    super.initState();
    _loadHostProfile();
    context.read<SessionBloc>().add(LoadSessions());
  }

  Future<void> _loadHostProfile() async {
    try {
      final secureStorage = sl<SecureStorageService>();
      final token = await secureStorage.getAccessToken();
      if (token != null) {
        final payload = _decodeJwt(token);
        if (mounted) {
          setState(() {
            if (payload['name'] != null) {
              _hostName = payload['name'] as String;
            }
            if (payload['email'] != null) {
              _hostEmail = payload['email'] as String;
            }
          });
        }
      }
    } catch (_) {
      // Retain default values
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
            DashboardHeader(hostName: _hostName),
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

  Widget _buildTabBody({
    required List<Session> sessions,
    required OverviewStats? stats,
  }) {
    Future<void> refresh() async {
      context.read<SessionBloc>().add(LoadSessions());
    }

    switch (_currentTab) {
      case 0:
        return HomeTabView(
          hostName: _hostName,
          stats: stats,
          sessions: sessions,
          onRefresh: refresh,
          onViewAllSessions: () => setState(() => _currentTab = 1),
        );
      case 1:
        return SessionsTabView(
          sessions: sessions,
          onRefresh: refresh,
        );
      case 2:
        return DashboardAnalyticsTab(
          stats: stats,
          sessions: sessions,
          onRefresh: refresh,
        );
      case 3:
        return DashboardProfileTab(
          hostName: _hostName,
          hostEmail: _hostEmail,
          stats: stats,
          sessions: sessions,
          onRefresh: refresh,
        );
      default:
        return HomeTabView(
          hostName: _hostName,
          stats: stats,
          sessions: sessions,
          onRefresh: refresh,
          onViewAllSessions: () => setState(() => _currentTab = 1),
        );
    }
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
            List<Session> sessions = _lastSessions;
            OverviewStats? stats = _lastStats;
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
                if (isOffline)
                  DashboardOfflineBanner(
                    message: errorMsg,
                    onRetry: () =>
                        context.read<SessionBloc>().add(LoadSessions()),
                  ),
                Expanded(
                  child: (sessions.isEmpty && _currentTab == 0)
                      ? _buildEmptyStateView(isDark)
                      : _buildTabBody(stats: stats, sessions: sessions),
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
          currentIndex: _currentTab,
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
      floatingActionButton: _currentTab == 1
          ? FloatingActionButton(
              backgroundColor: AppColors.primary,
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              onPressed: () => context.push('/session/create'),
              child: const Icon(
                Icons.add_rounded,
                color: Colors.white,
                size: 28,
              ),
            )
          : null,
    );
  }
}
