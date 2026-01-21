import '../models/interval_preview.dart';
import '../models/review_card.dart';
import '../models/review_quality.dart';
import '../models/review_result.dart';
import '../models/srs_settings.dart';
import 'srs_algorithm.dart';

/// Callback type for processing reviews in a custom algorithm.
typedef ReviewProcessor = ReviewCard Function(
  ReviewCard card,
  ReviewQuality quality,
  SRSSettings settings,
  DateTime reviewTime,
);

/// Callback type for calculating intervals in a custom algorithm.
typedef IntervalCalculator = Duration Function(
  ReviewCard card,
  ReviewQuality quality,
  SRSSettings settings,
);

/// Callback type for calculating ease factor in a custom algorithm.
typedef EaseCalculator = double Function(
  double currentEase,
  ReviewQuality quality,
  SRSSettings settings,
);

/// A fully customizable spaced repetition algorithm.
///
/// This class allows you to inject your own logic for any part of
/// the algorithm while using default implementations for the rest.
///
/// Example:
/// ```dart
/// final customAlgorithm = CustomAlgorithm(
///   intervalCalculator: (card, quality, settings) {
///     // Your custom interval logic
///     return Duration(days: card.repetitions + 1);
///   },
///   easeCalculator: (ease, quality, settings) {
///     // Your custom ease factor logic
///     return quality == ReviewQuality.easy ? ease + 0.2 : ease;
///   },
/// );
/// ```
class CustomAlgorithm with SRSAlgorithmUtils implements SRSAlgorithm {
  /// Custom function for processing reviews.
  /// If null, uses default SM-2 based processing.
  final ReviewProcessor? reviewProcessor;

  /// Custom function for calculating intervals.
  /// If null, uses default interval calculation.
  final IntervalCalculator? intervalCalculator;

  /// Custom function for calculating ease factor.
  /// If null, uses default ease calculation.
  final EaseCalculator? easeCalculator;

  /// Creates a custom algorithm with optional override functions.
  const CustomAlgorithm({
    this.reviewProcessor,
    this.intervalCalculator,
    this.easeCalculator,
  });

  @override
  ReviewResult processReview(
    ReviewCard card,
    ReviewQuality quality,
    SRSSettings settings, {
    DateTime? reviewTime,
  }) {
    final now = reviewTime ?? DateTime.now();
    final wasFirstReview = card.isNew;
    final previousCard = card;

    // Use custom processor or default logic
    final updatedCard = reviewProcessor != null
        ? reviewProcessor!(card, quality, settings, now)
        : _defaultProcessReview(card, quality, settings, now);

    // Determine state changes
    final graduatedFromLearning = previousCard.isInLearningPhase &&
        updatedCard.isInReviewPhase;
    final lapsedToLearning = previousCard.isInReviewPhase &&
        updatedCard.isInLearningPhase;
    final advancedLearningStep = previousCard.isInLearningPhase &&
        updatedCard.isInLearningPhase &&
        updatedCard.learningStepIndex > previousCard.learningStepIndex;

    final easeFactorDelta = updatedCard.easeFactor - previousCard.easeFactor;
    final easeFactorChanged = easeFactorDelta.abs() > 0.001;

    final preview = previewIntervals(updatedCard, settings);

    return ReviewResult(
      updatedCard: updatedCard,
      previousCard: previousCard,
      quality: quality,
      nextInterval: updatedCard.interval,
      graduatedFromLearning: graduatedFromLearning,
      lapsedToLearning: lapsedToLearning,
      wasFirstReview: wasFirstReview,
      advancedLearningStep: advancedLearningStep,
      easeFactorChanged: easeFactorChanged,
      easeFactorDelta: easeFactorDelta,
      preview: preview,
      reviewedAt: now,
    );
  }

  ReviewCard _defaultProcessReview(
    ReviewCard card,
    ReviewQuality quality,
    SRSSettings settings,
    DateTime now,
  ) {
    // Update counters
    int successCount = card.successCount;
    int failureCount = card.failureCount;
    int easyCount = card.easyCount;
    int hardCount = card.hardCount;
    int lapseCount = card.lapseCount;
    int streak = card.streak;
    int longestStreak = card.longestStreak;

    switch (quality) {
      case ReviewQuality.again:
        failureCount++;
        if (card.isInReviewPhase) lapseCount++;
        streak = 0;
      case ReviewQuality.hard:
        hardCount++;
        streak++;
      case ReviewQuality.good:
        successCount++;
        streak++;
      case ReviewQuality.easy:
        successCount++;
        easyCount++;
        streak++;
    }

    if (streak > longestStreak) {
      longestStreak = streak;
    }

    final newEase = calculateNewEaseFactor(card.easeFactor, quality, settings);
    final newInterval = calculateInterval(
      card.copyWith(easeFactor: newEase),
      quality,
      settings,
    );

    // Determine new phase
    CardPhase newPhase;
    int newStepIndex = card.learningStepIndex;
    int newReps = card.repetitions;

    if (card.isNew || card.isInLearningPhase) {
      if (quality == ReviewQuality.again) {
        newPhase = CardPhase.learning;
        newStepIndex = 0;
        newReps = 0;
      } else if (quality == ReviewQuality.easy) {
        newPhase = CardPhase.review;
        newStepIndex = settings.learningSteps.length;
        newReps = 1;
      } else if (shouldGraduate(card, quality, settings)) {
        newPhase = CardPhase.review;
        newStepIndex = settings.learningSteps.length;
        newReps = 1;
      } else {
        newPhase = CardPhase.learning;
        if (quality == ReviewQuality.good) {
          newStepIndex = (card.learningStepIndex + 1)
              .clamp(0, settings.learningSteps.length - 1);
          newReps = card.repetitions + 1;
        }
      }
    } else {
      // Review phase
      if (quality == ReviewQuality.again) {
        newPhase = CardPhase.relearning;
        newStepIndex = 0;
        newReps = 0;
      } else {
        newPhase = CardPhase.review;
        newReps = card.repetitions + 1;
      }
    }

    final clampedInterval = clampInterval(newInterval, settings);

    return card.copyWith(
      repetitions: newReps,
      easeFactor: newEase,
      learningStepIndex: newStepIndex,
      intervalMinutes: clampedInterval.inMinutes,
      nextReviewTime: now.add(clampedInterval),
      phase: newPhase,
      lastReviewedAt: now,
      lastReviewQuality: quality,
      successCount: successCount,
      failureCount: failureCount,
      easyCount: easyCount,
      hardCount: hardCount,
      lapseCount: lapseCount,
      streak: streak,
      longestStreak: longestStreak,
    );
  }

  @override
  IntervalPreview previewIntervals(ReviewCard card, SRSSettings settings) {
    return IntervalPreview(
      againInterval: calculateInterval(card, ReviewQuality.again, settings),
      hardInterval: calculateInterval(card, ReviewQuality.hard, settings),
      goodInterval: calculateInterval(card, ReviewQuality.good, settings),
      easyInterval: calculateInterval(card, ReviewQuality.easy, settings),
    );
  }

  @override
  double calculateNewEaseFactor(
    double currentEase,
    ReviewQuality quality,
    SRSSettings settings,
  ) {
    if (easeCalculator != null) {
      return clampEaseFactor(
        easeCalculator!(currentEase, quality, settings),
        settings,
      );
    }

    // Default ease calculation
    double newEase = currentEase;
    switch (quality) {
      case ReviewQuality.again:
        newEase -= settings.againEasePenalty;
      case ReviewQuality.hard:
        newEase -= settings.hardEasePenalty;
      case ReviewQuality.good:
        break;
      case ReviewQuality.easy:
        newEase += settings.easyEaseBonus;
    }
    return clampEaseFactor(newEase, settings);
  }

  @override
  Duration calculateInterval(
    ReviewCard card,
    ReviewQuality quality,
    SRSSettings settings,
  ) {
    if (intervalCalculator != null) {
      return clampInterval(
        intervalCalculator!(card, quality, settings),
        settings,
      );
    }

    // Default interval calculation
    if (card.isNew || card.isInLearningPhase) {
      switch (quality) {
        case ReviewQuality.again:
          return settings.learningSteps.first;
        case ReviewQuality.hard:
          final idx =
              card.learningStepIndex.clamp(0, settings.learningSteps.length - 1);
          return settings.learningSteps[idx];
        case ReviewQuality.good:
          if (shouldGraduate(card, quality, settings)) {
            return settings.graduatingInterval;
          }
          final nextIdx = (card.learningStepIndex + 1)
              .clamp(0, settings.learningSteps.length - 1);
          return settings.learningSteps[nextIdx];
        case ReviewQuality.easy:
          return settings.easyInterval;
      }
    }

    // Review phase
    switch (quality) {
      case ReviewQuality.again:
        if (settings.lapseMultiplier > 0) {
          return Duration(
            minutes: (card.intervalMinutes * settings.lapseMultiplier).round(),
          );
        }
        return settings.learningSteps.first;
      case ReviewQuality.hard:
        return Duration(
          minutes:
              (card.intervalMinutes * settings.hardIntervalMultiplier).round(),
        );
      case ReviewQuality.good:
        return Duration(
          minutes: (card.intervalMinutes * card.easeFactor).round(),
        );
      case ReviewQuality.easy:
        return Duration(
          minutes:
              (card.intervalMinutes * card.easeFactor * settings.easyBonus)
                  .round(),
        );
    }
  }

  @override
  bool shouldGraduate(
    ReviewCard card,
    ReviewQuality quality,
    SRSSettings settings,
  ) {
    if (!card.isInLearningPhase && !card.isNew) return false;
    if (quality == ReviewQuality.easy) return true;
    if (quality != ReviewQuality.good) return false;

    final nextStepIndex = card.learningStepIndex + 1;
    final nextReps = card.repetitions + 1;

    return nextStepIndex >= settings.learningSteps.length &&
        nextReps >= settings.graduationsRequired;
  }

  @override
  bool shouldLapse(
    ReviewCard card,
    ReviewQuality quality,
    SRSSettings settings,
  ) {
    return card.isInReviewPhase && quality == ReviewQuality.again;
  }
}
