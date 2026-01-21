import 'dart:math' as math;

import '../models/fsrs_models.dart';
import '../models/interval_preview.dart';
import '../models/review_card.dart';
import '../models/review_quality.dart';
import '../models/review_result.dart';
import '../models/srs_settings.dart';
import 'srs_algorithm.dart';

/// FSRS (Free Spaced Repetition Scheduler) algorithm implementation.
///
/// FSRS is a modern spaced repetition algorithm that uses machine learning
/// principles to optimize review scheduling. It tracks three key metrics:
///
/// - **Stability (S)**: Time (in days) for retrievability to decay to 90%
/// - **Difficulty (D)**: Inherent difficulty of the card (1-10)
/// - **Retrievability (R)**: Current probability of successful recall
///
/// FSRS is 20-30% more efficient than SM-2 in terms of reviews needed
/// to achieve the same retention rate.
///
/// Reference: https://github.com/open-spaced-repetition/fsrs4anki
class FSRSAlgorithm with SRSAlgorithmUtils implements SRSAlgorithm {
  /// Creates an FSRS algorithm with the given settings.
  FSRSAlgorithm({FSRSSettings? settings})
      : _settings = settings ?? FSRSSettings.standard();

  final FSRSSettings _settings;

  /// The FSRS settings.
  FSRSSettings get settings => _settings;

  // FSRS constants
  static const double _factor = 19 / 81;
  static const double _decay = -0.5;

  /// Processes a review and returns the updated card state.
  @override
  ReviewResult processReview(
    ReviewCard card,
    ReviewQuality quality,
    SRSSettings settings, {
    DateTime? reviewTime,
  }) {
    final now = reviewTime ?? DateTime.now();
    final fsrsState = _getFSRSState(card);

    // Calculate current retrievability
    final retrievabilityBefore = fsrsState.lastReview != null
        ? fsrsState.retrievability(now)
        : 0.0;

    // Process based on current state
    final FSRSSchedulingResult result;
    switch (fsrsState.state) {
      case FSRSCardState.newCard:
        result = _processNewCard(fsrsState, quality, now);
      case FSRSCardState.learning:
      case FSRSCardState.relearning:
        result = _processLearningCard(fsrsState, quality, now);
      case FSRSCardState.review:
        result = _processReviewCard(fsrsState, quality, now, retrievabilityBefore);
    }

    // Update the card
    final updatedCard = _updateCard(card, result, quality, now);

    // Determine transitions
    final wasLearning = fsrsState.state == FSRSCardState.learning ||
        fsrsState.state == FSRSCardState.newCard;
    final isNowReview = result.state.state == FSRSCardState.review;
    final wasReview = fsrsState.state == FSRSCardState.review;
    final isNowRelearning = result.state.state == FSRSCardState.relearning;
    final wasFirstReview = card.totalReviews == 0;
    final advancedStep = fsrsState.state == FSRSCardState.learning &&
        result.state.state == FSRSCardState.learning &&
        quality != ReviewQuality.again;
    final easeFactorDelta = updatedCard.easeFactor - card.easeFactor;

    return ReviewResult(
      updatedCard: updatedCard,
      previousCard: card,
      quality: quality,
      nextInterval: result.interval,
      graduatedFromLearning: wasLearning && isNowReview,
      lapsedToLearning: wasReview && isNowRelearning,
      wasFirstReview: wasFirstReview,
      advancedLearningStep: advancedStep,
      easeFactorChanged: easeFactorDelta.abs() > 0.001,
      easeFactorDelta: easeFactorDelta,
      preview: previewIntervals(card, settings),
      reviewedAt: now,
    );
  }

  /// Processes a new card.
  FSRSSchedulingResult _processNewCard(
    FSRSState state,
    ReviewQuality quality,
    DateTime now,
  ) {
    final p = _settings.parameters;

    // Initial stability based on quality
    final initialStability = switch (quality) {
      ReviewQuality.again => p.w0,
      ReviewQuality.hard => p.w1,
      ReviewQuality.good => p.w2,
      ReviewQuality.easy => p.w3,
    };

    // Initial difficulty
    final initialDifficulty = _initDifficulty(quality);

    // Determine next state
    final nextState = quality == ReviewQuality.again
        ? FSRSCardState.learning
        : quality == ReviewQuality.easy
            ? FSRSCardState.review
            : FSRSCardState.learning;

    // Calculate interval
    final intervalDays = _getInterval(initialStability, nextState, quality);

    return FSRSSchedulingResult(
      state: FSRSState(
        stability: initialStability,
        difficulty: initialDifficulty,
        lastReview: now,
        reps: 1,
        lapses: quality == ReviewQuality.again ? 1 : 0,
        state: nextState,
      ),
      intervalDays: intervalDays,
      nextReview: now.add(Duration(minutes: (intervalDays * 1440).round())),
      retrievabilityBefore: 0.0,
      retrievabilityAfter: _settings.desiredRetention,
    );
  }

  /// Processes a card in learning/relearning phase.
  FSRSSchedulingResult _processLearningCard(
    FSRSState state,
    ReviewQuality quality,
    DateTime now,
  ) {
    final p = _settings.parameters;
    final isRelearning = state.state == FSRSCardState.relearning;
    final steps = isRelearning
        ? _settings.relearningSteps
        : _settings.learningSteps;

    // Current step (approximate based on reps)
    final currentStep = (state.reps - 1).clamp(0, steps.length - 1);

    if (quality == ReviewQuality.again) {
      // Reset to first step
      final intervalMinutes = steps.first.toDouble();
      return FSRSSchedulingResult(
        state: state.copyWith(
          lastReview: now,
          reps: state.reps + 1,
          lapses: state.lapses + 1,
        ),
        intervalDays: intervalMinutes / 1440,
        nextReview: now.add(Duration(minutes: intervalMinutes.round())),
        retrievabilityBefore: state.retrievability(now),
        retrievabilityAfter: _settings.desiredRetention,
      );
    }

    if (quality == ReviewQuality.easy) {
      // Graduate immediately with bonus
      final newStability = _nextStability(
        state.stability > 0 ? state.stability : p.w2,
        state.difficulty > 0 ? state.difficulty : 5.0,
        1.0, // Perfect recall
        quality,
      );
      final intervalDays = _getInterval(newStability, FSRSCardState.review, quality);

      return FSRSSchedulingResult(
        state: state.copyWith(
          stability: newStability,
          lastReview: now,
          reps: state.reps + 1,
          state: FSRSCardState.review,
        ),
        intervalDays: intervalDays,
        nextReview: now.add(Duration(minutes: (intervalDays * 1440).round())),
        retrievabilityBefore: state.retrievability(now),
        retrievabilityAfter: _settings.desiredRetention,
      );
    }

    // Good or Hard - advance through steps
    final nextStep = quality == ReviewQuality.hard
        ? currentStep // Stay at current step for Hard
        : currentStep + 1;

    if (nextStep >= steps.length) {
      // Graduate to review
      final newStability = _nextStability(
        state.stability > 0 ? state.stability : p.w2,
        state.difficulty > 0 ? state.difficulty : 5.0,
        1.0,
        quality,
      );
      final intervalDays = _getInterval(newStability, FSRSCardState.review, quality);

      return FSRSSchedulingResult(
        state: state.copyWith(
          stability: newStability,
          lastReview: now,
          reps: state.reps + 1,
          state: FSRSCardState.review,
        ),
        intervalDays: intervalDays,
        nextReview: now.add(Duration(minutes: (intervalDays * 1440).round())),
        retrievabilityBefore: state.retrievability(now),
        retrievabilityAfter: _settings.desiredRetention,
      );
    }

    // Continue in learning
    final intervalMinutes = steps[nextStep].toDouble();
    return FSRSSchedulingResult(
      state: state.copyWith(
        lastReview: now,
        reps: state.reps + 1,
      ),
      intervalDays: intervalMinutes / 1440,
      nextReview: now.add(Duration(minutes: intervalMinutes.round())),
      retrievabilityBefore: state.retrievability(now),
      retrievabilityAfter: _settings.desiredRetention,
    );
  }

  /// Processes a card in review phase.
  FSRSSchedulingResult _processReviewCard(
    FSRSState state,
    ReviewQuality quality,
    DateTime now,
    double retrievability,
  ) {
    if (quality == ReviewQuality.again) {
      // Lapse - go to relearning
      final newStability = _nextForgetStability(
        state.stability,
        state.difficulty,
        retrievability,
      );
      final intervalMinutes = _settings.relearningSteps.first.toDouble();

      return FSRSSchedulingResult(
        state: state.copyWith(
          stability: newStability,
          difficulty: _nextDifficulty(state.difficulty, quality),
          lastReview: now,
          reps: state.reps + 1,
          lapses: state.lapses + 1,
          state: FSRSCardState.relearning,
        ),
        intervalDays: intervalMinutes / 1440,
        nextReview: now.add(Duration(minutes: intervalMinutes.round())),
        retrievabilityBefore: retrievability,
        retrievabilityAfter: _settings.desiredRetention,
      );
    }

    // Success - calculate new stability
    final newStability = _nextStability(
      state.stability,
      state.difficulty,
      retrievability,
      quality,
    );
    final newDifficulty = _nextDifficulty(state.difficulty, quality);
    final intervalDays = _getInterval(newStability, FSRSCardState.review, quality);

    return FSRSSchedulingResult(
      state: state.copyWith(
        stability: newStability,
        difficulty: newDifficulty,
        lastReview: now,
        reps: state.reps + 1,
      ),
      intervalDays: intervalDays,
      nextReview: now.add(Duration(minutes: (intervalDays * 1440).round())),
      retrievabilityBefore: retrievability,
      retrievabilityAfter: _settings.desiredRetention,
    );
  }

  /// Calculates initial difficulty for a new card.
  double _initDifficulty(ReviewQuality quality) {
    final p = _settings.parameters;
    final grade = quality.value.toDouble();
    // D0(G) = w4 - exp(w5 * (G - 1)) + 1
    final d = p.w4 - math.exp(p.w5 * (grade - 1)) + 1;
    return d.clamp(1.0, 10.0);
  }

  /// Calculates next difficulty after a review.
  double _nextDifficulty(double currentD, ReviewQuality quality) {
    final p = _settings.parameters;
    final grade = quality.value.toDouble();

    // D'(D, G) = w6 * D0(G) + (1 - w6) * D
    final d0 = p.w4 - math.exp(p.w5 * (grade - 1)) + 1;
    final newD = p.w6 * d0 + (1 - p.w6) * currentD;

    // Mean reversion: D'' = w7 * D0(3) + (1 - w7) * D'
    final d0Mean = p.w4 - math.exp(p.w5 * 2) + 1;
    final finalD = p.w7 * d0Mean + (1 - p.w7) * newD;

    return finalD.clamp(1.0, 10.0);
  }

  /// Calculates next stability after a successful review.
  double _nextStability(
    double currentS,
    double d,
    double r,
    ReviewQuality quality,
  ) {
    final p = _settings.parameters;

    // S'(D, S, R, G) = S * (exp(w8) * (11 - D) * S^(-w9) * (exp(w10 * (1 - R)) - 1) * hardPenalty * easyBonus + 1)
    final hardPenalty = quality == ReviewQuality.hard ? p.w17 : 1.0;
    final easyBonus = quality == ReviewQuality.easy ? p.w18 : 1.0;

    final factor = math.exp(p.w8) *
        (11 - d) *
        math.pow(currentS, -p.w9) *
        (math.exp(p.w10 * (1 - r)) - 1) *
        hardPenalty *
        easyBonus;

    final newS = currentS * (factor + 1);
    return newS.clamp(0.1, _settings.maximumInterval.toDouble());
  }

  /// Calculates stability after a lapse (forgetting).
  double _nextForgetStability(double currentS, double d, double r) {
    final p = _settings.parameters;

    // S'(D, S, R) = w13 * D^(-w14) * ((S + 1)^w15 - 1) * exp(w16 * (1 - R))
    final newS = p.w13 *
        math.pow(d, -p.w14) *
        (math.pow(currentS + 1, p.w15) - 1) *
        math.exp(p.w16 * (1 - r));

    return newS.clamp(0.1, currentS);
  }

  /// Gets the interval in days for the given stability.
  double _getInterval(double stability, FSRSCardState state, ReviewQuality quality) {
    if (state != FSRSCardState.review) {
      // Learning cards use fixed steps
      return 0.0;
    }

    // I(S, R) = S / FACTOR * (R^(1/DECAY) - 1)
    final r = _settings.desiredRetention;
    var interval = stability / _factor * (math.pow(r, 1 / _decay) - 1);

    // Apply fuzz if enabled
    if (_settings.enableFuzz && interval > 2.5) {
      interval = _applyFuzz(interval);
    }

    return interval.clamp(1.0, _settings.maximumInterval.toDouble());
  }

  /// Applies randomization to the interval.
  double _applyFuzz(double interval) {
    final random = math.Random();
    final fuzzFactor = 0.05; // 5% fuzz
    final fuzz = interval * fuzzFactor;
    return interval + (random.nextDouble() - 0.5) * 2 * fuzz;
  }

  /// Gets the FSRS state from a ReviewCard.
  FSRSState _getFSRSState(ReviewCard card) {
    // Try to extract FSRS state from metadata
    if (card.metadata != null && card.metadata!.containsKey('fsrs')) {
      return FSRSState.fromJson(
        card.metadata!['fsrs'] as Map<String, dynamic>,
      );
    }

    // Convert from standard card state
    final state = switch (card.phase) {
      CardPhase.isNew => FSRSCardState.newCard,
      CardPhase.learning => FSRSCardState.learning,
      CardPhase.review => FSRSCardState.review,
      CardPhase.relearning => FSRSCardState.relearning,
    };

    return FSRSState(
      stability: card.intervalMinutes > 0 ? card.intervalMinutes / 1440 : 0.0,
      difficulty: (10 - (card.easeFactor - 1.3) * 5).clamp(1.0, 10.0),
      lastReview: card.lastReviewedAt,
      reps: card.repetitions,
      lapses: card.lapseCount,
      state: state,
    );
  }

  /// Updates the card with the FSRS result.
  ReviewCard _updateCard(
    ReviewCard card,
    FSRSSchedulingResult result,
    ReviewQuality quality,
    DateTime now,
  ) {
    final phase = switch (result.state.state) {
      FSRSCardState.newCard => CardPhase.isNew,
      FSRSCardState.learning => CardPhase.learning,
      FSRSCardState.review => CardPhase.review,
      FSRSCardState.relearning => CardPhase.relearning,
    };

    // Convert difficulty back to ease factor for compatibility
    final easeFactor = 1.3 + (10 - result.state.difficulty) / 5 * 1.2;

    // Update statistics
    final isSuccess = quality == ReviewQuality.good || quality == ReviewQuality.easy;
    final isFailure = quality == ReviewQuality.again;

    // Store FSRS state in metadata
    final metadata = Map<String, dynamic>.from(card.metadata ?? {});
    metadata['fsrs'] = result.state.toJson();

    return card.copyWith(
      phase: phase,
      repetitions: result.state.reps,
      easeFactor: easeFactor.clamp(1.3, 3.0),
      intervalMinutes: result.interval.inMinutes,
      nextReviewTime: result.nextReview,
      lastReviewedAt: now,
      lapseCount: result.state.lapses,
      successCount: card.successCount + (isSuccess ? 1 : 0),
      failureCount: card.failureCount + (isFailure ? 1 : 0),
      easyCount: card.easyCount + (quality == ReviewQuality.easy ? 1 : 0),
      hardCount: card.hardCount + (quality == ReviewQuality.hard ? 1 : 0),
      streak: isFailure ? 0 : card.streak + 1,
      longestStreak: isFailure
          ? card.longestStreak
          : math.max(card.longestStreak, card.streak + 1),
      metadata: metadata,
    );
  }

  @override
  IntervalPreview previewIntervals(ReviewCard card, SRSSettings settings) {
    final now = DateTime.now();
    final fsrsState = _getFSRSState(card);

    // Preview all four responses
    final againResult = _previewQuality(fsrsState, ReviewQuality.again, now);
    final hardResult = _previewQuality(fsrsState, ReviewQuality.hard, now);
    final goodResult = _previewQuality(fsrsState, ReviewQuality.good, now);
    final easyResult = _previewQuality(fsrsState, ReviewQuality.easy, now);

    return IntervalPreview(
      againInterval: againResult.interval,
      hardInterval: hardResult.interval,
      goodInterval: goodResult.interval,
      easyInterval: easyResult.interval,
    );
  }

  FSRSSchedulingResult _previewQuality(
    FSRSState state,
    ReviewQuality quality,
    DateTime now,
  ) {
    final retrievability = state.lastReview != null
        ? state.retrievability(now)
        : 0.0;

    return switch (state.state) {
      FSRSCardState.newCard => _processNewCard(state, quality, now),
      FSRSCardState.learning ||
      FSRSCardState.relearning =>
        _processLearningCard(state, quality, now),
      FSRSCardState.review =>
        _processReviewCard(state, quality, now, retrievability),
    };
  }

  @override
  double calculateNewEaseFactor(
    double currentEase,
    ReviewQuality quality,
    SRSSettings settings,
  ) {
    // FSRS doesn't use ease factor, but we maintain compatibility
    return switch (quality) {
      ReviewQuality.again => (currentEase - 0.2).clamp(1.3, 3.0),
      ReviewQuality.hard => (currentEase - 0.15).clamp(1.3, 3.0),
      ReviewQuality.good => currentEase,
      ReviewQuality.easy => (currentEase + 0.15).clamp(1.3, 3.0),
    };
  }

  @override
  Duration calculateInterval(
    ReviewCard card,
    ReviewQuality quality,
    SRSSettings settings,
  ) {
    final now = DateTime.now();
    final fsrsState = _getFSRSState(card);
    final result = _previewQuality(fsrsState, quality, now);
    return result.interval;
  }

  @override
  bool shouldGraduate(
    ReviewCard card,
    ReviewQuality quality,
    SRSSettings settings,
  ) {
    if (card.phase != CardPhase.learning && card.phase != CardPhase.isNew) {
      return false;
    }
    if (quality == ReviewQuality.easy) return true;
    if (quality == ReviewQuality.again) return false;

    // Check if we've completed all learning steps
    final steps = _settings.learningSteps;
    final currentStep = (card.repetitions).clamp(0, steps.length);
    return currentStep >= steps.length;
  }

  @override
  bool shouldLapse(
    ReviewCard card,
    ReviewQuality quality,
    SRSSettings settings,
  ) {
    return card.phase == CardPhase.review && quality == ReviewQuality.again;
  }

  /// Gets the current retrievability for a card.
  double getRetrievability(ReviewCard card, {DateTime? asOf}) {
    final now = asOf ?? DateTime.now();
    final fsrsState = _getFSRSState(card);
    return fsrsState.retrievability(now);
  }

  /// Gets the FSRS state for a card.
  FSRSState getState(ReviewCard card) => _getFSRSState(card);
}
