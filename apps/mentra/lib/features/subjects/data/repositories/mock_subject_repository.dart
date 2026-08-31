import 'dart:math';
import '../../domain/models/subject_model.dart';
import '../../domain/models/topic_model.dart';
import '../../domain/repositories/subject_repository.dart';

class MockSubjectRepository implements SubjectRepository {
  MockSubjectRepository() {
    _initDefaults();
  }

  final List<SubjectModel> _subjects = [];

  void _initDefaults() {
    _subjects.addAll([
      const SubjectModel(
        id: 'sub_1',
        title: 'Data Analytics',
        code: 'CS-401',
        description: 'Statistical modeling, regression methods, and hypothesis testing.',
        colorHex: '#3B82F6',
        totalHours: 18.5,
        targetHours: 24.0,
        topics: [
          TopicModel(
            id: 'top_101',
            subjectId: 'sub_1',
            title: 'Correlation & Covariance',
            description: 'Pearson and Spearman rank correlation coefficients with significance testing.',
            progress: 0.90,
            totalMinutes: 240,
            keyConcepts: [
              'Covariance formula and units',
              'Pearson correlation r (-1 to +1)',
              'Spearman rank correlation for non-linear monotonic trends',
              'Spurious correlation vs causation',
            ],
            notesSnippet: 'Correlation measures the degree of linear association between two variables.',
            isCompleted: false,
          ),
          TopicModel(
            id: 'top_102',
            subjectId: 'sub_1',
            title: 'Linear & Multiple Regression',
            description: 'Ordinary Least Squares (OLS), residual analysis, and R-squared interpretation.',
            progress: 0.75,
            totalMinutes: 310,
            keyConcepts: [
              'OLS cost function minimization',
              'Assumptions: Linearity, Homoscedasticity, Normality of residuals',
              'Adjusted R-squared penalty',
              'Multicollinearity & Variance Inflation Factor (VIF)',
            ],
            notesSnippet: 'Minimizing the sum of squared residuals produces optimal slope and intercept coefficients.',
            isCompleted: false,
          ),
          TopicModel(
            id: 'top_103',
            subjectId: 'sub_1',
            title: 'Probability Distributions',
            description: 'Discrete & continuous distributions, Central Limit Theorem.',
            progress: 0.60,
            totalMinutes: 180,
            keyConcepts: [
              'Binomial and Poisson distributions',
              'Normal distribution and Z-score standardization',
              'Central Limit Theorem application',
            ],
            notesSnippet: 'As sample size grows, sample mean distribution approaches normal distribution regardless of population shape.',
            isCompleted: false,
          ),
          TopicModel(
            id: 'top_104',
            subjectId: 'sub_1',
            title: 'Hypothesis Testing & ANOVA',
            description: 'p-values, Type I/II errors, and one-way ANOVA.',
            progress: 0.40,
            totalMinutes: 150,
            keyConcepts: [
              'Null vs Alternative hypothesis',
              'Significance level alpha and p-value decision rule',
              'One-tailed vs Two-tailed tests',
              'F-statistic in ANOVA',
            ],
            notesSnippet: 'Reject null hypothesis when p-value is less than the predetermined significance threshold.',
            isCompleted: false,
          ),
        ],
      ),
      const SubjectModel(
        id: 'sub_2',
        title: 'Software Engineering',
        code: 'CS-302',
        description: 'Agile architectures, software lifecycles, patterns, and team engineering.',
        colorHex: '#10B981',
        totalHours: 14.2,
        targetHours: 20.0,
        topics: [
          TopicModel(
            id: 'top_201',
            subjectId: 'sub_2',
            title: 'Agile Methodology & Scrum',
            description: 'Sprints, daily standups, backlog refinement, and velocity metrics.',
            progress: 0.85,
            totalMinutes: 280,
            keyConcepts: [
              'Agile Manifesto 4 values & 12 principles',
              'Scrum ceremonies: Planning, Daily, Review, Retrospective',
              'Story points estimation & Planning Poker',
            ],
            notesSnippet: 'Iterative value delivery prioritizes working software and customer collaboration.',
            isCompleted: false,
          ),
          TopicModel(
            id: 'top_202',
            subjectId: 'sub_2',
            title: 'Extreme Programming & TDD',
            description: 'Test-driven development cycle: Red-Green-Refactor, paired programming.',
            progress: 0.65,
            totalMinutes: 210,
            keyConcepts: [
              'Red-Green-Refactor cycle',
              'Unit testing vs Integration testing',
              'Mocking & Test doubles',
            ],
            notesSnippet: 'Write failing tests first to establish rigorous requirements and prevent regression.',
            isCompleted: false,
          ),
          TopicModel(
            id: 'top_203',
            subjectId: 'sub_2',
            title: 'System Design Patterns',
            description: 'Factory, Observer, Strategy, and Clean Architecture boundaries.',
            progress: 0.50,
            totalMinutes: 190,
            keyConcepts: [
              'SOLID design principles',
              'Dependency Inversion Principle (DIP)',
              'Repository & Clean Architecture layer separation',
            ],
            notesSnippet: 'High-level modules should not depend on low-level modules; both should depend on abstractions.',
            isCompleted: false,
          ),
        ],
      ),
      const SubjectModel(
        id: 'sub_3',
        title: 'Web Programming',
        code: 'CS-205',
        description: 'Modern front-end, DOM manipulation, asynchronous JavaScript, and REST APIs.',
        colorHex: '#8B5CF6',
        totalHours: 10.0,
        targetHours: 18.0,
        topics: [
          TopicModel(
            id: 'top_301',
            subjectId: 'sub_3',
            title: 'HTML5 & Semantic Structure',
            description: 'Semantic tags, accessibility ARIA attributes, and DOM layout.',
            progress: 0.95,
            totalMinutes: 190,
            keyConcepts: [
              'Semantic elements (article, section, nav, aside)',
              'Accessible labels and headings hierarchy',
            ],
            notesSnippet: 'Semantic markup improves SEO, screen reader accessibility, and readability.',
            isCompleted: true,
          ),
          TopicModel(
            id: 'top_302',
            subjectId: 'sub_3',
            title: 'Modern CSS & Flexbox / Grid',
            description: 'Responsive layout systems, CSS variables, and fluid typography.',
            progress: 0.70,
            totalMinutes: 220,
            keyConcepts: [
              'Flexbox axis alignment & flex-grow/shrink',
              'CSS Grid template areas and auto-fit',
              'CSS Custom properties / design tokens',
            ],
            notesSnippet: 'Combine Flexbox for 1D component layouts with Grid for 2D page framing.',
            isCompleted: false,
          ),
          TopicModel(
            id: 'top_303',
            subjectId: 'sub_3',
            title: 'JavaScript ES6+ & Async/Await',
            description: 'Promises, Event loop, Microtasks, Closures, and Modules.',
            progress: 0.45,
            totalMinutes: 160,
            keyConcepts: [
              'Event Loop & Task Queue',
              'Promises & async/await error handling',
              'Array higher-order functions (map, filter, reduce)',
            ],
            notesSnippet: 'Async/await provides synchronous-looking syntax over Promise chains without blocking execution.',
            isCompleted: false,
          ),
        ],
      ),
    ]);
  }

  @override
  Future<List<SubjectModel>> getSubjects() async {
    return List.unmodifiable(_subjects);
  }

  @override
  Future<SubjectModel?> getSubjectById(String id) async {
    try {
      return _subjects.firstWhere((s) => s.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<SubjectModel> createSubject({
    required String title,
    required String code,
    required String description,
    required String colorHex,
  }) async {
    final newSubject = SubjectModel(
      id: 'sub_${Random().nextInt(999999)}',
      title: title,
      code: code,
      description: description,
      colorHex: colorHex,
      totalHours: 0.0,
      targetHours: 20.0,
      topics: [],
    );
    _subjects.add(newSubject);
    return newSubject;
  }

  @override
  Future<SubjectModel> updateSubject(SubjectModel subject) async {
    final index = _subjects.indexWhere((s) => s.id == subject.id);
    if (index != -1) {
      _subjects[index] = subject;
      return subject;
    }
    throw Exception('Subject not found');
  }

  @override
  Future<void> deleteSubject(String id) async {
    _subjects.removeWhere((s) => s.id == id);
  }

  @override
  Future<TopicModel> addTopic({
    required String subjectId,
    required String title,
    required String description,
    List<String> keyConcepts = const [],
  }) async {
    final subjectIndex = _subjects.indexWhere((s) => s.id == subjectId);
    if (subjectIndex == -1) throw Exception('Subject not found');

    final newTopic = TopicModel(
      id: 'top_${Random().nextInt(999999)}',
      subjectId: subjectId,
      title: title,
      description: description,
      progress: 0.0,
      totalMinutes: 0,
      keyConcepts: keyConcepts,
    );

    final current = _subjects[subjectIndex];
    _subjects[subjectIndex] = current.copyWith(
      topics: [...current.topics, newTopic],
    );
    return newTopic;
  }

  @override
  Future<TopicModel> updateTopic(TopicModel topic) async {
    final subjectIndex = _subjects.indexWhere((s) => s.id == topic.subjectId);
    if (subjectIndex == -1) throw Exception('Subject not found');

    final subject = _subjects[subjectIndex];
    final topicIndex = subject.topics.indexWhere((t) => t.id == topic.id);
    if (topicIndex == -1) throw Exception('Topic not found');

    final updatedTopics = List<TopicModel>.from(subject.topics);
    updatedTopics[topicIndex] = topic;

    _subjects[subjectIndex] = subject.copyWith(topics: updatedTopics);
    return topic;
  }

  @override
  Future<void> deleteTopic(String subjectId, String topicId) async {
    final subjectIndex = _subjects.indexWhere((s) => s.id == subjectId);
    if (subjectIndex == -1) return;

    final subject = _subjects[subjectIndex];
    final updatedTopics = subject.topics.where((t) => t.id != topicId).toList();
    _subjects[subjectIndex] = subject.copyWith(topics: updatedTopics);
  }
}
