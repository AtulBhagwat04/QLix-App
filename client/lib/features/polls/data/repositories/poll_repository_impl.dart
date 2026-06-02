import '../../../../core/network/api_client.dart';
import '../../domain/repositories/poll_repository.dart';

class PollRepositoryImpl implements PollRepository {
  final ApiClient _apiClient;

  PollRepositoryImpl(this._apiClient);

  @override
  Future<List<Map<String, dynamic>>> getSessionPolls(String sessionId) async {
    final response = await _apiClient.dio.get('/polls/session/$sessionId');
    if (response.statusCode == 200 && response.data != null) {
      final list = response.data['data'] as List;
      return list.map((item) => Map<String, dynamic>.from(item as Map)).toList();
    }
    throw Exception(response.data?['message'] ?? 'Failed to load polls');
  }

  @override
  Future<Map<String, dynamic>> createPoll({
    required String sessionId,
    required String title,
    required String type,
    Map<String, dynamic>? settings,
    List<Map<String, dynamic>>? options,
  }) async {
    final response = await _apiClient.dio.post('/polls', data: {
      'sessionId': sessionId,
      'title': title,
      'type': type,
      'settings': settings,
      'options': options,
    });

    if (response.statusCode == 201 && response.data != null) {
      return Map<String, dynamic>.from(response.data['data'] as Map);
    }
    throw Exception(response.data?['message'] ?? 'Failed to create poll');
  }

  @override
  Future<Map<String, dynamic>> updatePoll(String pollId, Map<String, dynamic> body) async {
    final response = await _apiClient.dio.patch('/polls/$pollId', data: body);
    if (response.statusCode == 200 && response.data != null) {
      return Map<String, dynamic>.from(response.data['data'] as Map);
    }
    throw Exception(response.data?['message'] ?? 'Failed to update poll');
  }

  @override
  Future<void> deletePoll(String pollId) async {
    final response = await _apiClient.dio.delete('/polls/$pollId');
    if (response.statusCode != 200) {
      throw Exception(response.data?['message'] ?? 'Failed to delete poll');
    }
  }

  @override
  Future<Map<String, dynamic>> getPollResults(String pollId) async {
    final response = await _apiClient.dio.get('/polls/$pollId/results');
    if (response.statusCode == 200 && response.data != null) {
      return Map<String, dynamic>.from(response.data['data'] as Map);
    }
    throw Exception(response.data?['message'] ?? 'Failed to load poll results');
  }
}
