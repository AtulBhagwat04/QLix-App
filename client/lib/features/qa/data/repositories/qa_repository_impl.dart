import '../../../../core/network/api_client.dart';
import '../../domain/repositories/qa_repository.dart';

class QaRepositoryImpl implements QaRepository {
  final ApiClient _apiClient;

  QaRepositoryImpl(this._apiClient);

  @override
  Future<List<Map<String, dynamic>>> getSessionQuestions(
    String sessionId, {
    String? participantId,
    String? status,
    String? sortBy,
    String? search,
  }) async {
    final queryParameters = <String, dynamic>{};
    if (participantId != null) queryParameters['participantId'] = participantId;
    if (status != null) queryParameters['status'] = status;
    if (sortBy != null) queryParameters['sortBy'] = sortBy;
    if (search != null) queryParameters['search'] = search;

    final response = await _apiClient.dio.get(
      '/qa/session/$sessionId',
      queryParameters: queryParameters,
    );

    if (response.statusCode == 200 && response.data != null) {
      final list = response.data['data'] as List;
      return list.map((item) => Map<String, dynamic>.from(item as Map)).toList();
    }
    throw Exception(response.data?['message'] ?? 'Failed to load Q&A questions');
  }

  @override
  Future<Map<String, dynamic>> updateQuestionStatus(
    String questionId, {
    String? status,
    bool? isPinned,
  }) async {
    final body = <String, dynamic>{};
    if (status != null) body['status'] = status;
    if (isPinned != null) body['isPinned'] = isPinned;

    final response = await _apiClient.dio.patch('/qa/$questionId', data: body);
    if (response.statusCode == 200 && response.data != null) {
      return Map<String, dynamic>.from(response.data['data'] as Map);
    }
    throw Exception(response.data?['message'] ?? 'Failed to update question status');
  }
}
