import 'package:flutter/material.dart';
import '../../core/network/api_client.dart';
import '../../core/routing/app_route.dart';
import '../../core/routing/app_router.dart';
import '../../core/theme/app_spacing.dart';
import '../../features/ai_coach/data/repositories/api_ai_coach_repository.dart';
import '../../features/ai_coach/domain/repositories/ai_coach_repository.dart';
import '../../features/ai_coach/presentation/ai_coach_page.dart';
import '../../features/analytics/data/repositories/api_analytics_repository.dart';
import '../../features/analytics/domain/repositories/analytics_repository.dart';
import '../../features/analytics/presentation/analytics_page.dart';
import '../../features/auth/services/token_storage_service.dart';
import '../../features/goals/data/repositories/api_goal_repository.dart';
import '../../features/goals/domain/repositories/goal_repository.dart';
import '../../features/goals/presentation/goals_page.dart';
import '../../features/home/presentation/home_page.dart';
import '../../features/notes/data/repositories/api_note_repository.dart';
import '../../features/notes/domain/repositories/note_repository.dart';
import '../../features/notes/presentation/notes_page.dart';
import '../../features/settings/presentation/settings_page.dart';
import '../../features/study_session/data/repositories/api_session_repository.dart';
import '../../features/study_session/domain/repositories/session_repository.dart';
import '../../features/study_session/presentation/active_study_page.dart';
import '../../features/study_session/presentation/session_controller.dart';
import '../../features/study_session/presentation/session_summary_page.dart';
import '../../features/study_session/presentation/study_prep_page.dart';
import '../../features/study_session/presentation/study_setup_dialog.dart';
import '../../features/subjects/data/repositories/api_subject_repository.dart';
import '../../features/subjects/domain/models/subject_model.dart';
import '../../features/subjects/domain/models/topic_model.dart';
import '../../features/subjects/domain/repositories/subject_repository.dart';
import '../../features/subjects/presentation/subject_workspace_page.dart';
import '../../features/subjects/presentation/subjects_page.dart';
import '../../features/subjects/presentation/topic_view_page.dart';
import '../../features/goals/data/repositories/mock_goal_repository.dart';
import '../../features/notes/data/repositories/mock_note_repository.dart';
import '../../features/analytics/data/repositories/mock_analytics_repository.dart';
import '../../features/study_session/data/repositories/mock_session_repository.dart';
import '../../features/subjects/data/repositories/mock_subject_repository.dart';
import '../widgets/mentra_sidebar.dart';

class WorkspaceLayout extends StatefulWidget {
  const WorkspaceLayout({
    super.key,
    this.subjectRepository,
    this.noteRepository,
    this.goalRepository,
    this.sessionRepository,
    this.analyticsRepository,
    this.aiCoachRepository,
  });

  final SubjectRepository? subjectRepository;
  final NoteRepository? noteRepository;
  final GoalRepository? goalRepository;
  final SessionRepository? sessionRepository;
  final AnalyticsRepository? analyticsRepository;
  final AiCoachRepository? aiCoachRepository;

  @override
  State<WorkspaceLayout> createState() => _WorkspaceLayoutState();
}

class _WorkspaceLayoutState extends State<WorkspaceLayout> {
  late final SubjectRepository _subjectRepo;
  late final NoteRepository _noteRepo;
  late final GoalRepository _goalRepo;
  late final SessionRepository _sessionRepo;
  late final AnalyticsRepository _analyticsRepo;
  late final AiCoachRepository _aiCoachRepo;
  late final SessionController _sessionController;

  // Sub-route state
  SubjectModel? _selectedSubject;
  TopicModel? _selectedTopic;

  @override
  void initState() {
    super.initState();
    final apiClient = ApiClient(
      tokenProvider: () async {
        try {
          return await SecureTokenStorage().getToken();
        } catch (_) {
          return null;
        }
      },
    );

    _subjectRepo = widget.subjectRepository ??
        ApiSubjectRepository(apiClient: apiClient, fallbackRepository: MockSubjectRepository());
    _noteRepo = widget.noteRepository ??
        ApiNoteRepository(apiClient: apiClient, fallbackRepository: MockNoteRepository());
    _goalRepo = widget.goalRepository ??
        ApiGoalRepository(apiClient: apiClient, fallbackRepository: MockGoalRepository());
    _sessionRepo = widget.sessionRepository ??
        ApiSessionRepository(apiClient: apiClient, fallbackRepository: MockSessionRepository());
    _analyticsRepo = widget.analyticsRepository ??
        ApiAnalyticsRepository(apiClient: apiClient, fallbackRepository: MockAnalyticsRepository());
    _aiCoachRepo = widget.aiCoachRepository ?? ApiAiCoachRepository(apiClient: apiClient);

    _sessionController = SessionController(sessionRepository: _sessionRepo);
    _sessionController.addListener(_onSessionStateChange);
  }

  void _onSessionStateChange() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _sessionController.removeListener(_onSessionStateChange);
    _sessionController.dispose();
    super.dispose();
  }

  void _openStudySetup({String? subjectId, String? topicId}) {
    StudySetupDialog.show(
      context: context,
      subjectRepository: _subjectRepo,
      initialSubjectId: subjectId,
      initialTopicId: topicId,
      onStartPreparation: (config) {
        _sessionController.setupSession(config);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // 1. If in Study Session Flow, show dedicated fullscreen views
    switch (_sessionController.state) {
      case SessionState.preparing:
        return StudyPrepPage(
          sessionController: _sessionController,
          onStartSession: _sessionController.startActiveSession,
          onCancel: _sessionController.cancelSession,
        );
      case SessionState.active:
      case SessionState.paused:
        return ActiveStudyPage(
          sessionController: _sessionController,
        );
      case SessionState.completed:
        return SessionSummaryPage(
          sessionController: _sessionController,
          aiCoachRepository: _aiCoachRepo,
          onDone: () {
            _sessionController.cancelSession();
            NavigationScope.of(context).setRoute(AppRoute.home);
          },
        );
      case SessionState.idle:
        break;
    }

    final nav = NavigationScope.of(context);

    return Scaffold(
      body: Row(
        children: [
          // Fixed Desktop Sidebar
          MentraSidebar(
            onStartStudySession: () => _openStudySetup(),
          ),

          // Main Workspace Viewport
          Expanded(
            child: FocusTraversalGroup(
              child: _buildCurrentWorkspace(nav.currentRoute),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentWorkspace(AppRoute route) {
    Widget content;

    // Reset sub-navigation when switching primary tabs away from subjects
    if (route != AppRoute.subjects && (_selectedSubject != null || _selectedTopic != null)) {
      _selectedSubject = null;
      _selectedTopic = null;
    }

    if (route == AppRoute.subjects) {
      if (_selectedTopic != null && _selectedSubject != null) {
        content = TopicViewPage(
          subject: _selectedSubject!,
          topic: _selectedTopic!,
          onBack: () => setState(() => _selectedTopic = null),
          onStartStudySession: (subId, topId) => _openStudySetup(subjectId: subId, topicId: topId),
        );
      } else if (_selectedSubject != null) {
        content = SubjectWorkspacePage(
          subjectId: _selectedSubject!.id,
          subjectRepository: _subjectRepo,
          onBack: () => setState(() => _selectedSubject = null),
          onOpenTopic: (sub, top) => setState(() {
            _selectedSubject = sub;
            _selectedTopic = top;
          }),
          onStartStudySession: (subId, topId) => _openStudySetup(subjectId: subId, topicId: topId),
        );
      } else {
        content = SubjectsPage(
          subjectRepository: _subjectRepo,
          onSelectSubject: (sub) => setState(() => _selectedSubject = sub),
          onStartStudySession: (subId) => _openStudySetup(subjectId: subId),
        );
      }
    } else {
      switch (route) {
        case AppRoute.home:
          content = HomePage(
            sessionRepository: _sessionRepo,
            onStartStudySession: () => _openStudySetup(),
            onOpenSubject: (subId) {
              NavigationScope.of(context).setRoute(AppRoute.subjects);
            },
          );
          break;
        case AppRoute.notes:
          content = NotesPage(
            noteRepository: _noteRepo,
          );
          break;
        case AppRoute.goals:
          content = GoalsPage(
            goalRepository: _goalRepo,
          );
          break;
        case AppRoute.analytics:
          content = AnalyticsPage(
            analyticsRepository: _analyticsRepo,
          );
          break;
        case AppRoute.aiCoach:
          content = AiCoachPage(
            aiCoachRepository: _aiCoachRepo,
            sessionController: _sessionController,
          );
          break;
        case AppRoute.settings:
          content = const SettingsPage();
          break;
        case AppRoute.subjects:
          content = const SizedBox.shrink();
          break;
      }
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
              child: content,
            ),
          ),
        );
      },
    );
  }
}
