import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/qlix_empty_state.dart';
import '../widgets/faq_accordion_item.dart';
import '../widgets/feedback_bottom_sheet.dart';
import '../widgets/profile_app_bar.dart';

class HelpSupportScreen extends StatefulWidget {
  const HelpSupportScreen({super.key});

  @override
  State<HelpSupportScreen> createState() => _HelpSupportScreenState();
}

class _HelpSupportScreenState extends State<HelpSupportScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  final List<Map<String, String>> _allFaqs = const [
    {
      'category': 'Getting Started',
      'question': 'How do I start a live session?',
      'answer':
          'From the Dashboard Home tab, tap "Create Session". Give your session a title, choose your desired features (Polls, Q&A, Quizzes), and tap "Create". Once created, tap "Launch Live Control" to display the access code and QR code for your participants.',
    },
    {
      'category': 'Participants',
      'question': 'Can participants join without an account?',
      'answer':
          'Yes! Participants do not need to register or install an app. They can join by opening the web app on any mobile browser or laptop and entering the 6-character session PIN, or scanning the session QR code.',
    },
    {
      'category': 'Polls & Quizzes',
      'question': 'How are quiz scores and leaderboards calculated?',
      'answer':
          'Participants receive points based on correctness and speed. Fast correct answers earn up to 1,000 points. As the host advances questions, the live leaderboard updates in real time for all participants.',
    },
    {
      'category': 'Q&A Moderation',
      'question': 'Can I moderate questions before they appear live?',
      'answer':
          'Yes. In Session Settings, enable "Q&A Moderation". All incoming participant questions will appear in your host moderation queue where you can approve, answer, or dismiss them before participants can see them.',
    },
    {
      'category': 'Analytics',
      'question': 'Can I export poll and session results to PDF or CSV?',
      'answer':
          'Yes. Open the Analytics tab on any completed or active session, tap "Export Report" in the top bar, and choose between a comprehensive PDF summary or raw CSV data.',
    },
    {
      'category': 'Troubleshooting',
      'question': 'What happens if my connection drops during a session?',
      'answer':
          'QLix uses resilient WebSocket reconnection with local state recovery. As soon as your internet connection is restored, your host control dashboard will automatically reconnect and sync with the session state without losing responses.',
    },
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showFeedbackModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const FeedbackBottomSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final cardBorder = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? Colors.white : AppColors.textPrimaryLight;
    final textSub = isDark ? const Color(0xFF94A3B8) : AppColors.textSecondaryLight;

    final filteredFaqs = _allFaqs.where((faq) {
      if (_searchQuery.isEmpty) return true;
      final q = faq['question']!.toLowerCase();
      final a = faq['answer']!.toLowerCase();
      final cat = faq['category']!.toLowerCase();
      final search = _searchQuery.toLowerCase();
      return q.contains(search) || a.contains(search) || cat.contains(search);
    }).toList();

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8F9FD),
      appBar: const ProfileAppBar(
        title: 'Help & Support',
        subtitle: 'FAQs, guides, and assistance',
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Search Input
            TextField(
              controller: _searchController,
              onChanged: (val) => setState(() => _searchQuery = val.trim()),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                hintText: 'Search help topics and questions...',
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                fillColor: cardBg,
              ),
            ),
            const SizedBox(height: 20),

            // Quick Support Actions Grid
            Row(
              children: [
                Expanded(
                  child: _buildQuickActionCard(
                    icon: Icons.feedback_outlined,
                    label: 'Send Feedback',
                    sub: 'Suggestions',
                    color: const Color(0xFF6366F1),
                    cardBg: cardBg,
                    cardBorder: cardBorder,
                    textPrimary: textPrimary,
                    textSub: textSub,
                    onTap: _showFeedbackModal,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildQuickActionCard(
                    icon: Icons.email_outlined,
                    label: 'Email Support',
                    sub: '24h Response',
                    color: const Color(0xFF10B981),
                    cardBg: cardBg,
                    cardBorder: cardBorder,
                    textPrimary: textPrimary,
                    textSub: textSub,
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Support email: support@qlix.app'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),

            // FAQ Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Frequently Asked Questions',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: textPrimary,
                  ),
                ),
                Text(
                  '${filteredFaqs.length} articles',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: textSub,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // FAQ List
            if (filteredFaqs.isEmpty)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: cardBorder),
                ),
                child: QlixEmptyState.noSearchResults(
                  compact: true,
                  query: _searchQuery,
                  onClearSearch: () {
                    setState(() {
                      _searchController.clear();
                      _searchQuery = '';
                    });
                  },
                ),
              )
            else
              ...filteredFaqs.map(
                (faq) => FaqAccordionItem(
                  question: faq['question']!,
                  answer: faq['answer']!,
                  category: faq['category']!,
                  initialExpanded: filteredFaqs.length == 1,
                ),
              ),
          ],
        ).animate().fade(duration: 350.ms).slideY(begin: 0.03, end: 0),
      ),
    );
  }

  Widget _buildQuickActionCard({
    required IconData icon,
    required String label,
    required String sub,
    required Color color,
    required Color cardBg,
    required Color cardBorder,
    required Color textPrimary,
    required Color textSub,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cardBorder, width: 1),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: textPrimary,
                        ),
                      ),
                      Text(
                        sub,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: textSub,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
