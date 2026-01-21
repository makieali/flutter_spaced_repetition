import 'package:flutter_spaced_repetition/flutter_spaced_repetition.dart';
import 'package:test/test.dart';

void main() {
  group('SpacedRepetitionEngine', () {
    late SpacedRepetitionEngine engine;

    setUp(() {
      engine = SpacedRepetitionEngine();
    });

    group('construction', () {
      test('uses Anki settings by default', () {
        final defaultEngine = SpacedRepetitionEngine();
        expect(defaultEngine.settings.initialEaseFactor, 2.5);
        expect(defaultEngine.settings.learningSteps.length, 2);
      });

      test('accepts custom settings', () {
        final customEngine = SpacedRepetitionEngine(
          settings: SRSSettings.aggressive(),
        );
        expect(customEngine.settings.learningSteps.length, 3);
      });

      test('uses correct algorithm for settings type', () {
        final sm2Engine = SpacedRepetitionEngine(
          settings: const SRSSettings(algorithmType: SRSAlgorithmType.sm2),
        );
        expect(sm2Engine.algorithm, isA<SM2Algorithm>());

        final sm2PlusEngine = SpacedRepetitionEngine(
          settings: const SRSSettings(algorithmType: SRSAlgorithmType.sm2Plus),
        );
        expect(sm2PlusEngine.algorithm, isA<SM2PlusAlgorithm>());
      });

      test('validates settings on construction', () {
        expect(
          () => SpacedRepetitionEngine(
            settings: const SRSSettings(learningSteps: []),
          ),
          throwsArgumentError,
        );
      });
    });

    group('createCard', () {
      test('creates new card with correct defaults', () {
        final card = engine.createCard(id: 'test_1');

        expect(card.id, 'test_1');
        expect(card.isNew, true);
        expect(card.easeFactor, engine.settings.initialEaseFactor);
      });

      test('passes metadata to card', () {
        final card = engine.createCard(
          id: 'test_2',
          metadata: {'deck': 'vocabulary'},
        );

        expect(card.metadata?['deck'], 'vocabulary');
      });
    });

    group('processReview', () {
      test('returns ReviewResult with updated card', () {
        final card = engine.createCard(id: 'test');
        final result = engine.processReview(card, ReviewQuality.good);

        expect(result.updatedCard, isNot(same(card)));
        expect(result.updatedCard.totalReviews, 1);
        expect(result.quality, ReviewQuality.good);
      });

      test('accepts custom review time', () {
        final card = engine.createCard(id: 'test');
        final customTime = DateTime(2025, 6, 15);

        final result = engine.processReview(
          card,
          ReviewQuality.good,
          reviewTime: customTime,
        );

        expect(result.reviewedAt, customTime);
        expect(result.updatedCard.lastReviewedAt, customTime);
      });
    });

    group('processBatch', () {
      test('processes multiple reviews', () {
        final cards = [
          engine.createCard(id: 'card_1'),
          engine.createCard(id: 'card_2'),
          engine.createCard(id: 'card_3'),
        ];

        final reviews = [
          (cards[0], ReviewQuality.good),
          (cards[1], ReviewQuality.easy),
          (cards[2], ReviewQuality.again),
        ];

        final results = engine.processBatch(reviews);

        expect(results.length, 3);
        expect(results[0].quality, ReviewQuality.good);
        expect(results[1].quality, ReviewQuality.easy);
        expect(results[2].quality, ReviewQuality.again);
      });

      test('uses same timestamp for all reviews', () {
        final cards = [
          engine.createCard(id: 'card_1'),
          engine.createCard(id: 'card_2'),
        ];

        final reviews = [
          (cards[0], ReviewQuality.good),
          (cards[1], ReviewQuality.easy),
        ];

        final results = engine.processBatch(reviews);

        expect(results[0].reviewedAt, results[1].reviewedAt);
      });
    });

    group('previewIntervals', () {
      test('returns intervals for all qualities', () {
        final card = engine.createCard(id: 'test');
        final preview = engine.previewIntervals(card);

        expect(preview.againInterval, isNotNull);
        expect(preview.hardInterval, isNotNull);
        expect(preview.goodInterval, isNotNull);
        expect(preview.easyInterval, isNotNull);
      });

      test('formatted intervals are human-readable', () {
        final card = engine.createCard(id: 'test');
        final preview = engine.previewIntervals(card);

        expect(preview.formattedAgainInterval, contains(RegExp(r'\d')));
        expect(preview.formattedGoodInterval, contains(RegExp(r'\d')));
      });
    });

    group('isDue', () {
      test('returns true for past due cards', () {
        final card = engine.createCard(id: 'test').copyWith(
          nextReviewTime: DateTime.now().subtract(const Duration(hours: 1)),
        );
        expect(engine.isDue(card), true);
      });

      test('returns false for future due cards', () {
        final card = engine.createCard(id: 'test').copyWith(
          nextReviewTime: DateTime.now().add(const Duration(hours: 1)),
        );
        expect(engine.isDue(card), false);
      });

      test('respects asOf parameter', () {
        final dueTime = DateTime(2025, 6, 15, 12, 0);
        final card = engine.createCard(id: 'test').copyWith(
          nextReviewTime: dueTime,
        );

        expect(
          engine.isDue(card, asOf: DateTime(2025, 6, 15, 11, 0)),
          false,
        );
        expect(
          engine.isDue(card, asOf: DateTime(2025, 6, 15, 13, 0)),
          true,
        );
      });
    });

    group('getDueCards', () {
      test('filters to only due cards', () {
        final now = DateTime.now();
        final cards = [
          engine.createCard(id: 'due_1').copyWith(
            nextReviewTime: now.subtract(const Duration(hours: 1)),
          ),
          engine.createCard(id: 'not_due').copyWith(
            nextReviewTime: now.add(const Duration(hours: 1)),
          ),
          engine.createCard(id: 'due_2').copyWith(
            nextReviewTime: now.subtract(const Duration(minutes: 30)),
          ),
        ];

        final dueCards = engine.getDueCards(cards);

        expect(dueCards.length, 2);
        expect(dueCards.map((c) => c.id), containsAll(['due_1', 'due_2']));
      });
    });

    group('sortByPriority', () {
      test('puts overdue cards first', () {
        final now = DateTime.now();
        final cards = [
          engine.createCard(id: 'future').copyWith(
            nextReviewTime: now.add(const Duration(hours: 1)),
          ),
          engine.createCard(id: 'overdue').copyWith(
            nextReviewTime: now.subtract(const Duration(hours: 2)),
          ),
          engine.createCard(id: 'less_overdue').copyWith(
            nextReviewTime: now.subtract(const Duration(hours: 1)),
          ),
        ];

        final sorted = engine.sortByPriority(cards);

        expect(sorted[0].id, 'overdue'); // Most overdue first
        expect(sorted[1].id, 'less_overdue');
        expect(sorted[2].id, 'future');
      });
    });

    group('updateSettings', () {
      test('updates settings', () {
        engine.updateSettings(SRSSettings.aggressive());
        expect(engine.settings.learningSteps.length, 3);
      });

      test('validates new settings', () {
        expect(
          () => engine.updateSettings(const SRSSettings(learningSteps: [])),
          throwsArgumentError,
        );
      });

      test('updates algorithm when type changes', () {
        engine.updateSettings(
          const SRSSettings(algorithmType: SRSAlgorithmType.sm2Plus),
        );
        expect(engine.algorithm, isA<SM2PlusAlgorithm>());
      });
    });

    group('setAlgorithm', () {
      test('allows custom algorithm', () {
        const customAlgorithm = CustomAlgorithm();
        engine.setAlgorithm(customAlgorithm);
        expect(engine.algorithm, customAlgorithm);
      });
    });

    group('wouldGraduate', () {
      test('returns true for Easy on new card', () {
        final card = engine.createCard(id: 'test');
        expect(engine.wouldGraduate(card, ReviewQuality.easy), true);
      });

      test('returns false for Again on new card', () {
        final card = engine.createCard(id: 'test');
        expect(engine.wouldGraduate(card, ReviewQuality.again), false);
      });
    });

    group('wouldLapse', () {
      test('returns true for Again on review card', () {
        final card = engine.createCard(id: 'test').copyWith(
          phase: CardPhase.review,
        );
        expect(engine.wouldLapse(card, ReviewQuality.again), true);
      });

      test('returns false for Good on review card', () {
        final card = engine.createCard(id: 'test').copyWith(
          phase: CardPhase.review,
        );
        expect(engine.wouldLapse(card, ReviewQuality.good), false);
      });
    });

    group('isLeech', () {
      test('returns true for cards with many lapses', () {
        final card = engine.createCard(id: 'test').copyWith(
          lapseCount: 10,
        );
        expect(engine.isLeech(card), true);
      });

      test('returns false for cards with few lapses', () {
        final card = engine.createCard(id: 'test').copyWith(
          lapseCount: 2,
        );
        expect(engine.isLeech(card), false);
      });

      test('respects lapsesBeforeLeech setting', () {
        final strictEngine = SpacedRepetitionEngine(
          settings: const SRSSettings(lapsesBeforeLeech: 3),
        );
        final card = engine.createCard(id: 'test').copyWith(
          lapseCount: 3,
        );
        expect(strictEngine.isLeech(card), true);
      });
    });

    group('resetCard', () {
      test('resets card to initial state', () {
        final card = engine.createCard(id: 'test').copyWith(
          phase: CardPhase.review,
          repetitions: 10,
          easeFactor: 1.5,
          intervalMinutes: 10000,
          successCount: 15,
        );

        final resetCard = engine.resetCard(card);

        expect(resetCard.isNew, true);
        expect(resetCard.repetitions, 0);
        expect(resetCard.easeFactor, engine.settings.initialEaseFactor);
        expect(resetCard.intervalMinutes, 0);
        expect(resetCard.successCount, 0);
      });

      test('preserves card ID and creation time', () {
        final card = engine.createCard(id: 'original');
        final resetCard = engine.resetCard(card);

        expect(resetCard.id, card.id);
        expect(resetCard.createdAt, card.createdAt);
      });

      test('preserves lapse count for leech detection', () {
        final card = engine.createCard(id: 'test').copyWith(
          lapseCount: 5,
        );
        final resetCard = engine.resetCard(card);

        expect(resetCard.lapseCount, 5);
      });
    });

    group('suspendCard and unsuspendCard', () {
      test('suspendCard sets far future due date', () {
        final card = engine.createCard(id: 'test');
        final suspended = engine.suspendCard(card);

        expect(
          suspended.nextReviewTime.isAfter(
            DateTime.now().add(const Duration(days: 36400)),
          ),
          true,
        );
        expect(engine.isSuspended(suspended), true);
      });

      test('unsuspendCard makes card due now', () {
        final card = engine.createCard(id: 'test');
        final suspended = engine.suspendCard(card);
        final unsuspended = engine.unsuspendCard(suspended);

        expect(engine.isDue(unsuspended), true);
        expect(engine.isSuspended(unsuspended), false);
      });
    });

    group('rescheduleCard', () {
      test('sets new due date', () {
        final card = engine.createCard(id: 'test');
        final newDate = DateTime(2025, 12, 25);

        final rescheduled = engine.rescheduleCard(card, newDate);

        expect(rescheduled.nextReviewTime, newDate);
      });
    });

    group('postponeCard', () {
      test('adds duration to due date', () {
        final card = engine.createCard(id: 'test').copyWith(
          nextReviewTime: DateTime(2025, 6, 15),
        );

        final postponed = engine.postponeCard(card, const Duration(days: 3));

        expect(postponed.nextReviewTime, DateTime(2025, 6, 18));
      });
    });

    group('getCardSummary', () {
      test('returns comprehensive summary', () {
        final card = engine.createCard(id: 'test').copyWith(
          phase: CardPhase.review,
          successCount: 5,
          failureCount: 1,
          streak: 3,
        );

        final summary = engine.getCardSummary(card);

        expect(summary['id'], 'test');
        expect(summary['phase'], 'review');
        expect(summary['streak'], 3);
        expect(summary['totalReviews'], 6);
      });
    });
  });
}
