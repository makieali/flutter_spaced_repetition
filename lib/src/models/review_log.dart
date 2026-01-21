import 'review_quality.dart';

/// A record of a single review event.
///
/// ReviewLog captures all the information about a review for analytics,
/// optimization, and history tracking purposes.
class ReviewLog {
  /// Creates a new review log entry.
  const ReviewLog({
    required this.cardId,
    required this.reviewTime,
    required this.rating,
    required this.scheduledInterval,
    required this.actualInterval,
    this.retrievability,
    this.stabilityBefore,
    this.stabilityAfter,
    this.difficultyBefore,
    this.difficultyAfter,
    this.easeFactorBefore,
    this.easeFactorAfter,
    this.algorithm,
    this.reviewDurationMs,
  });

  /// Creates from JSON.
  factory ReviewLog.fromJson(Map<String, dynamic> json) => ReviewLog(
        cardId: json['cardId'] as String,
        reviewTime: DateTime.parse(json['reviewTime'] as String),
        rating: ReviewQuality.fromValue(json['rating'] as int),
        scheduledInterval:
            Duration(minutes: json['scheduledIntervalMinutes'] as int),
        actualInterval:
            Duration(minutes: json['actualIntervalMinutes'] as int),
        retrievability: json['retrievability'] as double?,
        stabilityBefore: json['stabilityBefore'] as double?,
        stabilityAfter: json['stabilityAfter'] as double?,
        difficultyBefore: json['difficultyBefore'] as double?,
        difficultyAfter: json['difficultyAfter'] as double?,
        easeFactorBefore: json['easeFactorBefore'] as double?,
        easeFactorAfter: json['easeFactorAfter'] as double?,
        algorithm: json['algorithm'] as String?,
        reviewDurationMs: json['reviewDurationMs'] as int?,
      );

  /// Unique identifier for the card that was reviewed.
  final String cardId;

  /// When the review occurred.
  final DateTime reviewTime;

  /// The quality rating given by the user.
  final ReviewQuality rating;

  /// The interval that was scheduled before this review.
  final Duration scheduledInterval;

  /// The actual time elapsed since the last review.
  final Duration actualInterval;

  /// The predicted retrievability at the time of review (0.0 to 1.0).
  final double? retrievability;

  /// The card's stability before this review.
  final double? stabilityBefore;

  /// The card's stability after this review.
  final double? stabilityAfter;

  /// The card's difficulty before this review.
  final double? difficultyBefore;

  /// The card's difficulty after this review.
  final double? difficultyAfter;

  /// The ease factor before this review (for SM-2 compatibility).
  final double? easeFactorBefore;

  /// The ease factor after this review (for SM-2 compatibility).
  final double? easeFactorAfter;

  /// The algorithm used for this review.
  final String? algorithm;

  /// Duration of the review in milliseconds (time to answer).
  final int? reviewDurationMs;

  /// Whether this review was successful (Good or Easy).
  bool get wasSuccessful =>
      rating == ReviewQuality.good || rating == ReviewQuality.easy;

  /// Whether this review was a failure (Again).
  bool get wasFailure => rating == ReviewQuality.again;

  /// Whether the card was overdue when reviewed.
  bool get wasOverdue => actualInterval > scheduledInterval;

  /// How much the card was overdue by (negative if reviewed early).
  Duration get overdueAmount => actualInterval - scheduledInterval;

  /// Converts to JSON for persistence.
  Map<String, dynamic> toJson() => {
        'cardId': cardId,
        'reviewTime': reviewTime.toIso8601String(),
        'rating': rating.value,
        'scheduledIntervalMinutes': scheduledInterval.inMinutes,
        'actualIntervalMinutes': actualInterval.inMinutes,
        if (retrievability != null) 'retrievability': retrievability,
        if (stabilityBefore != null) 'stabilityBefore': stabilityBefore,
        if (stabilityAfter != null) 'stabilityAfter': stabilityAfter,
        if (difficultyBefore != null) 'difficultyBefore': difficultyBefore,
        if (difficultyAfter != null) 'difficultyAfter': difficultyAfter,
        if (easeFactorBefore != null) 'easeFactorBefore': easeFactorBefore,
        if (easeFactorAfter != null) 'easeFactorAfter': easeFactorAfter,
        if (algorithm != null) 'algorithm': algorithm,
        if (reviewDurationMs != null) 'reviewDurationMs': reviewDurationMs,
      };

  @override
  String toString() =>
      'ReviewLog(cardId: $cardId, rating: ${rating.label}, time: $reviewTime)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReviewLog &&
          cardId == other.cardId &&
          reviewTime == other.reviewTime &&
          rating == other.rating;

  @override
  int get hashCode => Object.hash(cardId, reviewTime, rating);
}

/// A collection of review logs with utility methods.
class ReviewHistory {
  /// Creates a new review history.
  ReviewHistory([List<ReviewLog>? logs]) : _logs = logs ?? [];

  /// Creates from JSON.
  factory ReviewHistory.fromJson(List<dynamic> json) => ReviewHistory(
        json
            .map((item) => ReviewLog.fromJson(item as Map<String, dynamic>))
            .toList(),
      );

  final List<ReviewLog> _logs;

  /// All logs in chronological order.
  List<ReviewLog> get logs => List.unmodifiable(_logs);

  /// Number of reviews in history.
  int get length => _logs.length;

  /// Whether the history is empty.
  bool get isEmpty => _logs.isEmpty;

  /// Whether the history is not empty.
  bool get isNotEmpty => _logs.isNotEmpty;

  /// Adds a new log entry.
  void add(ReviewLog log) {
    _logs.add(log);
  }

  /// Gets all logs for a specific card.
  List<ReviewLog> forCard(String cardId) =>
      _logs.where((log) => log.cardId == cardId).toList();

  /// Gets logs within a date range.
  List<ReviewLog> inRange(DateTime start, DateTime end) => _logs
      .where(
        (log) =>
            log.reviewTime.isAfter(start) && log.reviewTime.isBefore(end),
      )
      .toList();

  /// Gets logs for today.
  List<ReviewLog> get today {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    return inRange(startOfDay, endOfDay);
  }

  /// Gets logs for the last N days.
  List<ReviewLog> lastDays(int days) {
    final now = DateTime.now();
    final start = now.subtract(Duration(days: days));
    return _logs.where((log) => log.reviewTime.isAfter(start)).toList();
  }

  /// Total number of successful reviews.
  int get totalSuccessful => _logs.where((log) => log.wasSuccessful).length;

  /// Total number of failed reviews.
  int get totalFailed => _logs.where((log) => log.wasFailure).length;

  /// Overall success rate.
  double get successRate =>
      _logs.isEmpty ? 0.0 : totalSuccessful / _logs.length;

  /// Average retrievability at time of review.
  double get averageRetrievability {
    final logsWithRetrievability =
        _logs.where((log) => log.retrievability != null).toList();
    if (logsWithRetrievability.isEmpty) return 0.0;
    return logsWithRetrievability
            .map((log) => log.retrievability!)
            .reduce((a, b) => a + b) /
        logsWithRetrievability.length;
  }

  /// Reviews per day over the history period.
  Map<DateTime, int> get reviewsPerDay {
    final result = <DateTime, int>{};
    for (final log in _logs) {
      final day = DateTime(
        log.reviewTime.year,
        log.reviewTime.month,
        log.reviewTime.day,
      );
      result[day] = (result[day] ?? 0) + 1;
    }
    return result;
  }

  /// Converts to JSON.
  List<Map<String, dynamic>> toJson() =>
      _logs.map((log) => log.toJson()).toList();

  /// Clears all history.
  void clear() => _logs.clear();

  /// Removes logs older than the specified date.
  void pruneOlderThan(DateTime date) {
    _logs.removeWhere((log) => log.reviewTime.isBefore(date));
  }
}
