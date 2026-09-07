import 'package:equatable/equatable.dart';

class OverviewStats extends Equatable {
  final int totalSessions;
  final int totalParticipants;
  final int totalResponses;
  final int totalQuizzes;

  const OverviewStats({
    this.totalSessions = 0,
    this.totalParticipants = 0,
    this.totalResponses = 0,
    this.totalQuizzes = 0,
  });

  dynamic operator [](String key) {
    switch (key) {
      case 'totalSessions':
      case 'total_sessions':
        return totalSessions;
      case 'totalParticipants':
      case 'total_participants':
        return totalParticipants;
      case 'totalResponses':
      case 'total_responses':
        return totalResponses;
      case 'totalQuizzes':
      case 'total_quizzes':
        return totalQuizzes;
      default:
        return null;
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'totalSessions': totalSessions,
      'totalParticipants': totalParticipants,
      'totalResponses': totalResponses,
      'totalQuizzes': totalQuizzes,
    };
  }

  @override
  List<Object?> get props => [
        totalSessions,
        totalParticipants,
        totalResponses,
        totalQuizzes,
      ];
}
