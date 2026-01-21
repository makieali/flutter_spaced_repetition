import 'dart:math' as math;

import '../models/review_card.dart';
import '../models/review_log.dart';

/// Forgetting curve data point.
class ForgettingCurvePoint {
  /// Creates a forgetting curve data point.
  const ForgettingCurvePoint({
    required this.daysSinceReview,
    required this.retrievability,
  });

  /// Days since the last review.
  final double daysSinceReview;

  /// Predicted probability of recall (0.0 to 1.0).
  final double retrievability;
}

/// Generates forgetting curve data for visualization.
class ForgettingCurve {
  /// Creates a forgetting curve calculator.
  const ForgettingCurve();

  /// Generates forgetting curve points for a card.
  ///
  /// Returns a list of points showing how retrievability decays over time.
  List<ForgettingCurvePoint> generate(
    ReviewCard card, {
    int days = 30,
    int pointsPerDay = 4,
  }) {
    final stability = _getStability(card);
    if (stability <= 0) {
      // New card - return flat line at 0
      return List.generate(
        days * pointsPerDay,
        (i) => ForgettingCurvePoint(
          daysSinceReview: i / pointsPerDay,
          retrievability: 0.0,
        ),
      );
    }

    final points = <ForgettingCurvePoint>[];

    for (var i = 0; i <= days * pointsPerDay; i++) {
      final daysSinceReview = i / pointsPerDay;
      final retrievability = _calculateRetrievability(daysSinceReview, stability);
      points.add(ForgettingCurvePoint(
        daysSinceReview: daysSinceReview,
        retrievability: retrievability,
      ));
    }

    return points;
  }

  /// Calculates when retrievability drops to a target value.
  double daysUntilTarget(ReviewCard card, double targetRetention) {
    final stability = _getStability(card);
    if (stability <= 0) return 0.0;

    const factor = 19 / 81;
    const decay = -0.5;

    return stability * (math.pow(targetRetention, 1 / decay) - 1) / factor;
  }

  /// Gets the current retrievability of a card.
  double currentRetrievability(ReviewCard card, {DateTime? asOf}) {
    final now = asOf ?? DateTime.now();
    final stability = _getStability(card);
    if (stability <= 0 || card.lastReviewedAt == null) return 0.0;

    final daysSinceReview = now.difference(card.lastReviewedAt!).inMinutes / 1440;
    return _calculateRetrievability(daysSinceReview, stability);
  }

  double _getStability(ReviewCard card) {
    // Try to get FSRS stability from metadata
    if (card.metadata != null && card.metadata!.containsKey('fsrs')) {
      final fsrsData = card.metadata!['fsrs'] as Map<String, dynamic>;
      return (fsrsData['stability'] as num?)?.toDouble() ?? 0.0;
    }
    // Fallback: estimate from interval
    return card.intervalMinutes / 1440;
  }

  double _calculateRetrievability(double daysSinceReview, double stability) {
    if (daysSinceReview <= 0) return 1.0;
    const factor = 19 / 81;
    const decay = -0.5;
    return math.pow(1 + factor * daysSinceReview / stability, decay).toDouble();
  }
}

/// Daily workload forecast entry.
class WorkloadForecastDay {
  /// Creates a workload forecast entry.
  const WorkloadForecastDay({
    required this.date,
    required this.dueCount,
    required this.newCount,
    required this.reviewCount,
    required this.learningCount,
  });

  /// The date for this forecast.
  final DateTime date;

  /// Total number of cards due.
  final int dueCount;

  /// Number of new cards to introduce.
  final int newCount;

  /// Number of review phase cards due.
  final int reviewCount;

  /// Number of learning phase cards due.
  final int learningCount;
}

/// Forecasts future review workload.
class WorkloadForecast {
  /// Creates a workload forecaster.
  const WorkloadForecast();

  /// Generates a workload forecast for the next N days.
  ///
  /// Parameters:
  /// - [cards]: All cards in the deck.
  /// - [days]: Number of days to forecast.
  /// - [newCardsPerDay]: Number of new cards introduced per day.
  List<WorkloadForecastDay> generate(
    List<ReviewCard> cards, {
    int days = 30,
    int newCardsPerDay = 20,
  }) {
    final forecast = <WorkloadForecastDay>[];
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);

    // Track which new cards have been "introduced"
    var newCardsIntroduced = 0;
    final totalNewCards = cards.where((c) => c.isNew).length;

    for (var day = 0; day < days; day++) {
      final date = startOfToday.add(Duration(days: day));
      final endOfDay = date.add(const Duration(days: 1));

      var newCount = 0;
      var reviewCount = 0;
      var learningCount = 0;

      for (final card in cards) {
        if (card.isNew) {
          // Count new cards to be introduced this day
          if (newCardsIntroduced < totalNewCards) {
            final dailyNew = math.min(newCardsPerDay, totalNewCards - newCardsIntroduced);
            if (day == 0 || newCardsIntroduced + dailyNew <= totalNewCards) {
              newCount = dailyNew;
              if (day > 0) newCardsIntroduced += dailyNew;
            }
          }
        } else if (card.nextReviewTime.isBefore(endOfDay)) {
          // Card is due on or before this day
          if (card.isInLearningPhase || card.phase == CardPhase.relearning) {
            learningCount++;
          } else {
            reviewCount++;
          }
        }
      }

      if (day == 0) {
        newCardsIntroduced += newCardsPerDay;
      }

      forecast.add(WorkloadForecastDay(
        date: date,
        dueCount: newCount + reviewCount + learningCount,
        newCount: newCount,
        reviewCount: reviewCount,
        learningCount: learningCount,
      ));
    }

    return forecast;
  }

  /// Estimates total reviews needed over a period.
  int estimateTotalReviews(
    List<ReviewCard> cards, {
    int days = 30,
    int newCardsPerDay = 20,
  }) {
    final forecastDays = generate(cards, days: days, newCardsPerDay: newCardsPerDay);
    return forecastDays.fold(0, (sum, day) => sum + day.dueCount);
  }

  /// Gets the peak workload day.
  WorkloadForecastDay? getPeakDay(
    List<ReviewCard> cards, {
    int days = 30,
    int newCardsPerDay = 20,
  }) {
    final forecastDays = generate(cards, days: days, newCardsPerDay: newCardsPerDay);
    if (forecastDays.isEmpty) return null;

    return forecastDays.reduce(
      (max, day) => day.dueCount > max.dueCount ? day : max,
    );
  }

  /// Gets average daily workload.
  double getAverageWorkload(
    List<ReviewCard> cards, {
    int days = 30,
    int newCardsPerDay = 20,
  }) {
    final forecastDays = generate(cards, days: days, newCardsPerDay: newCardsPerDay);
    if (forecastDays.isEmpty) return 0.0;

    final total = forecastDays.fold(0, (sum, day) => sum + day.dueCount);
    return total / forecastDays.length;
  }
}

/// Retention analytics for review history.
class RetentionAnalytics {
  /// Creates retention analytics.
  const RetentionAnalytics();

  /// Calculates retention rate over a period.
  double calculateRetention(ReviewHistory history, {int days = 30}) {
    final recentLogs = history.lastDays(days);
    if (recentLogs.isEmpty) return 0.0;

    final successful = recentLogs.where((log) => log.wasSuccessful).length;
    return successful / recentLogs.length;
  }

  /// Calculates retention by day.
  Map<DateTime, double> retentionByDay(ReviewHistory history, {int days = 30}) {
    final result = <DateTime, double>{};
    final now = DateTime.now();

    for (var i = 0; i < days; i++) {
      final date = DateTime(now.year, now.month, now.day).subtract(Duration(days: i));
      final nextDate = date.add(const Duration(days: 1));

      final dayLogs = history.inRange(date, nextDate);
      if (dayLogs.isNotEmpty) {
        final successful = dayLogs.where((log) => log.wasSuccessful).length;
        result[date] = successful / dayLogs.length;
      }
    }

    return result;
  }

  /// Calculates true retention (weighted by retrievability).
  double calculateTrueRetention(ReviewHistory history, {int days = 30}) {
    final recentLogs = history.lastDays(days);
    if (recentLogs.isEmpty) return 0.0;

    // Weight by retrievability - lower retrievability recalls are more valuable
    var weightedSuccess = 0.0;
    var totalWeight = 0.0;

    for (final log in recentLogs) {
      final weight = 1 - (log.retrievability ?? 0.9);
      totalWeight += weight;
      if (log.wasSuccessful) {
        weightedSuccess += weight;
      }
    }

    return totalWeight > 0 ? weightedSuccess / totalWeight : 0.0;
  }

  /// Analyzes learning speed (cards graduated per day).
  double learningSpeed(ReviewHistory history, {int days = 30}) {
    // This would need graduation events tracked in logs
    // For now, estimate based on successful reviews
    final recentLogs = history.lastDays(days);
    if (recentLogs.isEmpty) return 0.0;

    final reviewsPerDay = recentLogs.length / days;
    final successRate = calculateRetention(history, days: days);

    return reviewsPerDay * successRate;
  }
}

/// Heatmap data for visualization.
class ReviewHeatmapData {
  /// Creates heatmap data.
  const ReviewHeatmapData({
    required this.date,
    required this.count,
    required this.intensity,
  });

  /// The date for this cell.
  final DateTime date;

  /// Number of reviews on this day.
  final int count;

  /// Intensity level (0.0 to 1.0) for coloring.
  final double intensity;
}

/// Generates heatmap data for review activity.
class ReviewHeatmap {
  /// Creates a review heatmap generator.
  const ReviewHeatmap();

  /// Generates heatmap data for a year.
  List<ReviewHeatmapData> generate(
    ReviewHistory history, {
    int weeks = 52,
  }) {
    final data = <ReviewHeatmapData>[];
    final reviewsPerDay = history.reviewsPerDay;

    // Find max reviews for intensity scaling
    final maxReviews = reviewsPerDay.values.isEmpty
        ? 1
        : reviewsPerDay.values.reduce(math.max);

    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);

    for (var i = weeks * 7 - 1; i >= 0; i--) {
      final date = startOfToday.subtract(Duration(days: i));
      final count = reviewsPerDay[date] ?? 0;
      final intensity = maxReviews > 0 ? count / maxReviews : 0.0;

      data.add(ReviewHeatmapData(
        date: date,
        count: count,
        intensity: intensity,
      ));
    }

    return data;
  }

  /// Gets streak information.
  ({int current, int longest}) getStreaks(ReviewHistory history) {
    final reviewsPerDay = history.reviewsPerDay;
    if (reviewsPerDay.isEmpty) return (current: 0, longest: 0);

    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);

    var currentStreak = 0;
    var longestStreak = 0;
    var tempStreak = 0;

    // Count current streak
    for (var i = 0; i < 365; i++) {
      final date = startOfToday.subtract(Duration(days: i));
      if (reviewsPerDay.containsKey(date)) {
        if (i == currentStreak) currentStreak++;
        tempStreak++;
        longestStreak = math.max(longestStreak, tempStreak);
      } else {
        tempStreak = 0;
      }
    }

    return (current: currentStreak, longest: longestStreak);
  }
}
