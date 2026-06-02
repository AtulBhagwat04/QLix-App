import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/network/socket_client.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/storage/cache_manager.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../qa/domain/repositories/qa_repository.dart';
import '../../domain/repositories/poll_repository.dart';
import '../../../quiz/domain/repositories/quiz_repository.dart';
import '../../../sessions/domain/repositories/session_repository.dart';

class ParticipantWorkspaceScreen extends StatefulWidget {
  final String accessCode;
  const ParticipantWorkspaceScreen({super.key, required this.accessCode});

  @override
  State<ParticipantWorkspaceScreen> createState() => _ParticipantWorkspaceScreenState();
}

class _ParticipantWorkspaceScreenState extends State<ParticipantWorkspaceScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  final _socketClient = sl<SocketClient>();
  final _cacheManager = sl<CacheManager>();

  Map<String, dynamic>? _participant;
  Map<String, dynamic>? _session;
  
  // Real-time elements
  Map<String, dynamic>? _activePoll;
  List<Map<String, dynamic>> _questions = [];
  List<Map<String, dynamic>> _announcements = [];
  
  // Optimistic UI tracking
  final Set<String> _votedPollIds = {};

  // Quiz states
  Map<String, dynamic>? _activeQuiz;
  int _quizTimeRemaining = 0;
  bool _hasAnsweredQuiz = false;

  // Q&A controller
  final _questionInputCtrl = TextEditingController();
  bool _qaAnonymous = true;

  // Active Poll inputs
  List<String> _selectedOptionIds = []; // For MC
  final _textResponseCtrl = TextEditingController(); // For Word Cloud / Open Text
  double _ratingValue = 3.0; // For Rating
  List<Map<String, dynamic>> _rankingOptions = []; // For Ranking reordering

  // Sockets streams
  StreamSubscription? _activationSub;
  StreamSubscription? _votesSub;
  StreamSubscription? _qaSub;
  StreamSubscription? _qaStatusSub;
  StreamSubscription? _qaUpvotedSub;
  StreamSubscription? _quizSub;
  StreamSubscription? _announcementSub;

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
    _textResponseCtrl.dispose();
    
    _activationSub?.cancel();
    _votesSub?.cancel();
    _qaSub?.cancel();
    _qaStatusSub?.cancel();
    _qaUpvotedSub?.cancel();
    _quizSub?.cancel();
    _announcementSub?.cancel();
    super.dispose();
  }

  Future<void> _initializeWorkspace() async {
    final cached = _cacheManager.getSessionParticipant(widget.accessCode);
    if (cached == null) {
      context.go('/');
      return;
    }

    try {
      final details = await sl<SessionRepository>().joinSessionByCode(
        widget.accessCode,
        _cacheManager.getDeviceId() ?? '',
        cached['name'] as String?,
        true,
      );

      setState(() {
        _session = details['session'] as Map<String, dynamic>;
        _participant = details['participant'] as Map<String, dynamic>;
      });

      final sessionId = _session!['id'] as String;

      // Load initial questions list
      final questions = await sl<QaRepository>().getSessionQuestions(sessionId, participantId: _participant!['id'] as String);
      setState(() {
        _questions = questions;
      });

      // Load active poll details if active
      if (_session!['active_poll_id'] != null) {
        final poll = await sl<PollRepository>().getPollResults(_session!['active_poll_id'] as String);
        setState(() {
          _activePoll = poll;
          if (poll['type'] == 'ranking') {
            _rankingOptions = List<Map<String, dynamic>>.from(poll['options'] as List);
          }
        });
      }

      // Connect to websocket room
      _socketClient.connect();
      _socketClient.joinSession(widget.accessCode, _participant!['id'] as String, 'participant');

      // Bind WebSockets Streams
      _activationSub = _socketClient.pollActivationStream.listen((data) {
        setState(() {
          if (data == null) {
            _activePoll = null;
          } else {
            _activePoll = Map<String, dynamic>.from(data['poll'] as Map);
            _selectedOptionIds.clear();
            _textResponseCtrl.clear();
            _ratingValue = 3.0;
            if (_activePoll!['type'] == 'ranking') {
              _rankingOptions = List<Map<String, dynamic>>.from(_activePoll!['options'] as List);
            }
          }
        });
      });

      _votesSub = _socketClient.votesUpdatedStream.listen((data) {
        final pollId = data['pollId'] as String;
        if (_activePoll != null && _activePoll!['id'] == pollId) {
          setState(() {
            _activePoll!['results'] = data['results'];
          });
        }
      });

      _qaSub = _socketClient.questionCreatedStream.listen((data) {
        final newQ = Map<String, dynamic>.from(data['question'] as Map);
        setState(() {
          // Remove corresponding optimistic question first
          _questions.removeWhere((q) => 
            q['isOptimistic'] == true && 
            q['text'] == newQ['text'] && 
            q['participantId'] == newQ['participantId']
          );

          final isMine = newQ['participantId'] == _participant!['id'];
          final isApproved = newQ['status'] == 'approved';
          
          if ((isApproved || isMine) && !_questions.any((q) => q['id'] == newQ['id'])) {
            _questions.insert(0, newQ);
          }
        });
      });

      _qaStatusSub = _socketClient.questionStatusStream.listen((data) {
        final updatedQ = Map<String, dynamic>.from(data['question'] as Map);
        setState(() {
          final index = _questions.indexWhere((q) => q['id'] == updatedQ['id']);
          final isMine = updatedQ['participantId'] == _participant!['id'];
          final isApproved = updatedQ['status'] == 'approved' || updatedQ['status'] == 'answered';

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
        final qId = data['questionId'] as String;
        final count = data['upvotesCount'] as int? ?? 0;
        setState(() {
          for (var q in _questions) {
            if (q['id'] == qId) {
              q['upvotesCount'] = count;
            }
          }
        });
      });

      _quizSub = _socketClient.quizTimerStream.listen((data) {
        final event = data['event'] as String;
        final pollId = data['pollId'] as String;

        if (event == 'start') {
          setState(() {
            _activeQuiz = {'id': pollId};
            _quizTimeRemaining = data['durationSeconds'] as int;
            _hasAnsweredQuiz = false;
          });
          sl<PollRepository>().getPollResults(pollId).then((details) {
            setState(() {
              _activeQuiz = details;
            });
          }).catchError((e) {
            // fail gracefully
          });
        } else if (event == 'tick') {
          setState(() {
            _quizTimeRemaining = data['remaining'] as int;
          });
        } else if (event == 'end') {
          setState(() {
            _activeQuiz = null;
            _quizTimeRemaining = 0;
          });
        }
      });

      _announcementSub = _socketClient.announcementStream.listen((data) {
        final alert = Map<String, dynamic>.from(data['announcement'] as Map);
        setState(() {
          _announcements.insert(0, alert);
        });
        _showAnnouncementDialog(alert['title'] as String, alert['message'] as String);
      });

      _socketClient.reactionStream.listen((data) {
        final emoji = data['emoji'] as String;
        _triggerLocalReaction(emoji);
      });

    } catch (e) {
      // debug log
    }
  }

  void _showAnnouncementDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          icon: const Icon(Icons.campaign_rounded, color: AppColors.primary, size: AppSizes.iconLarge),
          title: Text(title, textAlign: TextAlign.center),
          content: Text(message, textAlign: TextAlign.center),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Dismiss'),
            ),
          ],
        );
      },
    );
  }

  void _calculateOptimisticResults() {
    if (_activePoll == null) return;
    final type = _activePoll!['type'] as String;
    
    final Map<String, dynamic> results = Map<String, dynamic>.from(_activePoll!['results'] ?? {});
    
    if (type == 'multiple_choice') {
      final options = List<Map<String, dynamic>>.from(results['options'] ?? _activePoll!['options']?.map((o) => {
        'id': o['id'],
        'optionText': o['optionText'],
        'isCorrect': o['isCorrect'] ?? false,
        'votes': 0,
        'percentage': 0,
      })?.toList() ?? []);

      int totalVotes = results['totalVotes'] as int? ?? 0;
      totalVotes += 1;

      for (var opt in options) {
        if (_selectedOptionIds.contains(opt['id'])) {
          opt['votes'] = (opt['votes'] as int? ?? 0) + 1;
        }
      }

      for (var opt in options) {
        opt['percentage'] = totalVotes > 0 ? (((opt['votes'] as int) / totalVotes) * 100).round() : 0;
      }

      results['totalVotes'] = totalVotes;
      results['options'] = options;
    } else if (type == 'rating') {
      int totalVotes = results['totalVotes'] as int? ?? 0;
      double average = (results['average'] as num?)?.toDouble() ?? 0.0;
      final int val = _ratingValue.round();

      final newTotal = totalVotes + 1;
      final newAverage = ((average * totalVotes) + val) / newTotal;

      results['totalVotes'] = newTotal;
      results['average'] = newAverage;
    } else if (type == 'word_cloud') {
      int totalVotes = results['totalVotes'] as int? ?? 0;
      final words = List<Map<String, dynamic>>.from(results['words'] ?? []);
      final word = _textResponseCtrl.text.trim().toLowerCase();

      if (word.isNotEmpty) {
        totalVotes += 1;
        final idx = words.indexWhere((w) => w['text'] == word);
        if (idx != -1) {
          words[idx]['value'] = (words[idx]['value'] as int) + 1;
        } else {
          words.add({'text': word, 'value': 1});
        }
      }
      results['totalVotes'] = totalVotes;
      results['words'] = words..sort((a, b) => (b['value'] as int) - (a['value'] as int));
    } else if (type == 'open_text') {
      int totalVotes = results['totalVotes'] as int? ?? 0;
      final responses = List<Map<String, dynamic>>.from(results['responses'] ?? []);
      final text = _textResponseCtrl.text.trim();

      if (text.isNotEmpty) {
        totalVotes += 1;
        responses.insert(0, {
          'id': 'temp-vote',
          'text': text,
          'author': _participant!['name'] as String? ?? 'Anonymous',
          'createdAt': DateTime.now().toIso8601String(),
        });
      }
      results['totalVotes'] = totalVotes;
      results['responses'] = responses;
    } else if (type == 'ranking') {
      int totalVotes = results['totalVotes'] as int? ?? 0;
      totalVotes += 1;
      
      final options = List<Map<String, dynamic>>.from(results['options'] ?? _activePoll!['options']?.map((o) => {
        'id': o['id'],
        'optionText': o['optionText'],
        'score': 0,
        'votes': 0,
      })?.toList() ?? []);

      final n = options.length;
      final rankedIds = _rankingOptions.map((o) => o['id'] as String).toList();

      for (var opt in options) {
        final rank = rankedIds.indexOf(opt['id'] as String);
        if (rank != -1) {
          opt['score'] = (opt['score'] as int) + (n - rank);
          opt['votes'] = (opt['votes'] as int) + 1;
        }
      }

      results['totalVotes'] = totalVotes;
      results['options'] = options..sort((a, b) => (b['score'] as int) - (a['score'] as int));
    }

    setState(() {
      _activePoll!['results'] = results;
    });
  }

  void _submitVote() {
    if (_activePoll == null || _participant == null) return;
    
    final pollId = _activePoll!['id'] as String;

    // Apply Optimistic updates locally immediately!
    setState(() {
      _votedPollIds.add(pollId);
    });
    _calculateOptimisticResults();

    _socketClient.submitVote(
      pollId: pollId,
      participantId: _participant!['id'] as String,
      optionIds: _selectedOptionIds,
      textResponse: _textResponseCtrl.text,
      ratingValue: _ratingValue.round(),
      rankingIds: _rankingOptions.map((o) => o['id'] as String).toList(),
    );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(AppStrings.successVoteSubmit),
        backgroundColor: AppColors.success,
      ),
    );
  }

  void _submitQuestion() {
    final text = _questionInputCtrl.text.trim();
    if (text.isEmpty || _session == null || _participant == null) return;

    // Instant Q&A Optimistic update
    final tempId = 'temp-${DateTime.now().millisecondsSinceEpoch}';
    final tempQ = {
      'id': tempId,
      'sessionId': _session!['id'] as String,
      'participantId': _participant!['id'] as String,
      'text': text,
      'isAnonymous': _qaAnonymous,
      'status': 'pending',
      'upvotesCount': 0,
      'isPinned': false,
      'authorName': _qaAnonymous ? 'Anonymous' : (_participant!['name'] as String? ?? 'Guest'),
      'createdAt': DateTime.now().toIso8601String(),
      'isOptimistic': true, // visual loader tag
    };

    setState(() {
      _questions.insert(0, tempQ);
    });

    _socketClient.submitQuestion(
      sessionId: _session!['id'] as String,
      participantId: _participant!['id'] as String,
      text: text,
      isAnonymous: _qaAnonymous,
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
          q['upvotesCount'] = (q['upvotesCount'] as int) + (currentHasUpvoted ? -1 : 1);
        }
      }
    });

    _socketClient.upvoteQuestion(
      sessionId: _session!['id'] as String,
      questionId: questionId,
      participantId: _participant!['id'] as String,
    );
  }

  void _submitQuizAnswer(String optionId) {
    if (_activeQuiz == null || _participant == null) return;
    
    setState(() {
      _hasAnsweredQuiz = true;
    });

    final messenger = ScaffoldMessenger.of(context);

    sl<QuizRepository>().submitQuizAnswer(
      _session!['id'] as String,
      _participant!['id'] as String,
      _activeQuiz!['id'] as String,
      optionId,
    ).then((res) {
      final isCorrect = res['isCorrect'] as bool;
      final points = res['pointsEarned'] as int;
      messenger.showSnackBar(
        SnackBar(
          content: Text(isCorrect ? 'CORRECT! Earned $points pts!' : 'WRONG ANSWER! 0 pts.'),
          backgroundColor: isCorrect ? AppColors.success : AppColors.error,
        ),
      );
    }).catchError((e) {
      setState(() {
        _hasAnsweredQuiz = false;
      });
      messenger.showSnackBar(
        SnackBar(
          content: Text('Failed to submit answer: $e'),
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

  @override
  Widget build(BuildContext context) {
    if (_session == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: AppColors.primary)));
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_session!['title'] as String, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: -0.3)),
                Text(AppStrings.participantTitle, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isDark ? Colors.white38 : Colors.black38)),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.exit_to_app_rounded, color: AppColors.error),
                tooltip: 'Leave Room',
                onPressed: () {
                  _socketClient.disconnect();
                  context.go('/');
                },
              ),
            ],
            bottom: TabBar(
              controller: _tabController,
              indicatorColor: AppColors.primary,
              indicatorSize: TabBarIndicatorSize.label,
              labelColor: AppColors.primary,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold),
              unselectedLabelColor: isDark ? Colors.white60 : Colors.black54,
              tabs: const [
                Tab(icon: Icon(Icons.poll_rounded), text: AppStrings.livePollsTab),
                Tab(icon: Icon(Icons.question_answer_rounded), text: AppStrings.qaTab),
              ],
            ),
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              _buildPollsTabView(),
              _buildQaTabView(),
            ],
          ),
          bottomNavigationBar: _buildReactionTool(),
        ),
      ],
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
              _reactionBtn('😮'),
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

  Widget _buildPollsTabView() {
    if (_activeQuiz != null) {
      return _buildQuizActiveView();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_activePoll == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.wifi_tethering_off_rounded, size: 72, color: isDark ? Colors.white24 : Colors.black12),
              const SizedBox(height: AppSizes.space16),
              const Text(AppStrings.noActivePoll, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: AppSizes.space8),
              Text(
                AppStrings.noActivePollSub, 
                textAlign: TextAlign.center,
                style: TextStyle(color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
              ),
            ],
          ),
        ),
      );
    }

    final pollId = _activePoll!['id'] as String;

    // IF user has voted
    if (_votedPollIds.contains(pollId)) {
      return _buildPollResultsView();
    }

    final type = _activePoll!['type'] as String;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSizes.space24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            type.replaceAll('_', ' ').toUpperCase(),
            style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 0.5),
          ),
          const SizedBox(height: AppSizes.space8),
          Text(
            _activePoll!['title'] as String,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.4),
          ),
          const SizedBox(height: AppSizes.space24),

          _buildPollForm(type),
          
          const SizedBox(height: AppSizes.space32),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppSizes.radiusButton),
              gradient: const LinearGradient(colors: AppColors.primaryGradient),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.25),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                )
              ]
            ),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: AppSizes.space16),
              ),
              onPressed: _submitVote,
              child: const Text(AppStrings.submitResponse, style: AppTextStyles.buttonText),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPollResultsView() {
    final type = _activePoll!['type'] as String;
    final results = _activePoll!['results'] as Map<String, dynamic>?;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (results == null) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: AppColors.primary),
            SizedBox(height: AppSizes.space16),
            Text('Calculating results...', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          ],
        ),
      );
    }

    final totalVotes = results['totalVotes'] as int? ?? 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSizes.space24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.success),
              ),
              const SizedBox(width: 8),
              Text(
                'LIVE RESULTS: ${type.replaceAll('_', ' ').toUpperCase()}',
                style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 0.5),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.space8),
          Text(
            _activePoll!['title'] as String,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.4),
          ),
          const SizedBox(height: AppSizes.space24),
          
          _buildResultsChart(type, results),
          
          const SizedBox(height: AppSizes.space36),
          Text(
            'Total Responses: $totalVotes',
            style: TextStyle(color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight, fontSize: 13, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildResultsChart(String type, Map<String, dynamic> results) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    switch (type) {
      case 'multiple_choice':
        final options = results['options'] as List? ?? [];
        return Column(
          children: options.map((opt) {
            final text = opt['optionText'] as String? ?? '';
            final percentage = opt['percentage'] as int? ?? 0;
            final votes = opt['votes'] as int? ?? 0;
            final id = opt['id'] as String;
            final isSelected = _selectedOptionIds.contains(id);

            return Container(
              margin: const EdgeInsets.only(bottom: AppSizes.space16),
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
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            color: isSelected ? AppColors.primary : (isDark ? Colors.white70 : AppColors.textPrimaryLight),
                          ),
                        ),
                      ),
                      Text(
                        '$percentage% ($votes)',
                        style: TextStyle(
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          color: isSelected ? AppColors.primary : (isDark ? Colors.white60 : Colors.black54),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSizes.space8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppSizes.radiusSmall),
                    child: LinearProgressIndicator(
                      value: percentage / 100,
                      backgroundColor: isDark ? Colors.white10 : Colors.black.withOpacity(0.04),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        isSelected ? AppColors.primary : AppColors.primary.withOpacity(0.4),
                      ),
                      minHeight: AppSizes.barHeight * 2.5,
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
              style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: AppColors.primary, letterSpacing: -0.5),
            ),
            const SizedBox(height: AppSizes.space12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                final starVal = index + 1;
                return Icon(
                  starVal <= average.round() ? Icons.star_rounded : Icons.star_border_rounded,
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
          return const Text('No responses yet.', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold), textAlign: TextAlign.center);
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
              backgroundColor: AppColors.primary.withOpacity(0.12),
              side: BorderSide(color: AppColors.primary.withOpacity(0.2)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSizes.radiusBadge)),
              label: Text(
                '$text ($val)',
                style: TextStyle(fontSize: size, color: isDark ? Colors.white : AppColors.textPrimaryLight, fontWeight: FontWeight.bold),
              ),
            );
          }).toList(),
        );

      case 'open_text':
        final responses = results['responses'] as List? ?? [];
        if (responses.isEmpty) {
          return Text('No responses yet.', style: TextStyle(color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight, fontWeight: FontWeight.bold), textAlign: TextAlign.center);
        }
        return Column(
          children: responses.map((r) {
            final text = r['text'] as String? ?? '';
            final author = r['author'] as String? ?? 'Anonymous';
            return Card(
              margin: const EdgeInsets.only(bottom: AppSizes.space12),
              child: ListTile(
                title: Text(text, style: const TextStyle(fontWeight: FontWeight.w500)),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('By $author', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
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
                  backgroundColor: AppColors.primary.withOpacity(0.15),
                  child: Text('${idx + 1}', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                ),
                title: Text(text, style: const TextStyle(fontWeight: FontWeight.bold)),
                trailing: Text('$score pts', style: TextStyle(color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight, fontWeight: FontWeight.w600)),
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

    final timeColor = _quizTimeRemaining > 10
        ? AppColors.success
        : (_quizTimeRemaining > 5 ? AppColors.warning : AppColors.error);

    Widget timerWidget = Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: timeColor.withOpacity(0.12),
        borderRadius: BorderRadius.circular(AppSizes.radiusPill),
        border: Border.all(color: timeColor.withOpacity(0.3), width: 1.0),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.timer_outlined, size: 14, color: timeColor),
          const SizedBox(width: 6),
          Text(
            '$_quizTimeRemaining s', 
            style: TextStyle(color: timeColor, fontWeight: FontWeight.bold, fontSize: 13),
          ),
        ],
      ),
    );

    return Container(
      padding: const EdgeInsets.all(AppSizes.space24),
      color: AppColors.primary.withOpacity(0.02),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(AppStrings.quizTitle, style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 0.5)),
              timerWidget,
            ],
          ),
          const SizedBox(height: AppSizes.space24),
          Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.4)),
          const SizedBox(height: AppSizes.space32),
          if (_hasAnsweredQuiz) ...[
            Center(
              child: Column(
                children: [
                  const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 64),
                  const SizedBox(height: AppSizes.space16),
                  const Text(AppStrings.answerSubmitted, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(
                    AppStrings.quizWaitResults, 
                    style: TextStyle(color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
                  ),
                ],
              ),
            ),
          ] else ...[
            ...options.map((opt) {
              final id = opt['id'] as String;
              return Container(
                margin: const EdgeInsets.only(bottom: AppSizes.space16),
                child: InkWell(
                  onTap: () => _submitQuizAnswer(id),
                  borderRadius: BorderRadius.circular(AppSizes.radiusCard),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.02),
                      borderRadius: BorderRadius.circular(AppSizes.radiusCard),
                      border: Border.all(color: isDark ? Colors.white10 : Colors.black12, width: 1.0),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 12,
                          backgroundColor: AppColors.primary.withOpacity(0.15),
                          child: const Icon(Icons.star_rounded, size: 12, color: AppColors.primary),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            opt['optionText'] as String, 
                            style: TextStyle(
                              fontSize: 15, 
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : AppColors.textPrimaryLight,
                            ),
                          ),
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

  Widget _buildPollForm(String type) {
    final options = _activePoll!['options'] as List? ?? [];
    final isDark = Theme.of(context).brightness == Brightness.dark;

    switch (type) {
      case 'multiple_choice':
        return Column(
          children: options.map((opt) {
            final id = opt['id'] as String;
            final isSelected = _selectedOptionIds.contains(id);
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              child: InkWell(
                onTap: () {
                  setState(() {
                    _selectedOptionIds.clear(); // Single-select by default
                    _selectedOptionIds.add(id);
                  });
                },
                borderRadius: BorderRadius.circular(AppSizes.radiusCard),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                  decoration: BoxDecoration(
                    color: isSelected 
                        ? AppColors.primary.withOpacity(isDark ? 0.12 : 0.08)
                        : (isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.02)),
                    borderRadius: BorderRadius.circular(AppSizes.radiusCard),
                    border: Border.all(
                      color: isSelected ? AppColors.primary : Colors.transparent,
                      width: 2.0,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isSelected ? Icons.check_circle_rounded : Icons.radio_button_off_rounded,
                        color: isSelected ? AppColors.primary : Colors.grey,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          opt['optionText'] as String,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            color: isDark ? Colors.white : AppColors.textPrimaryLight,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
            }).toList(),
        );

      case 'word_cloud':
      case 'open_text':
        return TextField(
          controller: _textResponseCtrl,
          decoration: InputDecoration(
            labelText: AppStrings.wordCloudHint,
            prefixIcon: const Icon(Icons.edit_note_rounded),
            hintText: type == 'word_cloud' ? 'Enter a single word...' : 'Enter your open thoughts...',
          ),
          maxLength: type == 'word_cloud' ? 20 : 250,
        );

      case 'rating':
        return Column(
          children: [
            Text('${_ratingValue.toInt()} / 5 Stars', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.primary)),
            const SizedBox(height: AppSizes.space16),
            Slider(
              value: _ratingValue,
              min: 1.0,
              max: 5.0,
              divisions: 4,
              activeColor: AppColors.primary,
              inactiveColor: AppColors.primary.withOpacity(0.15),
              onChanged: (val) {
                setState(() {
                  _ratingValue = val;
                });
              },
            ),
          ],
        );

      case 'ranking':
        return Column(
          children: [
            Text(AppStrings.rankingGuide, style: TextStyle(color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight, fontSize: 13, fontWeight: FontWeight.w500)),
            const SizedBox(height: AppSizes.space16),
            ReorderableListView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: List.generate(_rankingOptions.length, (idx) {
                final opt = _rankingOptions[idx];
                return Card(
                  key: ValueKey(opt['id']),
                  margin: const EdgeInsets.only(bottom: AppSizes.space12),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppColors.primary.withOpacity(0.15),
                      child: Text('${idx + 1}', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                    ),
                    title: Text(opt['optionText'] as String, style: const TextStyle(fontWeight: FontWeight.bold)),
                    trailing: const Icon(Icons.drag_handle_rounded),
                  ),
                );
              }),
              onReorder: (oldIdx, newIdx) {
                setState(() {
                  if (newIdx > oldIdx) newIdx -= 1;
                  final item = _rankingOptions.removeAt(oldIdx);
                  _rankingOptions.insert(newIdx, item);
                });
              },
            ),
          ],
        );

      default:
        return const SizedBox.shrink();
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
                    prefixIcon: Icon(Icons.question_mark_rounded),
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
        // Filters
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSizes.space16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                AppStrings.postAnonymously, 
                style: TextStyle(fontSize: 12, color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight, fontWeight: FontWeight.bold),
              ),
              Switch(
                value: _qaAnonymous,
                activeColor: AppColors.primary,
                onChanged: (val) {
                  setState(() {
                    _qaAnonymous = val;
                  });
                },
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
                      Icon(Icons.forum_outlined, size: 48, color: isDark ? Colors.white24 : Colors.black12),
                      const SizedBox(height: 12),
                      const Text('No questions asked yet', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(AppSizes.space16),
                  itemCount: _questions.length,
                  itemBuilder: (context, index) {
                    final q = _questions[index];
                    final qId = q['id'] as String;
                    final author = q['authorName'] as String? ?? 'Anonymous';
                    final text = q['text'] as String;
                    final upvotes = q['upvotesCount'] as int? ?? 0;
                    final hasUpvoted = q['hasUpvoted'] as bool? ?? false;
                    final isPinned = q['isPinned'] as bool? ?? false;
                    final isAnswered = q['status'] == 'answered';
                    final isOptimistic = q['isOptimistic'] == true;

                    return Card(
                      color: isPinned 
                          ? AppColors.primary.withOpacity(0.06) 
                          : (isAnswered ? (isDark ? Colors.black12 : Colors.grey[50]) : null),
                      margin: const EdgeInsets.only(bottom: AppSizes.space12),
                      shape: RoundedRectangleBorder(
                        side: BorderSide(
                          color: isPinned ? AppColors.primary.withOpacity(0.3) : (isDark ? Colors.white10 : Colors.black12),
                          width: isPinned ? 1.5 : 1.0,
                        ),
                        borderRadius: BorderRadius.circular(AppSizes.radiusCard),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        title: Row(
                          children: [
                            if (isPinned) ...[
                              const Icon(Icons.push_pin, color: Colors.orange, size: 16),
                              const SizedBox(width: 6),
                            ],
                            Expanded(
                              child: Text(
                                text,
                                style: TextStyle(
                                  decoration: isAnswered ? TextDecoration.lineThrough : null,
                                  fontWeight: isPinned ? FontWeight.bold : FontWeight.normal,
                                  color: isAnswered 
                                      ? Colors.grey 
                                      : (isOptimistic ? (isDark ? Colors.white54 : Colors.black54) : (isDark ? Colors.white : Colors.black87)),
                                ),
                              ),
                            ),
                            if (isOptimistic) ...[
                              const SizedBox(width: 8),
                              const SizedBox(
                                width: 12,
                                height: 12,
                                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                              ),
                            ],
                          ],
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 8,
                                backgroundColor: AppColors.primary.withOpacity(0.2),
                                child: Text(author.isNotEmpty ? author[0].toUpperCase() : 'A', style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: AppColors.primary)),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'By $author • ${isAnswered ? 'ANSWERED' : isOptimistic ? 'Sending...' : 'Active'}',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                        trailing: TextButton.icon(
                          onPressed: isOptimistic ? null : () => _upvoteQuestion(qId, hasUpvoted),
                          icon: Icon(
                            hasUpvoted ? Icons.thumb_up_rounded : Icons.thumb_up_outlined,
                            color: AppColors.primary,
                            size: 16,
                          ),
                          label: Text(
                            '$upvotes',
                            style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 13),
                          ),
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



