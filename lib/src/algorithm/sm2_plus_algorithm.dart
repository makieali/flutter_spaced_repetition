import 'dart:math' as math;

import '../models/interval_preview.dart';
import '../models/review_card.dart';
import '../models/review_quality.dart';
import '../models/review_result.dart';
import '../models/srs_settings.dart';
import 'srs_algorithm.dart';

/// Enhanced SM-2 algorithm with improvements for better retention.
///
/// SM-2+ includes several improvements over the original SM-2:
/// - Takes into account how overdue a card is when calculating new interval
/// - More granular ease factor adjustments
/// - Better handling of the first few reviews
/// - Smoother interval progression
///
/// This algorithm is recommended for most use cases as it provides
/// better long-term retention than vanilla SM-2.
class SM2PlusAlgorithm with SRSAlgorithmUtils implements SRSAlgorithm {
  /// Creates an SM-2+ algorithm instance.
  const SM2PlusAlgorithm();

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

    ReviewCard updatedCard;
    bool graduatedFromLearning = false;
    bool lapsedToLearning = false;
    bool advancedLearningStep = false;

    if (card.isNew || card.isInLearningPhase) {
      final result = _processLearningReview(card, quality, settings, now);
      updatedCard = result.card;
      graduatedFromLearning = result.graduated;
      advancedLearningStep = result.advancedStep;
    } else {
      final result = _processReviewPhaseReview(card, quality, settings, now);
      updatedCard = result.card;
      lapsedToLearning = result.lapsed;
    }

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

  _LearningResult _processLearningReview(
    ReviewCard card,
    ReviewQuality quality,
    SRSSettings settings,
    DateTime now,
  ) {
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

    // Again - reset
    if (quality == ReviewQuality.again) {
      final interval = settings.learningSteps.first;
      return _LearningResult(
        card: card.copyWith(
          repetitions: 0,
          learningStepIndex: 0,
          intervalMinutes: interval.inMinutes,
          nextReviewTime: now.add(interval),
          phase:
              card.phase == CardPhase.isNew ? CardPhase.learning : card.phase,
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

    // Easy - immediate graduation with bonus
    if (quality == ReviewQuality.easy) {
      final newEase =
          calculateNewEaseFactor(card.easeFactor, quality, settings);
      // SM-2+: Easy gives a longer interval than standard
      final interval = Duration(
        minutes: (settings.easyInterval.inMinutes * settings.easyBonus).round(),
      );
      final clampedInterval = clampInterval(interval, settings);

      return _LearningResult(
        card: card.copyWith(
          repetitions: 1,
          easeFactor: newEase,
          learningStepIndex: settings.learningSteps.length,
          intervalMinutes: clampedInterval.inMinutes,
          nextReviewTime: now.add(clampedInterval),
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

    // Good/Hard - progress through steps
    int newStepIndex = card.learningStepIndex;
    int newReps = card.repetitions;

    if (quality == ReviewQuality.good) {
      newStepIndex++;
      newReps++;
    }
    // Hard in SM-2+: stay at step but add half the step duration
    // This gives a slight delay without resetting progress

    final shouldGrad = hasCompletedAllSteps(newStepIndex, newReps, settings) &&
        quality == ReviewQuality.good;

    if (shouldGrad) {
      final newEase =
          calculateNewEaseFactor(card.easeFactor, quality, settings);
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

    // Stay in learning
    final stepIndex = newStepIndex.clamp(0, settings.learningSteps.length - 1);
    Duration interval = settings.learningSteps[stepIndex];

    // SM-2+ improvement: Hard adds a fraction of the current step
    if (quality == ReviewQuality.hard) {
      final extraTime = Duration(minutes: (interval.inMinutes * 0.5).round());
      interval = interval + extraTime;
    }

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

  _ReviewResult _processReviewPhaseReview(
    ReviewCard card,
    ReviewQuality quality,
    SRSSettings settings,
    DateTime now,
  ) {
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

    // Handle lapse
    if (quality == ReviewQuality.again) {
      final newEase =
          calculateNewEaseFactor(card.easeFactor, quality, settings);

      Duration lapseInterval;
      if (settings.lapseMultiplier > 0) {
        final lapsedMinutes =
            (card.intervalMinutes * settings.lapseMultiplier).round();
        lapseInterval = Duration(
          minutes: math.max(lapsedMinutes, settings.minimumInterval.inMinutes),
        );
      } else {
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

    final newEase = calculateNewEaseFactor(card.easeFactor, quality, settings);

    // SM-2+ improvement: Factor in how overdue the card was
    final overdueBonus = _calculateOverdueBonus(card, now, settings);

    final newInterval = _calculateIntervalWithOverdue(
      card.copyWith(easeFactor: newEase),
      quality,
      settings,
      overdueBonus,
    );

    final fuzzedInterval = applyFuzz(newInterval, settings);
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

  /// Calculates bonus multiplier based on how overdue the card was.
  ///
  /// If you successfully recall a card that was overdue, you've demonstrated
  /// stronger memory than expected, so we give a small bonus.
  double _calculateOverdueBonus(
    ReviewCard card,
    DateTime now,
    SRSSettings settings,
  ) {
    if (card.intervalMinutes == 0) return 1.0;

    final scheduledDate = card.nextReviewTime;
    final actualDate = now;
    final overdueDays = actualDate.difference(scheduledDate).inDays;

    if (overdueDays <= 0) {
      // Not overdue or early - no bonus
      return 1.0;
    }

    // Cap the bonus at 2x for very overdue cards
    // Formula: 1 + min(overdueDays / intervalDays * 0.5, 1.0)
    final intervalDays = card.intervalMinutes / (24 * 60);
    if (intervalDays <= 0) return 1.0;

    final overdueRatio = overdueDays / intervalDays;
    final bonus = math.min(overdueRatio * 0.5, 1.0);

    return 1.0 + bonus;
  }

  Duration _calculateIntervalWithOverdue(
    ReviewCard card,
    ReviewQuality quality,
    SRSSettings settings,
    double overdueBonus,
  ) {
    final currentInterval = card.intervalMinutes;
    double newIntervalMinutes;

    switch (quality) {
      case ReviewQuality.again:
        return settings.learningSteps.first;

      case ReviewQuality.hard:
        // Hard: current interval * hardIntervalMultiplier (no overdue bonus)
        newIntervalMinutes = currentInterval * settings.hardIntervalMultiplier;

      case ReviewQuality.good:
        // Good: current interval * ease * overdue bonus
        newIntervalMinutes = currentInterval * card.easeFactor * overdueBonus;

      case ReviewQuality.easy:
        // Easy: current interval * ease * easy bonus * overdue bonus
        newIntervalMinutes = currentInterval *
            card.easeFactor *
            settings.easyBonus *
            overdueBonus;
    }

    // Ensure minimum growth
    final minGrowth = currentInterval + settings.minimumInterval.inMinutes;
    newIntervalMinutes = math.max(newIntervalMinutes, minGrowth.toDouble());

    return Duration(minutes: newIntervalMinutes.round());
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
        final stepIndex =
            card.learningStepIndex.clamp(0, settings.learningSteps.length - 1);
        final baseInterval = settings.learningSteps[stepIndex];
        // SM-2+: Hard adds 50% extra time
        return Duration(
          minutes: (baseInterval.inMinutes * 1.5).round(),
        );

      case ReviewQuality.good:
        final nextIndex = card.learningStepIndex + 1;
        if (nextIndex >= settings.learningSteps.length &&
            card.repetitions >= settings.graduationsRequired - 1) {
          return settings.graduatingInterval;
        }
        final stepIndex = nextIndex.clamp(0, settings.learningSteps.length - 1);
        return settings.learningSteps[stepIndex];

      case ReviewQuality.easy:
        return Duration(
          minutes:
              (settings.easyInterval.inMinutes * settings.easyBonus).round(),
        );
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

    // Preview assumes card is on time (no overdue bonus)
    final interval = _calculateIntervalWithOverdue(
      tempCard,
      quality,
      settings,
      1.0, // No overdue bonus for preview
    );

    return clampInterval(interval, settings);
  }

  @override
  double calculateNewEaseFactor(
    double currentEase,
    ReviewQuality quality,
    SRSSettings settings,
  ) {
    double newEase = currentEase;

    // SM-2+ has more nuanced ease adjustments
    switch (quality) {
      case ReviewQuality.again:
        // Larger penalty for complete failure
        newEase -= settings.againEasePenalty * 1.2;
      case ReviewQuality.hard:
        // Standard penalty
        newEase -= settings.hardEasePenalty;
      case ReviewQuality.good:
        // SM-2+: Good gives a tiny ease boost for consistent performance
        newEase += 0.02;
      case ReviewQuality.easy:
        // Generous bonus for easy
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
      return _previewLearningInterval(card, quality, settings);
    }
    // For review phase, use standard calculation without overdue bonus
    return _calculateIntervalWithOverdue(card, quality, settings, 1.0);
  }

  @override
  bool shouldGraduate(
    ReviewCard card,
    ReviewQuality quality,
    SRSSettings settings,
  ) {
    if (!card.isInLearningPhase && !card.isNew) return false;
    if (quality == ReviewQuality.easy) return true;
    if (quality == ReviewQuality.again || quality == ReviewQuality.hard) {
      return false;
    }

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

class _ReviewResult {
  final ReviewCard card;
  final bool lapsed;

  const _ReviewResult({
    required this.card,
    required this.lapsed,
  });
}
