import '../algorithm/custom_algorithm.dart';
import '../algorithm/fsrs_algorithm.dart';
import '../algorithm/sm2_algorithm.dart';
import '../algorithm/sm2_plus_algorithm.dart';
import '../algorithm/srs_algorithm.dart';
import '../analytics/analytics.dart';
import '../models/fsrs_models.dart';
import '../models/interval_preview.dart';
import '../models/review_card.dart';
import '../models/review_log.dart';
import '../models/review_quality.dart';
import '../models/review_result.dart';
import '../models/srs_settings.dart';

/// The main entry point for spaced repetition functionality.
///
/// This engine provides a high-level API for processing reviews, managing
/// cards, and configuring the algorithm.
///
/// Example:
/// ```dart
/// // Create engine with default settings
/// final engine = SpacedRepetitionEngine();
///
/// // Or with custom settings
/// final engine = SpacedRepetitionEngine(
///   settings: SRSSettings.aggressive(),
/// );
///
/// // Create and review a card
/// var card = engine.createCard(id: 'card_1');
/// final result = engine.processReview(card, ReviewQuality.good);
/// card = result.updatedCard;
///
/// // Preview next intervals
/// final preview = engine.previewIntervals(card);
/// print('Next intervals: $preview');
/// ```
class SpacedRepetitionEngine {
  /// The settings used by this engine.
  SRSSettings _settings;

  /// The algorithm implementation being used.
  SRSAlgorithm _algorithm;

  /// Creates a spaced repetition engine.
  ///
  /// Parameters:
  /// - [settings]: Configuration for the algorithm. Defaults to [SRSSettings.anki].
  /// - [algorithm]: Custom algorithm implementation. If null, uses the algorithm
  ///   specified in [settings.algorithmType].
  SpacedRepetitionEngine({
    SRSSettings? settings,
    SRSAlgorithm? algorithm,
  })  : _settings = settings ?? SRSSettings.anki(),
        _algorithm = algorithm ?? _createAlgorithmFromType(
          (settings ?? SRSSettings.anki()).algorithmType,
        ) {
    // Validate settings on construction
    _settings.validate();
  }

  /// Creates the appropriate algorithm based on type.
  static SRSAlgorithm _createAlgorithmFromType(SRSAlgorithmType type) {
    switch (type) {
      case SRSAlgorithmType.sm2:
        return const SM2Algorithm();
      case SRSAlgorithmType.sm2Plus:
        return const SM2PlusAlgorithm();
      case SRSAlgorithmType.fsrs:
        return FSRSAlgorithm();
      case SRSAlgorithmType.custom:
        return const CustomAlgorithm();
    }
  }

  // ============================================================
  // FSRS-SPECIFIC METHODS
  // ============================================================

  /// Gets the current retrievability of a card.
  ///
  /// Retrievability is the probability of successfully recalling the card.
  /// Only meaningful for FSRS algorithm; returns 0 for other algorithms.
  double getRetrievability(ReviewCard card, {DateTime? asOf}) {
    if (_algorithm is FSRSAlgorithm) {
      return (_algorithm as FSRSAlgorithm).getRetrievability(card, asOf: asOf);
    }
    // For non-FSRS algorithms, estimate from card state
    const forgettingCurve = ForgettingCurve();
    return forgettingCurve.currentRetrievability(card, asOf: asOf);
  }

  /// Gets the FSRS state of a card (stability, difficulty).
  ///
  /// Returns null if not using FSRS algorithm.
  FSRSState? getFSRSState(ReviewCard card) {
    if (_algorithm is FSRSAlgorithm) {
      return (_algorithm as FSRSAlgorithm).getState(card);
    }
    return null;
  }

  /// Generates a forgetting curve for a card.
  List<ForgettingCurvePoint> getForgettingCurve(
    ReviewCard card, {
    int days = 30,
  }) {
    const curve = ForgettingCurve();
    return curve.generate(card, days: days);
  }

  /// Generates a workload forecast.
  List<WorkloadForecastDay> getWorkloadForecast(
    List<ReviewCard> cards, {
    int days = 30,
    int newCardsPerDay = 20,
  }) {
    const forecast = WorkloadForecast();
    return forecast.generate(
      cards,
      days: days,
      newCardsPerDay: newCardsPerDay,
    );
  }

  /// Creates a review log entry from a review result.
  ReviewLog createReviewLog(
    ReviewResult result, {
    int? reviewDurationMs,
  }) {
    return ReviewLog(
      cardId: result.updatedCard.id,
      reviewTime: result.reviewedAt,
      rating: result.quality,
      scheduledInterval: result.previousCard.interval,
      actualInterval: result.reviewedAt.difference(
        result.previousCard.lastReviewedAt ?? result.previousCard.createdAt,
      ),
      retrievability: _algorithm is FSRSAlgorithm
          ? getRetrievability(result.previousCard, asOf: result.reviewedAt)
          : null,
      stabilityBefore: getFSRSState(result.previousCard)?.stability,
      stabilityAfter: getFSRSState(result.updatedCard)?.stability,
      difficultyBefore: getFSRSState(result.previousCard)?.difficulty,
      difficultyAfter: getFSRSState(result.updatedCard)?.difficulty,
      easeFactorBefore: result.previousCard.easeFactor,
      easeFactorAfter: result.updatedCard.easeFactor,
      algorithm: _settings.algorithmType.name,
      reviewDurationMs: reviewDurationMs,
    );
  }

  /// Gets the current settings.
  SRSSettings get settings => _settings;

  /// Gets the current algorithm.
  SRSAlgorithm get algorithm => _algorithm;

  /// Updates the settings.
  ///
  /// This also updates the algorithm if the [algorithmType] has changed.
  void updateSettings(SRSSettings newSettings) {
    newSettings.validate();

    // Update algorithm if type changed
    if (newSettings.algorithmType != _settings.algorithmType) {
      _algorithm = _createAlgorithmFromType(newSettings.algorithmType);
    }

    _settings = newSettings;
  }

  /// Sets a custom algorithm implementation.
  void setAlgorithm(SRSAlgorithm algorithm) {
    _algorithm = algorithm;
  }

  /// Creates a new card ready for review.
  ///
  /// Parameters:
  /// - [id]: Unique identifier for the card.
  /// - [metadata]: Optional application-specific data.
  ReviewCard createCard({
    required String id,
    Map<String, dynamic>? metadata,
  }) {
    return ReviewCard.newCard(
      id: id,
      initialEaseFactor: _settings.initialEaseFactor,
      metadata: metadata,
    );
  }

  /// Processes a review and returns the updated card.
  ///
  /// Parameters:
  /// - [card]: The card being reviewed.
  /// - [quality]: The quality of the user's response.
  /// - [reviewTime]: Optional override for the review time (for testing/syncing).
  ///
  /// Returns a [ReviewResult] containing the updated card and metadata.
  ReviewResult processReview(
    ReviewCard card,
    ReviewQuality quality, {
    DateTime? reviewTime,
  }) {
    return _algorithm.processReview(
      card,
      quality,
      _settings,
      reviewTime: reviewTime,
    );
  }

  /// Processes multiple reviews in batch.
  ///
  /// This is more efficient than calling [processReview] multiple times
  /// when you have several reviews to process.
  ///
  /// Parameters:
  /// - [reviews]: List of (card, quality) pairs to process.
  /// - [reviewTime]: Optional override for the review time.
  ///
  /// Returns a list of [ReviewResult]s in the same order as input.
  List<ReviewResult> processBatch(
    List<(ReviewCard, ReviewQuality)> reviews, {
    DateTime? reviewTime,
  }) {
    final time = reviewTime ?? DateTime.now();
    return reviews.map((pair) {
      return processReview(pair.$1, pair.$2, reviewTime: time);
    }).toList();
  }

  /// Previews the intervals that would result from each possible quality response.
  ///
  /// Use this to display interval previews in your UI before the user
  /// makes their choice.
  IntervalPreview previewIntervals(ReviewCard card) {
    return _algorithm.previewIntervals(card, _settings);
  }

  /// Checks if a card is due for review.
  ///
  /// Parameters:
  /// - [card]: The card to check.
  /// - [asOf]: Optional time to check against (defaults to now).
  bool isDue(ReviewCard card, {DateTime? asOf}) {
    final checkTime = asOf ?? DateTime.now();
    return checkTime.isAfter(card.nextReviewTime) ||
        checkTime.isAtSameMomentAs(card.nextReviewTime);
  }

  /// Gets the due status of a card.
  ///
  /// Returns:
  /// - Negative duration if the card is overdue
  /// - Zero duration if the card is due now
  /// - Positive duration if the card is not yet due
  Duration timeUntilDue(ReviewCard card, {DateTime? asOf}) {
    final checkTime = asOf ?? DateTime.now();
    return card.nextReviewTime.difference(checkTime);
  }

  /// Filters a list of cards to return only those that are due.
  ///
  /// Parameters:
  /// - [cards]: The cards to filter.
  /// - [asOf]: Optional time to check against (defaults to now).
  List<ReviewCard> getDueCards(List<ReviewCard> cards, {DateTime? asOf}) {
    return cards.where((card) => isDue(card, asOf: asOf)).toList();
  }

  /// Sorts cards by priority for review.
  ///
  /// Cards are sorted by:
  /// 1. Overdue cards first (most overdue first)
  /// 2. New cards
  /// 3. Learning cards
  /// 4. Review cards
  List<ReviewCard> sortByPriority(List<ReviewCard> cards) {
    final sorted = List<ReviewCard>.from(cards);
    sorted.sort((a, b) {
      // overdueAmount is positive when card is past due, negative when not yet due
      final aOverdue = a.overdueAmount;
      final bOverdue = b.overdueAmount;

      final aIsOverdue = !aOverdue.isNegative;
      final bIsOverdue = !bOverdue.isNegative;

      // If both are overdue, most overdue first (higher positive value first)
      if (aIsOverdue && bIsOverdue) {
        return bOverdue.compareTo(aOverdue); // Descending order
      }

      // Overdue cards come before not-yet-due cards
      if (aIsOverdue && !bIsOverdue) return -1;
      if (!aIsOverdue && bIsOverdue) return 1;

      // Then by phase priority
      final aPriority = _phasePriority(a.phase);
      final bPriority = _phasePriority(b.phase);
      if (aPriority != bPriority) {
        return aPriority.compareTo(bPriority);
      }

      // Finally by next review time (sooner first)
      return a.nextReviewTime.compareTo(b.nextReviewTime);
    });
    return sorted;
  }

  int _phasePriority(CardPhase phase) {
    return switch (phase) {
      CardPhase.relearning => 0, // Highest priority
      CardPhase.learning => 1,
      CardPhase.isNew => 2,
      CardPhase.review => 3, // Lowest priority
    };
  }

  /// Calculates what the ease factor would become for a given quality.
  double calculateNewEaseFactor(
    double currentEase,
    ReviewQuality quality,
  ) {
    return _algorithm.calculateNewEaseFactor(currentEase, quality, _settings);
  }

  /// Calculates what the interval would become for a given quality.
  Duration calculateInterval(
    ReviewCard card,
    ReviewQuality quality,
  ) {
    return _algorithm.calculateInterval(card, quality, _settings);
  }

  /// Checks if a card would graduate from learning with the given quality.
  bool wouldGraduate(ReviewCard card, ReviewQuality quality) {
    return _algorithm.shouldGraduate(card, quality, _settings);
  }

  /// Checks if a card would lapse with the given quality.
  bool wouldLapse(ReviewCard card, ReviewQuality quality) {
    return _algorithm.shouldLapse(card, quality, _settings);
  }

  /// Checks if a card is a "leech" (has lapsed too many times).
  bool isLeech(ReviewCard card) {
    if (_settings.lapsesBeforeLeech == 0) return false;
    return card.lapseCount >= _settings.lapsesBeforeLeech;
  }

  /// Resets a card to its initial state.
  ///
  /// Useful when a card needs to be completely relearned.
  ReviewCard resetCard(ReviewCard card) {
    final now = DateTime.now();
    return ReviewCard(
      id: card.id,
      easeFactor: _settings.initialEaseFactor,
      nextReviewTime: now,
      createdAt: card.createdAt,
      metadata: card.metadata,
      // Reset all progress but keep some history
      repetitions: 0,
      intervalMinutes: 0,
      phase: CardPhase.isNew,
      learningStepIndex: 0,
      successCount: 0,
      failureCount: 0,
      easyCount: 0,
      hardCount: 0,
      lapseCount: card.lapseCount, // Keep lapse count for leech detection
      lastReviewedAt: card.lastReviewedAt,
      lastReviewQuality: null,
      streak: 0,
      longestStreak: card.longestStreak, // Keep longest streak
    );
  }

  /// Suspends a card by setting its due date far in the future.
  ///
  /// Use this for cards that should be temporarily excluded from reviews.
  /// Call [unsuspendCard] to bring it back.
  ReviewCard suspendCard(ReviewCard card, {Duration? suspendFor}) {
    final duration = suspendFor ?? const Duration(days: 36500); // ~100 years
    return card.copyWith(
      nextReviewTime: DateTime.now().add(duration),
      metadata: {
        ...?card.metadata,
        '_suspended': true,
        '_suspendedAt': DateTime.now().toIso8601String(),
      },
    );
  }

  /// Unsuspends a card by making it due immediately.
  ReviewCard unsuspendCard(ReviewCard card) {
    final newMetadata = Map<String, dynamic>.from(card.metadata ?? {});
    newMetadata.remove('_suspended');
    newMetadata.remove('_suspendedAt');

    // Need to create a new card since copyWith doesn't allow clearing metadata
    return ReviewCard(
      id: card.id,
      repetitions: card.repetitions,
      easeFactor: card.easeFactor,
      intervalMinutes: card.intervalMinutes,
      nextReviewTime: DateTime.now(),
      phase: card.phase,
      learningStepIndex: card.learningStepIndex,
      successCount: card.successCount,
      failureCount: card.failureCount,
      easyCount: card.easyCount,
      hardCount: card.hardCount,
      lapseCount: card.lapseCount,
      createdAt: card.createdAt,
      lastReviewedAt: card.lastReviewedAt,
      lastReviewQuality: card.lastReviewQuality,
      streak: card.streak,
      longestStreak: card.longestStreak,
      metadata: newMetadata.isEmpty ? null : newMetadata,
    );
  }

  /// Checks if a card is suspended.
  bool isSuspended(ReviewCard card) {
    return card.metadata?['_suspended'] == true;
  }

  /// Reschedules a card to a specific date.
  ///
  /// Useful for manual scheduling adjustments.
  ReviewCard rescheduleCard(ReviewCard card, DateTime newDueDate) {
    return card.copyWith(nextReviewTime: newDueDate);
  }

  /// Advances a card's due date by a specified duration.
  ReviewCard postponeCard(ReviewCard card, Duration postponeBy) {
    return card.copyWith(
      nextReviewTime: card.nextReviewTime.add(postponeBy),
    );
  }

  /// Creates a summary of a card's current state.
  Map<String, dynamic> getCardSummary(ReviewCard card) {
    return {
      'id': card.id,
      'phase': card.phase.name,
      'easeFactor': card.easeFactor,
      'interval': card.formattedInterval,
      'isDue': isDue(card),
      'isOverdue': card.isOverdue,
      'isLeech': isLeech(card),
      'isSuspended': isSuspended(card),
      'successRate': (card.successRate * 100).toStringAsFixed(1) + '%',
      'streak': card.streak,
      'longestStreak': card.longestStreak,
      'totalReviews': card.totalReviews,
      'lapseCount': card.lapseCount,
      'nextReview': card.nextReviewTime.toIso8601String(),
      'dueIn': card.formattedDueTime,
    };
  }
}
