import 'package:flutter/material.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/mentra_button.dart';
import '../../../shared/widgets/mentra_card.dart';
import '../../../shared/widgets/mentra_logo.dart';

class OnboardingView extends StatefulWidget {
  const OnboardingView({
    super.key,
    required this.onComplete,
    this.onSignIn,
    this.onSignUp,
  });

  final VoidCallback onComplete;
  final VoidCallback? onSignIn;
  final VoidCallback? onSignUp;

  @override
  State<OnboardingView> createState() => _OnboardingViewState();
}

class _OnboardingViewState extends State<OnboardingView> {
  int _currentStep = 0;

  final List<Map<String, dynamic>> _steps = [
    {
      'badge': 'WELCOME TO MENTRA',
      'title': 'Master your studies with an\nIntelligent AI Study Coach.',
      'description': 'A calm, distraction-free workspace combining structured topic mastery, intelligent notes, and local behavioral guidance to help you reach peak academic performance.',
      'icon': Icons.psychology_outlined,
      'highlight': 'Built for focused students & deep learners',
    },
    {
      'badge': 'LIVE COMPUTER VISION',
      'title': 'Live Face & Gaze Tracking\nwith 100% On-Device Privacy.',
      'description': 'Observe your real-time attention score, gaze alignment, and blink rates during study sessions. All computer vision analysis executes locally in-memory on your hardware without transmitting video.',
      'icon': Icons.visibility_outlined,
      'highlight': 'Real-time focus HUD • Zero cloud video streaming',
    },
    {
      'badge': 'STRUCTURE & MASTERY',
      'title': 'Organize subjects, notes,\nand active milestones.',
      'description': 'Break complex coursework down into manageable topics, maintain persistent revision notes, and track your retention and study hours with precision.',
      'icon': Icons.folder_outlined,
      'highlight': 'Structured hierarchy • Rich notes & goal tracking',
    },
    {
      'badge': 'ADAPTIVE AI COACH',
      'title': 'Actionable analytics &\nproactive study interventions.',
      'description': 'Mentra learns your fatigue patterns, optimal study windows, and distraction triggers to provide tailored recommendations, break reminders, and motivating guidance.',
      'icon': Icons.auto_awesome_outlined,
      'highlight': 'Personalized insights • LLM coaching & support',
    },
  ];

  void _next() {
    if (_currentStep < _steps.length - 1) {
      setState(() => _currentStep++);
    } else {
      widget.onComplete();
    }
  }

  void _goToSignIn() {
    if (widget.onSignIn != null) {
      widget.onSignIn!();
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
      backgroundColor: isDark ? const Color(0xFF0F1216) : const Color(0xFFF7F8FA),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: MentraCard(
              padding: const EdgeInsets.all(AppSpacing.xxl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // App Brand Header & Step Indicator
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Flexible(
                        child: MentraLogo(
                          markSize: 26,
                          layout: MentraLogoLayout.horizontal,
                          showTagline: true,
                          taglineText: 'FOCUS / LEARN / GROW',
                        ),
                      ),
                      Row(
                        children: List.generate(_steps.length, (index) {
                          final isActive = index == _currentStep;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            margin: const EdgeInsets.only(left: 6),
                            width: isActive ? 24 : 8,
                            height: 6,
                            decoration: BoxDecoration(
                              color: isActive
                                  ? theme.colorScheme.primary
                                  : theme.dividerColor,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          );
                        }),
                      ),
                    ],
                  ),

                  const SizedBox(height: AppSpacing.xl),

                  // Feature Icon & Highlight Badge
                  Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withValues(alpha: isDark ? 0.18 : 0.08),
                          borderRadius: AppRadius.borderMd,
                          border: Border.all(
                            color: theme.colorScheme.primary.withValues(alpha: 0.25),
                          ),
                        ),
                        child: Icon(
                          step['icon'] as IconData,
                          size: 26,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              step['badge'] as String,
                              style: AppTypography.labelSmall.copyWith(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.4,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF1E232B) : const Color(0xFFEEF2F6),
                                borderRadius: AppRadius.borderSm,
                              ),
                              child: Text(
                                step['highlight'] as String,
                                style: AppTypography.bodySmall.copyWith(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? const Color(0xFF9EABB8) : const Color(0xFF4A5568),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: AppSpacing.lg),

                  // Step Title
                  Text(
                    step['title'] as String,
                    style: AppTypography.titleLarge.copyWith(
                      fontWeight: FontWeight.w800,
                      fontSize: 23,
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
                      height: 1.55,
                      fontSize: 14,
                    ),
                  ),

                  const SizedBox(height: AppSpacing.xxl),
                  Divider(color: theme.dividerColor, height: 1),
                  const SizedBox(height: AppSpacing.lg),

                  // Action Buttons & Sign In / Sign Up CTAs
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
                      ] else ...[
                        TextButton(
                          onPressed: _goToSignIn,
                          child: Text(
                            'Sign In',
                            style: AppTypography.labelMedium.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                      const Spacer(),
                      if (!isLast) ...[
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
                      ],
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
