import 'package:flutter_spaced_repetition/flutter_spaced_repetition.dart';
import 'package:test/test.dart';

void main() {
  group('SM2Algorithm', () {
    late SM2Algorithm algorithm;
    late SRSSettings settings;

    setUp(() {
      algorithm = const SM2Algorithm();
      settings = SRSSettings.anki();
    });

    group('new card first review', () {
      test('Again resets to first learning step', () {
        final card = ReviewCard.newCard(id: 'test');
        final result = algorithm.processReview(
          card,
          ReviewQuality.again,
          settings,
        );

        expect(result.updatedCard.phase, CardPhase.learning);
        expect(result.updatedCard.learningStepIndex, 0);
        expect(result.updatedCard.intervalMinutes, 1);
        expect(result.wasFirstReview, true);
        expect(result.graduatedFromLearning, false);
      });

      test('Good advances to next learning step', () {
        final card = ReviewCard.newCard(id: 'test');
        final result = algorithm.processReview(
          card,
          ReviewQuality.good,
          settings,
        );

        expect(result.updatedCard.phase, CardPhase.learning);
        expect(result.updatedCard.learningStepIndex, 1);
        expect(result.updatedCard.intervalMinutes, 10);
        expect(result.advancedLearningStep, true);
      });

      test('Easy graduates immediately', () {
        final card = ReviewCard.newCard(id: 'test');
        final result = algorithm.processReview(
          card,
          ReviewQuality.easy,
          settings,
        );

        expect(result.updatedCard.phase, CardPhase.review);
        expect(result.graduatedFromLearning, true);
        expect(result.updatedCard.intervalMinutes, settings.easyInterval.inMinutes);
      });
    });

    group('learning phase', () {
      test('completes learning steps and graduates', () {
        var card = ReviewCard.newCard(id: 'test');

        // First Good - advances to step 1
        var result = algorithm.processReview(card, ReviewQuality.good, settings);
        card = result.updatedCard;
        expect(card.learningStepIndex, 1);
        expect(card.phase, CardPhase.learning);

        // Second Good - graduates
        result = algorithm.processReview(card, ReviewQuality.good, settings);
        card = result.updatedCard;
        expect(card.phase, CardPhase.review);
        expect(result.graduatedFromLearning, true);
        expect(card.intervalMinutes, settings.graduatingInterval.inMinutes);
      });

      test('Again resets progress', () {
        var card = ReviewCard.newCard(id: 'test');

        // Advance to step 1
        var result = algorithm.processReview(card, ReviewQuality.good, settings);
        card = result.updatedCard;
        expect(card.learningStepIndex, 1);

        // Again resets
        result = algorithm.processReview(card, ReviewQuality.again, settings);
        card = result.updatedCard;
        expect(card.learningStepIndex, 0);
        expect(card.repetitions, 0);
      });

      test('Hard stays at current step', () {
        var card = ReviewCard.newCard(id: 'test');

        // First Good
        var result = algorithm.processReview(card, ReviewQuality.good, settings);
        card = result.updatedCard;
        expect(card.learningStepIndex, 1);

        // Hard keeps at step 1
        result = algorithm.processReview(card, ReviewQuality.hard, settings);
        card = result.updatedCard;
        expect(card.learningStepIndex, 1);
        expect(card.phase, CardPhase.learning);
      });
    });

    group('review phase', () {
      ReviewCard createReviewCard({
        int intervalMinutes = 1440,
        double easeFactor = 2.5,
        int repetitions = 3,
      }) {
        return ReviewCard.newCard(id: 'test').copyWith(
          phase: CardPhase.review,
          intervalMinutes: intervalMinutes,
          easeFactor: easeFactor,
          repetitions: repetitions,
        );
      }

      test('Good multiplies interval by ease factor', () {
        final card = createReviewCard(intervalMinutes: 1440, easeFactor: 2.5);
        final result = algorithm.processReview(
          card,
          ReviewQuality.good,
          settings,
        );

        // New interval should be at least current * ease
        // With minimum growth and potential fuzz
        expect(result.updatedCard.intervalMinutes, greaterThan(1440));
      });

      test('Easy applies easy bonus', () {
        final card = createReviewCard(intervalMinutes: 1440, easeFactor: 2.5);
        final resultGood = algorithm.processReview(
          card,
          ReviewQuality.good,
          settings,
        );
        final resultEasy = algorithm.processReview(
          card,
          ReviewQuality.easy,
          settings,
        );

        expect(
          resultEasy.updatedCard.intervalMinutes,
          greaterThan(resultGood.updatedCard.intervalMinutes),
        );
      });

      test('Again causes lapse', () {
        final card = createReviewCard();
        final result = algorithm.processReview(
          card,
          ReviewQuality.again,
          settings,
        );

        expect(result.lapsedToLearning, true);
        expect(result.updatedCard.phase, CardPhase.relearning);
        expect(result.updatedCard.lapseCount, 1);
      });

      test('Hard reduces interval', () {
        final card = createReviewCard(intervalMinutes: 10080); // 7 days
        final result = algorithm.processReview(
          card,
          ReviewQuality.hard,
          settings,
        );

        // Hard uses hardIntervalMultiplier which is > 1 but ease decreases
        expect(result.updatedCard.easeFactor, lessThan(card.easeFactor));
      });
    });

    group('ease factor adjustments', () {
      test('Again decreases ease factor', () {
        const currentEase = 2.5;
        final newEase = algorithm.calculateNewEaseFactor(
          currentEase,
          ReviewQuality.again,
          settings,
        );
        expect(newEase, lessThan(currentEase));
        expect(newEase, currentEase - settings.againEasePenalty);
      });

      test('Hard decreases ease factor', () {
        const currentEase = 2.5;
        final newEase = algorithm.calculateNewEaseFactor(
          currentEase,
          ReviewQuality.hard,
          settings,
        );
        expect(newEase, lessThan(currentEase));
        expect(newEase, currentEase - settings.hardEasePenalty);
      });

      test('Good does not change ease factor', () {
        const currentEase = 2.5;
        final newEase = algorithm.calculateNewEaseFactor(
          currentEase,
          ReviewQuality.good,
          settings,
        );
        expect(newEase, currentEase);
      });

      test('Easy increases ease factor', () {
        const currentEase = 2.5;
        final newEase = algorithm.calculateNewEaseFactor(
          currentEase,
          ReviewQuality.easy,
          settings,
        );
        expect(newEase, greaterThan(currentEase));
        expect(newEase, currentEase + settings.easyEaseBonus);
      });

      test('ease factor never goes below minimum', () {
        const currentEase = 1.35;
        final newEase = algorithm.calculateNewEaseFactor(
          currentEase,
          ReviewQuality.again,
          settings,
        );
        expect(newEase, settings.minimumEaseFactor);
      });
    });

    group('interval bounds', () {
      test('intervals are clamped to maximum', () {
        final card = ReviewCard.newCard(id: 'test').copyWith(
          phase: CardPhase.review,
          intervalMinutes: 300 * 1440, // 300 days
          easeFactor: 3.0,
        );

        final result = algorithm.processReview(
          card,
          ReviewQuality.easy,
          settings,
        );

        expect(
          result.updatedCard.intervalMinutes,
          lessThanOrEqualTo(settings.maximumInterval.inMinutes),
        );
      });

      test('intervals are at least minimum', () {
        final card = ReviewCard.newCard(id: 'test').copyWith(
          phase: CardPhase.review,
          intervalMinutes: 60, // 1 hour
          easeFactor: 1.5,
        );

        final result = algorithm.processReview(
          card,
          ReviewQuality.good,
          settings,
        );

        expect(
          result.updatedCard.intervalMinutes,
          greaterThanOrEqualTo(settings.minimumInterval.inMinutes),
        );
      });
    });

    group('previewIntervals', () {
      test('returns all four intervals', () {
        final card = ReviewCard.newCard(id: 'test');
        final preview = algorithm.previewIntervals(card, settings);

        expect(preview.againInterval, isNotNull);
        expect(preview.hardInterval, isNotNull);
        expect(preview.goodInterval, isNotNull);
        expect(preview.easyInterval, isNotNull);
      });

      test('Easy interval is longest for new cards', () {
        final card = ReviewCard.newCard(id: 'test');
        final preview = algorithm.previewIntervals(card, settings);

        expect(preview.easyInterval, greaterThan(preview.goodInterval));
        expect(preview.goodInterval, greaterThanOrEqualTo(preview.hardInterval));
      });

      test('Again interval is shortest', () {
        final card = ReviewCard.newCard(id: 'test').copyWith(
          phase: CardPhase.review,
          intervalMinutes: 1440,
        );
        final preview = algorithm.previewIntervals(card, settings);

        expect(preview.againInterval, lessThan(preview.hardInterval));
      });
    });

    group('statistics tracking', () {
      test('tracks success count on Good', () {
        final card = ReviewCard.newCard(id: 'test');
        final result = algorithm.processReview(
          card,
          ReviewQuality.good,
          settings,
        );
        expect(result.updatedCard.successCount, 1);
      });

      test('tracks easy count on Easy', () {
        final card = ReviewCard.newCard(id: 'test');
        final result = algorithm.processReview(
          card,
          ReviewQuality.easy,
          settings,
        );
        expect(result.updatedCard.easyCount, 1);
        expect(result.updatedCard.successCount, 1);
      });

      test('tracks failure count on Again', () {
        final card = ReviewCard.newCard(id: 'test');
        final result = algorithm.processReview(
          card,
          ReviewQuality.again,
          settings,
        );
        expect(result.updatedCard.failureCount, 1);
      });

      test('tracks hard count on Hard', () {
        final card = ReviewCard.newCard(id: 'test');
        final result = algorithm.processReview(
          card,
          ReviewQuality.hard,
          settings,
        );
        expect(result.updatedCard.hardCount, 1);
      });

      test('maintains streak on success', () {
        var card = ReviewCard.newCard(id: 'test');

        for (var i = 0; i < 5; i++) {
          final result = algorithm.processReview(
            card,
            ReviewQuality.good,
            settings,
          );
          card = result.updatedCard;
        }

        expect(card.streak, 5);
        expect(card.longestStreak, 5);
      });

      test('resets streak on Again', () {
        var card = ReviewCard.newCard(id: 'test').copyWith(
          streak: 5,
          longestStreak: 5,
        );

        final result = algorithm.processReview(
          card,
          ReviewQuality.again,
          settings,
        );

        expect(result.updatedCard.streak, 0);
        expect(result.updatedCard.longestStreak, 5); // Preserved
      });
    });
  });
}
