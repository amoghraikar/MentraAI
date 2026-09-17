import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mentra/core/network/api_client.dart';
import 'package:mentra/features/analytics/data/repositories/api_analytics_repository.dart';
import 'package:mentra/features/auth/services/auth_service.dart';
import 'package:mentra/features/auth/services/token_storage_service.dart';
import 'package:mentra/features/goals/data/repositories/api_goal_repository.dart';
import 'package:mentra/features/notes/data/repositories/api_note_repository.dart';
import 'package:mentra/features/study_session/data/repositories/api_session_repository.dart';
import 'package:mentra/features/subjects/data/repositories/api_subject_repository.dart';

void main() {
  group('M8 Frontend Failure & Chaos Hardening Tests', () {
    test('AuthService gracefully clears stored token on 401 unauthorized session restore', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({'detail': 'Token has expired.'}),
          401,
          headers: {'content-type': 'application/json'},
        );
      });

      final storage = InMemoryTokenStorage();
      await storage.saveToken('expired_test_token');
      final authService = AuthService(
        apiClient: ApiClient(httpClient: mockClient),
        tokenStorage: storage,
      );

      final restored = await authService.restoreSession();
      expect(restored, isNull);
      expect(await storage.getToken(), isNull);
    });

    test('ApiClient throws ApiException with statusCode 500 without leaking stack traces', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({'detail': 'Internal server error'}),
          500,
          headers: {'content-type': 'application/json'},
        );
      });

      final apiClient = ApiClient(httpClient: mockClient);
      final repo = ApiSubjectRepository(apiClient: apiClient);

      try {
        await repo.getSubjects();
        fail('Expected ApiException');
      } on ApiException catch (e) {
        expect(e.statusCode, 500);
        expect(e.message, 'Internal server error');
      }
    });

    test('ApiClient throws ApiException with statusCode 500 when socket connection drops', () async {
      final mockClient = MockClient((request) async {
        throw http.ClientException('Connection refused');
      });

      final apiClient = ApiClient(httpClient: mockClient);
      final repo = ApiNoteRepository(apiClient: apiClient);

      try {
        await repo.getNotes();
        fail('Expected ApiException');
      } on ApiException catch (e) {
        expect(e.statusCode, 500);
        expect(e.message, contains('Connection refused'));
      }
    });

    test('ApiAnalyticsRepository handles network disconnection with safe fallback model', () async {
      final mockClient = MockClient((request) async {
        throw http.ClientException('No Internet');
      });

      final apiClient = ApiClient(httpClient: mockClient);
      final repo = ApiAnalyticsRepository(apiClient: apiClient);

      final summary = await repo.getAnalyticsSummary();
      expect(summary.totalStudyMinutes, 0);
      expect(summary.totalSessionsCount, 0);
      expect(summary.hasData, isFalse);
    });

    test('ApiGoalRepository and ApiSessionRepository reject invalid response formats gracefully', () async {
      final mockClient = MockClient((request) async {
        return http.Response('<!DOCTYPE html><html><body>Error</body></html>', 502);
      });

      final apiClient = ApiClient(httpClient: mockClient);
      final goalRepo = ApiGoalRepository(apiClient: apiClient);
      final sessionRepo = ApiSessionRepository(apiClient: apiClient);

      expect(() => goalRepo.getGoals(), throwsA(isA<ApiException>()));
      expect(() => sessionRepo.getSessionStatistics(), throwsA(isA<ApiException>()));
    });
  });
}
