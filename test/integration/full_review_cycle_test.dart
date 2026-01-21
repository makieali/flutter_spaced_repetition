import 'package:flutter_spaced_repetition/flutter_spaced_repetition.dart';
import 'package:test/test.dart';

void main() {
  group('Full Review Cycle Integration', () {
    late SpacedRepetitionEngine engine;

    setUp(() {
      engine = SpacedRepetitionEngine(settings: SRSSettings.anki());
    });

    test('new card through learning to review phase', () {
      var card = engine.createCard(id: 'vocab_1');

      // New card starts due
      expect(card.isNew, true);
      expect(engine.isDue(card), true);

      // First review - Good
      var result = engine.processReview(card, ReviewQuality.good);
      card = result.updatedCard;

      expect(card.phase, CardPhase.learning);
      expect(card.learningStepIndex, 1);
      expect(card.intervalMinutes, 10); // Second learning step

      // Simulate time passing
      card = card.copyWith(
        nextReviewTime: DateTime.now().subtract(const Duration(minutes: 1)),
      );

      // Second review - Good (graduates)
      result = engine.processReview(card, ReviewQuality.good);
      card = result.updatedCard;

      expect(result.graduatedFromLearning, true);
      expect(card.phase, CardPhase.review);
      expect(card.intervalMinutes, 1440); // 1 day

      // Verify card is no longer due immediately
      expect(card.nextReviewTime.isAfter(DateTime.now()), true);
    });

    test('card with lapses recovers', () {
      var card = engine.createCard(id: 'difficult_card');

      // Graduate the card
      for (var i = 0; i < 2; i++) {
        final result = engine.processReview(card, ReviewQuality.good);
        card = result.updatedCard.copyWith(
          nextReviewTime: DateTime.now().subtract(const Duration(minutes: 1)),
        );
      }

      expect(card.phase, CardPhase.review);
      final initialEase = card.easeFactor;

      // Lapse
      var result = engine.processReview(card, ReviewQuality.again);
      card = result.updatedCard;

      expect(result.lapsedToLearning, true);
      expect(card.phase, CardPhase.relearning);
      expect(card.lapseCount, 1);
      expect(card.easeFactor, lessThan(initialEase));

      // Recover through relearning
      for (var i = 0; i < 2; i++) {
        result = engine.processReview(card, ReviewQuality.good);
        card = result.updatedCard.copyWith(
          nextReviewTime: DateTime.now().subtract(const Duration(minutes: 1)),
        );
      }

      expect(card.phase, CardPhase.review);
    });

    test('easy rating provides fast track', () {
      var card = engine.createCard(id: 'easy_card');

      // Easy on first review - immediate graduation
      final result = engine.processReview(card, ReviewQuality.easy);
      card = result.updatedCard;

      expect(result.graduatedFromLearning, true);
      expect(card.phase, CardPhase.review);
      expect(card.intervalMinutes, engine.settings.easyInterval.inMinutes);
    });

    test('statistics accumulate correctly', () {
      var card = engine.createCard(id: 'stats_card');

      // Mix of responses
      final responses = [
        ReviewQuality.good,
        ReviewQuality.good,
        ReviewQuality.hard,
        ReviewQuality.again,
        ReviewQuality.good,
        ReviewQuality.easy,
      ];

      for (final quality in responses) {
        final result = engine.processReview(card, quality);
        card = result.updatedCard.copyWith(
          nextReviewTime: DateTime.now().subtract(const Duration(minutes: 1)),
        );
      }

      expect(card.totalReviews, 6);
      // successCount = 3 goods + 1 easy = 4 (easy is also counted as success)
      expect(card.successCount, 4);
      expect(card.easyCount, 1);
      expect(card.hardCount, 1);
      expect(card.failureCount, 1);
      expect(card.lapseCount, greaterThanOrEqualTo(0)); // May or may not have lapsed
    });

    test('long-term interval growth', () {
      var card = engine.createCard(id: 'growth_card');

      // Graduate
      for (var i = 0; i < 2; i++) {
        final result = engine.processReview(card, ReviewQuality.good);
        card = result.updatedCard.copyWith(
          nextReviewTime: DateTime.now().subtract(const Duration(minutes: 1)),
        );
      }

      final intervals = <int>[card.intervalMinutes];

      // Simulate 10 successful reviews
      for (var i = 0; i < 10; i++) {
        final result = engine.processReview(card, ReviewQuality.good);
        card = result.updatedCard.copyWith(
          nextReviewTime: DateTime.now().subtract(const Duration(minutes: 1)),
        );
        intervals.add(card.intervalMinutes);
      }

      // Intervals should generally increase
      for (var i = 1; i < intervals.length; i++) {
        expect(
          intervals[i],
          greaterThanOrEqualTo(intervals[i - 1]),
          reason: 'Interval at $i should be >= interval at ${i - 1}',
        );
      }

      // Final interval should be much longer than starting
      expect(intervals.last, greaterThan(intervals.first * 5));
    });

    test('scheduler prioritizes correctly', () {
      final scheduler = ReviewScheduler();
      final now = DateTime.now();

      final cards = [
        engine.createCard(id: 'overdue').copyWith(
          phase: CardPhase.review,
          nextReviewTime: now.subtract(const Duration(days: 2)),
          intervalMinutes: 1440,
        ),
        engine.createCard(id: 'new'),
        engine.createCard(id: 'learning').copyWith(
          phase: CardPhase.learning,
          nextReviewTime: now.subtract(const Duration(minutes: 5)),
        ),
        engine.createCard(id: 'not_due').copyWith(
          phase: CardPhase.review,
          nextReviewTime: now.add(const Duration(days: 1)),
        ),
      ];

      final batch = scheduler.getNextBatch(cards);

      // Overdue and learning should be first
      expect(batch.length, greaterThan(0));
      expect(
        batch.take(2).map((c) => c.id),
        containsAll(['overdue', 'learning']),
      );
    });

    test('mastery calculator reflects progress', () {
      final calculator = MasteryCalculator();

      // New card has no mastery
      final newCard = engine.createCard(id: 'new');
      var mastery = calculator.calculate(newCard);
      expect(mastery.level, MasteryLevel.notStarted);
      expect(mastery.score, 0.0);

      // Card in learning phase
      var result = engine.processReview(newCard, ReviewQuality.good);
      var card = result.updatedCard;
      mastery = calculator.calculate(card);
      expect(mastery.level, MasteryLevel.learning);

      // Graduate and review successfully multiple times
      for (var i = 0; i < 15; i++) {
        result = engine.processReview(card, ReviewQuality.good);
        card = result.updatedCard.copyWith(
          nextReviewTime: DateTime.now().subtract(const Duration(minutes: 1)),
        );
      }

      mastery = calculator.calculate(card);
      expect(mastery.score, greaterThan(0.3));
      expect(
        [MasteryLevel.familiar, MasteryLevel.proficient, MasteryLevel.mastered, MasteryLevel.expert],
        contains(mastery.level),
      );
    });

    test('serialization preserves state through cycle', () {
      var card = engine.createCard(id: 'serialize_test');

      // Do some reviews
      for (var i = 0; i < 5; i++) {
        final result = engine.processReview(card, ReviewQuality.good);
        card = result.updatedCard.copyWith(
          nextReviewTime: DateTime.now().subtract(const Duration(minutes: 1)),
        );
      }

      // Serialize and deserialize
      final json = card.toJson();
      final restored = ReviewCard.fromJson(json);

      expect(restored.id, card.id);
      expect(restored.phase, card.phase);
      expect(restored.easeFactor, card.easeFactor);
      expect(restored.intervalMinutes, card.intervalMinutes);
      expect(restored.successCount, card.successCount);
      expect(restored.streak, card.streak);

      // Can continue reviewing
      final result = engine.processReview(restored, ReviewQuality.good);
      expect(result.updatedCard.successCount, restored.successCount + 1);
    });

    test('deck statistics reflect card states', () {
      final cards = <ReviewCard>[];

      // Create cards in various states
      for (var i = 0; i < 5; i++) {
        cards.add(engine.createCard(id: 'new_$i'));
      }

      for (var i = 0; i < 3; i++) {
        var card = engine.createCard(id: 'learning_$i');
        final result = engine.processReview(card, ReviewQuality.good);
        cards.add(result.updatedCard);
      }

      for (var i = 0; i < 4; i++) {
        var card = engine.createCard(id: 'review_$i');
        for (var j = 0; j < 3; j++) {
          final result = engine.processReview(card, ReviewQuality.good);
          card = result.updatedCard.copyWith(
            nextReviewTime: DateTime.now().subtract(const Duration(minutes: 1)),
          );
        }
        cards.add(card);
      }

      final stats = DeckStatistics(cards);

      expect(stats.totalCards, 12);
      expect(stats.newCards, 5);
      expect(stats.learningCards, 3);
      expect(stats.reviewCards, 4);
    });
  });

  group('Long-term Simulation', () {
    test('simulates 30 days of reviews', () {
      final engine = SpacedRepetitionEngine();
      final cards = <ReviewCard>[];
      final startTime = DateTime(2025, 1, 1);

      // Create 20 cards, all due at the start of simulation
      for (var i = 0; i < 20; i++) {
        cards.add(engine.createCard(id: 'card_$i').copyWith(
          nextReviewTime: startTime,
          createdAt: startTime,
        ));
      }

      var currentTime = startTime;
      const simulationDays = 30;

      for (var day = 0; day < simulationDays; day++) {
        // Get due cards for today
        final dueCards = cards.where((c) {
          return currentTime.isAfter(c.nextReviewTime) ||
              currentTime.isAtSameMomentAs(c.nextReviewTime);
        }).toList();

        // Review each due card
        for (var card in dueCards) {
          final idx = cards.indexWhere((c) => c.id == card.id);

          // Simulate varying quality (mostly good, some hard, few again)
          final quality = _simulateQuality(day, card.successCount);

          final result = engine.processReview(
            card,
            quality,
            reviewTime: currentTime,
          );

          cards[idx] = result.updatedCard;
        }

        // Move to next day
        currentTime = currentTime.add(const Duration(days: 1));
      }

      // Verify cards have progressed
      final stats = DeckStatistics(cards);

      expect(stats.totalReviews, greaterThan(0));
      expect(stats.reviewCards, greaterThan(0)); // Some should have graduated
      expect(stats.averageSuccessRate, greaterThan(0.5));
    });
  });
}

ReviewQuality _simulateQuality(int day, int successCount) {
  // Early reviews are harder
  if (day < 3 && successCount == 0) {
    return (day % 3 == 0) ? ReviewQuality.again : ReviewQuality.hard;
  }

  // Most reviews are good
  final rand = (day * 17 + successCount * 31) % 100;
  if (rand < 5) return ReviewQuality.again;
  if (rand < 15) return ReviewQuality.hard;
  if (rand < 85) return ReviewQuality.good;
  return ReviewQuality.easy;
}
