import '../../../../core/network/api_client.dart';
import '../../../../core/storage/cache_manager.dart';
import '../../domain/repositories/session_repository.dart';

class SessionRepositoryImpl implements SessionRepository {
  final ApiClient _apiClient;
  final CacheManager _cacheManager;

  SessionRepositoryImpl(this._apiClient, this._cacheManager);

  @override
  Future<List<Map<String, dynamic>>> getSessions() async {
    try {
      final response = await _apiClient.dio.get('/sessions');
      if (response.statusCode == 200 && response.data != null) {
        final list = (response.data['data'] as List)
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList();
        await _cacheManager.saveCachedSessions(list);
        return list;
      }
    } catch (_) {
      final cached = _cacheManager.getCachedSessions();
      if (cached.isNotEmpty) {
        return cached;
      }
      rethrow;
    }
    final cached = _cacheManager.getCachedSessions();
    if (cached.isNotEmpty) {
      return cached;
    }
    throw Exception('Failed to load sessions');
  }

  @override
  Future<Map<String, dynamic>> createSession(
    String title,
    String description,
    Map<String, dynamic> settings,
  ) async {
    final response = await _apiClient.dio.post(
      '/sessions',
      data: {'title': title, 'description': description, 'settings': settings},
    );

    if (response.statusCode == 201 && response.data != null) {
      final newSession = Map<String, dynamic>.from(response.data['data'] as Map);
      // Prepend to cached list
      final cached = _cacheManager.getCachedSessions();
      cached.insert(0, newSession);
      await _cacheManager.saveCachedSessions(cached);
      return newSession;
    }
    throw Exception(response.data?['message'] ?? 'Failed to create session');
  }

  @override
  Future<Map<String, dynamic>> getSessionDetails(String sessionId) async {
    try {
      final response = await _apiClient.dio.get('/sessions/$sessionId');
      if (response.statusCode == 200 && response.data != null) {
        return Map<String, dynamic>.from(response.data['data'] as Map);
      }
    } catch (_) {
      final cached = _cacheManager.getCachedSessions();
      final match = cached.firstWhere(
        (s) => s['id'] == sessionId || s['_id'] == sessionId,
        orElse: () => {},
      );
      if (match.isNotEmpty) return match;
      rethrow;
    }
    final cached = _cacheManager.getCachedSessions();
    final match = cached.firstWhere(
      (s) => s['id'] == sessionId || s['_id'] == sessionId,
      orElse: () => {},
    );
    if (match.isNotEmpty) return match;
    throw Exception('Session not found');
  }

  @override
  Future<Map<String, dynamic>> updateSession(
    String sessionId,
    Map<String, dynamic> body,
  ) async {
    final response = await _apiClient.dio.patch(
      '/sessions/$sessionId',
      data: body,
    );
    if (response.statusCode == 200 && response.data != null) {
      final updated = Map<String, dynamic>.from(response.data['data'] as Map);
      final cached = _cacheManager.getCachedSessions();
      final idx = cached.indexWhere((s) => s['id'] == sessionId || s['_id'] == sessionId);
      if (idx != -1) {
        cached[idx] = updated;
        await _cacheManager.saveCachedSessions(cached);
      }
      return updated;
    }
    throw Exception(response.data?['message'] ?? 'Failed to update session');
  }

  @override
  Future<void> deleteSession(String sessionId) async {
    final response = await _apiClient.dio.delete('/sessions/$sessionId');
    if (response.statusCode != 200) {
      throw Exception(response.data?['message'] ?? 'Failed to delete session');
    }
    final cached = _cacheManager.getCachedSessions();
    cached.removeWhere((s) => s['id'] == sessionId || s['_id'] == sessionId);
    await _cacheManager.saveCachedSessions(cached);
  }

  @override
  Future<Map<String, dynamic>> joinSessionByCode(
    String accessCode,
    String deviceId,
    String? name,
    bool isAnonymous,
  ) async {
    final response = await _apiClient.dio.post(
      '/sessions/join',
      data: {
        'accessCode': accessCode,
        'deviceId': deviceId,
        'name': name,
        'isAnonymous': isAnonymous,
      },
    );

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
    throw Exception(
      response.data?['message'] ?? 'Failed to verify session code',
    );
  }

  @override
  Future<Map<String, dynamic>> getOverviewStats() async {
    try {
      final response = await _apiClient.dio.get('/analytics/overview');
      if (response.statusCode == 200 && response.data != null) {
        final stats = Map<String, dynamic>.from(response.data['data'] as Map);
        await _cacheManager.saveCachedOverviewStats(stats);
        return stats;
      }
    } catch (_) {
      final cached = _cacheManager.getCachedOverviewStats();
      if (cached != null) return cached;
      rethrow;
    }
    final cached = _cacheManager.getCachedOverviewStats();
    if (cached != null) return cached;
    throw Exception(
      'Failed to load overview stats',
    );
  }
}
