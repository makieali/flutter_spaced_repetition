import '../models/review_card.dart';
import 'priority_queue.dart';

/// Scheduling mode for determining card order.
enum SchedulingMode {
  /// Strictly due-date based ordering.
  /// Most overdue cards are shown first.
  strict,

  /// Mix new cards with review cards.
  /// Provides variety in study sessions.
  interleaved,

  /// Prioritize cards with lower retention rates.
  /// Focuses on struggling cards.
  adaptive,

  /// Random order among due cards.
  /// Good for avoiding "position bias".
  random,
}

/// Configuration for the review scheduler.
class SchedulerConfig {
  /// Maximum number of new cards per session.
  final int maxNewCardsPerSession;

  /// Maximum number of review cards per session.
  final int maxReviewsPerSession;

  /// Maximum number of cards to return in one batch.
  final int batchSize;

  /// How to order cards for review.
  final SchedulingMode mode;

  /// Whether to include overdue cards even if max is reached.
  final bool alwaysIncludeOverdue;

  /// Threshold for considering a card "overdue" (multiplier of interval).
  final double overdueThreshold;

  /// Creates scheduler configuration.
  const SchedulerConfig({
    this.maxNewCardsPerSession = 20,
    this.maxReviewsPerSession = 200,
    this.batchSize = 20,
    this.mode = SchedulingMode.interleaved,
    this.alwaysIncludeOverdue = true,
    this.overdueThreshold = 1.0,
  });

  /// Default configuration for standard study sessions.
  factory SchedulerConfig.standard() => const SchedulerConfig();

  /// Configuration for intensive study (more cards, strict ordering).
  factory SchedulerConfig.intensive() => const SchedulerConfig(
        maxNewCardsPerSession: 50,
        maxReviewsPerSession: 500,
        batchSize: 50,
        mode: SchedulingMode.strict,
      );

  /// Configuration for light review (fewer cards).
  factory SchedulerConfig.light() => const SchedulerConfig(
        maxNewCardsPerSession: 10,
        maxReviewsPerSession: 50,
        batchSize: 10,
        mode: SchedulingMode.interleaved,
      );

  /// Configuration for catch-up sessions (focus on overdue).
  factory SchedulerConfig.catchUp() => const SchedulerConfig(
        maxNewCardsPerSession: 0,
        maxReviewsPerSession: 1000,
        batchSize: 100,
        mode: SchedulingMode.strict,
        alwaysIncludeOverdue: true,
      );

  SchedulerConfig copyWith({
    int? maxNewCardsPerSession,
    int? maxReviewsPerSession,
    int? batchSize,
    SchedulingMode? mode,
    bool? alwaysIncludeOverdue,
    double? overdueThreshold,
  }) {
    return SchedulerConfig(
      maxNewCardsPerSession: maxNewCardsPerSession ?? this.maxNewCardsPerSession,
      maxReviewsPerSession: maxReviewsPerSession ?? this.maxReviewsPerSession,
      batchSize: batchSize ?? this.batchSize,
      mode: mode ?? this.mode,
      alwaysIncludeOverdue: alwaysIncludeOverdue ?? this.alwaysIncludeOverdue,
      overdueThreshold: overdueThreshold ?? this.overdueThreshold,
    );
  }
}

/// Summary of scheduled reviews.
class SchedulerSummary {
  /// Number of new cards available.
  final int newCardsAvailable;

  /// Number of learning cards due.
  final int learningCardsDue;

  /// Number of review cards due.
  final int reviewCardsDue;

  /// Number of overdue cards.
  final int overdueCards;

  /// Total cards scheduled for this session.
  final int scheduledCount;

  /// Whether more cards are available beyond the session limit.
  final bool hasMore;

  const SchedulerSummary({
    required this.newCardsAvailable,
    required this.learningCardsDue,
    required this.reviewCardsDue,
    required this.overdueCards,
    required this.scheduledCount,
    required this.hasMore,
  });

  /// Total due cards (learning + review + overdue).
  int get totalDue => learningCardsDue + reviewCardsDue;

  @override
  String toString() => 'SchedulerSummary('
      'new: $newCardsAvailable, '
      'learning: $learningCardsDue, '
      'review: $reviewCardsDue, '
      'overdue: $overdueCards, '
      'scheduled: $scheduledCount)';
}

/// Schedules cards for review based on due dates and configuration.
///
/// Example:
/// ```dart
/// final scheduler = ReviewScheduler(
///   config: SchedulerConfig.standard(),
/// );
///
/// // Get due cards from a deck
/// final batch = scheduler.getNextBatch(allCards);
///
/// // Review the batch
/// for (final card in batch) {
///   // Show card to user...
/// }
///
/// // Get summary of remaining work
/// final summary = scheduler.getSummary(allCards);
/// print('Due today: ${summary.totalDue}');
/// ```
class ReviewScheduler {
  /// Configuration for this scheduler.
  final SchedulerConfig config;

  /// Track cards reviewed in current session for limits.
  int _sessionNewCards = 0;
  int _sessionReviews = 0;

  /// Creates a review scheduler.
  ReviewScheduler({
    SchedulerConfig? config,
  }) : config = config ?? SchedulerConfig.standard();

  /// Resets session counters.
  ///
  /// Call this at the start of a new study session.
  void resetSession() {
    _sessionNewCards = 0;
    _sessionReviews = 0;
  }

  /// Gets the next batch of cards to review.
  ///
  /// Parameters:
  /// - [cards]: All available cards.
  /// - [asOf]: Time to check due dates against (defaults to now).
  ///
  /// Returns a list of cards to review in order.
  List<ReviewCard> getNextBatch(List<ReviewCard> cards, {DateTime? asOf}) {
    final now = asOf ?? DateTime.now();

    // Categorize cards
    final newCards = <ReviewCard>[];
    final learningCards = <ReviewCard>[];
    final reviewCards = <ReviewCard>[];
    final overdueCards = <ReviewCard>[];

    for (final card in cards) {
      if (_isOverdue(card, now)) {
        overdueCards.add(card);
      } else if (_isDue(card, now)) {
        if (card.isNew) {
          newCards.add(card);
        } else if (card.isInLearningPhase) {
          learningCards.add(card);
        } else {
          reviewCards.add(card);
        }
      } else if (card.isNew) {
        newCards.add(card);
      }
    }

    // Build the batch
    final batch = <ReviewCard>[];

    // Always include overdue cards if configured
    if (config.alwaysIncludeOverdue) {
      batch.addAll(_sortByPriority(overdueCards, now));
    }

    // Add learning cards (they have tight timing)
    batch.addAll(_sortByPriority(learningCards, now));

    // Add new and review cards based on mode and limits
    final remainingSlots = config.batchSize - batch.length;
    if (remainingSlots > 0) {
      final additionalCards = _selectCards(
        newCards: newCards,
        reviewCards: reviewCards,
        maxSlots: remainingSlots,
        now: now,
      );
      batch.addAll(additionalCards);
    }

    return batch.take(config.batchSize).toList();
  }

  List<ReviewCard> _selectCards({
    required List<ReviewCard> newCards,
    required List<ReviewCard> reviewCards,
    required int maxSlots,
    required DateTime now,
  }) {
    final result = <ReviewCard>[];

    // Calculate remaining allowance for session
    final newAllowance = config.maxNewCardsPerSession - _sessionNewCards;
    final reviewAllowance = config.maxReviewsPerSession - _sessionReviews;

    switch (config.mode) {
      case SchedulingMode.strict:
        // Reviews first, then new
        final dueReviews = reviewCards
            .where((c) => _isDue(c, now))
            .take(reviewAllowance.clamp(0, maxSlots))
            .toList();
        result.addAll(_sortByPriority(dueReviews, now));

        final remaining = maxSlots - result.length;
        if (remaining > 0 && newAllowance > 0) {
          result.addAll(newCards.take(remaining.clamp(0, newAllowance)));
        }

      case SchedulingMode.interleaved:
        // Mix new and review cards
        final sortedNew = List<ReviewCard>.from(newCards);
        final sortedReview = _sortByPriority(
          reviewCards.where((c) => _isDue(c, now)).toList(),
          now,
        );

        int newIdx = 0;
        int reviewIdx = 0;
        int newUsed = 0;
        int reviewUsed = 0;

        // Interleave: 1 new per 5 reviews (adjustable)
        while (result.length < maxSlots) {
          final shouldAddNew = (result.length % 5 == 0) &&
              newIdx < sortedNew.length &&
              newUsed < newAllowance;

          if (shouldAddNew) {
            result.add(sortedNew[newIdx++]);
            newUsed++;
          } else if (reviewIdx < sortedReview.length &&
              reviewUsed < reviewAllowance) {
            result.add(sortedReview[reviewIdx++]);
            reviewUsed++;
          } else if (newIdx < sortedNew.length && newUsed < newAllowance) {
            result.add(sortedNew[newIdx++]);
            newUsed++;
          } else {
            break;
          }
        }

      case SchedulingMode.adaptive:
        // Prioritize cards with lower success rates
        final allDue = [
          ...newCards.take(newAllowance),
          ...reviewCards.where((c) => _isDue(c, now)).take(reviewAllowance),
        ];
        allDue.sort((a, b) => a.successRate.compareTo(b.successRate));
        result.addAll(allDue.take(maxSlots));

      case SchedulingMode.random:
        // Random selection among due cards
        final allDue = [
          ...newCards.take(newAllowance),
          ...reviewCards.where((c) => _isDue(c, now)).take(reviewAllowance),
        ];
        allDue.shuffle();
        result.addAll(allDue.take(maxSlots));
    }

    return result;
  }

  List<ReviewCard> _sortByPriority(List<ReviewCard> cards, DateTime now) {
    final sorted = List<ReviewCard>.from(cards);
    sorted.sort((a, b) {
      // Most overdue first
      final aOverdue = now.difference(a.nextReviewTime);
      final bOverdue = now.difference(b.nextReviewTime);
      return bOverdue.compareTo(aOverdue);
    });
    return sorted;
  }

  bool _isDue(ReviewCard card, DateTime now) {
    return now.isAfter(card.nextReviewTime) ||
        now.isAtSameMomentAs(card.nextReviewTime);
  }

  bool _isOverdue(ReviewCard card, DateTime now) {
    if (card.intervalMinutes == 0) return false;
    final overdueDuration = now.difference(card.nextReviewTime);
    final threshold = card.intervalMinutes * config.overdueThreshold;
    return overdueDuration.inMinutes > threshold;
  }

  /// Marks a card as reviewed for session tracking.
  ///
  /// Call this after processing each review to update session limits.
  void markReviewed(ReviewCard card) {
    if (card.isNew) {
      _sessionNewCards++;
    } else {
      _sessionReviews++;
    }
  }

  /// Gets a summary of the current scheduling state.
  SchedulerSummary getSummary(List<ReviewCard> cards, {DateTime? asOf}) {
    final now = asOf ?? DateTime.now();

    int newCount = 0;
    int learningCount = 0;
    int reviewCount = 0;
    int overdueCount = 0;

    for (final card in cards) {
      if (_isOverdue(card, now)) {
        overdueCount++;
      } else if (_isDue(card, now)) {
        if (card.isNew) {
          newCount++;
        } else if (card.isInLearningPhase) {
          learningCount++;
        } else {
          reviewCount++;
        }
      } else if (card.isNew) {
        newCount++;
      }
    }

    // Calculate scheduled count based on limits
    final newScheduled = newCount.clamp(
      0,
      config.maxNewCardsPerSession - _sessionNewCards,
    );
    final reviewScheduled = (learningCount + reviewCount).clamp(
      0,
      config.maxReviewsPerSession - _sessionReviews,
    );
    final scheduledCount = newScheduled + reviewScheduled + overdueCount;

    final totalAvailable = newCount + learningCount + reviewCount + overdueCount;

    return SchedulerSummary(
      newCardsAvailable: newCount,
      learningCardsDue: learningCount,
      reviewCardsDue: reviewCount,
      overdueCards: overdueCount,
      scheduledCount: scheduledCount.clamp(0, config.batchSize),
      hasMore: totalAvailable > config.batchSize,
    );
  }

  /// Gets cards that will be due within a specified time window.
  List<ReviewCard> getUpcoming(
    List<ReviewCard> cards, {
    Duration window = const Duration(hours: 24),
    DateTime? asOf,
  }) {
    final now = asOf ?? DateTime.now();
    final cutoff = now.add(window);

    return cards
        .where((card) =>
            card.nextReviewTime.isAfter(now) &&
            card.nextReviewTime.isBefore(cutoff))
        .toList()
      ..sort((a, b) => a.nextReviewTime.compareTo(b.nextReviewTime));
  }

  /// Creates a priority queue for efficient card ordering.
  CardPriorityQueue createPriorityQueue(List<ReviewCard> cards) {
    final queue = CardPriorityQueue();
    for (final card in cards) {
      queue.add(card);
    }
    return queue;
  }
}
