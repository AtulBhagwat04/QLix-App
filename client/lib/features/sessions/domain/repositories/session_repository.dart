abstract class SessionRepository {
  Future<List<Map<String, dynamic>>> getSessions();
  Future<Map<String, dynamic>> createSession(String title, String description, Map<String, dynamic> settings);
  Future<Map<String, dynamic>> getSessionDetails(String sessionId);
  Future<Map<String, dynamic>> updateSession(String sessionId, Map<String, dynamic> body);
  Future<void> deleteSession(String sessionId);
  Future<Map<String, dynamic>> joinSessionByCode(String accessCode, String deviceId, String? name, bool isAnonymous);
}
