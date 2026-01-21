import '../models/review_card.dart';
import '../models/review_quality.dart';
import '../models/srs_settings.dart';

/// Result of a validation operation.
class ValidationResult {
  /// Whether validation passed.
  final bool isValid;

  /// List of validation errors (empty if valid).
  final List<String> errors;

  /// List of validation warnings (non-fatal issues).
  final List<String> warnings;

  const ValidationResult({
    required this.isValid,
    this.errors = const [],
    this.warnings = const [],
  });

  /// Creates a successful validation result.
  const ValidationResult.success()
      : isValid = true,
        errors = const [],
        warnings = const [];

  /// Creates a failed validation result with errors.
  const ValidationResult.failure(this.errors)
      : isValid = false,
        warnings = const [];

  /// Creates a valid result with warnings.
  const ValidationResult.withWarnings(this.warnings)
      : isValid = true,
        errors = const [];

  /// Combines multiple validation results.
  factory ValidationResult.combine(List<ValidationResult> results) {
    final allErrors = <String>[];
    final allWarnings = <String>[];

    for (final result in results) {
      allErrors.addAll(result.errors);
      allWarnings.addAll(result.warnings);
    }

    return ValidationResult(
      isValid: allErrors.isEmpty,
      errors: allErrors,
      warnings: allWarnings,
    );
  }

  @override
  String toString() {
    if (isValid && warnings.isEmpty) return 'Valid';
    if (isValid) return 'Valid with warnings: ${warnings.join(", ")}';
    return 'Invalid: ${errors.join(", ")}';
  }
}

/// Validation utilities for SRS models.
class SRSValidator {
  /// Creates a validator instance.
  const SRSValidator();

  /// Validates a review card.
  ValidationResult validateCard(ReviewCard card, {SRSSettings? settings}) {
    final errors = <String>[];
    final warnings = <String>[];

    // Check ID
    if (card.id.isEmpty) {
      errors.add('Card ID cannot be empty');
    }

    // Check ease factor
    if (card.easeFactor < 1.0) {
      errors.add('Ease factor cannot be less than 1.0: ${card.easeFactor}');
    }
    if (settings != null && card.easeFactor < settings.minimumEaseFactor) {
      errors.add(
        'Ease factor ${card.easeFactor} is below minimum ${settings.minimumEaseFactor}',
      );
    }
    if (card.easeFactor > 5.0) {
      warnings.add('Ease factor ${card.easeFactor} is unusually high');
    }

    // Check interval
    if (card.intervalMinutes < 0) {
      errors.add('Interval cannot be negative: ${card.intervalMinutes}');
    }

    // Check repetitions
    if (card.repetitions < 0) {
      errors.add('Repetitions cannot be negative: ${card.repetitions}');
    }

    // Check learning step index
    if (card.learningStepIndex < 0) {
      errors.add(
        'Learning step index cannot be negative: ${card.learningStepIndex}',
      );
    }

    // Check counts
    if (card.successCount < 0) {
      errors.add('Success count cannot be negative');
    }
    if (card.failureCount < 0) {
      errors.add('Failure count cannot be negative');
    }
    if (card.easyCount < 0) {
      errors.add('Easy count cannot be negative');
    }
    if (card.hardCount < 0) {
      errors.add('Hard count cannot be negative');
    }
    if (card.lapseCount < 0) {
      errors.add('Lapse count cannot be negative');
    }

    // Check dates
    if (card.nextReviewTime.isBefore(card.createdAt)) {
      warnings.add('Next review time is before card creation time');
    }
    if (card.lastReviewedAt != null &&
        card.lastReviewedAt!.isBefore(card.createdAt)) {
      errors.add('Last reviewed time cannot be before card creation time');
    }

    // Check streak consistency
    if (card.streak > card.longestStreak) {
      errors.add('Current streak cannot exceed longest streak');
    }

    // Phase-specific checks
    if (card.isNew && card.totalReviews > 0) {
      errors.add('New card cannot have reviews');
    }

    if (settings != null) {
      if (card.learningStepIndex >= settings.learningSteps.length &&
          card.isInLearningPhase) {
        warnings.add(
          'Learning step index exceeds available steps',
        );
      }
    }

    return ValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
      warnings: warnings,
    );
  }

  /// Validates SRS settings.
  ValidationResult validateSettings(SRSSettings settings) {
    final errors = <String>[];
    final warnings = <String>[];

    // Learning steps
    if (settings.learningSteps.isEmpty) {
      errors.add('Learning steps cannot be empty');
    }
    for (var i = 0; i < settings.learningSteps.length; i++) {
      if (settings.learningSteps[i].inSeconds <= 0) {
        errors.add('Learning step $i must be positive');
      }
    }
    // Check steps are in order
    for (var i = 1; i < settings.learningSteps.length; i++) {
      if (settings.learningSteps[i] < settings.learningSteps[i - 1]) {
        warnings.add('Learning steps are not in ascending order');
        break;
      }
    }

    // Graduations required
    if (settings.graduationsRequired < 1) {
      errors.add('Graduations required must be at least 1');
    }
    if (settings.graduationsRequired > settings.learningSteps.length) {
      warnings.add(
        'Graduations required exceeds learning steps count',
      );
    }

    // Lapses before leech
    if (settings.lapsesBeforeLeech < 0) {
      errors.add('Lapses before leech cannot be negative');
    }

    // Intervals
    if (settings.graduatingInterval.inSeconds <= 0) {
      errors.add('Graduating interval must be positive');
    }
    if (settings.easyInterval.inSeconds <= 0) {
      errors.add('Easy interval must be positive');
    }
    if (settings.minimumInterval.inSeconds <= 0) {
      errors.add('Minimum interval must be positive');
    }
    if (settings.maximumInterval.inSeconds <= 0) {
      errors.add('Maximum interval must be positive');
    }
    if (settings.maximumInterval < settings.minimumInterval) {
      errors.add('Maximum interval must be >= minimum interval');
    }
    if (settings.graduatingInterval < settings.minimumInterval) {
      warnings.add('Graduating interval is less than minimum interval');
    }

    // Ease factors
    if (settings.initialEaseFactor < 1.0) {
      errors.add('Initial ease factor must be at least 1.0');
    }
    if (settings.minimumEaseFactor < 1.0) {
      errors.add('Minimum ease factor must be at least 1.0');
    }
    if (settings.initialEaseFactor < settings.minimumEaseFactor) {
      errors.add('Initial ease factor must be >= minimum ease factor');
    }

    // Bonuses and penalties
    if (settings.easyBonus < 1.0) {
      errors.add('Easy bonus must be at least 1.0');
    }
    if (settings.hardIntervalMultiplier <= 0) {
      errors.add('Hard interval multiplier must be positive');
    }
    if (settings.lapseMultiplier < 0 || settings.lapseMultiplier > 1) {
      errors.add('Lapse multiplier must be between 0 and 1');
    }

    // Ease adjustments
    if (settings.hardEasePenalty < 0) {
      errors.add('Hard ease penalty cannot be negative');
    }
    if (settings.againEasePenalty < 0) {
      errors.add('Again ease penalty cannot be negative');
    }
    if (settings.easyEaseBonus < 0) {
      errors.add('Easy ease bonus cannot be negative');
    }

    // Fuzz
    if (settings.intervalFuzz < 0 || settings.intervalFuzz > 1) {
      errors.add('Interval fuzz must be between 0 and 1');
    }

    return ValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
      warnings: warnings,
    );
  }

  /// Validates a review quality value.
  ValidationResult validateQuality(int value) {
    if (value < 1 || value > 4) {
      return ValidationResult.failure([
        'Review quality must be between 1 and 4, got: $value',
      ]);
    }
    return const ValidationResult.success();
  }

  /// Validates a review quality enum.
  ValidationResult validateQualityEnum(ReviewQuality quality) {
    // Enum is always valid by construction
    return const ValidationResult.success();
  }

  /// Validates that a card can be reviewed with a specific quality.
  ValidationResult validateReview(ReviewCard card, ReviewQuality quality) {
    final errors = <String>[];
    final warnings = <String>[];

    // Basic card validation
    final cardValidation = validateCard(card);
    errors.addAll(cardValidation.errors);
    warnings.addAll(cardValidation.warnings);

    // Check if card is actually due (warning only)
    if (!card.isDue) {
      warnings.add('Card is not yet due for review');
    }

    return ValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
      warnings: warnings,
    );
  }

  /// Validates a batch of cards.
  ValidationResult validateCardBatch(
    List<ReviewCard> cards, {
    SRSSettings? settings,
  }) {
    final errors = <String>[];
    final warnings = <String>[];
    final seenIds = <String>{};

    for (var i = 0; i < cards.length; i++) {
      final card = cards[i];

      // Check for duplicate IDs
      if (seenIds.contains(card.id)) {
        errors.add('Duplicate card ID at index $i: ${card.id}');
      }
      seenIds.add(card.id);

      // Validate each card
      final result = validateCard(card, settings: settings);
      for (final error in result.errors) {
        errors.add('Card ${card.id}: $error');
      }
      for (final warning in result.warnings) {
        warnings.add('Card ${card.id}: $warning');
      }
    }

    return ValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
      warnings: warnings,
    );
  }
}

/// Default validator instance for convenience.
const srsValidator = SRSValidator();

/// Extension for easy validation on models.
extension ReviewCardValidation on ReviewCard {
  /// Validates this card.
  ValidationResult validate({SRSSettings? settings}) {
    return srsValidator.validateCard(this, settings: settings);
  }

  /// Returns true if this card is valid.
  bool get isValid => validate().isValid;
}

/// Extension for easy validation on settings.
extension SRSSettingsValidation on SRSSettings {
  /// Validates these settings.
  ValidationResult validateAll() {
    return srsValidator.validateSettings(this);
  }

  /// Returns true if these settings are valid.
  bool get isValid => validateAll().isValid;
}
