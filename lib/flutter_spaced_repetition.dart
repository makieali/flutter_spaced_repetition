/// A pure Dart implementation of spaced repetition algorithms (SM-2, SM-2+).
///
/// This library provides a complete, production-ready spaced repetition system
/// that can be used in flashcard apps, language learning apps, or any
/// application that benefits from optimized review scheduling.
///
/// ## Features
///
/// - **Multiple Algorithms**: SM-2 (classic), SM-2+ (improved), and custom
/// - **Fully Configurable**: All 17+ settings are functional (no dead code)
/// - **No Dependencies**: Pure Dart, works everywhere (Flutter, CLI, server)
/// - **Statistics**: Per-card and deck-level analytics
/// - **Scheduling**: Priority-based card ordering and session management
/// - **Serialization**: Full JSON import/export support
///
/// ## Quick Start
///
/// ```dart
/// import 'package:flutter_spaced_repetition/flutter_spaced_repetition.dart';
///
/// // Create engine with default Anki-like settings
/// final engine = SpacedRepetitionEngine();
///
/// // Create a new card
/// var card = engine.createCard(id: 'card_1');
///
/// // Process a review
/// final result = engine.processReview(card, ReviewQuality.good);
/// card = result.updatedCard;
///
/// // Check next review time
/// print('Next review: ${card.formattedDueTime}');
/// print('Interval: ${card.formattedInterval}');
///
/// // Preview intervals for UI buttons
/// final preview = engine.previewIntervals(card);
/// print('Again: ${preview.formattedAgainInterval}');
/// print('Good: ${preview.formattedGoodInterval}');
/// ```
///
/// ## Customization
///
/// ```dart
/// // Use preset configurations
/// final aggressive = SpacedRepetitionEngine(
///   settings: SRSSettings.aggressive(),
/// );
///
/// // Or fully customize
/// final custom = SpacedRepetitionEngine(
///   settings: SRSSettings(
///     learningSteps: [Duration(minutes: 1), Duration(minutes: 10)],
///     graduatingInterval: Duration(days: 1),
///     easyInterval: Duration(days: 4),
///     minimumEaseFactor: 1.3,
///     maximumInterval: Duration(days: 365),
///   ),
/// );
/// ```
///
/// ## Statistics
///
/// ```dart
/// // Card-level statistics
/// final stats = CardStatistics(card);
/// print('Success rate: ${stats.successRate}');
/// print('Stability: ${stats.stability}');
///
/// // Deck-level statistics
/// final deckStats = DeckStatistics(cards);
/// print('Total cards: ${deckStats.totalCards}');
/// print('Due today: ${deckStats.dueToday}');
///
/// // Mastery calculation
/// final calculator = MasteryCalculator();
/// final mastery = calculator.calculate(card);
/// print('Mastery level: ${mastery.level.label}');
/// ```
library flutter_spaced_repetition;

// Models
export 'src/models/review_card.dart';
export 'src/models/review_quality.dart';
export 'src/models/review_result.dart';
export 'src/models/srs_settings.dart';
export 'src/models/interval_preview.dart';

// Algorithms
export 'src/algorithm/srs_algorithm.dart';
export 'src/algorithm/sm2_algorithm.dart';
export 'src/algorithm/sm2_plus_algorithm.dart';
export 'src/algorithm/custom_algorithm.dart';

// Engine
export 'src/engine/spaced_repetition_engine.dart';

// Scheduler
export 'src/scheduler/review_scheduler.dart';
export 'src/scheduler/priority_queue.dart';

// Statistics
export 'src/statistics/card_statistics.dart';
export 'src/statistics/deck_statistics.dart';
export 'src/statistics/mastery_calculator.dart';

// Utilities
export 'src/utils/interval_formatter.dart';
export 'src/utils/validators.dart';
export 'src/utils/serialization.dart';
