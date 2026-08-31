import 'dart:math';
import '../../domain/models/note_model.dart';
import '../../domain/repositories/note_repository.dart';

class MockNoteRepository implements NoteRepository {
  MockNoteRepository() {
    _initDefaults();
  }

  final List<NoteModel> _notes = [];

  void _initDefaults() {
    final now = DateTime.now();
    _notes.addAll([
      NoteModel(
        id: 'note_1',
        subjectId: 'sub_1',
        subjectTitle: 'Data Analytics',
        title: 'Correlation vs Causation & Regression Foundations',
        content: '''# Correlation vs Causation & Regression Foundations

## Key Takeaways
- **Correlation** is bounded between -1.0 and +1.0. A value near 0 indicates no linear relationship.
- **Causation** requires controlled experimental validation or instrumental variables; correlation alone is never sufficient.
- **Ordinary Least Squares (OLS)** minimizes the sum of squared vertical residuals:
  `min sum((y_i - (beta_0 + beta_1 * x_i))^2)`

## Common Pitfalls
1. Confounding variables creating apparent correlations.
2. Homoscedasticity violation: when error variance increases with X, standard errors become biased.
3. Multicollinearity: check Variance Inflation Factor (VIF > 5 requires investigation).
''',
        updatedAt: now.subtract(const Duration(hours: 2)),
        tags: ['Stats', 'Formulas', 'Exam Prep'],
      ),
      NoteModel(
        id: 'note_2',
        subjectId: 'sub_2',
        subjectTitle: 'Software Engineering',
        title: 'Agile Scrum Ceremonies & Velocity Estimation',
        content: '''# Agile Scrum Ceremonies & Velocity Estimation

## 4 Core Ceremonies
1. **Sprint Planning**: Commit to Sprint Goal based on team capacity and story estimates.
2. **Daily Standup (15m)**: What was completed yesterday, what is planned today, what blockers exist.
3. **Sprint Review / Demo**: Showcase working software increments to stakeholders.
4. **Sprint Retrospective**: Continuous improvement of team processes and team health.

## Story Points & Fibonnaci Scale
- 1, 2, 3, 5, 8, 13, 21.
- Points reflect relative complexity, risk, and cognitive effort, NOT raw elapsed clock hours.
''',
        updatedAt: now.subtract(const Duration(days: 1)),
        tags: ['Agile', 'Methodology', 'Scrum'],
      ),
      NoteModel(
        id: 'note_3',
        subjectId: 'sub_3',
        subjectTitle: 'Web Programming',
        title: 'CSS Modern Layout: Flexbox vs Grid System',
        content: '''# CSS Modern Layout: Flexbox vs Grid System

## Rules of Thumb
- Use **Flexbox** for one-dimensional distribution (either row OR column).
- Use **CSS Grid** for two-dimensional grid layouts with explicit columns and rows.

```css
/* Clean Card Grid Pattern */
.card-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(280px, 1fr));
  gap: 16px;
}
```
''',
        updatedAt: now.subtract(const Duration(days: 3)),
        tags: ['CSS', 'Layouts', 'Web Dev'],
      ),
    ]);
  }

  @override
  Future<List<NoteModel>> getNotes({String? searchQuery, String? subjectId}) async {
    return _notes.where((n) {
      if (subjectId != null && n.subjectId != subjectId) return false;
      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        final q = searchQuery.toLowerCase();
        return n.title.toLowerCase().contains(q) ||
            n.content.toLowerCase().contains(q) ||
            n.subjectTitle.toLowerCase().contains(q) ||
            n.tags.any((t) => t.toLowerCase().contains(q));
      }
      return true;
    }).toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  @override
  Future<NoteModel?> getNoteById(String id) async {
    try {
      return _notes.firstWhere((n) => n.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<NoteModel> createNote({
    required String title,
    required String subjectId,
    required String subjectTitle,
    String content = '',
    List<String> tags = const [],
  }) async {
    final note = NoteModel(
      id: 'note_${Random().nextInt(999999)}',
      subjectId: subjectId,
      subjectTitle: subjectTitle,
      title: title,
      content: content,
      updatedAt: DateTime.now(),
      tags: tags,
    );
    _notes.insert(0, note);
    return note;
  }

  @override
  Future<NoteModel> updateNote(NoteModel note) async {
    final index = _notes.indexWhere((n) => n.id == note.id);
    if (index != -1) {
      final updated = note.copyWith(updatedAt: DateTime.now());
      _notes[index] = updated;
      return updated;
    }
    throw Exception('Note not found');
  }

  @override
  Future<void> deleteNote(String id) async {
    _notes.removeWhere((n) => n.id == id);
  }
}
