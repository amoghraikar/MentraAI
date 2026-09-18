import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

enum CoachGptPersona {
  conceptTutor(
    label: 'Master Tutor',
    icon: Icons.school_rounded,
    description: 'First-principles breakdown, intuitive analogies, and step-by-step derivations',
    prompts: [
      'Optimal study interval?',
      'Active recall strategy',
      'How to eliminate phone distraction?',
      'Teach me Data Analytics',
      'Explain OLS Regression',
      'What is Gradient Descent?',
    ],
  ),
  activeQuizzer(
    label: 'Active Quizzer',
    icon: Icons.quiz_rounded,
    description: 'Active recall drills, retrieval practice questions, and formula tests',
    prompts: [
      'Quiz me on Data Analytics',
      'Test my understanding of ANOVA',
      'Active recall questions on ML',
      'Flash quiz on study methods',
    ],
  ),
  studyArchitect(
    label: 'Study Architect',
    icon: Icons.calendar_month_rounded,
    description: 'Day-by-day revision timetables, Pomodoro pacing, and milestone roadmaps',
    prompts: [
      'Create a 7-day study plan',
      'Optimal study interval?',
      'How to structure 2-hour revision block',
      'Exam preparation schedule',
    ],
  ),
  focusMindset(
    label: 'Focus & Mindset',
    icon: Icons.self_improvement_rounded,
    description: 'Anti-distraction tactics, phone friction boundaries, and fatigue resets',
    prompts: [
      'How to eliminate phone distraction?',
      'How to beat drowsiness?',
      'Overcoming study procrastination',
      'The 20-20-20 visual reset technique',
    ],
  ),
  progressAnalyst(
    label: 'Progress Analyst',
    icon: Icons.insights_rounded,
    description: 'Live database telemetry analysis, focus health score, and retention trends',
    prompts: [
      'How is my progress?',
      'Analyze my focus baseline',
      'Evaluate my study consistency',
      'What topic should I study next?',
    ],
  );

  const CoachGptPersona({
    required this.label,
    required this.icon,
    required this.description,
    required this.prompts,
  });

  final String label;
  final IconData icon;
  final String description;
  final List<String> prompts;
}

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

  // Custom GPT Configuration
  String _selectedProvider = 'openai';
  String _customApiKey = '';
  String _customModel = 'gpt-4o-mini';
  String _customSystemPrompt = '';
  String _customEndpointUrl = '';
  CoachGptPersona _selectedPersona = CoachGptPersona.conceptTutor;

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
      final reply = await widget.aiCoachRepository.askCoachQuestion(
        text,
        history: _messages,
        provider: _selectedProvider,
        apiKey: _customApiKey,
        model: _customModel,
        customSystemPrompt: _customSystemPrompt.isNotEmpty ? _customSystemPrompt : null,
        customEndpointUrl: _customEndpointUrl.isNotEmpty ? _customEndpointUrl : null,
      );
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
            text: 'I am temporarily unable to reach the AI engine. Please verify your internet connection or API Key.',
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

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Copied response to clipboard'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _clearChatHistory() {
    setState(() {
      _messages = [
        ChatMessage(
          id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
          sender: 'coach',
          text: 'New session initialized with **${_selectedPersona.label} GPT**. Ask any question to begin!',
          timestamp: DateTime.now(),
        ),
      ];
    });
  }

  void _showAiConfigDialog() {
    final keyController = TextEditingController(text: _customApiKey);
    final modelController = TextEditingController(text: _customModel);
    final promptController = TextEditingController(text: _customSystemPrompt);
    final endpointController = TextEditingController(text: _customEndpointUrl);
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
                  const Icon(Icons.psychology_outlined, color: AppColors.primary, size: 22),
                  const SizedBox(width: AppSpacing.sm),
                  Text('Custom Study GPT Setup', style: AppTypography.titleMedium),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Connect your own GPT model, API key, or custom LLM endpoint to power your study assistant with zero preset limits:',
                      style: AppTypography.bodySmall,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    DropdownButtonFormField<String>(
                      initialValue: tempProvider,
                      decoration: const InputDecoration(
                        labelText: 'GPT Engine / LLM Provider',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'openai', child: Text('OpenAI ChatGPT (GPT-4o / GPT-4o-mini)')),
                        DropdownMenuItem(value: 'gemini', child: Text('Google Gemini (Gemini 1.5 / 2.0)')),
                        DropdownMenuItem(value: 'groq', child: Text('Groq Cloud (Llama 3.3 70B)')),
                        DropdownMenuItem(value: 'openrouter', child: Text('OpenRouter (Claude, DeepSeek, Llama)')),
                        DropdownMenuItem(value: 'ollama', child: Text('Ollama (Local Offline LLM)')),
                        DropdownMenuItem(value: 'custom', child: Text('Custom OpenAI-Compatible API')),
                        DropdownMenuItem(value: 'cognitive', child: Text('Mentra Dynamic Real-Time AI')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setModalState(() {
                            tempProvider = val;
                            if (val == 'openai') modelController.text = 'gpt-4o-mini';
                            if (val == 'gemini') modelController.text = 'gemini-1.5-flash';
                            if (val == 'groq') modelController.text = 'llama-3.3-70b-versatile';
                            if (val == 'openrouter') modelController.text = 'meta-llama/llama-3.3-70b-instruct:free';
                            if (val == 'ollama') modelController.text = 'llama3';
                          });
                        }
                      },
                    ),
                    const SizedBox(height: AppSpacing.md),
                    if (tempProvider != 'cognitive' && tempProvider != 'ollama') ...[
                      TextField(
                        controller: keyController,
                        obscureText: true,
                        decoration: InputDecoration(
                          labelText: '${tempProvider.toUpperCase()} API Key',
                          hintText: 'Enter your API key (e.g. sk-...)',
                          border: const OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                    ],
                    if (tempProvider == 'custom' || tempProvider == 'ollama') ...[
                      TextField(
                        controller: endpointController,
                        decoration: const InputDecoration(
                          labelText: 'Base Endpoint URL',
                          hintText: 'e.g. http://localhost:11434/v1 or https://api.together.xyz/v1',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                    ],
                    TextField(
                      controller: modelController,
                      decoration: const InputDecoration(
                        labelText: 'Model Identifier',
                        hintText: 'e.g. gpt-4o, gemini-1.5-pro, llama-3.3-70b',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextField(
                      controller: promptController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Custom System Instructions (Optional)',
                        hintText: 'e.g. You are a strict Harvard professor, answer concisely with step-by-step math.',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Cancel'),
                ),
                MentraButton(
                  label: 'Connect & Save GPT',
                  icon: Icons.check_rounded,
                  onPressed: () {
                    setState(() {
                      _selectedProvider = tempProvider;
                      _customApiKey = keyController.text.trim();
                      _customModel = modelController.text.trim();
                      _customSystemPrompt = promptController.text.trim();
                      _customEndpointUrl = endpointController.text.trim();
                    });
                    Navigator.of(ctx).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Connected to $_selectedProvider (${_customModel.isNotEmpty ? _customModel : "default"})')),
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
                subtitle: 'Study Coach GPT — real-time instruction, concept breakdown, active quizzes, and focus coaching',
              ),
            ),
            MentraButton(
              label: 'GPT Settings & Key',
              icon: Icons.tune_rounded,
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
                        const MentraBadge(label: 'Real-Time GPT Active', variant: MentraBadgeVariant.success),
                        MentraBadge(
                          label: '${_selectedProvider.toUpperCase()} (${_customModel.isNotEmpty ? _customModel : "live"})',
                          variant: MentraBadgeVariant.primary,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      'Ask any custom question, request active recall quizzes, or configure your own model in GPT Settings.',
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
          subtitle: 'Study Coach GPT Workspace — live multi-turn conversations powered by your configured GPT model',
          child: MentraCard(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Persona Selector Tabs
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: CoachGptPersona.values.map((persona) {
                      final isSelected = _selectedPersona == persona;
                      return Padding(
                        padding: const EdgeInsets.only(right: AppSpacing.xs),
                        child: FilterChip(
                          selected: isSelected,
                          avatar: Icon(
                            persona.icon,
                            size: 16,
                            color: isSelected ? Colors.white : AppColors.primary,
                          ),
                          label: Text(persona.label),
                          labelStyle: AppTypography.labelSmall.copyWith(
                            color: isSelected ? Colors.white : theme.colorScheme.onSurface,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.normal,
                          ),
                          selectedColor: AppColors.primary,
                          backgroundColor: isDark ? const Color(0xFF1E2420) : const Color(0xFFF0F4F2),
                          side: BorderSide(
                            color: isSelected ? AppColors.primary : theme.dividerColor,
                          ),
                          onSelected: (_) {
                            setState(() {
                              _selectedPersona = persona;
                            });
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  _selectedPersona.description,
                  style: AppTypography.labelSmall.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                // Quick Suggestion Chips for Selected Persona
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _selectedPersona.prompts.map((p) {
                      return Padding(
                        padding: const EdgeInsets.only(right: AppSpacing.xs),
                        child: _buildPromptChip(p),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                // Header with Clear Chat action
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Live Conversation Session',
                      style: AppTypography.labelSmall.copyWith(
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    TextButton.icon(
                      icon: const Icon(Icons.refresh_rounded, size: 14),
                      label: Text('New Chat', style: AppTypography.labelSmall),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: _clearChatHistory,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),

                // Message History List
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 420),
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
                          constraints: const BoxConstraints(maxWidth: 640),
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
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        isUser ? Icons.person_outline_rounded : _selectedPersona.icon,
                                        size: 14,
                                        color: isUser ? Colors.white70 : AppColors.primary,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        isUser ? 'You' : 'Mentra ${_selectedPersona.label}',
                                        style: AppTypography.labelSmall.copyWith(
                                          color: isUser ? Colors.white70 : AppColors.primary,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (!isUser)
                                    IconButton(
                                      icon: const Icon(Icons.copy_rounded, size: 14),
                                      tooltip: 'Copy response',
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      color: theme.colorScheme.onSurfaceVariant,
                                      onPressed: () => _copyToClipboard(msg.text),
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
                        'Mentra GPT is generating response...',
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
                          hintText: 'Ask ${_selectedPersona.label} anything (e.g. teach me, quiz me, explain math formula)...',
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
                const Text('• ', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
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
