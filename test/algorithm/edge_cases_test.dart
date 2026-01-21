import 'package:flutter_spaced_repetition/flutter_spaced_repetition.dart';
import 'package:test/test.dart';

void main() {
  group('Edge Cases', () {
    late SM2Algorithm algorithm;
    late SRSSettings settings;

    setUp(() {
      algorithm = const SM2Algorithm();
      settings = SRSSettings.anki();
    });

    group('boundary values', () {
      test('handles ease factor at exactly minimum', () {
        final card = ReviewCard.newCard(id: 'test').copyWith(
          phase: CardPhase.review,
          easeFactor: 1.3, // Exactly minimum
          intervalMinutes: 1440,
        );

        // Again should not go below minimum
        final result = algorithm.processReview(
          card,
          ReviewQuality.again,
          settings,
        );
        expect(
          result.updatedCard.easeFactor,
          greaterThanOrEqualTo(settings.minimumEaseFactor),
        );
      });

      test('handles very long intervals', () {
        final card = ReviewCard.newCard(id: 'test').copyWith(
          phase: CardPhase.review,
          easeFactor: 2.5,
          intervalMinutes: 365 * 24 * 60, // 1 year
        );

        final result = algorithm.processReview(
          card,
          ReviewQuality.good,
          settings,
        );

        // Should be clamped to max
        expect(
          result.updatedCard.intervalMinutes,
          lessThanOrEqualTo(settings.maximumInterval.inMinutes),
        );
      });

      test('handles very short intervals', () {
        final card = ReviewCard.newCard(id: 'test').copyWith(
          phase: CardPhase.review,
          easeFactor: 1.3,
          intervalMinutes: 1, // 1 minute
        );

        final result = algorithm.processReview(
          card,
          ReviewQuality.good,
          settings,
        );

        // Should be at least minimum
        expect(
          result.updatedCard.intervalMinutes,
          greaterThanOrEqualTo(settings.minimumInterval.inMinutes),
        );
      });

      test('handles zero interval gracefully', () {
        final card = ReviewCard.newCard(id: 'test').copyWith(
          phase: CardPhase.review,
          easeFactor: 2.5,
          intervalMinutes: 0,
        );

        final result = algorithm.processReview(
          card,
          ReviewQuality.good,
          settings,
        );

        // Should still produce a valid interval
        expect(result.updatedCard.intervalMinutes, greaterThan(0));
      });
    });

    group('multiple lapses', () {
      test('tracks multiple lapses correctly', () {
        var card = ReviewCard.newCard(id: 'test').copyWith(
          phase: CardPhase.review,
          intervalMinutes: 1440,
          easeFactor: 2.5,
        );

        // Lapse multiple times
        for (var i = 0; i < 5; i++) {
          final result = algorithm.processReview(
            card,
            ReviewQuality.again,
            settings,
          );
          card = result.updatedCard;

          // Re-graduate
          for (var j = 0; j < settings.learningSteps.length; j++) {
            final stepResult = algorithm.processReview(
              card,
              ReviewQuality.good,
              settings,
            );
            card = stepResult.updatedCard;
          }
        }

        expect(card.lapseCount, 5);
        expect(card.easeFactor, lessThan(2.5));
        expect(card.easeFactor, greaterThanOrEqualTo(settings.minimumEaseFactor));
      });
    });

    group('custom settings', () {
      test('respects single learning step', () {
        final singleStepSettings = settings.copyWith(
          learningSteps: [const Duration(minutes: 5)],
          graduationsRequired: 1,
        );

        var card = ReviewCard.newCard(id: 'test');

        // Should graduate after one Good
        final result = algorithm.processReview(
          card,
          ReviewQuality.good,
          singleStepSettings,
        );

        expect(result.graduatedFromLearning, true);
        expect(result.updatedCard.phase, CardPhase.review);
      });

      test('respects many learning steps', () {
        final manyStepSettings = settings.copyWith(
          learningSteps: [
            const Duration(minutes: 1),
            const Duration(minutes: 5),
            const Duration(minutes: 10),
            const Duration(minutes: 30),
          ],
          graduationsRequired: 4,
        );

        var card = ReviewCard.newCard(id: 'test');

        // Should not graduate until all steps complete
        for (var i = 0; i < 3; i++) {
          final result = algorithm.processReview(
            card,
            ReviewQuality.good,
            manyStepSettings,
          );
          card = result.updatedCard;
          expect(result.graduatedFromLearning, false);
          expect(card.phase, CardPhase.learning);
        }

        // Fourth Good should graduate
        final finalResult = algorithm.processReview(
          card,
          ReviewQuality.good,
          manyStepSettings,
        );
        expect(finalResult.graduatedFromLearning, true);
        expect(finalResult.updatedCard.phase, CardPhase.review);
      });

      test('respects custom lapse multiplier', () {
        final lapseSettings = settings.copyWith(lapseMultiplier: 0.5);

        final card = ReviewCard.newCard(id: 'test').copyWith(
          phase: CardPhase.review,
          intervalMinutes: 10080, // 7 days
          easeFactor: 2.5,
        );

        final result = algorithm.processReview(
          card,
          ReviewQuality.again,
          lapseSettings,
        );

        // With lapse multiplier 0.5, should be around half the interval
        // but at least minimum interval
        expect(
          result.updatedCard.intervalMinutes,
          greaterThanOrEqualTo(lapseSettings.minimumInterval.inMinutes),
        );
      });
    });

    group('review time override', () {
      test('uses provided review time', () {
        final card = ReviewCard.newCard(id: 'test');
        final customTime = DateTime(2025, 6, 15, 10, 30);

        final result = algorithm.processReview(
          card,
          ReviewQuality.good,
          settings,
          reviewTime: customTime,
        );

        expect(result.reviewedAt, customTime);
        expect(result.updatedCard.lastReviewedAt, customTime);
      });

      test('next review time is based on review time', () {
        final card = ReviewCard.newCard(id: 'test');
        final customTime = DateTime(2025, 6, 15, 10, 30);

        final result = algorithm.processReview(
          card,
          ReviewQuality.good,
          settings,
          reviewTime: customTime,
        );

        // Next review should be after the custom time
        expect(result.updatedCard.nextReviewTime.isAfter(customTime), true);
      });
    });

    group('relearning phase', () {
      test('relearning follows same steps as learning', () {
        final card = ReviewCard.newCard(id: 'test').copyWith(
          phase: CardPhase.relearning,
          learningStepIndex: 0,
          intervalMinutes: 1,
        );

        final result = algorithm.processReview(
          card,
          ReviewQuality.good,
          settings,
        );

        expect(result.updatedCard.learningStepIndex, 1);
      });

      test('Again in relearning resets step', () {
        final card = ReviewCard.newCard(id: 'test').copyWith(
          phase: CardPhase.relearning,
          learningStepIndex: 1,
        );

        final result = algorithm.processReview(
          card,
          ReviewQuality.again,
          settings,
        );

        expect(result.updatedCard.learningStepIndex, 0);
      });
    });

    group('consecutive reviews', () {
      test('handles many consecutive reviews without error', () {
        var card = ReviewCard.newCard(id: 'test');

        // Simulate 100 reviews
        for (var i = 0; i < 100; i++) {
          final quality = i % 4 == 0
              ? ReviewQuality.again
              : i % 3 == 0
                  ? ReviewQuality.hard
                  : i % 2 == 0
                      ? ReviewQuality.good
                      : ReviewQuality.easy;

          final result = algorithm.processReview(card, quality, settings);
          card = result.updatedCard;

          // Invariants should always hold
          expect(card.easeFactor, greaterThanOrEqualTo(settings.minimumEaseFactor));
          expect(card.intervalMinutes, greaterThanOrEqualTo(0));
          expect(
            card.intervalMinutes,
            lessThanOrEqualTo(settings.maximumInterval.inMinutes),
          );
        }
      });
    });
  });
}
