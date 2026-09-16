import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/mentra_badge.dart';
import '../../../shared/widgets/mentra_button.dart';
import '../../../shared/widgets/mentra_card.dart';
import '../../../shared/widgets/mentra_page_header.dart';
import '../../../shared/widgets/mentra_section.dart';
import '../domain/models/coach_insight.dart';
import '../domain/repositories/ai_coach_repository.dart';

class AiCoachPage extends StatefulWidget {
  const AiCoachPage({
    super.key,
    required this.aiCoachRepository,
  });

  final AiCoachRepository aiCoachRepository;

  @override
  State<AiCoachPage> createState() => _AiCoachPageState();
}

class _AiCoachPageState extends State<AiCoachPage> {
  List<CoachInsightModel> _insights = [];
  List<ChatMessage> _messages = [];
  final TextEditingController _queryController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = true;
  bool _isSending = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadCoachData();
  }

  @override
  void dispose() {
    _queryController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadCoachData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final insights = await widget.aiCoachRepository.getCoachInsights();
      final chat = await widget.aiCoachRepository.getInitialChatHistory();
      if (!mounted) return;
      setState(() {
        _insights = insights;
        _messages = chat;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Unable to load coaching data. Tap retry to reload.';
        _isLoading = false;
      });
    }
  }

  Future<void> _sendQuestion([String? promptText]) async {
    final text = (promptText ?? _queryController.text).trim();
    if (text.isEmpty || _isSending) return;

    if (promptText == null) {
      _queryController.clear();
    }

    final userMsg = ChatMessage(
      id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
      sender: 'user',
      text: text,
      timestamp: DateTime.now(),
    );

    setState(() {
      _messages.add(userMsg);
      _isSending = true;
    });

    _scrollToBottom();

    try {
      final reply = await widget.aiCoachRepository.askCoachQuestion(text);
      if (!mounted) return;
      setState(() {
        _messages.add(reply);
        _isSending = false;
      });
      _scrollToBottom();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _messages.add(
          ChatMessage(
            id: 'err_${DateTime.now().millisecondsSinceEpoch}',
            sender: 'coach',
            text: 'I am temporarily unable to reach the coaching engine. Using local focus heuristics.',
            timestamp: DateTime.now(),
          ),
        );
        _isSending = false;
      });
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.xxl),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_errorMessage!, style: AppTypography.bodyMedium),
            const SizedBox(height: AppSpacing.md),
            MentraButton(
              label: 'Retry',
              icon: Icons.refresh_rounded,
              onPressed: _loadCoachData,
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const MentraPageHeader(
          title: 'AI Coach',
          subtitle: 'Personalized study patterns, behavioral coaching, and adaptive recommendations',
        ),

        // Personalized Coach Greeting Banner
        MentraCard(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: isDark ? 0.2 : 0.1),
                  borderRadius: AppRadius.borderMd,
                ),
                child: const Icon(Icons.psychology_outlined, color: AppColors.accent, size: 26),
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text('Study Coach Active', style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.w700)),
                        const SizedBox(width: AppSpacing.sm),
                        const MentraBadge(label: 'Behavioral Insights', variant: MentraBadgeVariant.primary),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      'I analyzed your completed study history. Your peak focus retention occurs during 45-minute morning sessions.',
                      style: AppTypography.bodySmall.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: AppSpacing.xl),

        // Behavioral Insights Cards
        MentraSection(
          title: 'Focus Patterns & Recommendations',
          subtitle: 'Synthesized observations derived from your study telemetry',
          child: Column(
            children: _insights.map((insight) {
              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: MentraCard(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          MentraBadge(label: insight.category, variant: MentraBadgeVariant.neutral),
                          Text(
                            insight.impactMetric,
                            style: AppTypography.labelSmall.copyWith(
                              color: AppColors.success,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        insight.title,
                        style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        insight.summary,
                        style: AppTypography.bodySmall.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF222222) : const Color(0xFFF2F2F0),
                          borderRadius: AppRadius.borderSm,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.lightbulb_outline_rounded, size: 16, color: Colors.amber),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Text(
                                insight.actionRecommendation,
                                style: AppTypography.bodySmall.copyWith(fontWeight: FontWeight.w500),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),

        const SizedBox(height: AppSpacing.xl),

        // Interactive "Ask Mentra" Study Chat Workspace
        MentraSection(
          title: 'Ask Mentra',
          subtitle: 'Ask questions about your study schedule, topic difficulty, or focus tactics',
          child: MentraCard(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Quick Suggestion Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildPromptChip('Optimal study interval?'),
                      const SizedBox(width: AppSpacing.xs),
                      _buildPromptChip('Active recall strategy'),
                      const SizedBox(width: AppSpacing.xs),
                      _buildPromptChip('How to eliminate phone distraction?'),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                // Message History List
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 260),
                  child: ListView.builder(
                    controller: _scrollController,
                    shrinkWrap: true,
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final msg = _messages[index];
                      final isUser = msg.sender == 'user';
                      return Align(
                        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                          constraints: const BoxConstraints(maxWidth: 480),
                          decoration: BoxDecoration(
                            color: isUser
                                ? theme.colorScheme.primary
                                : (isDark ? const Color(0xFF222222) : const Color(0xFFF2F2F0)),
                            borderRadius: AppRadius.borderMd,
                          ),
                          child: Text(
                            msg.text,
                            style: AppTypography.bodySmall.copyWith(
                              color: isUser ? Colors.white : theme.colorScheme.onSurface,
                              height: 1.4,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),

                const SizedBox(height: AppSpacing.md),
                Divider(color: theme.dividerColor, height: 1),
                const SizedBox(height: AppSpacing.md),

                // Query Input Bar
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _queryController,
                        onSubmitted: (_) => _sendQuestion(),
                        decoration: InputDecoration(
                          hintText: 'e.g. How should I structure my revision for Data Analytics?',
                          hintStyle: AppTypography.bodySmall.copyWith(
                            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                          ),
                          filled: true,
                          fillColor: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF9F9F8),
                          contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 12),
                          border: OutlineInputBorder(
                            borderRadius: AppRadius.borderSm,
                            borderSide: BorderSide(color: theme.dividerColor),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: AppRadius.borderSm,
                            borderSide: BorderSide(color: theme.dividerColor),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    MentraButton(
                      label: 'Send',
                      icon: Icons.send_rounded,
                      isLoading: _isSending,
                      onPressed: _sendQuestion,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPromptChip(String label) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return ActionChip(
      label: Text(label, style: AppTypography.labelSmall.copyWith(fontSize: 11)),
      backgroundColor: isDark ? const Color(0xFF222222) : const Color(0xFFEFEFEF),
      side: BorderSide(color: theme.dividerColor),
      onPressed: () => _sendQuestion(label),
    );
  }
}
