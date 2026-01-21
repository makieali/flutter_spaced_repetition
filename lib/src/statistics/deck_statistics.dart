import '../models/review_card.dart';
import 'card_statistics.dart';

/// Aggregate statistics for a collection of cards (deck).
///
/// Example:
/// ```dart
/// final stats = DeckStatistics(cards);
///
/// print('Total cards: ${stats.totalCards}');
/// print('Mastered: ${stats.masteredCards}');
/// print('Due today: ${stats.dueToday}');
/// print('Average retention: ${stats.averageRetention}');
/// ```
class DeckStatistics {
  /// The cards in this deck.
  final List<ReviewCard> cards;

  /// Statistics for individual cards (computed lazily).
  late final List<CardStatistics> cardStats;

  /// Creates deck statistics from a list of cards.
  DeckStatistics(this.cards) {
    cardStats = cards.map((c) => CardStatistics(c)).toList();
  }

  // ============================================================
  // COUNT STATISTICS
  // ============================================================

  /// Total number of cards in the deck.
  int get totalCards => cards.length;

  /// Number of new cards (never reviewed).
  int get newCards => cards.where((c) => c.isNew).length;

  /// Number of cards in learning phase.
  int get learningCards => cards.where((c) => c.isInLearningPhase).length;

  /// Number of cards in review phase.
  int get reviewCards => cards.where((c) => c.isInReviewPhase).length;

  /// Number of cards currently due.
  int get dueCards {
    final now = DateTime.now();
    return cards
        .where((c) =>
            now.isAfter(c.nextReviewTime) ||
            now.isAtSameMomentAs(c.nextReviewTime))
        .length;
  }

  /// Number of cards due today (by end of day).
  int get dueToday {
    final endOfDay = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
      23,
      59,
      59,
    );
    return cards.where((c) => c.nextReviewTime.isBefore(endOfDay)).length;
  }

  /// Number of overdue cards (past their scheduled time).
  int get overdueCards {
    final now = DateTime.now();
    return cards
        .where((c) => c.intervalMinutes > 0 && now.isAfter(c.nextReviewTime))
        .length;
  }

  /// Number of suspended cards.
  int get suspendedCards =>
      cards.where((c) => c.metadata?['_suspended'] == true).length;

  // ============================================================
  // MASTERY STATISTICS
  // ============================================================

  /// Number of cards considered "mastered" (high interval, high success rate).
  int get masteredCards => cardStats.where((s) => s.stability >= 0.7).length;

  /// Number of cards considered "young" (still building memory).
  int get youngCards => cardStats
      .where((s) => s.stability > 0 && s.stability < 0.3)
      .length;

  /// Number of cards considered "mature" (stable but not mastered).
  int get matureCards => cardStats
      .where((s) => s.stability >= 0.3 && s.stability < 0.7)
      .length;

  /// Number of "leech" cards (high failure rate).
  int leechCards({int lapseThreshold = 8}) =>
      cards.where((c) => c.lapseCount >= lapseThreshold).length;

  // ============================================================
  // PERFORMANCE STATISTICS
  // ============================================================

  /// Average success rate across all reviewed cards.
  double get averageSuccessRate {
    final reviewed = cardStats.where((s) => s.totalReviews > 0);
    if (reviewed.isEmpty) return 0.0;
    return reviewed.map((s) => s.successRate).reduce((a, b) => a + b) /
        reviewed.length;
  }

  /// Average retention rate across all reviewed cards.
  double get averageRetention {
    final reviewed = cardStats.where((s) => s.totalReviews > 0);
    if (reviewed.isEmpty) return 0.0;
    return reviewed.map((s) => s.retentionRate).reduce((a, b) => a + b) /
        reviewed.length;
  }

  /// Average ease factor across all cards.
  double get averageEaseFactor {
    if (cards.isEmpty) return 2.5;
    return cards.map((c) => c.easeFactor).reduce((a, b) => a + b) / cards.length;
  }

  /// Average stability across all cards.
  double get averageStability {
    if (cardStats.isEmpty) return 0.0;
    return cardStats.map((s) => s.stability).reduce((a, b) => a + b) /
        cardStats.length;
  }

  /// Average difficulty across all cards.
  double get averageDifficulty {
    if (cardStats.isEmpty) return 0.5;
    return cardStats.map((s) => s.difficulty).reduce((a, b) => a + b) /
        cardStats.length;
  }

  /// Total number of reviews performed across all cards.
  int get totalReviews =>
      cards.map((c) => c.totalReviews).fold(0, (a, b) => a + b);

  /// Total lapses across all cards.
  int get totalLapses => cards.map((c) => c.lapseCount).fold(0, (a, b) => a + b);

  // ============================================================
  // INTERVAL STATISTICS
  // ============================================================

  /// Average interval across review phase cards.
  Duration get averageInterval {
    final reviewPhase = cards.where((c) => c.isInReviewPhase);
    if (reviewPhase.isEmpty) return Duration.zero;
    final totalMinutes =
        reviewPhase.map((c) => c.intervalMinutes).fold(0, (a, b) => a + b);
    return Duration(minutes: totalMinutes ~/ reviewPhase.length);
  }

  /// Minimum interval among review phase cards.
  Duration get minInterval {
    final reviewPhase = cards.where((c) => c.isInReviewPhase);
    if (reviewPhase.isEmpty) return Duration.zero;
    final minMinutes = reviewPhase
        .map((c) => c.intervalMinutes)
        .reduce((a, b) => a < b ? a : b);
    return Duration(minutes: minMinutes);
  }

  /// Maximum interval among review phase cards.
  Duration get maxInterval {
    final reviewPhase = cards.where((c) => c.isInReviewPhase);
    if (reviewPhase.isEmpty) return Duration.zero;
    final maxMinutes = reviewPhase
        .map((c) => c.intervalMinutes)
        .reduce((a, b) => a > b ? a : b);
    return Duration(minutes: maxMinutes);
  }

  // ============================================================
  // STREAK STATISTICS
  // ============================================================

  /// Longest current streak across all cards.
  int get longestCurrentStreak {
    if (cards.isEmpty) return 0;
    return cards.map((c) => c.streak).reduce((a, b) => a > b ? a : b);
  }

  /// Longest streak ever achieved across all cards.
  int get longestStreakEver {
    if (cards.isEmpty) return 0;
    return cards.map((c) => c.longestStreak).reduce((a, b) => a > b ? a : b);
  }

  // ============================================================
  // WORKLOAD STATISTICS
  // ============================================================

  /// Estimated reviews for today.
  int get estimatedReviewsToday => dueToday;

  /// Estimated reviews for the next 7 days.
  Map<int, int> get reviewForecast {
    final forecast = <int, int>{};
    final now = DateTime.now();

    for (var i = 0; i < 7; i++) {
      final dayStart = DateTime(now.year, now.month, now.day + i);
      final dayEnd = dayStart.add(const Duration(days: 1));

      forecast[i] = cards
          .where((c) =>
              c.nextReviewTime.isAfter(dayStart) &&
              c.nextReviewTime.isBefore(dayEnd))
          .length;
    }

    return forecast;
  }

  /// Average reviews per day (based on history).
  double get averageReviewsPerDay {
    if (cards.isEmpty) return 0.0;

    // Find the oldest card
    final oldestCard = cards.reduce(
      (a, b) => a.createdAt.isBefore(b.createdAt) ? a : b,
    );
    final days = DateTime.now().difference(oldestCard.createdAt).inDays;

    if (days == 0) return totalReviews.toDouble();
    return totalReviews / days;
  }

  // ============================================================
  // DISTRIBUTION STATISTICS
  // ============================================================

  /// Distribution of cards by phase.
  Map<CardPhase, int> get phaseDistribution {
    final dist = <CardPhase, int>{};
    for (final phase in CardPhase.values) {
      dist[phase] = cards.where((c) => c.phase == phase).length;
    }
    return dist;
  }

  /// Distribution of cards by ease factor range.
  Map<String, int> get easeDistribution {
    final dist = <String, int>{
      '< 1.5': 0,
      '1.5 - 2.0': 0,
      '2.0 - 2.5': 0,
      '2.5 - 3.0': 0,
      '> 3.0': 0,
    };

    for (final card in cards) {
      if (card.easeFactor < 1.5) {
        dist['< 1.5'] = dist['< 1.5']! + 1;
      } else if (card.easeFactor < 2.0) {
        dist['1.5 - 2.0'] = dist['1.5 - 2.0']! + 1;
      } else if (card.easeFactor < 2.5) {
        dist['2.0 - 2.5'] = dist['2.0 - 2.5']! + 1;
      } else if (card.easeFactor < 3.0) {
        dist['2.5 - 3.0'] = dist['2.5 - 3.0']! + 1;
      } else {
        dist['> 3.0'] = dist['> 3.0']! + 1;
      }
    }

    return dist;
  }

  /// Distribution of cards by interval range.
  Map<String, int> get intervalDistribution {
    final dist = <String, int>{
      'Learning': 0,
      '< 1 day': 0,
      '1 - 7 days': 0,
      '1 - 4 weeks': 0,
      '1 - 3 months': 0,
      '> 3 months': 0,
    };

    for (final card in cards) {
      if (card.isInLearningPhase || card.isNew) {
        dist['Learning'] = dist['Learning']! + 1;
      } else if (card.intervalMinutes < 24 * 60) {
        dist['< 1 day'] = dist['< 1 day']! + 1;
      } else if (card.intervalMinutes < 7 * 24 * 60) {
        dist['1 - 7 days'] = dist['1 - 7 days']! + 1;
      } else if (card.intervalMinutes < 28 * 24 * 60) {
        dist['1 - 4 weeks'] = dist['1 - 4 weeks']! + 1;
      } else if (card.intervalMinutes < 90 * 24 * 60) {
        dist['1 - 3 months'] = dist['1 - 3 months']! + 1;
      } else {
        dist['> 3 months'] = dist['> 3 months']! + 1;
      }
    }

    return dist;
  }

  // ============================================================
  // OUTPUT
  // ============================================================

  /// Returns a summary map suitable for display or serialization.
  Map<String, dynamic> toMap() => {
        'totalCards': totalCards,
        'newCards': newCards,
        'learningCards': learningCards,
        'reviewCards': reviewCards,
        'dueCards': dueCards,
        'dueToday': dueToday,
        'overdueCards': overdueCards,
        'masteredCards': masteredCards,
        'youngCards': youngCards,
        'matureCards': matureCards,
        'averageSuccessRate':
            (averageSuccessRate * 100).toStringAsFixed(1) + '%',
        'averageRetention': (averageRetention * 100).toStringAsFixed(1) + '%',
        'averageEaseFactor': averageEaseFactor.toStringAsFixed(2),
        'averageStability': (averageStability * 100).toStringAsFixed(1) + '%',
        'totalReviews': totalReviews,
        'totalLapses': totalLapses,
        'averageReviewsPerDay': averageReviewsPerDay.toStringAsFixed(1),
        'longestCurrentStreak': longestCurrentStreak,
        'longestStreakEver': longestStreakEver,
        'phaseDistribution':
            phaseDistribution.map((k, v) => MapEntry(k.name, v)),
        'reviewForecast': reviewForecast,
      };

  @override
  String toString() => 'DeckStatistics('
      'total: $totalCards, '
      'due: $dueCards, '
      'mastered: $masteredCards, '
      'retention: ${(averageRetention * 100).toStringAsFixed(0)}%)';
}
