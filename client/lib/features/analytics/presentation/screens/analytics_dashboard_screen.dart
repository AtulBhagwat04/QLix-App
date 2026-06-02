import 'dart:io';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';

class AnalyticsDashboardScreen extends StatefulWidget {
  final String sessionId;
  const AnalyticsDashboardScreen({super.key, required this.sessionId});

  @override
  State<AnalyticsDashboardScreen> createState() => _AnalyticsDashboardScreenState();
}

class _AnalyticsDashboardScreenState extends State<AnalyticsDashboardScreen> {
  final _apiClient = sl<ApiClient>();

  Map<String, dynamic>? _analyticsData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAnalytics();
  }

  Future<void> _loadAnalytics() async {
    try {
      final response = await _apiClient.dio.get('/analytics/session/${widget.sessionId}');
      if (response.statusCode == 200 && response.data != null) {
        setState(() {
          _analyticsData = response.data['data'] as Map<String, dynamic>;
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final metrics = _analyticsData!['metrics'] as Map<String, dynamic>;
    final timeline = _analyticsData!['activityTimeline'] as List? ?? [];
    final polls = _analyticsData!['pollStats'] as List? ?? [];
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      appBar: AppBar(
        title: const Text(
          'Session Analytics',
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: -0.5),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
        actions: [
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: AppColors.accentGradient),
              borderRadius: BorderRadius.circular(AppSizes.radiusButton),
              boxShadow: [
                BoxShadow(
                  color: AppColors.accent.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TextButton.icon(
              onPressed: _exportPDF,
              icon: const Icon(Icons.picture_as_pdf_rounded, color: Colors.white, size: 18),
              label: const Text(
                'EXPORT PDF',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                  letterSpacing: 0.5,
                ),
              ),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSizes.radiusButton),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          if (isDark) ...[
            Positioned(
              top: -100,
              left: -100,
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Positioned(
              bottom: -150,
              right: -100,
              child: Container(
                width: 400,
                height: 400,
                decoration: BoxDecoration(
                  color: AppColors.secondary.withOpacity(0.06),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ],
          SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Row metrics
                Row(
                  children: [
                    Expanded(
                      child: _buildMetricCard(
                        'Attendees',
                        '${metrics['totalParticipants']}',
                        Icons.group_rounded,
                        AppColors.primary,
                        AppColors.primaryGradient,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildMetricCard(
                        'Total Votes',
                        '${metrics['totalVotes']}',
                        Icons.how_to_vote_rounded,
                        AppColors.secondary,
                        AppColors.tealGradient,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildMetricCard(
                        'Q&A Count',
                        '${metrics['totalQuestions']}',
                        Icons.question_answer_rounded,
                        AppColors.accent,
                        AppColors.accentGradient,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 36),

                // Timelines activity chart
                Text(
                  'Timeline Activity (Joined Attendees)',
                  style: TextStyle(
                    color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  height: 250,
                  padding: const EdgeInsets.fromLTRB(16, 24, 24, 16),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.surfaceDark.withOpacity(0.45) : Colors.white,
                    borderRadius: BorderRadius.circular(AppSizes.radiusCard),
                    border: Border.all(
                      color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05),
                    ),
                  ),
                  child: timeline.isEmpty
                      ? Center(
                          child: Text(
                            'Not enough activity data yet',
                            style: TextStyle(
                              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                            ),
                          ),
                        )
                      : LineChart(
                          LineChartData(
                            gridData: FlGridData(
                              show: true,
                              drawVerticalLine: true,
                              horizontalInterval: 1,
                              verticalInterval: 1,
                              getDrawingHorizontalLine: (value) {
                                return FlLine(
                                  color: isDark
                                      ? Colors.white.withOpacity(0.05)
                                      : Colors.black.withOpacity(0.05),
                                  strokeWidth: 1,
                                );
                              },
                              getDrawingVerticalLine: (value) {
                                return FlLine(
                                  color: isDark
                                      ? Colors.white.withOpacity(0.05)
                                      : Colors.black.withOpacity(0.05),
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
                                  reservedSize: 32,
                                  getTitlesWidget: (value, meta) {
                                    return Text(
                                      value.toInt().toString(),
                                      style: TextStyle(
                                        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    );
                                  },
                                ),
                              ),
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: 30,
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
                                        padding: const EdgeInsets.only(top: 8.0),
                                        child: Text(
                                          display,
                                          style: TextStyle(
                                            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                                            fontSize: 10,
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
                            borderData: FlBorderData(
                              show: true,
                              border: Border(
                                bottom: BorderSide(
                                  color: isDark ? Colors.white12 : Colors.black12,
                                  width: 1,
                                ),
                                left: BorderSide(
                                  color: isDark ? Colors.white12 : Colors.black12,
                                  width: 1,
                                ),
                              ),
                            ),
                            lineTouchData: LineTouchData(
                              touchTooltipData: LineTouchTooltipData(
                                getTooltipColor: (touchedSpot) => isDark ? AppColors.cardDark : Colors.white,
                                getTooltipItems: (touchedSpots) {
                                  return touchedSpots.map((spot) {
                                    final idx = spot.x.toInt();
                                    final timeStr = idx >= 0 && idx < timeline.length ? timeline[idx]['time'] as String? ?? '' : '';
                                    String display = timeStr;
                                    if (timeStr.contains('T')) {
                                      final timePart = timeStr.split('T').last;
                                      if (timePart.length >= 5) {
                                        display = timePart.substring(0, 5);
                                      }
                                    }
                                    return LineTooltipItem(
                                      '$display\n${spot.y.toInt()} users',
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
                                  colors: [AppColors.primary, AppColors.secondary],
                                ),
                                barWidth: 4,
                                dotData: const FlDotData(show: true),
                                belowBarData: BarAreaData(
                                  show: true,
                                  gradient: LinearGradient(
                                    colors: [
                                      AppColors.primary.withOpacity(0.25),
                                      AppColors.secondary.withOpacity(0.0),
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
                const SizedBox(height: 36),

                // Poll list stats
                Text(
                  'Poll Participation Logs',
                  style: TextStyle(
                    color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 16),
                polls.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            'No polls cast in this session yet',
                            style: TextStyle(
                              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                            ),
                          ),
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: polls.length,
                        itemBuilder: (context, index) {
                          final p = polls[index];
                          final count = p['votesCount'] as int;
                          final type = p['type'] as String;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: isDark ? AppColors.surfaceDark.withOpacity(0.45) : Colors.white,
                              borderRadius: BorderRadius.circular(AppSizes.radiusCard),
                              border: Border.all(
                                color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05),
                              ),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                              leading: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.poll_rounded, color: AppColors.primary, size: 24),
                              ),
                              title: Text(
                                p['title'] as String,
                                style: TextStyle(
                                  color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 4.0),
                                child: Text(
                                  type.replaceAll('_', ' ').toUpperCase(),
                                  style: const TextStyle(
                                    color: AppColors.secondary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                              trailing: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(AppSizes.radiusPill),
                                  border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                                ),
                                child: Text(
                                  '$count votes',
                                  style: const TextStyle(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                const SizedBox(height: 40),

                // Download utilities
                Text(
                  'Data Downloads',
                  style: TextStyle(
                    color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(AppSizes.radiusButton),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withOpacity(0.15),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppSizes.radiusButton),
                            ),
                          ),
                          onPressed: () => _exportCSV('questions'),
                          icon: const Icon(Icons.download_rounded),
                          label: const Text(
                            'Export Questions (CSV)',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(AppSizes.radiusButton),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.secondary.withOpacity(0.15),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            backgroundColor: AppColors.secondary,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppSizes.radiusButton),
                            ),
                          ),
                          onPressed: () => _exportCSV('votes'),
                          icon: const Icon(Icons.download_rounded),
                          label: const Text(
                            'Export Votes (CSV)',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
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
  }

  Widget _buildMetricCard(String label, String value, IconData icon, Color accentColor, List<Color> gradient) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark.withOpacity(0.55) : Colors.white,
        borderRadius: BorderRadius.circular(AppSizes.radiusCard),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05),
        ),
        boxShadow: [
          BoxShadow(
            color: accentColor.withOpacity(isDark ? 0.05 : 0.02),
            blurRadius: 16,
            spreadRadius: 1,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: 5,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: gradient,
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: accentColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(AppSizes.radiusCard),
                  ),
                  child: Icon(icon, color: accentColor, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        value,
                        style: TextStyle(
                          color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -1.0,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        label,
                        style: TextStyle(
                          color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
