import 'package:flutter/material.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../shared/widgets/mentra_button.dart';
import '../../../shared/widgets/mentra_card.dart';
import '../../../shared/widgets/mentra_page_header.dart';
import '../../../shared/widgets/mentra_section.dart';
import '../../auth/presentation/auth_controller.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  int _selectedTab = 0;
  final ApiClient _apiClient = ApiClient();

  final List<String> _tabs = [
    'Profile',
    'Appearance',
    'Local AI Engine',
    'Study Preferences',
    'Privacy',
    'Notifications',
    'Camera & Permissions',
    'Data',
  ];

  bool _isTestingKey = false;
  String? _aiTestResult;
  bool? _aiTestSuccess;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final themeCtrl = ThemeScope.of(context);
    final authCtrl = AuthScope.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const MentraPageHeader(
          title: 'Settings',
          subtitle: 'Manage your workspace, appearance, privacy, and study preferences',
        ),

        // Settings Navigation Tabs
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: List.generate(_tabs.length, (index) {
              final isSelected = _selectedTab == index;
              return Padding(
                padding: const EdgeInsets.only(right: AppSpacing.sm),
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedTab = index),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 120),
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.base,
                        vertical: AppSpacing.sm,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? theme.colorScheme.primary.withValues(alpha: isDark ? 0.2 : 0.1)
                            : (isDark ? const Color(0xFF222222) : const Color(0xFFF2F2F0)),
                        borderRadius: AppRadius.borderSm,
                        border: Border.all(
                          color: isSelected ? theme.colorScheme.primary : Colors.transparent,
                          width: 1,
                        ),
                      ),
                      child: Text(
                        _tabs[index],
                        style: AppTypography.labelMedium.copyWith(
                          color: isSelected
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurface,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),

        const SizedBox(height: AppSpacing.xl),

        // Selected Settings Panel
        _buildActiveTabContent(_selectedTab, themeCtrl, authCtrl),
      ],
    );
  }

  Widget _buildActiveTabContent(
    int tabIndex,
    ThemeController themeCtrl,
    AuthController authCtrl,
  ) {
    switch (tabIndex) {
      case 0:
        return _buildProfileSection(authCtrl);
      case 1:
        return _buildAppearanceSection(themeCtrl);
      case 2:
        return _buildAiModelSection();
      case 3:
        return _buildStudyPreferencesSection();
      case 4:
        return _buildPrivacySection();
      case 5:
        return _buildNotificationsSection();
      case 6:
        return _buildCameraSection();
      case 7:
        return _buildDataSection();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildProfileSection(AuthController authCtrl) {
    final theme = Theme.of(context);
    final user = authCtrl.currentUser;
    final displayName = (user?.fullName?.isNotEmpty ?? false)
        ? user!.fullName!
        : 'Mentra Scholar';
    final displayEmail = user?.email ?? 'scholar@mentra.ai';
    final initialLetter = displayName.isNotEmpty ? displayName[0].toUpperCase() : 'M';
    final workspaceId = user != null ? 'ws_${user.id.substring(0, 8)}' : 'ws_local_09214';

    return MentraSection(
      title: 'Profile Settings',
      subtitle: 'Personalize your student identity and account access',
      child: MentraCard(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.15),
                  child: Text(
                    initialLetter,
                    style: AppTypography.titleLarge.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.base),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(displayName, style: AppTypography.titleSmall),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        '$displayEmail • Active Session',
                        style: AppTypography.bodySmall.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                MentraButton(
                  label: 'Log Out',
                  icon: Icons.logout_rounded,
                  variant: MentraButtonVariant.outline,
                  onPressed: () => _confirmLogout(context, authCtrl),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Divider(color: theme.dividerColor, height: 1),
            const SizedBox(height: AppSpacing.lg),
            _buildSettingRow(
              'Primary Study Goal',
              'Ace Final Semester Exams & Machine Learning Certifications',
            ),
            const SizedBox(height: AppSpacing.md),
            _buildSettingRow(
              'Workspace ID',
              workspaceId,
            ),
          ],
        ),
      ),
    );
  }

  void _confirmLogout(BuildContext context, AuthController authCtrl) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.borderLg),
        title: const Text('Log out of Mentra?'),
        content: const Text(
          'Your active study session and telemetry will be preserved on the server. You can sign back in anytime.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          MentraButton(
            label: 'Log Out',
            variant: MentraButtonVariant.primary,
            onPressed: () {
              Navigator.of(ctx).pop();
              authCtrl.logout();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAppearanceSection(ThemeController themeCtrl) {
    return MentraSection(
      title: 'Appearance',
      subtitle: 'Customize the workspace theme and visual density',
      child: MentraCard(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Theme Mode',
              style: AppTypography.titleSmall.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                _buildThemeChoice(
                  label: 'Light',
                  icon: Icons.light_mode_outlined,
                  isSelected: themeCtrl.themeMode == ThemeMode.light,
                  onTap: () => themeCtrl.setThemeMode(ThemeMode.light),
                ),
                const SizedBox(width: AppSpacing.md),
                _buildThemeChoice(
                  label: 'Dark',
                  icon: Icons.dark_mode_outlined,
                  isSelected: themeCtrl.themeMode == ThemeMode.dark,
                  onTap: () => themeCtrl.setThemeMode(ThemeMode.dark),
                ),
                const SizedBox(width: AppSpacing.md),
                _buildThemeChoice(
                  label: 'System',
                  icon: Icons.settings_system_daydream_outlined,
                  isSelected: themeCtrl.themeMode == ThemeMode.system,
                  onTap: () => themeCtrl.setThemeMode(ThemeMode.system),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeChoice({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
          decoration: BoxDecoration(
            color: isSelected
                ? theme.colorScheme.primary.withValues(alpha: isDark ? 0.2 : 0.1)
                : (isDark ? const Color(0xFF222222) : const Color(0xFFF2F2F0)),
            borderRadius: AppRadius.borderMd,
            border: Border.all(
              color: isSelected ? theme.colorScheme.primary : theme.dividerColor,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 18,
                color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                label,
                style: AppTypography.labelMedium.copyWith(
                  color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAiModelSection() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return MentraSection(
      title: 'Local AI Engine',
      subtitle: '100% offline, local open-weight instruction-tuned LLM execution',
      child: MentraCard(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.memory_rounded, color: AppColors.primary, size: 22),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Canonical Model: qwen2.5:0.5b', style: AppTypography.titleSmall),
                      Text('Open-weight instruction-tuned model running locally via Ollama runtime', style: AppTypography.bodySmall),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppColors.success, shape: BoxShape.circle)),
                      const SizedBox(width: 6),
                      Text('100% OFFLINE', style: AppTypography.labelSmall.copyWith(color: AppColors.success, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            if (_aiTestResult != null) ...[
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: (_aiTestSuccess ?? false)
                      ? AppColors.success.withValues(alpha: isDark ? 0.2 : 0.1)
                      : theme.colorScheme.error.withValues(alpha: isDark ? 0.2 : 0.1),
                  borderRadius: AppRadius.borderSm,
                  border: Border.all(
                    color: (_aiTestSuccess ?? false) ? AppColors.success : theme.colorScheme.error,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      (_aiTestSuccess ?? false) ? Icons.check_circle_outline : Icons.error_outline,
                      color: (_aiTestSuccess ?? false) ? AppColors.success : theme.colorScheme.error,
                      size: 20,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        _aiTestResult!,
                        style: AppTypography.labelSmall.copyWith(
                          color: (_aiTestSuccess ?? false) ? AppColors.success : theme.colorScheme.error,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            Row(
              children: [
                MentraButton(
                  label: _isTestingKey ? 'Checking Model...' : 'Check Local AI Engine Status',
                  icon: Icons.refresh_rounded,
                  variant: MentraButtonVariant.secondary,
                  isLoading: _isTestingKey,
                  onPressed: () async {
                    setState(() {
                      _isTestingKey = true;
                      _aiTestResult = null;
                      _aiTestSuccess = null;
                    });
                    try {
                      final res = await _apiClient.get('/api/v1/ai-coach/status');
                      if (res is Map<String, dynamic> && res['is_ready'] == true) {
                        setState(() {
                          _isTestingKey = false;
                          _aiTestSuccess = true;
                          _aiTestResult = 'Mentra Local AI Engine ready! Model: ${res['model']} (Status: ${res['status_message']})';
                        });
                      } else {
                        setState(() {
                          _isTestingKey = false;
                          _aiTestSuccess = false;
                          final status = res is Map<String, dynamic> ? res['status_message'] ?? 'Unavailable' : 'Unavailable';
                          _aiTestResult = 'Model engine not ready. Status: $status';
                        });
                      }
                    } catch (e) {
                      setState(() {
                        _isTestingKey = false;
                        _aiTestSuccess = false;
                        _aiTestResult = 'Could not reach backend AI engine: $e';
                      });
                    }
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStudyPreferencesSection() {
    return MentraSection(
      title: 'Study Preferences',
      subtitle: 'Configure your default session parameters',
      child: MentraCard(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          children: [
            _buildSettingRow('Default Session Duration', '45 minutes'),
            const SizedBox(height: AppSpacing.md),
            _buildSettingRow('Rest Interval', '10 minutes'),
            const SizedBox(height: AppSpacing.md),
            _buildSettingRow('Target Focus Score', '80% Attention Baseline'),
          ],
        ),
      ),
    );
  }

  Widget _buildPrivacySection() {
    final theme = Theme.of(context);
    return MentraSection(
      title: 'Privacy & Security',
      subtitle: 'Mentra is privacy-first and designed for local execution',
      child: MentraCard(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.shield_outlined, color: AppColors.success, size: 22),
                const SizedBox(width: AppSpacing.sm),
                Text('On-Device Privacy Guarantee', style: AppTypography.titleSmall),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Computer vision analysis runs 100% locally on your device. Video frames are processed in-memory and derived behavioral events (attention score, blink rate, phone detection) are generated without ever saving or transmitting raw camera footage.',
              style: AppTypography.bodySmall.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationsSection() {
    return MentraSection(
      title: 'Notifications',
      subtitle: 'Control study nudges and break alerts',
      child: MentraCard(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          children: [
            _buildSettingRow('Fatigue / Drowsiness Alert', 'Enabled (Gentle audio cue)'),
            const SizedBox(height: AppSpacing.md),
            _buildSettingRow('Phone Distraction Nudge', 'Enabled (Visual indicator)'),
            const SizedBox(height: AppSpacing.md),
            _buildSettingRow('Break Reminder', 'Enabled'),
          ],
        ),
      ),
    );
  }

  Widget _buildCameraSection() {
    return MentraSection(
      title: 'Camera & Permissions',
      subtitle: 'Manage local vision device access',
      child: MentraCard(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSettingRow('Active Camera Device', 'FaceTime HD Camera (Built-in)'),
            const SizedBox(height: AppSpacing.md),
            _buildSettingRow('Resolution Mode', '720p (Optimized for low CPU overhead)'),
            const SizedBox(height: AppSpacing.md),
            _buildSettingRow('Permission Status', 'Granted (Local Only)'),
          ],
        ),
      ),
    );
  }

  Widget _buildDataSection() {
    return MentraSection(
      title: 'Data & Telemetry',
      subtitle: 'Manage local workspace storage',
      child: MentraCard(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSettingRow('Local Session Storage', '3.4 MB'),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                MentraButton(
                  label: 'Export Study Data (JSON)',
                  variant: MentraButtonVariant.secondary,
                  onPressed: () {},
                ),
                const SizedBox(width: AppSpacing.md),
                MentraButton(
                  label: 'Clear Local Cache',
                  variant: MentraButtonVariant.outline,
                  onPressed: () {},
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingRow(String label, String value) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: Text(
            label,
            style: AppTypography.bodySmall.copyWith(
              fontWeight: FontWeight.w500,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          flex: 3,
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: AppTypography.bodySmall.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}
