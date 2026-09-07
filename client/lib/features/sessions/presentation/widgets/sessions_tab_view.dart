import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../domain/entities/session.dart';
import 'session_card_tile.dart';
import 'session_menu_sheet.dart';

class SessionsTabView extends StatefulWidget {
  final List<Session> sessions;
  final Future<void> Function() onRefresh;

  const SessionsTabView({
    super.key,
    required this.sessions,
    required this.onRefresh,
  });

  @override
  State<SessionsTabView> createState() => _SessionsTabViewState();
}

class _SessionsTabViewState extends State<SessionsTabView> {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _searchFocusNode.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _searchFocusNode.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Widget _buildSessionGroup({
    required String title,
    required int count,
    required List<Session> sessions,
    required Color headerColor,
    required bool isDark,
    bool showGroupHeader = true,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showGroupHeader) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: headerColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: isDark
                        ? Colors.white70
                        : AppColors.textSecondaryLight,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: headerColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$count',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: headerColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
        Container(
          decoration: BoxDecoration(
            color: isDark
                ? AppColors.surfaceDark.withValues(alpha: 0.4)
                : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : const Color(0xFFE2E8F0),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.015),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: sessions.asMap().entries.map((entry) {
              final idx = entry.key;
              final session = entry.value;
              return SessionCardTile(
                session: session,
                index: idx,
                totalCount: sessions.length,
                onTap: () => context.push('/analytics/${session.id}'),
                onMenuTap: () => SessionMenuSheet.show(context, session),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    List<Session> targetSessions = widget.sessions;
    if (_searchQuery.isNotEmpty) {
      targetSessions = widget.sessions.where((s) {
        return s.title.toLowerCase().contains(_searchQuery.toLowerCase());
      }).toList();
    }

    final liveSessions = targetSessions.where((s) => s.isLive).toList();
    final draftSessions = targetSessions.where((s) => s.isDraft).toList();
    final completedSessions = targetSessions.where((s) => s.isEnded).toList();

    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 36),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Sessions',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : AppColors.textPrimaryLight,
                letterSpacing: -0.8,
              ),
            ),
            const SizedBox(height: 16),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 48,
              decoration: BoxDecoration(
                color: isDark
                    ? (_searchFocusNode.hasFocus
                        ? Colors.white.withValues(alpha: 0.07)
                        : Colors.white.withValues(alpha: 0.04))
                    : (_searchFocusNode.hasFocus
                        ? const Color(0xFFF8FAFC)
                        : const Color(0xFFF1F5F9)),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _searchFocusNode.hasFocus
                      ? AppColors.primary.withValues(alpha: 0.45)
                      : (isDark
                          ? Colors.white.withValues(alpha: 0.08)
                          : const Color(0xFFE2E8F0)),
                  width: 1.2,
                ),
                boxShadow: _searchFocusNode.hasFocus
                    ? [
                        BoxShadow(
                          color: AppColors.primary.withValues(
                            alpha: 0.06,
                          ),
                          blurRadius: 8,
                          spreadRadius: 1,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : [],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: TextField(
                  controller: _searchController,
                  focusNode: _searchFocusNode,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white : AppColors.textPrimaryLight,
                  ),
                  onChanged: (val) {
                    setState(() {
                      _searchQuery = val;
                    });
                  },
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 13,
                    ),
                    hintText: 'Search sessions by title...',
                    hintStyle: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.white38 : Colors.grey.shade400,
                    ),
                    prefixIcon: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        Icons.search_rounded,
                        key: ValueKey(_searchFocusNode.hasFocus),
                        size: 20,
                        color: _searchFocusNode.hasFocus
                            ? AppColors.primary
                            : (isDark
                                ? Colors.white38
                                : Colors.grey.shade500),
                      ),
                    ),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            icon: Icon(
                              Icons.clear_rounded,
                              size: 18,
                              color: isDark
                                  ? Colors.white38
                                  : Colors.grey.shade500,
                            ),
                            onPressed: () {
                              setState(() {
                                _searchQuery = '';
                                _searchController.clear();
                              });
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                  ),
                ),
              ),
            ),
            if (_searchQuery.isNotEmpty) ...[
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  children: [
                    const Icon(
                      Icons.filter_list_rounded,
                      size: 14,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Filtering by: "$_searchQuery"',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? Colors.white70
                            : AppColors.textSecondaryLight,
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _searchQuery = '';
                          _searchController.clear();
                        });
                      },
                      child: const Text(
                        'Clear filter',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            if (targetSessions.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Column(
                    children: [
                      Icon(
                        Icons.event_busy_rounded,
                        size: 48,
                        color: Colors.grey.withValues(alpha: 0.4),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _searchQuery.isNotEmpty
                            ? 'No matches found'
                            : 'No sessions yet',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: Colors.grey,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else ...[
              if (liveSessions.isNotEmpty) ...[
                _buildSessionGroup(
                  title: 'Live Sessions',
                  count: liveSessions.length,
                  sessions: liveSessions,
                  headerColor: AppColors.success,
                  isDark: isDark,
                ),
                const SizedBox(height: 16),
              ],
              if (draftSessions.isNotEmpty) ...[
                _buildSessionGroup(
                  title: 'Draft Sessions',
                  count: draftSessions.length,
                  sessions: draftSessions,
                  headerColor: AppColors.primary,
                  isDark: isDark,
                ),
                const SizedBox(height: 16),
              ],
              if (completedSessions.isNotEmpty) ...[
                _buildSessionGroup(
                  title: 'Completed Sessions',
                  count: completedSessions.length,
                  sessions: completedSessions,
                  headerColor: Colors.grey,
                  isDark: isDark,
                  showGroupHeader: true,
                ),
              ],
            ],
          ],
        )
            .animate()
            .fade(duration: 400.ms)
            .slideY(begin: 0.05, end: 0, curve: Curves.easeOutCubic),
      ),
    );
  }
}
