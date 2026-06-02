abstract class AuthRepository {
  Future<void> login(String email, String password);
  Future<void> signup(String email, String password, String fullName);
  Future<void> logout();
  Future<bool> checkAuthStatus();
}
