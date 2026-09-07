import '../../domain/entities/session.dart';

class SessionModel extends Session {
  const SessionModel({
    required super.id,
    required super.accessCode,
    super.hostId = '',
    required super.title,
    super.description,
    super.state = 'draft',
    super.isPresenterModeActive = false,
    super.activePollId,
    super.activeQuizQuestionId,
    super.settings = const {},
    super.createdAt,
    super.updatedAt,
    super.participantCount = 0,
    super.pollCount = 0,
  });

  factory SessionModel.fromJson(Map<String, dynamic> json) {
    final rawSettings = json['settings'];
    Map<String, dynamic> parsedSettings = const {};
    if (rawSettings is Map) {
      parsedSettings = Map<String, dynamic>.from(rawSettings);
    }

    return SessionModel(
      id: (json['id'] ?? json['_id'])?.toString() ?? '',
      accessCode: (json['access_code'] ?? json['accessCode'])?.toString() ?? '',
      hostId: (json['host_id'] ?? json['hostId'])?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString(),
      state: json['state']?.toString() ?? 'draft',
      isPresenterModeActive: json['is_presenter_mode_active'] == true ||
          json['isPresentModeActive'] == true,
      activePollId:
          (json['active_poll_id'] ?? json['activePollId'])?.toString(),
      activeQuizQuestionId: (json['active_quiz_question_id'] ??
              json['activeQuizQuestionId'])
          ?.toString(),
      settings: parsedSettings,
      createdAt: (json['created_at'] ?? json['createdAt'])?.toString(),
      updatedAt: (json['updated_at'] ?? json['updatedAt'])?.toString(),
      participantCount: int.tryParse(
            (json['participant_count'] ?? json['participantCount'])
                    ?.toString() ??
                '0',
          ) ??
          0,
      pollCount: int.tryParse(
            (json['poll_count'] ?? json['pollCount'])?.toString() ?? '0',
          ) ??
          0,
    );
  }

  Map<String, dynamic> toJson() => toMap();

  SessionModel copyWith({
    String? id,
    String? accessCode,
    String? hostId,
    String? title,
    String? description,
    String? state,
    bool? isPresenterModeActive,
    String? activePollId,
    String? activeQuizQuestionId,
    Map<String, dynamic>? settings,
    String? createdAt,
    String? updatedAt,
    int? participantCount,
    int? pollCount,
  }) {
    return SessionModel(
      id: id ?? this.id,
      accessCode: accessCode ?? this.accessCode,
      hostId: hostId ?? this.hostId,
      title: title ?? this.title,
      description: description ?? this.description,
      state: state ?? this.state,
      isPresenterModeActive:
          isPresenterModeActive ?? this.isPresenterModeActive,
      activePollId: activePollId ?? this.activePollId,
      activeQuizQuestionId: activeQuizQuestionId ?? this.activeQuizQuestionId,
      settings: settings ?? this.settings,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      participantCount: participantCount ?? this.participantCount,
      pollCount: pollCount ?? this.pollCount,
    );
  }
}
