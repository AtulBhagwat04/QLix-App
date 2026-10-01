import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/constants/app_colors.dart';
import '../widgets/legal_section_card.dart';
import '../widgets/profile_app_bar.dart';

class TermsPrivacyScreen extends StatefulWidget {
  const TermsPrivacyScreen({super.key});

  @override
  State<TermsPrivacyScreen> createState() => _TermsPrivacyScreenState();
}

class _TermsPrivacyScreenState extends State<TermsPrivacyScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final cardBorder = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? Colors.white : AppColors.textPrimaryLight;
    final textSub = isDark ? const Color(0xFF94A3B8) : AppColors.textSecondaryLight;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8F9FD),
      appBar: const ProfileAppBar(
        title: 'Terms & Privacy',
        subtitle: 'Legal and data policies',
      ),
      body: Column(
        children: [
          // Segmented Tab Bar Container
          Container(
            margin: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: cardBorder, width: 1),
            ),
            child: TabBar(
              controller: _tabController,
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              indicator: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(10),
              ),
              labelColor: Colors.white,
              unselectedLabelColor: textSub,
              labelStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
              unselectedLabelStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              tabs: const [
                Tab(text: 'Terms of Service'),
                Tab(text: 'Privacy Policy'),
              ],
            ),
          ),

          // Date & Compliance Callout
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Icon(
                  Icons.verified_user_outlined,
                  size: 14,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 6),
                Text(
                  'Effective Date: January 2026 • Version 2.1',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                    color: textSub,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Tab Views
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildTermsTab(textPrimary, textSub, isDark),
                _buildPrivacyTab(textPrimary, textSub, isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTermsTab(Color textPrimary, Color textSub, bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: const [
          LegalSectionCard(
            icon: Icons.gavel_rounded,
            title: '1. Acceptance of Terms',
            badge: 'Binding',
            content:
                'By accessing or using the QLix live audience engagement platform, you agree to comply with and be legally bound by these Terms of Service. If you disagree with any portion, you must cease using our application immediately.',
          ),
          LegalSectionCard(
            icon: Icons.person_pin_rounded,
            title: '2. Host Responsibilities',
            badge: 'Account',
            content:
                'As a session host, you are solely responsible for all content presented during live sessions, including poll questions, quiz choices, and moderated audience Q&A. You agree not to distribute harmful, unlawful, or copyrighted material without appropriate permissions.',
          ),
          LegalSectionCard(
            icon: Icons.copyright_rounded,
            title: '3. Intellectual Property Rights',
            badge: 'Ownership',
            content:
                'You retain full ownership of all custom questions, presentations, and branding assets you upload to QLix. QLix and its underlying code, visual designs, and trademarks remain the exclusive property of the QLix open-source project.',
          ),
          LegalSectionCard(
            icon: Icons.groups_rounded,
            title: '4. Participant Conduct & Fair Use',
            badge: 'Community',
            content:
                'Audience members participating in live polls and interactive sessions must engage respectfully. Hosts hold complete administrative rights to remove participants or moderate submitted questions that violate common decency standards.',
          ),
          LegalSectionCard(
            icon: Icons.cloud_done_rounded,
            title: '5. Service Availability & Termination',
            badge: 'Uptime',
            content:
                'QLix strives for continuous 99.9% uptime. We reserve the right to suspend or restrict access to accounts that engage in abusive network practices or unauthorized automated scraping of our WebSocket servers.',
          ),
        ],
      ).animate().fade(duration: 250.ms),
    );
  }

  Widget _buildPrivacyTab(Color textPrimary, Color textSub, bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: const [
          LegalSectionCard(
            icon: Icons.security_rounded,
            title: '1. Information We Collect',
            badge: 'Encrypted',
            content:
                'We collect minimal host information required for authentication (full name, email address, password hash). Session metrics such as participant counts, poll responses, and quiz timestamps are recorded to provide host analytics.',
          ),
          LegalSectionCard(
            icon: Icons.no_accounts_rounded,
            title: '2. Anonymous Audience Participation',
            badge: 'Zero-Track',
            content:
                'Audience participants do not require accounts. We do not place tracking cookies, collect personal identifiers, or profile participants. Only the chosen display name is temporarily retained for the live leaderboard.',
          ),
          LegalSectionCard(
            icon: Icons.lock_outline_rounded,
            title: '3. Real-Time Data Security',
            badge: 'TLS 1.3',
            content:
                'All WebSocket communications, voting actions, and Q&A streams are encrypted in transit using industry-standard TLS 1.3 protocol. Access tokens are stored on hosts’ devices using secure enclave hardware encryption.',
          ),
          LegalSectionCard(
            icon: Icons.delete_sweep_rounded,
            title: '4. Data Retention & Deletion Rights',
            badge: 'GDPR',
            content:
                'Hosts can export or permanently purge past session records and participant submissions at any time from the Analytics screen. In compliance with GDPR and CCPA, you may request full account data erasure.',
          ),
          LegalSectionCard(
            icon: Icons.mail_outline_rounded,
            title: '5. Privacy Inquiries',
            badge: 'Contact',
            content:
                'If you have any questions or data compliance inquiries, please contact our data privacy team at privacy@qlix.app. We respond to all verified inquiries within 48 business hours.',
          ),
        ],
      ).animate().fade(duration: 250.ms),
    );
  }
}
