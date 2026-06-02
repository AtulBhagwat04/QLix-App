abstract class PollRepository {
  Future<List<Map<String, dynamic>>> getSessionPolls(String sessionId);
  Future<Map<String, dynamic>> createPoll({
    required String sessionId,
    required String title,
    required String type,
    Map<String, dynamic>? settings,
    List<Map<String, dynamic>>? options,
  });
  Future<Map<String, dynamic>> updatePoll(String pollId, Map<String, dynamic> body);
  Future<void> deletePoll(String pollId);
  Future<Map<String, dynamic>> getPollResults(String pollId);
}
