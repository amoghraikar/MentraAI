class NoteItem {
  const NoteItem({
    required this.id,
    required this.title,
    required this.subject,
    required this.snippet,
    required this.lastModified,
  });

  final String id;
  final String title;
  final String subject;
  final String snippet;
  final String lastModified;
}

class MockNotesData {
  static const List<NoteItem> notes = [
    NoteItem(
      id: 'note-1',
      title: 'Correlation & Regression',
      subject: 'Data Analytics',
      snippet: 'Pearson r coefficient measures linear relationship between two continuous variables...',
      lastModified: '2 hours ago',
    ),
    NoteItem(
      id: 'note-2',
      title: 'Software Engineering — Agile',
      subject: 'Software Engineering',
      snippet: 'Scrum artifacts include Product Backlog, Sprint Backlog, and Increment with timeboxed ceremonies...',
      lastModified: 'Yesterday',
    ),
    NoteItem(
      id: 'note-3',
      title: 'HTML & CSS Architecture',
      subject: 'Web Programming',
      snippet: 'Semantic HTML5 structure and CSS Flexbox / Grid layout models for desktop and responsive views...',
      lastModified: '3 days ago',
    ),
  ];
}
