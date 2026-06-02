import 'dart:async';
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
import '../../../quiz/domain/repositories/quiz_repository.dart';
import '../../domain/repositories/session_repository.dart';

class HostLiveControlScreen extends StatefulWidget {
  final String sessionId;
  const HostLiveControlScreen({super.key, required this.sessionId});

  @override
  State<HostLiveControlScreen> createState() => _HostLiveControlScreenState();
}

class _HostLiveControlScreenState extends State<HostLiveControlScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _socketClient = sl<SocketClient>();

  Map<String, dynamic>? _session;
  List<Map<String, dynamic>> _polls = [];
  List<Map<String, dynamic>> _questions = [];
  String? _activePollId;
  String? _activeQuizQuestionId;

  // Announcement inputs
  final _announcementTitleCtrl = TextEditingController();
  final _announcementMsgCtrl = TextEditingController();

  // Socket subscription streams
  StreamSubscription? _votesSubscription;
  StreamSubscription? _questionsSubscription;
  StreamSubscription? _questionsStatusSubscription;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
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
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    try {
      final session = await sl<SessionRepository>().getSessionDetails(widget.sessionId);
      final polls = await sl<PollRepository>().getSessionPolls(widget.sessionId);
      final questions = await sl<QaRepository>().getSessionQuestions(widget.sessionId);

      setState(() {
        _session = session;
        _polls = polls;
        _questions = questions;
        _activePollId = session['active_poll_id'] as String?;
        _activeQuizQuestionId = session['active_quiz_question_id'] as String?;
      });

      // Join Socket Room
      _socketClient.connect();
      _socketClient.joinSession(session['access_code'] as String, 'host', 'host');

      // Bind Socket Events
      _votesSubscription = _socketClient.votesUpdatedStream.listen((data) {
        final pollId = data['pollId'] as String;
        final results = Map<String, dynamic>.from(data['results'] as Map);
        
        setState(() {
          for (var p in _polls) {
            if (p['id'] == pollId) {
              p['results'] = results;
            }
          }
        });
      });

      _questionsSubscription = _socketClient.questionCreatedStream.listen((data) {
        final newQ = Map<String, dynamic>.from(data['question'] as Map);
        setState(() {
          // Avoid duplicate inserts
          if (!_questions.any((q) => q['id'] == newQ['id'])) {
            _questions.insert(0, newQ);
          }
        });
      });

      _questionsStatusSubscription = _socketClient.questionStatusStream.listen((data) {
        final updatedQ = Map<String, dynamic>.from(data['question'] as Map);
        setState(() {
          final index = _questions.indexWhere((q) => q['id'] == updatedQ['id']);
          if (index != -1) {
            _questions[index] = updatedQ;
          } else {
            _questions.insert(0, updatedQ);
          }
        });
      });

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading control panel: $e'), backgroundColor: Colors.redAccent),
      );
    }
  }

  void _activatePoll(String? pollId) {
    if (_session == null) return;
    _socketClient.activatePoll(_session!['id'] as String, pollId);
    setState(() {
      _activePollId = pollId;
      for (var p in _polls) {
        if (p['id'] == pollId) {
          p['status'] = 'active';
        } else if (p['status'] == 'active') {
          p['status'] = 'ended';
        }
      }
    });
  }

  void _deactivateActivePoll() {
    _activatePoll(null);
  }

  void _lockActivePoll() async {
    if (_activePollId == null) return;
    try {
      await sl<PollRepository>().updatePoll(_activePollId!, {'status': 'locked'});
      setState(() {
        for (var p in _polls) {
          if (p['id'] == _activePollId) {
            p['status'] = 'locked';
          }
        }
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to lock poll: $e'), backgroundColor: Colors.redAccent),
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

  void _startQuizQuestion(String pollId, int timerLimit) {
    if (_session == null) return;
    final messenger = ScaffoldMessenger.of(context);
    // Set question active in DB first
    sl<QuizRepository>().activateQuizQuestion(_session!['id'] as String, pollId, timerLimit).then((_) {
      // Start real-time countdown via sockets
      _socketClient.startQuizTimer(_session!['id'] as String, pollId, timerLimit);
      setState(() {
        _activeQuizQuestionId = pollId;
      });
      messenger.showSnackBar(
        const SnackBar(content: Text('Quiz question activated, timer started!'), backgroundColor: Colors.green),
      );
    }).catchError((e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Failed to start quiz: $e'), backgroundColor: Colors.redAccent),
      );
    });
  }

  void _broadcastAnnouncement() {
    if (_session == null) return;
    final title = _announcementTitleCtrl.text.trim();
    final message = _announcementMsgCtrl.text.trim();

    if (title.isEmpty || message.isEmpty) return;

    _socketClient.sendAnnouncement(_session!['id'] as String, title, message);
    
    _announcementTitleCtrl.clear();
    _announcementMsgCtrl.clear();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Announcement broadcasted!'), backgroundColor: Colors.green),
    );
  }

  void _addNewPollDialog() {
    final titleCtrl = TextEditingController();
    String type = 'multiple_choice';
    final optCtrls = [TextEditingController(), TextEditingController()];

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Add Live Poll'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleCtrl,
                      decoration: const InputDecoration(labelText: 'Question Title'),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: type,
                      items: const [
                        DropdownMenuItem(value: 'multiple_choice', child: Text('Multiple Choice')),
                        DropdownMenuItem(value: 'word_cloud', child: Text('Word Cloud')),
                        DropdownMenuItem(value: 'rating', child: Text('Rating Poll')),
                        DropdownMenuItem(value: 'open_text', child: Text('Open Text')),
                        DropdownMenuItem(value: 'ranking', child: Text('Ranking List')),
                      ],
                      onChanged: (v) {
                        setDialogState(() {
                          type = v ?? 'multiple_choice';
                        });
                      },
                      decoration: const InputDecoration(labelText: 'Poll Type'),
                    ),
                    if (type == 'multiple_choice' || type == 'ranking') ...[
                      const SizedBox(height: 16),
                      const Text('Options', style: TextStyle(fontWeight: FontWeight.bold)),
                      ...List.generate(optCtrls.length, (index) {
                        return Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: optCtrls[index],
                                decoration: InputDecoration(labelText: 'Option ${index + 1}'),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                              onPressed: () {
                                if (optCtrls.length > 2) {
                                  setDialogState(() {
                                    optCtrls.removeAt(index);
                                  });
                                }
                              },
                            ),
                          ],
                        );
                      }),
                      TextButton.icon(
                        onPressed: () {
                          setDialogState(() {
                            optCtrls.add(TextEditingController());
                          });
                        },
                        icon: const Icon(Icons.add),
                        label: const Text('Add Option'),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                TextButton(
                  onPressed: () async {
                    final title = titleCtrl.text.trim();
                    if (title.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please enter a question title'), backgroundColor: Colors.redAccent),
                      );
                      return;
                    }
                    if (_session == null) return;

                    List<Map<String, dynamic>>? optsList;
                    if (type == 'multiple_choice' || type == 'ranking') {
                      optsList = optCtrls.where((c) => c.text.trim().isNotEmpty).map((c) => {'optionText': c.text.trim()}).toList();
                      if (optsList.length < 2) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please provide at least 2 non-empty options'), backgroundColor: Colors.redAccent),
                        );
                        return;
                      }
                    }

                    final messenger = ScaffoldMessenger.of(context);
                    final navigator = Navigator.of(context);

                    try {
                      await sl<PollRepository>().createPoll(
                        sessionId: _session!['id'] as String,
                        title: title,
                        type: type,
                        options: optsList,
                      );
                      navigator.pop();
                      _loadInitialData(); // Refresh list
                    } catch (e) {
                      messenger.showSnackBar(
                        SnackBar(content: Text('Failed to create poll: $e'), backgroundColor: Colors.redAccent),
                      );
                    }
                  },
                  child: const Text('Create'),
                ),
              ],
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
          title: const Text('Session QR Code', textAlign: TextAlign.center),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppSizes.radiusCard),
                ),
                child: QrImageView(
                  data: 'http://localhost:3000/session/$code',
                  version: QrVersions.auto,
                  size: 200,
                  gapless: false,
                  foregroundColor: Colors.black,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Code: $code',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
              ),
              const SizedBox(height: 8),
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

  @override
  Widget build(BuildContext context) {
    if (_session == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: AppColors.primary)));
    }

    final code = _session!['access_code'] as String;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_session!['title'] as String, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: -0.3)),
            Row(
              children: [
                const Icon(Icons.key_rounded, size: 12, color: AppColors.primary),
                const SizedBox(width: 4),
                Text('Room Code: $code', style: const TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_2_rounded, color: AppColors.primary),
            tooltip: 'Show QR Code',
            onPressed: () => _showQrDialog(context, code),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          indicatorSize: TabBarIndicatorSize.label,
          labelColor: AppColors.primary,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          unselectedLabelColor: isDark ? Colors.white60 : Colors.black54,
          tabs: const [
            Tab(icon: Icon(Icons.poll_rounded), text: 'Polls'),
            Tab(icon: Icon(Icons.question_answer_rounded), text: 'Q&A'),
            Tab(icon: Icon(Icons.emoji_events_rounded), text: 'Quizzes'),
            Tab(icon: Icon(Icons.campaign_rounded), text: 'Alerts'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // 1. Polls Tab View
          _buildPollsTab(),

          // 2. Q&A Tab View
          _buildQaTab(),

          // 3. Quiz Tab View
          _buildQuizTab(),

          // 4. Announcements Tab View
          _buildAnnouncementsTab(),
        ],
      ),
    );
  }

  Widget _buildPollsTab() {
    final activePolls = _polls.where((p) => p['settings']?['isQuiz'] != true).toList();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${activePolls.length} Active Polls', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: -0.2)),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppSizes.radiusPill),
                  gradient: const LinearGradient(colors: AppColors.primaryGradient),
                ),
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                  onPressed: _addNewPollDialog,
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Add Poll', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                ),
              ),
            ],
          ),
        ),
        if (_activePollId != null) ...[
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(AppSizes.radiusCard),
              border: Border.all(color: AppColors.primary.withOpacity(0.25), width: 1.5),
            ),
            child: Row(
              children: [
                const _LiveIndicator(),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('LIVE ACTIVE POLL', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 10, color: AppColors.primary, letterSpacing: 0.5)),
                      const SizedBox(height: 2),
                      Text(
                        _polls.firstWhere((p) => p['id'] == _activePollId, orElse: () => {'title': 'Unknown'})['title'] as String,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: _lockActivePoll,
                  child: const Text('Lock'),
                ),
                const SizedBox(width: 4),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8)),
                  onPressed: _deactivateActivePoll,
                  child: const Text('Stop', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
        Expanded(
          child: activePolls.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.ballot_outlined, size: 48, color: isDark ? Colors.white24 : Colors.black12),
                      const SizedBox(height: 12),
                      const Text('No polls created for this session', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                      color: isCurrent ? AppColors.primary.withOpacity(0.04) : null,
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        side: BorderSide(
                          color: isCurrent ? AppColors.primary.withOpacity(0.3) : (isDark ? Colors.white10 : Colors.black12),
                          width: isCurrent ? 1.5 : 1.0,
                        ),
                        borderRadius: BorderRadius.circular(AppSizes.radiusCard),
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
                                    Icon(typeIcon, size: 14, color: isDark ? Colors.white60 : Colors.black54),
                                    const SizedBox(width: 6),
                                    Text(
                                      (poll['type'] as String).replaceAll('_', ' ').toUpperCase(),
                                      style: TextStyle(color: isDark ? Colors.white60 : Colors.black54, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                                    ),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: badgeColor.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(AppSizes.radiusBadge),
                                  ),
                                  child: Text(
                                    status.toUpperCase(),
                                    style: TextStyle(color: badgeColor, fontSize: 9, fontWeight: FontWeight.w900),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(poll['title'] as String, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            
                            // Visual mini progress bars for results summary
                            _buildMiniResults(poll),

                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                if (!isCurrent && status != 'ended') ...[
                                  ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primary, 
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSizes.radiusButton)),
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                    ),
                                    onPressed: () => _activatePoll(pollId),
                                    icon: const Icon(Icons.play_arrow_rounded, size: 16),
                                    label: const Text('Activate', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
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
                    child: Text(text, style: const TextStyle(fontSize: 12, overflow: TextOverflow.ellipsis), maxLines: 1),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 5,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(AppSizes.radiusSmall),
                      child: LinearProgressIndicator(
                        value: percent / 100,
                        minHeight: 6,
                        backgroundColor: Colors.grey.withOpacity(0.1),
                        valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary.withOpacity(0.7)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('$percent%', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
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
              '${average.toStringAsFixed(1)} / 5.0 Rating (${total} votes)',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey),
            ),
          ],
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildQaTab() {
    // Unanswered questions (pending & approved)
    final unanswered = _questions.where((q) => q['status'] == 'pending' || q['status'] == 'approved').toList();
    // Answered questions
    final answered = _questions.where((q) => q['status'] == 'answered').toList();

    // Sort answered by updatedAt or createdAt descending
    answered.sort((a, b) {
      final aTimeStr = a['updatedAt'] ?? a['createdAt'] ?? '';
      final bTimeStr = b['updatedAt'] ?? b['createdAt'] ?? '';
      final aTime = DateTime.tryParse(aTimeStr.toString()) ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bTime = DateTime.tryParse(bTimeStr.toString()) ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bTime.compareTo(aTime);
    });

    final List<dynamic> items = [];
    if (unanswered.isEmpty) {
      items.add('empty_unanswered');
    } else {
      items.addAll(unanswered);
    }

    if (answered.isNotEmpty) {
      items.add('header_answered');
      items.addAll(answered);
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];

        if (item == 'empty_unanswered') {
          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Column(
                children: [
                  Icon(Icons.question_answer_outlined, size: 48, color: isDark ? Colors.white30 : Colors.black26),
                  const SizedBox(height: 12),
                  Text(
                    'No unanswered questions yet',
                    style: TextStyle(color: isDark ? Colors.white60 : Colors.black54),
                  ),
                ],
              ),
            ),
          );
        }

        if (item == 'header_answered') {
          return Padding(
            padding: const EdgeInsets.only(top: 24, bottom: 12),
            child: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.green, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Answered Questions (${answered.length})',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),
          );
        }

        final q = item as Map<String, dynamic>;
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
              color: isPinned ? Colors.orange.withOpacity(0.5) : (isDark ? Colors.white10 : Colors.black12),
              width: isPinned ? 1.5 : 1.0,
            ),
            borderRadius: BorderRadius.circular(AppSizes.radiusCard),
          ),
          color: isAnswered
              ? (isDark ? Colors.black12 : Colors.grey[100])
              : (isPinned ? AppColors.primary.withOpacity(0.04) : null),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            title: Text(
              text,
              style: TextStyle(
                decoration: isAnswered ? TextDecoration.lineThrough : null,
                fontWeight: isPinned ? FontWeight.bold : FontWeight.normal,
                color: isAnswered 
                    ? (isDark ? Colors.white38 : Colors.black38) 
                    : (isDark ? Colors.white : Colors.black87),
              ),
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
                    'By $author • $upvotes upvotes',
                    style: TextStyle(
                      fontSize: 11,
                      color: isAnswered 
                          ? (isDark ? Colors.white30 : Colors.black38) 
                          : (isDark ? Colors.white60 : Colors.black54),
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
                    icon: const Icon(Icons.check_circle_outline, color: Colors.green),
                    tooltip: 'Approve Question',
                    onPressed: () => _updateQuestionStatus(qId, 'approved'),
                  ),
                  IconButton(
                    icon: const Icon(Icons.cancel_outlined, color: Colors.redAccent),
                    tooltip: 'Dismiss Question',
                    onPressed: () => _updateQuestionStatus(qId, 'dismissed'),
                  ),
                ] else if (isAnswered) ...[
                  IconButton(
                    icon: const Icon(Icons.history_rounded, color: Colors.grey),
                    tooltip: 'Reopen Question',
                    onPressed: () => _updateQuestionStatus(qId, 'approved'),
                  ),
                ] else ...[
                  IconButton(
                    icon: Icon(
                      isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                      color: isPinned ? Colors.orange : Colors.grey,
                    ),
                    tooltip: isPinned ? 'Unpin from Presenter Screen' : 'Pin to Presenter Screen',
                    onPressed: () => _toggleQuestionPin(qId, isPinned),
                  ),
                  IconButton(
                    icon: const Icon(Icons.check_circle_rounded, color: Colors.green),
                    tooltip: 'Mark as Answered',
                    onPressed: () => _updateQuestionStatus(qId, 'answered'),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildQuizTab() {
    final quizPolls = _polls.where((p) => p['settings']?['isQuiz'] == true).toList();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${quizPolls.length} Quiz Questions', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: -0.2)),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppSizes.radiusPill),
                  gradient: const LinearGradient(colors: AppColors.primaryGradient),
                ),
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                  onPressed: () {
                    // Quick add quiz question dialog
                    final titleCtrl = TextEditingController();
                    final optCtrls = [TextEditingController(), TextEditingController(), TextEditingController(), TextEditingController()];
                    int correctIndex = 0;

                    showDialog(
                      context: context,
                      builder: (context) {
                        return StatefulBuilder(builder: (context, setDialogState) {
                          return AlertDialog(
                            title: const Text('Add Quiz Question', style: TextStyle(fontWeight: FontWeight.bold)),
                            content: SingleChildScrollView(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  TextField(
                                    controller: titleCtrl, 
                                    decoration: const InputDecoration(labelText: 'Question text'),
                                  ),
                                  const SizedBox(height: 16),
                                  const Text('Select the correct answer option:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                                  const SizedBox(height: 8),
                                  ...List.generate(optCtrls.length, (idx) {
                                    return Row(
                                      children: [
                                        Radio<int>(
                                          value: idx,
                                          groupValue: correctIndex,
                                          activeColor: AppColors.primary,
                                          onChanged: (v) {
                                            setDialogState(() {
                                              correctIndex = v ?? 0;
                                            });
                                          },
                                        ),
                                        Expanded(
                                          child: TextField(controller: optCtrls[idx], decoration: InputDecoration(labelText: 'Option ${idx + 1}')),
                                        ),
                                      ],
                                    );
                                  }),
                                ],
                              ),
                            ),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                              TextButton(
                                onPressed: () async {
                                  final title = titleCtrl.text.trim();
                                  if (title.isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Please enter a question text'), backgroundColor: AppColors.error),
                                    );
                                    return;
                                  }
                                  if (_session == null) return;

                                  final filledOptions = optCtrls.asMap().entries
                                      .where((e) => e.value.text.trim().isNotEmpty)
                                      .toList();

                                  if (filledOptions.length < 2) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Please provide at least 2 non-empty options'), backgroundColor: AppColors.error),
                                    );
                                    return;
                                  }

                                  final isCorrectOptionFilled = optCtrls[correctIndex].text.trim().isNotEmpty;
                                  if (!isCorrectOptionFilled) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('The correct option cannot be empty'), backgroundColor: AppColors.error),
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
                                  final navigator = Navigator.of(context);

                                  try {
                                    await sl<PollRepository>().createPoll(
                                      sessionId: _session!['id'] as String,
                                      title: title,
                                      type: 'multiple_choice',
                                      settings: {'isQuiz': true},
                                      options: options,
                                    );
                                    navigator.pop();
                                    _loadInitialData(); // Refresh list
                                  } catch (e) {
                                    messenger.showSnackBar(
                                      SnackBar(content: Text('Failed to create quiz: $e'), backgroundColor: AppColors.error),
                                    );
                                  }
                                },
                                child: const Text('Create', style: TextStyle(fontWeight: FontWeight.bold)),
                              ),
                            ],
                          );
                        });
                      },
                    );
                  },
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Add Question', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: quizPolls.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.quiz_outlined, size: 48, color: isDark ? Colors.white24 : Colors.black12),
                      const SizedBox(height: 12),
                      const Text('No quiz questions created', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: quizPolls.length,
                  itemBuilder: (context, index) {
                    final quiz = quizPolls[index];
                    final pollId = quiz['id'] as String;
                    final isCurrent = _activeQuizQuestionId == pollId;

                    return Card(
                      color: isCurrent ? AppColors.accent.withOpacity(0.04) : null,
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        side: BorderSide(
                          color: isCurrent ? AppColors.accent.withOpacity(0.3) : (isDark ? Colors.white10 : Colors.black12),
                          width: isCurrent ? 1.5 : 1.0,
                        ),
                        borderRadius: BorderRadius.circular(AppSizes.radiusCard),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        title: Text(quiz['title'] as String, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: isCurrent ? AppColors.accent.withOpacity(0.12) : Colors.grey.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(AppSizes.radiusBadge),
                                ),
                                child: Text(
                                  isCurrent ? 'ACTIVE TIMER TICKING' : 'DRAFT QUESTION',
                                  style: TextStyle(color: isCurrent ? AppColors.accent : Colors.grey, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                                ),
                              ),
                            ],
                          ),
                        ),
                        trailing: ElevatedButton.icon(
                          onPressed: isCurrent ? null : () => _startQuizQuestion(pollId, 15),
                          icon: const Icon(Icons.timer_outlined, size: 14),
                          label: const Text('Start (15s)'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isCurrent ? Colors.transparent : AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSizes.radiusButton)),
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

  Widget _buildAnnouncementsTab() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.campaign_rounded, color: AppColors.primary, size: 28),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Broadcast Alerts', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: -0.3)),
                    SizedBox(height: 2),
                    Text('Push real-time popup alerts directly onto all participants\' screens.', style: TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          TextField(
            controller: _announcementTitleCtrl,
            decoration: const InputDecoration(
              labelText: 'Alert Title',
              hintText: 'e.g. Breakout Room starting soon',
              prefixIcon: Icon(Icons.title_rounded),
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _announcementMsgCtrl,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Alert Message Body',
              hintText: 'Type the description message to broadcast...',
              prefixIcon: Padding(
                padding: EdgeInsets.only(bottom: 56),
                child: Icon(Icons.message_rounded),
              ),
            ),
          ),
          const SizedBox(height: 32),
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
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              onPressed: _broadcastAnnouncement,
              icon: const Icon(Icons.send_rounded, size: 18),
              label: const Text('Broadcast Alert Now', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}

// Micro-animation pulsing live indicator
// Pulse dot lived state indicator
class _LiveIndicator extends StatefulWidget {
  const _LiveIndicator();

  @override
  State<_LiveIndicator> createState() => _LiveIndicatorState();
}

class _LiveIndicatorState extends State<_LiveIndicator> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 1))..repeat(reverse: true);
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
                color: AppColors.primary.withOpacity(0.5 * _ctrl.value + 0.1),
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
