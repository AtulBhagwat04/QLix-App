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

// BLoCs
import '../../../features/auth/presentation/blocs/auth_bloc.dart';
import '../../../features/sessions/presentation/blocs/session_bloc.dart';

final sl = GetIt.instance;

Future<void> initDI() async {
  // 1. Storage Services
  final secureStorage = SecureStorageService();
  sl.registerSingleton<SecureStorageService>(secureStorage);

  final cacheManager = CacheManager();
  await cacheManager.init();
  sl.registerSingleton<CacheManager>(cacheManager);

  // 2. Network Client Services
  final apiClient = ApiClient(secureStorage);
  sl.registerSingleton<ApiClient>(apiClient);

  final socketClient = SocketClient();
  sl.registerSingleton<SocketClient>(socketClient);

  // 3. Repositories
  sl.registerLazySingleton<AuthRepository>(() => AuthRepositoryImpl(sl(), sl()));
  sl.registerLazySingleton<SessionRepository>(() => SessionRepositoryImpl(sl()));
  sl.registerLazySingleton<PollRepository>(() => PollRepositoryImpl(sl()));
  sl.registerLazySingleton<QaRepository>(() => QaRepositoryImpl(sl()));
  sl.registerLazySingleton<QuizRepository>(() => QuizRepositoryImpl(sl()));

  // 4. State Management (BLoCs)
  sl.registerFactory<AuthBloc>(() => AuthBloc(sl()));
  sl.registerFactory<SessionBloc>(() => SessionBloc(sl()));
}
