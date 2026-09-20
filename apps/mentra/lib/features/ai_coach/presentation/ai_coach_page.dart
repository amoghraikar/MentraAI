import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/mentra_badge.dart';
import '../domain/models/coach_insight.dart';
import '../domain/repositories/ai_coach_repository.dart';
import 'widgets/chat_history_drawer.dart';
import 'widgets/markdown_message_view.dart';
import 'widgets/mentra_ai_avatar.dart';

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
  final TextEditingController _queryController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _inputFocusNode = FocusNode();

  List<ChatMessage> _messages = [];
  List<ChatMessage> _fullHistory = [];

  bool _isLoading = true;
  bool _isGenerating = false;
  String? _errorMessage;

  // Local Canonical Model State
  String _modelState = 'READY'; // UNINITIALIZED, LOADING, READY, GENERATING, STOPPING, ERROR
  String _currentStreamBuffer = '';
  StreamSubscription<String>? _activeStreamSubscription;

  // 4 Starter actions matching Milestone 3
  static const List<String> _starterPrompts = [
    'Explain a topic',
    'Quiz me',
    'Help me understand',
    'Practice',
  ];

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _activeStreamSubscription?.cancel();
    _queryController.dispose();
    _scrollController.dispose();
    _inputFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final statusFuture = widget.aiCoachRepository.getModelStatus();
      final historyFuture = widget.aiCoachRepository.getInitialChatHistory();

      final results = await Future.wait([statusFuture, historyFuture]);

      if (!mounted) return;
      final status = results[0] as Map<String, dynamic>;
      final rawState = (status['state'] as String? ?? 'READY').toUpperCase();

      setState(() {
        _modelState = rawState;
        _fullHistory = results[1] as List<ChatMessage>;
        _messages = [];
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _modelState = 'READY';
        _errorMessage = null;
        _messages = [];
      });
    }
  }

  Future<void> _sendQuestion([String? promptText]) async {
    final text = (promptText ?? _queryController.text).trim();
    if (text.isEmpty || _isGenerating) return;

    if (promptText == null) {
      _queryController.clear();
    }

    final userMsg = ChatMessage(
      id: 'usr_${DateTime.now().millisecondsSinceEpoch}',
      sender: 'user',
      text: text,
      timestamp: DateTime.now(),
    );

    setState(() {
      _messages.add(userMsg);
      _fullHistory.add(userMsg);
      _isGenerating = true;
      _modelState = 'GENERATING';
      _currentStreamBuffer = '';
      _errorMessage = null;
    });

    _scrollToBottom();

    final coachMsgId = 'coach_${DateTime.now().millisecondsSinceEpoch}';
    final coachPlaceholder = ChatMessage(
      id: coachMsgId,
      sender: 'coach',
      text: '',
      timestamp: DateTime.now(),
    );

    setState(() {
      _messages.add(coachPlaceholder);
    });

    try {
      final stream = widget.aiCoachRepository.streamCoachQuestion(
        text,
        history: _messages.sublist(0, _messages.length - 1),
      );

      _activeStreamSubscription = stream.listen(
        (chunk) {
          if (!mounted) return;
          setState(() {
            _currentStreamBuffer += chunk;
            final idx = _messages.indexWhere((m) => m.id == coachMsgId);
            if (idx != -1) {
              _messages[idx] = ChatMessage(
                id: coachMsgId,
                sender: 'coach',
                text: _currentStreamBuffer,
                timestamp: coachPlaceholder.timestamp,
              );
            }
          });
          _scrollToBottom();
        },
        onError: (err) async {
          if (!mounted) return;
          final idx = _messages.indexWhere((m) => m.id == coachMsgId);
          if (idx != -1 && _messages[idx].text.isEmpty) {
            try {
              final fallback = await widget.aiCoachRepository.askCoachQuestion(
                text,
                history: _messages.sublist(0, _messages.length - 1),
              );
              if (!mounted) return;
              setState(() {
                _isGenerating = false;
                _modelState = 'READY';
                _messages[idx] = fallback;
                _fullHistory.add(fallback);
              });
              _scrollToBottom();
              return;
            } catch (_) {}
          }
          if (!mounted) return;
          setState(() {
            _isGenerating = false;
            _modelState = 'READY';
          });
        },
        onDone: () {
          if (!mounted) return;
          setState(() {
            _isGenerating = false;
            _modelState = 'READY';
            final idx = _messages.indexWhere((m) => m.id == coachMsgId);
            if (idx != -1) {
              _fullHistory.add(_messages[idx]);
            }
          });
          _scrollToBottom();
        },
        cancelOnError: true,
      );
    } catch (_) {
      if (!mounted) return;
      final idx = _messages.indexWhere((m) => m.id == coachMsgId);
      try {
        final fallback = await widget.aiCoachRepository.askCoachQuestion(
          text,
          history: _messages.where((m) => m.id != coachMsgId).toList(),
        );
        if (!mounted) return;
        setState(() {
          _isGenerating = false;
          _modelState = 'READY';
          if (idx != -1) {
            _messages[idx] = fallback;
            _fullHistory.add(fallback);
          } else {
            _messages.add(fallback);
          }
        });
        _scrollToBottom();
      } catch (_) {
        if (!mounted) return;
        setState(() {
          _isGenerating = false;
          _modelState = 'READY';
        });
      }
    }
  }

  Future<void> _stopGeneration() async {
    setState(() {
      _modelState = 'STOPPING';
    });

    await _activeStreamSubscription?.cancel();
    _activeStreamSubscription = null;

    try {
      await widget.aiCoachRepository.cancelGeneration();
    } catch (_) {}

    if (mounted) {
      setState(() {
        _isGenerating = false;
        _modelState = 'READY';
      });
      _scrollToBottom();
    }
  }

  void _startNewChat() {
    _activeStreamSubscription?.cancel();
    _activeStreamSubscription = null;
    setState(() {
      _messages.clear();
      _isGenerating = false;
      _modelState = 'READY';
      _currentStreamBuffer = '';
      _errorMessage = null;
    });
    _queryController.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_isGenerating && !_isLoading) {
        _inputFocusNode.requestFocus();
      }
    });
  }

  Future<void> _clearChatHistory() async {
    _startNewChat();
    setState(() {
      _fullHistory.clear();
    });
    await widget.aiCoachRepository.clearChatHistory();
  }

  void _openChatHistory() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => FractionallySizedBox(
        heightFactor: 0.85,
        child: ChatHistoryDrawer(
          messages: _fullHistory,
          onSelectMessage: (msg) {
            _sendQuestion(msg.text);
          },
          onNewChat: _startNewChat,
          onClearHistory: _clearChatHistory,
        ),
      ),
    );
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
    if (_isLoading) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const MentraAiAvatar(size: 48, isGenerating: true),
              const SizedBox(height: AppSpacing.lg),
              const CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2.5),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Preparing your study coach...',
                style: AppTypography.titleSmall.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isMobile = MediaQuery.of(context).size.width < 768;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isBounded = constraints.hasBoundedHeight;

        final conversationContent = _messages.isEmpty
            ? _buildEmptyState(theme, isDark, isMobile, isBounded)
            : _buildConversationView(theme, isDark, isMobile, isBounded);

        return Container(
          color: theme.scaffoldBackgroundColor,
          child: Column(
            children: [
              // Header Bar
              _buildHeaderBar(theme, isDark, isMobile),

              if (_errorMessage != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 8),
                  color: AppColors.error.withValues(alpha: 0.1),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded, size: 16, color: AppColors.error),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: AppTypography.bodySmall.copyWith(color: AppColors.error),
                        ),
                      ),
                      TextButton(
                        onPressed: _loadInitialData,
                        child: const Text('Retry', style: TextStyle(color: AppColors.error)),
                      ),
                    ],
                  ),
                ),

              const Divider(height: 1),

              // Conversation View or Empty State
              if (isBounded)
                Expanded(child: conversationContent)
              else
                conversationContent,

              // Bottom Composer
              _buildComposer(theme, isDark, isMobile),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeaderBar(ThemeData theme, bool isDark, bool isMobile) {
    String badgeLabel;
    MentraBadgeVariant badgeVariant;

    switch (_modelState) {
      case 'LOADING':
      case 'UNINITIALIZED':
        badgeLabel = 'Preparing Mentra...';
        badgeVariant = MentraBadgeVariant.neutral;
        break;
      case 'ERROR':
        badgeLabel = "Mentra AI couldn't start";
        badgeVariant = MentraBadgeVariant.danger;
        break;
      case 'GENERATING':
        badgeLabel = 'Thinking...';
        badgeVariant = MentraBadgeVariant.primary;
        break;
      case 'READY':
      default:
        badgeLabel = 'Mentra AI ready';
        badgeVariant = MentraBadgeVariant.success;
        break;
    }

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? AppSpacing.md : AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      color: theme.colorScheme.surface,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Brand Title
          Expanded(
            child: Row(
              children: [
                MentraAiAvatar(size: 34, isGenerating: _isGenerating),
                const SizedBox(width: AppSpacing.sm),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'MENTRA',
                        style: AppTypography.titleMedium.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.0,
                        ),
                      ),
                      Text(
                        'Your personal AI study coach',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.labelSmall.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Actions
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              MentraBadge(
                label: badgeLabel,
                variant: badgeVariant,
              ),
              const SizedBox(width: AppSpacing.xs),
              IconButton(
                tooltip: 'Chat History',
                icon: const Icon(Icons.history_rounded, size: 20),
                onPressed: _openChatHistory,
              ),
              const SizedBox(width: AppSpacing.xs),
              ElevatedButton.icon(
                onPressed: _startNewChat,
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('New Chat'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  textStyle: AppTypography.labelMedium.copyWith(fontWeight: FontWeight.w600),
                  shape: RoundedRectangleBorder(borderRadius: AppRadius.borderSm),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme, bool isDark, bool isMobile, bool isBounded) {
    final body = Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: AppSpacing.xxl),

            // Mentra Identity Avatar
            const MentraAiAvatar(size: 64),
            const SizedBox(height: AppSpacing.lg),

            // Headline & Description
            Text(
              'Learn something today.',
              textAlign: TextAlign.center,
              style: AppTypography.displayMedium.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Ask Mentra anything about your studies.',
              textAlign: TextAlign.center,
              style: AppTypography.bodyMedium.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),

            const SizedBox(height: AppSpacing.xl),

            // 4 Starter Action Prompts
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              alignment: WrapAlignment.center,
              children: _starterPrompts.map((prompt) {
                return ActionChip(
                  label: Text(
                    prompt,
                    style: AppTypography.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  backgroundColor: isDark ? const Color(0xFF1E1E22) : const Color(0xFFF1F5F9),
                  side: BorderSide(
                    color: isDark ? const Color(0xFF2E2E34) : const Color(0xFFE2E8F0),
                  ),
                  shape: RoundedRectangleBorder(borderRadius: AppRadius.borderMd),
                  onPressed: () => _sendQuestion(prompt),
                );
              }).toList(),
            ),

            const SizedBox(height: AppSpacing.xxl),
          ],
        ),
      ),
    );

    if (isBounded) {
      return SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? AppSpacing.md : AppSpacing.xl,
          vertical: AppSpacing.md,
        ),
        child: body,
      );
    }
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? AppSpacing.md : AppSpacing.xl,
        vertical: AppSpacing.md,
      ),
      child: body,
    );
  }

  Widget _buildConversationView(ThemeData theme, bool isDark, bool isMobile, bool isBounded) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: ListView.builder(
          controller: _scrollController,
          shrinkWrap: !isBounded,
          physics: isBounded ? null : const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.symmetric(
            horizontal: isMobile ? AppSpacing.md : AppSpacing.lg,
            vertical: AppSpacing.lg,
          ),
          itemCount: _messages.length,
          itemBuilder: (context, index) {
            final msg = _messages[index];
            final isUser = msg.sender == 'user';
            final isLastMsg = index == _messages.length - 1;
            final isCurrentlyStreaming = isLastMsg && !isUser && _isGenerating;

            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xl),
              child: isUser
                  ? _buildUserMessage(msg, theme, isDark)
                  : _buildCoachMessage(msg, theme, isDark, isCurrentlyStreaming),
            );
          },
        ),
      ),
    );
  }

  Widget _buildUserMessage(ChatMessage msg, ThemeData theme, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(width: 48),
        Flexible(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(4),
                bottomLeft: const Radius.circular(16),
                bottomRight: const Radius.circular(16),
              ),
            ),
            child: Text(
              msg.text,
              style: AppTypography.bodyMedium.copyWith(
                color: Colors.white,
                height: 1.45,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCoachMessage(ChatMessage msg, ThemeData theme, bool isDark, bool isStreaming) {
    final isError = msg.text.contains("Mentra couldn't generate a response");

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MentraAiAvatar(size: 32, isGenerating: isStreaming),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Text(
                    'MENTRA',
                    style: AppTypography.labelMedium.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                      color: AppColors.primary,
                    ),
                  ),
                  if (isStreaming) ...[
                    const SizedBox(width: AppSpacing.sm),
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 6),

              // Content or Typing Indicator
              if (msg.text.isEmpty && isStreaming)
                Row(
                  children: [
                    Text(
                      'Mentra is thinking...',
                      style: AppTypography.bodySmall.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                )
              else
                MarkdownMessageView(
                  content: msg.text,
                  isUser: false,
                ),

              // Error Retry Action
              if (isError) ...[
                const SizedBox(height: AppSpacing.sm),
                TextButton.icon(
                  onPressed: () {
                    final lastUserMsg = _messages.reversed.firstWhere(
                      (m) => m.sender == 'user',
                      orElse: () => ChatMessage(id: '', sender: '', text: '', timestamp: DateTime.now()),
                    );
                    if (lastUserMsg.text.isNotEmpty) {
                      _sendQuestion(lastUserMsg.text);
                    }
                  },
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: const Text('Retry'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildComposer(ThemeData theme, bool isDark, bool isMobile) {
    final canSend = _queryController.text.trim().isNotEmpty && !_isGenerating && !_isLoading;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? AppSpacing.md : AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(color: theme.dividerColor.withValues(alpha: 0.6)),
        ),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              GestureDetector(
                onTap: () {
                  if (!_isGenerating && !_isLoading) {
                    _inputFocusNode.requestFocus();
                  }
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E1E22) : const Color(0xFFF8FAFC),
                    borderRadius: AppRadius.borderMd,
                    border: Border.all(
                      color: isDark ? const Color(0xFF2E2E34) : const Color(0xFFE2E8F0),
                      width: 1,
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // Multiline Text Field (Enter to send, Shift+Enter for newline)
                      Expanded(
                        child: CallbackShortcuts(
                          bindings: {
                            const SingleActivator(LogicalKeyboardKey.enter): () {
                              if (!_isGenerating && _queryController.text.trim().isNotEmpty) {
                                _sendQuestion();
                              }
                            },
                          },
                          child: TextField(
                            controller: _queryController,
                            focusNode: _inputFocusNode,
                            readOnly: _isGenerating || _isLoading,
                            maxLines: 5,
                            minLines: 1,
                            keyboardType: TextInputType.multiline,
                            textInputAction: TextInputAction.newline,
                            style: AppTypography.bodyMedium,
                            decoration: InputDecoration(
                              hintText: 'Ask Mentra anything...',
                              hintStyle: AppTypography.bodyMedium.copyWith(
                                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                            onChanged: (_) {
                              setState(() {});
                            },
                          ),
                        ),
                      ),

                      const SizedBox(width: AppSpacing.xs),

                      // Action Button: Stop during generation, Send otherwise
                      if (_isGenerating)
                        ElevatedButton.icon(
                          onPressed: _stopGeneration,
                          icon: const Icon(Icons.stop_circle_rounded, size: 16),
                          label: const Text('Stop'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.error,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: AppRadius.borderSm),
                          ),
                        )
                      else
                        IconButton(
                          tooltip: 'Send',
                          icon: const Icon(Icons.arrow_upward_rounded, size: 20),
                          color: canSend
                              ? AppColors.primary
                              : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                          onPressed: canSend ? () => _sendQuestion() : null,
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Center(
                child: Text(
                  'Mentra AI • Local private intelligence',
                  style: TextStyle(
                    fontSize: 10,
                    color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
