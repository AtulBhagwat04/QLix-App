import 'package:get_it/get_it.dart';
import '../storage/secure_storage.dart';
import '../storage/cache_manager.dart';
import '../network/api_client.dart';
import '../network/socket_client.dart';

// Repositories
import '../../../features/auth/domain/repositories/auth_repository.dart';
import '../../../features/auth/data/repositories/auth_repository_impl.dart';
import '../../../features/sessions/domain/repositories/session_repository.dart';
import '../../../features/sessions/data/repositories/session_repository_impl.dart';
import '../../../features/polls/domain/repositories/poll_repository.dart';
import '../../../features/polls/data/repositories/poll_repository_impl.dart';
import '../../../features/qa/domain/repositories/qa_repository.dart';
import '../../../features/qa/data/repositories/qa_repository_impl.dart';
import '../../../features/quiz/domain/repositories/quiz_repository.dart';
import '../../../features/quiz/data/repositories/quiz_repository_impl.dart';
import '../../../features/profile/domain/repositories/profile_repository.dart';
import '../../../features/profile/data/repositories/profile_repository_impl.dart';

// BLoCs & Cubits
import '../../../features/auth/presentation/blocs/auth_bloc.dart';
import '../../../features/sessions/presentation/blocs/session_bloc.dart';
import '../../../features/profile/presentation/blocs/profile_bloc.dart';
import '../../../features/profile/presentation/cubits/theme_cubit.dart';

final sl = GetIt.instance;

Future<void> initDI() async {
  // 1. Storage Services
  if (!sl.isRegistered<SecureStorageService>()) {
    final secureStorage = SecureStorageService();
    sl.registerSingleton<SecureStorageService>(secureStorage);
  }

  if (!sl.isRegistered<CacheManager>()) {
    final cacheManager = CacheManager();
    await cacheManager.init();
    sl.registerSingleton<CacheManager>(cacheManager);
  }

  // 2. Network Client Services
  if (!sl.isRegistered<ApiClient>()) {
    final apiClient = ApiClient(sl());
    sl.registerSingleton<ApiClient>(apiClient);
  }

  if (!sl.isRegistered<SocketClient>()) {
    final socketClient = SocketClient();
    sl.registerSingleton<SocketClient>(socketClient);
  }

  // 3. Repositories
  if (!sl.isRegistered<AuthRepository>()) {
    sl.registerLazySingleton<AuthRepository>(
      () => AuthRepositoryImpl(sl(), sl()),
    );
  }
  if (!sl.isRegistered<SessionRepository>()) {
    sl.registerLazySingleton<SessionRepository>(
      () => SessionRepositoryImpl(sl(), sl()),
    );
  }
  if (!sl.isRegistered<PollRepository>()) {
    sl.registerLazySingleton<PollRepository>(() => PollRepositoryImpl(sl()));
  }
  if (!sl.isRegistered<QaRepository>()) {
    sl.registerLazySingleton<QaRepository>(() => QaRepositoryImpl(sl()));
  }
  if (!sl.isRegistered<QuizRepository>()) {
    sl.registerLazySingleton<QuizRepository>(() => QuizRepositoryImpl(sl()));
  }
  if (!sl.isRegistered<ProfileRepository>()) {
    sl.registerLazySingleton<ProfileRepository>(
      () => ProfileRepositoryImpl(sl(), sl()),
    );
  }

  // 4. State Management (BLoCs & Cubits)
  if (!sl.isRegistered<AuthBloc>()) {
    sl.registerFactory<AuthBloc>(() => AuthBloc(sl()));
  }
  if (!sl.isRegistered<SessionBloc>()) {
    sl.registerFactory<SessionBloc>(() => SessionBloc(sl()));
  }
  if (!sl.isRegistered<ProfileBloc>()) {
    sl.registerFactory<ProfileBloc>(() => ProfileBloc(sl()));
  }
  if (!sl.isRegistered<ThemeCubit>()) {
    sl.registerLazySingleton<ThemeCubit>(() => ThemeCubit(sl()));
  }
}

