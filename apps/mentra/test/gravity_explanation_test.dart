import 'package:flutter_test/flutter_test.dart';
import 'package:mentra/features/ai_coach/domain/services/built_in_study_coach.dart';

void main() {
  group('AI Coach Deep Explanations Test', () {
    test('Query "explain gravity" returns authentic physics explanation without placeholders', () async {
      final response = await BuiltInStudyCoach.instance.generateResponse(
        question: 'explain gravity',
      );

      // Verify it does NOT contain the generic placeholder
      expect(response.contains('your current study material'), isFalse);
      expect(response.contains('core building block in your syllabus'), isFalse);

      // Verify authentic gravity physics content
      expect(response.toLowerCase().contains('gravity'), isTrue);
      expect(response.contains('Newton'), isTrue);
      expect(response.contains('9.8'), isTrue);
      expect(response.contains('G'), isTrue);
    });

    test('Query "what is photosynthesis" returns authentic biological explanation', () async {
      final response = await BuiltInStudyCoach.instance.generateResponse(
        question: 'what is photosynthesis',
      );

      expect(response.contains('your current study material'), isFalse);
      expect(response.toLowerCase().contains('photosynthesis'), isTrue);
      expect(response.contains('chloroplast') || response.contains('Chlorophyll') || response.contains('Calvin'), isTrue);
    });

    test('Quiz query on gravity returns specific gravity practice question', () async {
      final quiz = await BuiltInStudyCoach.instance.generateResponse(
        question: 'Quiz me',
        topicTitle: 'Gravity',
      );

      expect(quiz.contains('satellites'), isTrue);
      expect(quiz.contains('gravitational force'), isTrue);
      expect(quiz.contains('one-fourth'), isTrue);
    });
  });
}
