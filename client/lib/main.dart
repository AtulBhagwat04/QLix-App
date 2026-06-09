import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'core/di/injection_container.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/blocs/auth_bloc.dart';
import 'features/sessions/presentation/blocs/session_bloc.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Initialize dependency injection composition root
  await initDI();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>(
          create: (context) => sl<AuthBloc>()..add(AppStarted()),
        ),
        BlocProvider<SessionBloc>(create: (context) => sl<SessionBloc>()),
      ],
      child: MaterialApp.router(
        title: 'QLix engagement platform',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.light, // Defaulting to fresh light mode
        routerConfig: appRouter,
      ),
    );
  }
}
