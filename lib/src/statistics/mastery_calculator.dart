import '../models/review_card.dart';
import 'card_statistics.dart';

/// Configuration for mastery calculation.
class MasteryConfig {
  /// Minimum interval (in days) to consider a card mastered.
  final int minimumIntervalDays;

  /// Minimum success rate to consider a card mastered.
  final double minimumSuccessRate;

  /// Minimum number of reviews before considering mastery.
  final int minimumReviews;

  /// Maximum number of lapses allowed for mastery.
  final int maximumLapses;

  /// Minimum stability score for mastery.
  final double minimumStability;

  /// Creates a mastery configuration.
  const MasteryConfig({
    this.minimumIntervalDays = 21,
    this.minimumSuccessRate = 0.8,
    this.minimumReviews = 5,
    this.maximumLapses = 3,
    this.minimumStability = 0.6,
  });

  /// Strict mastery requirements (longer interval, higher success rate).
  factory MasteryConfig.strict() => const MasteryConfig(
        minimumIntervalDays: 60,
        minimumSuccessRate: 0.9,
        minimumReviews: 8,
        maximumLapses: 1,
        minimumStability: 0.8,
      );

  /// Relaxed mastery requirements (shorter interval, lower success rate).
  factory MasteryConfig.relaxed() => const MasteryConfig(
        minimumIntervalDays: 7,
        minimumSuccessRate: 0.7,
        minimumReviews: 3,
        maximumLapses: 5,
        minimumStability: 0.4,
      );

  /// Default configuration.
  factory MasteryConfig.standard() => const MasteryConfig();

  MasteryConfig copyWith({
    int? minimumIntervalDays,
    double? minimumSuccessRate,
    int? minimumReviews,
    int? maximumLapses,
    double? minimumStability,
  }) {
    return MasteryConfig(
      minimumIntervalDays: minimumIntervalDays ?? this.minimumIntervalDays,
      minimumSuccessRate: minimumSuccessRate ?? this.minimumSuccessRate,
      minimumReviews: minimumReviews ?? this.minimumReviews,
      maximumLapses: maximumLapses ?? this.maximumLapses,
      minimumStability: minimumStability ?? this.minimumStability,
    );
  }
}

/// Mastery level classification.
enum MasteryLevel {
  /// Card has never been reviewed.
  notStarted('Not Started', 0.0),

  /// Card is in learning phase.
  learning('Learning', 0.1),

  /// Card is being reviewed but hasn't stabilized.
  familiar('Familiar', 0.3),

  /// Card shows good retention.
  proficient('Proficient', 0.6),

  /// Card is well known with long intervals.
  mastered('Mastered', 0.9),

  /// Card is deeply encoded in long-term memory.
  expert('Expert', 1.0);

  /// Human-readable label.
  final String label;

  /// Numeric threshold for this level.
  final double threshold;

  const MasteryLevel(this.label, this.threshold);
}

/// Result of mastery calculation for a card.
class MasteryResult {
  /// The card this result is for.
  final ReviewCard card;

  /// Calculated mastery score (0.0 to 1.0).
  final double score;

  /// The mastery level classification.
  final MasteryLevel level;

  /// Whether the card meets the mastery criteria.
  final bool isMastered;

  /// Breakdown of individual criteria.
  final MasteryCriteria criteria;

  /// Progress towards mastery (0.0 to 1.0).
  final double progress;

  const MasteryResult({
    required this.card,
    required this.score,
    required this.level,
    required this.isMastered,
    required this.criteria,
    required this.progress,
  });

  Map<String, dynamic> toMap() => {
        'cardId': card.id,
        'score': (score * 100).toStringAsFixed(1) + '%',
        'level': level.label,
        'isMastered': isMastered,
        'progress': (progress * 100).toStringAsFixed(1) + '%',
        'criteria': criteria.toMap(),
      };

  @override
  String toString() =>
      'MasteryResult(${card.id}: ${level.label}, ${(score * 100).toStringAsFixed(0)}%)';
}

/// Breakdown of mastery criteria checks.
class MasteryCriteria {
  final bool intervalMet;
  final bool successRateMet;
  final bool reviewCountMet;
  final bool lapseLimitMet;
  final bool stabilityMet;

  const MasteryCriteria({
    required this.intervalMet,
    required this.successRateMet,
    required this.reviewCountMet,
    required this.lapseLimitMet,
    required this.stabilityMet,
  });

  /// Number of criteria met.
  int get metCount {
    var count = 0;
    if (intervalMet) count++;
    if (successRateMet) count++;
    if (reviewCountMet) count++;
    if (lapseLimitMet) count++;
    if (stabilityMet) count++;
    return count;
  }

  /// Whether all criteria are met.
  bool get allMet =>
      intervalMet &&
      successRateMet &&
      reviewCountMet &&
      lapseLimitMet &&
      stabilityMet;

  Map<String, bool> toMap() => {
        'intervalMet': intervalMet,
        'successRateMet': successRateMet,
        'reviewCountMet': reviewCountMet,
        'lapseLimitMet': lapseLimitMet,
        'stabilityMet': stabilityMet,
      };
}

/// Calculates mastery scores and levels for cards.
///
/// Example:
/// ```dart
/// final calculator = MasteryCalculator(
///   config: MasteryConfig.standard(),
/// );
///
/// final result = calculator.calculate(card);
/// print('Mastery: ${result.level.label}');
/// print('Progress: ${(result.progress * 100).toStringAsFixed(0)}%');
/// ```
class MasteryCalculator {
  /// Configuration for mastery thresholds.
  final MasteryConfig config;

  /// Creates a mastery calculator.
  const MasteryCalculator({
    MasteryConfig? config,
  }) : config = config ?? const MasteryConfig();

  /// Calculates mastery for a single card.
  MasteryResult calculate(ReviewCard card) {
    final stats = CardStatistics(card);

    // Check individual criteria
    final intervalDays = card.intervalMinutes / (24 * 60);
    final criteria = MasteryCriteria(
      intervalMet: intervalDays >= config.minimumIntervalDays,
      successRateMet: stats.successRate >= config.minimumSuccessRate,
      reviewCountMet: stats.totalReviews >= config.minimumReviews,
      lapseLimitMet: card.lapseCount <= config.maximumLapses,
      stabilityMet: stats.stability >= config.minimumStability,
    );

    // Calculate progress towards mastery
    final intervalProgress =
        (intervalDays / config.minimumIntervalDays).clamp(0.0, 1.0);
    final successProgress =
        (stats.successRate / config.minimumSuccessRate).clamp(0.0, 1.0);
    final reviewProgress =
        (stats.totalReviews / config.minimumReviews).clamp(0.0, 1.0);
    final lapseProgress = config.maximumLapses > 0
        ? (1 - card.lapseCount / config.maximumLapses).clamp(0.0, 1.0)
        : (card.lapseCount == 0 ? 1.0 : 0.0);
    final stabilityProgress =
        (stats.stability / config.minimumStability).clamp(0.0, 1.0);

    // Weighted average for overall progress
    final progress = (intervalProgress * 0.25 +
            successProgress * 0.25 +
            reviewProgress * 0.15 +
            lapseProgress * 0.15 +
            stabilityProgress * 0.20)
        .clamp(0.0, 1.0);

    // Calculate overall mastery score
    final score = _calculateScore(card, stats, criteria);

    // Determine level
    final level = _determineLevel(card, score, criteria);

    return MasteryResult(
      card: card,
      score: score,
      level: level,
      isMastered: criteria.allMet,
      criteria: criteria,
      progress: progress,
    );
  }

  double _calculateScore(
    ReviewCard card,
    CardStatistics stats,
    MasteryCriteria criteria,
  ) {
    if (card.isNew) return 0.0;
    if (stats.totalReviews == 0) return 0.0;

    // Weighted combination of factors
    double score = 0.0;

    // Stability is the primary factor
    score += stats.stability * 0.4;

    // Success rate matters
    score += stats.successRate * 0.25;

    // Interval length indicates long-term retention
    final intervalScore =
        (card.intervalMinutes / (365 * 24 * 60)).clamp(0.0, 1.0);
    score += intervalScore * 0.2;

    // Ease factor indicates learning efficiency
    final easeScore = ((card.easeFactor - 1.3) / 1.7).clamp(0.0, 1.0);
    score += easeScore * 0.15;

    // Penalize for lapses
    if (card.lapseCount > 0) {
      score *= (1.0 - (card.lapseCount * 0.05)).clamp(0.5, 1.0);
    }

    return score.clamp(0.0, 1.0);
  }

  MasteryLevel _determineLevel(
    ReviewCard card,
    double score,
    MasteryCriteria criteria,
  ) {
    if (card.isNew) return MasteryLevel.notStarted;
    if (card.isInLearningPhase) return MasteryLevel.learning;

    if (criteria.allMet && score >= 0.9) {
      return MasteryLevel.expert;
    }
    if (criteria.allMet || score >= 0.8) {
      return MasteryLevel.mastered;
    }
    if (score >= 0.6) {
      return MasteryLevel.proficient;
    }
    if (score >= 0.3) {
      return MasteryLevel.familiar;
    }
    return MasteryLevel.learning;
  }

  /// Calculates mastery for multiple cards.
  List<MasteryResult> calculateBatch(List<ReviewCard> cards) {
    return cards.map((c) => calculate(c)).toList();
  }

  /// Gets cards at each mastery level.
  Map<MasteryLevel, List<ReviewCard>> groupByLevel(List<ReviewCard> cards) {
    final groups = <MasteryLevel, List<ReviewCard>>{};
    for (final level in MasteryLevel.values) {
      groups[level] = [];
    }

    for (final card in cards) {
      final result = calculate(card);
      groups[result.level]!.add(card);
    }

    return groups;
  }

  /// Calculates overall mastery percentage for a deck.
  double calculateDeckMastery(List<ReviewCard> cards) {
    if (cards.isEmpty) return 0.0;

    final masteredCount =
        cards.where((c) => calculate(c).isMastered).length;
    return masteredCount / cards.length;
  }

  /// Gets cards that need the most work (lowest mastery).
  List<ReviewCard> getWeakestCards(List<ReviewCard> cards, {int limit = 10}) {
    final results = calculateBatch(cards);
    results.sort((a, b) => a.score.compareTo(b.score));
    return results.take(limit).map((r) => r.card).toList();
  }

  /// Gets cards closest to mastery (good progress but not yet mastered).
  List<ReviewCard> getAlmostMastered(List<ReviewCard> cards, {int limit = 10}) {
    final results = calculateBatch(cards);
    final almostThere = results
        .where((r) => !r.isMastered && r.progress >= 0.7)
        .toList();
    almostThere.sort((a, b) => b.progress.compareTo(a.progress));
    return almostThere.take(limit).map((r) => r.card).toList();
  }
}
