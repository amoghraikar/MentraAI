import 'package:flutter/material.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/mentra_button.dart';
import '../../../shared/widgets/mentra_card.dart';
import '../../../shared/widgets/mentra_logo.dart';
import 'auth_controller.dart';

class AuthView extends StatefulWidget {
  const AuthView({
    super.key,
    this.initialRegisterMode = false,
    this.onBackToOnboarding,
  });

  final bool initialRegisterMode;
  final VoidCallback? onBackToOnboarding;

  @override
  State<AuthView> createState() => _AuthViewState();
}

class _AuthViewState extends State<AuthView> {
  late bool _isRegisterMode;
  bool _obscurePassword = true;

  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _fullNameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _isRegisterMode = widget.initialRegisterMode;
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _fullNameController.dispose();
    super.dispose();
  }

  void _submit(AuthController auth) {
    auth.clearError();
    if (_formKey.currentState?.validate() ?? false) {
      if (_isRegisterMode) {
        auth.register(
          email: _emailController.text,
          password: _passwordController.text,
          fullName: _fullNameController.text.trim().isNotEmpty
              ? _fullNameController.text.trim()
              : null,
        );
      } else {
        auth.login(
          email: _emailController.text,
          password: _passwordController.text,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final auth = AuthScope.of(context);

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: MentraCard(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (widget.onBackToOnboarding != null) ...[
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: widget.onBackToOnboarding,
                          icon: const Icon(Icons.arrow_back_rounded, size: 16),
                          label: const Text('Back to Introduction'),
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                    ],

                    // Official Brand Icon & Wordmark
                    const Center(
                      child: MentraLogo(
                        markSize: 44,
                        layout: MentraLogoLayout.stacked,
                        showTagline: true,
                        taglineText: 'FOCUS  /  LEARN  /  GROW',
                      ),
                    ),

                    const SizedBox(height: AppSpacing.xl),
                    Divider(color: theme.dividerColor, height: 1),
                    const SizedBox(height: AppSpacing.lg),

                    // Mode Switcher Tabs
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF0F0EF),
                        borderRadius: AppRadius.borderMd,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              borderRadius: AppRadius.borderSm,
                              onTap: () {
                                auth.clearError();
                                setState(() => _isRegisterMode = true);
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                decoration: BoxDecoration(
                                  color: _isRegisterMode
                                      ? (isDark ? const Color(0xFF2C2C2C) : Colors.white)
                                      : Colors.transparent,
                                  borderRadius: AppRadius.borderSm,
                                  boxShadow: _isRegisterMode
                                      ? [
                                          BoxShadow(
                                            color: Colors.black.withValues(alpha: 0.08),
                                            blurRadius: 4,
                                            offset: const Offset(0, 1),
                                          )
                                        ]
                                      : null,
                                ),
                                child: Center(
                                  child: Text(
                                    'Create Account',
                                    style: AppTypography.labelMedium.copyWith(
                                      fontWeight: _isRegisterMode ? FontWeight.w700 : FontWeight.w500,
                                      color: _isRegisterMode
                                          ? theme.colorScheme.onSurface
                                          : theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: InkWell(
                              borderRadius: AppRadius.borderSm,
                              onTap: () {
                                auth.clearError();
                                setState(() => _isRegisterMode = false);
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                decoration: BoxDecoration(
                                  color: !_isRegisterMode
                                      ? (isDark ? const Color(0xFF2C2C2C) : Colors.white)
                                      : Colors.transparent,
                                  borderRadius: AppRadius.borderSm,
                                  boxShadow: !_isRegisterMode
                                      ? [
                                          BoxShadow(
                                            color: Colors.black.withValues(alpha: 0.08),
                                            blurRadius: 4,
                                            offset: const Offset(0, 1),
                                          )
                                        ]
                                      : null,
                                ),
                                child: Center(
                                  child: Text(
                                    'Log In',
                                    style: AppTypography.labelMedium.copyWith(
                                      fontWeight: !_isRegisterMode ? FontWeight.w700 : FontWeight.w500,
                                      color: !_isRegisterMode
                                          ? theme.colorScheme.onSurface
                                          : theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: AppSpacing.lg),

                    // Title & Subtitle
                    Text(
                      _isRegisterMode ? 'Create Your Account' : 'Sign In to Mentra',
                      style: AppTypography.titleLarge.copyWith(
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      _isRegisterMode
                          ? 'Set up your study profile to track focus, goals, and notes'
                          : 'Enter your credentials to access your study workspace',
                      style: AppTypography.bodySmall.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),

                    const SizedBox(height: AppSpacing.lg),

                    // Error Banner (if any)
                    if (auth.errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF3B1E1E) : const Color(0xFFFEF2F2),
                          borderRadius: AppRadius.borderSm,
                          border: Border.all(
                            color: isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFECACA),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.error_outline_rounded, size: 16, color: Colors.red),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Text(
                                auth.errorMessage!,
                                style: AppTypography.bodySmall.copyWith(
                                  color: isDark ? const Color(0xFFFCA5A5) : const Color(0xFFDC2626),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                    ],

                    // Full Name (Only in Register mode)
                    if (_isRegisterMode) ...[
                      Text('Full Name', style: AppTypography.labelSmall),
                      const SizedBox(height: AppSpacing.xs),
                      _buildTextField(
                        controller: _fullNameController,
                        hintText: 'e.g. Alex Chen',
                        prefixIcon: Icons.person_outline_rounded,
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: AppSpacing.md),
                    ],

                    // Email Field
                    Text('Email Address', style: AppTypography.labelSmall),
                    const SizedBox(height: AppSpacing.xs),
                    _buildTextField(
                      controller: _emailController,
                      hintText: 'you@example.com',
                      prefixIcon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter your email';
                        }
                        if (!value.contains('@') || !value.contains('.')) {
                          return 'Enter a valid email address';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: AppSpacing.md),

                    // Password Field
                    Text('Password', style: AppTypography.labelSmall),
                    const SizedBox(height: AppSpacing.xs),
                    _buildTextField(
                      controller: _passwordController,
                      hintText: '••••••••',
                      prefixIcon: Icons.lock_outline_rounded,
                      obscureText: _obscurePassword,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _submit(auth),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                          size: 18,
                        ),
                        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your password';
                        }
                        if (value.length < 6) {
                          return 'Password must be at least 6 characters';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: AppSpacing.xl),

                    // Primary Submit Button
                    MentraButton(
                      label: _isRegisterMode ? 'Create Account' : 'Sign In',
                      isLoading: auth.isLoading,
                      fullWidth: true,
                      onPressed: () => _submit(auth),
                    ),

                    const SizedBox(height: AppSpacing.sm),

                    // Quick Guest / Demo Access
                    MentraButton(
                      label: 'Explore as Guest (Demo Mode)',
                      variant: MentraButtonVariant.secondary,
                      icon: Icons.explore_outlined,
                      fullWidth: true,
                      onPressed: () {
                        auth.clearError();
                        auth.login(
                          email: 'student@mentra.ai',
                          password: 'Password123!',
                        );
                      },
                    ),

                    const SizedBox(height: AppSpacing.base),

                    // Toggle Register / Login Mode
                    Center(
                      child: GestureDetector(
                        onTap: () {
                          auth.clearError();
                          setState(() => _isRegisterMode = !_isRegisterMode);
                        },
                        child: Text.rich(
                          TextSpan(
                            text: _isRegisterMode
                                ? 'Already have an account? '
                                : "Don't have an account? ",
                            style: AppTypography.bodySmall.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            children: [
                              TextSpan(
                                text: _isRegisterMode ? 'Sign In' : 'Create Account',
                                style: AppTypography.bodySmall.copyWith(
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    if (widget.onBackToOnboarding != null) ...[
                      const SizedBox(height: AppSpacing.md),
                      Center(
                        child: TextButton.icon(
                          onPressed: widget.onBackToOnboarding,
                          icon: const Icon(Icons.info_outline_rounded, size: 14),
                          label: const Text('View Product Introduction Tour'),
                          style: TextButton.styleFrom(
                            foregroundColor: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                            textStyle: AppTypography.bodySmall,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    required IconData prefixIcon,
    TextInputType? keyboardType,
    TextInputAction? textInputAction,
    bool obscureText = false,
    Widget? suffixIcon,
    String? Function(String?)? validator,
    void Function(String)? onFieldSubmitted,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      obscureText: obscureText,
      validator: validator,
      onFieldSubmitted: onFieldSubmitted,
      style: AppTypography.bodyMedium.copyWith(color: theme.colorScheme.onSurface),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: AppTypography.bodyMedium.copyWith(
          color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
        ),
        prefixIcon: Icon(prefixIcon, size: 18, color: theme.colorScheme.onSurfaceVariant),
        suffixIcon: suffixIcon,
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
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.borderSm,
          borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppRadius.borderSm,
          borderSide: const BorderSide(color: Colors.red),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: AppRadius.borderSm,
          borderSide: const BorderSide(color: Colors.red, width: 1.5),
        ),
      ),
    );
  }
}
