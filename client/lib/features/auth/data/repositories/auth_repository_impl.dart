import '../../../../core/network/api_client.dart';
import '../../../../core/storage/secure_storage.dart';
import '../../domain/repositories/auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  final ApiClient _apiClient;
  final SecureStorageService _secureStorage;

  AuthRepositoryImpl(this._apiClient, this._secureStorage);

  @override
  Future<void> login(String email, String password) async {
    final response = await _apiClient.dio.post('/auth/login', data: {
      'email': email,
      'password': password,
    });

    if (response.statusCode == 200 && response.data != null) {
      final data = response.data['data'];
      final accessToken = data['accessToken'] as String;
      final refreshToken = data['refreshToken'] as String;

      await _secureStorage.saveAccessToken(accessToken);
      await _secureStorage.saveRefreshToken(refreshToken);
    } else {
      throw Exception(response.data?['message'] ?? 'Login failed');
    }
  }

  @override
  Future<void> signup(String email, String password, String fullName) async {
    final response = await _apiClient.dio.post('/auth/signup', data: {
      'email': email,
      'password': password,
      'fullName': fullName,
    });

    if (response.statusCode == 201 && response.data != null) {
      final data = response.data['data'];
      final accessToken = data['accessToken'] as String;
      final refreshToken = data['refreshToken'] as String;

      await _secureStorage.saveAccessToken(accessToken);
      await _secureStorage.saveRefreshToken(refreshToken);
    } else {
      throw Exception(response.data?['message'] ?? 'Signup failed');
    }
  }

  @override
  Future<void> logout() async {
    await _secureStorage.clearAll();
  }

  @override
  Future<bool> checkAuthStatus() async {
    final token = await _secureStorage.getAccessToken();
    return token != null;
  }
}
