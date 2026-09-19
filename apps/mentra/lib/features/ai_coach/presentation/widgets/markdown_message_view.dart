import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';

class MarkdownMessageView extends StatelessWidget {
  const MarkdownMessageView({
    super.key,
    required this.content,
    this.isUser = false,
  });

  final String content;
  final bool isUser;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (isUser) {
      return Text(
        content,
        style: AppTypography.bodyMedium.copyWith(
          color: Colors.white,
          height: 1.5,
        ),
      );
    }

    // Split message into code blocks and normal markdown segments
    final segments = _splitContent(content);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: segments.map((segment) {
        if (segment.isCodeBlock) {
          return _buildCodeBlock(context, segment.code, segment.language, isDark);
        } else {
          return _buildMarkdownSection(context, segment.text, theme, isDark);
        }
      }).toList(),
    );
  }

  Widget _buildCodeBlock(BuildContext context, String code, String language, bool isDark) {
    final displayLang = language.trim().isNotEmpty ? language.trim().toUpperCase() : 'CODE';

    return Container(
      margin: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: const Color(0xFF18181B), // Dark zinc background for code
        borderRadius: AppRadius.borderSm,
        border: Border.all(
          color: const Color(0xFF27272A),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Bar with Language and Copy Button
          Container(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 6),
            decoration: const BoxDecoration(
              color: Color(0xFF202023),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(7),
                topRight: Radius.circular(7),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  displayLang,
                  style: const TextStyle(
                    color: Color(0xFFA1A1AA),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                    fontFamily: 'monospace',
                  ),
                ),
                InkWell(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: code));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Code copied to clipboard'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(4),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    child: Row(
                      children: [
                        Icon(Icons.copy_rounded, color: Color(0xFFA1A1AA), size: 13),
                        SizedBox(width: 4),
                        Text(
                          'Copy',
                          style: TextStyle(
                            color: Color(0xFFA1A1AA),
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Horizontally scrollable code
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(AppSpacing.md),
            child: SelectableText(
              code,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 13,
                height: 1.5,
                color: Color(0xFFE4E4E7),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMarkdownSection(BuildContext context, String text, ThemeData theme, bool isDark) {
    final lines = text.split('\n');
    final widgets = <Widget>[];

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final trimmed = line.trim();

      if (trimmed.isEmpty) {
        widgets.add(const SizedBox(height: 8));
        continue;
      }

      // Headers: #, ##, ###
      if (trimmed.startsWith('### ')) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 4),
            child: Text(
              trimmed.substring(4),
              style: AppTypography.titleSmall.copyWith(
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
        );
      } else if (trimmed.startsWith('## ')) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 4),
            child: Text(
              trimmed.substring(3),
              style: AppTypography.titleMedium.copyWith(
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
        );
      } else if (trimmed.startsWith('# ')) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 6),
            child: Text(
              trimmed.substring(2),
              style: AppTypography.titleLarge.copyWith(
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
        );
      }
      // Bullet items: -, *, •
      else if (trimmed.startsWith('• ') || trimmed.startsWith('- ') || trimmed.startsWith('* ')) {
        final bulletText = trimmed.substring(2);
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(left: 6, bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 6, right: 8),
                  child: Icon(Icons.circle, size: 5, color: AppColors.primary),
                ),
                Expanded(
                  child: _buildRichInlineText(bulletText, theme, isDark),
                ),
              ],
            ),
          ),
        );
      }
      // Numbered items: 1. , 2. , etc.
      else if (RegExp(r'^\d+\.\s').hasMatch(trimmed)) {
        final match = RegExp(r'^(\d+\.)\s*(.*)$').firstMatch(trimmed);
        final numPrefix = match?.group(1) ?? '•';
        final itemText = match?.group(2) ?? trimmed;
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 24,
                  child: Text(
                    numPrefix,
                    style: AppTypography.bodySmall.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                Expanded(
                  child: _buildRichInlineText(itemText, theme, isDark),
                ),
              ],
            ),
          ),
        );
      }
      // Regular paragraph line
      else {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: _buildRichInlineText(trimmed, theme, isDark),
          ),
        );
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }

  Widget _buildRichInlineText(String text, ThemeData theme, bool isDark) {
    final spans = <InlineSpan>[];
    // Match inline code `code` or bold **bold**
    final regex = RegExp(r'(`[^`]+`|\*\*[^*]+\*\*)');
    int lastEnd = 0;

    for (final match in regex.allMatches(text)) {
      if (match.start > lastEnd) {
        spans.add(TextSpan(
          text: text.substring(lastEnd, match.start),
          style: AppTypography.bodyMedium.copyWith(
            color: theme.colorScheme.onSurface,
            height: 1.5,
          ),
        ));
      }

      final matchedStr = match.group(0)!;
      if (matchedStr.startsWith('`') && matchedStr.endsWith('`')) {
        // Inline code
        final code = matchedStr.substring(1, matchedStr.length - 1);
        spans.add(WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF27272A) : const Color(0xFFE4E4E7),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              code,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7),
              ),
            ),
          ),
        ));
      } else if (matchedStr.startsWith('**') && matchedStr.endsWith('**')) {
        // Bold
        final boldText = matchedStr.substring(2, matchedStr.length - 2);
        spans.add(TextSpan(
          text: boldText,
          style: AppTypography.bodyMedium.copyWith(
            fontWeight: FontWeight.w700,
            color: theme.colorScheme.onSurface,
            height: 1.5,
          ),
        ));
      }

      lastEnd = match.end;
    }

    if (lastEnd < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastEnd),
        style: AppTypography.bodyMedium.copyWith(
          color: theme.colorScheme.onSurface,
          height: 1.5,
        ),
      ));
    }

    return SelectableText.rich(
      TextSpan(children: spans),
    );
  }

  List<_ContentSegment> _splitContent(String text) {
    final segments = <_ContentSegment>[];
    final codeBlockRegex = RegExp(r'```([a-zA-Z0-9_\-]*)\n([\s\S]*?)```');
    int lastEnd = 0;

    for (final match in codeBlockRegex.allMatches(text)) {
      if (match.start > lastEnd) {
        segments.add(_ContentSegment(
          text: text.substring(lastEnd, match.start),
          isCodeBlock: false,
        ));
      }
      final lang = match.group(1) ?? '';
      final code = match.group(2) ?? '';
      segments.add(_ContentSegment(
        text: '',
        code: code.trimRight(),
        language: lang,
        isCodeBlock: true,
      ));
      lastEnd = match.end;
    }

    if (lastEnd < text.length) {
      segments.add(_ContentSegment(
        text: text.substring(lastEnd),
        isCodeBlock: false,
      ));
    }

    return segments;
  }
}

class _ContentSegment {
  _ContentSegment({
    required this.text,
    this.code = '',
    this.language = '',
    required this.isCodeBlock,
  });

  final String text;
  final String code;
  final String language;
  final bool isCodeBlock;
}
