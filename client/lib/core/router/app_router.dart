import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../di/injection_container.dart';
import '../storage/secure_storage.dart';

// Import Screens (we will create these next)
import '../../../features/auth/presentation/screens/login_screen.dart';
import '../../../features/auth/presentation/screens/signup_screen.dart';
import '../../../features/auth/presentation/screens/splash_screen.dart';
import '../../../features/auth/presentation/screens/onboarding_screen.dart';
import '../../../features/sessions/presentation/screens/dashboard_screen.dart';
import '../../../features/sessions/presentation/screens/create_session_screen.dart';
import '../../../features/sessions/presentation/screens/live_control_screen.dart';
import '../../../features/polls/presentation/screens/participant_workspace_screen.dart';
import '../../../features/presenter/presentation/screens/presenter_mode_screen.dart';
import '../../../features/analytics/presentation/screens/analytics_dashboard_screen.dart';

import '../../../features/sessions/presentation/screens/join_screen.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/splash',
  redirect: (BuildContext context, GoRouterState state) async {
    final secureStorage = sl<SecureStorageService>();
    final path = state.uri.path;

    // Temporarily disable redirects for onboarding during design phase
    if (path == '/onboarding') {
      return null;
    }

    // Check if user has seen onboarding. If not, redirect to onboarding.
    final hasSeenOnboarding = await secureStorage.getHasSeenOnboarding();
    if (!hasSeenOnboarding && path != '/onboarding' && path != '/splash') {
      return '/onboarding';
    }

    final token = await secureStorage.getAccessToken();
    final isLoggedIn = token != null;

    // List of routes that require Host Authentication
    final hostOnlyRoutes = [
      '/dashboard',
      '/session/create',
      '/session/control',
      '/analytics',
    ];

    final isHostRoute = hostOnlyRoutes.any((r) => path.startsWith(r));

    if (isHostRoute && !isLoggedIn) {
      return '/login';
    }

    if (isLoggedIn && (path == '/login' || path == '/signup' || path == '/onboarding')) {
      return '/dashboard';
    }

    return null;
  },
  routes: [
    GoRoute(
      path: '/splash',
      builder: (context, state) => const HostSplashWidget(),
    ),
    GoRoute(
      path: '/onboarding',
      builder: (context, state) => const OnboardingScreen(),
    ),
    GoRoute(
      path: '/',
      builder: (context, state) => const ParticipantJoinScreen(),
    ),
    GoRoute(
      path: '/login',
      builder: (context, state) => const HostLoginScreen(),
    ),
    GoRoute(
      path: '/signup',
      builder: (context, state) => const HostSignupScreen(),
    ),
    GoRoute(
      path: '/dashboard',
      builder: (context, state) => const HostDashboardScreen(),
    ),
    GoRoute(
      path: '/session/create',
      builder: (context, state) => const CreateSessionScreen(),
    ),
    GoRoute(
      path: '/session/control/:id',
      builder: (context, state) {
        final sessionId = state.pathParameters['id']!;
        return HostLiveControlScreen(sessionId: sessionId);
      },
    ),
    GoRoute(
      path: '/session/:code',
      builder: (context, state) {
        final accessCode = state.pathParameters['code']!;
        return ParticipantWorkspaceScreen(accessCode: accessCode);
      },
    ),
    GoRoute(
      path: '/presenter/:code',
      builder: (context, state) {
        final accessCode = state.pathParameters['code']!;
        return PresenterModeScreen(accessCode: accessCode);
      },
    ),
    GoRoute(
      path: '/analytics/:id',
      builder: (context, state) {
        final sessionId = state.pathParameters['id']!;
        return AnalyticsDashboardScreen(sessionId: sessionId);
      },
    ),
  ],
);
