import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/models/coach_insight.dart';

class ChatHistoryDrawer extends StatelessWidget {
  const ChatHistoryDrawer({
    super.key,
    required this.messages,
    required this.onSelectMessage,
    required this.onNewChat,
    required this.onClearHistory,
  });

  final List<ChatMessage> messages;
  final ValueChanged<ChatMessage> onSelectMessage;
  final VoidCallback onNewChat;
  final VoidCallback onClearHistory;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Filter user questions as conversation topics
    final userQuestions = messages.where((m) => m.sender == 'user').toList().reversed.toList();

    return Drawer(
      backgroundColor: theme.colorScheme.surface,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.history_rounded, color: AppColors.primary, size: 22),
                      const SizedBox(width: AppSpacing.sm),
                      Text('Chat History', style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.w700)),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // New Chat Button
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  onNewChat();
                },
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('New Chat'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: AppRadius.borderSm),
                ),
              ),
            ),

            // History List
            Expanded(
              child: userQuestions.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.xl),
                        child: Text(
                          'No recent conversations yet.\nAsk Mentra anything to start.',
                          textAlign: TextAlign.center,
                          style: AppTypography.bodySmall.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
                      itemCount: userQuestions.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 4),
                      itemBuilder: (context, index) {
                        final msg = userQuestions[index];
                        final timeStr = _formatTimestamp(msg.timestamp);

                        return Material(
                          color: Colors.transparent,
                          borderRadius: AppRadius.borderSm,
                          child: InkWell(
                            onTap: () {
                              Navigator.of(context).pop();
                              onSelectMessage(msg);
                            },
                            borderRadius: AppRadius.borderSm,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 10),
                              child: Row(
                                children: [
                                  const Icon(Icons.chat_bubble_outline_rounded, size: 16, color: AppColors.primary),
                                  const SizedBox(width: AppSpacing.sm),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          msg.text,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: AppTypography.bodySmall.copyWith(
                                            fontWeight: FontWeight.w600,
                                            color: theme.colorScheme.onSurface,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          timeStr,
                                          style: AppTypography.labelSmall.copyWith(
                                            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                                            fontSize: 10,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),

            const Divider(height: 1),
            // Footer: Delete Chat / Clear History
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: OutlinedButton.icon(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Delete Chat History?'),
                      content: const Text('This will permanently delete your stored conversation history with Mentra.'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.of(ctx).pop();
                            Navigator.of(context).pop();
                            onClearHistory();
                          },
                          child: const Text('Delete', style: TextStyle(color: AppColors.error)),
                        ),
                      ],
                    ),
                  );
                },
                icon: const Icon(Icons.delete_outline_rounded, size: 16, color: AppColors.error),
                label: const Text('Delete Chat History', style: TextStyle(color: AppColors.error)),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: AppColors.error.withValues(alpha: 0.4)),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: AppRadius.borderSm),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTimestamp(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${dt.month}/${dt.day}';
  }
}
