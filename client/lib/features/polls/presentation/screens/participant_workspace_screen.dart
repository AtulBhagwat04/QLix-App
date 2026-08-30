import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/network/socket_client.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/storage/cache_manager.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/utils/error_handler.dart';
import '../../../qa/domain/repositories/qa_repository.dart';
import '../../domain/repositories/poll_repository.dart';
import '../../../quiz/domain/repositories/quiz_repository.dart';
import '../../../sessions/domain/repositories/session_repository.dart';

class ParticipantWorkspaceScreen extends StatefulWidget {
  final String accessCode;
  const ParticipantWorkspaceScreen({super.key, required this.accessCode});

  @override
  State<ParticipantWorkspaceScreen> createState() =>
      _ParticipantWorkspaceScreenState();
}

class _ParticipantWorkspaceScreenState extends State<ParticipantWorkspaceScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final _socketClient = sl<SocketClient>();
  final _cacheManager = sl<CacheManager>();

  Map<String, dynamic>? _participant;
  Map<String, dynamic>? _session;

  // Real-time active polls list & category filtering
  List<Map<String, dynamic>> _activePolls = [];
  String _selectedCategoryFilter = 'ALL';
  bool _showAnsweredPolls = false;
  final Set<String> _fetchingResultsPollIds = {};

  List<String> get _availableCategories {
    final types = <String>{'ALL'};
    for (var p in _activePolls) {
      final t = (p['type'] ?? 'multiple_choice').toString().toUpperCase();
      types.add(t);
    }
    return types.toList();
  }

  List<Map<String, dynamic>> get _filteredActivePolls {
    List<Map<String, dynamic>> list;
    if (_selectedCategoryFilter == 'ALL') {
      list = List<Map<String, dynamic>>.from(_activePolls);
    } else {
      list = _activePolls.where((p) {
        final t = (p['type'] ?? 'multiple_choice').toString().toUpperCase();
        return t == _selectedCategoryFilter;
      }).toList();
    }

    // Unanswered polls first, answered polls last
    list.sort((a, b) {
      final aId = (a['id'] ?? '').toString();
      final bId = (b['id'] ?? '').toString();
      final aVoted = _votedPollIds.contains(aId);
      final bVoted = _votedPollIds.contains(bId);

      if (aVoted == bVoted) return 0;
      return aVoted ? 1 : -1;
    });

    return list;
  }

  List<Map<String, dynamic>> _questions = [];
  final List<Map<String, dynamic>> _announcements = [];

  // Optimistic UI tracking
  final Set<String> _votedPollIds = {};
  final Set<String> _editingPollIds = {};

  // Quiz states
  Map<String, dynamic>? _activeQuiz;
  int _quizTimeRemaining = 0;
  bool _hasAnsweredQuiz = false;

  // Q&A controller
  final _questionInputCtrl = TextEditingController();

  // Per-poll input state maps
  final Map<String, Set<String>> _selectedOptionIdsMap = {};
  final Map<String, TextEditingController> _textResponseCtrlsMap = {};
  final Map<String, double> _ratingValuesMap = {};
  final Map<String, List<Map<String, dynamic>>> _rankingOptionsMap = {};

  // Sockets streams
  StreamSubscription? _activationSub;
  StreamSubscription? _votesSub;
  StreamSubscription? _qaSub;
  StreamSubscription? _qaStatusSub;
  StreamSubscription? _qaUpvotedSub;
  StreamSubscription? _quizSub;
  StreamSubscription? _announcementSub;
  StreamSubscription? _sessionStateSub;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initializeWorkspace();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _questionInputCtrl.dispose();
    for (var ctrl in _textResponseCtrlsMap.values) {
      ctrl.dispose();
    }

    _activationSub?.cancel();
    _votesSub?.cancel();
    _qaSub?.cancel();
    _qaStatusSub?.cancel();
    _qaUpvotedSub?.cancel();
    _quizSub?.cancel();
    _announcementSub?.cancel();
    _sessionStateSub?.cancel();
    super.dispose();
  }

  Future<void> _initializeWorkspace() async {
    final cached = _cacheManager.getSessionParticipant(widget.accessCode);
    final participantName = cached != null
        ? (cached['name']?.toString() ?? 'Guest')
        : 'Guest';

    try {
      final details = await sl<SessionRepository>().joinSessionByCode(
        widget.accessCode,
        _cacheManager.getDeviceId() ?? '',
        participantName,
        true,
      );

      final cachedVoted = _cacheManager.getVotedPollIds(widget.accessCode);
      final serverVoted = (details['votedPollIds'] as List? ?? [])
          .map((id) => id.toString())
          .toList();

      if (!mounted) return;

      setState(() {
        _session = Map<String, dynamic>.from(
          (details['session'] as Map?) ?? {},
        );
        _participant = Map<String, dynamic>.from(
          (details['participant'] as Map?) ?? {},
        );
        _votedPollIds.addAll(cachedVoted);
        _votedPollIds.addAll(serverVoted);
      });

      final sessionId = (_session?['id'] ?? '').toString();
      final participantId = (_participant?['id'] ?? '').toString();

      // Load initial questions list
      if (sessionId.isNotEmpty && participantId.isNotEmpty) {
        final questions = await sl<QaRepository>().getSessionQuestions(
          sessionId,
          participantId: participantId,
        );
        if (!mounted) return;
        setState(() {
          _questions = questions;
        });
      }

      // Load active session polls list
      if (sessionId.isNotEmpty) {
        try {
          final sessionPolls = await sl<PollRepository>().getSessionPolls(
            sessionId,
          );
          final activeList = sessionPolls
              .where((p) => (p['status'] ?? '').toString() == 'active')
              .toList();
          if (!mounted) return;
          setState(() {
            _activePolls = activeList;
          });
        } catch (_) {}
      }

      // Connect to websocket room
      _socketClient.connect();
      _socketClient.joinSession(
        widget.accessCode,
        participantId,
        'participant',
      );

      // Bind WebSockets Streams
      _activationSub = _socketClient.pollActivationStream.listen((data) {
        if (!mounted) return;
        if (data == null || data['poll'] == null) return;
        final poll = Map<String, dynamic>.from((data['poll'] as Map?) ?? {});
        final pollId = (poll['id'] ?? '').toString();
        if (pollId.isEmpty) return;

        setState(() {
          final idx = _activePolls.indexWhere(
            (p) => (p['id'] ?? '').toString() == pollId,
          );
          if (idx != -1) {
            _activePolls[idx] = poll;
          } else {
            _activePolls.insert(0, poll);
          }
        });
      });

      _votesSub = _socketClient.votesUpdatedStream.listen((data) {
        final pollId = (data['pollId'] ?? '').toString();
        if (!mounted) return;
        setState(() {
          for (var p in _activePolls) {
            if ((p['id'] ?? '').toString() == pollId) {
              p['results'] = data['results'];
            }
          }
        });
      });

      _qaSub = _socketClient.questionCreatedStream.listen((data) {
        if (data['question'] == null) return;
        final newQ = Map<String, dynamic>.from(
          (data['question'] as Map?) ?? {},
        );
        if (!mounted) return;
        setState(() {
          _questions.removeWhere(
            (q) =>
                q['isOptimistic'] == true &&
                q['text'] == newQ['text'] &&
                q['participantId'] == newQ['participantId'],
          );

          final isMine =
              newQ['participantId'] == _participant?['id']?.toString();
          final isApproved = newQ['status'] == 'approved';

          if ((isApproved || isMine) &&
              !_questions.any((q) => q['id'] == newQ['id'])) {
            _questions.insert(0, newQ);
          }
        });
      });

      _qaStatusSub = _socketClient.questionStatusStream.listen((data) {
        if (data['question'] == null) return;
        final updatedQ = Map<String, dynamic>.from(
          (data['question'] as Map?) ?? {},
        );
        if (!mounted) return;
        setState(() {
          final index = _questions.indexWhere((q) => q['id'] == updatedQ['id']);
          final isMine =
              updatedQ['participantId'] == _participant?['id']?.toString();
          final isApproved =
              updatedQ['status'] == 'approved' ||
              updatedQ['status'] == 'answered';

          if (index != -1) {
            if (isApproved || isMine) {
              _questions[index] = updatedQ;
            } else {
              _questions.removeAt(index);
            }
          } else if (isApproved || isMine) {
            _questions.insert(0, updatedQ);
          }
        });
      });

      _qaUpvotedSub = _socketClient.questionUpvotedStream.listen((data) {
        final qId = (data['questionId'] ?? '').toString();
        final count = (data['upvotesCount'] as num?)?.toInt() ?? 0;
        if (!mounted) return;
        setState(() {
          for (var q in _questions) {
            if (q['id'] == qId) {
              q['upvotesCount'] = count;
            }
          }
        });
      });

      _quizSub = _socketClient.quizTimerStream.listen((data) {
        final event = (data['event'] ?? '').toString();
        final pollId = (data['pollId'] ?? '').toString();

        if (!mounted) return;

        if (event == 'start') {
          final pollIdStr = pollId.toString();
          setState(() {
            _activeQuiz = {'id': pollIdStr};
            _quizTimeRemaining =
                (data['durationSeconds'] as num?)?.toInt() ?? 15;
            _hasAnsweredQuiz = _votedPollIds.contains(pollIdStr);
          });
          sl<PollRepository>()
              .getPollResults(pollId)
              .then((details) {
                if (!mounted) return;
                setState(() {
                  _activeQuiz = details;
                });
              })
              .catchError((e) {
                // fail gracefully
              });
        } else if (event == 'tick') {
          setState(() {
            _quizTimeRemaining = (data['remaining'] as num?)?.toInt() ?? 0;
          });
        } else if (event == 'end') {
          setState(() {
            _activeQuiz = null;
            _quizTimeRemaining = 0;
          });
        }
      });

      _announcementSub = _socketClient.announcementStream.listen((data) {
        if (data['announcement'] == null) return;
        final alert = Map<String, dynamic>.from(
          (data['announcement'] as Map?) ?? {},
        );
        if (!mounted) return;
        setState(() {
          _announcements.insert(0, alert);
        });
        _showAnnouncementDialog(
          (alert['title'] ?? 'Alert').toString(),
          (alert['message'] ?? '').toString(),
        );
      });

      _socketClient.reactionStream.listen((data) {
        final emoji = (data['emoji'] ?? '').toString();
        _triggerLocalReaction(emoji);
      });

      _sessionStateSub = _socketClient.sessionStateStream.listen((data) {
        final newState = (data['state'] ?? '').toString();
        if (!mounted || newState.isEmpty) return;
        setState(() {
          if (_session != null) {
            _session!['state'] = newState;
          }
        });
        if (newState == 'active') {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(
                    Icons.play_circle_fill_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                  SizedBox(width: 8),
                  Text('The host has started the session!'),
                ],
              ),
              backgroundColor: AppColors.success,
              behavior: SnackBarBehavior.floating,
            ),
          );
        } else if (newState == 'ended') {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(
                    Icons.stop_circle_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                  SizedBox(width: 8),
                  Text('This session has ended.'),
                ],
              ),
              backgroundColor: AppColors.error,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppError.from(e, context: 'join')),
            backgroundColor: AppColors.error,
          ),
        );
        if (_session == null) {
          Future.delayed(const Duration(milliseconds: 700), () {
            if (mounted && context.canPop()) {
              context.pop();
            } else if (mounted) {
              context.go('/join');
            }
          });
        }
      }
    }
  }

  void _showAnnouncementDialog(String title, String message) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 24,
          ),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.1)
                    : const Color(0xFFE2E8F0),
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.2),
                  blurRadius: 32,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: AppColors.primaryGradient,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.35),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.campaign_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'HOST BROADCAST',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : AppColors.textPrimaryLight,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.4,
                    fontWeight: FontWeight.w500,
                    color: isDark
                        ? Colors.white70
                        : AppColors.textSecondaryLight,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'Got it',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _submitQuestion() {
    final text = _questionInputCtrl.text.trim();
    if (text.isEmpty || _session == null || _participant == null) return;

    final participantName = (_participant?['name']?.toString() ?? 'Guest');
    // Instant Q&A Optimistic update
    final tempId = 'temp-${DateTime.now().millisecondsSinceEpoch}';
    final tempQ = {
      'id': tempId,
      'sessionId': (_session?['id'] ?? '').toString(),
      'participantId': (_participant?['id'] ?? '').toString(),
      'text': text,
      'isAnonymous': false,
      'status': 'pending',
      'upvotesCount': 0,
      'isPinned': false,
      'authorName': participantName,
      'createdAt': DateTime.now().toIso8601String(),
      'isOptimistic': true, // visual loader tag
    };

    setState(() {
      _questions.insert(0, tempQ);
    });

    _socketClient.submitQuestion(
      sessionId: (_session?['id'] ?? '').toString(),
      participantId: (_participant?['id'] ?? '').toString(),
      text: text,
      isAnonymous: false,
    );

    _questionInputCtrl.clear();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Question submitted instantly!'),
        backgroundColor: AppColors.success,
      ),
    );
  }

  void _upvoteQuestion(String questionId, bool currentHasUpvoted) {
    if (_session == null || _participant == null) return;

    setState(() {
      for (var q in _questions) {
        if (q['id'] == questionId) {
          q['hasUpvoted'] = !currentHasUpvoted;
          q['upvotesCount'] =
              (q['upvotesCount'] as int) + (currentHasUpvoted ? -1 : 1);
        }
      }
    });

    _socketClient.upvoteQuestion(
      sessionId: (_session?['id'] ?? '').toString(),
      questionId: questionId,
      participantId: (_participant?['id'] ?? '').toString(),
    );
  }

  void _submitQuizAnswer(String optionId) {
    if (_activeQuiz == null || _participant == null) return;

    setState(() {
      _hasAnsweredQuiz = true;
    });

    final messenger = ScaffoldMessenger.of(context);

    sl<QuizRepository>()
        .submitQuizAnswer(
          (_session?['id'] ?? '').toString(),
          (_participant?['id'] ?? '').toString(),
          (_activeQuiz?['id'] ?? '').toString(),
          optionId,
        )
        .then((res) {
          final pollId = (_activeQuiz?['id'] ?? '').toString();
          if (pollId.isNotEmpty) {
            _votedPollIds.add(pollId);
          }
          final isCorrect = res['isCorrect'] as bool;
          final points = res['pointsEarned'] as int;
          messenger.showSnackBar(
            SnackBar(
              content: Text(
                isCorrect
                    ? 'CORRECT! Earned $points pts!'
                    : 'WRONG ANSWER! 0 pts.',
              ),
              backgroundColor: isCorrect ? AppColors.success : AppColors.error,
            ),
          );
        })
        .catchError((e) {
          setState(() {
            _hasAnsweredQuiz = false;
          });
          messenger.showSnackBar(
            SnackBar(
              content: Text(AppError.from(e, context: 'submit')),
              backgroundColor: AppColors.error,
            ),
          );
        });
  }

  void _sendReaction(String emoji) {
    _socketClient.submitReaction(emoji);
    _triggerLocalReaction(emoji);
  }

  void _triggerLocalReaction(String emoji) {
    // Local reaction animations disabled to optimize performance
  }

  void _confirmLeaveRoom() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.exit_to_app_rounded, color: AppColors.error),
            SizedBox(width: 10),
            Text(
              'Leave Session?',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        content: const Text(
          'Are you sure you want to exit this live session? You can always rejoin using the session code.',
          style: TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Stay',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _socketClient.disconnect();
              context.go('/');
            },
            child: const Text('Leave Room'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_session == null) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final participantName = (_participant?['name'] ?? 'Participant').toString();
    final sessionTitle = (_session!['title'] ?? 'Live Session').toString();
    final accessCode = (_session!['access_code'] ?? widget.accessCode)
        .toString();

    final sessionState = (_session!['state'] ?? 'draft').toString();
    final isDraft = sessionState != 'active' && sessionState != 'ended';
    final isEnded = sessionState == 'ended';

    // ── 1. DRAFT / WAITING LOBBY STATE ──────────────────────────────────────
    if (isDraft) {
      return Stack(
        children: [
          Scaffold(
            appBar: _buildWorkspaceAppBar(
              context: context,
              isDark: isDark,
              sessionTitle: sessionTitle,
              accessCode: accessCode,
              participantName: participantName,
              status: 'WAITING',
              isLive: false,
              hasTabs: false,
            ),
            body: _buildSessionWaitingLobby(
              isDark,
              sessionTitle,
              accessCode,
              participantName,
            ),
            bottomNavigationBar: _buildReactionTool(),
          ),
        ],
      );
    }

    // ── 2. SESSION ENDED STATE ──────────────────────────────────────────────
    if (isEnded) {
      return Stack(
        children: [
          Scaffold(
            appBar: _buildWorkspaceAppBar(
              context: context,
              isDark: isDark,
              sessionTitle: sessionTitle,
              accessCode: accessCode,
              participantName: participantName,
              status: 'ENDED',
              isLive: false,
              hasTabs: false,
            ),
            body: _buildSessionEndedScreen(
              isDark,
              sessionTitle,
              participantName,
            ),
          ),
        ],
      );
    }

    // ── 3. ACTIVE LIVE SESSION STATE ────────────────────────────────────────
    return Stack(
      children: [
        Scaffold(
          appBar: _buildWorkspaceAppBar(
            context: context,
            isDark: isDark,
            sessionTitle: sessionTitle,
            accessCode: accessCode,
            participantName: participantName,
            status: 'LIVE',
            isLive: true,
            hasTabs: true,
          ),
          body: TabBarView(
            controller: _tabController,
            children: [_buildPollsTabView(), _buildQaTabView()],
          ),
          bottomNavigationBar: _buildReactionTool(),
        ),
      ],
    );
  }

  PreferredSizeWidget _buildWorkspaceAppBar({
    required BuildContext context,
    required bool isDark,
    required String sessionTitle,
    required String accessCode,
    required String participantName,
    required String status,
    required bool isLive,
    required bool hasTabs,
  }) {
    final statusColor = isLive
        ? AppColors.success
        : (status == 'WAITING' ? Colors.amber : Colors.grey);

    return AppBar(
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      titleSpacing: 0,
      leading: Padding(
        padding: const EdgeInsets.only(left: 14),
        child: Center(
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: isLive
                    ? AppColors.primaryGradient
                    : [
                        statusColor.withValues(alpha: 0.7),
                        statusColor.withValues(alpha: 0.9),
                      ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: (isLive ? AppColors.primary : statusColor).withValues(
                    alpha: 0.25,
                  ),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Text(
              participantName.isNotEmpty
                  ? participantName[0].toUpperCase()
                  : 'P',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ),
      title: Padding(
        padding: const EdgeInsets.only(left: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              sessionTitle,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
                color: isDark ? Colors.white : AppColors.textPrimaryLight,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 3),
            Row(
              children: [
                // Status indicator pill
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: statusColor.withValues(alpha: 0.25),
                      width: 0.8,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: statusColor,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        status,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.6,
                          color: statusColor,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Copyable PIN
                GestureDetector(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: accessCode));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Session code copied!'),
                        duration: Duration(seconds: 1),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.05)
                          : Colors.black.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '#$accessCode',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white70 : Colors.black54,
                          ),
                        ),
                        const SizedBox(width: 3),
                        Icon(
                          Icons.copy_rounded,
                          size: 10,
                          color: isDark ? Colors.white38 : Colors.black38,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        Container(
          margin: const EdgeInsets.only(right: 12),
          decoration: BoxDecoration(
            color: AppColors.error.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: IconButton(
            icon: const Icon(
              Icons.logout_rounded,
              color: AppColors.error,
              size: 18,
            ),
            visualDensity: VisualDensity.compact,
            tooltip: 'Leave Session',
            onPressed: _confirmLeaveRoom,
          ),
        ),
      ],
      bottom: hasTabs
          ? PreferredSize(
              preferredSize: const Size.fromHeight(48),
              child: Container(
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: isDark
                          ? Colors.white10
                          : Colors.black.withValues(alpha: 0.06),
                      width: 1,
                    ),
                  ),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicatorColor: AppColors.primary,
                  indicatorWeight: 2.5,
                  indicatorSize: TabBarIndicatorSize.tab,
                  labelColor: AppColors.primary,
                  labelStyle: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    letterSpacing: -0.2,
                  ),
                  unselectedLabelColor: isDark
                      ? Colors.white60
                      : Colors.black54,
                  unselectedLabelStyle: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                  tabs: [
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.poll_rounded, size: 18),
                          const SizedBox(width: 6),
                          const Text('Live Polls'),
                          if (_activePolls.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '${_activePolls.length}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.question_answer_rounded, size: 18),
                          const SizedBox(width: 6),
                          const Text('Q&A'),
                          if (_questions.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.purpleAccent,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '${_questions.length}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            )
          : PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Divider(
                height: 1,
                color: isDark
                    ? Colors.white10
                    : Colors.black.withValues(alpha: 0.06),
              ),
            ),
    );
  }

  Widget _buildSessionWaitingLobby(
    bool isDark,
    String sessionTitle,
    String accessCode,
    String participantName,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Clean minimal icon
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.amber.withValues(alpha: 0.12),
              ),
              child: const Icon(
                Icons.hourglass_top_rounded,
                size: 30,
                color: Colors.amber,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Waiting for host to start...',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : AppColors.textPrimaryLight,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              'Polls and Q&A will appear here automatically.',
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white60 : Colors.black54,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            // Minimal pill tag
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.black.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.person_outline_rounded,
                    size: 14,
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    participantName,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '•',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white38 : Colors.black38,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '#$accessCode',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSessionEndedScreen(
    bool isDark,
    String sessionTitle,
    String participantName,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.success.withValues(alpha: 0.12),
              ),
              child: const Icon(
                Icons.check_circle_outline_rounded,
                size: 32,
                color: AppColors.success,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Session Ended',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : AppColors.textPrimaryLight,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              'Thank you for participating!',
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white60 : Colors.black54,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 42,
              child: OutlinedButton.icon(
                onPressed: _confirmLeaveRoom,
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.logout_rounded, size: 16),
                label: const Text(
                  'Leave Session',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReactionTool() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: AppDecoration.glassWrapper(
        context: context,
        borderRadius: AppSizes.radiusCard,
        blur: 16.0,
        opacity: isDark ? 0.04 : 0.08,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _reactionBtn('👍'),
              _reactionBtn('🔥'),
              _reactionBtn('👏'),
              _reactionBtn('💡'),
              _reactionBtn('🎉'),
              _reactionBtn('❤️'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _reactionBtn(String emoji) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppSizes.radiusCard),
      onTap: () => _sendReaction(emoji),
      child: Container(
        padding: const EdgeInsets.all(8),
        child: Text(emoji, style: const TextStyle(fontSize: 24)),
      ),
    );
  }

  Widget _buildLobbyWaitingState(bool isDark) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Radar Beacon Icon
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.primary.withValues(alpha: 0.2),
                    AppColors.primary.withValues(alpha: 0.04),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      width: 1.5,
                    ),
                  ),
                  child: const Icon(
                    Icons.sensors_rounded,
                    size: 38,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppColors.success.withValues(alpha: 0.3),
                ),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.check_circle_rounded,
                    color: AppColors.success,
                    size: 14,
                  ),
                  SizedBox(width: 6),
                  Text(
                    'CONNECTED TO LIVE ROOM',
                    style: TextStyle(
                      color: AppColors.success,
                      fontWeight: FontWeight.w900,
                      fontSize: 10,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Waiting for Next Poll',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
                color: isDark ? Colors.white : AppColors.textPrimaryLight,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'The host will launch interactive polls, quizzes, and questions here in real-time. Feel free to cheer with reactions below!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                height: 1.4,
                color: isDark ? Colors.white60 : Colors.black54,
              ),
            ),
            const SizedBox(height: 28),
            // Quick Q&A Button
            OutlinedButton.icon(
              onPressed: () {
                _tabController.animateTo(1);
              },
              icon: const Icon(Icons.question_answer_rounded, size: 16),
              label: const Text('Ask a Question in Q&A'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: BorderSide(
                  color: AppColors.primary.withValues(alpha: 0.4),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPollsTabView() {
    if (_activeQuiz != null) {
      return _buildQuizActiveView();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_activePolls.isEmpty) {
      return _buildLobbyWaitingState(isDark);
    }

    final filteredList = _filteredActivePolls;
    final unansweredPolls = filteredList
        .where((p) => !_votedPollIds.contains((p['id'] ?? '').toString()))
        .toList();
    final answeredPolls = filteredList
        .where((p) => _votedPollIds.contains((p['id'] ?? '').toString()))
        .toList();

    return Column(
      children: [
        const SizedBox(height: AppSizes.space12),
        _buildCategoryFilterHeader(isDark),
        Expanded(
          child: filteredList.isEmpty
              ? Center(
                  child: Text(
                    'No active polls in this category.',
                    style: TextStyle(
                      color: isDark ? Colors.white54 : Colors.black54,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(AppSizes.space16),
                  children: [
                    // Unanswered polls list first
                    ...unansweredPolls.map(
                      (poll) => _buildSingleActivePollCard(poll, isDark),
                    ),

                    // Answered polls wrapped in a collapsible expandable section
                    if (answeredPolls.isNotEmpty) ...[
                      const SizedBox(height: AppSizes.space8),
                      InkWell(
                        onTap: () {
                          setState(() {
                            _showAnsweredPolls = !_showAnsweredPolls;
                          });
                        },
                        borderRadius: BorderRadius.circular(
                          AppSizes.radiusCard,
                        ),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.04)
                                : Colors.black.withValues(alpha: 0.03),
                            borderRadius: BorderRadius.circular(
                              AppSizes.radiusCard,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.check_circle_rounded,
                                    color: AppColors.success,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Completed Responses (${answeredPolls.length})',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                              Icon(
                                _showAnsweredPolls
                                    ? Icons.keyboard_arrow_up_rounded
                                    : Icons.keyboard_arrow_down_rounded,
                                size: 20,
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (_showAnsweredPolls) ...[
                        const SizedBox(height: 12),
                        ...answeredPolls.map(
                          (poll) => _buildSingleActivePollCard(poll, isDark),
                        ),
                      ],
                    ],
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildCategoryFilterHeader(bool isDark) {
    final categories = _availableCategories;
    if (categories.length <= 1) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: categories.map((cat) {
            final isSelected = _selectedCategoryFilter == cat;
            final label = cat == 'ALL' ? 'All Polls' : cat.replaceAll('_', ' ');

            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                selected: isSelected,
                showCheckmark: false,
                label: Text(
                  label,
                  style: TextStyle(
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    fontSize: 12,
                    letterSpacing: 0.2,
                    color: isSelected
                        ? Colors.white
                        : (isDark ? Colors.white70 : Colors.black87),
                  ),
                ),
                selectedColor: AppColors.primary,
                backgroundColor: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.black.withValues(alpha: 0.04),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                side: BorderSide(
                  color: isSelected
                      ? AppColors.primary
                      : (isDark ? Colors.white12 : Colors.black12),
                ),
                onSelected: (val) {
                  if (val) {
                    setState(() {
                      _selectedCategoryFilter = cat;
                    });
                  }
                },
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildSingleActivePollCard(Map<String, dynamic> poll, bool isDark) {
    final pollId = (poll['id'] ?? '').toString();
    final title = (poll['title'] ?? 'Live Poll').toString();
    final type = (poll['type'] ?? 'multiple_choice').toString();
    final hasVoted = _votedPollIds.contains(pollId);
    final isEditing = _editingPollIds.contains(pollId);

    String typeLabel = 'POLL';
    IconData typeIcon = Icons.poll_rounded;
    if (type == 'multiple_choice') {
      typeLabel = 'MULTIPLE CHOICE';
      typeIcon = Icons.list_alt_rounded;
    } else if (type == 'rating') {
      typeLabel = 'STAR RATING';
      typeIcon = Icons.star_rate_rounded;
    } else if (type == 'word_cloud') {
      typeLabel = 'WORD CLOUD';
      typeIcon = Icons.cloud_outlined;
    } else if (type == 'open_text') {
      typeLabel = 'OPEN TEXT';
      typeIcon = Icons.text_snippet_outlined;
    } else if (type == 'ranking') {
      typeLabel = 'RANKING';
      typeIcon = Icons.format_list_numbered_rounded;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: AppSizes.space20),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.035) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: (hasVoted && !isEditing)
              ? AppColors.success.withValues(alpha: 0.3)
              : (isDark
                    ? Colors.white.withValues(alpha: 0.1)
                    : Colors.black.withValues(alpha: 0.08)),
          width: (hasVoted && !isEditing) ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.3)
                : AppColors.primary.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Tag Bar (Category Type & Answered Badge)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(typeIcon, size: 12, color: AppColors.primary),
                        const SizedBox(width: 4),
                        Text(
                          typeLabel,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (hasVoted && !isEditing)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: AppColors.success.withValues(alpha: 0.3),
                        ),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.check_circle_rounded,
                            size: 13,
                            color: AppColors.success,
                          ),
                          SizedBox(width: 5),
                          Text(
                            'ANSWERED',
                            style: TextStyle(
                              color: AppColors.success,
                              fontWeight: FontWeight.w800,
                              fontSize: 10,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),

              // Question Title
              Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  height: 1.3,
                  letterSpacing: -0.3,
                  color: isDark ? Colors.white : AppColors.textPrimaryLight,
                ),
              ),
              const SizedBox(height: 20),

              // Card Content: Results (with edit option) or Input Form
              if (hasVoted && !isEditing) ...[
                _buildPollResultsViewForPoll(poll),
                const SizedBox(height: 14),
                Center(
                  child: TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _editingPollIds.add(pollId);
                      });
                    },
                    icon: const Icon(Icons.edit_note_rounded, size: 16),
                    label: const Text(
                      'Change My Response',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.primary,
                    ),
                  ),
                ),
              ] else ...[
                _buildPollFormForPoll(poll),
                const SizedBox(height: 20),
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    gradient: const LinearGradient(
                      colors: AppColors.primaryGradient,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.3),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16.0),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: () => _submitVoteForPoll(poll),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          isEditing ? 'Update Response' : 'Submit Response',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          isEditing
                              ? Icons.check_circle_outline_rounded
                              : Icons.arrow_forward_rounded,
                          size: 18,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResultsChart(String type, Map<String, dynamic> results) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    switch (type) {
      case 'multiple_choice':
        final options = results['options'] as List? ?? [];
        int maxVotes = 0;
        for (var opt in options) {
          final v = opt['votes'] as int? ?? 0;
          if (v > maxVotes) maxVotes = v;
        }

        return Column(
          children: options.map((opt) {
            final text = opt['optionText'] as String? ?? '';
            final percentage = opt['percentage'] as int? ?? 0;
            final votes = opt['votes'] as int? ?? 0;
            final isLeading = votes == maxVotes && maxVotes > 0;

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isLeading
                    ? AppColors.primary.withValues(alpha: isDark ? 0.08 : 0.04)
                    : (isDark
                          ? Colors.white.withValues(alpha: 0.02)
                          : Colors.black.withValues(alpha: 0.02)),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isLeading
                      ? AppColors.primary.withValues(alpha: 0.3)
                      : Colors.transparent,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          text,
                          style: TextStyle(
                            fontWeight: isLeading
                                ? FontWeight.w800
                                : FontWeight.w600,
                            fontSize: 14,
                            color: isDark
                                ? Colors.white
                                : AppColors.textPrimaryLight,
                          ),
                        ),
                      ),
                      Text(
                        '$percentage% ($votes)',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          color: isLeading
                              ? AppColors.primary
                              : (isDark ? Colors.white60 : Colors.black54),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: percentage / 100,
                      backgroundColor: isDark
                          ? Colors.white10
                          : Colors.black.withValues(alpha: 0.06),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        isLeading
                            ? AppColors.primary
                            : AppColors.primary.withValues(alpha: 0.45),
                      ),
                      minHeight: 10,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        );

      case 'rating':
        final average = results['average'] as num? ?? 0.0;
        return Column(
          children: [
            Text(
              '${average.toStringAsFixed(1)} / 5 Stars',
              style: const TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.w900,
                color: AppColors.primary,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: AppSizes.space12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                final starVal = index + 1;
                return Icon(
                  starVal <= average.round()
                      ? Icons.star_rounded
                      : Icons.star_border_rounded,
                  color: Colors.amber,
                  size: 40,
                );
              }),
            ),
          ],
        );

      case 'word_cloud':
        final words = results['words'] as List? ?? [];
        if (words.isEmpty) {
          return const Text(
            'No responses yet.',
            style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          );
        }
        return Wrap(
          spacing: AppSizes.space8,
          runSpacing: AppSizes.space8,
          alignment: WrapAlignment.center,
          children: words.map((w) {
            final text = w['text'] as String? ?? '';
            final val = w['value'] as int? ?? 1;
            final size = 12.0 + (val * 2.0).clamp(0, 18);
            return Chip(
              backgroundColor: AppColors.primary.withValues(alpha: 0.12),
              side: BorderSide(color: AppColors.primary.withValues(alpha: 0.2)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSizes.radiusBadge),
              ),
              label: Text(
                '$text ($val)',
                style: TextStyle(
                  fontSize: size,
                  color: isDark ? Colors.white : AppColors.textPrimaryLight,
                  fontWeight: FontWeight.bold,
                ),
              ),
            );
          }).toList(),
        );

      case 'open_text':
        final responses = results['responses'] as List? ?? [];
        if (responses.isEmpty) {
          return Text(
            'No responses yet.',
            style: TextStyle(
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          );
        }
        return Column(
          children: responses.map((r) {
            final text = r['text'] as String? ?? '';
            final author = r['author'] as String? ?? 'Anonymous';
            return Card(
              margin: const EdgeInsets.only(bottom: AppSizes.space12),
              child: ListTile(
                title: Text(
                  text,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'By $author',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        );

      case 'ranking':
        final options = results['options'] as List? ?? [];
        return Column(
          children: List.generate(options.length, (idx) {
            final opt = options[idx];
            final text = opt['optionText'] as String? ?? '';
            final score = opt['score'] as int? ?? 0;
            return Card(
              margin: const EdgeInsets.only(bottom: AppSizes.space12),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                  child: Text(
                    '${idx + 1}',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                title: Text(
                  text,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                trailing: Text(
                  '$score pts',
                  style: TextStyle(
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            );
          }),
        );

      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildQuizActiveView() {
    final title = _activeQuiz!['title'] as String? ?? 'Quiz Question';
    final options = _activeQuiz!['options'] as List? ?? [];
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final letters = ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H'];

    final timeColor = _quizTimeRemaining > 10
        ? AppColors.success
        : (_quizTimeRemaining > 5 ? AppColors.warning : AppColors.error);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Quiz Header Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.purpleAccent.withValues(
                alpha: isDark ? 0.12 : 0.08,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.purpleAccent.withValues(alpha: 0.3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppColors.purpleAccent.withValues(
                              alpha: 0.2,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.emoji_events_rounded,
                            color: AppColors.purpleAccent,
                            size: 16,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'LIVE QUIZ CHALLENGE',
                          style: TextStyle(
                            color: AppColors.purpleAccent,
                            fontWeight: FontWeight.w900,
                            fontSize: 11,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: timeColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: timeColor.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.timer_rounded, size: 14, color: timeColor),
                          const SizedBox(width: 6),
                          Text(
                            '${_quizTimeRemaining}s left',
                            style: TextStyle(
                              color: timeColor,
                              fontWeight: FontWeight.w900,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: (_quizTimeRemaining / 15.0).clamp(0.0, 1.0),
                    minHeight: 6,
                    backgroundColor: isDark ? Colors.white10 : Colors.black12,
                    valueColor: AlwaysStoppedAnimation<Color>(timeColor),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Question Title
          Text(
            title,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              height: 1.3,
              letterSpacing: -0.4,
              color: isDark ? Colors.white : AppColors.textPrimaryLight,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Answer quickly for higher speed bonus points (up to 1000 pts)',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white54 : Colors.black54,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 24),

          if (_hasAnsweredQuiz) ...[
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.04)
                    : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppColors.success.withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_circle_rounded,
                      color: AppColors.success,
                      size: 48,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Answer Submitted!',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Your answer was recorded. Waiting for the timer to finish and leaderboard reveal.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.white60 : Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            ...List.generate(options.length, (idx) {
              final opt = options[idx];
              final id = (opt['id'] ?? '').toString();
              final letter = idx < letters.length ? letters[idx] : '${idx + 1}';
              final label = (opt['optionText'] ?? opt['option_text'] ?? '')
                  .toString();

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                child: InkWell(
                  onTap: () => _submitQuizAnswer(id),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 16,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.04)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark ? Colors.white12 : Colors.black12,
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(
                            alpha: isDark ? 0.2 : 0.03,
                          ),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.purpleAccent.withValues(
                              alpha: 0.12,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              letter,
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 13,
                                color: AppColors.purpleAccent,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            label,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: isDark
                                  ? Colors.white
                                  : AppColors.textPrimaryLight,
                            ),
                          ),
                        ),
                        const Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 14,
                          color: Colors.grey,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildPollFormForPoll(Map<String, dynamic> poll) {
    final pollId = (poll['id'] ?? '').toString();
    final type = (poll['type'] ?? 'multiple_choice').toString();
    final options = poll['options'] as List? ?? [];
    final isDark = Theme.of(context).brightness == Brightness.dark;

    switch (type) {
      case 'multiple_choice':
        _selectedOptionIdsMap.putIfAbsent(pollId, () => {});
        final selectedSet = _selectedOptionIdsMap[pollId]!;
        final letters = ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H'];

        return Column(
          children: List.generate(options.length, (idx) {
            final opt = options[idx];
            final id = (opt['id'] ?? '').toString();
            final isSelected = selectedSet.contains(id);
            final optionLabel = (opt['optionText'] ?? opt['option_text'] ?? '')
                .toString();
            final letter = idx < letters.length ? letters[idx] : '${idx + 1}';

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              child: InkWell(
                onTap: () {
                  setState(() {
                    selectedSet.clear();
                    selectedSet.add(id);
                  });
                },
                borderRadius: BorderRadius.circular(14),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primary.withValues(
                            alpha: isDark ? 0.16 : 0.1,
                          )
                        : (isDark
                              ? Colors.white.withValues(alpha: 0.03)
                              : Colors.black.withValues(alpha: 0.02)),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.primary
                          : (isDark ? Colors.white12 : Colors.black12),
                      width: isSelected ? 2.0 : 1.0,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isSelected
                              ? AppColors.primary
                              : (isDark
                                    ? Colors.white.withValues(alpha: 0.08)
                                    : Colors.black.withValues(alpha: 0.06)),
                        ),
                        child: Center(
                          child: Text(
                            letter,
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                              color: isSelected
                                  ? Colors.white
                                  : (isDark ? Colors.white70 : Colors.black87),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          optionLabel,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: isSelected
                                ? FontWeight.w800
                                : FontWeight.w500,
                            color: isSelected
                                ? AppColors.primary
                                : (isDark
                                      ? Colors.white
                                      : AppColors.textPrimaryLight),
                          ),
                        ),
                      ),
                      if (isSelected)
                        const Icon(
                          Icons.check_circle_rounded,
                          color: AppColors.primary,
                          size: 22,
                        ),
                    ],
                  ),
                ),
              ),
            );
          }),
        );

      case 'word_cloud':
      case 'open_text':
        _textResponseCtrlsMap.putIfAbsent(
          pollId,
          () => TextEditingController(),
        );
        final ctrl = _textResponseCtrlsMap[pollId]!;
        return TextField(
          controller: ctrl,
          decoration: InputDecoration(
            labelText: AppStrings.wordCloudHint,
            prefixIcon: const Icon(Icons.edit_note_rounded),
            hintText: type == 'word_cloud'
                ? 'Enter a single word...'
                : 'Enter your open thoughts...',
          ),
          maxLength: type == 'word_cloud' ? 20 : 250,
        );

      case 'rating':
        _ratingValuesMap.putIfAbsent(pollId, () => 3.0);
        final currentRating = _ratingValuesMap[pollId]!;
        final ratingLabels = ['Poor', 'Fair', 'Good', 'Great', 'Excellent!'];
        final rIdx = (currentRating.round() - 1).clamp(0, 4);

        return Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.15),
                ),
              ),
              child: Column(
                children: [
                  Text(
                    '${currentRating.toInt()} / 5 Stars - ${ratingLabels[rIdx]}',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: List.generate(5, (index) {
                      final starVal = (index + 1).toDouble();
                      final isSelected = starVal <= currentRating;
                      return InkWell(
                        onTap: () {
                          setState(() {
                            _ratingValuesMap[pollId] = starVal;
                          });
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Colors.amber.withValues(alpha: 0.15)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            isSelected
                                ? Icons.star_rounded
                                : Icons.star_border_rounded,
                            color: isSelected
                                ? Colors.amber
                                : Colors.grey.shade400,
                            size: 34,
                          ),
                        ),
                      );
                    }),
                  ),
                ],
              ),
            ),
          ],
        );

      case 'ranking':
        _rankingOptionsMap.putIfAbsent(
          pollId,
          () => List<Map<String, dynamic>>.from(options),
        );
        final rankingList = _rankingOptionsMap[pollId]!;

        return Column(
          children: [
            Text(
              AppStrings.rankingGuide,
              style: TextStyle(
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: AppSizes.space12),
            ReorderableListView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: List.generate(rankingList.length, (idx) {
                final opt = rankingList[idx];
                final optionLabel =
                    (opt['optionText'] ?? opt['option_text'] ?? '').toString();
                return Card(
                  key: ValueKey((opt['id'] ?? idx).toString()),
                  margin: const EdgeInsets.only(bottom: AppSizes.space12),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppColors.primary.withValues(
                        alpha: 0.15,
                      ),
                      child: Text(
                        '${idx + 1}',
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Text(
                      optionLabel,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    trailing: const Icon(Icons.drag_handle_rounded),
                  ),
                );
              }),
              onReorder: (oldIdx, newIdx) {
                setState(() {
                  if (newIdx > oldIdx) newIdx -= 1;
                  final item = rankingList.removeAt(oldIdx);
                  rankingList.insert(newIdx, item);
                });
              },
            ),
          ],
        );

      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildPollResultsViewForPoll(Map<String, dynamic> poll) {
    final pollId = (poll['id'] ?? '').toString();
    final type = (poll['type'] ?? 'multiple_choice').toString();
    final results = poll['results'] as Map<String, dynamic>?;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (results == null) {
      _fetchPollResults(pollId);
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: AppColors.primary),
              SizedBox(height: AppSizes.space16),
              Text(
                'Loading live results...',
                style: TextStyle(
                  color: Colors.grey,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final totalVotes = results['totalVotes'] as int? ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildResultsChart(type, results),
        const SizedBox(height: AppSizes.space20),
        Text(
          'Total Responses: $totalVotes',
          style: TextStyle(
            color: isDark
                ? AppColors.textSecondaryDark
                : AppColors.textSecondaryLight,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  void _submitVoteForPoll(Map<String, dynamic> poll) {
    if (_participant == null) return;
    final pollId = (poll['id'] ?? '').toString();
    final type = (poll['type'] ?? 'multiple_choice').toString();
    final selectedOptions = (_selectedOptionIdsMap[pollId] ?? {}).toList();
    final textCtrl = _textResponseCtrlsMap[pollId];
    final textResponse = textCtrl?.text.trim() ?? '';
    final ratingValue = _ratingValuesMap[pollId] ?? 3.0;
    final rankingOptions = _rankingOptionsMap[pollId] ?? [];

    if (type == 'multiple_choice' && selectedOptions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select an option before submitting'),
          backgroundColor: AppColors.warning,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if ((type == 'word_cloud' || type == 'open_text') && textResponse.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter your response before submitting'),
          backgroundColor: AppColors.warning,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() {
      _votedPollIds.add(pollId);
      _editingPollIds.remove(pollId);
    });
    _cacheManager.saveVotedPollId(widget.accessCode, pollId);

    _socketClient.submitVote(
      pollId: pollId,
      participantId: (_participant?['id'] ?? '').toString(),
      optionIds: selectedOptions,
      textResponse: textResponse,
      ratingValue: ratingValue.round(),
      rankingIds: rankingOptions
          .map((o) => (o['id'] ?? '').toString())
          .toList(),
    );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(AppStrings.successVoteSubmit),
        backgroundColor: AppColors.success,
      ),
    );
  }

  void _fetchPollResults(String pollId) async {
    if (pollId.isEmpty || _fetchingResultsPollIds.contains(pollId)) return;
    _fetchingResultsPollIds.add(pollId);
    try {
      final res = await sl<PollRepository>().getPollResults(pollId);
      if (!mounted) return;
      setState(() {
        final idx = _activePolls.indexWhere(
          (p) => (p['id'] ?? '').toString() == pollId,
        );
        if (idx != -1) {
          _activePolls[idx]['results'] = res;
        }
      });
    } catch (_) {
    } finally {
      _fetchingResultsPollIds.remove(pollId);
    }
  }

  Widget _buildQaTabView() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: [
        // Question submission field
        Padding(
          padding: const EdgeInsets.all(AppSizes.space16),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _questionInputCtrl,
                  decoration: const InputDecoration(
                    hintText: AppStrings.askQuestionHint,
                  ),
                ),
              ),
              const SizedBox(width: AppSizes.space12),
              Container(
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(colors: AppColors.primaryGradient),
                ),
                child: IconButton(
                  icon: const Icon(Icons.send_rounded, color: Colors.white),
                  onPressed: _submitQuestion,
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: _questions.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.forum_outlined,
                        size: 48,
                        color: isDark ? Colors.white24 : Colors.black12,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'No questions asked yet',
                        style: TextStyle(
                          color: Colors.grey,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(AppSizes.space16),
                  itemCount: _questions.length,
                  itemBuilder: (context, index) {
                    final q = _questions[index];
                    final qId = (q['id'] ?? '').toString();
                    final author = q['authorName'] as String? ?? 'Anonymous';
                    final text = (q['text'] ?? '').toString();
                    final upvotes = q['upvotesCount'] as int? ?? 0;
                    final hasUpvoted = q['hasUpvoted'] as bool? ?? false;
                    final isPinned = q['isPinned'] as bool? ?? false;
                    final isAnswered = q['status'] == 'answered';
                    final isOptimistic = q['isOptimistic'] == true;

                    return Card(
                      color: isPinned
                          ? AppColors.primary.withValues(alpha: 0.06)
                          : (isAnswered
                                ? AppColors.success.withValues(alpha: 0.04)
                                : null),
                      margin: const EdgeInsets.only(bottom: AppSizes.space12),
                      shape: RoundedRectangleBorder(
                        side: BorderSide(
                          color: isPinned
                              ? AppColors.primary.withValues(alpha: 0.3)
                              : isAnswered
                              ? AppColors.success.withValues(alpha: 0.3)
                              : (isDark ? Colors.white10 : Colors.black12),
                          width: (isPinned || isAnswered) ? 1.5 : 1.0,
                        ),
                        borderRadius: BorderRadius.circular(
                          AppSizes.radiusCard,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Question header row
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (isPinned) ...[
                                  const Icon(
                                    Icons.push_pin,
                                    color: Colors.orange,
                                    size: 15,
                                  ),
                                  const SizedBox(width: 6),
                                ],
                                Expanded(
                                  child: Text(
                                    text,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                      color: isDark
                                          ? Colors.white
                                          : Colors.black87,
                                    ),
                                  ),
                                ),
                                if (isOptimistic)
                                  const Padding(
                                    padding: EdgeInsets.only(left: 8),
                                    child: SizedBox(
                                      width: 12,
                                      height: 12,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            // Author & status row
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 8,
                                  backgroundColor: AppColors.primary.withValues(
                                    alpha: 0.2,
                                  ),
                                  child: Text(
                                    author.isNotEmpty
                                        ? author[0].toUpperCase()
                                        : 'A',
                                    style: const TextStyle(
                                      fontSize: 8,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    'By $author • ${isOptimistic
                                        ? 'Sending...'
                                        : isAnswered
                                        ? ''
                                        : 'Active'}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ),
                                if (isAnswered)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.success.withValues(
                                        alpha: 0.12,
                                      ),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: const [
                                        Icon(
                                          Icons.check_circle_rounded,
                                          color: AppColors.success,
                                          size: 11,
                                        ),
                                        SizedBox(width: 4),
                                        Text(
                                          'ANSWERED',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w800,
                                            color: AppColors.success,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                // Upvote button
                                if (!isAnswered) ...[
                                  const SizedBox(width: 8),
                                  GestureDetector(
                                    onTap: isOptimistic
                                        ? null
                                        : () =>
                                              _upvoteQuestion(qId, hasUpvoted),
                                    child: Row(
                                      children: [
                                        Icon(
                                          hasUpvoted
                                              ? Icons.thumb_up_rounded
                                              : Icons.thumb_up_outlined,
                                          color: hasUpvoted
                                              ? AppColors.primary
                                              : Colors.grey,
                                          size: 15,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          '$upvotes',
                                          style: TextStyle(
                                            color: hasUpvoted
                                                ? AppColors.primary
                                                : Colors.grey,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            // Host answer section
                            if (isAnswered) ...[
                              const SizedBox(height: 10),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppColors.success.withValues(
                                    alpha: 0.08,
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: AppColors.success.withValues(
                                      alpha: 0.2,
                                    ),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: const [
                                        Icon(
                                          Icons.record_voice_over_rounded,
                                          color: AppColors.success,
                                          size: 13,
                                        ),
                                        SizedBox(width: 6),
                                        Text(
                                          'Host\'s Answer',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w800,
                                            color: AppColors.success,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      (q['answerText'] as String?)
                                                  ?.isNotEmpty ==
                                              true
                                          ? q['answerText'] as String
                                          : 'This question was addressed verbally.',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: isDark
                                            ? Colors.white70
                                            : Colors.black87,
                                        fontStyle:
                                            (q['answerText'] as String?)
                                                    ?.isNotEmpty ==
                                                true
                                            ? FontStyle.normal
                                            : FontStyle.italic,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
