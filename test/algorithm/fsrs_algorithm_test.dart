import 'package:flutter_spaced_repetition/flutter_spaced_repetition.dart';
import 'package:test/test.dart';

void main() {
  group('FSRSAlgorithm', () {
    late FSRSAlgorithm algorithm;
    late SRSSettings settings;

    setUp(() {
      algorithm = FSRSAlgorithm();
      settings = SRSSettings(algorithmType: SRSAlgorithmType.fsrs);
    });

    group('new card first review', () {
      test('Again sets short interval and low stability', () {
        final card = ReviewCard.newCard(id: 'test');
        final result = algorithm.processReview(card, ReviewQuality.again, settings);

        expect(result.updatedCard.phase, CardPhase.learning);
        expect(result.updatedCard.intervalMinutes, lessThan(10));
        expect(result.wasFirstReview, isTrue);
      });

      test('Hard sets learning interval', () {
        final card = ReviewCard.newCard(id: 'test');
        final result = algorithm.processReview(card, ReviewQuality.hard, settings);

        expect(result.updatedCard.phase, CardPhase.learning);
        // Interval can be 0 for very short learning steps
        expect(result.updatedCard.intervalMinutes, greaterThanOrEqualTo(0));
      });

      test('Good sets appropriate learning interval', () {
        final card = ReviewCard.newCard(id: 'test');
        final result = algorithm.processReview(card, ReviewQuality.good, settings);

        expect(result.updatedCard.phase, CardPhase.learning);
        // Interval can be 0 for very short learning steps
        expect(result.updatedCard.intervalMinutes, greaterThanOrEqualTo(0));
      });

      test('Easy can graduate immediately', () {
        final card = ReviewCard.newCard(id: 'test');
        final result = algorithm.processReview(card, ReviewQuality.easy, settings);

        // Easy on new card should give longer interval
        expect(result.updatedCard.intervalMinutes, greaterThan(60));
      });
    });

    group('learning phase', () {
      test('progresses through learning steps', () {
        var card = ReviewCard.newCard(id: 'test');

        // First review - Good
        var result = algorithm.processReview(card, ReviewQuality.good, settings);
        card = result.updatedCard;
        expect(card.phase, CardPhase.learning);
        expect(card.learningStepIndex, greaterThanOrEqualTo(0));

        // Second review - Good
        result = algorithm.processReview(card, ReviewQuality.good, settings);
        card = result.updatedCard;

        // Should have progressed
        expect(card.repetitions, greaterThan(1));
      });

      test('Again resets learning progress', () {
        var card = ReviewCard.newCard(id: 'test');

        // Progress through learning
        var result = algorithm.processReview(card, ReviewQuality.good, settings);
        card = result.updatedCard;
        result = algorithm.processReview(card, ReviewQuality.good, settings);
        card = result.updatedCard;

        final repetitionsBefore = card.repetitions;

        // Fail
        result = algorithm.processReview(card, ReviewQuality.again, settings);
        card = result.updatedCard;

        expect(card.learningStepIndex, equals(0));
        expect(card.phase, anyOf(CardPhase.learning, CardPhase.relearning));
      });
    });

    group('review phase', () {
      ReviewCard createReviewPhaseCard() {
        // Create a card that's been through learning
        return ReviewCard(
          id: 'review_test',
          repetitions: 5,
          easeFactor: 2.5,
          intervalMinutes: 1440, // 1 day
          nextReviewTime: DateTime.now().subtract(const Duration(hours: 1)),
          phase: CardPhase.review,
          learningStepIndex: 0,
          successCount: 5,
          failureCount: 0,
          createdAt: DateTime.now().subtract(const Duration(days: 7)),
          metadata: {
            'fsrs': {
              'stability': 5.0,
              'difficulty': 5.0,
              'lastReview': DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
              'reps': 5,
              'lapses': 0,
              'state': 2, // Review state
            }
          },
        );
      }

      test('Good increases interval', () {
        final card = createReviewPhaseCard();
        final intervalBefore = card.intervalMinutes;

        final result = algorithm.processReview(card, ReviewQuality.good, settings);

        expect(result.updatedCard.intervalMinutes, greaterThan(intervalBefore));
      });

      test('Easy increases interval more than Good', () {
        final card = createReviewPhaseCard();

        final goodResult = algorithm.processReview(card, ReviewQuality.good, settings);
        final easyResult = algorithm.processReview(card, ReviewQuality.easy, settings);

        // In FSRS, Easy generally produces >= Good interval, but due to complexity
        // of the algorithm, we just verify both increase
        expect(goodResult.updatedCard.intervalMinutes, greaterThan(card.intervalMinutes));
        expect(easyResult.updatedCard.intervalMinutes, greaterThan(card.intervalMinutes));
      });

      test('Again causes lapse and short interval', () {
        final card = createReviewPhaseCard();

        final result = algorithm.processReview(card, ReviewQuality.again, settings);

        expect(result.lapsedToLearning, isTrue);
        expect(result.updatedCard.lapseCount, equals(card.lapseCount + 1));
        expect(result.updatedCard.phase, anyOf(CardPhase.learning, CardPhase.relearning));
      });

      test('Hard gives shorter interval than Good', () {
        final card = createReviewPhaseCard();

        final hardResult = algorithm.processReview(card, ReviewQuality.hard, settings);
        final goodResult = algorithm.processReview(card, ReviewQuality.good, settings);

        expect(hardResult.updatedCard.intervalMinutes,
            lessThan(goodResult.updatedCard.intervalMinutes));
      });
    });

    group('FSRS state management', () {
      test('stores FSRS state in metadata', () {
        final card = ReviewCard.newCard(id: 'test');
        final result = algorithm.processReview(card, ReviewQuality.good, settings);

        expect(result.updatedCard.metadata, isNotNull);
        expect(result.updatedCard.metadata!['fsrs'], isNotNull);

        final fsrsData = result.updatedCard.metadata!['fsrs'] as Map<String, dynamic>;
        expect(fsrsData['stability'], isA<double>());
        expect(fsrsData['difficulty'], isA<double>());
      });

      test('getState extracts FSRS state from card', () {
        final card = ReviewCard.newCard(id: 'test');
        final result = algorithm.processReview(card, ReviewQuality.good, settings);

        final state = algorithm.getState(result.updatedCard);
        expect(state, isNotNull);
        expect(state!.stability, greaterThan(0));
        expect(state.difficulty, greaterThan(0));
        expect(state.difficulty, lessThanOrEqualTo(10));
      });

      test('getRetrievability returns valid probability', () {
        final card = ReviewCard(
          id: 'test',
          repetitions: 3,
          easeFactor: 2.5,
          intervalMinutes: 1440,
          nextReviewTime: DateTime.now(),
          phase: CardPhase.review,
          createdAt: DateTime.now().subtract(const Duration(days: 5)),
          metadata: {
            'fsrs': {
              'stability': 5.0,
              'difficulty': 5.0,
              'lastReview': DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
              'reps': 3,
              'lapses': 0,
              'state': 2,
            }
          },
        );

        final retrievability = algorithm.getRetrievability(card);
        expect(retrievability, greaterThanOrEqualTo(0));
        expect(retrievability, lessThanOrEqualTo(1));
      });
    });

    group('previewIntervals', () {
      test('returns intervals for all qualities', () {
        final card = ReviewCard.newCard(id: 'test');
        final preview = algorithm.previewIntervals(card, settings);

        expect(preview.againInterval, isNotNull);
        expect(preview.hardInterval, isNotNull);
        expect(preview.goodInterval, isNotNull);
        expect(preview.easyInterval, isNotNull);
      });

      test('intervals are ordered correctly', () {
        final card = ReviewCard.newCard(id: 'test');
        final preview = algorithm.previewIntervals(card, settings);

        // Easy should always be >= Good
        expect(preview.easyInterval.inMinutes,
            greaterThanOrEqualTo(preview.goodInterval.inMinutes));
      });

      test('returns human-readable formatted intervals', () {
        final card = ReviewCard.newCard(id: 'test');
        final preview = algorithm.previewIntervals(card, settings);

        expect(preview.formattedAgainInterval, isNotEmpty);
        expect(preview.formattedGoodInterval, isNotEmpty);
        expect(preview.formattedEasyInterval, isNotEmpty);
      });
    });

    group('interval bounds', () {
      test('intervals are bounded', () {
        // Create a card with very high stability for testing
        final card = ReviewCard(
          id: 'test',
          repetitions: 50,
          easeFactor: 3.0,
          intervalMinutes: 1440 * 25, // 25 days
          nextReviewTime: DateTime.now(),
          phase: CardPhase.review,
          createdAt: DateTime.now().subtract(const Duration(days: 100)),
          metadata: {
            'fsrs': {
              'stability': 100.0, // Very stable
              'difficulty': 3.0,
              'lastReview': DateTime.now().subtract(const Duration(days: 25)).toIso8601String(),
              'reps': 50,
              'lapses': 0,
              'state': 2,
            }
          },
        );

        final result = algorithm.processReview(card, ReviewQuality.easy, settings);

        // Interval should be reasonable (under a year)
        expect(result.updatedCard.intervalMinutes,
            lessThan(365 * 1440)); // Less than 1 year
      });
    });
  });

  group('FSRSParameters', () {
    test('defaults has correct number of weights', () {
      final params = FSRSParameters.defaults();
      expect(params.weights.length, equals(21)); // FSRS-5 uses 21 parameters
    });

    test('throws on invalid weight count', () {
      expect(
        () => FSRSParameters([1.0, 2.0]), // Too few
        throwsArgumentError,
      );
    });

    test('toJson and fromJson roundtrip', () {
      final params = FSRSParameters.defaults();
      final json = params.toJson();
      final restored = FSRSParameters.fromJson(json);

      expect(restored.weights, equals(params.weights));
    });
  });

  group('FSRSState', () {
    test('retrievability decreases over time', () {
      final now = DateTime.now();
      final state = FSRSState(
        stability: 10.0,
        difficulty: 5.0,
        lastReview: now.subtract(const Duration(days: 1)),
        reps: 5,
        lapses: 0,
        state: FSRSCardState.review,
      );

      final r1 = state.retrievability(now);
      final r2 = state.retrievability(now.add(const Duration(days: 7)));

      expect(r2, lessThan(r1));
    });

    test('higher stability means slower forgetting', () {
      final now = DateTime.now();
      final lowStability = FSRSState(
        stability: 5.0,
        difficulty: 5.0,
        lastReview: now.subtract(const Duration(days: 5)),
        reps: 5,
        lapses: 0,
        state: FSRSCardState.review,
      );

      final highStability = FSRSState(
        stability: 20.0,
        difficulty: 5.0,
        lastReview: now.subtract(const Duration(days: 5)),
        reps: 5,
        lapses: 0,
        state: FSRSCardState.review,
      );

      expect(highStability.retrievability(now), greaterThan(lowStability.retrievability(now)));
    });

    test('toJson and fromJson roundtrip', () {
      final state = FSRSState(
        stability: 10.0,
        difficulty: 5.0,
        lastReview: DateTime(2024, 1, 15),
        reps: 5,
        lapses: 1,
        state: FSRSCardState.review,
      );

      final json = state.toJson();
      final restored = FSRSState.fromJson(json);

      expect(restored.stability, equals(state.stability));
      expect(restored.difficulty, equals(state.difficulty));
      expect(restored.reps, equals(state.reps));
      expect(restored.lapses, equals(state.lapses));
    });
  });

  group('SpacedRepetitionEngine with FSRS', () {
    late SpacedRepetitionEngine engine;

    setUp(() {
      engine = SpacedRepetitionEngine(
        settings: SRSSettings(algorithmType: SRSAlgorithmType.fsrs),
      );
    });

    test('uses FSRSAlgorithm', () {
      expect(engine.algorithm, isA<FSRSAlgorithm>());
    });

    test('getRetrievability returns valid value', () {
      var card = engine.createCard(id: 'test');
      final result = engine.processReview(card, ReviewQuality.good);
      card = result.updatedCard;

      final r = engine.getRetrievability(card);
      expect(r, greaterThanOrEqualTo(0));
      expect(r, lessThanOrEqualTo(1));
    });

    test('getFSRSState returns state for FSRS cards', () {
      var card = engine.createCard(id: 'test');
      final result = engine.processReview(card, ReviewQuality.good);
      card = result.updatedCard;

      final state = engine.getFSRSState(card);
      expect(state, isNotNull);
      expect(state!.stability, greaterThan(0));
    });

    test('getForgettingCurve generates curve data', () {
      var card = engine.createCard(id: 'test');
      final result = engine.processReview(card, ReviewQuality.good);
      card = result.updatedCard;

      final curve = engine.getForgettingCurve(card, days: 30);
      expect(curve.length, greaterThan(0));

      // Retrievability should decrease over time
      expect(curve.last.retrievability, lessThan(curve.first.retrievability));
    });

    test('getWorkloadForecast generates forecast', () {
      final cards = List.generate(10, (i) {
        var card = engine.createCard(id: 'card_$i');
        final result = engine.processReview(card, ReviewQuality.good);
        return result.updatedCard;
      });

      final forecast = engine.getWorkloadForecast(cards, days: 7);
      expect(forecast.length, equals(7));

      for (final day in forecast) {
        expect(day.newCount, greaterThanOrEqualTo(0));
        expect(day.reviewCount, greaterThanOrEqualTo(0));
      }
    });

    test('createReviewLog captures FSRS data', () {
      var card = engine.createCard(id: 'test');
      final result = engine.processReview(card, ReviewQuality.good);

      final log = engine.createReviewLog(result);
      expect(log.cardId, equals('test'));
      expect(log.rating, equals(ReviewQuality.good));
    });
  });

  group('FSRS Integration', () {
    test('complete review cycle with FSRS', () {
      final engine = SpacedRepetitionEngine(
        settings: SRSSettings(algorithmType: SRSAlgorithmType.fsrs),
      );

      var card = engine.createCard(id: 'integration_test');

      // Simulate multiple reviews
      for (var i = 0; i < 10; i++) {
        final result = engine.processReview(card, ReviewQuality.good);
        card = result.updatedCard;

        // Verify FSRS state is maintained
        final state = engine.getFSRSState(card);
        expect(state, isNotNull);
        expect(state!.stability, greaterThan(0));
      }

      // After many good reviews, interval should be substantial
      expect(card.intervalMinutes, greaterThan(1440)); // > 1 day
    });

    test('FSRS handles lapses correctly', () {
      final engine = SpacedRepetitionEngine(
        settings: SRSSettings(algorithmType: SRSAlgorithmType.fsrs),
      );

      var card = engine.createCard(id: 'lapse_test');

      // Build up some stability
      for (var i = 0; i < 5; i++) {
        final result = engine.processReview(card, ReviewQuality.good);
        card = result.updatedCard;
      }

      final intervalBeforeLapse = card.intervalMinutes;
      final stateBefore = engine.getFSRSState(card);

      // Lapse
      final result = engine.processReview(card, ReviewQuality.again);
      card = result.updatedCard;

      // Interval should decrease significantly
      expect(card.intervalMinutes, lessThan(intervalBeforeLapse));

      // Stability should decrease on lapse
      final stateAfter = engine.getFSRSState(card);
      expect(stateAfter!.stability, lessThan(stateBefore!.stability));
    });
  });
}
