import '../../../../core/network/api_client.dart';
import '../../../../core/storage/cache_manager.dart';
import '../../domain/entities/session.dart';
import '../../domain/entities/overview_stats.dart';
import '../../domain/repositories/session_repository.dart';
import '../models/session_model.dart';
import '../models/overview_stats_model.dart';

class SessionRepositoryImpl implements SessionRepository {
  final ApiClient _apiClient;
  final CacheManager _cacheManager;

  SessionRepositoryImpl(this._apiClient, this._cacheManager);

  @override
  Future<List<Session>> getSessions() async {
    try {
      final response = await _apiClient.dio.get('/sessions');
      if (response.statusCode == 200 && response.data != null) {
        final rawList = response.data['data'] as List;
        final list = rawList
            .map((item) =>
                SessionModel.fromJson(Map<String, dynamic>.from(item as Map)))
            .toList();
        await _cacheManager
            .saveCachedSessions(list.map((s) => s.toJson()).toList());
        return list;
      }
    } catch (_) {
      final cached = _cacheManager.getCachedSessions();
      if (cached.isNotEmpty) {
        return cached.map((item) => SessionModel.fromJson(item)).toList();
      }
      rethrow;
    }
    final cached = _cacheManager.getCachedSessions();
    if (cached.isNotEmpty) {
      return cached.map((item) => SessionModel.fromJson(item)).toList();
    }
    throw Exception('Failed to load sessions');
  }

  @override
  Future<Session> createSession(
    String title,
    String description,
    Map<String, dynamic> settings,
  ) async {
    final response = await _apiClient.dio.post(
      '/sessions',
      data: {'title': title, 'description': description, 'settings': settings},
    );

    if (response.statusCode == 201 && response.data != null) {
      final newSession = SessionModel.fromJson(
        Map<String, dynamic>.from(response.data['data'] as Map),
      );
      // Prepend to cached list
      final cached = _cacheManager.getCachedSessions();
      cached.insert(0, newSession.toJson());
      await _cacheManager.saveCachedSessions(cached);
      return newSession;
    }
    throw Exception(response.data?['message'] ?? 'Failed to create session');
  }

  @override
  Future<Session> getSessionDetails(String sessionId) async {
    try {
      final response = await _apiClient.dio.get('/sessions/$sessionId');
      if (response.statusCode == 200 && response.data != null) {
        return SessionModel.fromJson(
          Map<String, dynamic>.from(response.data['data'] as Map),
        );
      }
    } catch (_) {
      final cached = _cacheManager.getCachedSessions();
      final match = cached.firstWhere(
        (s) => s['id'] == sessionId || s['_id'] == sessionId,
        orElse: () => {},
      );
      if (match.isNotEmpty) return SessionModel.fromJson(match);
      rethrow;
    }
    final cached = _cacheManager.getCachedSessions();
    final match = cached.firstWhere(
      (s) => s['id'] == sessionId || s['_id'] == sessionId,
      orElse: () => {},
    );
    if (match.isNotEmpty) return SessionModel.fromJson(match);
    throw Exception('Session not found');
  }

  @override
  Future<Session> updateSession(
    String sessionId,
    Map<String, dynamic> body,
  ) async {
    final response = await _apiClient.dio.patch(
      '/sessions/$sessionId',
      data: body,
    );
    if (response.statusCode == 200 && response.data != null) {
      final updated = SessionModel.fromJson(
        Map<String, dynamic>.from(response.data['data'] as Map),
      );
      final cached = _cacheManager.getCachedSessions();
      final idx = cached
          .indexWhere((s) => s['id'] == sessionId || s['_id'] == sessionId);
      if (idx != -1) {
        cached[idx] = updated.toJson();
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
      final data = response.data['data'] as Map;
      final sessionModel = SessionModel.fromJson(
        Map<String, dynamic>.from(data['session'] as Map),
      );
      final participant =
          Map<String, dynamic>.from(data['participant'] as Map);
      return {
        'session': sessionModel,
        'participant': participant,
      };
    }
    throw Exception(response.data?['message'] ?? 'Failed to join session');
  }

  @override
  Future<Session> verifySessionCode(String accessCode) async {
    final response = await _apiClient.dio.get('/sessions/verify/$accessCode');
    if (response.statusCode == 200 && response.data != null) {
      return SessionModel.fromJson(
        Map<String, dynamic>.from(response.data['data'] as Map),
      );
    }
    throw Exception(
      response.data?['message'] ?? 'Failed to verify session code',
    );
  }

  @override
  Future<OverviewStats> getOverviewStats() async {
    try {
      final response = await _apiClient.dio.get('/analytics/overview');
      if (response.statusCode == 200 && response.data != null) {
        final stats = OverviewStatsModel.fromJson(
          Map<String, dynamic>.from(response.data['data'] as Map),
        );
        await _cacheManager.saveCachedOverviewStats(stats.toJson());
        return stats;
      }
    } catch (_) {
      final cached = _cacheManager.getCachedOverviewStats();
      if (cached != null) return OverviewStatsModel.fromJson(cached);
      rethrow;
    }
    final cached = _cacheManager.getCachedOverviewStats();
    if (cached != null) return OverviewStatsModel.fromJson(cached);
    throw Exception('Failed to load overview stats');
  }
}
