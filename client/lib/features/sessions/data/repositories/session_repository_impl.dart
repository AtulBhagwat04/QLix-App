import '../../../../core/network/api_client.dart';
import '../../domain/repositories/session_repository.dart';

class SessionRepositoryImpl implements SessionRepository {
  final ApiClient _apiClient;

  SessionRepositoryImpl(this._apiClient);

  @override
  Future<List<Map<String, dynamic>>> getSessions() async {
    final response = await _apiClient.dio.get('/sessions');
    if (response.statusCode == 200 && response.data != null) {
      final list = response.data['data'] as List;
      return list.map((item) => Map<String, dynamic>.from(item as Map)).toList();
    }
    throw Exception(response.data?['message'] ?? 'Failed to load sessions');
  }

  @override
  Future<Map<String, dynamic>> createSession(
    String title,
    String description,
    Map<String, dynamic> settings,
  ) async {
    final response = await _apiClient.dio.post('/sessions', data: {
      'title': title,
      'description': description,
      'settings': settings,
    });

    if (response.statusCode == 201 && response.data != null) {
      return Map<String, dynamic>.from(response.data['data'] as Map);
    }
    throw Exception(response.data?['message'] ?? 'Failed to create session');
  }

  @override
  Future<Map<String, dynamic>> getSessionDetails(String sessionId) async {
    final response = await _apiClient.dio.get('/sessions/$sessionId');
    if (response.statusCode == 200 && response.data != null) {
      return Map<String, dynamic>.from(response.data['data'] as Map);
    }
    throw Exception(response.data?['message'] ?? 'Session not found');
  }

  @override
  Future<Map<String, dynamic>> updateSession(String sessionId, Map<String, dynamic> body) async {
    final response = await _apiClient.dio.patch('/sessions/$sessionId', data: body);
    if (response.statusCode == 200 && response.data != null) {
      return Map<String, dynamic>.from(response.data['data'] as Map);
    }
    throw Exception(response.data?['message'] ?? 'Failed to update session');
  }

  @override
  Future<void> deleteSession(String sessionId) async {
    final response = await _apiClient.dio.delete('/sessions/$sessionId');
    if (response.statusCode != 200) {
      throw Exception(response.data?['message'] ?? 'Failed to delete session');
    }
  }

  @override
  Future<Map<String, dynamic>> joinSessionByCode(
    String accessCode,
    String deviceId,
    String? name,
    bool isAnonymous,
  ) async {
    final response = await _apiClient.dio.post('/sessions/join', data: {
      'accessCode': accessCode,
      'deviceId': deviceId,
      'name': name,
      'isAnonymous': isAnonymous,
    });

    if (response.statusCode == 200 && response.data != null) {
      return Map<String, dynamic>.from(response.data['data'] as Map);
    }
    throw Exception(response.data?['message'] ?? 'Failed to join session');
  }

  @override
  Future<Map<String, dynamic>> verifySessionCode(String accessCode) async {
    final response = await _apiClient.dio.get('/sessions/verify/$accessCode');
    if (response.statusCode == 200 && response.data != null) {
      return Map<String, dynamic>.from(response.data['data'] as Map);
    }
    throw Exception(response.data?['message'] ?? 'Failed to verify session code');
  }

  @override
  Future<Map<String, dynamic>> getOverviewStats() async {
    final response = await _apiClient.dio.get('/analytics/overview');
    if (response.statusCode == 200 && response.data != null) {
      return Map<String, dynamic>.from(response.data['data'] as Map);
    }
    throw Exception(response.data?['message'] ?? 'Failed to load overview stats');
  }
}
