import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mentra/core/network/api_client.dart';
import 'package:mentra/features/analytics/data/repositories/api_analytics_repository.dart';
import 'package:mentra/features/goals/data/repositories/api_goal_repository.dart';
import 'package:mentra/features/notes/data/repositories/api_note_repository.dart';
import 'package:mentra/features/study_session/data/repositories/api_session_repository.dart';
import 'package:mentra/features/study_session/domain/models/study_session_record.dart';
import 'package:mentra/features/subjects/data/repositories/api_subject_repository.dart';

void main() {
  group('ApiSubjectRepository', () {
    test('getSubjects parses response correctly', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, '/api/v1/subjects');
        return http.Response(
          jsonEncode([
            {
              'id': 'sub_1',
              'user_id': 'u_1',
              'title': 'Data Analytics',
              'code': 'DA-101',
              'description': 'Intro to data',
              'color_hex': '#3B82F6',
              'total_hours': 10.0,
              'target_hours': 30.0,
              'created_at': '2026-09-01T12:00:00Z',
              'updated_at': '2026-09-01T12:00:00Z',
              'topics': [
                {
                  'id': 'top_1',
                  'subject_id': 'sub_1',
                  'title': 'Linear Regression',
                  'description': 'OLS basics',
                  'progress': 0.5,
                  'total_minutes': 60,
                  'key_concepts': ['OLS', 'Residuals'],
                  'notes_snippet': 'Formula',
                  'is_completed': false,
                  'created_at': '2026-09-01T12:00:00Z',
                  'updated_at': '2026-09-01T12:00:00Z',
                }
              ],
            }
          ]),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final repo = ApiSubjectRepository(apiClient: ApiClient(httpClient: mockClient));
      final subjects = await repo.getSubjects();

      expect(subjects.length, 1);
      expect(subjects.first.title, 'Data Analytics');
      expect(subjects.first.topics.length, 1);
      expect(subjects.first.topics.first.title, 'Linear Regression');
    });

    test('createSubject posts data and parses response', () async {
      final mockClient = MockClient((request) async {
        expect(request.method, 'POST');
        final body = jsonDecode(request.body);
        expect(body['title'], 'Software Eng');
        return http.Response(
          jsonEncode({
            'id': 'sub_2',
            'user_id': 'u_1',
            'title': 'Software Eng',
            'code': 'SE-201',
            'description': 'System design',
            'color_hex': '#10B981',
            'total_hours': 0.0,
            'target_hours': 20.0,
            'created_at': '2026-09-01T12:00:00Z',
            'updated_at': '2026-09-01T12:00:00Z',
            'topics': [],
          }),
          201,
          headers: {'content-type': 'application/json'},
        );
      });

      final repo = ApiSubjectRepository(apiClient: ApiClient(httpClient: mockClient));
      final created = await repo.createSubject(
        title: 'Software Eng',
        code: 'SE-201',
        description: 'System design',
        colorHex: '#10B981',
      );

      expect(created.id, 'sub_2');
      expect(created.code, 'SE-201');
    });
  });

  group('ApiNoteRepository', () {
    test('getNotes parses list and filters correctly', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode([
            {
              'id': 'n_1',
              'user_id': 'u_1',
              'subject_id': 'sub_1',
              'title': 'Calculus Formulas',
              'content': 'Integration by parts',
              'tags': ['Math', 'Calculus'],
              'updated_at': '2026-09-01T12:00:00Z',
              'created_at': '2026-09-01T12:00:00Z',
            },
            {
              'id': 'n_2',
              'user_id': 'u_1',
              'subject_id': 'sub_1',
              'title': 'SQL Indexing',
              'content': 'B-Trees and hash indexes',
              'tags': ['Database'],
              'updated_at': '2026-09-01T12:00:00Z',
              'created_at': '2026-09-01T12:00:00Z',
            }
          ]),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final repo = ApiNoteRepository(apiClient: ApiClient(httpClient: mockClient));
      final allNotes = await repo.getNotes();
      expect(allNotes.length, 2);

      final searchNotes = await repo.getNotes(searchQuery: 'Calculus');
      expect(searchNotes.length, 1);
      expect(searchNotes.first.title, 'Calculus Formulas');
    });
  });

  group('ApiGoalRepository', () {
    test('getGoals parses goal and milestones', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode([
            {
              'id': 'g_1',
              'user_id': 'u_1',
              'subject_id': 'sub_1',
              'title': 'Finish Project',
              'target_date': '2026-09-15T00:00:00Z',
              'is_completed': false,
              'created_at': '2026-09-01T12:00:00Z',
              'updated_at': '2026-09-01T12:00:00Z',
              'milestones': [
                {
                  'id': 'm_1',
                  'goal_id': 'g_1',
                  'title': 'Milestone 1',
                  'is_completed': true,
                  'created_at': '2026-09-01T12:00:00Z',
                }
              ],
            }
          ]),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final repo = ApiGoalRepository(apiClient: ApiClient(httpClient: mockClient));
      final goals = await repo.getGoals();
      expect(goals.length, 1);
      expect(goals.first.progress, 1.0);
    });
  });

  group('ApiSessionRepository', () {
    test('saveSession posts and computes statistics', () async {
      final mockClient = MockClient((request) async {
        if (request.method == 'GET' && request.url.path == '/api/v1/subjects') {
          return http.Response(
            jsonEncode([{'id': 'sub_1', 'title': 'Math'}]),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.method == 'POST' && request.url.path == '/api/v1/sessions') {
          return http.Response(
            jsonEncode({
              'id': 'sess_1',
              'user_id': 'u_1',
              'subject_id': 'sub_1',
              'target_duration_minutes': 45,
              'actual_duration_minutes': 45,
              'study_mode': 'Focus Mode',
              'is_focus_monitoring_enabled': true,
              'focus_score': 90,
              'distractions_count': 1,
              'reflection': 'good',
              'started_at': '2026-09-01T10:00:00Z',
              'ended_at': '2026-09-01T10:45:00Z',
              'created_at': '2026-09-01T10:45:00Z',
            }),
            201,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.method == 'GET' && request.url.path == '/api/v1/sessions') {
          return http.Response(
            jsonEncode([
              {
                'id': 'sess_1',
                'user_id': 'u_1',
                'subject_id': 'sub_1',
                'target_duration_minutes': 45,
                'actual_duration_minutes': 45,
                'study_mode': 'Focus Mode',
                'is_focus_monitoring_enabled': true,
                'focus_score': 90,
                'distractions_count': 1,
                'reflection': 'good',
                'started_at': '2026-09-01T10:00:00Z',
                'ended_at': '2026-09-01T10:45:00Z',
                'created_at': '2026-09-01T10:45:00Z',
              }
            ]),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not Found', 404);
      });

      final repo = ApiSessionRepository(apiClient: ApiClient(httpClient: mockClient));
      final saved = await repo.saveSession(
        StudySessionRecord(
          id: '',
          subjectTitle: 'Math',
          topicTitle: 'Calculus',
          durationMinutes: 45,
          focusScore: 90,
          distractionsCount: 1,
          completedAt: DateTime.now(),
        ),
      );

      expect(saved.id, 'sess_1');
      expect(saved.focusScore, 90);

      final stats = await repo.getSessionStatistics();
      expect(stats['totalMinutes'], 45);
      expect(stats['averageFocusScore'], 90);
    });
  });

  group('ApiAnalyticsRepository', () {
    test('getAnalyticsSummary computes aggregate trends from sessions', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode([
            {
              'id': 'sess_1',
              'user_id': 'u_1',
              'subject_id': 'sub_1',
              'actual_duration_minutes': 60,
              'focus_score': 85,
              'distractions_count': 4,
              'reflection': 'good',
              'started_at': '2026-09-01T10:00:00Z',
              'ended_at': '2026-09-01T11:00:00Z',
              'created_at': '2026-09-01T11:00:00Z',
            }
          ]),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final repo = ApiAnalyticsRepository(apiClient: ApiClient(httpClient: mockClient));
      final summary = await repo.getAnalyticsSummary();

      expect(summary.totalStudyTimeFormatted, '1h 0m');
      expect(summary.totalSessionsCount, 1);
      expect(summary.averageFocusScore, 85);
      expect(summary.weeklyTrends.length, 7);
      expect(summary.distractionBreakdown.length, 3);
    });
  });
}
