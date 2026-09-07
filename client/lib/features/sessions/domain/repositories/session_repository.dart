import '../entities/session.dart';
import '../entities/overview_stats.dart';

abstract class SessionRepository {
  Future<List<Session>> getSessions();
  Future<Session> createSession(
    String title,
    String description,
    Map<String, dynamic> settings,
  );
  Future<Session> getSessionDetails(String sessionId);
  Future<Session> updateSession(
    String sessionId,
    Map<String, dynamic> body,
  );
  Future<void> deleteSession(String sessionId);
  Future<Map<String, dynamic>> joinSessionByCode(
    String accessCode,
    String deviceId,
    String? name,
    bool isAnonymous,
  );
  Future<Session> verifySessionCode(String accessCode);
  Future<OverviewStats> getOverviewStats();
}
