import 'package:dio/dio.dart';
import '../storage/secure_storage.dart';

class ApiClient {
  late final Dio dio;
  final SecureStorageService _secureStorage;

  static const String defaultBaseUrl = 'https://qlix-app.onrender.com';
  static String get defaultHost => 'qlix-app.onrender.com';

  static String formatApiUrl(String input) {
    var raw = input.trim();
    if (raw.isEmpty) return '$defaultBaseUrl/api';

    // If input already specifies http:// or https://
    if (raw.startsWith('http://') || raw.startsWith('https://')) {
      while (raw.endsWith('/')) {
        raw = raw.substring(0, raw.length - 1);
      }
      if (raw.endsWith('/api')) {
        return raw;
      }
      return '$raw/api';
    }

    // If it's a domain name (e.g. *.onrender.com or custom domain)
    final isDomain = raw.contains('.onrender.com') ||
        (raw.contains('.') &&
            !RegExp(r'^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}').hasMatch(raw) &&
            !raw.contains(':'));

    if (isDomain) {
      while (raw.endsWith('/')) {
        raw = raw.substring(0, raw.length - 1);
      }
      if (raw.endsWith('/api')) {
        return 'https://$raw';
      }
      return 'https://$raw/api';
    }

    // Local IP or host with explicit port
    if (raw.contains(':')) {
      return 'http://$raw/api';
    }

    // Default to port 3000 for local IP addresses
    return 'http://$raw:3000/api';
  }

  static String get baseUrl => '$defaultBaseUrl/api';

  void updateBaseUrl(String newIp) {
    dio.options.baseUrl = formatApiUrl(newIp);
  }

  ApiClient(this._secureStorage) {
    dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _secureStorage.getAccessToken();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
        onError: (DioException error, handler) async {
          if (error.response?.statusCode == 401 &&
              error.requestOptions.path != '/auth/login' &&
              error.requestOptions.path != '/auth/signup') {
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
      ),
    );
  }

  Future<bool> _refreshToken() async {
    final rToken = await _secureStorage.getRefreshToken();
    if (rToken == null) return false;

    // Use a clean Dio instance to avoid interceptor infinite loops
    final cleanDio = Dio(BaseOptions(baseUrl: baseUrl));
    try {
      final response = await cleanDio.post(
        '/auth/refresh',
        data: {'refreshToken': rToken},
      );

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
