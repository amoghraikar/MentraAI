import 'package:flutter/material.dart';
import '../../core/routing/app_route.dart';
import '../../core/routing/app_router.dart';
import '../../core/theme/app_spacing.dart';
import '../../features/ai_coach/presentation/ai_coach_page.dart';
import '../../features/analytics/presentation/analytics_page.dart';
import '../../features/goals/presentation/goals_page.dart';
import '../../features/home/presentation/home_page.dart';
import '../../features/notes/presentation/notes_page.dart';
import '../../features/settings/presentation/settings_page.dart';
import '../../features/subjects/presentation/subjects_page.dart';
import '../widgets/mentra_sidebar.dart';

class WorkspaceLayout extends StatelessWidget {
  const WorkspaceLayout({super.key});

  @override
  Widget build(BuildContext context) {
    final nav = NavigationScope.of(context);

    return Scaffold(
      body: Row(
        children: [
          // Fixed Desktop Sidebar
          const MentraSidebar(),

          // Main Workspace Viewport
          Expanded(
            child: FocusTraversalGroup(
              child: _buildCurrentPage(nav.currentRoute),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentPage(AppRoute route) {
    Widget page;
    switch (route) {
      case AppRoute.home:
        page = const HomePage();
        break;
      case AppRoute.subjects:
        page = const SubjectsPage();
        break;
      case AppRoute.notes:
        page = const NotesPage();
        break;
      case AppRoute.goals:
        page = const GoalsPage();
        break;
      case AppRoute.analytics:
        page = const AnalyticsPage();
        break;
      case AppRoute.aiCoach:
        page = const AiCoachPage();
        break;
      case AppRoute.settings:
        page = const SettingsPage();
        break;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xxl,
            vertical: AppSpacing.xl,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: AppSpacing.maxContentWidth,
              ),
              child: page,
            ),
          ),
        );
      },
    );
  }
}
