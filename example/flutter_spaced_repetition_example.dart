/// Example demonstrating the flutter_spaced_repetition package.
///
/// This example shows:
/// - Creating and reviewing flashcards
/// - Using different quality ratings
/// - Checking card statistics
/// - Configuring the algorithm
library;

import 'package:flutter_spaced_repetition/flutter_spaced_repetition.dart';

void main() {
  print('=== Flutter Spaced Repetition Example ===\n');

  // Basic Usage Example
  basicUsageExample();

  // Custom Settings Example
  customSettingsExample();

  // Statistics Example
  statisticsExample();

  // Batch Processing Example
  batchProcessingExample();

  // Scheduler Example
  schedulerExample();
}

/// Demonstrates basic usage of the spaced repetition engine.
void basicUsageExample() {
  print('--- Basic Usage ---');

  // Create engine with default Anki-like settings
  final engine = SpacedRepetitionEngine();

  // Create a new flashcard
  var card = engine.createCard(
    id: 'vocab_hello',
    metadata: {'front': 'Hello', 'back': 'Hola'},
  );

  print('Created new card: ${card.id}');
  print('Phase: ${card.phase.name}');
  print('Due: ${card.formattedDueTime}');

  // Preview intervals before reviewing
  final preview = engine.previewIntervals(card);
  print('\nInterval preview:');
  print('  Again: ${preview.formattedAgainInterval}');
  print('  Hard: ${preview.formattedHardInterval}');
  print('  Good: ${preview.formattedGoodInterval}');
  print('  Easy: ${preview.formattedEasyInterval}');

  // Process first review - user answered "Good"
  var result = engine.processReview(card, ReviewQuality.good);
  card = result.updatedCard;

  print('\nAfter first review (Good):');
  print('  Phase: ${card.phase.name}');
  print('  Interval: ${card.formattedInterval}');
  print('  Due: ${card.formattedDueTime}');

  // Simulate the card becoming due again
  card = card.copyWith(
    nextReviewTime: DateTime.now().subtract(const Duration(minutes: 1)),
  );

  // Process second review - graduated!
  result = engine.processReview(card, ReviewQuality.good);
  card = result.updatedCard;

  print('\nAfter second review (Good):');
  print('  Graduated: ${result.graduatedFromLearning}');
  print('  Phase: ${card.phase.name}');
  print('  Interval: ${card.formattedInterval}');
  print('  Ease: ${card.easeFactor.toStringAsFixed(2)}');

  print('\n');
}

/// Demonstrates using custom settings.
void customSettingsExample() {
  print('--- Custom Settings ---');

  // Use preset configurations
  print('Available presets:');
  print('  - SRSSettings.anki() - Standard Anki defaults');
  print('  - SRSSettings.supermemo() - Original SuperMemo');
  print('  - SRSSettings.aggressive() - More frequent reviews');
  print('  - SRSSettings.relaxed() - Fewer reviews');

  // Create engine with aggressive settings
  final aggressiveEngine = SpacedRepetitionEngine(
    settings: SRSSettings.aggressive(),
  );

  print('\nAggressive settings:');
  print('  Learning steps: ${aggressiveEngine.settings.learningSteps.length}');
  print(
    '  Graduating interval: ${aggressiveEngine.settings.graduatingInterval.inHours}h',
  );
  print('  Max interval: ${aggressiveEngine.settings.maximumInterval.inDays}d');

  // Or fully customize
  final customEngine = SpacedRepetitionEngine(
    settings: const SRSSettings(
      learningSteps: [
        Duration(minutes: 1),
        Duration(minutes: 5),
        Duration(minutes: 15),
      ],
      graduationsRequired: 3,
      graduatingInterval: Duration(hours: 12),
      easyInterval: Duration(days: 3),
      initialEaseFactor: 2.3,
      minimumEaseFactor: 1.5,
      algorithmType: SRSAlgorithmType.sm2Plus,
    ),
  );

  print('\nCustom settings:');
  print('  Algorithm: ${customEngine.settings.algorithmType.name}');
  print('  Learning steps: ${customEngine.settings.learningSteps.length}');
  print('  Initial ease: ${customEngine.settings.initialEaseFactor}');

  print('\n');
}

/// Demonstrates card and deck statistics.
void statisticsExample() {
  print('--- Statistics ---');

  final engine = SpacedRepetitionEngine();

  // Create and review some cards
  final cards = <ReviewCard>[];
  for (var i = 0; i < 5; i++) {
    var card = engine.createCard(id: 'card_$i');

    // Simulate some reviews
    for (var j = 0; j < 3 + i; j++) {
      final result = engine.processReview(card, ReviewQuality.good);
      card = result.updatedCard.copyWith(
        nextReviewTime: DateTime.now().subtract(const Duration(minutes: 1)),
      );
    }
    cards.add(card);
  }

  // Card-level statistics
  final cardStats = CardStatistics(cards[2]);
  print('Card statistics:');
  print('  Total reviews: ${cardStats.totalReviews}');
  print(
    '  Success rate: ${(cardStats.successRate * 100).toStringAsFixed(1)}%',
  );
  print('  Stability: ${(cardStats.stability * 100).toStringAsFixed(1)}%');
  print('  Difficulty: ${(cardStats.difficulty * 100).toStringAsFixed(1)}%');

  // Deck-level statistics
  final deckStats = DeckStatistics(cards);
  print('\nDeck statistics:');
  print('  Total cards: ${deckStats.totalCards}');
  print('  New cards: ${deckStats.newCards}');
  print('  Learning: ${deckStats.learningCards}');
  print('  Review: ${deckStats.reviewCards}');
  print('  Total reviews: ${deckStats.totalReviews}');
  print(
    '  Avg success: ${(deckStats.averageSuccessRate * 100).toStringAsFixed(1)}%',
  );

  // Mastery calculation
  const calculator = MasteryCalculator();
  final mastery = calculator.calculate(cards[4]);
  print('\nMastery for card_4:');
  print('  Level: ${mastery.level.label}');
  print('  Score: ${(mastery.score * 100).toStringAsFixed(1)}%');
  print('  Progress: ${(mastery.progress * 100).toStringAsFixed(1)}%');

  print('\n');
}

/// Demonstrates batch processing of reviews.
void batchProcessingExample() {
  print('--- Batch Processing ---');

  final engine = SpacedRepetitionEngine();

  // Create multiple cards
  final cards = List.generate(
    5,
    (i) => engine.createCard(id: 'batch_$i'),
  );

  // Process multiple reviews at once
  final reviews = [
    (cards[0], ReviewQuality.good),
    (cards[1], ReviewQuality.easy),
    (cards[2], ReviewQuality.hard),
    (cards[3], ReviewQuality.again),
    (cards[4], ReviewQuality.good),
  ];

  final results = engine.processBatch(reviews);

  print('Batch results:');
  for (var i = 0; i < results.length; i++) {
    final r = results[i];
    print(
      '  ${r.updatedCard.id}: ${r.quality.label} -> ${r.updatedCard.formattedInterval}',
    );
  }

  print('\n');
}

/// Demonstrates the review scheduler.
void schedulerExample() {
  print('--- Review Scheduler ---');

  final engine = SpacedRepetitionEngine();
  final scheduler = ReviewScheduler(
    config: SchedulerConfig.standard(),
  );

  // Create cards in various states
  final now = DateTime.now();
  final cards = [
    // Overdue cards
    engine.createCard(id: 'overdue_1').copyWith(
      phase: CardPhase.review,
      nextReviewTime: now.subtract(const Duration(days: 2)),
      intervalMinutes: 1440,
    ),
    engine.createCard(id: 'overdue_2').copyWith(
      phase: CardPhase.review,
      nextReviewTime: now.subtract(const Duration(hours: 12)),
      intervalMinutes: 1440,
    ),
    // New cards
    engine.createCard(id: 'new_1'),
    engine.createCard(id: 'new_2'),
    // Learning cards
    engine.createCard(id: 'learning_1').copyWith(
      phase: CardPhase.learning,
      nextReviewTime: now.subtract(const Duration(minutes: 5)),
    ),
    // Future due
    engine.createCard(id: 'future_1').copyWith(
      phase: CardPhase.review,
      nextReviewTime: now.add(const Duration(days: 1)),
    ),
  ];

  // Get scheduling summary
  final summary = scheduler.getSummary(cards);
  print('Scheduling summary:');
  print('  New available: ${summary.newCardsAvailable}');
  print('  Learning due: ${summary.learningCardsDue}');
  print('  Review due: ${summary.reviewCardsDue}');
  print('  Overdue: ${summary.overdueCards}');

  // Get next batch
  final batch = scheduler.getNextBatch(cards);
  print('\nNext batch to review:');
  for (final card in batch) {
    print('  ${card.id} (${card.phase.name})');
  }

  print('\n');
}
