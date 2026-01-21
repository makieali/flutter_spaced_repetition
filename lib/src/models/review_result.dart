import 'interval_preview.dart';
import 'review_card.dart';
import 'review_quality.dart';

/// The result of processing a review.
///
/// Contains the updated card state and metadata about what changed
/// during the review. This is immutable and can be used for undo
/// functionality, analytics, or debugging.
///
/// Example:
/// ```dart
/// final result = engine.processReview(card, ReviewQuality.good);
///
/// // Get the updated card
/// final updatedCard = result.updatedCard;
///
/// // Check what happened
/// if (result.graduatedFromLearning) {
///   print('Card graduated to review phase!');
/// }
///
/// // Show the preview for the next review
/// print('Next intervals: ${result.preview}');
/// ```
class ReviewResult {
  /// The card state after the review was processed.
  final ReviewCard updatedCard;

  /// The card state before the review was processed.
  final ReviewCard previousCard;

  /// The quality rating that was given.
  final ReviewQuality quality;

  /// The interval that was assigned.
  final Duration nextInterval;

  /// Whether the card graduated from learning to review phase.
  final bool graduatedFromLearning;

  /// Whether the card lapsed from review back to learning phase.
  final bool lapsedToLearning;

  /// Whether this was the card's first review ever.
  final bool wasFirstReview;

  /// Whether the card advanced to the next learning step.
  final bool advancedLearningStep;

  /// Whether the card's ease factor changed.
  final bool easeFactorChanged;

  /// The amount the ease factor changed (positive = increased).
  final double easeFactorDelta;

  /// Preview of intervals for the next review.
  final IntervalPreview preview;

  /// When this review was processed.
  final DateTime reviewedAt;

  /// Creates a review result.
  const ReviewResult({
    required this.updatedCard,
    required this.previousCard,
    required this.quality,
    required this.nextInterval,
    required this.graduatedFromLearning,
    required this.lapsedToLearning,
    required this.wasFirstReview,
    required this.advancedLearningStep,
    required this.easeFactorChanged,
    required this.easeFactorDelta,
    required this.preview,
    required this.reviewedAt,
  });

  /// Whether this review was successful (not Again).
  bool get wasSuccessful => quality.isSuccess;

  /// Whether this review was a lapse (Again).
  bool get wasLapse => quality.isLapse;

  /// The previous interval before this review.
  Duration get previousInterval => previousCard.interval;

  /// How much the interval changed.
  Duration get intervalDelta => nextInterval - previousInterval;

  /// The ratio of new interval to old interval.
  ///
  /// Returns null if the previous interval was zero.
  double? get intervalMultiplier {
    if (previousInterval.inMinutes == 0) return null;
    return nextInterval.inMinutes / previousInterval.inMinutes;
  }

  /// Whether the card is now in the learning phase.
  bool get isNowLearning => updatedCard.isInLearningPhase;

  /// Whether the card is now in the review phase.
  bool get isNowReviewing => updatedCard.isInReviewPhase;

  /// A summary of what happened in this review.
  String get summary {
    final parts = <String>[];

    if (wasFirstReview) {
      parts.add('First review');
    }

    parts.add('Rated ${quality.label}');

    if (graduatedFromLearning) {
      parts.add('Graduated to review phase');
    } else if (lapsedToLearning) {
      parts.add('Lapsed to learning phase');
    } else if (advancedLearningStep) {
      parts.add('Advanced to next learning step');
    }

    if (easeFactorChanged) {
      final sign = easeFactorDelta >= 0 ? '+' : '';
      parts.add('Ease $sign${(easeFactorDelta * 100).toStringAsFixed(0)}%');
    }

    parts.add('Next: ${updatedCard.formattedInterval}');

    return parts.join(' • ');
  }

  /// Converts to a JSON-compatible map.
  Map<String, dynamic> toJson() => {
        'updatedCard': updatedCard.toJson(),
        'previousCard': previousCard.toJson(),
        'quality': quality.value,
        'nextInterval': nextInterval.inMilliseconds,
        'graduatedFromLearning': graduatedFromLearning,
        'lapsedToLearning': lapsedToLearning,
        'wasFirstReview': wasFirstReview,
        'advancedLearningStep': advancedLearningStep,
        'easeFactorChanged': easeFactorChanged,
        'easeFactorDelta': easeFactorDelta,
        'preview': preview.toJson(),
        'reviewedAt': reviewedAt.toIso8601String(),
      };

  /// Creates from a JSON map.
  factory ReviewResult.fromJson(Map<String, dynamic> json) {
    return ReviewResult(
      updatedCard:
          ReviewCard.fromJson(json['updatedCard'] as Map<String, dynamic>),
      previousCard:
          ReviewCard.fromJson(json['previousCard'] as Map<String, dynamic>),
      quality: ReviewQuality.fromValue(json['quality'] as int),
      nextInterval: Duration(milliseconds: json['nextInterval'] as int),
      graduatedFromLearning: json['graduatedFromLearning'] as bool,
      lapsedToLearning: json['lapsedToLearning'] as bool,
      wasFirstReview: json['wasFirstReview'] as bool,
      advancedLearningStep: json['advancedLearningStep'] as bool,
      easeFactorChanged: json['easeFactorChanged'] as bool,
      easeFactorDelta: (json['easeFactorDelta'] as num).toDouble(),
      preview: IntervalPreview.fromJson(json['preview'] as Map<String, dynamic>),
      reviewedAt: DateTime.parse(json['reviewedAt'] as String),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReviewResult &&
          runtimeType == other.runtimeType &&
          updatedCard == other.updatedCard &&
          previousCard == other.previousCard &&
          quality == other.quality &&
          reviewedAt == other.reviewedAt;

  @override
  int get hashCode => Object.hash(updatedCard, previousCard, quality, reviewedAt);

  @override
  String toString() => 'ReviewResult($summary)';
}
