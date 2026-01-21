/// A pure Dart implementation of spaced repetition algorithms (SM-2, SM-2+, FSRS).
///
/// This library provides a complete, production-ready spaced repetition system
/// that can be used in flashcard apps, language learning apps, or any
/// application that benefits from optimized review scheduling.
///
/// ## Features
///
/// - **Multiple Algorithms**: SM-2 (classic), SM-2+ (improved), FSRS (modern), and custom
/// - **Fully Configurable**: All 17+ settings are functional (no dead code)
/// - **No Dependencies**: Pure Dart, works everywhere (Flutter, CLI, server)
/// - **Statistics**: Per-card and deck-level analytics with mastery tracking
/// - **Analytics**: Forgetting curves, workload forecasting, retention analysis
/// - **Scheduling**: Priority-based card ordering and session management
/// - **Serialization**: Full JSON import/export support, Anki/CSV compatibility
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
/// ## Using FSRS Algorithm
///
/// FSRS (Free Spaced Repetition Scheduler) is 20-30% more efficient than SM-2.
///
/// ```dart
/// final engine = SpacedRepetitionEngine(
///   settings: SRSSettings(algorithmType: SRSAlgorithmType.fsrs),
/// );
///
/// // Get retrievability (probability of recall)
/// final retrievability = engine.getRetrievability(card);
/// print('Chance of recall: ${(retrievability * 100).toStringAsFixed(0)}%');
///
/// // Get forgetting curve data for visualization
/// final curve = engine.getForgettingCurve(card, days: 30);
///
/// // Get workload forecast
/// final forecast = engine.getWorkloadForecast(cards, days: 30);
/// ```
///
/// ## Statistics & Analytics
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
///
/// // Retention analytics
/// final retention = RetentionAnalytics();
/// print('30-day retention: ${retention.calculateRetention(history)}');
/// ```
///
/// ## Import/Export
///
/// ```dart
/// // Import from CSV
/// final result = SRSImporter.fromCSV(csvContent);
///
/// // Export to JSON
/// final json = SRSExporter.toJSON(cards, settings: engine.settings);
///
/// // Migrate from SM-2 to FSRS
/// final migratedCards = AlgorithmMigration.sm2ToFSRS(cards);
/// ```
library flutter_spaced_repetition;

// Models
export 'src/models/review_card.dart';
export 'src/models/review_quality.dart';
export 'src/models/review_result.dart';
export 'src/models/srs_settings.dart';
export 'src/models/interval_preview.dart';
export 'src/models/review_log.dart';
export 'src/models/fsrs_models.dart';

// Algorithms
export 'src/algorithm/srs_algorithm.dart';
export 'src/algorithm/sm2_algorithm.dart';
export 'src/algorithm/sm2_plus_algorithm.dart';
export 'src/algorithm/fsrs_algorithm.dart';
export 'src/algorithm/fsrs_optimizer.dart';
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

// Analytics
export 'src/analytics/analytics.dart';

// Utilities
export 'src/utils/interval_formatter.dart';
export 'src/utils/validators.dart';
export 'src/utils/serialization.dart';
export 'src/utils/importers.dart';
