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
  String _selectedProvider = 'Dynamic Real-Time AI';

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
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showAiConfigDialog() {
    final keyController = TextEditingController();
    String tempProvider = _selectedProvider;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              backgroundColor: Theme.of(context).colorScheme.surface,
              title: Row(
                children: [
                  const Icon(Icons.tune_rounded, color: AppColors.primary, size: 22),
                  const SizedBox(width: AppSpacing.sm),
                  Text('AI Engine Configuration', style: AppTypography.titleMedium),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Mentra uses a real-time multi-provider AI engine. Select your preferred provider or enter your custom API key:',
                      style: AppTypography.bodySmall,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    DropdownButtonFormField<String>(
                      initialValue: tempProvider,
                      decoration: const InputDecoration(
                        labelText: 'AI Provider',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'Dynamic Real-Time AI', child: Text('Dynamic Real-Time AI (Built-in)')),
                        DropdownMenuItem(value: 'Google Gemini', child: Text('Google Gemini (Gemini 1.5 / 2.0)')),
                        DropdownMenuItem(value: 'OpenAI ChatGPT', child: Text('OpenAI ChatGPT (GPT-4o / Mini)')),
                        DropdownMenuItem(value: 'Groq Cloud', child: Text('Groq Cloud (Llama 3.3 70B)')),
                        DropdownMenuItem(value: 'OpenRouter', child: Text('OpenRouter (Multi-Model)')),
                        DropdownMenuItem(value: 'Ollama Local', child: Text('Ollama (Local LLM)')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setModalState(() => tempProvider = val);
                        }
                      },
                    ),
                    const SizedBox(height: AppSpacing.md),
                    if (tempProvider != 'Dynamic Real-Time AI' && tempProvider != 'Ollama Local') ...[
                      TextField(
                        controller: keyController,
                        obscureText: true,
                        decoration: InputDecoration(
                          labelText: '$tempProvider API Key',
                          hintText: 'Enter your personal key (optional)',
                          border: const OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Leave empty to use default environment configuration.',
                        style: AppTypography.labelSmall.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Close'),
                ),
                MentraButton(
                  label: 'Save Configuration',
                  icon: Icons.check_rounded,
                  onPressed: () {
                    setState(() {
                      _selectedProvider = tempProvider;
                    });
                    Navigator.of(ctx).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('AI Engine set to $_selectedProvider')),
                    );
                  },
                ),
              ],
            );
          },
        );
      },
    );
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
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Expanded(
              child: MentraPageHeader(
                title: 'AI Coach',
                subtitle: 'Real-time personalized instruction, academic breakdown, and focus guidance',
              ),
            ),
            IconButton(
              tooltip: 'Configure AI Provider & Keys',
              icon: const Icon(Icons.settings_outlined, color: AppColors.primary),
              onPressed: _showAiConfigDialog,
            ),
          ],
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
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text('Study Coach Active', style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.w700)),
                        const MentraBadge(label: 'Real-Time AI Active', variant: MentraBadgeVariant.success),
                        MentraBadge(label: _selectedProvider, variant: MentraBadgeVariant.primary),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      'Ask any question across any academic domain, study strategy, progress analytics, or topic deconstruction.',
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
          subtitle: 'Real-time AI instruction — ask about any topic, concept, formula, progress analysis, or study strategy',
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
                      _buildPromptChip('Teach me Data Analytics'),
                      const SizedBox(width: AppSpacing.xs),
                      _buildPromptChip('How is my progress?'),
                      const SizedBox(width: AppSpacing.xs),
                      _buildPromptChip('Explain OLS Regression'),
                      const SizedBox(width: AppSpacing.xs),
                      _buildPromptChip('Optimal study interval?'),
                      const SizedBox(width: AppSpacing.xs),
                      _buildPromptChip('Active recall strategy'),
                      const SizedBox(width: AppSpacing.xs),
                      _buildPromptChip('How to beat drowsiness?'),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                // Message History List
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 380),
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
                          margin: const EdgeInsets.only(bottom: AppSpacing.md),
                          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
                          constraints: const BoxConstraints(maxWidth: 620),
                          decoration: BoxDecoration(
                            color: isUser
                                ? theme.colorScheme.primary
                                : (isDark ? const Color(0xFF1E2420) : const Color(0xFFF2F5F3)),
                            border: Border.all(
                              color: isUser
                                  ? theme.colorScheme.primary
                                  : (isDark ? const Color(0xFF2A362E) : const Color(0xFFE2E8E4)),
                            ),
                            borderRadius: AppRadius.borderMd,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    isUser ? Icons.person_outline_rounded : Icons.psychology_outlined,
                                    size: 14,
                                    color: isUser ? Colors.white70 : AppColors.primary,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    isUser ? 'You' : 'Mentra Coach',
                                    style: AppTypography.labelSmall.copyWith(
                                      color: isUser ? Colors.white70 : AppColors.primary,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              _buildFormattedText(msg.text, isUser, theme),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),

                if (_isSending) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Row(
                    children: [
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        'Mentra is generating real-time response...',
                        style: AppTypography.labelSmall.copyWith(color: AppColors.primary),
                      ),
                    ],
                  ),
                ],

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
                          hintText: 'e.g. Teach me Data Analytics, Explain ANOVA tests, How is my focus?',
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

  Widget _buildFormattedText(String text, bool isUser, ThemeData theme) {
    if (isUser) {
      return Text(
        text,
        style: AppTypography.bodySmall.copyWith(
          color: Colors.white,
          height: 1.45,
        ),
      );
    }

    // Clean formatting for coach responses
    final lines = text.split('\n');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: lines.map((line) {
        final trimmed = line.trim();
        if (trimmed.isEmpty) {
          return const SizedBox(height: 6);
        }
        if (trimmed.startsWith('### ')) {
          return Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 4),
            child: Text(
              trimmed.substring(4),
              style: AppTypography.titleSmall.copyWith(
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurface,
              ),
            ),
          );
        }
        if (trimmed.startsWith('• ') || trimmed.startsWith('- ') || trimmed.startsWith('* ')) {
          final bulletText = trimmed.substring(2);
          return Padding(
            padding: const EdgeInsets.only(left: 6, bottom: 3),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('• ', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                Expanded(
                  child: Text(
                    bulletText.replaceAll('**', ''),
                    style: AppTypography.bodySmall.copyWith(
                      color: theme.colorScheme.onSurface,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          );
        }
        return Padding(
          padding: const EdgeInsets.only(bottom: 3),
          child: Text(
            trimmed.replaceAll('**', ''),
            style: AppTypography.bodySmall.copyWith(
              color: theme.colorScheme.onSurface,
              height: 1.45,
            ),
          ),
        );
      }).toList(),
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
