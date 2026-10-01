import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'core/di/injection_container.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/storage/cache_manager.dart';
import 'core/storage/secure_storage.dart';
import 'features/auth/presentation/blocs/auth_bloc.dart';
import 'features/sessions/presentation/blocs/session_bloc.dart';
import 'features/profile/domain/repositories/profile_repository.dart';
import 'features/profile/data/repositories/profile_repository_impl.dart';
import 'features/profile/presentation/blocs/profile_bloc.dart';
import 'features/profile/presentation/blocs/profile_event.dart';
import 'features/profile/presentation/cubits/theme_cubit.dart';

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
        BlocProvider<ProfileBloc>(
          create: (context) {
            if (sl.isRegistered<ProfileBloc>()) {
              return sl<ProfileBloc>()..add(LoadProfile());
            }
            final repo = sl.isRegistered<ProfileRepository>()
                ? sl<ProfileRepository>()
                : ProfileRepositoryImpl(
                    sl<SecureStorageService>(),
                    sl<CacheManager>(),
                  );
            return ProfileBloc(repo)..add(LoadProfile());
          },
        ),
        BlocProvider<ThemeCubit>(
          create: (context) {
            if (sl.isRegistered<ThemeCubit>()) {
              return sl<ThemeCubit>();
            }
            return ThemeCubit(sl<CacheManager>());
          },
        ),
      ],
      child: BlocBuilder<ThemeCubit, ThemeMode>(
        builder: (context, themeMode) {
          return MaterialApp.router(
            title: 'QLix engagement platform',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeMode,
            routerConfig: appRouter,
          );
        },
      ),
    );
  }
}
