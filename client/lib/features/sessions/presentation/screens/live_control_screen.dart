import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../../core/network/socket_client.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../polls/domain/repositories/poll_repository.dart';
import '../../../qa/domain/repositories/qa_repository.dart';
import '../../../quiz/domain/repositories/quiz_repository.dart';
import '../../domain/repositories/session_repository.dart';

class HostLiveControlScreen extends StatefulWidget {
  final String sessionId;
  const HostLiveControlScreen({super.key, required this.sessionId});

  @override
  State<HostLiveControlScreen> createState() => _HostLiveControlScreenState();
}

class _HostLiveControlScreenState extends State<HostLiveControlScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _socketClient = sl<SocketClient>();

  Map<String, dynamic>? _session;
  List<Map<String, dynamic>> _polls = [];
  List<Map<String, dynamic>> _questions = [];
  String? _activePollId;
  String? _activeQuizQuestionId;

  // Q&A Filtering
  String _qaFilter = 'all'; // 'all', 'unanswered', 'answered', 'pinned'

  // Announcement inputs
  final _announcementTitleCtrl = TextEditingController();
  final _announcementMsgCtrl = TextEditingController();

  // Socket subscription streams
  StreamSubscription? _votesSubscription;
  StreamSubscription? _questionsSubscription;
  StreamSubscription? _questionsStatusSubscription;
  StreamSubscription? _quizTimerSubscription;

  // Quiz timer tracking
  int _quizTimeRemaining = 0;
  final Map<String, int> _quizDurations = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    _loadInitialData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _announcementTitleCtrl.dispose();
    _announcementMsgCtrl.dispose();
    _votesSubscription?.cancel();
    _questionsSubscription?.cancel();
    _questionsStatusSubscription?.cancel();
    _quizTimerSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    try {
      final session = await sl<SessionRepository>().getSessionDetails(
        widget.sessionId,
      );
      final polls = await sl<PollRepository>().getSessionPolls(
        widget.sessionId,
      );
      final questions = await sl<QaRepository>().getSessionQuestions(
        widget.sessionId,
      );

      if (!mounted) return;

      setState(() {
        _session = session;
        _polls = polls;
        _questions = questions;
        _activePollId = session['active_poll_id'] as String?;
        _activeQuizQuestionId = session['active_quiz_question_id'] as String?;
      });

      // Join Socket Room
      _socketClient.connect();
      _socketClient.joinSession(
        (session['access_code'] ?? '').toString(),
        'host',
        'host',
      );

      // Bind Socket Events
      _votesSubscription = _socketClient.votesUpdatedStream.listen((data) {
        final pollId = data['pollId'] as String;
        final results = Map<String, dynamic>.from(data['results'] as Map);

        if (!mounted) return;
        setState(() {
          for (var p in _polls) {
            if (p['id'] == pollId) {
              p['results'] = results;
            }
          }
        });
      });

      _questionsSubscription = _socketClient.questionCreatedStream.listen((
        data,
      ) {
        final newQ = Map<String, dynamic>.from(data['question'] as Map);
        if (!mounted) return;
        setState(() {
          if (!_questions.any((q) => q['id'] == newQ['id'])) {
            _questions.insert(0, newQ);
          }
        });
      });

      _questionsStatusSubscription = _socketClient.questionStatusStream.listen((
        data,
      ) {
        final updatedQ = Map<String, dynamic>.from(data['question'] as Map);
        if (!mounted) return;
        setState(() {
          final index = _questions.indexWhere((q) => q['id'] == updatedQ['id']);
          if (index != -1) {
            _questions[index] = updatedQ;
          } else {
            _questions.insert(0, updatedQ);
          }
        });
      });

      _quizTimerSubscription = _socketClient.quizTimerStream.listen((data) {
        final event = (data['event'] ?? '').toString();
        final pollId = (data['pollId'] ?? '').toString();

        if (!mounted) return;
        setState(() {
          if (event == 'start') {
            _activeQuizQuestionId = pollId;
            _quizTimeRemaining =
                (data['durationSeconds'] as num?)?.toInt() ?? 15;
          } else if (event == 'tick') {
            _quizTimeRemaining = (data['remaining'] as num?)?.toInt() ?? 0;
          } else if (event == 'end') {
            _quizTimeRemaining = 0;
          }
        });
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading control panel: $e'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _activatePoll(String? pollId) {
    if (_session == null) return;
    _socketClient.activatePoll((_session?['id'] ?? '').toString(), pollId);
    setState(() {
      _activePollId = pollId;
      for (var p in _polls) {
        if (p['id'] == pollId) {
          p['status'] = 'active';
        }
      }
    });
  }

  void _deactivateActivePoll() {
    _activatePoll(null);
  }

  void _endPoll(String pollId) async {
    try {
      await sl<PollRepository>().updatePoll(pollId, {'status': 'ended'});
      if (!mounted) return;
      setState(() {
        for (var p in _polls) {
          if (p['id'] == pollId) {
            p['status'] = 'ended';
          }
        }
        if (_activePollId == pollId) {
          _activePollId = null;
        }
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to end poll: $e')));
    }
  }

  void _lockActivePoll() async {
    if (_activePollId == null) return;
    try {
      await sl<PollRepository>().updatePoll(_activePollId!, {
        'status': 'locked',
      });
      if (!mounted) return;
      setState(() {
        for (var p in _polls) {
          if (p['id'] == _activePollId) {
            p['status'] = 'locked';
          }
        }
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to lock poll: $e'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _updateQuestionStatus(String questionId, String status) {
    if (_session == null) return;
    _socketClient.updateQuestionStatus(
      sessionId: _session!['id'] as String,
      questionId: questionId,
      status: status,
    );
  }

  void _toggleQuestionPin(String questionId, bool currentPin) {
    if (_session == null) return;
    _socketClient.updateQuestionStatus(
      sessionId: _session!['id'] as String,
      questionId: questionId,
      isPinned: !currentPin,
    );
  }

  int _getQuizDuration(Map<String, dynamic> quiz) {
    final pollId = (quiz['id'] ?? '').toString();
    if (_quizDurations.containsKey(pollId)) {
      return _quizDurations[pollId]!;
    }
    final settings = quiz['settings'];
    if (settings is Map && settings['timeLimit'] is num) {
      return (settings['timeLimit'] as num).toInt();
    }
    return 15;
  }

  void _showSetTimerDialog(Map<String, dynamic> quiz) {
    final pollId = (quiz['id'] ?? '').toString();
    final quizTitle = (quiz['title'] ?? 'Quiz Question').toString();
    int currentDuration = _getQuizDuration(quiz);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final options = [10, 15, 20, 30, 45, 60, 90, 120];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        int selected = currentDuration;
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceDark : Colors.white,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.purpleAccent.withValues(
                                alpha: 0.12,
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.timer_rounded,
                              color: AppColors.purpleAccent,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Set Quiz Timer',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: isDark
                                  ? Colors.white
                                  : AppColors.textPrimaryLight,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Select countdown duration for "$quizTitle".',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.white60 : Colors.black54,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 20),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: options.map((sec) {
                      final isChosen = selected == sec;
                      return ChoiceChip(
                        label: Text('${sec}s'),
                        selected: isChosen,
                        selectedColor: AppColors.purpleAccent,
                        labelStyle: TextStyle(
                          color: isChosen
                              ? Colors.white
                              : (isDark ? Colors.white70 : Colors.black87),
                          fontWeight: isChosen
                              ? FontWeight.w800
                              : FontWeight.w600,
                        ),
                        backgroundColor: isDark
                            ? Colors.white.withValues(alpha: 0.05)
                            : Colors.black.withValues(alpha: 0.04),
                        onSelected: (val) {
                          if (val) {
                            setDialogState(() {
                              selected = sec;
                            });
                          }
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _quizDurations[pollId] = selected;
                        });
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Timer set to ${selected}s for this quiz question',
                            ),
                            backgroundColor: AppColors.purpleAccent,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.purpleAccent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'Apply Timer',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _startQuizQuestion(
    String pollId,
    int timerLimit, {
    bool isRestart = false,
  }) {
    if (_session == null) return;
    final messenger = ScaffoldMessenger.of(context);
    sl<QuizRepository>()
        .activateQuizQuestion(_session!['id'] as String, pollId, timerLimit)
        .then((_) {
          _socketClient.startQuizTimer(
            _session!['id'] as String,
            pollId,
            timerLimit,
          );
          if (!mounted) return;
          setState(() {
            _activeQuizQuestionId = pollId;
            _quizTimeRemaining = timerLimit;
          });
          messenger.showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(
                    isRestart ? Icons.replay_rounded : Icons.timer_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      isRestart
                          ? 'Timer restarted for ${timerLimit}s! Previous participant responses are preserved.'
                          : 'Quiz timer started for ${timerLimit}s!',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              backgroundColor: isRestart
                  ? const Color(0xFF8B5CF6)
                  : AppColors.success,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        })
        .catchError((e) {
          if (!mounted) return;
          messenger.showSnackBar(
            SnackBar(
              content: Text('Failed to start quiz: $e'),
              backgroundColor: AppColors.error,
              behavior: SnackBarBehavior.floating,
            ),
          );
        });
  }

  void _stopQuizQuestion(String pollId) {
    if (_session == null) return;
    _socketClient.stopQuizTimer(_session!['id'] as String, pollId);
    if (!mounted) return;
    setState(() {
      _quizTimeRemaining = 0;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Quiz timer stopped.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _broadcastAnnouncement() {
    if (_session == null) return;
    final title = _announcementTitleCtrl.text.trim();
    final message = _announcementMsgCtrl.text.trim();

    if (title.isEmpty || message.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill out both alert title and message body'),
          backgroundColor: AppColors.warning,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    _socketClient.sendAnnouncement(_session!['id'] as String, title, message);

    _announcementTitleCtrl.clear();
    _announcementMsgCtrl.clear();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.campaign_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Alert Broadcast Sent!',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Pushed to all active participants in real-time.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.9),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _addNewPollDialog() {
    final titleCtrl = TextEditingController();
    String type = 'multiple_choice';
    final optCtrls = [TextEditingController(), TextEditingController()];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            final screenHeight = MediaQuery.of(context).size.height;

            final pollTypes = [
              {
                'value': 'multiple_choice',
                'label': 'Multiple\nChoice',
                'icon': Icons.list_alt_rounded,
                'color': AppColors.primary,
              },
              {
                'value': 'word_cloud',
                'label': 'Word\nCloud',
                'icon': Icons.cloud_rounded,
                'color': const Color(0xFF06B6D4),
              },
              {
                'value': 'rating',
                'label': 'Star\nRating',
                'icon': Icons.star_rounded,
                'color': Colors.amber,
              },
              {
                'value': 'open_text',
                'label': 'Open\nText',
                'icon': Icons.notes_rounded,
                'color': AppColors.success,
              },
              {
                'value': 'ranking',
                'label': 'Ranking\nList',
                'icon': Icons.sort_rounded,
                'color': AppColors.purpleAccent,
              },
            ];

            return Container(
              height: screenHeight * 0.92,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1A1B2E) : Colors.white,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
              ),
              child: Column(
                children: [
                  // Drag Handle
                  const SizedBox(height: 12),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.black12,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Header
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              const Text(
                                'Create Live Poll',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),
                  Divider(
                    height: 1,
                    color: isDark
                        ? Colors.white10
                        : Colors.black.withValues(alpha: 0.06),
                  ),

                  // Scrollable Content
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Question title input
                          Text(
                            'POLL QUESTION',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white38 : Colors.black38,
                              letterSpacing: 1.0,
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: titleCtrl,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                            decoration: InputDecoration(
                              hintText: 'What topic should we cover next?',
                              hintStyle: TextStyle(
                                color: isDark ? Colors.white30 : Colors.black26,
                                fontWeight: FontWeight.normal,
                              ),
                              prefixIcon: Container(
                                margin: const EdgeInsets.all(10),
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(
                                    alpha: 0.1,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.help_outline_rounded,
                                  color: AppColors.primary,
                                  size: 16,
                                ),
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide(
                                  color: isDark
                                      ? Colors.white12
                                      : Colors.black12,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide(
                                  color: isDark
                                      ? Colors.white12
                                      : Colors.black12,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(
                                  color: AppColors.primary,
                                  width: 2,
                                ),
                              ),
                              filled: true,
                              fillColor: isDark
                                  ? Colors.white.withValues(alpha: 0.04)
                                  : Colors.black.withValues(alpha: 0.02),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                            ),
                          ),

                          const SizedBox(height: 28),

                          // Poll type selector
                          Text(
                            'POLL FORMAT',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white38 : Colors.black38,
                              letterSpacing: 1.0,
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            height: 100,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: pollTypes.length,
                              itemBuilder: (ctx, idx) {
                                final pt = pollTypes[idx];
                                final isSelected = type == pt['value'];
                                final color = pt['color'] as Color;
                                return Padding(
                                  padding: EdgeInsets.only(
                                    right: idx < pollTypes.length - 1 ? 10 : 0,
                                  ),
                                  child: GestureDetector(
                                    onTap: () => setDialogState(
                                      () => type = pt['value'] as String,
                                    ),
                                    child: AnimatedContainer(
                                      duration: const Duration(
                                        milliseconds: 200,
                                      ),
                                      width: 84,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 12,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? color.withValues(
                                                alpha: isDark ? 0.18 : 0.1,
                                              )
                                            : (isDark
                                                  ? Colors.white.withValues(
                                                      alpha: 0.04,
                                                    )
                                                  : Colors.black.withValues(
                                                      alpha: 0.02,
                                                    )),
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: isSelected
                                              ? color
                                              : (isDark
                                                    ? Colors.white12
                                                    : Colors.black12),
                                          width: isSelected ? 2 : 1,
                                        ),
                                        boxShadow: isSelected
                                            ? [
                                                BoxShadow(
                                                  color: color.withValues(
                                                    alpha: 0.2,
                                                  ),
                                                  blurRadius: 8,
                                                  offset: const Offset(0, 3),
                                                ),
                                              ]
                                            : null,
                                      ),
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            pt['icon'] as IconData,
                                            color: isSelected
                                                ? color
                                                : (isDark
                                                      ? Colors.white38
                                                      : Colors.black38),
                                            size: 26,
                                          ),
                                          const SizedBox(height: 7),
                                          Text(
                                            pt['label'] as String,
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: isSelected
                                                  ? FontWeight.w800
                                                  : FontWeight.w600,
                                              color: isSelected
                                                  ? color
                                                  : (isDark
                                                        ? Colors.white54
                                                        : Colors.black45),
                                              height: 1.2,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),

                          if (type == 'multiple_choice' ||
                              type == 'ranking') ...[
                            const SizedBox(height: 28),
                            Row(
                              children: [
                                Text(
                                  'ANSWER OPTIONS',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: isDark
                                        ? Colors.white38
                                        : Colors.black38,
                                    letterSpacing: 1.0,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  '${optCtrls.length} options',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: isDark
                                        ? Colors.white38
                                        : Colors.black38,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            ...List.generate(optCtrls.length, (index) {
                              final letters = [
                                'A',
                                'B',
                                'C',
                                'D',
                                'E',
                                'F',
                                'G',
                                'H',
                              ];
                              final letter = index < letters.length
                                  ? letters[index]
                                  : '${index + 1}';
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 34,
                                      height: 34,
                                      decoration: BoxDecoration(
                                        color: AppColors.primary.withValues(
                                          alpha: 0.12,
                                        ),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Center(
                                        child: Text(
                                          letter,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 13,
                                            color: AppColors.primary,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: TextField(
                                        controller: optCtrls[index],
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                        ),
                                        decoration: InputDecoration(
                                          hintText: 'Option $letter…',
                                          hintStyle: TextStyle(
                                            color: isDark
                                                ? Colors.white24
                                                : Colors.black26,
                                          ),
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            borderSide: BorderSide(
                                              color: isDark
                                                  ? Colors.white12
                                                  : Colors.black12,
                                            ),
                                          ),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            borderSide: BorderSide(
                                              color: isDark
                                                  ? Colors.white12
                                                  : Colors.black12,
                                            ),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            borderSide: const BorderSide(
                                              color: AppColors.primary,
                                              width: 2,
                                            ),
                                          ),
                                          filled: true,
                                          fillColor: isDark
                                              ? Colors.white.withValues(
                                                  alpha: 0.03,
                                                )
                                              : Colors.black.withValues(
                                                  alpha: 0.02,
                                                ),
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                horizontal: 14,
                                                vertical: 12,
                                              ),
                                        ),
                                      ),
                                    ),
                                    if (optCtrls.length > 2)
                                      Padding(
                                        padding: const EdgeInsets.only(left: 8),
                                        child: InkWell(
                                          onTap: () => setDialogState(
                                            () => optCtrls.removeAt(index),
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          child: Container(
                                            padding: const EdgeInsets.all(7),
                                            decoration: BoxDecoration(
                                              color: AppColors.error.withValues(
                                                alpha: 0.08,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: const Icon(
                                              Icons.close_rounded,
                                              color: AppColors.error,
                                              size: 16,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              );
                            }),
                            const SizedBox(height: 6),
                            GestureDetector(
                              onTap: () => setDialogState(
                                () => optCtrls.add(TextEditingController()),
                              ),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 13,
                                ),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: AppColors.primary.withValues(
                                      alpha: 0.35,
                                    ),
                                    style: BorderStyle.solid,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                  color: AppColors.primary.withValues(
                                    alpha: 0.03,
                                  ),
                                ),
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.add_rounded,
                                      color: AppColors.primary,
                                      size: 18,
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      'Add Another Option',
                                      style: TextStyle(
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],

                          const SizedBox(height: 36),

                          // Submit button
                          Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: AppColors.primaryGradient,
                              ),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary.withValues(
                                    alpha: 0.35,
                                  ),
                                  blurRadius: 20,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              onPressed: () async {
                                final title = titleCtrl.text.trim();
                                if (title.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Please enter a question title',
                                      ),
                                      backgroundColor: AppColors.error,
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                  return;
                                }
                                if (_session == null) return;

                                List<Map<String, dynamic>>? optsList;
                                if (type == 'multiple_choice' ||
                                    type == 'ranking') {
                                  optsList = optCtrls
                                      .where((c) => c.text.trim().isNotEmpty)
                                      .map((c) => {'optionText': c.text.trim()})
                                      .toList();
                                  if (optsList.length < 2) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Please provide at least 2 non-empty options',
                                        ),
                                        backgroundColor: AppColors.error,
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                    return;
                                  }
                                }

                                final messenger = ScaffoldMessenger.of(context);
                                final navigator = Navigator.of(dialogCtx);

                                try {
                                  await sl<PollRepository>().createPoll(
                                    sessionId: _session!['id'] as String,
                                    title: title,
                                    type: type,
                                    options: optsList,
                                  );
                                  navigator.pop();
                                  await _loadInitialData();
                                  messenger.showSnackBar(
                                    const SnackBar(
                                      content: Row(
                                        children: [
                                          Icon(
                                            Icons.check_circle_rounded,
                                            color: Colors.white,
                                            size: 16,
                                          ),
                                          SizedBox(width: 8),
                                          Text(
                                            'Live poll created successfully!',
                                          ),
                                        ],
                                      ),
                                      backgroundColor: AppColors.success,
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                } catch (e) {
                                  messenger.showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Failed to create poll: $e',
                                      ),
                                      backgroundColor: AppColors.error,
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                }
                              },
                              icon: const Icon(Icons.poll_rounded, size: 18),
                              label: const Text(
                                'Create Live Poll',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _addNewQuizDialog() {
    final titleCtrl = TextEditingController();
    final optCtrls = [
      TextEditingController(),
      TextEditingController(),
      TextEditingController(),
      TextEditingController(),
    ];
    int correctIndex = 0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            final screenHeight = MediaQuery.of(context).size.height;

            return Container(
              height: screenHeight * 0.92,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1A1B2E) : Colors.white,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
              ),
              child: Column(
                children: [
                  // Drag Handle
                  const SizedBox(height: 12),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.black12,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Header
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF8B5CF6), Color(0xFFEC4899)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.purpleAccent.withValues(
                                  alpha: 0.35,
                                ),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.emoji_events_rounded,
                            color: Colors.white,
                            size: 26,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Add Quiz Question',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              Text(
                                'Scored timed question with correct answer',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isDark
                                      ? Colors.white54
                                      : Colors.black45,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.close_rounded,
                            color: isDark ? Colors.white38 : Colors.black38,
                          ),
                          onPressed: () => Navigator.pop(dialogCtx),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Timer hint banner
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.purpleAccent.withValues(
                          alpha: isDark ? 0.12 : 0.07,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.purpleAccent.withValues(alpha: 0.25),
                        ),
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.timer_rounded,
                            color: AppColors.purpleAccent,
                            size: 16,
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'A 15-second timer starts automatically when you launch this question live',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.purpleAccent,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),
                  Divider(
                    height: 1,
                    color: isDark
                        ? Colors.white10
                        : Colors.black.withValues(alpha: 0.06),
                  ),

                  // Scrollable content
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'QUIZ QUESTION',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white38 : Colors.black38,
                              letterSpacing: 1.0,
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: titleCtrl,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 2,
                            decoration: InputDecoration(
                              hintText:
                                  'e.g. Which keyword defines an immutable variable in Dart?',
                              hintStyle: TextStyle(
                                color: isDark ? Colors.white30 : Colors.black26,
                                fontWeight: FontWeight.normal,
                              ),
                              prefixIcon: Padding(
                                padding: const EdgeInsets.only(bottom: 28),
                                child: Container(
                                  margin: const EdgeInsets.all(10),
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: AppColors.purpleAccent.withValues(
                                      alpha: 0.1,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.help_outline_rounded,
                                    color: AppColors.purpleAccent,
                                    size: 16,
                                  ),
                                ),
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide(
                                  color: isDark
                                      ? Colors.white12
                                      : Colors.black12,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide(
                                  color: isDark
                                      ? Colors.white12
                                      : Colors.black12,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(
                                  color: AppColors.purpleAccent,
                                  width: 2,
                                ),
                              ),
                              filled: true,
                              fillColor: isDark
                                  ? Colors.white.withValues(alpha: 0.04)
                                  : Colors.black.withValues(alpha: 0.02),
                              contentPadding: const EdgeInsets.fromLTRB(
                                16,
                                14,
                                16,
                                14,
                              ),
                            ),
                          ),

                          const SizedBox(height: 28),

                          Row(
                            children: [
                              Text(
                                'ANSWER OPTIONS',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: isDark
                                      ? Colors.white38
                                      : Colors.black38,
                                  letterSpacing: 1.0,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.success.withValues(
                                    alpha: 0.1,
                                  ),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(
                                      Icons.check_circle_rounded,
                                      color: AppColors.success,
                                      size: 10,
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      'Tap ○ to mark correct',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: AppColors.success,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          ...List.generate(optCtrls.length, (idx) {
                            final isSelected = correctIndex == idx;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? AppColors.success.withValues(
                                          alpha: isDark ? 0.12 : 0.06,
                                        )
                                      : (isDark
                                            ? Colors.white.withValues(
                                                alpha: 0.03,
                                              )
                                            : Colors.black.withValues(
                                                alpha: 0.02,
                                              )),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: isSelected
                                        ? AppColors.success.withValues(
                                            alpha: 0.5,
                                          )
                                        : (isDark
                                              ? Colors.white10
                                              : Colors.black.withValues(
                                                  alpha: 0.08,
                                                )),
                                    width: isSelected ? 1.5 : 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    GestureDetector(
                                      onTap: () => setDialogState(
                                        () => correctIndex = idx,
                                      ),
                                      child: AnimatedContainer(
                                        duration: const Duration(
                                          milliseconds: 200,
                                        ),
                                        width: 28,
                                        height: 28,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: isSelected
                                              ? AppColors.success
                                              : Colors.transparent,
                                          border: Border.all(
                                            color: isSelected
                                                ? AppColors.success
                                                : (isDark
                                                      ? Colors.white30
                                                      : Colors.black26),
                                            width: 2,
                                          ),
                                        ),
                                        child: isSelected
                                            ? const Icon(
                                                Icons.check_rounded,
                                                size: 16,
                                                color: Colors.white,
                                              )
                                            : null,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: TextField(
                                        controller: optCtrls[idx],
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: isSelected
                                              ? FontWeight.w700
                                              : FontWeight.w500,
                                          color: isSelected
                                              ? AppColors.success
                                              : (isDark
                                                    ? Colors.white
                                                    : Colors.black87),
                                        ),
                                        decoration: InputDecoration(
                                          hintText: 'Option ${idx + 1}',
                                          hintStyle: TextStyle(
                                            color: isDark
                                                ? Colors.white24
                                                : Colors.black26,
                                          ),
                                          border: InputBorder.none,
                                          contentPadding: EdgeInsets.zero,
                                          isDense: true,
                                        ),
                                      ),
                                    ),
                                    if (isSelected)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.success.withValues(
                                            alpha: 0.15,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                        child: const Text(
                                          'CORRECT',
                                          style: TextStyle(
                                            fontSize: 9,
                                            color: AppColors.success,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            );
                          }),

                          const SizedBox(height: 36),

                          // Submit button
                          Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF8B5CF6), Color(0xFFEC4899)],
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                              ),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.purpleAccent.withValues(
                                    alpha: 0.35,
                                  ),
                                  blurRadius: 20,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              onPressed: () async {
                                final title = titleCtrl.text.trim();
                                if (title.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Please enter a question text',
                                      ),
                                      backgroundColor: AppColors.error,
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                  return;
                                }
                                if (_session == null) return;

                                final filledOptions = optCtrls
                                    .asMap()
                                    .entries
                                    .where(
                                      (e) => e.value.text.trim().isNotEmpty,
                                    )
                                    .toList();

                                if (filledOptions.length < 2) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Please provide at least 2 non-empty options',
                                      ),
                                      backgroundColor: AppColors.error,
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                  return;
                                }

                                final isCorrectOptionFilled =
                                    optCtrls[correctIndex].text
                                        .trim()
                                        .isNotEmpty;
                                if (!isCorrectOptionFilled) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'The correct option cannot be empty',
                                      ),
                                      backgroundColor: AppColors.error,
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                  return;
                                }

                                final options = filledOptions.map((e) {
                                  return {
                                    'optionText': e.value.text.trim(),
                                    'isCorrect': e.key == correctIndex,
                                  };
                                }).toList();

                                final messenger = ScaffoldMessenger.of(context);
                                final navigator = Navigator.of(dialogCtx);

                                try {
                                  await sl<PollRepository>().createPoll(
                                    sessionId: _session!['id'] as String,
                                    title: title,
                                    type: 'multiple_choice',
                                    settings: {'isQuiz': true},
                                    options: options,
                                  );
                                  navigator.pop();
                                  await _loadInitialData();
                                  messenger.showSnackBar(
                                    const SnackBar(
                                      content: Row(
                                        children: [
                                          Icon(
                                            Icons.check_circle_rounded,
                                            color: Colors.white,
                                            size: 16,
                                          ),
                                          SizedBox(width: 8),
                                          Text(
                                            'Quiz question created successfully!',
                                          ),
                                        ],
                                      ),
                                      backgroundColor: AppColors.success,
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                } catch (e) {
                                  messenger.showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Failed to create quiz: $e',
                                      ),
                                      backgroundColor: AppColors.error,
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                }
                              },
                              icon: const Icon(
                                Icons.emoji_events_rounded,
                                size: 18,
                              ),
                              label: const Text(
                                'Create Quiz Question',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showQrDialog(BuildContext context, String code) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.radiusCard),
          ),
          title: const Text('Session Access QR', textAlign: TextAlign.center),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppSizes.radiusCard),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: QrImageView(
                  data: 'http://${ApiClient.defaultHost}:3000/session/$code',
                  version: QrVersions.auto,
                  size: 200,
                  gapless: false,
                  eyeStyle: const QrEyeStyle(
                    eyeShape: QrEyeShape.square,
                    color: Colors.black,
                  ),
                  dataModuleStyle: const QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.square,
                    color: Colors.black,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Code: $code',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                      letterSpacing: 1.0,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy_rounded, size: 18),
                    color: AppColors.primary,
                    tooltip: 'Copy Code',
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: code));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Access code copied to clipboard!'),
                          backgroundColor: AppColors.success,
                          duration: Duration(seconds: 2),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'Show this QR code to participants to let them scan and join instantly.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  // Speed Dial Quick Options Modal or FAB trigger
  void _showQuickActionsSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Quick Control Actions',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.poll_rounded,
                    color: AppColors.primary,
                  ),
                ),
                title: const Text(
                  'Create New Poll',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: const Text(
                  'Multiple choice, word cloud, rating, ranking',
                ),
                onTap: () {
                  Navigator.pop(context);
                  _addNewPollDialog();
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.purpleAccent.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.emoji_events_rounded,
                    color: AppColors.purpleAccent,
                  ),
                ),
                title: const Text(
                  'Add Quiz Question',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: const Text('Question with timer and scoring options'),
                onTap: () {
                  Navigator.pop(context);
                  _addNewQuizDialog();
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.campaign_rounded,
                    color: AppColors.accent,
                  ),
                ),
                title: const Text(
                  'Broadcast Alert',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: const Text(
                  'Push instant banner message to all attendees',
                ),
                onTap: () {
                  Navigator.pop(context);
                  _tabController.animateTo(3);
                },
              ),
            ],
          ),
        );
      },
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

    final code = _session!['access_code'] as String;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final activePollsCount = _polls.where((p) => !_isQuizPoll(p)).length;
    final unansweredQaCount = _questions
        .where((q) => q['status'] == 'pending' || q['status'] == 'approved')
        .length;
    final quizCount = _polls.where((p) => _isQuizPoll(p)).length;

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        title: Row(
          children: [
            const _LiveIndicator(),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _session!['title'] as String,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: code));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Access code copied to clipboard!'),
                          backgroundColor: AppColors.success,
                          duration: Duration(seconds: 2),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.key_rounded,
                          size: 12,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Code: $code',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.copy_rounded,
                          size: 10,
                          color: AppColors.primary,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_2_rounded, color: AppColors.primary),
            tooltip: 'Show Session QR Code',
            onPressed: () => _showQrDialog(context, code),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          indicatorWeight: 3,
          indicatorSize: TabBarIndicatorSize.tab,
          labelColor: AppColors.primary,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
          unselectedLabelColor: isDark ? Colors.white60 : Colors.black54,
          tabs: [
            Tab(
              icon: Badge(
                label: Text('$activePollsCount'),
                isLabelVisible: activePollsCount > 0,
                backgroundColor: AppColors.primary,
                child: const Icon(Icons.poll_rounded),
              ),
              text: 'Polls',
            ),
            Tab(
              icon: Badge(
                label: Text('$unansweredQaCount'),
                isLabelVisible: unansweredQaCount > 0,
                backgroundColor: AppColors.accent,
                child: const Icon(Icons.question_answer_rounded),
              ),
              text: 'Q&A',
            ),
            Tab(
              icon: Badge(
                label: Text('$quizCount'),
                isLabelVisible: quizCount > 0,
                backgroundColor: AppColors.purpleAccent,
                child: const Icon(Icons.emoji_events_rounded),
              ),
              text: 'Quizzes',
            ),
            const Tab(icon: Icon(Icons.campaign_rounded), text: 'Alerts'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildPollsTab(),
          _buildQaTab(),
          _buildQuizTab(),
          _buildAnnouncementsTab(),
        ],
      ),
      // FAB placed at Bottom Right corner as explicitly requested (hidden on Alerts tab)
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: _tabController.index == 3
          ? null
          : _buildDynamicFab(),
    );
  }

  // Dynamic FAB at bottom-right corner adapting to active tab context
  Widget? _buildDynamicFab() {
    final tabIdx = _tabController.index;
    if (tabIdx == 3) return null;

    IconData fabIcon;
    String fabLabel;
    VoidCallback fabAction;
    Color fabColor;

    switch (tabIdx) {
      case 0:
        fabIcon = Icons.add_rounded;
        fabLabel = 'Add Poll';
        fabAction = _addNewPollDialog;
        fabColor = AppColors.primary;
        break;
      case 1:
        fabIcon = Icons.add_rounded;
        fabLabel = 'Action';
        fabAction = _showQuickActionsSheet;
        fabColor = AppColors.accent;
        break;
      case 2:
        fabIcon = Icons.add_rounded;
        fabLabel = 'Add Question';
        fabAction = _addNewQuizDialog;
        fabColor = AppColors.purpleAccent;
        break;
      default:
        return null;
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: fabColor.withValues(alpha: 0.35),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: FloatingActionButton.extended(
        onPressed: fabAction,
        backgroundColor: fabColor,
        foregroundColor: Colors.white,
        icon: Icon(fabIcon),
        label: Text(
          fabLabel,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            letterSpacing: 0.2,
          ),
        ),
      ),
    );
  }

  bool _isQuizPoll(Map<String, dynamic> poll) {
    final settings = poll['settings'];
    if (settings == null) return false;
    if (settings is Map) {
      return settings['isQuiz'] == true;
    }
    if (settings is String) {
      return settings.contains('isQuiz') && settings.contains('true');
    }
    return false;
  }

  Widget _buildPollsTab() {
    final activePolls = _polls.where((p) => !_isQuizPoll(p)).toList();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        if (_activePollId != null) ...[
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(AppSizes.radiusCard),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.3),
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                const _LiveIndicator(),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'LIVE ACTIVE POLL',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 10,
                          color: AppColors.primary,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _polls
                                .firstWhere(
                                  (p) => p['id'] == _activePollId,
                                  orElse: () => {'title': 'Unknown'},
                                )['title']
                                ?.toString() ??
                            'Unknown',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.warning,
                    side: const BorderSide(color: AppColors.warning),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                  ),
                  onPressed: _lockActivePoll,
                  child: const Text('Lock'),
                ),
                const SizedBox(width: 6),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                  ),
                  onPressed: _deactivateActivePoll,
                  child: const Text(
                    'Stop',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ],
        Expanded(
          child: activePolls.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.ballot_outlined,
                        size: 54,
                        color: isDark ? Colors.white24 : Colors.black12,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'No live polls created yet',
                        style: TextStyle(
                          color: Colors.grey,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Tap the bottom-right + button to create a poll',
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                  itemCount: activePolls.length,
                  itemBuilder: (context, index) {
                    final poll = activePolls[index];
                    final pollId = poll['id'] as String;
                    final isCurrent = _activePollId == pollId;
                    final status = poll['status'] as String;

                    Color badgeColor;
                    switch (status) {
                      case 'active':
                        badgeColor = AppColors.success;
                        break;
                      case 'locked':
                        badgeColor = AppColors.warning;
                        break;
                      case 'ended':
                        badgeColor = Colors.grey;
                        break;
                      default:
                        badgeColor = AppColors.primary;
                    }

                    IconData typeIcon;
                    switch (poll['type'] as String) {
                      case 'multiple_choice':
                        typeIcon = Icons.list_rounded;
                        break;
                      case 'word_cloud':
                        typeIcon = Icons.cloud_rounded;
                        break;
                      case 'rating':
                        typeIcon = Icons.star_rounded;
                        break;
                      case 'ranking':
                        typeIcon = Icons.sort_rounded;
                        break;
                      default:
                        typeIcon = Icons.short_text_rounded;
                    }

                    return Card(
                      color: isCurrent
                          ? AppColors.primary.withValues(alpha: 0.04)
                          : null,
                      margin: const EdgeInsets.only(bottom: 12),
                      elevation: isCurrent ? 2 : 0.5,
                      shape: RoundedRectangleBorder(
                        side: BorderSide(
                          color: isCurrent
                              ? AppColors.primary.withValues(alpha: 0.4)
                              : (isDark ? Colors.white10 : Colors.black12),
                          width: isCurrent ? 1.5 : 1.0,
                        ),
                        borderRadius: BorderRadius.circular(
                          AppSizes.radiusCard,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      typeIcon,
                                      size: 14,
                                      color: isDark
                                          ? Colors.white60
                                          : Colors.black54,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      (poll['type'] as String)
                                          .replaceAll('_', ' ')
                                          .toUpperCase(),
                                      style: TextStyle(
                                        color: isDark
                                            ? Colors.white60
                                            : Colors.black54,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: badgeColor.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(
                                      AppSizes.radiusBadge,
                                    ),
                                  ),
                                  child: Text(
                                    status.toUpperCase(),
                                    style: TextStyle(
                                      color: badgeColor,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              poll['title'] as String,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            _buildMiniResults(poll),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                if (status == 'active') ...[
                                  ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.error,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(
                                          AppSizes.radiusButton,
                                        ),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 8,
                                      ),
                                    ),
                                    onPressed: () => _endPoll(pollId),
                                    icon: const Icon(
                                      Icons.stop_rounded,
                                      size: 16,
                                    ),
                                    label: const Text(
                                      'End Poll',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ] else if (status == 'ended') ...[
                                  ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.purpleAccent,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(
                                          AppSizes.radiusButton,
                                        ),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 8,
                                      ),
                                    ),
                                    onPressed: () => _activatePoll(pollId),
                                    icon: const Icon(
                                      Icons.replay_rounded,
                                      size: 16,
                                    ),
                                    label: const Text(
                                      'Reopen Poll',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ] else ...[
                                  ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primary,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(
                                          AppSizes.radiusButton,
                                        ),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 8,
                                      ),
                                    ),
                                    onPressed: () => _activatePoll(pollId),
                                    icon: const Icon(
                                      Icons.play_arrow_rounded,
                                      size: 16,
                                    ),
                                    label: const Text(
                                      'Activate Poll',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
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

  Widget _buildMiniResults(Map<String, dynamic> poll) {
    final results = poll['results'];
    if (results == null) return const SizedBox.shrink();
    final type = poll['type'] as String;

    if (type == 'multiple_choice') {
      final options = results['options'] as List? ?? [];
      if (options.isEmpty) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Column(
          children: options.take(3).map<Widget>((opt) {
            final percent = opt['percentage'] as int? ?? 0;
            final text = opt['optionText'] as String? ?? '';
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Text(
                      text,
                      style: const TextStyle(
                        fontSize: 12,
                        overflow: TextOverflow.ellipsis,
                      ),
                      maxLines: 1,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 5,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(AppSizes.radiusSmall),
                      child: LinearProgressIndicator(
                        value: percent / 100,
                        minHeight: 6,
                        backgroundColor: Colors.grey.withValues(alpha: 0.1),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppColors.primary.withValues(alpha: 0.7),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$percent%',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      );
    } else if (type == 'rating') {
      final average = (results['average'] as num?)?.toDouble() ?? 0.0;
      final total = results['totalVotes'] as int? ?? 0;
      if (total == 0) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Row(
          children: [
            const Icon(Icons.star_rounded, color: Colors.amber, size: 16),
            const SizedBox(width: 4),
            Text(
              '${average.toStringAsFixed(1)} / 5.0 Rating ($total votes)',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildQaTab() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Filter questions based on filter pill selection
    List<Map<String, dynamic>> filteredQuestions = _questions;
    if (_qaFilter == 'unanswered') {
      filteredQuestions = _questions
          .where((q) => q['status'] == 'pending' || q['status'] == 'approved')
          .toList();
    } else if (_qaFilter == 'answered') {
      filteredQuestions = _questions
          .where((q) => q['status'] == 'answered')
          .toList();
    } else if (_qaFilter == 'pinned') {
      filteredQuestions = _questions
          .where((q) => q['isPinned'] == true)
          .toList();
    }

    return Column(
      children: [
        // Quick Q&A filter header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('all', 'All (${_questions.length})'),
                const SizedBox(width: 8),
                _buildFilterChip(
                  'unanswered',
                  'Unanswered (${_questions.where((q) => q['status'] != 'answered').length})',
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  'answered',
                  'Answered (${_questions.where((q) => q['status'] == 'answered').length})',
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  'pinned',
                  'Pinned (${_questions.where((q) => q['isPinned'] == true).length})',
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: filteredQuestions.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.question_answer_outlined,
                        size: 54,
                        color: isDark ? Colors.white24 : Colors.black12,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'No questions found',
                        style: TextStyle(
                          color: Colors.grey,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                  itemCount: filteredQuestions.length,
                  itemBuilder: (context, index) {
                    final q = filteredQuestions[index];
                    final qId = q['id'] as String;
                    final author = q['authorName'] as String? ?? 'Anonymous';
                    final text = q['text'] as String;
                    final upvotes = q['upvotesCount'] as int? ?? 0;
                    final isPinned = q['isPinned'] as bool? ?? false;
                    final status = q['status'] as String;
                    final isAnswered = status == 'answered';
                    final isPending = status == 'pending';

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        side: BorderSide(
                          color: isPinned
                              ? Colors.orange.withValues(alpha: 0.6)
                              : (isDark ? Colors.white10 : Colors.black12),
                          width: isPinned ? 1.5 : 1.0,
                        ),
                        borderRadius: BorderRadius.circular(
                          AppSizes.radiusCard,
                        ),
                      ),
                      color: isAnswered
                          ? (isDark ? Colors.black12 : Colors.grey[100])
                          : (isPinned
                                ? AppColors.primary.withValues(alpha: 0.04)
                                : null),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        title: Text(
                          text,
                          style: TextStyle(
                            decoration: isAnswered
                                ? TextDecoration.lineThrough
                                : null,
                            fontWeight: isPinned
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: isAnswered
                                ? (isDark ? Colors.white38 : Colors.black38)
                                : (isDark ? Colors.white : Colors.black87),
                          ),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 9,
                                backgroundColor: AppColors.primary.withValues(
                                  alpha: 0.2,
                                ),
                                child: Text(
                                  author.isNotEmpty
                                      ? author[0].toUpperCase()
                                      : 'A',
                                  style: const TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '$author • ',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isAnswered
                                      ? Colors.grey
                                      : (isDark
                                            ? Colors.white70
                                            : Colors.black87),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(
                                    alpha: 0.1,
                                  ),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.thumb_up_rounded,
                                      size: 10,
                                      color: AppColors.primary,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '$upvotes',
                                      style: const TextStyle(
                                        fontSize: 10,
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
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isPending) ...[
                              IconButton(
                                icon: const Icon(
                                  Icons.check_circle_outline,
                                  color: AppColors.success,
                                ),
                                tooltip: 'Approve Question',
                                onPressed: () =>
                                    _updateQuestionStatus(qId, 'approved'),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.cancel_outlined,
                                  color: AppColors.error,
                                ),
                                tooltip: 'Dismiss Question',
                                onPressed: () =>
                                    _updateQuestionStatus(qId, 'dismissed'),
                              ),
                            ] else if (isAnswered) ...[
                              IconButton(
                                icon: const Icon(
                                  Icons.history_rounded,
                                  color: Colors.grey,
                                ),
                                tooltip: 'Reopen Question',
                                onPressed: () =>
                                    _updateQuestionStatus(qId, 'approved'),
                              ),
                            ] else ...[
                              IconButton(
                                icon: Icon(
                                  isPinned
                                      ? Icons.push_pin
                                      : Icons.push_pin_outlined,
                                  color: isPinned ? Colors.orange : Colors.grey,
                                ),
                                tooltip: isPinned
                                    ? 'Unpin from Presenter Screen'
                                    : 'Pin to Presenter Screen',
                                onPressed: () =>
                                    _toggleQuestionPin(qId, isPinned),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.check_circle_rounded,
                                  color: AppColors.success,
                                ),
                                tooltip: 'Mark as Answered',
                                onPressed: () =>
                                    _updateQuestionStatus(qId, 'answered'),
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

  Widget _buildFilterChip(String filterKey, String label) {
    final isSelected = _qaFilter == filterKey;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: AppColors.primary.withValues(alpha: 0.15),
      labelStyle: TextStyle(
        color: isSelected ? AppColors.primary : Colors.grey[700],
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        fontSize: 12,
      ),
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _qaFilter = filterKey;
          });
        }
      },
    );
  }

  Widget _buildQuizTab() {
    final quizPolls = _polls.where((p) => _isQuizPoll(p)).toList();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        Expanded(
          child: quizPolls.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.quiz_outlined,
                        size: 54,
                        color: isDark ? Colors.white24 : Colors.black12,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'No quiz questions created',
                        style: TextStyle(
                          color: Colors.grey,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Tap the bottom-right + button to add quiz questions',
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                  itemCount: quizPolls.length,
                  itemBuilder: (context, index) {
                    final quiz = quizPolls[index];
                    final pollId = (quiz['id'] ?? '').toString();
                    final isCurrent = _activeQuizQuestionId == pollId;
                    final isTicking = isCurrent && _quizTimeRemaining > 0;
                    final duration = _getQuizDuration(quiz);
                    final totalVotes = (quiz['results']?['totalVotes'] as num?)?.toInt() ?? 0;
                    final options = (quiz['options'] as List?) ?? [];

                    return Card(
                      color: isCurrent
                          ? AppColors.purpleAccent.withValues(alpha: 0.05)
                          : (isDark
                                ? Colors.white.withValues(alpha: 0.03)
                                : Colors.white),
                      margin: const EdgeInsets.only(bottom: 14),
                      shape: RoundedRectangleBorder(
                        side: BorderSide(
                          color: isTicking
                              ? AppColors.purpleAccent
                              : (isCurrent
                                    ? AppColors.purpleAccent.withValues(alpha: 0.4)
                                    : (isDark ? Colors.white10 : Colors.black12)),
                          width: isTicking ? 2.0 : 1.0,
                        ),
                        borderRadius: BorderRadius.circular(
                          AppSizes.radiusCard,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Header Row: Title and responses badge
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppColors.purpleAccent.withValues(
                                      alpha: 0.12,
                                    ),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(
                                    Icons.emoji_events_rounded,
                                    color: AppColors.purpleAccent,
                                    size: 18,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        quiz['title'] as String? ?? 'Quiz Question',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 16,
                                          letterSpacing: -0.2,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${options.length} choices • 1000 base pts',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: isDark
                                              ? Colors.white54
                                              : Colors.black54,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (totalVotes > 0)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.success.withValues(
                                        alpha: 0.12,
                                      ),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: AppColors.success.withValues(
                                          alpha: 0.3,
                                        ),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.check_circle_outline_rounded,
                                          color: AppColors.success,
                                          size: 13,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          '$totalVotes answered',
                                          style: const TextStyle(
                                            color: AppColors.success,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),

                            const SizedBox(height: 14),
                            Divider(
                              height: 1,
                              color: isDark ? Colors.white10 : Colors.black12,
                            ),
                            const SizedBox(height: 14),

                            // Controls Row: Timer selector chip & Action buttons
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                // Timer Duration selector chip
                                InkWell(
                                  onTap: () => _showSetTimerDialog(quiz),
                                  borderRadius: BorderRadius.circular(20),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? Colors.white.withValues(alpha: 0.06)
                                          : Colors.black.withValues(alpha: 0.05),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: isDark
                                            ? Colors.white12
                                            : Colors.black12,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.timer_outlined,
                                          size: 14,
                                          color: AppColors.purpleAccent,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          '${duration}s',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 12,
                                            color: AppColors.purpleAccent,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Icon(
                                          Icons.arrow_drop_down_rounded,
                                          size: 18,
                                          color: isDark
                                              ? Colors.white54
                                              : Colors.black54,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),

                                // Status Badge & Actions
                                Row(
                                  children: [
                                    if (isTicking) ...[
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 6,
                                        ),
                                        margin: const EdgeInsets.only(right: 8),
                                        decoration: BoxDecoration(
                                          color: AppColors.purpleAccent
                                              .withValues(alpha: 0.15),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const SizedBox(
                                              width: 10,
                                              height: 10,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: AppColors.purpleAccent,
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              '${_quizTimeRemaining}s left',
                                              style: const TextStyle(
                                                color: AppColors.purpleAccent,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      // Restart Timer Button
                                      ElevatedButton.icon(
                                        onPressed: () => _startQuizQuestion(
                                          pollId,
                                          duration,
                                          isRestart: true,
                                        ),
                                        icon: const Icon(
                                          Icons.replay_rounded,
                                          size: 14,
                                        ),
                                        label: const Text('Restart'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor:
                                              AppColors.purpleAccent,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 8,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(10),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      // Stop timer button
                                      IconButton(
                                        icon: const Icon(
                                          Icons.stop_circle_outlined,
                                          color: AppColors.error,
                                        ),
                                        tooltip: 'Stop Timer',
                                        onPressed: () => _stopQuizQuestion(pollId),
                                      ),
                                    ] else ...[
                                      // If already has responses, show Restart Timer, else Start Timer
                                      ElevatedButton.icon(
                                        onPressed: () => _startQuizQuestion(
                                          pollId,
                                          duration,
                                          isRestart: totalVotes > 0,
                                        ),
                                        icon: Icon(
                                          totalVotes > 0
                                              ? Icons.replay_rounded
                                              : Icons.play_arrow_rounded,
                                          size: 16,
                                        ),
                                        label: Text(
                                          totalVotes > 0
                                              ? 'Restart (${duration}s)'
                                              : 'Start (${duration}s)',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                          ),
                                        ),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: totalVotes > 0
                                              ? const Color(0xFF7C3AED)
                                              : AppColors.purpleAccent,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 14,
                                            vertical: 10,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(10),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
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

  Widget _buildAnnouncementsTab() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final presets = [
      {
        'icon': Icons.rocket_launch_rounded,
        'title': 'Start Soon',
        'subtitle': 'Seats & attention',
        'alertTitle': 'Session Starting Soon',
        'alertMsg':
            'Please take your seats! We are starting the presentation shortly.',
      },
      {
        'icon': Icons.bar_chart_rounded,
        'title': 'Poll Opened',
        'subtitle': 'Cast your vote',
        'alertTitle': 'Live Poll Now Open',
        'alertMsg':
            'A new live poll is active! Open your app to cast your vote.',
      },
      {
        'icon': Icons.question_answer_rounded,
        'title': 'Q&A Time',
        'subtitle': 'Submit questions',
        'alertTitle': 'Q&A Session Open',
        'alertMsg':
            'Submit your questions and upvote your favorites in the Q&A tab.',
      },
      {
        'icon': Icons.coffee_rounded,
        'title': '5 Min Break',
        'subtitle': 'Short break',
        'alertTitle': 'Short 5-Minute Break',
        'alertMsg': 'We are taking a short 5-minute break. Stay tuned!',
      },
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Quick Presets label
          Text(
            'QUICK PRESETS',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white38 : Colors.black38,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 12),

          // Preset tiles responsive grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 220,
              mainAxisExtent: 72,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: presets.length,
            itemBuilder: (context, index) {
              final preset = presets[index];
              return GestureDetector(
                onTap: () {
                  _announcementTitleCtrl.text = preset['alertTitle'] as String;
                  _announcementMsgCtrl.text = preset['alertMsg'] as String;
                  setState(() {});
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : Colors.black.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isDark
                          ? Colors.white10
                          : Colors.black.withValues(alpha: 0.08),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        preset['icon'] as IconData,
                        color: AppColors.primary,
                        size: 22,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              preset['title'] as String,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.87)
                                    : Colors.black87,
                              ),
                            ),
                            Text(
                              preset['subtitle'] as String,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 10,
                                color: isDark ? Colors.white38 : Colors.black38,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 28),

          // Alert Title input
          Text(
            'ALERT TITLE',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white38 : Colors.black38,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _announcementTitleCtrl,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'e.g. Session starting in 2 minutes',
              hintStyle: TextStyle(
                color: isDark ? Colors.white30 : Colors.black26,
                fontWeight: FontWeight.normal,
              ),
              prefixIcon: Container(
                margin: const EdgeInsets.all(10),
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.title_rounded,
                  color: AppColors.primary,
                  size: 16,
                ),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: isDark ? Colors.white12 : Colors.black12,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: isDark ? Colors.white12 : Colors.black12,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(
                  color: AppColors.primary,
                  width: 2,
                ),
              ),
              filled: true,
              fillColor: isDark
                  ? Colors.white.withValues(alpha: 0.04)
                  : Colors.black.withValues(alpha: 0.02),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Alert message body
          Text(
            'MESSAGE BODY',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white38 : Colors.black38,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _announcementMsgCtrl,
            maxLines: 4,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Type your message to broadcast to all attendees\u2026',
              hintStyle: TextStyle(
                color: isDark ? Colors.white30 : Colors.black26,
                fontWeight: FontWeight.normal,
              ),
              alignLabelWithHint: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: isDark ? Colors.white12 : Colors.black12,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: isDark ? Colors.white12 : Colors.black12,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(
                  color: AppColors.primary,
                  width: 2,
                ),
              ),
              filled: true,
              fillColor: isDark
                  ? Colors.white.withValues(alpha: 0.04)
                  : Colors.black.withValues(alpha: 0.02),
              contentPadding: const EdgeInsets.all(16),
            ),
          ),

          const SizedBox(height: 28),

          // Broadcast button
          Container(
            height: 54,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: AppColors.primaryGradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.35),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: _broadcastAnnouncement,
              child: const Center(
                child: Text(
                  'Broadcast Announcement',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Pulsing live state indicator widget
class _LiveIndicator extends StatefulWidget {
  const _LiveIndicator();

  @override
  State<_LiveIndicator> createState() => _LiveIndicatorState();
}

class _LiveIndicatorState extends State<_LiveIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        return Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.primary,
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(
                  alpha: 0.5 * _ctrl.value + 0.1,
                ),
                blurRadius: 8.0 * _ctrl.value + 2.0,
                spreadRadius: 3.0 * _ctrl.value,
              ),
            ],
          ),
        );
      },
    );
  }
}
