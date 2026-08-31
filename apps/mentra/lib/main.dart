import 'package:flutter/material.dart';
import 'core/constants/app_constants.dart';
import 'core/routing/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_controller.dart';
import 'features/auth/presentation/auth_controller.dart';
import 'features/auth/presentation/auth_view.dart';
import 'features/auth/services/auth_service.dart';
import 'features/onboarding/presentation/onboarding_view.dart';
import 'shared/layouts/workspace_layout.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MentraRoot());
}

class MentraRoot extends StatefulWidget {
  const MentraRoot({
    super.key,
    this.authService,
    this.initialShowOnboarding = false,
  });

  final AuthService? authService;
  final bool initialShowOnboarding;

  @override
  State<MentraRoot> createState() => _MentraRootState();
}

class _MentraRootState extends State<MentraRoot> {
  late final NavigationController _navigationController;
  late final ThemeController _themeController;
  late final AuthController _authController;
  late bool _hasCompletedOnboarding;

  @override
  void initState() {
    super.initState();
    _hasCompletedOnboarding = !widget.initialShowOnboarding;
    _navigationController = NavigationController();
    _themeController = ThemeController();
    _authController = AuthController(authService: widget.authService);
    _authController.initialize();
  }

  @override
  void dispose() {
    _navigationController.dispose();
    _themeController.dispose();
    _authController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ThemeScope(
      controller: _themeController,
      child: AuthScope(
        controller: _authController,
        child: NavigationScope(
          controller: _navigationController,
          child: AnimatedBuilder(
            animation: Listenable.merge([_themeController, _authController]),
            builder: (context, _) {
              Widget homeWidget;

              if (!_hasCompletedOnboarding) {
                homeWidget = OnboardingView(
                  onComplete: () => setState(() => _hasCompletedOnboarding = true),
                );
              } else {
                switch (_authController.status) {
                  case AuthStatus.checking:
                    homeWidget = const Scaffold(
                      body: Center(
                        child: CircularProgressIndicator(),
                      ),
                    );
                    break;
                  case AuthStatus.authenticated:
                    homeWidget = const WorkspaceLayout();
                    break;
                  case AuthStatus.unauthenticated:
                    homeWidget = const AuthView();
                    break;
                }
              }

              return MaterialApp(
                title: AppConstants.appName,
                debugShowCheckedModeBanner: false,
                theme: AppTheme.lightTheme,
                darkTheme: AppTheme.darkTheme,
                themeMode: _themeController.themeMode,
                home: homeWidget,
              );
            },
          ),
        ),
      ),
    );
  }
}
