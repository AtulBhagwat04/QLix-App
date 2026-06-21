import 'dart:async';
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/network/socket_client.dart';
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

class _PresenterModeScreenState extends State<PresenterModeScreen> with SingleTickerProviderStateMixin {
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

  // Floating reaction particles
  @override
  void initState() {
    super.initState();
    _loadSessionDetails();
  }

  @override
  void dispose() {
    _activationSub?.cancel();
    _votesSub?.cancel();
    _qaSub?.cancel();
    _qaStatusSub?.cancel();
    _qaUpvotedSub?.cancel();
    _quizSub?.cancel();
    _socketClient.disconnect();
    super.dispose();
  }

  Future<void> _loadSessionDetails() async {
    try {
      final details = await sl<SessionRepository>().joinSessionByCode(
        widget.accessCode,
        'presenter_device', // dummy device ID for presenter
        'Presenter Screen',
        false,
      );

      setState(() {
        _session = details['session'] as Map<String, dynamic>;
      });

      final sessionId = _session!['id'] as String;

      // Join Sockets Room
      _socketClient.connect();
      _socketClient.joinSession(widget.accessCode, 'presenter', 'presenter');

      // Load initial active poll if set
      if (_session!['active_poll_id'] != null) {
        _fetchActivePollResults(_session!['active_poll_id'] as String);
      }

      // Load initial Q&A questions
      final questions = await sl<QaRepository>().getSessionQuestions(sessionId, status: 'approved', sortBy: 'popular');
      setState(() {
        _questions = questions;
      });

      // Bind socket events
      _activationSub = _socketClient.pollActivationStream.listen((data) {
        setState(() {
          if (data == null) {
            _activePoll = null;
          } else {
            _activePoll = Map<String, dynamic>.from(data['poll'] as Map);
            _fetchActivePollResults(_activePoll!['id'] as String);
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
          if (newQ['status'] == 'approved' && !_questions.any((q) => q['id'] == newQ['id'])) {
            _questions.insert(0, newQ);
            _questions.sort((a, b) => (b['upvotesCount'] as int? ?? 0).compareTo(a['upvotesCount'] as int? ?? 0));
          }
        });
      });

      _qaStatusSub = _socketClient.questionStatusStream.listen((data) {
        final updatedQ = Map<String, dynamic>.from(data['question'] as Map);
        setState(() {
          final index = _questions.indexWhere((q) => q['id'] == updatedQ['id']);
          final isApproved = updatedQ['status'] == 'approved' || updatedQ['status'] == 'answered';

          if (index != -1) {
            if (isApproved) {
              _questions[index] = updatedQ;
            } else {
              _questions.removeAt(index);
            }
          } else if (isApproved) {
            _questions.insert(0, updatedQ);
          }
          _questions.sort((a, b) => (b['upvotesCount'] as int? ?? 0).compareTo(a['upvotesCount'] as int? ?? 0));
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
          _questions.sort((a, b) => (b['upvotesCount'] as int? ?? 0).compareTo(a['upvotesCount'] as int? ?? 0));
        });
      });

      // Reaction animations emitter

      // Quiz state triggers
      _quizSub = _socketClient.quizTimerStream.listen((data) {
        final event = data['event'] as String;
        if (event == 'end') {
          // Fetch leaderboard
          sl<QuizRepository>().getLeaderboard(sessionId).then((lb) {
            setState(() {
              _leaderboard = lb;
            });
          });
        }
      });

    } catch (e) {
      print(e);
    }
  }

  Future<void> _fetchActivePollResults(String pollId) async {
    try {
      final results = await sl<PollRepository>().getPollResults(pollId);
      setState(() {
        _activePoll = results;
      });
    } catch (e) {
      print(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_session == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final code = _session!['access_code'] as String;

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
          // Blur bubbles
          Positioned(
            top: -100,
            left: -100,
            child: Container(
              width: 400,
              height: 400,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.18),
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
                color: AppColors.secondary.withOpacity(0.15),
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
                color: AppColors.purpleAccent.withOpacity(0.08),
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
              padding: const EdgeInsets.all(36),
              child: Column(
                children: [
                  // Presentation Header
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isMobile = MediaQuery.of(context).size.width < 800;
                      if (isMobile) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 10,
                                      height: 10,
                                      decoration: const BoxDecoration(
                                        color: AppColors.success,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    const Text(
                                      'LIVE PRESENTATION',
                                      style: TextStyle(
                                        color: AppColors.success,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1.5,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _session!['title'] as String,
                                  style: const TextStyle(
                                    color: AppColors.textPrimaryDark,
                                    fontSize: 28,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -1.0,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'Live Audience Engagement Dashboard',
                                  style: TextStyle(
                                    color: AppColors.textSecondaryDark,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: _buildQrCard(code),
                            ),
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
                                Row(
                                  children: [
                                    Container(
                                      width: 10,
                                      height: 10,
                                      decoration: const BoxDecoration(
                                        color: AppColors.success,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    const Text(
                                      'LIVE PRESENTATION',
                                      style: TextStyle(
                                        color: AppColors.success,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1.5,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _session!['title'] as String,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: AppColors.textPrimaryDark,
                                    fontSize: 36,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -1.0,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'Live Audience Engagement Dashboard',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: AppColors.textSecondaryDark,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 24),
                          _buildQrCard(code),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 36),
                  const Divider(color: Colors.white12),
                  const SizedBox(height: 24),

                  // Split View: Active poll results on the left, Q&A pinned list on the right
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final isMobile = MediaQuery.of(context).size.width < 900;
                        if (isMobile) {
                          return SingleChildScrollView(
                            child: Column(
                              children: [
                                // Top: Poll Results
                                SizedBox(
                                  height: 420,
                                  child: _buildActivePresentationPanel(),
                                ),
                                const SizedBox(height: 24),
                                // Bottom: Live Q&A
                                SizedBox(
                                  height: 380,
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
                            const SizedBox(width: 36),
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

  Widget _buildQrCard(String code) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark.withOpacity(0.55),
        borderRadius: BorderRadius.circular(AppSizes.radiusCard),
        border: Border.all(color: AppColors.primary.withOpacity(0.35), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.15),
            blurRadius: 16,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppSizes.radiusCard),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 8,
                ),
              ],
            ),
            child: QrImageView(
              data: 'http://localhost:3000/session/$code',
              version: QrVersions.auto,
              size: 72,
              gapless: false,
              foregroundColor: Colors.black,
            ),
          ),
          const SizedBox(width: 20),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Row(
                children: [
                  Text('Join at ', style: TextStyle(color: AppColors.textSecondaryDark, fontSize: 16)),
                  Text('qlix.app', style: TextStyle(color: AppColors.textPrimaryDark, fontWeight: FontWeight.bold, fontSize: 18)),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Text('Code: ', style: TextStyle(color: AppColors.textSecondaryDark, fontSize: 16)),
                  Text(
                    code,
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w900,
                      fontSize: 26,
                      letterSpacing: 1.0,
                    ),
                  ),
                ],
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
          color: AppColors.surfaceDark.withOpacity(0.45),
          borderRadius: BorderRadius.circular(AppSizes.radiusCard),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        clipBehavior: Clip.antiAlias,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.slideshow_rounded, size: 96, color: Colors.white.withOpacity(0.15)),
                  const SizedBox(height: 24),
                  const Text(
                    'Welcome! We\'re ready to start.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textPrimaryDark, fontSize: 26, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Please join the session room using the access code above to participate.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textSecondaryDark, fontSize: 16),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final type = _activePoll!['type'] as String;
    final title = _activePoll!['title'] as String;
    final results = _activePoll!['results'] as Map<String, dynamic>?;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceDark.withOpacity(0.45),
        borderRadius: BorderRadius.circular(AppSizes.radiusCard),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(AppSizes.radiusPill),
                      border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                    ),
                    child: Text(
                      type.replaceAll('_', ' ').toUpperCase(),
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                  if (results != null)
                    Text(
                      '${results['totalVotes'] ?? 0} responses',
                      style: const TextStyle(
                        color: AppColors.textSecondaryDark,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.textPrimaryDark,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 36),
              Expanded(
                child: _buildChartRenderer(type, results),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChartRenderer(String type, Map<String, dynamic>? results) {
    if (results == null) {
      return const Center(child: CircularProgressIndicator());
    }

    switch (type) {
      case 'multiple_choice':
        final options = results['options'] as List? ?? [];
        return ListView.builder(
          itemCount: options.length,
          itemBuilder: (context, index) {
            final opt = options[index];
            final percent = opt['percentage'] as int? ?? 0;
            final isCorrect = opt['isCorrect'] as bool? ?? false;

            return Container(
              margin: const EdgeInsets.only(bottom: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          opt['optionText'] as String,
                          style: const TextStyle(
                            color: AppColors.textPrimaryDark,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Text(
                        '$percent%',
                        style: TextStyle(
                          color: isCorrect ? AppColors.success : AppColors.textPrimaryDark,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      return Stack(
                        children: [
                          Container(
                            height: 18,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(AppSizes.radiusBadge),
                            ),
                          ),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 600),
                            curve: Curves.easeOutCubic,
                            height: 18,
                            width: constraints.maxWidth * (percent / 100),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: isCorrect
                                    ? [AppColors.success, Colors.tealAccent]
                                    : [AppColors.primary, AppColors.purpleAccent],
                              ),
                              borderRadius: BorderRadius.circular(AppSizes.radiusBadge),
                              boxShadow: [
                                BoxShadow(
                                  color: (isCorrect ? AppColors.success : AppColors.primary).withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            );
          },
        );

      case 'rating':
        final average = results['average'] as double? ?? 0.0;
        final totalVotes = results['totalVotes'] as int? ?? 0;
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.surfaceDark.withOpacity(0.3),
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.secondary.withOpacity(0.3), width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.secondary.withOpacity(0.1),
                      blurRadius: 40,
                      spreadRadius: 10,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      average.toStringAsFixed(1),
                      style: const TextStyle(
                        color: AppColors.textPrimaryDark,
                        fontSize: 84,
                        fontWeight: FontWeight.w900,
                        shadows: [
                          Shadow(
                            color: AppColors.secondary,
                            blurRadius: 20,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (idx) {
                  final filled = idx < average.round();
                  return Icon(
                    filled ? Icons.star_rounded : Icons.star_border_rounded,
                    color: Colors.amber,
                    size: 48,
                  );
                }),
              ),
              const SizedBox(height: 20),
              Text(
                'Based on $totalVotes total rating ratings',
                style: const TextStyle(color: AppColors.textSecondaryDark, fontSize: 16, fontWeight: FontWeight.w500),
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
              style: TextStyle(color: AppColors.textSecondaryDark, fontSize: 16),
            ),
          );
        }
        return Center(
          child: SingleChildScrollView(
            child: Wrap(
              spacing: 16,
              runSpacing: 16,
              alignment: WrapAlignment.center,
              children: List.generate(words.length, (idx) {
                final w = words[idx];
                final text = w['text'] as String? ?? '';
                final val = w['value'] as int? ?? 0;
                final baseColor = _getWordColor(val);
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: baseColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppSizes.radiusCard),
                    border: Border.all(color: baseColor.withOpacity(0.3), width: 1),
                  ),
                  child: Text(
                    text,
                    style: TextStyle(
                      color: baseColor,
                      fontSize: 18.0 + (val * 4.5).clamp(0, 32),
                      fontWeight: FontWeight.bold,
                      shadows: [
                        Shadow(
                          color: baseColor.withOpacity(0.4),
                          blurRadius: 6,
                        ),
                      ],
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
              style: TextStyle(color: AppColors.textSecondaryDark, fontSize: 16),
            ),
          );
        }
        return GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 20,
            mainAxisSpacing: 20,
            childAspectRatio: 2.4,
          ),
          itemCount: responses.length,
          itemBuilder: (context, index) {
            final r = responses[index];
            final author = r['author'] as String? ?? 'Anonymous';
            final text = r['text'] as String? ?? '';
            return Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.cardDark.withOpacity(0.4),
                borderRadius: BorderRadius.circular(AppSizes.radiusCard),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      '"$text"',
                      style: const TextStyle(
                        color: AppColors.textPrimaryDark,
                        fontSize: 15,
                        fontStyle: FontStyle.italic,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.secondary.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(AppSizes.radiusBadge),
                          ),
                          child: Text(
                            author,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.secondary,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
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

      default:
        return const Center(child: Text('Aggregating results...'));
    }
  }

  Color _getWordColor(int val) {
    if (val > 8) return AppColors.accent;
    if (val > 4) return AppColors.primary;
    return AppColors.secondary;
  }

  Widget _buildQuizLeaderboardView() {
    final top3 = _leaderboard.take(3).toList();
    final remaining = _leaderboard.skip(3).toList();

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceDark.withOpacity(0.45),
        borderRadius: BorderRadius.circular(AppSizes.radiusCard),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.emoji_events_rounded, color: Colors.amber, size: 36),
                  const SizedBox(width: 12),
                  const Text(
                    'QUIZ LEADERBOARD',
                    style: TextStyle(
                      color: AppColors.textPrimaryDark,
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 40),

              // Podium Layout for Top 3
              if (top3.isNotEmpty)
                SizedBox(
                  height: 220,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // 2nd Place (Left)
                      if (top3.length > 1)
                        _buildPodiumColumn(
                          name: top3[1]['name'] as String? ?? 'Anonymous',
                          score: top3[1]['score'] as int? ?? 0,
                          rank: 2,
                          height: 110,
                          gradient: const [Color(0xFFCFD8DC), Color(0xFF78909C)],
                        ),
                      const SizedBox(width: 20),

                      // 1st Place (Center)
                      _buildPodiumColumn(
                        name: top3[0]['name'] as String? ?? 'Anonymous',
                        score: top3[0]['score'] as int? ?? 0,
                        rank: 1,
                        height: 150,
                        gradient: const [Color(0xFFFFD54F), Color(0xFFFFB300)],
                      ),
                      const SizedBox(width: 20),

                      // 3rd Place (Right)
                      if (top3.length > 2)
                        _buildPodiumColumn(
                          name: top3[2]['name'] as String? ?? 'Anonymous',
                          score: top3[2]['score'] as int? ?? 0,
                          rank: 3,
                          height: 80,
                          gradient: const [Color(0xFFFFAB91), Color(0xFFD84315)],
                        ),
                    ],
                  ),
                ),
              const SizedBox(height: 32),
              const Divider(color: Colors.white24),
              const SizedBox(height: 16),

              // Remaining Players List
              Expanded(
                child: remaining.isEmpty
                    ? const Center(
                        child: Text(
                          'No other participants on the board yet',
                          style: TextStyle(color: AppColors.textSecondaryDark, fontSize: 14),
                        ),
                      )
                    : ListView.builder(
                        itemCount: remaining.length,
                        itemBuilder: (context, index) {
                          final item = remaining[index];
                          final name = item['name'] as String? ?? 'Anonymous';
                          final score = item['score'] as int? ?? 0;
                          final rank = item['rank'] as int? ?? (index + 4);

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                            decoration: BoxDecoration(
                              color: AppColors.cardDark.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(AppSizes.radiusCard),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 28,
                                  height: 28,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.05),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Text(
                                    '$rank',
                                    style: const TextStyle(
                                      color: AppColors.textPrimaryDark,
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Text(
                                    name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: AppColors.textPrimaryDark,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  '$score pts',
                                  style: const TextStyle(
                                    color: AppColors.primary,
                                    fontSize: 16,
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
    final medalIcon = rank == 1
        ? '👑'
        : rank == 2
            ? '🥈'
            : '🥉';

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(
          medalIcon,
          style: const TextStyle(fontSize: 28),
        ),
        const SizedBox(height: 6),
        SizedBox(
          width: 90,
          child: Text(
            name,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textPrimaryDark,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(height: 4),
        SizedBox(
          width: 90,
          child: Text(
            '$score pts',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: gradient[0],
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Container(
          width: 90,
          height: height,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: gradient,
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(AppSizes.radiusCard),
              topRight: Radius.circular(AppSizes.radiusCard),
            ),
            boxShadow: [
              BoxShadow(
                color: gradient[0].withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            '#$rank',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQaPresentationPanel() {
    final pinned = _questions.where((q) => q['isPinned'] == true).toList();
    final list = pinned.isNotEmpty ? pinned : _questions.take(5).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.forum_rounded, color: AppColors.primary, size: 24),
                const SizedBox(width: 8),
                const Text(
                  'Live Q&A',
                  style: TextStyle(
                    color: AppColors.textPrimaryDark,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.05),
                borderRadius: BorderRadius.circular(AppSizes.radiusBadge),
                border: Border.all(color: const Color(0xFFE2E8F0)),
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
        const SizedBox(height: 20),
        Expanded(
          child: list.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.chat_bubble_outline_rounded,
                        size: 48,
                        color: AppColors.textSecondaryDark.withOpacity(0.4),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No questions yet.\nAsk on qlix.app using code ${widget.accessCode}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppColors.textSecondaryDark,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: list.length,
                  itemBuilder: (context, index) {
                    final q = list[index];
                    final author = q['authorName'] as String? ?? 'Anonymous';
                    final text = q['text'] as String? ?? '';
                    final upvotes = q['upvotesCount'] as int? ?? 0;
                    final isPinned = q['isPinned'] as bool? ?? false;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isPinned
                              ? [AppColors.primary.withOpacity(0.18), AppColors.purpleAccent.withOpacity(0.12)]
                              : [AppColors.cardDark.withOpacity(0.35), AppColors.cardDark.withOpacity(0.25)],
                        ),
                        borderRadius: BorderRadius.circular(AppSizes.radiusCard),
                        border: Border.all(
                          color: isPinned
                              ? AppColors.primary.withOpacity(0.4)
                              : const Color(0xFFE2E8F0),
                          width: isPinned ? 1.5 : 1.0,
                        ),
                        boxShadow: isPinned
                            ? [
                                BoxShadow(
                                  color: AppColors.primary.withOpacity(0.15),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                )
                              ]
                            : [],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (isPinned)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: Row(
                                  children: [
                                    const Icon(Icons.push_pin_rounded, color: AppColors.accent, size: 14),
                                    const SizedBox(width: 6),
                                    const Text(
                                      'PINNED QUESTION',
                                      style: TextStyle(
                                        color: AppColors.accent,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 1.0,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            Text(
                              text,
                              style: const TextStyle(
                                color: AppColors.textPrimaryDark,
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                                height: 1.3,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Flexible(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.05),
                                      borderRadius: BorderRadius.circular(AppSizes.radiusBadge),
                                    ),
                                    child: Text(
                                      '— $author',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: AppColors.textSecondaryDark,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Row(
                                  children: [
                                    const Icon(Icons.thumb_up_rounded, color: AppColors.secondary, size: 14),
                                    const SizedBox(width: 6),
                                    Text(
                                      '$upvotes',
                                      style: const TextStyle(
                                        color: AppColors.secondary,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 13,
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


