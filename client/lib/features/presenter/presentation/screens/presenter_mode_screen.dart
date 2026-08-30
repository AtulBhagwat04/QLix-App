import 'dart:async';
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../../core/network/socket_client.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../polls/domain/repositories/poll_repository.dart';
import '../../../qa/domain/repositories/qa_repository.dart';
import '../../../sessions/domain/repositories/session_repository.dart';
import '../../../quiz/domain/repositories/quiz_repository.dart';

class PresenterModeScreen extends StatefulWidget {
  final String accessCode;
  const PresenterModeScreen({super.key, required this.accessCode});

  @override
  State<PresenterModeScreen> createState() => _PresenterModeScreenState();
}

class _PresenterModeScreenState extends State<PresenterModeScreen>
    with SingleTickerProviderStateMixin {
  final _socketClient = sl<SocketClient>();

  Map<String, dynamic>? _session;
  Map<String, dynamic>? _activePoll;
  List<Map<String, dynamic>> _questions = [];
  List<Map<String, dynamic>> _leaderboard = [];

  // Live connections
  StreamSubscription? _activationSub;
  StreamSubscription? _votesSub;
  StreamSubscription? _qaSub;
  StreamSubscription? _qaStatusSub;
  StreamSubscription? _qaUpvotedSub;
  StreamSubscription? _quizSub;
  StreamSubscription? _sessionStateSub;
  Timer? _heartbeatTimer;

  @override
  void initState() {
    super.initState();
    _setupSocketListeners();
    _loadSessionDetails();

    // Heartbeat background sync to guarantee real-time reliability
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted || _session == null) return;
      if (_activePoll != null) {
        _fetchActivePollResults((_activePoll!['id'] ?? '').toString());
      }
    });
  }

  @override
  void dispose() {
    _heartbeatTimer?.cancel();
    _activationSub?.cancel();
    _votesSub?.cancel();
    _qaSub?.cancel();
    _qaStatusSub?.cancel();
    _qaUpvotedSub?.cancel();
    _quizSub?.cancel();
    _sessionStateSub?.cancel();
    _socketClient.disconnect();
    super.dispose();
  }

  void _setupSocketListeners() {
    // 1. Live Poll Activation / Deactivation
    _activationSub = _socketClient.pollActivationStream.listen((data) {
      if (!mounted) return;
      if (data == null) {
        setState(() {
          _activePoll = null;
        });
      } else {
        final poll = Map<String, dynamic>.from(data['poll'] as Map);
        final pollId = (poll['id'] ?? '').toString();
        setState(() {
          _activePoll = poll;
          _leaderboard = []; // Reset leaderboard to show the new active poll
        });
        _fetchActivePollResults(pollId);
      }
    });

    // 2. Real-time Votes / Interactions
    _votesSub = _socketClient.votesUpdatedStream.listen((data) {
      if (!mounted) return;
      final pollId = (data['pollId'] ?? '').toString();
      final results = data['results'] != null
          ? Map<String, dynamic>.from(data['results'] as Map)
          : null;

      setState(() {
        if (_activePoll != null &&
            (_activePoll!['id'] ?? '').toString() == pollId) {
          _activePoll!['results'] = results;
        } else if (_activePoll == null) {
          _fetchActivePollResults(pollId);
        }
      });
    });

    // 3. New Q&A questions created (prioritized at the top)
    _qaSub = _socketClient.questionCreatedStream.listen((data) {
      if (!mounted) return;
      final newQ = Map<String, dynamic>.from(data['question'] as Map);
      setState(() {
        final idx = _questions.indexWhere(
          (q) => (q['id'] ?? '').toString() == (newQ['id'] ?? '').toString(),
        );
        if (idx != -1) {
          _questions[idx] = newQ;
        } else {
          _questions.insert(0, newQ);
        }
        _sortQuestions();
      });
    });

    // 4. Question status changed (Host answers / approves / pins)
    _qaStatusSub = _socketClient.questionStatusStream.listen((data) {
      if (!mounted) return;
      final updatedQ = Map<String, dynamic>.from(data['question'] as Map);
      setState(() {
        final index = _questions.indexWhere(
          (q) =>
              (q['id'] ?? '').toString() == (updatedQ['id'] ?? '').toString(),
        );
        final isDismissed = updatedQ['status'] == 'dismissed';

        if (isDismissed) {
          if (index != -1) _questions.removeAt(index);
        } else {
          if (index != -1) {
            _questions[index] = updatedQ;
          } else {
            _questions.insert(0, updatedQ);
          }
        }
        _sortQuestions();
      });
    });

    // 5. Question upvoted
    _qaUpvotedSub = _socketClient.questionUpvotedStream.listen((data) {
      if (!mounted) return;
      final qId = (data['questionId'] ?? '').toString();
      final count = (data['upvotesCount'] as num?)?.toInt() ?? 0;
      setState(() {
        for (var q in _questions) {
          if ((q['id'] ?? '').toString() == qId) {
            q['upvotesCount'] = count;
          }
        }
        _sortQuestions();
      });
    });

    // 6. Session state changes (draft, active, ended)
    _sessionStateSub = _socketClient.sessionStateStream.listen((data) {
      if (!mounted) return;
      if (data['state'] != null && _session != null) {
        setState(() {
          _session!['state'] = data['state'];
        });
      }
    });

    // 7. Quiz controls & countdowns
    _quizSub = _socketClient.quizTimerStream.listen((data) {
      if (!mounted) return;
      final event = (data['event'] ?? '').toString();
      final pollId = (data['pollId'] ?? '').toString();

      if (event == 'start') {
        setState(() {
          _leaderboard = [];
        });
        _fetchActivePollResults(pollId);
      } else if (event == 'end') {
        if (_session != null) {
          final sessionId = (_session!['id'] ?? '').toString();
          sl<QuizRepository>().getLeaderboard(sessionId).then((lb) {
            if (!mounted) return;
            setState(() {
              _leaderboard = lb;
            });
          });
        }
      }
    });
  }

  Future<void> _loadSessionDetails() async {
    try {
      final details = await sl<SessionRepository>().joinSessionByCode(
        widget.accessCode,
        'presenter_device',
        'Presenter Screen',
        false,
      );

      if (!mounted) return;
      setState(() {
        _session = details['session'] as Map<String, dynamic>;
      });

      final sessionId = (_session!['id'] ?? '').toString();

      // Connect socket & join room
      _socketClient.connect();
      _socketClient.joinSession(widget.accessCode, 'presenter', 'presenter');

      // Fetch all session polls to find active or opened poll
      try {
        final polls = await sl<PollRepository>().getSessionPolls(sessionId);
        final activePollFromList = polls.cast<Map<String, dynamic>?>().firstWhere(
              (p) => p?['status'] == 'active',
              orElse: () => null,
            );

        final targetPollId = _session!['active_poll_id']?.toString() ??
            _session!['active_quiz_question_id']?.toString() ??
            activePollFromList?['id']?.toString();

        if (targetPollId != null && targetPollId.isNotEmpty) {
          await _fetchActivePollResults(targetPollId);
        }
      } catch (_) {}

      // Load all active & answered Q&A questions
      try {
        final questions = await sl<QaRepository>().getSessionQuestions(sessionId);
        if (mounted) {
          setState(() {
            _questions = questions;
            _sortQuestions();
          });
        }
      } catch (_) {}
    } catch (_) {}
  }

  void _sortQuestions() {
    _questions.sort((a, b) {
      // 1. Pinned first
      final aPinned = a['isPinned'] == true;
      final bPinned = b['isPinned'] == true;
      if (aPinned != bPinned) return aPinned ? -1 : 1;

      // 2. Answered with host response prioritized
      final aHasAnswer = a['answerText'] != null &&
          (a['answerText'] as String).trim().isNotEmpty;
      final bHasAnswer = b['answerText'] != null &&
          (b['answerText'] as String).trim().isNotEmpty;
      if (aHasAnswer != bHasAnswer) return aHasAnswer ? -1 : 1;

      // 3. Upvotes count descending
      final aUpvotes = (a['upvotesCount'] as num?)?.toInt() ?? 0;
      final bUpvotes = (b['upvotesCount'] as num?)?.toInt() ?? 0;
      return bUpvotes.compareTo(aUpvotes);
    });
  }

  Future<void> _fetchActivePollResults(String pollId) async {
    try {
      final results = await sl<PollRepository>().getPollResults(pollId);
      if (!mounted) return;
      setState(() {
        _activePoll = results;
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (_session == null) {
      return const Scaffold(
        backgroundColor: AppColors.backgroundDark,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    final code = (_session!['access_code'] ?? widget.accessCode).toString();
    final sessionState =
        (_session!['state'] as String? ?? 'active').toLowerCase();

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: Stack(
        children: [
          // Background Gradient Mesh
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: AppColors.bgGradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          // Ambient Glow Bubbles
          Positioned(
            top: -100,
            left: -100,
            child: Container(
              width: 400,
              height: 400,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.18),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            bottom: -150,
            right: -50,
            child: Container(
              width: 500,
              height: 500,
              decoration: BoxDecoration(
                color: AppColors.secondary.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            top: 200,
            right: 200,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                color: AppColors.purpleAccent.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
            ),
          ),

          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 100, sigmaY: 100),
              child: const SizedBox(),
            ),
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
              child: Column(
                children: [
                  // Presentation Header with Live Status & QR Code
                  _buildHeader(code, sessionState),
                  const SizedBox(height: 24),
                  const Divider(color: Colors.white12, height: 1),
                  const SizedBox(height: 24),

                  // Split View: Active poll results on the left, Q&A pinned list on the right
                  Expanded(
                    child: Builder(
                      builder: (context) {
                        final isMobile =
                            MediaQuery.of(context).size.width < 900;
                        if (isMobile) {
                          return SingleChildScrollView(
                            child: Column(
                              children: [
                                // Top: Poll Results
                                SizedBox(
                                  height: 460,
                                  child: _buildActivePresentationPanel(),
                                ),
                                const SizedBox(height: 24),
                                // Bottom: Live Q&A
                                SizedBox(
                                  height: 420,
                                  child: _buildQaPresentationPanel(),
                                ),
                              ],
                            ),
                          );
                        }

                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Left: Poll Results
                            Expanded(
                              flex: 3,
                              child: _buildActivePresentationPanel(),
                            ),
                            const SizedBox(width: 32),
                            // Right: Live Q&A
                            Expanded(
                              flex: 2,
                              child: _buildQaPresentationPanel(),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(String code, String sessionState) {
    Color stateColor;
    String stateLabel;
    IconData stateIcon;

    switch (sessionState) {
      case 'draft':
        stateColor = Colors.amber;
        stateLabel = 'WAITING';
        stateIcon = Icons.hourglass_top_rounded;
        break;
      case 'ended':
        stateColor = Colors.grey;
        stateLabel = 'ENDED';
        stateIcon = Icons.stop_circle_rounded;
        break;
      default:
        stateColor = AppColors.success;
        stateLabel = 'LIVE';
        stateIcon = Icons.sensors_rounded;
    }

    final isMobile = MediaQuery.of(context).size.width < 800;

    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: stateColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: stateColor.withValues(alpha: 0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(stateIcon, color: stateColor, size: 13),
                    const SizedBox(width: 5),
                    Text(
                      stateLabel,
                      style: TextStyle(
                        color: stateColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            _session!['title'] as String? ?? 'Untitled Session',
            style: const TextStyle(
              color: AppColors.textPrimaryDark,
              fontSize: 24,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 14),
          _buildQrCard(code),
        ],
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: stateColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: stateColor.withValues(alpha: 0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(stateIcon, color: stateColor, size: 14),
                    const SizedBox(width: 6),
                    Text(
                      stateLabel,
                      style: TextStyle(
                        color: stateColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Text(
                _session!['title'] as String? ?? 'Untitled Session',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textPrimaryDark,
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.8,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 24),
        _buildQrCard(code),
      ],
    );
  }

  Widget _buildQrCard(String code) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(AppSizes.radiusCard),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.35),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.15),
            blurRadius: 16,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 6,
                ),
              ],
            ),
            child: QrImageView(
              data: 'http://${ApiClient.defaultHost}:3000/session/$code',
              version: QrVersions.auto,
              size: 64,
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
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'JOIN CODE',
                style: TextStyle(
                  color: AppColors.textSecondaryDark,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                code,
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w900,
                  fontSize: 24,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActivePresentationPanel() {
    if (_leaderboard.isNotEmpty) {
      return _buildQuizLeaderboardView();
    }

    if (_activePoll == null) {
      return Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceDark.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(AppSizes.radiusCard),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        clipBehavior: Clip.antiAlias,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.slideshow_rounded,
                    size: 80,
                    color: Colors.white.withValues(alpha: 0.15),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Waiting for active poll...',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.textPrimaryDark,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'When the host launches a poll or quiz, live audience responses will appear here in real time.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.textSecondaryDark,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final type = _activePoll!['type'] as String? ?? 'multiple_choice';
    final title = _activePoll!['title'] as String? ?? '';
    final results = _activePoll!['results'] as Map<String, dynamic>?;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceDark.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(AppSizes.radiusCard),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(AppSizes.radiusPill),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      type.replaceAll('_', ' ').toUpperCase(),
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  if (results != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${results['totalVotes'] ?? 0} responses',
                        style: const TextStyle(
                          color: AppColors.textSecondaryDark,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.textPrimaryDark,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 28),
              Expanded(child: _buildChartRenderer(type, results)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChartRenderer(String type, Map<String, dynamic>? results) {
    if (results == null) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    switch (type) {
      case 'multiple_choice':
        final options = results['options'] as List? ?? [];
        return ListView.builder(
          itemCount: options.length,
          itemBuilder: (context, index) {
            final opt = options[index];
            final percent = (opt['percentage'] as num?)?.toInt() ?? 0;
            final count = (opt['votesCount'] as num?)?.toInt() ?? 0;
            final isCorrect = opt['isCorrect'] as bool? ?? false;

            return Container(
              margin: const EdgeInsets.only(bottom: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            if (isCorrect)
                              const Padding(
                                padding: EdgeInsets.only(right: 6),
                                child: Icon(
                                  Icons.check_circle_rounded,
                                  color: AppColors.success,
                                  size: 16,
                                ),
                              ),
                            Expanded(
                              child: Text(
                                opt['optionText'] as String? ?? '',
                                style: TextStyle(
                                  color: isCorrect
                                      ? AppColors.success
                                      : AppColors.textPrimaryDark,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '$percent% ($count)',
                        style: TextStyle(
                          color: isCorrect
                              ? AppColors.success
                              : AppColors.textPrimaryDark,
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Stack(
                    children: [
                      Container(
                        height: 14,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.06),
                          borderRadius:
                              BorderRadius.circular(AppSizes.radiusBadge),
                        ),
                      ),
                      FractionallySizedBox(
                        widthFactor: (percent / 100).clamp(0.0, 1.0),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 500),
                          curve: Curves.easeOutCubic,
                          height: 14,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: isCorrect
                                  ? [AppColors.success, Colors.tealAccent]
                                  : [
                                      AppColors.primary,
                                      AppColors.purpleAccent,
                                    ],
                            ),
                            borderRadius:
                                BorderRadius.circular(AppSizes.radiusBadge),
                            boxShadow: [
                              BoxShadow(
                                color: (isCorrect
                                        ? AppColors.success
                                        : AppColors.primary)
                                    .withValues(alpha: 0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );

      case 'ranking':
        final options = results['options'] as List? ?? [];
        return ListView.builder(
          itemCount: options.length,
          itemBuilder: (context, index) {
            final opt = options[index];
            final percent = (opt['percentage'] as num?)?.toInt() ?? 0;
            final rank = index + 1;

            return Container(
              margin: const EdgeInsets.only(bottom: 18),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppColors.purpleAccent.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.purpleAccent.withValues(alpha: 0.4),
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '#$rank',
                      style: const TextStyle(
                        color: AppColors.purpleAccent,
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                opt['optionText'] as String? ?? '',
                                style: const TextStyle(
                                  color: AppColors.textPrimaryDark,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Text(
                              '$percent%',
                              style: const TextStyle(
                                color: AppColors.purpleAccent,
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Stack(
                          children: [
                            Container(
                              height: 10,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.06),
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                            FractionallySizedBox(
                              widthFactor: (percent / 100).clamp(0.0, 1.0),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 500),
                                curve: Curves.easeOutCubic,
                                height: 10,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      AppColors.purpleAccent,
                                      Color(0xFFC084FC),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );

      case 'rating':
        final average = (results['average'] as num?)?.toDouble() ?? 0.0;
        final totalVotes = (results['totalVotes'] as num?)?.toInt() ?? 0;
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: AppColors.surfaceDark.withValues(alpha: 0.3),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.amber.withValues(alpha: 0.4),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.amber.withValues(alpha: 0.15),
                      blurRadius: 36,
                      spreadRadius: 8,
                    ),
                  ],
                ),
                child: Text(
                  average.toStringAsFixed(1),
                  style: const TextStyle(
                    color: AppColors.textPrimaryDark,
                    fontSize: 72,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (idx) {
                  final filled = idx < average.round();
                  return Icon(
                    filled ? Icons.star_rounded : Icons.star_border_rounded,
                    color: Colors.amber,
                    size: 42,
                  );
                }),
              ),
              const SizedBox(height: 16),
              Text(
                'Based on $totalVotes ratings',
                style: const TextStyle(
                  color: AppColors.textSecondaryDark,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        );

      case 'word_cloud':
        final words = results['words'] as List? ?? [];
        if (words.isEmpty) {
          return const Center(
            child: Text(
              'No words submitted yet',
              style: TextStyle(
                color: AppColors.textSecondaryDark,
                fontSize: 15,
              ),
            ),
          );
        }
        return Center(
          child: SingleChildScrollView(
            child: Wrap(
              spacing: 14,
              runSpacing: 14,
              alignment: WrapAlignment.center,
              children: List.generate(words.length, (idx) {
                final w = words[idx];
                final text = w['text'] as String? ?? '';
                final val = (w['value'] as num?)?.toInt() ?? 0;
                final baseColor = _getWordColor(val);
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: baseColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppSizes.radiusCard),
                    border: Border.all(
                      color: baseColor.withValues(alpha: 0.35),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    text,
                    style: TextStyle(
                      color: baseColor,
                      fontSize: 16.0 + (val * 4.0).clamp(0, 28),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                );
              }),
            ),
          ),
        );

      case 'open_text':
        final responses = results['responses'] as List? ?? [];
        if (responses.isEmpty) {
          return const Center(
            child: Text(
              'No responses submitted yet',
              style: TextStyle(
                color: AppColors.textSecondaryDark,
                fontSize: 15,
              ),
            ),
          );
        }
        return ListView.builder(
          itemCount: responses.length,
          itemBuilder: (context, index) {
            final r = responses[index];
            final author = r['author'] as String? ?? 'Participant';
            final text = r['text'] as String? ?? '';
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.cardDark.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.format_quote_rounded,
                      color: AppColors.primary,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          text,
                          style: const TextStyle(
                            color: AppColors.textPrimaryDark,
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '— $author',
                          style: const TextStyle(
                            color: AppColors.textSecondaryDark,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );

      default:
        return const Center(
          child: Text(
            'Aggregating live responses...',
            style: TextStyle(color: AppColors.textSecondaryDark),
          ),
        );
    }
  }

  Color _getWordColor(int val) {
    if (val > 8) return const Color(0xFFF59E0B);
    if (val > 4) return AppColors.primary;
    return const Color(0xFF06B6D4);
  }

  Widget _buildQuizLeaderboardView() {
    final top3 = _leaderboard.take(3).toList();
    final remaining = _leaderboard.skip(3).toList();

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceDark.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(AppSizes.radiusCard),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      clipBehavior: Clip.antiAlias,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            children: [
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.emoji_events_rounded,
                    color: Colors.amber,
                    size: 32,
                  ),
                  SizedBox(width: 10),
                  Text(
                    'QUIZ LEADERBOARD',
                    style: TextStyle(
                      color: AppColors.textPrimaryDark,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // Podium Layout for Top 3
              if (top3.isNotEmpty)
                SizedBox(
                  height: 200,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // 2nd Place
                      if (top3.length > 1)
                        _buildPodiumColumn(
                          name: top3[1]['name'] as String? ?? 'Anonymous',
                          score: (top3[1]['score'] as num?)?.toInt() ?? 0,
                          rank: 2,
                          height: 100,
                          gradient: const [
                            Color(0xFFCFD8DC),
                            Color(0xFF78909C),
                          ],
                        ),
                      const SizedBox(width: 16),

                      // 1st Place
                      _buildPodiumColumn(
                        name: top3[0]['name'] as String? ?? 'Anonymous',
                        score: (top3[0]['score'] as num?)?.toInt() ?? 0,
                        rank: 1,
                        height: 140,
                        gradient: const [Color(0xFFFFD54F), Color(0xFFFFB300)],
                      ),
                      const SizedBox(width: 16),

                      // 3rd Place
                      if (top3.length > 2)
                        _buildPodiumColumn(
                          name: top3[2]['name'] as String? ?? 'Anonymous',
                          score: (top3[2]['score'] as num?)?.toInt() ?? 0,
                          rank: 3,
                          height: 75,
                          gradient: const [
                            Color(0xFFFFAB91),
                            Color(0xFFD84315),
                          ],
                        ),
                    ],
                  ),
                ),
              const SizedBox(height: 24),
              const Divider(color: Colors.white12),
              const SizedBox(height: 12),

              // Remaining Players List
              Expanded(
                child: remaining.isEmpty
                    ? const Center(
                        child: Text(
                          'No other participants on the board yet',
                          style: TextStyle(
                            color: AppColors.textSecondaryDark,
                            fontSize: 13,
                          ),
                        ),
                      )
                    : ListView.builder(
                        itemCount: remaining.length,
                        itemBuilder: (context, index) {
                          final item = remaining[index];
                          final name = item['name'] as String? ?? 'Anonymous';
                          final score = (item['score'] as num?)?.toInt() ?? 0;
                          final rank = index + 4;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.cardDark.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Text(
                                  '#$rank',
                                  style: const TextStyle(
                                    color: AppColors.textSecondaryDark,
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Text(
                                    name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: AppColors.textPrimaryDark,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                Text(
                                  '$score pts',
                                  style: const TextStyle(
                                    color: AppColors.primary,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPodiumColumn({
    required String name,
    required int score,
    required int rank,
    required double height,
    required List<Color> gradient,
  }) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(
          rank == 1 ? '👑' : rank == 2 ? '🥈' : '🥉',
          style: const TextStyle(fontSize: 24),
        ),
        const SizedBox(height: 4),
        SizedBox(
          width: 80,
          child: Text(
            name,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textPrimaryDark,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          '$score pts',
          style: TextStyle(
            color: gradient[0],
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: 80,
          height: height,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: gradient,
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(12),
              topRight: Radius.circular(12),
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            '#$rank',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQaPresentationPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Row(
              children: [
                Icon(
                  Icons.forum_rounded,
                  color: AppColors.primary,
                  size: 22,
                ),
                SizedBox(width: 8),
                Text(
                  'Live Q&A',
                  style: TextStyle(
                    color: AppColors.textPrimaryDark,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${_questions.length} questions',
                style: const TextStyle(
                  color: AppColors.textSecondaryDark,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: _questions.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.chat_bubble_outline_rounded,
                        size: 44,
                        color: AppColors.textSecondaryDark.withValues(
                          alpha: 0.4,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'No questions yet.\nJoin with code ${widget.accessCode} to ask!',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppColors.textSecondaryDark,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _questions.length,
                  itemBuilder: (context, index) {
                    final q = _questions[index];
                    final author = q['authorName'] as String? ?? 'Anonymous';
                    final text = q['text'] as String? ?? '';
                    final upvotes = (q['upvotesCount'] as num?)?.toInt() ?? 0;
                    final isPinned = q['isPinned'] == true;
                    final answerText = (q['answerText'] as String?)?.trim() ?? '';
                    final hasAnswer = answerText.isNotEmpty;
                    final isAnsweredOnly =
                        q['status'] == 'answered' && !hasAnswer;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 14),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isPinned
                              ? [
                                  AppColors.primary.withValues(alpha: 0.22),
                                  AppColors.purpleAccent.withValues(
                                    alpha: 0.14,
                                  ),
                                ]
                              : hasAnswer
                                  ? [
                                      AppColors.success.withValues(alpha: 0.12),
                                      AppColors.cardDark.withValues(alpha: 0.3),
                                    ]
                                  : [
                                      AppColors.cardDark.withValues(alpha: 0.35),
                                      AppColors.cardDark.withValues(alpha: 0.25),
                                    ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isPinned
                              ? AppColors.primary.withValues(alpha: 0.4)
                              : hasAnswer
                                  ? AppColors.success.withValues(alpha: 0.35)
                                  : Colors.white.withValues(alpha: 0.08),
                          width: isPinned || hasAnswer ? 1.5 : 1.0,
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (isPinned)
                              const Padding(
                                padding: EdgeInsets.only(bottom: 8),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.push_pin_rounded,
                                      color: AppColors.accent,
                                      size: 13,
                                    ),
                                    SizedBox(width: 5),
                                    Text(
                                      'PINNED QUESTION',
                                      style: TextStyle(
                                        color: AppColors.accent,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 0.8,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            Text(
                              text,
                              style: const TextStyle(
                                color: AppColors.textPrimaryDark,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                height: 1.3,
                              ),
                            ),

                            // Host Answer Section
                            if (hasAnswer) ...[
                              const SizedBox(height: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      AppColors.success.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color:
                                        AppColors.success.withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(
                                      Icons.verified_rounded,
                                      color: AppColors.success,
                                      size: 15,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'HOST ANSWER',
                                            style: TextStyle(
                                              color: AppColors.success,
                                              fontSize: 9,
                                              fontWeight: FontWeight.w900,
                                              letterSpacing: 0.8,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            answerText,
                                            style: const TextStyle(
                                              color: AppColors.textPrimaryDark,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ] else if (isAnsweredOnly) ...[
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      AppColors.success.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.check_circle_rounded,
                                      color: AppColors.success,
                                      size: 12,
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      'Answered Live',
                                      style: TextStyle(
                                        color: AppColors.success,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],

                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '— $author',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: AppColors.textSecondaryDark,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.thumb_up_rounded,
                                      color: AppColors.secondary,
                                      size: 13,
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      '$upvotes',
                                      style: const TextStyle(
                                        color: AppColors.secondary,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 12,
                                      ),
                                    ),
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
}
