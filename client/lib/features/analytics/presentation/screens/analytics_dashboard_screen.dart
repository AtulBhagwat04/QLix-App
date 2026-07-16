import 'dart:io';
import 'dart:ui' as ui;
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
import '../../../../core/network/socket_client.dart';
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
  State<AnalyticsDashboardScreen> createState() =>
      _AnalyticsDashboardScreenState();
}

class _AnalyticsDashboardScreenState extends State<AnalyticsDashboardScreen>
    with SingleTickerProviderStateMixin {
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
  final _participantSearchController = TextEditingController();
  String _participantSearchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _loadAnalytics();
    _participantSearchController.addListener(() {
      setState(() {
        _participantSearchQuery = _participantSearchController.text;
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _titleController.dispose();
    _descController.dispose();
    _participantSearchController.dispose();
    super.dispose();
  }

  Future<void> _loadAnalytics() async {
    try {
      final session = await sl<SessionRepository>().getSessionDetails(
        widget.sessionId,
      );
      final response = await _apiClient.dio.get(
        '/analytics/session/${widget.sessionId}',
      );
      final questions = await sl<QaRepository>().getSessionQuestions(
        widget.sessionId,
      );
      final polls = await sl<PollRepository>().getSessionPolls(
        widget.sessionId,
      );

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
        SnackBar(
          content: Text('Failed to load analytics: $e'),
          backgroundColor: Colors.redAccent,
        ),
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
        final file = File(
          '${tempDir.path}/session-${widget.sessionId}-$type.csv',
        );
        await file.writeAsString(csvString);

        await Share.shareXFiles([
          XFile(file.path),
        ], text: 'Exported session $type reports');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to export CSV: $e'),
          backgroundColor: Colors.redAccent,
        ),
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
                pw.Text(
                  'Session ID: ${widget.sessionId}',
                  style: const pw.TextStyle(fontSize: 12),
                ),
                pw.Text(
                  'Date Generated: ${DateTime.now().toLocal().toString()}',
                  style: const pw.TextStyle(fontSize: 12),
                ),
                pw.SizedBox(height: 32),
                pw.Text(
                  'CORE METRICS',
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Divider(),
                pw.SizedBox(height: 12),
                pw.Bullet(
                  text:
                      'Total Participants Joined: ${metrics['totalParticipants']}',
                ),
                pw.Bullet(text: 'Total Votes Cast: ${metrics['totalVotes']}'),
                pw.Bullet(
                  text:
                      'Total Q&A Questions Asked: ${metrics['totalQuestions']}',
                ),
                pw.Bullet(
                  text:
                      'Average Engagement Ratio: ${metrics['averageEngagement']} events/user',
                ),
                pw.SizedBox(height: 32),
                pw.Text(
                  'POLL FEEDBACK SUMMARY',
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Divider(),
                pw.SizedBox(height: 12),
                ...polls.map((p) {
                  return pw.Padding(
                    padding: const pw.EdgeInsets.only(bottom: 12),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          p['title'] as String,
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        ),
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
      final file = File(
        '${tempDir.path}/session-${widget.sessionId}-report.pdf',
      );
      await file.writeAsBytes(await pdf.save());

      await Share.shareXFiles([
        XFile(file.path),
      ], text: 'Exported session PDF report');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to compile PDF: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  String _getShortTypeName(String type) {
    switch (type) {
      case 'multiple_choice':
        return 'MCQ';
      case 'word_cloud':
        return 'Cloud';
      case 'rating':
        return 'Rating';
      case 'open_text':
        return 'Open';
      case 'ranking':
        return 'Rank';
      case 'survey':
        return 'Survey';
      default:
        return 'Poll';
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '';
    try {
      final date = DateTime.parse(dateStr).toLocal();
      final months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
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
      backgroundColor: isDark
          ? AppColors.backgroundDark
          : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_rounded,
            color: isDark ? Colors.white : AppColors.textPrimaryLight,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.ios_share_rounded,
              color: isDark ? Colors.white : AppColors.textPrimaryLight,
            ),
            tooltip: 'Export PDF Report',
            onPressed: _exportPDF,
          ),
          PopupMenuButton<String>(
            icon: Icon(
              Icons.more_vert_rounded,
              color: isDark ? Colors.white : AppColors.textPrimaryLight,
            ),
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
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              indicatorColor: AppColors.primary,
              indicatorSize: TabBarIndicatorSize.label,
              labelColor: AppColors.primary,
              labelStyle: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
              unselectedLabelColor: isDark ? Colors.white60 : Colors.black54,
              unselectedLabelStyle: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
              indicatorWeight: 3,
              tabs: const [
                Tab(text: 'Overview'),
                Tab(text: 'Q&A Feed'),
                Tab(text: 'Poll Results'),
                Tab(text: 'Attendees'),
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
    final participantsCount =
        _analyticsData?['metrics']?['totalParticipants'] ?? 0;

    final isLive = state == 'active';
    final stateText = isLive ? 'LIVE' : (state == 'ended' ? 'ENDED' : 'DRAFT');
    final stateColor = isLive
        ? AppColors.success
        : (state == 'ended' ? Colors.grey : AppColors.warning);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark
                ? Colors.white.withOpacity(0.08)
                : Colors.black.withOpacity(0.05),
          ),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.analytics_rounded,
              color: AppColors.primary,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
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
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: isDark
                              ? Colors.white
                              : AppColors.textPrimaryLight,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: stateColor.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: stateColor.withOpacity(0.2),
                          width: 1,
                        ),
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
                            const SizedBox(width: 5),
                          ],
                          Text(
                            stateText,
                            style: TextStyle(
                              color: stateColor,
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${_formatDate(createdAt)}  •  $participantsCount attendees joined',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: isDark
                        ? Colors.white54
                        : AppColors.textSecondaryLight,
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
                    side: const BorderSide(
                      color: AppColors.primary,
                      width: 1.5,
                    ),
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.08)
              : Colors.black.withOpacity(0.05),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SESSION CODE',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                    color: isDark ? Colors.white54 : Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          formattedCode,
                          style: TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w900,
                            color: isDark
                                ? Colors.white
                                : AppColors.textPrimaryLight,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 2),
                    IconButton(
                      icon: const Icon(
                        Icons.copy_rounded,
                        color: AppColors.primary,
                        size: 16,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: code));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Session code copied!'),
                            backgroundColor: AppColors.primary,
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            height: 72,
            width: 1,
            color: isDark
                ? Colors.white.withOpacity(0.08)
                : Colors.black.withOpacity(0.05),
            margin: const EdgeInsets.symmetric(horizontal: 10),
          ),
          Column(
            children: [
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: Colors.black.withOpacity(0.05),
                    width: 1,
                  ),
                ),
                child: QrImageView(
                  data: '${SocketClient.serverUrl}/session/$code',
                  version: QrVersions.auto,
                  size: 72,
                  gapless: false,
                  foregroundColor: Colors.black,
                ),
              ),
              const SizedBox(height: 4),
              GestureDetector(
                onTap: () => _shareQrCode(code),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.share_rounded,
                      size: 11,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Share QR',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                        letterSpacing: 0.1,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  void _drawCenteredText(Canvas canvas, String text, double centerY, TextStyle style, double maxWidth) {
    final textPainter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );
    textPainter.layout(maxWidth: maxWidth);
    final x = (maxWidth - textPainter.width) / 2;
    final y = centerY - (textPainter.height / 2);
    textPainter.paint(canvas, Offset(x, y));
  }

  Future<void> _shareQrCode(String code) async {
    try {
      final qrValidationResult = QrValidator.validate(
        data: '${SocketClient.serverUrl}/session/$code',
        version: QrVersions.auto,
        errorCorrectionLevel: QrErrorCorrectLevel.M, // Allow room for center logo overlay
      );

      if (qrValidationResult.status == QrValidationStatus.valid) {
        final qrCode = qrValidationResult.qrCode!;
        final painter = QrPainter.withQr(
          qr: qrCode,
          eyeStyle: const QrEyeStyle(
            eyeShape: QrEyeShape.square,
            color: Color(0xFF0F172A), // Matching dark slate color for QR
          ),
          dataModuleStyle: const QrDataModuleStyle(
            dataModuleShape: QrDataModuleShape.square,
            color: Color(0xFF0F172A),
          ),
          gapless: true,
        );

        // Define base dimensions for the poster
        const double posterWidth = 400.0;
        const double posterHeight = 720.0;
        const double scaleFactor = 4.0; // 4x scaling renders a razor-sharp UHD image (1600 x 2880 pixels)

        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, posterWidth * scaleFactor, posterHeight * scaleFactor));

        // Scale the canvas up for high definition rendering
        canvas.scale(scaleFactor);

        // 1. Draw Background (Plain Light Ice Theme matching the App style)
        final bgPaint = Paint()..color = const Color(0xFFF5F7FB);
        canvas.drawRect(const Rect.fromLTWH(0, 0, posterWidth, posterHeight), bgPaint);

        // Draw a light clean border around the poster edges
        final borderPaint = Paint()
          ..color = const Color(0xFFE2E8F0)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0;
        canvas.drawRect(const Rect.fromLTWH(0, 0, posterWidth, posterHeight), borderPaint);

        // 2. Draw Logo and QLix Header
        // Indigo logo circle
        final logoBgPaint = Paint()..color = const Color(0xFF6366F1);
        canvas.drawCircle(const Offset(140, 75), 18, logoBgPaint);
        
        // Logo Text "Q"
        final logoTextPainter = TextPainter(
          text: const TextSpan(
            text: 'Q',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        logoTextPainter.paint(canvas, Offset(140 - (logoTextPainter.width / 2), 75 - (logoTextPainter.height / 2)));

        // QLix brand name
        final brandPainter = TextPainter(
          text: const TextSpan(
            text: 'QLix',
            style: TextStyle(
              color: Color(0xFF0F172A), // Dark slate text for light theme
              fontSize: 28,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        brandPainter.paint(canvas, Offset(170, 75 - (brandPainter.height / 2)));

        // 3. Draw Subtitles
        _drawCenteredText(
          canvas,
          'JOIN LIVE SESSION',
          140,
          const TextStyle(
            color: Color(0xFF6366F1), // Primary Indigo for light theme
            fontSize: 14,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.5,
          ),
          posterWidth,
        );

        _drawCenteredText(
          canvas,
          'Scan QR code using QLix App',
          170,
          const TextStyle(
            color: Color(0xFF475569), // Muted slate text
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
          posterWidth,
        );

        // 4. Draw Qr Code Rounded Container (White Card)
        final cardPaint = Paint()..color = const Color(0xFFFFFFFF);
        final cardShadowPaint = Paint()
          ..color = const Color(0xFF0F172A).withOpacity(0.04)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
        
        final cardRect = RRect.fromRectAndRadius(
          const Rect.fromLTWH(50, 210, 300, 300),
          const Radius.circular(24),
        );
        // Draw card shadow
        canvas.drawRRect(cardRect.shift(const Offset(0, 4)), cardShadowPaint);
        // Draw card body
        canvas.drawRRect(cardRect, cardPaint);

        // Draw card border
        final cardBorderPaint = Paint()
          ..color = const Color(0xFFE2E8F0)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5;
        canvas.drawRRect(cardRect, cardBorderPaint);

        // Paint QrPainter inside white container
        canvas.save();
        canvas.translate(70, 230);
        painter.paint(canvas, const Size(260, 260));
        canvas.restore();

        // 5. Draw QLix Center Badge inside QR code matrix
        // White circular border clearing space in the center
        final centerClearPaint = Paint()..color = const Color(0xFFFFFFFF);
        canvas.drawCircle(const Offset(200, 360), 22, centerClearPaint);

        // Indigo inner circle
        final centerLogoBg = Paint()..color = const Color(0xFF6366F1);
        canvas.drawCircle(const Offset(200, 360), 17, centerLogoBg);

        // Center Text "Q"
        final centerLogoText = TextPainter(
          text: const TextSpan(
            text: 'Q',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        centerLogoText.paint(
          canvas,
          Offset(200 - (centerLogoText.width / 2), 360 - (centerLogoText.height / 2)),
        );

        // 6. Draw Host Session Code
        final formattedCode = code.length == 6 ? '${code.substring(0, 3)} ${code.substring(3)}' : code;
        _drawCenteredText(
          canvas,
          'SESSION CODE',
          550,
          const TextStyle(
            color: Color(0xFF475569),
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.0,
          ),
          posterWidth,
        );

        _drawCenteredText(
          canvas,
          formattedCode,
          590,
          const TextStyle(
            color: Color(0xFF6366F1), // Primary Indigo for high contrast
            fontSize: 36,
            fontWeight: FontWeight.w900,
            letterSpacing: 2.0,
          ),
          posterWidth,
        );

        // 7. Footer
        _drawCenteredText(
          canvas,
          '© 2026 QLix App. All rights reserved.',
          670,
          const TextStyle(
            color: Color(0xFF94A3B8),
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
          posterWidth,
        );

        final picture = recorder.endRecording();
        final ui.Image image = await picture.toImage((posterWidth * scaleFactor).toInt(), (posterHeight * scaleFactor).toInt());
        final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);

        if (byteData != null) {
          final Uint8List pngBytes = byteData.buffer.asUint8List();
          final tempDir = await getTemporaryDirectory();
          final file = File('${tempDir.path}/qlix_session_invite_$code.png');
          await file.writeAsBytes(pngBytes);

          final text = 'Join my QLix interactive session using code: $code\n'
              'Scan the attached QR code to join directly!\n\n'
              'Download QLix app from Play Store or App Store:\n'
              'Android (Play Store): https://play.google.com/store/apps/details?id=com.atulbhagwat.qlix\n'
              'iOS (App Store): https://apps.apple.com/app/qlix/id1234567890\n\n'
              'Or join via web at: ${SocketClient.serverUrl}/session/$code';

          await Share.shareXFiles(
            [XFile(file.path)],
            text: text,
            subject: 'Join QLix Session: $code',
          );
          return;
        }
      }

      await Share.share(
        'Join my QLix interactive session using code: $code\n'
        'Or join online at: ${SocketClient.serverUrl}/session/$code',
      );
    } catch (e) {
      debugPrint('Error sharing QR: $e');
      await Share.share(
        'Join my QLix interactive session using code: $code\n'
        'Or join online at: ${SocketClient.serverUrl}/session/$code',
      );
    }
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
              icon: Icons.people_outline_rounded,
              iconBgColor: AppColors.primary.withOpacity(0.08),
              iconColor: AppColors.primary,
              value: '$participantsCount',
              label: 'Total Users',
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
                    'Live tracking',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.success,
                    ),
                  ),
                ],
              ),
            ),
            _buildStatCard(
              isDark: isDark,
              width: cardWidth,
              icon: Icons.insights_rounded,
              iconBgColor: engColor.withOpacity(0.08),
              iconColor: engColor,
              value: '${(averageEngagement * 10).clamp(0, 100).toInt()}%',
              label: 'Engagement Rate',
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
                    '$engLabel activity',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: engColor,
                    ),
                  ),
                ],
              ),
            ),
            _buildStatCard(
              isDark: isDark,
              width: cardWidth,
              icon: Icons.how_to_vote_rounded,
              iconBgColor: AppColors.secondary.withOpacity(0.08),
              iconColor: AppColors.secondary,
              value: '$totalVotes',
              label: 'Votes Cast',
              footerWidget: Text(
                'Across all polls',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white38 : Colors.grey.shade500,
                ),
              ),
            ),
            _buildStatCard(
              isDark: isDark,
              width: cardWidth,
              icon: Icons.timer_outlined,
              iconBgColor: AppColors.purpleAccent.withOpacity(0.08),
              iconColor: AppColors.purpleAccent,
              value: _getMockAvgTime(participantsCount, totalVotes),
              label: 'Avg Response Time',
              footerWidget: Text(
                'Per response',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white38 : Colors.grey.shade500,
                ),
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.08)
              : Colors.black.withOpacity(0.05),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  label.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white38 : Colors.grey.shade500,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: iconBgColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: iconColor, size: 14),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : AppColors.textPrimaryLight,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
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
          color: isDark
              ? Colors.white.withOpacity(0.08)
              : Colors.black.withOpacity(0.05),
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isDark
                        ? Colors.white12
                        : Colors.black.withOpacity(0.05),
                  ),
                ),
                child: Row(
                  children: [
                    Text(
                      'Last 30 mins',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isDark
                            ? Colors.white70
                            : AppColors.textSecondaryLight,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 14,
                      color: isDark
                          ? Colors.white70
                          : AppColors.textSecondaryLight,
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
                        color: isDark
                            ? Colors.white60
                            : AppColors.textSecondaryLight,
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
                            color: isDark
                                ? Colors.white.withOpacity(0.05)
                                : Colors.black.withOpacity(0.04),
                            strokeWidth: 1,
                          );
                        },
                      ),
                      titlesData: FlTitlesData(
                        show: true,
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
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
                                final timeStr =
                                    timeline[idx]['time'] as String? ?? '';
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
                          getTooltipColor: (touchedSpot) =>
                              isDark ? AppColors.cardDark : Colors.white,
                          getTooltipItems: (touchedSpots) {
                            return touchedSpots.map((spot) {
                              final idx = spot.x.toInt();
                              final timeStr = idx >= 0 && idx < timeline.length
                                  ? timeline[idx]['time'] as String? ?? ''
                                  : '';
                              String display = timeStr;
                              if (timeStr.contains('T')) {
                                display = timeStr
                                    .split('T')
                                    .last
                                    .substring(0, 5);
                              }
                              return LineTooltipItem(
                                '$display\n${spot.y.toInt()} joins',
                                TextStyle(
                                  color: isDark
                                      ? AppColors.textPrimaryDark
                                      : AppColors.textPrimaryLight,
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
                            return FlSpot(
                              idx.toDouble(),
                              (timeline[idx]['count'] as int).toDouble(),
                            );
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
              'Recent Activity',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : AppColors.textPrimaryLight,
                letterSpacing: -0.5,
              ),
            ),
            TextButton(
              onPressed: () {
                _tabController.animateTo(2); // Switch to Poll Results tab
              },
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text(
                'View All Results',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        recent.isEmpty
            ? Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.surfaceDark : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withOpacity(0.08)
                        : Colors.black.withOpacity(0.05),
                  ),
                ),
                child: const Center(
                  child: Text(
                    'No responses received yet',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              )
            : Column(
                children: List.generate(recent.length, (idx) {
                  final resp = recent[idx] as Map<String, dynamic>;
                  final name =
                      resp['participantName'] as String? ?? 'Anonymous';
                  final pollTitle = resp['pollTitle'] as String? ?? 'Question';
                  final type = resp['pollType'] as String? ?? '';
                  final timeStr = resp['createdAt'] as String? ?? '';

                  String displayTime = '';
                  try {
                    final dt = DateTime.parse(timeStr).toLocal();
                    final hr = dt.hour > 12
                        ? dt.hour - 12
                        : (dt.hour == 0 ? 12 : dt.hour);
                    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
                    final min = dt.minute < 10
                        ? '0${dt.minute}'
                        : '${dt.minute}';
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

                  final initials = name.length >= 2
                      ? name.substring(0, 2).toUpperCase()
                      : 'A';
                  final colorsList = [
                    Colors.blue,
                    Colors.purple,
                    Colors.teal,
                    Colors.amber,
                    Colors.pink,
                  ];
                  final avatarBg = colorsList[idx % colorsList.length];

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.surfaceDark : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withOpacity(0.08)
                            : Colors.black.withOpacity(0.05),
                      ),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: avatarBg.withOpacity(0.08),
                          radius: 16,
                          child: Text(
                            initials,
                            style: TextStyle(
                              color: avatarBg,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: isDark
                                      ? Colors.white
                                      : AppColors.textPrimaryLight,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                displayTime,
                                style: TextStyle(
                                  color: isDark
                                      ? Colors.white38
                                      : Colors.grey.shade500,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Flexible(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '${pollTitle.length > 12 ? pollTitle.substring(0, 10) + "..." : pollTitle} • ${_getShortTypeName(type).toUpperCase()}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: isDark
                                      ? Colors.white38
                                      : Colors.grey.shade500,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  valText,
                                  style: const TextStyle(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                            ],
                          ),
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
            Icon(
              Icons.forum_outlined,
              size: 48,
              color: Colors.grey.withOpacity(0.4),
            ),
            const SizedBox(height: 16),
            const Text(
              'No questions in this feed yet',
              style: TextStyle(
                color: Colors.grey,
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      itemCount: _questions.length,
      itemBuilder: (context, index) {
        final q = _questions[index];
        final author = q['authorName'] as String? ?? 'Anonymous';
        final text = q['text'] as String? ?? '';
        final upvotes = q['upvotesCount'] as int? ?? 0;
        final isPinned = q['isPinned'] as bool? ?? false;
        final status = q['status'] as String? ?? 'approved';

        final initials = author.length >= 2
            ? author.substring(0, 2).toUpperCase()
            : 'A';
        final colors = [Colors.blue, Colors.purple, Colors.teal, Colors.amber];
        final avatarColor = colors[index % colors.length];

        return Container(
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isPinned
                  ? AppColors.primary.withOpacity(0.3)
                  : (isDark
                        ? Colors.white.withOpacity(0.08)
                        : Colors.black.withOpacity(0.05)),
              width: isPinned ? 1.5 : 1.0,
            ),
            boxShadow: isPinned
                ? [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Container(
              decoration: BoxDecoration(
                border: isPinned
                    ? const Border(
                        left: BorderSide(color: AppColors.primary, width: 4),
                      )
                    : null,
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: avatarColor.withOpacity(0.08),
                              radius: 14,
                              child: Text(
                                initials,
                                style: TextStyle(
                                  color: avatarColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                author,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: isDark
                                      ? Colors.white
                                      : AppColors.textPrimaryLight,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      if (isPinned)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.push_pin_rounded,
                              color: AppColors.primary,
                              size: 13,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Pinned',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.bold,
                                fontSize: 10,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    text,
                    style: TextStyle(
                      color: isDark
                          ? Colors.white70
                          : AppColors.textPrimaryLight,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: status == 'answered'
                              ? Colors.green.withOpacity(0.08)
                              : Colors.grey.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: status == 'answered'
                                ? Colors.green.withOpacity(0.15)
                                : Colors.grey.withOpacity(0.15),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          status == 'answered' ? 'ANSWERED' : 'OPEN',
                          style: TextStyle(
                            color: status == 'answered'
                                ? Colors.green
                                : Colors.grey.shade600,
                            fontWeight: FontWeight.w800,
                            fontSize: 9,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.secondary.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppColors.secondary.withOpacity(0.2),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.thumb_up_alt_outlined,
                              color: AppColors.secondary,
                              size: 13,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '$upvotes',
                              style: const TextStyle(
                                color: AppColors.secondary,
                                fontWeight: FontWeight.w800,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
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
            Icon(
              Icons.insert_chart_outlined_rounded,
              size: 48,
              color: Colors.grey.withOpacity(0.4),
            ),
            const SizedBox(height: 16),
            const Text(
              'No polls in this session',
              style: TextStyle(
                color: Colors.grey,
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
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
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark
                  ? Colors.white.withOpacity(0.08)
                  : Colors.black.withOpacity(0.05),
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
                      Icon(typeIcon, size: 14, color: Colors.grey.shade500),
                      const SizedBox(width: 6),
                      Text(
                        _getShortTypeName(type).toUpperCase(),
                        style: TextStyle(
                          color: isDark ? Colors.white54 : Colors.grey.shade600,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
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
                      color:
                          (status == 'active'
                                  ? AppColors.success
                                  : (status == 'ended'
                                        ? Colors.grey
                                        : AppColors.warning))
                              .withOpacity(0.08),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color:
                            (status == 'active'
                                    ? AppColors.success
                                    : (status == 'ended'
                                          ? Colors.grey
                                          : AppColors.warning))
                                .withOpacity(0.15),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      status.toUpperCase(),
                      style: TextStyle(
                        color: status == 'active'
                            ? AppColors.success
                            : (status == 'ended'
                                  ? Colors.grey
                                  : AppColors.warning),
                        fontSize: 8,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
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
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 14),
              _buildPollResultsSummary(isDark, poll),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPollResultsSummary(bool isDark, Map<String, dynamic> poll) {
    final results = poll['results'];
    if (results == null) {
      return Text(
        'No votes cast yet',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: isDark ? Colors.white38 : Colors.grey.shade500,
        ),
      );
    }

    final type = poll['type'] as String? ?? 'multiple_choice';

    if (type == 'multiple_choice') {
      final options = results['options'] as List? ?? [];
      if (options.isEmpty) {
        return const Text(
          'No options available',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        );
      }
      return Column(
        children: options.map<Widget>((opt) {
          final percent = opt['percentage'] as int? ?? 0;
          final text = opt['optionText'] as String? ?? '';
          return Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Stack(
              children: [
                Container(
                  height: 36,
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withOpacity(0.02)
                        : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withOpacity(0.04)
                          : Colors.black.withOpacity(0.03),
                    ),
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: (percent / 100.0).clamp(0.0, 1.0),
                  child: Container(
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                Container(
                  height: 36,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          text,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: isDark
                                ? Colors.white
                                : AppColors.textPrimaryLight,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '$percent%',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
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
      return Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.06),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              average.toStringAsFixed(1),
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: List.generate(5, (idx) {
                  final filled = idx < average.round();
                  return Icon(
                    filled ? Icons.star_rounded : Icons.star_border_rounded,
                    color: Colors.amber,
                    size: 16,
                  );
                }),
              ),
              const SizedBox(height: 4),
              Text(
                'Based on $total votes',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white38 : Colors.grey.shade500,
                ),
              ),
            ],
          ),
        ],
      );
    }

    final totalVotes = results['totalVotes'] as int? ?? 0;
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.08),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            '$totalVotes responses',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildParticipantsTab(bool isDark) {
    final rawParticipants = _analyticsData?['participantsList'] as List? ?? [];

    // Filter list by search query
    final query = _participantSearchQuery.trim().toLowerCase();
    final participantsList = rawParticipants.where((p) {
      final name = (p['name'] as String? ?? 'Anonymous').toLowerCase();
      return name.contains(query);
    }).toList();

    return Column(
      children: [
        // Search Bar Container
        Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
          color: isDark ? AppColors.backgroundDark : const Color(0xFFF8FAFC),
          child: TextField(
            controller: _participantSearchController,
            decoration: InputDecoration(
              hintText: 'Search attendees...',
              hintStyle: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white38 : Colors.grey.shade500,
              ),
              prefixIcon: Icon(
                Icons.search_rounded,
                size: 18,
                color: isDark ? Colors.white38 : Colors.grey.shade500,
              ),
              suffixIcon: _participantSearchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 18),
                      onPressed: () {
                        _participantSearchController.clear();
                      },
                    )
                  : null,
              filled: true,
              fillColor: isDark ? AppColors.surfaceDark : Colors.white,
              contentPadding: const EdgeInsets.symmetric(
                vertical: 0,
                horizontal: 16,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                  color: isDark
                      ? Colors.white.withOpacity(0.08)
                      : Colors.black.withOpacity(0.05),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                  color: isDark
                      ? Colors.white.withOpacity(0.08)
                      : Colors.black.withOpacity(0.05),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(
                  color: AppColors.primary,
                  width: 1.5,
                ),
              ),
            ),
          ),
        ),
        Expanded(
          child: participantsList.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.group_off_rounded,
                        size: 48,
                        color: Colors.grey.withOpacity(0.4),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        rawParticipants.isEmpty
                            ? 'No attendees joined yet'
                            : 'No matching attendees found',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  itemCount: participantsList.length,
                  itemBuilder: (context, index) {
                    final p = participantsList[index];
                    final name = p['name'] as String? ?? 'Anonymous';
                    final isAnonymous = p['isAnonymous'] as bool? ?? false;
                    final joinedAt = p['joinedAt'] as String? ?? '';

                    final initials = name.length >= 2
                        ? name.substring(0, 2).toUpperCase()
                        : 'A';
                    final colors = [
                      Colors.blue,
                      Colors.purple,
                      Colors.teal,
                      Colors.amber,
                    ];
                    final avatarColor = colors[index % colors.length];

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.surfaceDark : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withOpacity(0.08)
                              : Colors.black.withOpacity(0.05),
                        ),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: avatarColor.withOpacity(0.08),
                            radius: 16,
                            child: Text(
                              initials,
                              style: TextStyle(
                                color: avatarColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: isDark
                                              ? Colors.white
                                              : AppColors.textPrimaryLight,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                    if (isAnonymous) ...[
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 5,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.grey.withOpacity(0.08),
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        child: Text(
                                          'Anon',
                                          style: TextStyle(
                                            color: isDark
                                                ? Colors.white38
                                                : Colors.grey.shade600,
                                            fontSize: 8,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Joined at ${_formatTime(joinedAt)}',
                                  style: TextStyle(
                                    color: isDark
                                        ? Colors.white38
                                        : Colors.grey.shade500,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  String _formatTime(String dateStr) {
    try {
      final date = DateTime.parse(dateStr).toLocal();
      final hr = date.hour > 12
          ? date.hour - 12
          : (date.hour == 0 ? 12 : date.hour);
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
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Session Details',
            style: TextStyle(
              color: isDark ? Colors.white : AppColors.textPrimaryLight,
              fontSize: 15,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _titleController,
            decoration: InputDecoration(
              labelText: 'Session Title',
              labelStyle: TextStyle(
                color: isDark ? Colors.white54 : Colors.grey.shade600,
                fontSize: 13,
              ),
              filled: true,
              fillColor: isDark ? AppColors.surfaceDark : Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                  color: isDark
                      ? Colors.white.withOpacity(0.08)
                      : Colors.black.withOpacity(0.05),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                  color: isDark
                      ? Colors.white.withOpacity(0.08)
                      : Colors.black.withOpacity(0.05),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(
                  color: AppColors.primary,
                  width: 1.5,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _descController,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: 'Session Description',
              labelStyle: TextStyle(
                color: isDark ? Colors.white54 : Colors.grey.shade600,
                fontSize: 13,
              ),
              filled: true,
              fillColor: isDark ? AppColors.surfaceDark : Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                  color: isDark
                      ? Colors.white.withOpacity(0.08)
                      : Colors.black.withOpacity(0.05),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                  color: isDark
                      ? Colors.white.withOpacity(0.08)
                      : Colors.black.withOpacity(0.05),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(
                  color: AppColors.primary,
                  width: 1.5,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Session Status',
            style: TextStyle(
              color: isDark ? Colors.white : AppColors.textPrimaryLight,
              fontSize: 15,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceDark : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark
                    ? Colors.white.withOpacity(0.08)
                    : Colors.black.withOpacity(0.05),
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
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        status == 'active'
                            ? 'Active and open for joins.'
                            : (status == 'ended'
                                  ? 'Closed and cannot be joined.'
                                  : 'Draft mode.'),
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? Colors.white38 : Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ),
                DropdownButton<String>(
                  value: status,
                  underline: const SizedBox(),
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
          const SizedBox(height: 24),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: _isSavingSettings ? null : _saveSessionSettings,
            child: _isSavingSettings
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Text(
                    'Save Settings',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _updateSessionStatus(String newStatus) async {
    try {
      final updated = await sl<SessionRepository>().updateSession(
        widget.sessionId,
        {'state': newStatus},
      );
      setState(() {
        _session = updated;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Session status updated!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update status: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Future<void> _saveSessionSettings() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a session title'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => _isSavingSettings = true);

    try {
      final updated = await sl<SessionRepository>().updateSession(
        widget.sessionId,
        {'title': title, 'description': _descController.text.trim()},
      );
      setState(() {
        _session = updated;
        _isSavingSettings = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Session details updated!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      setState(() => _isSavingSettings = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update settings: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }
}
