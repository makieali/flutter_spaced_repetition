# flutter_spaced_repetition

A production-ready, pure Dart implementation of spaced repetition algorithms (SM-2, SM-2+) for Flutter and Dart applications.

[![pub package](https://img.shields.io/pub/v/flutter_spaced_repetition.svg)](https://pub.dev/packages/flutter_spaced_repetition)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

## Features

- **Multiple Algorithms**: SM-2 (classic), SM-2+ (improved), and custom algorithm support
- **Fully Configurable**: All 17+ settings are functional - no dead code
- **No Dependencies**: Pure Dart, works everywhere (Flutter, CLI, server)
- **Statistics**: Per-card and deck-level analytics with mastery tracking
- **Scheduling**: Priority-based card ordering and session management
- **Serialization**: Full JSON import/export support
- **Well Tested**: 138+ tests with comprehensive coverage

## Installation

Add this to your package's `pubspec.yaml` file:

```yaml
dependencies:
  flutter_spaced_repetition: ^1.0.0
```

## Quick Start

```dart
import 'package:flutter_spaced_repetition/flutter_spaced_repetition.dart';

// Create engine with default Anki-like settings
final engine = SpacedRepetitionEngine();

// Create a new card
var card = engine.createCard(id: 'card_1');

// Process a review with quality rating
final result = engine.processReview(card, ReviewQuality.good);
card = result.updatedCard;

// Check next review time
print('Next review: ${card.formattedDueTime}');
print('Interval: ${card.formattedInterval}');
```

## Quality Ratings

The package uses four quality ratings for reviews:

| Rating | Value | Use When |
|--------|-------|----------|
| `ReviewQuality.again` | 1 | Complete failure to recall |
| `ReviewQuality.hard` | 2 | Correct but with difficulty |
| `ReviewQuality.good` | 3 | Correct with some hesitation |
| `ReviewQuality.easy` | 4 | Perfect, instant recall |

## Configuration Presets

```dart
// Standard Anki defaults
final anki = SpacedRepetitionEngine(settings: SRSSettings.anki());

// Original SuperMemo settings
final supermemo = SpacedRepetitionEngine(settings: SRSSettings.supermemo());

// More frequent reviews for faster learning
final aggressive = SpacedRepetitionEngine(settings: SRSSettings.aggressive());

// Fewer reviews for maintenance
final relaxed = SpacedRepetitionEngine(settings: SRSSettings.relaxed());
```

## Custom Configuration

Every setting is fully functional and configurable:

```dart
final engine = SpacedRepetitionEngine(
  settings: SRSSettings(
    // Learning phase
    learningSteps: [Duration(minutes: 1), Duration(minutes: 10)],
    graduationsRequired: 2,
    lapsesBeforeLeech: 8,

    // Intervals
    graduatingInterval: Duration(days: 1),
    easyInterval: Duration(days: 4),
    minimumInterval: Duration(days: 1),
    maximumInterval: Duration(days: 365),

    // Ease factor
    initialEaseFactor: 2.5,
    minimumEaseFactor: 1.3,
    easyBonus: 1.3,
    hardIntervalMultiplier: 1.2,
    lapseMultiplier: 0.0,

    // Ease adjustments
    hardEasePenalty: 0.15,
    againEasePenalty: 0.20,
    easyEaseBonus: 0.15,

    // Algorithm
    algorithmType: SRSAlgorithmType.sm2Plus,
    intervalFuzz: 0.05,
  ),
);
```

## Interval Preview

Show users what interval each button will produce:

```dart
final preview = engine.previewIntervals(card);

// Display on buttons
print('Again: ${preview.formattedAgainInterval}');  // e.g., "1m"
print('Hard: ${preview.formattedHardInterval}');    // e.g., "6m"
print('Good: ${preview.formattedGoodInterval}');    // e.g., "10m"
print('Easy: ${preview.formattedEasyInterval}');    // e.g., "4d"
```

## Card Lifecycle

Cards progress through these phases:

1. **New** (`CardPhase.isNew`) - Never reviewed
2. **Learning** (`CardPhase.learning`) - Going through learning steps
3. **Review** (`CardPhase.review`) - Graduated, using spaced intervals
4. **Relearning** (`CardPhase.relearning`) - Lapsed, re-learning

```dart
// Check card state
if (card.isNew) print('Card is new');
if (card.isInLearningPhase) print('Card is learning');
if (card.isInReviewPhase) print('Card has graduated');
```

## Statistics

### Card Statistics

```dart
final stats = CardStatistics(card);

print('Total reviews: ${stats.totalReviews}');
print('Success rate: ${(stats.successRate * 100).toStringAsFixed(1)}%');
print('Current streak: ${stats.currentStreak}');
print('Stability: ${(stats.stability * 100).toStringAsFixed(1)}%');
print('Difficulty: ${(stats.difficulty * 100).toStringAsFixed(1)}%');
```

### Deck Statistics

```dart
final deckStats = DeckStatistics(cards);

print('Total cards: ${deckStats.totalCards}');
print('Due today: ${deckStats.dueToday}');
print('Mastered: ${deckStats.masteredCards}');
print('Average retention: ${deckStats.averageRetention}');
```

### Mastery Tracking

```dart
final calculator = MasteryCalculator();
final mastery = calculator.calculate(card);

print('Level: ${mastery.level.label}');   // e.g., "Proficient"
print('Score: ${mastery.score}');         // 0.0 to 1.0
print('Progress: ${mastery.progress}');   // Progress towards mastery
```

## Scheduling

```dart
final scheduler = ReviewScheduler(
  config: SchedulerConfig(
    maxNewCardsPerSession: 20,
    maxReviewsPerSession: 200,
    batchSize: 20,
    mode: SchedulingMode.interleaved,
  ),
);

// Get next batch of cards to review
final batch = scheduler.getNextBatch(allCards);

// Get summary
final summary = scheduler.getSummary(allCards);
print('New: ${summary.newCardsAvailable}');
print('Due: ${summary.totalDue}');
print('Overdue: ${summary.overdueCards}');
```

## Metadata

Store application-specific data with each card:

```dart
// Create card with metadata
var card = engine.createCard(
  id: 'vocab_42',
  metadata: {
    'front': 'Hello',
    'back': 'Hola',
    'deck': 'Spanish',
    'tags': ['greetings', 'beginner'],
  },
);

// Access metadata
print(card.metadata?['front']); // "Hello"
```

## Serialization

```dart
// Serialize to JSON
final json = card.toJson();

// Deserialize from JSON
final restored = ReviewCard.fromJson(json);

// Export entire deck
final export = srsSerializer.exportDeck(
  cards: cards,
  settings: engine.settings,
  deckMetadata: {'name': 'Spanish Vocabulary'},
);

// Import deck
final import = srsSerializer.importDeck(exportedJson);
print('Imported ${import.cards.length} cards');
```

## Algorithms

### SM-2 (Default)

The classic SuperMemo 2 algorithm by Piotr Wozniak:
- Learning phase with configurable steps
- Ease factor adjustment based on response quality
- Interval calculation: `interval = previous_interval * ease_factor`

### SM-2+ (Enhanced)

Improved version with better retention:
- Accounts for overdue bonus (successfully recalling overdue cards)
- More nuanced ease factor adjustments
- Smoother interval progression

```dart
final engine = SpacedRepetitionEngine(
  settings: SRSSettings(algorithmType: SRSAlgorithmType.sm2Plus),
);
```

### Custom Algorithm

Implement your own algorithm:

```dart
final customAlgorithm = CustomAlgorithm(
  intervalCalculator: (card, quality, settings) {
    // Your custom interval logic
    return Duration(days: card.repetitions + 1);
  },
  easeCalculator: (ease, quality, settings) {
    // Your custom ease factor logic
    return quality == ReviewQuality.easy ? ease + 0.2 : ease;
  },
);

final engine = SpacedRepetitionEngine();
engine.setAlgorithm(customAlgorithm);
```

## Card Management

```dart
// Check if due
if (engine.isDue(card)) {
  // Show for review
}

// Get due cards
final dueCards = engine.getDueCards(allCards);

// Sort by priority
final sorted = engine.sortByPriority(cards);

// Suspend a card
final suspended = engine.suspendCard(card);

// Unsuspend
final active = engine.unsuspendCard(suspended);

// Reset a card
final reset = engine.resetCard(card);

// Reschedule
final rescheduled = engine.rescheduleCard(card, DateTime(2025, 12, 25));
```

## Use Cases

- **Flashcard Apps**: Language learning, medical study, exam preparation
- **Educational Platforms**: Course content review, knowledge retention
- **Personal Knowledge Management**: Note review systems
- **Any Learning Application**: Anything that benefits from spaced repetition

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Used In Production

- [Revisable](https://github.com/makieali/revisable-app) - A powerful flashcard app for efficient learning

## Acknowledgments

- Based on the SM-2 algorithm by Piotr Wozniak
- Inspired by Anki and SuperMemo
