import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:get_it/get_it.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../storage/cache_manager.dart';

class SocketClient {
  io.Socket? _socket;

  static String get defaultHost {
    if (kIsWeb) return 'localhost';
    return '10.225.134.64';
  }

  static String get serverUrl {
    try {
      final ip = GetIt.instance<CacheManager>().getServerIpOverride();
      if (ip != null &&
          ip.trim().isNotEmpty &&
          ip.trim() != '10.202.235.64' &&
          ip.trim() != '10.128.231.64' &&
          ip.trim() != '10.109.186.64') {
        return 'http://${ip.trim()}:3000';
      }
    } catch (_) {}
    return 'http://$defaultHost:3000';
  }

  void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
  }

  void reconnect() {
    disconnect();
    connect();
  }

  // Streams for reactive BLoC integrations
  final _connectionController = StreamController<bool>.broadcast();
  final _pollActivationController =
      StreamController<Map<String, dynamic>?>.broadcast();
  final _votesUpdatedController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _questionCreatedController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _questionStatusController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _questionUpvotedController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _reactionController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _quizTimerController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _announcementController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _sessionStateController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _participantJoinedController =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<bool> get connectionStream => _connectionController.stream;
  Stream<Map<String, dynamic>?> get pollActivationStream =>
      _pollActivationController.stream;
  Stream<Map<String, dynamic>> get votesUpdatedStream =>
      _votesUpdatedController.stream;
  Stream<Map<String, dynamic>> get questionCreatedStream =>
      _questionCreatedController.stream;
  Stream<Map<String, dynamic>> get questionStatusStream =>
      _questionStatusController.stream;
  Stream<Map<String, dynamic>> get questionUpvotedStream =>
      _questionUpvotedController.stream;
  Stream<Map<String, dynamic>> get reactionStream => _reactionController.stream;
  Stream<Map<String, dynamic>> get quizTimerStream =>
      _quizTimerController.stream;
  Stream<Map<String, dynamic>> get announcementStream =>
      _announcementController.stream;
  Stream<Map<String, dynamic>> get sessionStateStream =>
      _sessionStateController.stream;
  Stream<Map<String, dynamic>> get participantJoinedStream =>
      _participantJoinedController.stream;

  bool get isConnected => _socket?.connected ?? false;

  String? _lastAccessCode;
  String? _lastParticipantId;
  String? _lastRole;

  void connect() {
    if (_socket != null && _socket!.connected) return;

    _socket = io.io(
      serverUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .enableReconnection()
          .setReconnectionDelay(2000)
          .build(),
    );

    _socket!.onConnect((_) {
      debugPrint('Socket connected to backend');
      _connectionController.add(true);
      if (_lastAccessCode != null) {
        _socket?.emit('join_session', {
          'accessCode': _lastAccessCode,
          'participantId': _lastParticipantId,
          'role': _lastRole ?? 'participant',
        });
      }
    });

    _socket!.onDisconnect((_) {
      debugPrint('Socket disconnected from backend');
      _connectionController.add(false);
    });

    // Register event map bindings
    _socket!.on('poll_activated', (data) {
      final map = data != null ? Map<String, dynamic>.from(data as Map) : null;
      _pollActivationController.add(map);
    });

    _socket!.on('poll_deactivated', (_) {
      _pollActivationController.add(null);
    });

    _socket!.on('votes_updated', (data) {
      _votesUpdatedController.add(Map<String, dynamic>.from(data as Map));
    });

    _socket!.on('question_created', (data) {
      _questionCreatedController.add(Map<String, dynamic>.from(data as Map));
    });

    _socket!.on('question_status_changed', (data) {
      _questionStatusController.add(Map<String, dynamic>.from(data as Map));
    });

    _socket!.on('question_upvoted', (data) {
      _questionUpvotedController.add(Map<String, dynamic>.from(data as Map));
    });

    _socket!.on('reaction_broadcast', (data) {
      _reactionController.add(Map<String, dynamic>.from(data as Map));
    });

    _socket!.on('quiz_timer_start', (data) {
      _quizTimerController.add({
        'event': 'start',
        ...Map<String, dynamic>.from(data as Map),
      });
    });

    _socket!.on('quiz_timer_tick', (data) {
      _quizTimerController.add({
        'event': 'tick',
        ...Map<String, dynamic>.from(data as Map),
      });
    });

    _socket!.on('quiz_timer_end', (data) {
      _quizTimerController.add({
        'event': 'end',
        ...Map<String, dynamic>.from(data as Map),
      });
    });

    _socket!.on('announcement_received', (data) {
      _announcementController.add(Map<String, dynamic>.from(data as Map));
    });

    _socket!.on('session_state_changed', (data) {
      if (data != null) {
        _sessionStateController.add(Map<String, dynamic>.from(data as Map));
      }
    });

    _socket!.on('participant_joined_ack', (data) {
      if (data != null) {
        _participantJoinedController.add(Map<String, dynamic>.from(data as Map));
      }
    });

    _socket!.connect();
  }

  void joinSession(String accessCode, String participantId, String role) {
    _lastAccessCode = accessCode;
    _lastParticipantId = participantId;
    _lastRole = role;

    if (_socket == null || !_socket!.connected) {
      connect();
    } else {
      _socket?.emit('join_session', {
        'accessCode': accessCode,
        'participantId': participantId,
        'role': role,
      });
    }
  }

  void submitVote({
    required String pollId,
    required String participantId,
    List<String>? optionIds,
    String? textResponse,
    int? ratingValue,
    List<String>? rankingIds,
  }) {
    _socket?.emit('submit_vote', {
      'pollId': pollId,
      'participantId': participantId,
      'optionIds': optionIds,
      'textResponse': textResponse,
      'ratingValue': ratingValue,
      'rankingIds': rankingIds,
    });
  }

  void submitQuestion({
    required String sessionId,
    required String participantId,
    required String text,
    bool isAnonymous = false,
  }) {
    _socket?.emit('submit_question', {
      'sessionId': sessionId,
      'participantId': participantId,
      'text': text,
      'isAnonymous': isAnonymous,
    });
  }

  void upvoteQuestion({
    String? sessionId,
    required String questionId,
    required String participantId,
  }) {
    _socket?.emit('upvote_question', {
      'sessionId': sessionId,
      'questionId': questionId,
      'participantId': participantId,
    });
  }

  void updateQuestionStatus({
    required String sessionId,
    required String questionId,
    String? status,
    bool? isPinned,
    String? answerText,
  }) {
    _socket?.emit('update_question_status', {
      'sessionId': sessionId,
      'questionId': questionId,
      'status': status,
      'isPinned': isPinned,
      'answerText': answerText,
    });
  }

  void submitReaction(String emoji) {
    _socket?.emit('submit_reaction', {'emoji': emoji});
  }

  void activatePoll(String sessionId, String? pollId) {
    _socket?.emit('activate_poll', {'sessionId': sessionId, 'pollId': pollId});
  }

  void startQuizTimer(String sessionId, String pollId, int durationSeconds) {
    _socket?.emit('start_quiz_timer', {
      'sessionId': sessionId,
      'pollId': pollId,
      'durationSeconds': durationSeconds,
    });
  }

  void stopQuizTimer(String sessionId, String pollId) {
    _socket?.emit('stop_quiz_timer', {
      'sessionId': sessionId,
      'pollId': pollId,
    });
  }

  void sendAnnouncement(String sessionId, String title, String message) {
    _socket?.emit('send_announcement', {
      'sessionId': sessionId,
      'title': title,
      'message': message,
    });
  }

  void updateSessionState(String sessionId, String state) {
    _socket?.emit('update_session_state', {
      'sessionId': sessionId,
      'state': state,
    });
  }

  void dispose() {
    disconnect();
    _connectionController.close();
    _pollActivationController.close();
    _votesUpdatedController.close();
    _questionCreatedController.close();
    _questionStatusController.close();
    _questionUpvotedController.close();
    _reactionController.close();
    _quizTimerController.close();
    _announcementController.close();
    _sessionStateController.close();
    _participantJoinedController.close();
  }
}
