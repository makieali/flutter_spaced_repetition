import '../models/review_card.dart';
import '../models/review_quality.dart';

/// Detailed statistics for a single card.
///
/// Provides metrics about review history, retention, and mastery.
class CardStatistics {
  /// The card these statistics are for.
  final ReviewCard card;

  /// Creates statistics for a card.
  const CardStatistics(this.card);

  /// Total number of reviews performed on this card.
  int get totalReviews => card.totalReviews;

  /// Number of successful reviews (Good or Easy responses).
  int get successfulReviews => card.successCount + card.easyCount;

  /// Number of failed reviews (Again responses).
  int get failedReviews => card.failureCount;

  /// Number of difficult reviews (Hard responses).
  int get hardReviews => card.hardCount;

  /// Number of easy reviews.
  int get easyReviews => card.easyCount;

  /// Number of times this card has lapsed.
  int get lapses => card.lapseCount;

  /// Current streak of successful reviews.
  int get currentStreak => card.streak;

  /// Longest streak of successful reviews ever achieved.
  int get longestStreak => card.longestStreak;

  /// Success rate as a percentage (0.0 to 1.0).
  ///
  /// Success = Good + Easy responses.
  double get successRate => card.successRate;

  /// Retention rate as a percentage (0.0 to 1.0).
  ///
  /// Retention = Hard + Good + Easy responses (anything that wasn't Again).
  double get retentionRate => card.retentionRate;

  /// Failure rate as a percentage (0.0 to 1.0).
  double get failureRate {
    if (totalReviews == 0) return 0.0;
    return failedReviews / totalReviews;
  }

  /// Lapse rate as a percentage (0.0 to 1.0).
  ///
  /// Only meaningful for cards that have graduated at least once.
  double get lapseRate {
    final totalGraduatedReviews = successfulReviews + hardReviews + failedReviews;
    if (totalGraduatedReviews == 0) return 0.0;
    return lapses / totalGraduatedReviews;
  }

  /// Current ease factor.
  double get easeFactor => card.easeFactor;

  /// Current interval.
  Duration get interval => card.interval;

  /// The current phase of the card.
  CardPhase get phase => card.phase;

  /// Whether this card is in the learning phase.
  bool get isLearning => card.isInLearningPhase;

  /// Whether this card is in the review phase.
  bool get isReviewing => card.isInReviewPhase;

  /// Whether this card is new.
  bool get isNew => card.isNew;

  /// Age of the card (time since creation).
  Duration get age => DateTime.now().difference(card.createdAt);

  /// Time since last review, or null if never reviewed.
  Duration? get timeSinceLastReview {
    if (card.lastReviewedAt == null) return null;
    return DateTime.now().difference(card.lastReviewedAt!);
  }

  /// Average reviews per day since card creation.
  double get reviewsPerDay {
    final days = age.inDays;
    if (days == 0) return totalReviews.toDouble();
    return totalReviews / days;
  }

  /// Stability score (higher = more stable memory).
  ///
  /// Calculated based on interval and success rate.
  /// Range: 0.0 (unstable) to 1.0 (very stable).
  double get stability {
    if (card.isNew || totalReviews == 0) return 0.0;

    // Base stability on interval (longer = more stable)
    final intervalDays = card.intervalMinutes / (24 * 60);
    final intervalFactor = (intervalDays / 365).clamp(0.0, 1.0);

    // Weight by success rate
    final successWeight = successRate;

    // Penalize for lapses
    final lapsePenalty = lapses > 0 ? 0.9 / lapses : 1.0;

    return (intervalFactor * 0.5 + successWeight * 0.5) * lapsePenalty;
  }

  /// Difficulty score (higher = more difficult card).
  ///
  /// Calculated based on ease factor, failure rate, and lapses.
  /// Range: 0.0 (easy) to 1.0 (very difficult).
  double get difficulty {
    if (card.isNew || totalReviews == 0) return 0.5; // Unknown difficulty

    // Lower ease = harder
    final easeScore = 1.0 - ((card.easeFactor - 1.3) / 1.7).clamp(0.0, 1.0);

    // Higher failure rate = harder
    final failScore = failureRate;

    // More lapses = harder
    final lapseScore = (lapses / 10.0).clamp(0.0, 1.0);

    return (easeScore * 0.4 + failScore * 0.4 + lapseScore * 0.2);
  }

  /// Predicted retention probability (based on current interval and ease).
  ///
  /// This estimates the probability of recall at the next review time.
  /// Range: 0.0 to 1.0.
  double get predictedRetention {
    if (card.isNew) return 1.0; // New cards are "perfectly retained"
    if (card.isInLearningPhase) return 0.9; // Learning cards should be fresh

    // Simple exponential decay model
    // R = e^(-t/S) where S is stability
    final timeUntilDue = card.nextReviewTime.difference(DateTime.now());
    if (timeUntilDue.isNegative) {
      // Card is overdue - retention decreases
      final overdueRatio = -timeUntilDue.inMinutes / card.intervalMinutes;
      return (0.9 * _exp(-overdueRatio * 0.5)).clamp(0.0, 1.0);
    }

    // Card is not yet due - high retention expected
    return 0.9;
  }

  double _exp(double x) {
    // Simple exponential approximation
    if (x > 10) return 0.0;
    if (x < -10) return 1.0;
    return 1.0 / (1.0 + x * x / 2 + x * x * x * x / 24);
  }

  /// Quality of the last review, or null if never reviewed.
  ReviewQuality? get lastReviewQuality => card.lastReviewQuality;

  /// Returns a map of statistics suitable for display or serialization.
  Map<String, dynamic> toMap() => {
        'cardId': card.id,
        'phase': phase.name,
        'totalReviews': totalReviews,
        'successfulReviews': successfulReviews,
        'failedReviews': failedReviews,
        'hardReviews': hardReviews,
        'easyReviews': easyReviews,
        'lapses': lapses,
        'currentStreak': currentStreak,
        'longestStreak': longestStreak,
        'successRate': (successRate * 100).toStringAsFixed(1) + '%',
        'retentionRate': (retentionRate * 100).toStringAsFixed(1) + '%',
        'failureRate': (failureRate * 100).toStringAsFixed(1) + '%',
        'easeFactor': easeFactor.toStringAsFixed(2),
        'interval': card.formattedInterval,
        'stability': (stability * 100).toStringAsFixed(1) + '%',
        'difficulty': (difficulty * 100).toStringAsFixed(1) + '%',
        'predictedRetention':
            (predictedRetention * 100).toStringAsFixed(1) + '%',
        'ageInDays': age.inDays,
        'lastReviewedAt': card.lastReviewedAt?.toIso8601String(),
      };

  @override
  String toString() => 'CardStatistics(${card.id}: '
      'success=${(successRate * 100).toStringAsFixed(0)}%, '
      'stability=${(stability * 100).toStringAsFixed(0)}%)';
}
