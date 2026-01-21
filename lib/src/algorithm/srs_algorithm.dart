import '../models/interval_preview.dart';
import '../models/review_card.dart';
import '../models/review_quality.dart';
import '../models/review_result.dart';
import '../models/srs_settings.dart';

/// Abstract interface for spaced repetition algorithms.
///
/// Implement this interface to create custom algorithms. The package provides
/// two built-in implementations: [SM2Algorithm] and [SM2PlusAlgorithm].
///
/// Example custom implementation:
/// ```dart
/// class MyCustomAlgorithm implements SRSAlgorithm {
///   @override
///   ReviewResult processReview(
///     ReviewCard card,
///     ReviewQuality quality,
///     SRSSettings settings, {
///     DateTime? reviewTime,
///   }) {
///     // Your custom logic here
///   }
///
///   // ... other required methods
/// }
/// ```
abstract class SRSAlgorithm {
  /// Processes a review and returns the updated card state.
  ///
  /// This is the main method that determines how the algorithm updates
  /// card state based on review quality.
  ///
  /// Parameters:
  /// - [card]: The current card state.
  /// - [quality]: The quality rating for this review.
  /// - [settings]: The SRS settings to use.
  /// - [reviewTime]: Optional override for the review timestamp (defaults to now).
  ///
  /// Returns a [ReviewResult] containing the updated card and metadata.
  ReviewResult processReview(
    ReviewCard card,
    ReviewQuality quality,
    SRSSettings settings, {
    DateTime? reviewTime,
  });

  /// Previews intervals for all possible quality responses.
  ///
  /// This is used for UI to show users what interval each button would produce.
  ///
  /// Parameters:
  /// - [card]: The current card state.
  /// - [settings]: The SRS settings to use.
  ///
  /// Returns an [IntervalPreview] with intervals for Again, Hard, Good, Easy.
  IntervalPreview previewIntervals(
    ReviewCard card,
    SRSSettings settings,
  );

  /// Calculates the new ease factor based on response quality.
  ///
  /// Parameters:
  /// - [currentEase]: The current ease factor.
  /// - [quality]: The quality rating.
  /// - [settings]: The SRS settings to use.
  ///
  /// Returns the new ease factor, bounded by settings.minimumEaseFactor.
  double calculateNewEaseFactor(
    double currentEase,
    ReviewQuality quality,
    SRSSettings settings,
  );

  /// Calculates the next interval for a card.
  ///
  /// Parameters:
  /// - [card]: The current card state.
  /// - [quality]: The quality rating.
  /// - [settings]: The SRS settings to use.
  ///
  /// Returns the next interval, bounded by min/max settings.
  Duration calculateInterval(
    ReviewCard card,
    ReviewQuality quality,
    SRSSettings settings,
  );

  /// Checks if a card should graduate from learning to review phase.
  ///
  /// Parameters:
  /// - [card]: The current card state.
  /// - [quality]: The quality rating.
  /// - [settings]: The SRS settings to use.
  ///
  /// Returns true if the card should graduate.
  bool shouldGraduate(
    ReviewCard card,
    ReviewQuality quality,
    SRSSettings settings,
  );

  /// Checks if a card should lapse from review to relearning phase.
  ///
  /// Parameters:
  /// - [card]: The current card state.
  /// - [quality]: The quality rating.
  /// - [settings]: The SRS settings to use.
  ///
  /// Returns true if the card should lapse.
  bool shouldLapse(
    ReviewCard card,
    ReviewQuality quality,
    SRSSettings settings,
  );
}

/// Provides utility methods for algorithm implementations.
mixin SRSAlgorithmUtils {
  /// Clamps a duration to the min/max interval settings.
  Duration clampInterval(Duration interval, SRSSettings settings) {
    if (interval < settings.minimumInterval) {
      return settings.minimumInterval;
    }
    if (interval > settings.maximumInterval) {
      return settings.maximumInterval;
    }
    return interval;
  }

  /// Applies fuzz (randomization) to an interval.
  Duration applyFuzz(Duration interval, SRSSettings settings, {int? seed}) {
    if (settings.intervalFuzz <= 0) {
      return interval;
    }

    // Use a deterministic approach for testability when seed is provided
    final random = seed != null
        ? _seededRandom(seed, settings.intervalFuzz)
        : _randomFuzz(settings.intervalFuzz);

    final minutes = interval.inMinutes;
    final fuzzRange = (minutes * settings.intervalFuzz).round();
    final fuzzedMinutes = minutes + (random * fuzzRange * 2 - fuzzRange).round();

    return Duration(minutes: fuzzedMinutes.clamp(1, interval.inMinutes * 2));
  }

  double _seededRandom(int seed, double fuzz) {
    // Simple deterministic pseudo-random based on seed
    return ((seed * 1103515245 + 12345) % (1 << 31)) / (1 << 31);
  }

  double _randomFuzz(double fuzz) {
    // In production, use actual random
    return DateTime.now().microsecond / 1000000;
  }

  /// Clamps the ease factor to the minimum.
  double clampEaseFactor(double ease, SRSSettings settings) {
    return ease < settings.minimumEaseFactor ? settings.minimumEaseFactor : ease;
  }

  /// Gets the next learning step duration.
  Duration getNextLearningStep(int currentIndex, SRSSettings settings) {
    if (currentIndex >= settings.learningSteps.length) {
      return settings.learningSteps.last;
    }
    return settings.learningSteps[currentIndex];
  }

  /// Checks if a card has completed all learning steps.
  ///
  /// Called AFTER incrementing stepIndex and reps, so we check if the
  /// new values indicate graduation (stepIndex past the last step,
  /// reps meeting the requirement).
  bool hasCompletedAllSteps(int stepIndex, int reps, SRSSettings settings) {
    return stepIndex >= settings.learningSteps.length &&
        reps >= settings.graduationsRequired;
  }
}
