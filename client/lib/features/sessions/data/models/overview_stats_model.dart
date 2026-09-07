import '../../domain/entities/overview_stats.dart';

class OverviewStatsModel extends OverviewStats {
  const OverviewStatsModel({
    super.totalSessions = 0,
    super.totalParticipants = 0,
    super.totalResponses = 0,
    super.totalQuizzes = 0,
  });

  factory OverviewStatsModel.fromJson(Map<String, dynamic> json) {
    return OverviewStatsModel(
      totalSessions: int.tryParse(
            (json['totalSessions'] ?? json['total_sessions'])?.toString() ??
                '0',
          ) ??
          0,
      totalParticipants: int.tryParse(
            (json['totalParticipants'] ?? json['total_participants'])
                    ?.toString() ??
                '0',
          ) ??
          0,
      totalResponses: int.tryParse(
            (json['totalResponses'] ?? json['total_responses'])?.toString() ??
                '0',
          ) ??
          0,
      totalQuizzes: int.tryParse(
            (json['totalQuizzes'] ?? json['total_quizzes'])?.toString() ?? '0',
          ) ??
          0,
    );
  }

  Map<String, dynamic> toJson() => toMap();
}
