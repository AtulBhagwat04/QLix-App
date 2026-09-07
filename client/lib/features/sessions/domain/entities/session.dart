import 'package:equatable/equatable.dart';

class Session extends Equatable {
  final String id;
  final String accessCode;
  final String hostId;
  final String title;
  final String? description;
  final String state; // 'draft', 'active', 'ended'
  final bool isPresenterModeActive;
  final String? activePollId;
  final String? activeQuizQuestionId;
  final Map<String, dynamic> settings;
  final String? createdAt;
  final String? updatedAt;
  final int participantCount;
  final int pollCount;

  const Session({
    required this.id,
    required this.accessCode,
    this.hostId = '',
    required this.title,
    this.description,
    this.state = 'draft',
    this.isPresenterModeActive = false,
    this.activePollId,
    this.activeQuizQuestionId,
    this.settings = const {},
    this.createdAt,
    this.updatedAt,
    this.participantCount = 0,
    this.pollCount = 0,
  });

  bool get isLive => state == 'active';
  bool get isDraft => state == 'draft';
  bool get isEnded => state == 'ended';
  String get displayTitle => title.trim().isEmpty ? 'Untitled Session' : title;

  dynamic operator [](String key) {
    switch (key) {
      case 'id':
      case '_id':
        return id;
      case 'access_code':
      case 'accessCode':
        return accessCode;
      case 'host_id':
      case 'hostId':
        return hostId;
      case 'title':
        return title;
      case 'description':
        return description;
      case 'state':
        return state;
      case 'is_presenter_mode_active':
      case 'isPresentModeActive':
        return isPresenterModeActive;
      case 'active_poll_id':
      case 'activePollId':
        return activePollId;
      case 'active_quiz_question_id':
      case 'activeQuizQuestionId':
        return activeQuizQuestionId;
      case 'settings':
        return settings;
      case 'created_at':
      case 'createdAt':
        return createdAt;
      case 'updated_at':
      case 'updatedAt':
        return updatedAt;
      case 'participant_count':
      case 'participantCount':
        return participantCount;
      case 'poll_count':
      case 'pollCount':
        return pollCount;
      default:
        return null;
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      '_id': id,
      'access_code': accessCode,
      'host_id': hostId,
      'title': title,
      'description': description,
      'state': state,
      'is_presenter_mode_active': isPresenterModeActive,
      'active_poll_id': activePollId,
      'active_quiz_question_id': activeQuizQuestionId,
      'settings': settings,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'participant_count': participantCount,
      'poll_count': pollCount,
    };
  }

  @override
  List<Object?> get props => [
        id,
        accessCode,
        hostId,
        title,
        description,
        state,
        isPresenterModeActive,
        activePollId,
        activeQuizQuestionId,
        settings,
        createdAt,
        updatedAt,
        participantCount,
        pollCount,
      ];
}
