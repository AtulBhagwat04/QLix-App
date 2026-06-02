import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:get_it/get_it.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../storage/cache_manager.dart';

class SocketClient {
  io.Socket? _socket;
  
  static String get serverUrl {
    try {
      final ip = GetIt.instance<CacheManager>().getServerIpOverride();
      if (ip != null && ip.trim().isNotEmpty) {
        return 'http://${ip.trim()}:3000';
      }
    } catch (_) {}
    if (kIsWeb) return 'http://localhost:3000';
    // Connect to host PC using its local Wi-Fi IP address (enables physical device testing)
    return 'http://10.197.55.64:3000';
  }

  // Streams for reactive BLoC integrations
  final _connectionController = StreamController<bool>.broadcast();
  final _pollActivationController = StreamController<Map<String, dynamic>?>.broadcast();
  final _votesUpdatedController = StreamController<Map<String, dynamic>>.broadcast();
  final _questionCreatedController = StreamController<Map<String, dynamic>>.broadcast();
  final _questionStatusController = StreamController<Map<String, dynamic>>.broadcast();
  final _questionUpvotedController = StreamController<Map<String, dynamic>>.broadcast();
  final _reactionController = StreamController<Map<String, dynamic>>.broadcast();
  final _quizTimerController = StreamController<Map<String, dynamic>>.broadcast();
  final _announcementController = StreamController<Map<String, dynamic>>.broadcast();

  Stream<bool> get connectionStream => _connectionController.stream;
  Stream<Map<String, dynamic>?> get pollActivationStream => _pollActivationController.stream;
  Stream<Map<String, dynamic>> get votesUpdatedStream => _votesUpdatedController.stream;
  Stream<Map<String, dynamic>> get questionCreatedStream => _questionCreatedController.stream;
  Stream<Map<String, dynamic>> get questionStatusStream => _questionStatusController.stream;
  Stream<Map<String, dynamic>> get questionUpvotedStream => _questionUpvotedController.stream;
  Stream<Map<String, dynamic>> get reactionStream => _reactionController.stream;
  Stream<Map<String, dynamic>> get quizTimerStream => _quizTimerController.stream;
  Stream<Map<String, dynamic>> get announcementStream => _announcementController.stream;

  bool get isConnected => _socket?.connected ?? false;

  void connect() {
    if (_socket != null && _socket!.connected) return;

    _socket = io.io(serverUrl, io.OptionBuilder()
      .setTransports(['websocket'])
      .disableAutoConnect()
      .enableReconnection()
      .setReconnectionDelay(2000)
      .build());

    _socket!.onConnect((_) {
      print('Socket connected to backend');
      _connectionController.add(true);
    });

    _socket!.onDisconnect((_) {
      print('Socket disconnected from backend');
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
      _quizTimerController.add({'event': 'start', ...Map<String, dynamic>.from(data as Map)});
    });

    _socket!.on('quiz_timer_tick', (data) {
      _quizTimerController.add({'event': 'tick', ...Map<String, dynamic>.from(data as Map)});
    });

    _socket!.on('quiz_timer_end', (data) {
      _quizTimerController.add({'event': 'end', ...Map<String, dynamic>.from(data as Map)});
    });

    _socket!.on('announcement_received', (data) {
      _announcementController.add(Map<String, dynamic>.from(data as Map));
    });

    _socket!.connect();
  }

  void joinSession(String accessCode, String participantId, String role) {
    if (_socket == null || !_socket!.connected) {
      connect();
    }
    _socket?.emit('join_session', {
      'accessCode': accessCode,
      'participantId': participantId,
      'role': role,
    });
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
      'optionIds': optionIds ?? [],
      'textResponse': textResponse,
      'ratingValue': ratingValue,
      'rankingIds': rankingIds ?? [],
    });
  }

  void submitQuestion({
    required String sessionId,
    required String participantId,
    required String text,
    required bool isAnonymous,
  }) {
    _socket?.emit('submit_question', {
      'sessionId': sessionId,
      'participantId': participantId,
      'text': text,
      'isAnonymous': isAnonymous,
    });
  }

  void upvoteQuestion({
    required String sessionId,
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
  }) {
    _socket?.emit('update_question_status', {
      'sessionId': sessionId,
      'questionId': questionId,
      'status': status,
      'isPinned': isPinned,
    });
  }

  void submitReaction(String emoji) {
    _socket?.emit('submit_reaction', {'emoji': emoji});
  }

  void activatePoll(String sessionId, String? pollId) {
    _socket?.emit('activate_poll', {
      'sessionId': sessionId,
      'pollId': pollId,
    });
  }

  void startQuizTimer(String sessionId, String pollId, int durationSeconds) {
    _socket?.emit('start_quiz_timer', {
      'sessionId': sessionId,
      'pollId': pollId,
      'durationSeconds': durationSeconds,
    });
  }

  void sendAnnouncement(String sessionId, String title, String message) {
    _socket?.emit('send_announcement', {
      'sessionId': sessionId,
      'title': title,
      'message': message,
    });
  }

  void disconnect() {
    _socket?.disconnect();
    _socket = null;
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
  }
}
