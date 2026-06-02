import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:get_it/get_it.dart';
import '../storage/secure_storage.dart';
import '../storage/cache_manager.dart';

class ApiClient {
  late final Dio dio;
  final SecureStorageService _secureStorage;

  static String get baseUrl {
    try {
      final ip = GetIt.instance<CacheManager>().getServerIpOverride();
      if (ip != null && ip.trim().isNotEmpty) {
        return 'http://${ip.trim()}:3000/api';
      }
    } catch (_) {}
    if (kIsWeb) return 'http://localhost:3000/api';
    // Connect to host PC using its local Wi-Fi IP address (enables physical device testing)
    return 'http://10.197.55.64:3000/api';
  }

  void updateBaseUrl(String newIp) {
    dio.options.baseUrl = 'http://$newIp:3000/api';
  }

  ApiClient(this._secureStorage) {
    dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));

    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _secureStorage.getAccessToken();
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
      onError: (DioException error, handler) async {
        if (error.response?.statusCode == 401 && error.requestOptions.path != '/auth/login' && error.requestOptions.path != '/auth/signup') {
          // Token expired, attempt refresh
          final refreshed = await _refreshToken();
          if (refreshed) {
            // Retry request with new token
            final options = error.requestOptions;
            final newToken = await _secureStorage.getAccessToken();
            options.headers['Authorization'] = 'Bearer $newToken';
            
            try {
              final response = await dio.fetch(options);
              return handler.resolve(response);
            } on DioException catch (e) {
              return handler.next(e);
            }
          }
        }
        return handler.next(error);
      },
    ));
  }

  Future<bool> _refreshToken() async {
    final rToken = await _secureStorage.getRefreshToken();
    if (rToken == null) return false;

    // Use a clean Dio instance to avoid interceptor infinite loops
    final cleanDio = Dio(BaseOptions(baseUrl: baseUrl));
    try {
      final response = await cleanDio.post('/auth/refresh', data: {
        'refreshToken': rToken,
      });

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data['data'];
        final newAccessToken = data['accessToken'] as String;
        final newRefreshToken = data['refreshToken'] as String;

        await _secureStorage.saveAccessToken(newAccessToken);
        await _secureStorage.saveRefreshToken(newRefreshToken);
        return true;
      }
    } catch (e) {
      // Refresh token is expired too, wipe tokens to trigger relog
      await _secureStorage.clearAll();
    }
    return false;
  }
}
