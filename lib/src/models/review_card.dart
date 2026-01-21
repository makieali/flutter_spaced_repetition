import 'review_quality.dart';
import 'srs_settings.dart';

/// The phase a card is currently in.
enum CardPhase {
  /// Card has never been reviewed.
  isNew,

  /// Card is in the learning phase (short intervals, building memory).
  learning,

  /// Card is in the review phase (graduated, using spaced intervals).
  review,

  /// Card has lapsed and is re-learning.
  relearning,
}

/// Represents a flashcard's spaced repetition state.
///
/// This is a pure data model containing only the SRS-relevant information.
/// Application-specific data (like content, tags, deck associations) should
/// be stored in the [metadata] field or in your own data model that wraps
/// this class.
///
/// Example:
/// ```dart
/// // Create a new card
/// final card = ReviewCard.newCard(id: 'card_1');
///
/// // Card with custom metadata
/// final cardWithMeta = ReviewCard.newCard(
///   id: 'vocab_42',
///   metadata: {'word': 'hello', 'translation': 'hola'},
/// );
/// ```
class ReviewCard {
  /// Unique identifier for this card.
  final String id;

  /// Number of consecutive successful reviews in the current phase.
  final int repetitions;

  /// The ease factor (multiplier for interval calculations).
  ///
  /// Higher values mean longer intervals between reviews.
  /// Typically ranges from 1.3 to 3.0+.
  final double easeFactor;

  /// Current interval in minutes.
  final int intervalMinutes;

  /// When this card is due for review.
  final DateTime nextReviewTime;

  /// Current phase of the card.
  final CardPhase phase;

  /// Current step index in learning/relearning phase.
  ///
  /// Only relevant when [phase] is [CardPhase.learning] or [CardPhase.relearning].
  final int learningStepIndex;

  /// Total number of successful reviews (Good or Easy responses).
  final int successCount;

  /// Total number of failed reviews (Again responses).
  final int failureCount;

  /// Total number of Easy responses.
  final int easyCount;

  /// Total number of Hard responses.
  final int hardCount;

  /// Number of times this card has lapsed (gone from review back to learning).
  final int lapseCount;

  /// When this card was created.
  final DateTime createdAt;

  /// When this card was last reviewed, or null if never reviewed.
  final DateTime? lastReviewedAt;

  /// The quality of the last review, or null if never reviewed.
  final ReviewQuality? lastReviewQuality;

  /// Current streak of consecutive successful reviews.
  final int streak;

  /// Longest streak of consecutive successful reviews.
  final int longestStreak;

  /// Flexible storage for application-specific data.
  ///
  /// Use this to store your own data like deck ID, tags, content, etc.
  /// This data is preserved through reviews and serialization.
  final Map<String, dynamic>? metadata;

  /// Creates a ReviewCard with explicit values.
  ///
  /// Prefer using [ReviewCard.newCard] for creating new cards.
  const ReviewCard({
    required this.id,
    this.repetitions = 0,
    this.easeFactor = 2.5,
    this.intervalMinutes = 0,
    required this.nextReviewTime,
    this.phase = CardPhase.isNew,
    this.learningStepIndex = 0,
    this.successCount = 0,
    this.failureCount = 0,
    this.easyCount = 0,
    this.hardCount = 0,
    this.lapseCount = 0,
    required this.createdAt,
    this.lastReviewedAt,
    this.lastReviewQuality,
    this.streak = 0,
    this.longestStreak = 0,
    this.metadata,
  });

  /// Creates a new card ready for its first review.
  ///
  /// The card starts in the [CardPhase.isNew] phase and is due immediately.
  factory ReviewCard.newCard({
    required String id,
    double? initialEaseFactor,
    DateTime? createdAt,
    Map<String, dynamic>? metadata,
  }) {
    final now = createdAt ?? DateTime.now();
    return ReviewCard(
      id: id,
      easeFactor: initialEaseFactor ?? 2.5,
      nextReviewTime: now,
      createdAt: now,
      metadata: metadata,
    );
  }

  /// Whether this card has never been reviewed.
  bool get isNew => phase == CardPhase.isNew;

  /// Whether this card is in learning or relearning phase.
  bool get isInLearningPhase =>
      phase == CardPhase.learning || phase == CardPhase.relearning;

  /// Whether this card is in the review phase (graduated).
  bool get isInReviewPhase => phase == CardPhase.review;

  /// Whether this card is currently due for review.
  bool get isDue => DateTime.now().isAfter(nextReviewTime);

  /// Whether this card is overdue by more than one interval.
  bool get isOverdue {
    if (intervalMinutes == 0) return false;
    final overdueDuration = DateTime.now().difference(nextReviewTime);
    return overdueDuration.inMinutes > intervalMinutes;
  }

  /// The current interval as a Duration.
  Duration get interval => Duration(minutes: intervalMinutes);

  /// Total number of reviews for this card.
  int get totalReviews => successCount + failureCount + hardCount;

  /// Success rate as a percentage (0.0 to 1.0).
  ///
  /// Success = Good + Easy responses (easyCount is a subset of successCount).
  /// Returns 0.0 if the card has never been reviewed.
  double get successRate {
    if (totalReviews == 0) return 0.0;
    return successCount / totalReviews;
  }

  /// Retention rate (successful reviews / total reviews).
  ///
  /// Unlike [successRate], this counts Hard responses as partial successes.
  /// Retention = Success + Hard responses.
  double get retentionRate {
    if (totalReviews == 0) return 0.0;
    return (successCount + hardCount) / totalReviews;
  }

  /// Returns how overdue the card is (negative if not yet due).
  Duration get overdueAmount => DateTime.now().difference(nextReviewTime);

  /// A formatted string of the current interval for display.
  String get formattedInterval => _formatDuration(interval);

  /// A formatted string of time until/since due.
  String get formattedDueTime {
    final diff = nextReviewTime.difference(DateTime.now());
    if (diff.isNegative) {
      return '${_formatDuration(diff.abs())} ago';
    }
    return 'in ${_formatDuration(diff)}';
  }

  /// Creates a copy with updated fields.
  ReviewCard copyWith({
    String? id,
    int? repetitions,
    double? easeFactor,
    int? intervalMinutes,
    DateTime? nextReviewTime,
    CardPhase? phase,
    int? learningStepIndex,
    int? successCount,
    int? failureCount,
    int? easyCount,
    int? hardCount,
    int? lapseCount,
    DateTime? createdAt,
    DateTime? lastReviewedAt,
    ReviewQuality? lastReviewQuality,
    int? streak,
    int? longestStreak,
    Map<String, dynamic>? metadata,
  }) {
    return ReviewCard(
      id: id ?? this.id,
      repetitions: repetitions ?? this.repetitions,
      easeFactor: easeFactor ?? this.easeFactor,
      intervalMinutes: intervalMinutes ?? this.intervalMinutes,
      nextReviewTime: nextReviewTime ?? this.nextReviewTime,
      phase: phase ?? this.phase,
      learningStepIndex: learningStepIndex ?? this.learningStepIndex,
      successCount: successCount ?? this.successCount,
      failureCount: failureCount ?? this.failureCount,
      easyCount: easyCount ?? this.easyCount,
      hardCount: hardCount ?? this.hardCount,
      lapseCount: lapseCount ?? this.lapseCount,
      createdAt: createdAt ?? this.createdAt,
      lastReviewedAt: lastReviewedAt ?? this.lastReviewedAt,
      lastReviewQuality: lastReviewQuality ?? this.lastReviewQuality,
      streak: streak ?? this.streak,
      longestStreak: longestStreak ?? this.longestStreak,
      metadata: metadata ?? this.metadata,
    );
  }

  /// Converts to a JSON-compatible map.
  Map<String, dynamic> toJson() => {
        'id': id,
        'repetitions': repetitions,
        'easeFactor': easeFactor,
        'intervalMinutes': intervalMinutes,
        'nextReviewTime': nextReviewTime.toIso8601String(),
        'phase': phase.name,
        'learningStepIndex': learningStepIndex,
        'successCount': successCount,
        'failureCount': failureCount,
        'easyCount': easyCount,
        'hardCount': hardCount,
        'lapseCount': lapseCount,
        'createdAt': createdAt.toIso8601String(),
        'lastReviewedAt': lastReviewedAt?.toIso8601String(),
        'lastReviewQuality': lastReviewQuality?.value,
        'streak': streak,
        'longestStreak': longestStreak,
        if (metadata != null) 'metadata': metadata,
      };

  /// Creates a ReviewCard from a JSON map.
  factory ReviewCard.fromJson(Map<String, dynamic> json) {
    return ReviewCard(
      id: json['id'] as String,
      repetitions: json['repetitions'] as int? ?? 0,
      easeFactor: (json['easeFactor'] as num?)?.toDouble() ?? 2.5,
      intervalMinutes: json['intervalMinutes'] as int? ?? 0,
      nextReviewTime: DateTime.parse(json['nextReviewTime'] as String),
      phase: CardPhase.values.firstWhere(
        (e) => e.name == json['phase'],
        orElse: () => CardPhase.isNew,
      ),
      learningStepIndex: json['learningStepIndex'] as int? ?? 0,
      successCount: json['successCount'] as int? ?? 0,
      failureCount: json['failureCount'] as int? ?? 0,
      easyCount: json['easyCount'] as int? ?? 0,
      hardCount: json['hardCount'] as int? ?? 0,
      lapseCount: json['lapseCount'] as int? ?? 0,
      createdAt: DateTime.parse(json['createdAt'] as String),
      lastReviewedAt: json['lastReviewedAt'] != null
          ? DateTime.parse(json['lastReviewedAt'] as String)
          : null,
      lastReviewQuality: json['lastReviewQuality'] != null
          ? ReviewQuality.fromValue(json['lastReviewQuality'] as int)
          : null,
      streak: json['streak'] as int? ?? 0,
      longestStreak: json['longestStreak'] as int? ?? 0,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  /// Validates this card's state and throws if invalid.
  void validate(SRSSettings settings) {
    if (id.isEmpty) {
      throw ArgumentError.value(id, 'id', 'Card ID cannot be empty');
    }

    if (easeFactor < settings.minimumEaseFactor) {
      throw StateError(
        'Ease factor ($easeFactor) is below minimum (${settings.minimumEaseFactor})',
      );
    }

    if (intervalMinutes < 0) {
      throw StateError('Interval cannot be negative: $intervalMinutes');
    }

    if (repetitions < 0) {
      throw StateError('Repetitions cannot be negative: $repetitions');
    }

    if (learningStepIndex < 0) {
      throw StateError(
        'Learning step index cannot be negative: $learningStepIndex',
      );
    }
  }

  static String _formatDuration(Duration duration) {
    if (duration.inDays >= 365) {
      final years = duration.inDays / 365;
      if (years == years.roundToDouble()) {
        return '${years.round()}y';
      }
      return '${years.toStringAsFixed(1)}y';
    }
    if (duration.inDays >= 30) {
      final months = duration.inDays / 30;
      if (months == months.roundToDouble()) {
        return '${months.round()}mo';
      }
      return '${months.toStringAsFixed(1)}mo';
    }
    if (duration.inDays >= 1) {
      return '${duration.inDays}d';
    }
    if (duration.inHours >= 1) {
      return '${duration.inHours}h';
    }
    if (duration.inMinutes >= 1) {
      return '${duration.inMinutes}m';
    }
    return '${duration.inSeconds}s';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReviewCard &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          repetitions == other.repetitions &&
          easeFactor == other.easeFactor &&
          intervalMinutes == other.intervalMinutes &&
          nextReviewTime == other.nextReviewTime &&
          phase == other.phase &&
          learningStepIndex == other.learningStepIndex;

  @override
  int get hashCode => Object.hash(
        id,
        repetitions,
        easeFactor,
        intervalMinutes,
        nextReviewTime,
        phase,
        learningStepIndex,
      );

  @override
  String toString() => 'ReviewCard('
      'id: $id, '
      'phase: ${phase.name}, '
      'ease: ${easeFactor.toStringAsFixed(2)}, '
      'interval: $formattedInterval, '
      'due: $formattedDueTime)';
}
