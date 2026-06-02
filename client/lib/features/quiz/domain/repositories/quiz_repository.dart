abstract class QuizRepository {
  Future<Map<String, dynamic>> activateQuizQuestion(String sessionId, String pollId, int timeLimit);
  Future<Map<String, dynamic>> submitQuizAnswer(String sessionId, String participantId, String pollId, String optionId);
  Future<List<Map<String, dynamic>>> getLeaderboard(String sessionId);
  Future<void> resetQuiz(String sessionId);
}
