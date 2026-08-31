import 'package:flutter/material.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/mentra_button.dart';
import '../../../shared/widgets/mentra_card.dart';

class OnboardingView extends StatefulWidget {
  const OnboardingView({
    super.key,
    required this.onComplete,
  });

  final VoidCallback onComplete;

  @override
  State<OnboardingView> createState() => _OnboardingViewState();
}

class _OnboardingViewState extends State<OnboardingView> {
  int _currentStep = 0;

  final List<Map<String, dynamic>> _steps = [
    {
      'badge': 'WELCOME TO MENTRA',
      'title': 'Understand your focus.\nImprove your learning.',
      'description': 'A calm, Notion-inspired study workspace designed to help you master challenging subjects through focused sessions and intelligent behavioral insights.',
      'icon': Icons.psychology_outlined,
    },
    {
      'badge': 'STRUCTURE & CLARITY',
      'title': 'Organize your subjects,\ntopics, and notes.',
      'description': 'Structure coursework by subjects, break them down into bite-sized topics, track milestone progress, and capture lecture notes in one distraction-free environment.',
      'icon': Icons.folder_outlined,
    },
    {
      'badge': 'LOCAL FOCUS MONITORING',
      'title': 'Deep focus sessions with\non-device privacy.',
      'description': 'Study with gentle fatigue and distraction nudges. All computer vision analysis runs 100% locally on your machine without storing or streaming raw video.',
      'icon': Icons.visibility_outlined,
    },
    {
      'badge': 'PERSONALIZED COACHING',
      'title': 'Actionable analytics &\nstudy recommendations.',
      'description': 'Understand your peak attention hours, detect recurring distraction triggers, and receive adaptive recommendations from your personal AI Study Coach.',
      'icon': Icons.auto_awesome_outlined,
    },
  ];

  void _next() {
    if (_currentStep < _steps.length - 1) {
      setState(() => _currentStep++);
    } else {
      widget.onComplete();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final step = _steps[_currentStep];
    final isLast = _currentStep == _steps.length - 1;

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: MentraCard(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // App Icon & Progress Dots
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF2C2C2C) : const Color(0xFFE8E8E6),
                          borderRadius: AppRadius.borderSm,
                        ),
                        child: Center(
                          child: Text(
                            'M',
                            style: AppTypography.titleLarge.copyWith(
                              fontWeight: FontWeight.w800,
                              color: theme.colorScheme.primary,
                              height: 1,
                            ),
                          ),
                        ),
                      ),
                      Row(
                        children: List.generate(_steps.length, (index) {
                          final isActive = index == _currentStep;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.only(left: AppSpacing.xs),
                            width: isActive ? 20 : 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: isActive ? theme.colorScheme.primary : theme.dividerColor,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          );
                        }),
                      ),
                    ],
                  ),

                  const SizedBox(height: AppSpacing.xl),

                  // Step Icon
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: isDark ? 0.15 : 0.08),
                      borderRadius: AppRadius.borderMd,
                      border: Border.all(
                        color: theme.colorScheme.primary.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Icon(
                      step['icon'] as IconData,
                      size: 24,
                      color: theme.colorScheme.primary,
                    ),
                  ),

                  const SizedBox(height: AppSpacing.lg),

                  // Step Badge
                  Text(
                    step['badge'] as String,
                    style: AppTypography.labelSmall.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
                  ),

                  const SizedBox(height: AppSpacing.sm),

                  // Step Title
                  Text(
                    step['title'] as String,
                    style: AppTypography.titleLarge.copyWith(
                      fontWeight: FontWeight.w800,
                      height: 1.25,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),

                  const SizedBox(height: AppSpacing.md),

                  // Step Description
                  Text(
                    step['description'] as String,
                    style: AppTypography.bodyMedium.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1.5,
                    ),
                  ),

                  const SizedBox(height: AppSpacing.xl),
                  Divider(color: theme.dividerColor, height: 1),
                  const SizedBox(height: AppSpacing.lg),

                  // Action Buttons
                  Row(
                    children: [
                      if (_currentStep > 0) ...[
                        TextButton(
                          onPressed: () => setState(() => _currentStep--),
                          child: Text(
                            'Back',
                            style: AppTypography.labelMedium.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                      ],
                      const Spacer(),
                      if (!isLast)
                        TextButton(
                          onPressed: widget.onComplete,
                          child: Text(
                            'Skip',
                            style: AppTypography.labelMedium.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      const SizedBox(width: AppSpacing.sm),
                      MentraButton(
                        label: isLast ? 'Get Started' : 'Continue',
                        icon: isLast ? Icons.arrow_forward_rounded : null,
                        onPressed: _next,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
