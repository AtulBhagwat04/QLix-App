import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';

import '../../../sessions/domain/repositories/session_repository.dart';
import '../../../polls/domain/repositories/poll_repository.dart';
import '../../../qa/domain/repositories/qa_repository.dart';

class AnalyticsDashboardScreen extends StatefulWidget {
  final String sessionId;
  const AnalyticsDashboardScreen({super.key, required this.sessionId});

  @override
  State<AnalyticsDashboardScreen> createState() => _AnalyticsDashboardScreenState();
}

class _AnalyticsDashboardScreenState extends State<AnalyticsDashboardScreen> with SingleTickerProviderStateMixin {
  final _apiClient = sl<ApiClient>();
  late TabController _tabController;

  Map<String, dynamic>? _session;
  Map<String, dynamic>? _analyticsData;
  List<Map<String, dynamic>> _questions = [];
  List<Map<String, dynamic>> _polls = [];
  
  bool _isLoading = true;
  bool _isSavingSettings = false;

  final _titleController = TextEditingController();
  final _descController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _loadAnalytics();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _loadAnalytics() async {
    try {
      final session = await sl<SessionRepository>().getSessionDetails(widget.sessionId);
      final response = await _apiClient.dio.get('/analytics/session/${widget.sessionId}');
      final questions = await sl<QaRepository>().getSessionQuestions(widget.sessionId);
      final polls = await sl<PollRepository>().getSessionPolls(widget.sessionId);
      
      if (response.statusCode == 200 && response.data != null) {
        setState(() {
          _session = session;
          _analyticsData = response.data['data'] as Map<String, dynamic>;
          _questions = questions;
          _polls = polls;
          _titleController.text = session['title'] as String? ?? '';
          _descController.text = session['description'] as String? ?? '';
          _isLoading = false;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load analytics: $e'), backgroundColor: Colors.redAccent),
      );
    }
  }

  Future<void> _exportCSV(String type) async {
    try {
      final url = '/analytics/session/${widget.sessionId}/export/$type';
      final response = await _apiClient.dio.get(url);
      
      if (response.statusCode == 200 && response.data != null) {
        final csvString = response.data as String;
        final tempDir = await getTemporaryDirectory();
        final file = File('${tempDir.path}/session-${widget.sessionId}-$type.csv');
        await file.writeAsString(csvString);

        await Share.shareXFiles([XFile(file.path)], text: 'Exported session $type reports');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to export CSV: $e'), backgroundColor: Colors.redAccent),
      );
    }
  }

  Future<void> _exportPDF() async {
    if (_analyticsData == null) return;
    
    final metrics = _analyticsData!['metrics'] as Map<String, dynamic>;
    final polls = _analyticsData!['pollStats'] as List? ?? [];

    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Padding(
            padding: const pw.EdgeInsets.all(32),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Header(level: 0, text: 'QLix Session Engagement Report'),
                pw.SizedBox(height: 24),
                pw.Text('Session ID: ${widget.sessionId}', style: const pw.TextStyle(fontSize: 12)),
                pw.Text('Date Generated: ${DateTime.now().toLocal().toString()}', style: const pw.TextStyle(fontSize: 12)),
                pw.SizedBox(height: 32),
                pw.Text('CORE METRICS', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                pw.Divider(),
                pw.SizedBox(height: 12),
                pw.Bullet(text: 'Total Participants Joined: ${metrics['totalParticipants']}'),
                pw.Bullet(text: 'Total Votes Cast: ${metrics['totalVotes']}'),
                pw.Bullet(text: 'Total Q&A Questions Asked: ${metrics['totalQuestions']}'),
                pw.Bullet(text: 'Average Engagement Ratio: ${metrics['averageEngagement']} events/user'),
                pw.SizedBox(height: 32),
                pw.Text('POLL FEEDBACK SUMMARY', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                pw.Divider(),
                pw.SizedBox(height: 12),
                ...polls.map((p) {
                  return pw.Padding(
                    padding: const pw.EdgeInsets.only(bottom: 12),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(p['title'] as String, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        pw.Text('${p['votesCount']} responses'),
                      ],
                    ),
                  );
                }),
              ],
            ),
          );
        },
      ),
    );

    try {
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/session-${widget.sessionId}-report.pdf');
      await file.writeAsBytes(await pdf.save());

      await Share.shareXFiles([XFile(file.path)], text: 'Exported session PDF report');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to compile PDF: $e'), backgroundColor: Colors.redAccent),
      );
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '';
    try {
      final date = DateTime.parse(dateStr).toLocal();
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${months[date.month - 1]} ${date.day}, ${date.year}';
    } catch (_) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final code = _session?['access_code'] as String? ?? '000000';
    final formattedCode = code.length == 6
        ? '${code.substring(0, 3)} ${code.substring(3)}'
        : code;

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: isDark ? Colors.white : AppColors.textPrimaryLight),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.ios_share_rounded, color: isDark ? Colors.white : AppColors.textPrimaryLight),
            tooltip: 'Export PDF Report',
            onPressed: _exportPDF,
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert_rounded, color: isDark ? Colors.white : AppColors.textPrimaryLight),
            onSelected: (val) {
              if (val == 'export_questions') {
                _exportCSV('questions');
              } else if (val == 'export_votes') {
                _exportCSV('votes');
              } else if (val == 'refresh') {
                setState(() => _isLoading = true);
                _loadAnalytics();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'export_questions',
                child: Row(
                  children: [
                    Icon(Icons.download_rounded, size: 18),
                    SizedBox(width: 8),
                    Text('Export Questions (CSV)'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'export_votes',
                child: Row(
                  children: [
                    Icon(Icons.download_rounded, size: 18),
                    SizedBox(width: 8),
                    Text('Export Votes (CSV)'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'refresh',
                child: Row(
                  children: [
                    Icon(Icons.refresh_rounded, size: 18),
                    SizedBox(width: 8),
                    Text('Refresh Data'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // 1. Session Title Header Card
          _buildHeaderCard(isDark),

          // 2. TabBar
          Container(
            color: isDark ? AppColors.surfaceDark : Colors.white,
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              indicatorColor: AppColors.primary,
              indicatorSize: TabBarIndicatorSize.tab,
              labelColor: AppColors.primary,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              unselectedLabelColor: isDark ? Colors.white60 : Colors.black54,
              indicatorWeight: 3,
              tabs: const [
                Tab(text: 'Overview'),
                Tab(text: 'Questions'),
                Tab(text: 'Responses'),
                Tab(text: 'Participants'),
                Tab(text: 'Settings'),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1),

          // 3. TabBarView
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildOverviewTab(isDark, formattedCode),
                _buildQuestionsTab(isDark),
                _buildResponsesTab(isDark),
                _buildParticipantsTab(isDark),
                _buildSettingsTab(isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderCard(bool isDark) {
    final title = _session?['title'] as String? ?? 'Poll Session';
    final state = _session?['state'] as String? ?? 'draft';
    final createdAt = _session?['created_at'] as String? ?? '';
    final participantsCount = _analyticsData?['metrics']?['totalParticipants'] ?? 0;

    final isLive = state == 'active';
    final stateText = isLive ? 'Live' : (state == 'ended' ? 'Ended' : 'Draft');
    final stateColor = isLive ? AppColors.success : (state == 'ended' ? Colors.grey : AppColors.warning);

    return Container(
      color: isDark ? AppColors.surfaceDark : Colors.white,
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Violet Icon
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.analytics_rounded,
              color: AppColors.primary,
              size: 32,
            ),
          ),
          const SizedBox(width: 16),
          // Title and Meta
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: isDark ? Colors.white : AppColors.textPrimaryLight,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: stateColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isLive) ...[
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: AppColors.success,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 4),
                          ],
                          Text(
                            stateText,
                            style: TextStyle(
                              color: stateColor,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Created on ${_formatDate(createdAt)}   •   $participantsCount participants',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white60 : AppColors.textSecondaryLight,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewTab(bool isDark, String formattedCode) {
    final metrics = _analyticsData!['metrics'] as Map<String, dynamic>;
    final timeline = _analyticsData!['activityTimeline'] as List? ?? [];
    final recentResponses = _analyticsData!['recentResponses'] as List? ?? [];
    final code = _session?['access_code'] as String? ?? '000000';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Session Code Card
          _buildSessionCodeCard(isDark, formattedCode, code),
          const SizedBox(height: 24),

          // 2. Statistics Grid
          _buildStatsGrid(isDark, metrics),
          const SizedBox(height: 24),

          // 3. Response Activity Chart
          _buildResponseActivityChart(isDark, timeline),
          const SizedBox(height: 24),

          // 4. Recent Responses
          _buildRecentResponsesSection(isDark, recentResponses),
          const SizedBox(height: 32),

          // 5. Bottom action buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: const BorderSide(color: AppColors.primary, width: 1.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    foregroundColor: AppColors.primary,
                  ),
                  onPressed: () {
                    _tabController.animateTo(4); // Switch to Settings tab
                  },
                  icon: const Icon(Icons.settings_rounded, size: 20),
                  label: const Text(
                    'Session Settings',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () {
                    context.push('/presenter/$code');
                  },
                  icon: const Icon(Icons.play_arrow_rounded, size: 20),
                  label: const Text(
                    'Present Session',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSessionCodeCard(bool isDark, String formattedCode, String code) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Left side
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Session Code',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(
                      formattedCode,
                      style: TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : AppColors.textPrimaryLight,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.copy_rounded, color: AppColors.primary, size: 20),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: code));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Session code copied to clipboard!'),
                            backgroundColor: AppColors.primary,
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                RichText(
                  text: TextSpan(
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white60 : AppColors.textSecondaryLight,
                    ),
                    children: const [
                      TextSpan(text: 'Participants can join at '),
                      TextSpan(
                        text: 'qlix.app',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextSpan(text: ' with this code'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Divider
          Container(
            height: 80,
            width: 1,
            color: isDark ? Colors.white10 : Colors.black12,
            margin: const EdgeInsets.symmetric(horizontal: 20),
          ),
          // Right side
          Column(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: QrImageView(
                  data: 'http://localhost:3000/session/$code',
                  version: QrVersions.auto,
                  size: 60,
                  gapless: false,
                  foregroundColor: Colors.black,
                ),
              ),
              const SizedBox(height: 6),
              TextButton.icon(
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: () {
                  Share.share('Join my QLix interactive session using code: $code\nOr join online at: http://localhost:3000/session/$code');
                },
                icon: const Icon(Icons.share_rounded, size: 14, color: AppColors.primary),
                label: const Text(
                  'Share Code',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid(bool isDark, Map<String, dynamic> metrics) {
    final participantsCount = metrics['totalParticipants'] ?? 0;
    final totalVotes = metrics['totalVotes'] ?? 0;
    final averageEngagement = metrics['averageEngagement'] ?? 0.0;

    // Engagement label
    String engLabel = 'Low';
    Color engColor = AppColors.error;
    if (averageEngagement >= 5.0) {
      engLabel = 'High';
      engColor = AppColors.success;
    } else if (averageEngagement >= 2.0) {
      engLabel = 'Medium';
      engColor = AppColors.warning;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final double cardWidth = (constraints.maxWidth - 16) / 2;
        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            _buildStatCard(
              isDark: isDark,
              width: cardWidth,
              icon: Icons.group_rounded,
              iconBgColor: AppColors.primary.withOpacity(0.12),
              iconColor: AppColors.primary,
              value: '$participantsCount',
              label: 'Participants',
              footerWidget: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: AppColors.success,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Text(
                    'Live',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.success),
                  ),
                ],
              ),
            ),
            _buildStatCard(
              isDark: isDark,
              width: cardWidth,
              icon: Icons.trending_up_rounded,
              iconBgColor: engColor.withOpacity(0.12),
              iconColor: engColor,
              value: '${(averageEngagement * 10).clamp(0, 100).toInt()}%',
              label: 'Engagement',
              footerWidget: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: engColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    engLabel,
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: engColor),
                  ),
                ],
              ),
            ),
            _buildStatCard(
              isDark: isDark,
              width: cardWidth,
              icon: Icons.how_to_vote_rounded,
              iconBgColor: AppColors.secondary.withOpacity(0.12),
              iconColor: AppColors.secondary,
              value: '$totalVotes',
              label: 'Responses',
              footerWidget: const Text(
                'Total',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey),
              ),
            ),
            _buildStatCard(
              isDark: isDark,
              width: cardWidth,
              icon: Icons.timer_rounded,
              iconBgColor: AppColors.purpleAccent.withOpacity(0.12),
              iconColor: AppColors.purpleAccent,
              value: _getMockAvgTime(participantsCount, totalVotes),
              label: 'Avg. Time',
              footerWidget: const Text(
                'Per participant',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey),
              ),
            ),
          ],
        );
      },
    );
  }

  String _getMockAvgTime(int participants, int votes) {
    if (participants == 0 || votes == 0) return '0s';
    final totalSec = (votes * 15 + participants * 25) % 180 + 30;
    final min = totalSec ~/ 60;
    final sec = totalSec % 60;
    return min > 0 ? '${min}m ${sec}s' : '${sec}s';
  }

  Widget _buildStatCard({
    required bool isDark,
    required double width,
    required IconData icon,
    required Color iconBgColor,
    required Color iconColor,
    required String value,
    required String label,
    required Widget footerWidget,
  }) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconBgColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            value,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : AppColors.textPrimaryLight,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 10),
          footerWidget,
        ],
      ),
    );
  }

  Widget _buildResponseActivityChart(bool isDark, List<dynamic> timeline) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Response Activity',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : AppColors.textPrimaryLight,
                  letterSpacing: -0.5,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isDark ? Colors.white12 : Colors.black.withOpacity(0.05),
                  ),
                ),
                child: Row(
                  children: [
                    Text(
                      'Last 30 mins',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white70 : AppColors.textSecondaryLight,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 14,
                      color: isDark ? Colors.white70 : AppColors.textSecondaryLight,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 180,
            child: timeline.isEmpty
                ? Center(
                    child: Text(
                      'No timeline activity registered yet',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.white60 : AppColors.textSecondaryLight,
                      ),
                    ),
                  )
                : LineChart(
                    LineChartData(
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        getDrawingHorizontalLine: (value) {
                          return FlLine(
                            color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.04),
                            strokeWidth: 1,
                          );
                        },
                      ),
                      titlesData: FlTitlesData(
                        show: true,
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 28,
                            getTitlesWidget: (value, meta) {
                              return Text(
                                value.toInt().toString(),
                                style: const TextStyle(
                                  color: Colors.grey,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              );
                            },
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 22,
                            getTitlesWidget: (value, meta) {
                              final idx = value.toInt();
                              if (idx >= 0 && idx < timeline.length) {
                                final timeStr = timeline[idx]['time'] as String? ?? '';
                                String display = timeStr;
                                if (timeStr.contains('T')) {
                                  final timePart = timeStr.split('T').last;
                                  if (timePart.length >= 5) {
                                    display = timePart.substring(0, 5);
                                  }
                                } else if (timeStr.contains(' ')) {
                                  final timePart = timeStr.split(' ').last;
                                  if (timePart.length >= 5) {
                                    display = timePart.substring(0, 5);
                                  }
                                }
                                return Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    display,
                                    style: const TextStyle(
                                      color: Colors.grey,
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                );
                              }
                              return const SizedBox();
                            },
                          ),
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      lineTouchData: LineTouchData(
                        touchTooltipData: LineTouchTooltipData(
                          getTooltipColor: (touchedSpot) => isDark ? AppColors.cardDark : Colors.white,
                          getTooltipItems: (touchedSpots) {
                            return touchedSpots.map((spot) {
                              final idx = spot.x.toInt();
                              final timeStr = idx >= 0 && idx < timeline.length ? timeline[idx]['time'] as String? ?? '' : '';
                              String display = timeStr;
                              if (timeStr.contains('T')) {
                                display = timeStr.split('T').last.substring(0, 5);
                              }
                              return LineTooltipItem(
                                '$display\n${spot.y.toInt()} joins',
                                TextStyle(
                                  color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                                  fontWeight: FontWeight.bold,
                                ),
                              );
                            }).toList();
                          },
                        ),
                      ),
                      lineBarsData: [
                        LineChartBarData(
                          spots: List.generate(timeline.length, (idx) {
                            return FlSpot(idx.toDouble(), (timeline[idx]['count'] as int).toDouble());
                          }),
                          isCurved: true,
                          gradient: const LinearGradient(
                            colors: [AppColors.primary, AppColors.purpleAccent],
                          ),
                          barWidth: 3.5,
                          dotData: const FlDotData(show: false),
                          belowBarData: BarAreaData(
                            show: true,
                            gradient: LinearGradient(
                              colors: [
                                AppColors.primary.withOpacity(0.18),
                                AppColors.primary.withOpacity(0.0),
                              ],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
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
  }

  Widget _buildRecentResponsesSection(bool isDark, List<dynamic> recent) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Recent Responses',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : AppColors.textPrimaryLight,
                letterSpacing: -0.5,
              ),
            ),
            TextButton(
              onPressed: () {
                _tabController.animateTo(2); // Switch to Responses tab
              },
              child: const Text(
                'View All',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        recent.isEmpty
            ? Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.surfaceDark : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05),
                  ),
                ),
                child: const Center(
                  child: Text(
                    'No responses received yet',
                    style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w500),
                  ),
                ),
              )
            : Column(
                children: List.generate(recent.length, (idx) {
                  final resp = recent[idx] as Map<String, dynamic>;
                  final name = resp['participantName'] as String? ?? 'Anonymous';
                  final pollTitle = resp['pollTitle'] as String? ?? 'Question';
                  final type = resp['pollType'] as String? ?? '';
                  final timeStr = resp['createdAt'] as String? ?? '';
                  
                  String displayTime = '';
                  try {
                    final dt = DateTime.parse(timeStr).toLocal();
                    final hr = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
                    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
                    final min = dt.minute < 10 ? '0${dt.minute}' : '${dt.minute}';
                    displayTime = '$hr:$min $ampm';
                  } catch (_) {
                    displayTime = timeStr;
                  }

                  String valText = '';
                  if (type == 'rating') {
                    valText = '${resp['ratingValue'] ?? 0}/5';
                  } else if (type == 'multiple_choice' || type == 'ranking') {
                    valText = resp['optionText'] as String? ?? '';
                  } else {
                    valText = resp['textResponse'] as String? ?? 'Submitted';
                  }
                  if (valText.length > 15) {
                    valText = '${valText.substring(0, 12)}...';
                  }

                  final initials = name.length >= 2 ? name.substring(0, 2).toUpperCase() : 'A';
                  final colorsList = [Colors.blue, Colors.purple, Colors.teal, Colors.amber, Colors.pink];
                  final avatarBg = colorsList[idx % colorsList.length];

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.surfaceDark : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05),
                      ),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: avatarBg.withOpacity(0.12),
                          radius: 20,
                          child: Text(
                            initials,
                            style: TextStyle(color: avatarBg, fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: isDark ? Colors.white : AppColors.textPrimaryLight,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                displayTime,
                                style: const TextStyle(
                                  color: Colors.grey,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '${pollTitle.length > 15 ? pollTitle.substring(0, 12) + "..." : pollTitle} • ${type == "multiple_choice" ? "MCQ" : type.replaceAll("_", " ").toUpperCase()}',
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                valText,
                                style: const TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }),
              ),
      ],
    );
  }

  Widget _buildQuestionsTab(bool isDark) {
    if (_questions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.chat_bubble_outline_rounded, size: 48, color: Colors.grey.withOpacity(0.5)),
            const SizedBox(height: 16),
            const Text(
              'No questions asked yet',
              style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w600, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: _questions.length,
      itemBuilder: (context, index) {
        final q = _questions[index];
        final author = q['authorName'] as String? ?? 'Anonymous';
        final text = q['text'] as String? ?? '';
        final upvotes = q['upvotesCount'] as int? ?? 0;
        final isPinned = q['isPinned'] as bool? ?? false;
        final status = q['status'] as String? ?? 'approved';
        
        final initials = author.length >= 2 ? author.substring(0, 2).toUpperCase() : 'A';
        final colors = [Colors.blue, Colors.purple, Colors.teal, Colors.amber];
        final avatarColor = colors[index % colors.length];

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isPinned
                  ? AppColors.primary.withOpacity(0.3)
                  : (isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05)),
              width: isPinned ? 1.5 : 1.0,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: avatarColor.withOpacity(0.12),
                        radius: 16,
                        child: Text(
                          initials,
                          style: TextStyle(color: avatarColor, fontWeight: FontWeight.bold, fontSize: 11),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        author,
                        style: TextStyle(
                          color: isDark ? Colors.white : AppColors.textPrimaryLight,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  if (isPinned)
                    const Row(
                      children: [
                        Icon(Icons.push_pin_rounded, color: AppColors.accent, size: 14),
                        SizedBox(width: 4),
                        Text(
                          'Pinned',
                          style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold, fontSize: 11),
                        ),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                text,
                style: TextStyle(
                  color: isDark ? Colors.white70 : AppColors.textPrimaryLight,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: status == 'answered' ? Colors.green.withOpacity(0.12) : Colors.grey.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      status == 'answered' ? 'ANSWERED' : 'UNANSWERED',
                      style: TextStyle(
                        color: status == 'answered' ? Colors.green : Colors.grey,
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      const Icon(Icons.thumb_up_rounded, color: AppColors.secondary, size: 14),
                      const SizedBox(width: 6),
                      Text(
                        '$upvotes upvotes',
                        style: const TextStyle(
                          color: AppColors.secondary,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildResponsesTab(bool isDark) {
    if (_polls.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bar_chart_rounded, size: 48, color: Colors.grey.withOpacity(0.5)),
            const SizedBox(height: 16),
            const Text(
              'No polls created in this session',
              style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w600, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: _polls.length,
      itemBuilder: (context, index) {
        final poll = _polls[index];
        final title = poll['title'] as String? ?? 'Poll';
        final type = poll['type'] as String? ?? 'multiple_choice';
        final status = poll['status'] as String? ?? 'draft';

        IconData typeIcon;
        switch (type) {
          case 'multiple_choice':
            typeIcon = Icons.list_rounded;
            break;
          case 'word_cloud':
            typeIcon = Icons.cloud_rounded;
            break;
          case 'rating':
            typeIcon = Icons.star_rounded;
            break;
          default:
            typeIcon = Icons.short_text_rounded;
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(typeIcon, size: 14, color: Colors.grey),
                      const SizedBox(width: 6),
                      Text(
                        type.replaceAll('_', ' ').toUpperCase(),
                        style: const TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: (status == 'active' ? AppColors.success : (status == 'ended' ? Colors.grey : AppColors.warning)).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      status.toUpperCase(),
                      style: TextStyle(
                        color: status == 'active' ? AppColors.success : (status == 'ended' ? Colors.grey : AppColors.warning),
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                title,
                style: TextStyle(
                  color: isDark ? Colors.white : AppColors.textPrimaryLight,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 12),
              _buildPollResultsSummary(poll),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPollResultsSummary(Map<String, dynamic> poll) {
    final results = poll['results'];
    if (results == null) {
      return const Text(
        'No votes cast yet',
        style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.grey),
      );
    }

    final type = poll['type'] as String? ?? 'multiple_choice';

    if (type == 'multiple_choice') {
      final options = results['options'] as List? ?? [];
      if (options.isEmpty) {
        return const Text('No options available', style: TextStyle(fontSize: 12, color: Colors.grey));
      }
      return Column(
        children: options.map<Widget>((opt) {
          final percent = opt['percentage'] as int? ?? 0;
          final text = opt['optionText'] as String? ?? '';
          return Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        text,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$percent%',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: percent / 100,
                    minHeight: 8,
                    backgroundColor: Colors.grey.withOpacity(0.12),
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary.withOpacity(0.85)),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      );
    } else if (type == 'rating') {
      final average = (results['average'] as num?)?.toDouble() ?? 0.0;
      final total = results['totalVotes'] as int? ?? 0;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ...List.generate(5, (idx) {
                final filled = idx < average.round();
                return Icon(
                  filled ? Icons.star_rounded : Icons.star_border_rounded,
                  color: Colors.amber,
                  size: 20,
                );
              }),
              const SizedBox(width: 8),
              Text(
                '${average.toStringAsFixed(1)} / 5.0',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Based on $total responses',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      );
    }

    final totalVotes = results['totalVotes'] as int? ?? 0;
    return Text(
      'Collected $totalVotes total responses',
      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primary),
    );
  }

  Widget _buildParticipantsTab(bool isDark) {
    final participantsList = _analyticsData?['participantsList'] as List? ?? [];
    if (participantsList.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.group_outlined, size: 48, color: Colors.grey.withOpacity(0.5)),
            const SizedBox(height: 16),
            const Text(
              'No participants joined yet',
              style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w600, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: participantsList.length,
      itemBuilder: (context, index) {
        final p = participantsList[index];
        final name = p['name'] as String? ?? 'Anonymous';
        final isAnonymous = p['isAnonymous'] as bool? ?? false;
        final joinedAt = p['joinedAt'] as String? ?? '';

        final initials = name.length >= 2 ? name.substring(0, 2).toUpperCase() : 'A';
        final colors = [Colors.blue, Colors.purple, Colors.teal, Colors.amber];
        final avatarColor = colors[index % colors.length];

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05),
            ),
          ),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: avatarColor.withOpacity(0.12),
                radius: 20,
                child: Text(
                  initials,
                  style: TextStyle(color: avatarColor, fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          name,
                          style: TextStyle(
                            color: isDark ? Colors.white : AppColors.textPrimaryLight,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        if (isAnonymous) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.grey.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'Anonymous',
                              style: TextStyle(color: Colors.grey, fontSize: 9, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Joined at ${_formatTime(joinedAt)}',
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 12,
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
  }

  String _formatTime(String dateStr) {
    try {
      final date = DateTime.parse(dateStr).toLocal();
      final hr = date.hour > 12 ? date.hour - 12 : (date.hour == 0 ? 12 : date.hour);
      final ampm = date.hour >= 12 ? 'PM' : 'AM';
      final min = date.minute < 10 ? '0${date.minute}' : '${date.minute}';
      return '$hr:$min $ampm';
    } catch (_) {
      return dateStr;
    }
  }

  Widget _buildSettingsTab(bool isDark) {
    final status = _session?['state'] as String? ?? 'draft';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Session Details',
            style: TextStyle(
              color: isDark ? Colors.white : AppColors.textPrimaryLight,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _titleController,
            decoration: InputDecoration(
              labelText: 'Session Title',
              filled: true,
              fillColor: isDark ? Colors.white.withOpacity(0.04) : const Color(0xFFF1F5F9),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _descController,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: 'Session Description',
              filled: true,
              fillColor: isDark ? Colors.white.withOpacity(0.04) : const Color(0xFFF1F5F9),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Session Status',
            style: TextStyle(
              color: isDark ? Colors.white : AppColors.textPrimaryLight,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceDark : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Session State',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        status == 'active'
                            ? 'Active and open for joins.'
                            : (status == 'ended'
                                ? 'Closed and cannot be joined.'
                                : 'Draft mode.'),
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                DropdownButton<String>(
                  value: status,
                  onChanged: (val) {
                    if (val != null) {
                      _updateSessionStatus(val);
                    }
                  },
                  items: const [
                    DropdownMenuItem(value: 'draft', child: Text('Draft')),
                    DropdownMenuItem(value: 'active', child: Text('Active')),
                    DropdownMenuItem(value: 'ended', child: Text('Ended')),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: _isSavingSettings ? null : _saveSessionSettings,
            child: _isSavingSettings
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : const Text(
                    'Save Settings',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _updateSessionStatus(String newStatus) async {
    try {
      final updated = await sl<SessionRepository>().updateSession(widget.sessionId, {'state': newStatus});
      setState(() {
        _session = updated;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Session status updated!'), backgroundColor: Colors.green),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update status: $e'), backgroundColor: Colors.redAccent),
      );
    }
  }

  Future<void> _saveSessionSettings() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a session title'), backgroundColor: Colors.redAccent),
      );
      return;
    }

    setState(() => _isSavingSettings = true);

    try {
      final updated = await sl<SessionRepository>().updateSession(widget.sessionId, {
        'title': title,
        'description': _descController.text.trim(),
      });
      setState(() {
        _session = updated;
        _isSavingSettings = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Session details updated!'), backgroundColor: Colors.green),
      );
    } catch (e) {
      setState(() => _isSavingSettings = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update settings: $e'), backgroundColor: Colors.redAccent),
      );
    }
  }
}
