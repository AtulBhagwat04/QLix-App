abstract class QaRepository {
  Future<List<Map<String, dynamic>>> getSessionQuestions(String sessionId, {String? participantId, String? status, String? sortBy, String? search});
  Future<Map<String, dynamic>> updateQuestionStatus(String questionId, {String? status, bool? isPinned});
}
