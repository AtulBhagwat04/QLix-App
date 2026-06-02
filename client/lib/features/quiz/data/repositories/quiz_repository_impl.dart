import '../../../../core/network/api_client.dart';
import '../../domain/repositories/quiz_repository.dart';

class QuizRepositoryImpl implements QuizRepository {
  final ApiClient _apiClient;

  QuizRepositoryImpl(this._apiClient);

  @override
  Future<Map<String, dynamic>> activateQuizQuestion(String sessionId, String pollId, int timeLimit) async {
    final response = await _apiClient.dio.post('/quiz/activate', data: {
      'sessionId': sessionId,
      'pollId': pollId,
      'timeLimit': timeLimit,
    });

    if (response.statusCode == 200 && response.data != null) {
      return Map<String, dynamic>.from(response.data['data'] as Map);
    }
    throw Exception(response.data?['message'] ?? 'Failed to activate quiz question');
  }

  @override
  Future<Map<String, dynamic>> submitQuizAnswer(
    String sessionId,
    String participantId,
    String pollId,
    String optionId,
  ) async {
    final response = await _apiClient.dio.post('/quiz/submit', data: {
      'sessionId': sessionId,
      'participantId': participantId,
      'pollId': pollId,
      'optionId': optionId,
    });

    if (response.statusCode == 200 && response.data != null) {
      return Map<String, dynamic>.from(response.data['data'] as Map);
    }
    throw Exception(response.data?['message'] ?? 'Failed to submit quiz answer');
  }

  @override
  Future<List<Map<String, dynamic>>> getLeaderboard(String sessionId) async {
    final response = await _apiClient.dio.get('/quiz/session/$sessionId/leaderboard');
    if (response.statusCode == 200 && response.data != null) {
      final list = response.data['data'] as List;
      return list.map((item) => Map<String, dynamic>.from(item as Map)).toList();
    }
    throw Exception(response.data?['message'] ?? 'Failed to load leaderboard');
  }

  @override
  Future<void> resetQuiz(String sessionId) async {
    final response = await _apiClient.dio.post('/quiz/session/$sessionId/reset');
    if (response.statusCode != 200) {
      throw Exception(response.data?['message'] ?? 'Failed to reset quiz');
    }
  }
}
