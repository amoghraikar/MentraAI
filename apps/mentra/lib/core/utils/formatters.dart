/// Domain-specific formatting utilities for Mentra.
/// Consolidates duration, timer, and relative timestamp representations across the workspace.
abstract class Formatters {
  /// Formats seconds into mm:ss (e.g. 05:30)
  static String formatTimer(int totalSeconds) {
    final s = totalSeconds.clamp(0, 999999);
    final m = s ~/ 60;
    final sec = s % 60;
    return '${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }

  /// Formats seconds into "Xm Ys" (e.g. 5m 30s)
  static String formatDurationMinutesSeconds(num totalSeconds) {
    final s = totalSeconds.toInt().clamp(0, 999999);
    final m = s ~/ 60;
    final r = s % 60;
    return '${m}m ${r.toString().padLeft(2, '0')}s';
  }

  /// Formats a DateTime into human-readable relative time (e.g. "Just now", "5m ago", "2h ago", "MM/DD")
  static String formatRelativeTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.month}/${dt.day}';
  }
}
