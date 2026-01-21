import 'dart:math' as math;

import '../models/interval_preview.dart';
import '../models/review_card.dart';
import '../models/review_quality.dart';
import '../models/review_result.dart';
import '../models/srs_settings.dart';
import 'srs_algorithm.dart';

/// Implementation of the SM-2 spaced repetition algorithm.
///
/// This is a faithful implementation of the SM-2 algorithm by Piotr Wozniak,
/// with all settings from [SRSSettings] properly applied.
///
/// Key features:
/// - Learning phase with configurable steps
/// - Review phase with ease-based intervals
/// - Proper min/max interval enforcement
/// - All ease factor adjustments use settings values
///
/// Reference: https://www.supermemo.com/en/archives1990-2015/english/ol/sm2
class SM2Algorithm with SRSAlgorithmUtils implements SRSAlgorithm {
  /// Creates an SM-2 algorithm instance.
  const SM2Algorithm();

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

    // Determine the new state based on current phase and quality
    ReviewCard updatedCard;
    bool graduatedFromLearning = false;
    bool lapsedToLearning = false;
    bool advancedLearningStep = false;

    if (card.isNew || card.isInLearningPhase) {
      // Handle learning/relearning phase
      final result = _processLearningReview(card, quality, settings, now);
      updatedCard = result.card;
      graduatedFromLearning = result.graduated;
      advancedLearningStep = result.advancedStep;
    } else {
      // Handle review phase
      final result = _processReviewPhaseReview(card, quality, settings, now);
      updatedCard = result.card;
      lapsedToLearning = result.lapsed;
    }

    // Calculate ease factor change
    final easeFactorDelta = updatedCard.easeFactor - previousCard.easeFactor;
    final easeFactorChanged = easeFactorDelta.abs() > 0.001;

    // Generate preview for next review
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

  /// Processes a review for a card in learning/relearning phase.
  _LearningResult _processLearningReview(
    ReviewCard card,
    ReviewQuality quality,
    SRSSettings settings,
    DateTime now,
  ) {
    // Update response counters
    int successCount = card.successCount;
    int failureCount = card.failureCount;
    int easyCount = card.easyCount;
    int hardCount = card.hardCount;
    int streak = card.streak;
    int longestStreak = card.longestStreak;

    switch (quality) {
      case ReviewQuality.again:
        failureCount++;
        streak = 0;
      case ReviewQuality.hard:
        hardCount++;
        // Hard in learning counts as partial success
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

    // Handle Again - reset to first learning step
    if (quality == ReviewQuality.again) {
      final interval = settings.learningSteps.first;
      return _LearningResult(
        card: card.copyWith(
          repetitions: 0,
          learningStepIndex: 0,
          intervalMinutes: interval.inMinutes,
          nextReviewTime: now.add(interval),
          phase: card.phase == CardPhase.isNew
              ? CardPhase.learning
              : card.phase,
          lastReviewedAt: now,
          lastReviewQuality: quality,
          failureCount: failureCount,
          streak: streak,
          longestStreak: longestStreak,
        ),
        graduated: false,
        advancedStep: false,
      );
    }

    // Handle Easy - immediately graduate with easy interval
    if (quality == ReviewQuality.easy) {
      final newEase = calculateNewEaseFactor(card.easeFactor, quality, settings);
      final interval = settings.easyInterval;

      return _LearningResult(
        card: card.copyWith(
          repetitions: 1,
          easeFactor: newEase,
          learningStepIndex: settings.learningSteps.length,
          intervalMinutes: interval.inMinutes,
          nextReviewTime: now.add(interval),
          phase: CardPhase.review,
          lastReviewedAt: now,
          lastReviewQuality: quality,
          successCount: successCount,
          easyCount: easyCount,
          streak: streak,
          longestStreak: longestStreak,
        ),
        graduated: true,
        advancedStep: false,
      );
    }

    // Handle Good/Hard - advance through learning steps
    int newStepIndex = card.learningStepIndex;
    int newReps = card.repetitions;

    if (quality == ReviewQuality.good) {
      newStepIndex++;
      newReps++;
    }
    // Hard keeps same step but counts as a rep

    // Check if should graduate
    final shouldGrad = hasCompletedAllSteps(newStepIndex, newReps, settings) &&
        quality == ReviewQuality.good;

    if (shouldGrad) {
      final newEase = calculateNewEaseFactor(card.easeFactor, quality, settings);
      final interval = settings.graduatingInterval;

      return _LearningResult(
        card: card.copyWith(
          repetitions: 1,
          easeFactor: newEase,
          learningStepIndex: settings.learningSteps.length,
          intervalMinutes: interval.inMinutes,
          nextReviewTime: now.add(interval),
          phase: CardPhase.review,
          lastReviewedAt: now,
          lastReviewQuality: quality,
          successCount: successCount,
          hardCount: hardCount,
          streak: streak,
          longestStreak: longestStreak,
        ),
        graduated: true,
        advancedStep: false,
      );
    }

    // Stay in learning, move to next step
    final stepIndex = newStepIndex.clamp(0, settings.learningSteps.length - 1);
    final interval = settings.learningSteps[stepIndex];

    return _LearningResult(
      card: card.copyWith(
        repetitions: newReps,
        learningStepIndex: stepIndex,
        intervalMinutes: interval.inMinutes,
        nextReviewTime: now.add(interval),
        phase: card.phase == CardPhase.isNew ? CardPhase.learning : card.phase,
        lastReviewedAt: now,
        lastReviewQuality: quality,
        successCount: successCount,
        hardCount: hardCount,
        streak: streak,
        longestStreak: longestStreak,
      ),
      graduated: false,
      advancedStep: quality == ReviewQuality.good,
    );
  }

  /// Processes a review for a card in review phase.
  _ReviewResult _processReviewPhaseReview(
    ReviewCard card,
    ReviewQuality quality,
    SRSSettings settings,
    DateTime now,
  ) {
    // Update response counters
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
        lapseCount++;
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

    // Handle lapse (Again response)
    if (quality == ReviewQuality.again) {
      final newEase = calculateNewEaseFactor(card.easeFactor, quality, settings);

      // Calculate lapsed interval
      Duration lapseInterval;
      if (settings.lapseMultiplier > 0) {
        final lapsedMinutes =
            (card.intervalMinutes * settings.lapseMultiplier).round();
        lapseInterval = Duration(
          minutes: math.max(lapsedMinutes, settings.minimumInterval.inMinutes),
        );
      } else {
        // Start from first learning step
        lapseInterval = settings.learningSteps.first;
      }

      return _ReviewResult(
        card: card.copyWith(
          repetitions: 0,
          easeFactor: newEase,
          learningStepIndex: 0,
          intervalMinutes: lapseInterval.inMinutes,
          nextReviewTime: now.add(lapseInterval),
          phase: CardPhase.relearning,
          lastReviewedAt: now,
          lastReviewQuality: quality,
          failureCount: failureCount,
          lapseCount: lapseCount,
          streak: streak,
          longestStreak: longestStreak,
        ),
        lapsed: true,
      );
    }

    // Calculate new ease factor
    final newEase = calculateNewEaseFactor(card.easeFactor, quality, settings);

    // Calculate new interval
    final newInterval = calculateInterval(
      card.copyWith(easeFactor: newEase),
      quality,
      settings,
    );

    // Apply fuzz to prevent bunching
    final fuzzedInterval = applyFuzz(newInterval, settings);

    // Clamp to bounds
    final clampedInterval = clampInterval(fuzzedInterval, settings);

    return _ReviewResult(
      card: card.copyWith(
        repetitions: card.repetitions + 1,
        easeFactor: newEase,
        intervalMinutes: clampedInterval.inMinutes,
        nextReviewTime: now.add(clampedInterval),
        lastReviewedAt: now,
        lastReviewQuality: quality,
        successCount: successCount,
        hardCount: hardCount,
        easyCount: easyCount,
        streak: streak,
        longestStreak: longestStreak,
      ),
      lapsed: false,
    );
  }

  @override
  IntervalPreview previewIntervals(ReviewCard card, SRSSettings settings) {
    return IntervalPreview(
      againInterval: _previewInterval(card, ReviewQuality.again, settings),
      hardInterval: _previewInterval(card, ReviewQuality.hard, settings),
      goodInterval: _previewInterval(card, ReviewQuality.good, settings),
      easyInterval: _previewInterval(card, ReviewQuality.easy, settings),
    );
  }

  Duration _previewInterval(
    ReviewCard card,
    ReviewQuality quality,
    SRSSettings settings,
  ) {
    if (card.isNew || card.isInLearningPhase) {
      return _previewLearningInterval(card, quality, settings);
    }
    return _previewReviewInterval(card, quality, settings);
  }

  Duration _previewLearningInterval(
    ReviewCard card,
    ReviewQuality quality,
    SRSSettings settings,
  ) {
    switch (quality) {
      case ReviewQuality.again:
        return settings.learningSteps.first;

      case ReviewQuality.hard:
        // Stay at current step
        final stepIndex =
            card.learningStepIndex.clamp(0, settings.learningSteps.length - 1);
        return settings.learningSteps[stepIndex];

      case ReviewQuality.good:
        final nextIndex = card.learningStepIndex + 1;
        if (nextIndex >= settings.learningSteps.length &&
            card.repetitions >= settings.graduationsRequired - 1) {
          return settings.graduatingInterval;
        }
        final stepIndex = nextIndex.clamp(0, settings.learningSteps.length - 1);
        return settings.learningSteps[stepIndex];

      case ReviewQuality.easy:
        return settings.easyInterval;
    }
  }

  Duration _previewReviewInterval(
    ReviewCard card,
    ReviewQuality quality,
    SRSSettings settings,
  ) {
    if (quality == ReviewQuality.again) {
      if (settings.lapseMultiplier > 0) {
        final lapsedMinutes =
            (card.intervalMinutes * settings.lapseMultiplier).round();
        return Duration(
          minutes: math.max(lapsedMinutes, settings.minimumInterval.inMinutes),
        );
      }
      return settings.learningSteps.first;
    }

    final newEase = calculateNewEaseFactor(card.easeFactor, quality, settings);
    final tempCard = card.copyWith(easeFactor: newEase);
    final interval = calculateInterval(tempCard, quality, settings);
    return clampInterval(interval, settings);
  }

  @override
  double calculateNewEaseFactor(
    double currentEase,
    ReviewQuality quality,
    SRSSettings settings,
  ) {
    double newEase = currentEase;

    switch (quality) {
      case ReviewQuality.again:
        newEase -= settings.againEasePenalty;
      case ReviewQuality.hard:
        newEase -= settings.hardEasePenalty;
      case ReviewQuality.good:
        // Good response doesn't change ease factor in SM-2
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
    if (card.isInLearningPhase || card.isNew) {
      // Learning phase intervals handled separately
      return _previewLearningInterval(card, quality, settings);
    }

    // Review phase interval calculation
    final currentInterval = card.intervalMinutes;
    double newIntervalMinutes;

    switch (quality) {
      case ReviewQuality.again:
        // Handled in lapse logic
        return settings.learningSteps.first;

      case ReviewQuality.hard:
        // Hard: current interval * hardIntervalMultiplier
        newIntervalMinutes = currentInterval * settings.hardIntervalMultiplier;

      case ReviewQuality.good:
        // Good: current interval * ease factor
        newIntervalMinutes = currentInterval * card.easeFactor;

      case ReviewQuality.easy:
        // Easy: current interval * ease factor * easy bonus
        newIntervalMinutes =
            currentInterval * card.easeFactor * settings.easyBonus;
    }

    // Ensure minimum growth
    final minGrowth = currentInterval + settings.minimumInterval.inMinutes;
    newIntervalMinutes = math.max(newIntervalMinutes, minGrowth.toDouble());

    return Duration(minutes: newIntervalMinutes.round());
  }

  @override
  bool shouldGraduate(
    ReviewCard card,
    ReviewQuality quality,
    SRSSettings settings,
  ) {
    if (!card.isInLearningPhase && !card.isNew) {
      return false;
    }

    if (quality == ReviewQuality.easy) {
      return true;
    }

    if (quality == ReviewQuality.again || quality == ReviewQuality.hard) {
      return false;
    }

    // Good response - check if completed all steps
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

/// Internal result type for learning phase processing.
class _LearningResult {
  final ReviewCard card;
  final bool graduated;
  final bool advancedStep;

  const _LearningResult({
    required this.card,
    required this.graduated,
    required this.advancedStep,
  });
}

/// Internal result type for review phase processing.
class _ReviewResult {
  final ReviewCard card;
  final bool lapsed;

  const _ReviewResult({
    required this.card,
    required this.lapsed,
  });
}
