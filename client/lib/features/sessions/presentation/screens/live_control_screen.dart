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
      await sl<PollRepository>().updatePoll(pollId, {
        'status': 'ended',
      });
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to end poll: $e')),
      );
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

  void _startQuizQuestion(String pollId, int timerLimit) {
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
          });
          messenger.showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.timer_rounded, color: Colors.white, size: 16),
                  SizedBox(width: 8),
                  Text('Quiz question activated, timer started!'),
                ],
              ),
              backgroundColor: AppColors.success,
              behavior: SnackBarBehavior.floating,
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
      const SnackBar(
        content: Row(
          children: [
            Icon(Icons.campaign_rounded, color: Colors.white, size: 16),
            SizedBox(width: 8),
            Text('Announcement broadcasted to all participants!'),
          ],
        ),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _addNewPollDialog() {
    final titleCtrl = TextEditingController();
    String type = 'multiple_choice';
    final optCtrls = [TextEditingController(), TextEditingController()];

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSizes.radiusCard),
              ),
              title: const Row(
                children: [
                  Icon(Icons.poll_rounded, color: AppColors.primary, size: 22),
                  SizedBox(width: 10),
                  Text(
                    'Create Live Poll',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: titleCtrl,
                      decoration: InputDecoration(
                        labelText: 'Poll Question Title',
                        hintText: 'e.g. What topic should we cover next?',
                        prefixIcon: const Icon(Icons.help_outline_rounded),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            AppSizes.radiusInput,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: type,
                      items: const [
                        DropdownMenuItem(
                          value: 'multiple_choice',
                          child: Row(
                            children: [
                              Icon(Icons.list_rounded, size: 18),
                              SizedBox(width: 8),
                              Text('Multiple Choice'),
                            ],
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'word_cloud',
                          child: Row(
                            children: [
                              Icon(Icons.cloud_rounded, size: 18),
                              SizedBox(width: 8),
                              Text('Word Cloud'),
                            ],
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'rating',
                          child: Row(
                            children: [
                              Icon(Icons.star_rounded, size: 18),
                              SizedBox(width: 8),
                              Text('Rating Poll (1-5 Stars)'),
                            ],
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'open_text',
                          child: Row(
                            children: [
                              Icon(Icons.notes_rounded, size: 18),
                              SizedBox(width: 8),
                              Text('Open Text Response'),
                            ],
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'ranking',
                          child: Row(
                            children: [
                              Icon(Icons.sort_rounded, size: 18),
                              SizedBox(width: 8),
                              Text('Ranking List'),
                            ],
                          ),
                        ),
                      ],
                      onChanged: (v) {
                        setDialogState(() {
                          type = v ?? 'multiple_choice';
                        });
                      },
                      decoration: InputDecoration(
                        labelText: 'Poll Format Type',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            AppSizes.radiusInput,
                          ),
                        ),
                      ),
                    ),
                    if (type == 'multiple_choice' || type == 'ranking') ...[
                      const SizedBox(height: 20),
                      const Text(
                        'Options',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...List.generate(optCtrls.length, (index) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: optCtrls[index],
                                  decoration: InputDecoration(
                                    labelText: 'Option ${index + 1}',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(
                                        AppSizes.radiusInput,
                                      ),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 12,
                                    ),
                                  ),
                                ),
                              ),
                              if (optCtrls.length > 2)
                                IconButton(
                                  icon: const Icon(
                                    Icons.remove_circle_outline_rounded,
                                    color: AppColors.error,
                                  ),
                                  onPressed: () {
                                    setDialogState(() {
                                      optCtrls.removeAt(index);
                                    });
                                  },
                                ),
                            ],
                          ),
                        );
                      }),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              AppSizes.radiusButton,
                            ),
                          ),
                        ),
                        onPressed: () {
                          setDialogState(() {
                            optCtrls.add(TextEditingController());
                          });
                        },
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: const Text('Add Option'),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        AppSizes.radiusButton,
                      ),
                    ),
                  ),
                  onPressed: () async {
                    final title = titleCtrl.text.trim();
                    if (title.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please enter a question title'),
                          backgroundColor: AppColors.error,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                      return;
                    }
                    if (_session == null) return;

                    List<Map<String, dynamic>>? optsList;
                    if (type == 'multiple_choice' || type == 'ranking') {
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
                              Text('Live poll created successfully!'),
                            ],
                          ),
                          backgroundColor: AppColors.success,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    } catch (e) {
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text('Failed to create poll: $e'),
                          backgroundColor: AppColors.error,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  },
                  child: const Text('Create Poll'),
                ),
              ],
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

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSizes.radiusCard),
              ),
              title: const Row(
                children: [
                  Icon(
                    Icons.emoji_events_rounded,
                    color: AppColors.purpleAccent,
                    size: 22,
                  ),
                  SizedBox(width: 10),
                  Text(
                    'Add Quiz Question',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: titleCtrl,
                      decoration: InputDecoration(
                        labelText: 'Quiz Question Text',
                        hintText:
                            'e.g. Which keyword defines an immutable variable in Dart?',
                        prefixIcon: const Icon(Icons.help_outline_rounded),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            AppSizes.radiusInput,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Select the correct answer option:',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ...List.generate(optCtrls.length, (idx) {
                      final isSelected = correctIndex == idx;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          children: [
                            InkWell(
                              onTap: () {
                                setDialogState(() {
                                  correctIndex = idx;
                                });
                              },
                              borderRadius: BorderRadius.circular(20),
                              child: Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isSelected
                                      ? AppColors.success
                                      : Colors.transparent,
                                  border: Border.all(
                                    color: isSelected
                                        ? AppColors.success
                                        : Colors.grey,
                                    width: 2,
                                  ),
                                ),
                                child: isSelected
                                    ? const Icon(
                                        Icons.check,
                                        size: 14,
                                        color: Colors.white,
                                      )
                                    : null,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextField(
                                controller: optCtrls[idx],
                                decoration: InputDecoration(
                                  labelText: 'Option ${idx + 1}',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(
                                      AppSizes.radiusInput,
                                    ),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 12,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.purpleAccent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        AppSizes.radiusButton,
                      ),
                    ),
                  ),
                  onPressed: () async {
                    final title = titleCtrl.text.trim();
                    if (title.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please enter a question text'),
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
                        .where((e) => e.value.text.trim().isNotEmpty)
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

                    final isCorrectOptionFilled = optCtrls[correctIndex].text
                        .trim()
                        .isNotEmpty;
                    if (!isCorrectOptionFilled) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('The correct option cannot be empty'),
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
                              Text('Quiz question created successfully!'),
                            ],
                          ),
                          backgroundColor: AppColors.success,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    } catch (e) {
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text('Failed to create quiz: $e'),
                          backgroundColor: AppColors.error,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  },
                  child: const Text('Create Question'),
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
      // FAB placed at Bottom Right corner as explicitly requested
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: _buildDynamicFab(),
    );
  }

  // Dynamic FAB at bottom-right corner adapting to active tab context
  Widget _buildDynamicFab() {
    final tabIdx = _tabController.index;

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
      case 3:
        fabIcon = Icons.send_rounded;
        fabLabel = 'Broadcast';
        fabAction = _broadcastAnnouncement;
        fabColor = AppColors.primary;
        break;
      default:
        fabIcon = Icons.add_rounded;
        fabLabel = 'New';
        fabAction = _addNewPollDialog;
        fabColor = AppColors.primary;
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
                    final pollId = quiz['id'] as String;
                    final isCurrent = _activeQuizQuestionId == pollId;

                    return Card(
                      color: isCurrent
                          ? AppColors.purpleAccent.withValues(alpha: 0.04)
                          : null,
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        side: BorderSide(
                          color: isCurrent
                              ? AppColors.purpleAccent.withValues(alpha: 0.4)
                              : (isDark ? Colors.white10 : Colors.black12),
                          width: isCurrent ? 1.5 : 1.0,
                        ),
                        borderRadius: BorderRadius.circular(
                          AppSizes.radiusCard,
                        ),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        title: Text(
                          quiz['title'] as String,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: isCurrent
                                      ? AppColors.purpleAccent.withValues(
                                          alpha: 0.12,
                                        )
                                      : Colors.grey.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(
                                    AppSizes.radiusBadge,
                                  ),
                                ),
                                child: Text(
                                  isCurrent
                                      ? 'ACTIVE TIMER TICKING'
                                      : 'READY TO LAUNCH',
                                  style: TextStyle(
                                    color: isCurrent
                                        ? AppColors.purpleAccent
                                        : Colors.grey,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        trailing: ElevatedButton.icon(
                          onPressed: isCurrent
                              ? null
                              : () => _startQuizQuestion(pollId, 15),
                          icon: const Icon(Icons.timer_outlined, size: 14),
                          label: const Text('Start (15s)'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isCurrent
                                ? Colors.transparent
                                : AppColors.purpleAccent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                AppSizes.radiusButton,
                              ),
                            ),
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
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 80),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.campaign_rounded,
                  color: AppColors.primary,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Broadcast Alerts',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Push real-time popup messages to all participants instantly.',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Text(
            'Quick Presets:',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ActionChip(
                avatar: const Icon(Icons.play_circle_outline, size: 16),
                label: const Text('Starting Soon'),
                onPressed: () {
                  _announcementTitleCtrl.text = 'Session Starting Soon';
                  _announcementMsgCtrl.text =
                      'Please take your seats! We are starting the presentation shortly.';
                },
              ),
              ActionChip(
                avatar: const Icon(Icons.poll, size: 16),
                label: const Text('Poll Opened'),
                onPressed: () {
                  _announcementTitleCtrl.text = 'Live Poll Now Open';
                  _announcementMsgCtrl.text =
                      'A new live poll is active! Open your app to cast your vote.';
                },
              ),
              ActionChip(
                avatar: const Icon(Icons.question_answer, size: 16),
                label: const Text('Q&A Time'),
                onPressed: () {
                  _announcementTitleCtrl.text = 'Q&A Session Open';
                  _announcementMsgCtrl.text =
                      'Submit your questions and upvote your favorites in the Q&A tab.';
                },
              ),
              ActionChip(
                avatar: const Icon(Icons.timer, size: 16),
                label: const Text('5 Min Break'),
                onPressed: () {
                  _announcementTitleCtrl.text = 'Short 5-Minute Break';
                  _announcementMsgCtrl.text =
                      'We are taking a short 5-minute break. Stay tuned!';
                },
              ),
            ],
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _announcementTitleCtrl,
            decoration: InputDecoration(
              labelText: 'Alert Title',
              hintText: 'e.g. Session starting in 2 minutes',
              prefixIcon: const Icon(Icons.title_rounded),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppSizes.radiusInput),
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _announcementMsgCtrl,
            maxLines: 4,
            decoration: InputDecoration(
              labelText: 'Alert Message Body',
              hintText: 'Type your message to broadcast...',
              alignLabelWithHint: true,
              prefixIcon: const Padding(
                padding: EdgeInsets.only(bottom: 60),
                child: Icon(Icons.message_rounded),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppSizes.radiusInput),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppSizes.radiusButton),
              gradient: const LinearGradient(colors: AppColors.primaryGradient),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.3),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: _broadcastAnnouncement,
              icon: const Icon(Icons.send_rounded, size: 18),
              label: const Text(
                'Broadcast Alert Now',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
