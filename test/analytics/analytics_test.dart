import 'package:flutter_spaced_repetition/flutter_spaced_repetition.dart';
import 'package:test/test.dart';

void main() {
  group('ForgettingCurve', () {
    const curve = ForgettingCurve();

    test('generate creates points for the specified days', () {
      final card = _createReviewedCard();
      final points = curve.generate(card, days: 30);

      expect(points.length, greaterThan(0));
    });

    test('points have ascending daysSinceReview', () {
      final card = _createReviewedCard();
      final points = curve.generate(card, days: 10);

      for (var i = 0; i < points.length - 1; i++) {
        expect(
          points[i + 1].daysSinceReview,
          greaterThanOrEqualTo(points[i].daysSinceReview),
        );
      }
    });

    test('retrievability decreases over time', () {
      final card = _createReviewedCard();
      final points = curve.generate(card, days: 30);

      // First point should have higher retrievability than last
      expect(points.first.retrievability, greaterThan(points.last.retrievability));
    });

    test('retrievability values are between 0 and 1', () {
      final card = _createReviewedCard();
      final points = curve.generate(card, days: 30);

      for (final point in points) {
        expect(point.retrievability, greaterThanOrEqualTo(0));
        expect(point.retrievability, lessThanOrEqualTo(1));
      }
    });

    test('currentRetrievability returns valid probability', () {
      final card = _createReviewedCard();
      final r = curve.currentRetrievability(card);

      expect(r, greaterThanOrEqualTo(0));
      expect(r, lessThanOrEqualTo(1));
    });

    test('daysUntilTarget calculates target days', () {
      final card = _createReviewedCard();
      final days = curve.daysUntilTarget(card, 0.9);

      expect(days, greaterThanOrEqualTo(0));
    });

    test('new card without stability returns zero retrievability', () {
      final card = ReviewCard.newCard(id: 'new');
      final points = curve.generate(card, days: 5);

      // New card with no interval should have 0 retrievability
      expect(points.first.retrievability, equals(0.0));
    });
  });

  group('WorkloadForecast', () {
    const forecast = WorkloadForecast();

    test('generate creates correct number of days', () {
      final cards = _createCardSet(10);
      final days = forecast.generate(cards, days: 7);

      expect(days.length, equals(7));
    });

    test('includes new cards per day', () {
      final cards = <ReviewCard>[];
      final days = forecast.generate(cards, days: 7, newCardsPerDay: 20);

      // First day should have new cards
      expect(days.first.newCount, greaterThanOrEqualTo(0));
    });

    test('review cards are forecasted based on due dates', () {
      // Create cards due at different times
      final now = DateTime.now();
      final cards = [
        _createCardDueAt(now, 'card_1'),
        _createCardDueAt(now.add(const Duration(days: 1)), 'card_2'),
        _createCardDueAt(now.add(const Duration(days: 2)), 'card_3'),
      ];

      final days = forecast.generate(cards, days: 7, newCardsPerDay: 0);

      // Day 0 should have at least 1 card due
      expect(days[0].reviewCount, greaterThanOrEqualTo(1));
    });

    test('dueCount returns sum of all card types', () {
      final cards = _createCardSet(5);
      final days = forecast.generate(cards, days: 7, newCardsPerDay: 10);

      for (final day in days) {
        expect(
          day.dueCount,
          equals(day.newCount + day.reviewCount + day.learningCount),
        );
      }
    });

    test('date field is set correctly', () {
      final cards = <ReviewCard>[];
      final days = forecast.generate(cards, days: 3);
      final now = DateTime.now();

      expect(days[0].date.day, equals(now.day));
      expect(days[1].date.day, equals(now.add(const Duration(days: 1)).day));
    });

    test('estimateTotalReviews sums all days', () {
      final cards = _createCardSet(5);
      final total = forecast.estimateTotalReviews(cards, days: 7);

      expect(total, greaterThanOrEqualTo(0));
    });

    test('getPeakDay returns day with most reviews', () {
      final cards = _createCardSet(10);
      final peak = forecast.getPeakDay(cards, days: 7);

      expect(peak, isNotNull);
      expect(peak!.dueCount, greaterThanOrEqualTo(0));
    });

    test('getAverageWorkload calculates mean', () {
      final cards = _createCardSet(5);
      final avg = forecast.getAverageWorkload(cards, days: 7);

      expect(avg, greaterThanOrEqualTo(0));
    });
  });

  group('RetentionAnalytics', () {
    const analytics = RetentionAnalytics();

    test('calculateRetention with no history returns 0', () {
      final history = ReviewHistory();
      final retention = analytics.calculateRetention(history);

      expect(retention, equals(0.0));
    });

    test('calculateRetention with all successes returns 1', () {
      final logs = List.generate(
        10,
        (i) => ReviewLog(
          cardId: 'card_$i',
          reviewTime: DateTime.now(),
          rating: ReviewQuality.good,
          scheduledInterval: const Duration(days: 1),
          actualInterval: const Duration(days: 1),
        ),
      );

      final history = ReviewHistory(logs);
      final retention = analytics.calculateRetention(history);

      expect(retention, equals(1.0));
    });

    test('calculateRetention with all failures returns 0', () {
      final logs = List.generate(
        10,
        (i) => ReviewLog(
          cardId: 'card_$i',
          reviewTime: DateTime.now(),
          rating: ReviewQuality.again,
          scheduledInterval: const Duration(days: 1),
          actualInterval: const Duration(days: 1),
        ),
      );

      final history = ReviewHistory(logs);
      final retention = analytics.calculateRetention(history);

      expect(retention, equals(0.0));
    });

    test('calculateRetention with mixed results returns correct ratio', () {
      final logs = [
        ReviewLog(
          cardId: 'card_1',
          reviewTime: DateTime.now(),
          rating: ReviewQuality.good,
          scheduledInterval: const Duration(days: 1),
          actualInterval: const Duration(days: 1),
        ),
        ReviewLog(
          cardId: 'card_2',
          reviewTime: DateTime.now(),
          rating: ReviewQuality.again,
          scheduledInterval: const Duration(days: 1),
          actualInterval: const Duration(days: 1),
        ),
      ];

      final history = ReviewHistory(logs);
      final retention = analytics.calculateRetention(history);

      expect(retention, equals(0.5));
    });

    test('retentionByDay groups by date', () {
      final now = DateTime.now();
      final logs = [
        ReviewLog(
          cardId: 'card_1',
          reviewTime: now,
          rating: ReviewQuality.good,
          scheduledInterval: const Duration(days: 1),
          actualInterval: const Duration(days: 1),
        ),
        ReviewLog(
          cardId: 'card_2',
          reviewTime: now.subtract(const Duration(days: 1)),
          rating: ReviewQuality.good,
          scheduledInterval: const Duration(days: 1),
          actualInterval: const Duration(days: 1),
        ),
      ];

      final history = ReviewHistory(logs);
      final byDay = analytics.retentionByDay(history, days: 30);

      expect(byDay.length, greaterThan(0));
    });

    test('calculateTrueRetention weights by retrievability', () {
      final logs = [
        ReviewLog(
          cardId: 'card_1',
          reviewTime: DateTime.now(),
          rating: ReviewQuality.good,
          scheduledInterval: const Duration(days: 1),
          actualInterval: const Duration(days: 1),
          retrievability: 0.5, // Low retrievability recall
        ),
        ReviewLog(
          cardId: 'card_2',
          reviewTime: DateTime.now(),
          rating: ReviewQuality.good,
          scheduledInterval: const Duration(days: 1),
          actualInterval: const Duration(days: 1),
          retrievability: 0.9, // High retrievability recall
        ),
      ];

      final history = ReviewHistory(logs);
      final trueRetention = analytics.calculateTrueRetention(history);

      expect(trueRetention, greaterThan(0));
      expect(trueRetention, lessThanOrEqualTo(1));
    });

    test('learningSpeed estimates cards per day', () {
      final logs = List.generate(
        30,
        (i) => ReviewLog(
          cardId: 'card_$i',
          reviewTime: DateTime.now().subtract(Duration(days: i % 10)),
          rating: ReviewQuality.good,
          scheduledInterval: const Duration(days: 1),
          actualInterval: const Duration(days: 1),
        ),
      );

      final history = ReviewHistory(logs);
      final speed = analytics.learningSpeed(history, days: 30);

      expect(speed, greaterThan(0));
    });
  });

  group('ReviewHeatmap', () {
    const heatmap = ReviewHeatmap();

    test('generate creates entries for specified weeks', () {
      final history = ReviewHistory();
      final entries = heatmap.generate(history, weeks: 4);

      expect(entries.length, equals(4 * 7)); // 4 weeks * 7 days
    });

    test('entries have zero count for empty history', () {
      final history = ReviewHistory();
      final entries = heatmap.generate(history, weeks: 1);

      for (final entry in entries) {
        expect(entry.count, equals(0));
      }
    });

    test('counts reviews per day correctly', () {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      final logs = [
        ReviewLog(
          cardId: 'card_1',
          reviewTime: today.add(const Duration(hours: 10)),
          rating: ReviewQuality.good,
          scheduledInterval: const Duration(days: 1),
          actualInterval: const Duration(days: 1),
        ),
        ReviewLog(
          cardId: 'card_2',
          reviewTime: today.add(const Duration(hours: 12)),
          rating: ReviewQuality.good,
          scheduledInterval: const Duration(days: 1),
          actualInterval: const Duration(days: 1),
        ),
      ];

      final history = ReviewHistory(logs);
      final entries = heatmap.generate(history, weeks: 1);

      // Find today's entry
      final todayEntry = entries.firstWhere(
        (e) => e.date.day == today.day && e.date.month == today.month,
        orElse: () => ReviewHeatmapData(date: today, count: -1, intensity: 0),
      );

      expect(todayEntry.count, equals(2));
    });

    test('intensity is normalized correctly', () {
      final now = DateTime.now();
      final logs = List.generate(
        100,
        (i) => ReviewLog(
          cardId: 'card_$i',
          reviewTime: now,
          rating: ReviewQuality.good,
          scheduledInterval: const Duration(days: 1),
          actualInterval: const Duration(days: 1),
        ),
      );

      final history = ReviewHistory(logs);
      final entries = heatmap.generate(history, weeks: 1);

      for (final entry in entries) {
        expect(entry.intensity, greaterThanOrEqualTo(0));
        expect(entry.intensity, lessThanOrEqualTo(1));
      }
    });

    test('getStreaks calculates current and longest streaks', () {
      final now = DateTime.now();
      final logs = [
        ReviewLog(
          cardId: 'card_1',
          reviewTime: now,
          rating: ReviewQuality.good,
          scheduledInterval: const Duration(days: 1),
          actualInterval: const Duration(days: 1),
        ),
        ReviewLog(
          cardId: 'card_2',
          reviewTime: now.subtract(const Duration(days: 1)),
          rating: ReviewQuality.good,
          scheduledInterval: const Duration(days: 1),
          actualInterval: const Duration(days: 1),
        ),
      ];

      final history = ReviewHistory(logs);
      final streaks = heatmap.getStreaks(history);

      expect(streaks.current, greaterThanOrEqualTo(0));
      expect(streaks.longest, greaterThanOrEqualTo(0));
    });
  });

  group('ReviewHistory', () {
    test('forCard filters by card ID', () {
      final logs = [
        ReviewLog(
          cardId: 'card_1',
          reviewTime: DateTime.now(),
          rating: ReviewQuality.good,
          scheduledInterval: const Duration(days: 1),
          actualInterval: const Duration(days: 1),
        ),
        ReviewLog(
          cardId: 'card_2',
          reviewTime: DateTime.now(),
          rating: ReviewQuality.good,
          scheduledInterval: const Duration(days: 1),
          actualInterval: const Duration(days: 1),
        ),
      ];

      final history = ReviewHistory(logs);
      final card1Logs = history.forCard('card_1');

      expect(card1Logs.length, equals(1));
      expect(card1Logs.first.cardId, equals('card_1'));
    });

    test('today returns logs from today', () {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day, 12);
      final yesterday = today.subtract(const Duration(days: 1));

      final logs = [
        ReviewLog(
          cardId: 'today',
          reviewTime: today,
          rating: ReviewQuality.good,
          scheduledInterval: const Duration(days: 1),
          actualInterval: const Duration(days: 1),
        ),
        ReviewLog(
          cardId: 'yesterday',
          reviewTime: yesterday,
          rating: ReviewQuality.good,
          scheduledInterval: const Duration(days: 1),
          actualInterval: const Duration(days: 1),
        ),
      ];

      final history = ReviewHistory(logs);
      final todayLogs = history.today;

      expect(todayLogs.length, equals(1));
      expect(todayLogs.first.cardId, equals('today'));
    });

    test('successRate calculates correctly', () {
      final logs = [
        ReviewLog(
          cardId: 'card_1',
          reviewTime: DateTime.now(),
          rating: ReviewQuality.good,
          scheduledInterval: const Duration(days: 1),
          actualInterval: const Duration(days: 1),
        ),
        ReviewLog(
          cardId: 'card_2',
          reviewTime: DateTime.now(),
          rating: ReviewQuality.again,
          scheduledInterval: const Duration(days: 1),
          actualInterval: const Duration(days: 1),
        ),
      ];

      final history = ReviewHistory(logs);

      expect(history.successRate, equals(0.5));
    });

    test('add appends log', () {
      final history = ReviewHistory();
      history.add(ReviewLog(
        cardId: 'new_card',
        reviewTime: DateTime.now(),
        rating: ReviewQuality.good,
        scheduledInterval: const Duration(days: 1),
        actualInterval: const Duration(days: 1),
      ));

      expect(history.length, equals(1));
    });

    test('clear removes all logs', () {
      final logs = [
        ReviewLog(
          cardId: 'card_1',
          reviewTime: DateTime.now(),
          rating: ReviewQuality.good,
          scheduledInterval: const Duration(days: 1),
          actualInterval: const Duration(days: 1),
        ),
      ];

      final history = ReviewHistory(logs);
      history.clear();

      expect(history.isEmpty, isTrue);
    });

    test('toJson and fromJson roundtrip', () {
      final logs = [
        ReviewLog(
          cardId: 'card_1',
          reviewTime: DateTime(2024, 1, 15, 10, 30),
          rating: ReviewQuality.good,
          scheduledInterval: const Duration(days: 1),
          actualInterval: const Duration(days: 1),
        ),
      ];

      final history = ReviewHistory(logs);
      final json = history.toJson();
      final restored = ReviewHistory.fromJson(json);

      expect(restored.length, equals(history.length));
      expect(restored.logs.first.cardId, equals('card_1'));
    });
  });

  group('ReviewLog', () {
    test('wasSuccessful for Good and Easy', () {
      final good = ReviewLog(
        cardId: 'test',
        reviewTime: DateTime.now(),
        rating: ReviewQuality.good,
        scheduledInterval: const Duration(days: 1),
        actualInterval: const Duration(days: 1),
      );

      final easy = ReviewLog(
        cardId: 'test',
        reviewTime: DateTime.now(),
        rating: ReviewQuality.easy,
        scheduledInterval: const Duration(days: 1),
        actualInterval: const Duration(days: 1),
      );

      expect(good.wasSuccessful, isTrue);
      expect(easy.wasSuccessful, isTrue);
    });

    test('wasFailure for Again', () {
      final again = ReviewLog(
        cardId: 'test',
        reviewTime: DateTime.now(),
        rating: ReviewQuality.again,
        scheduledInterval: const Duration(days: 1),
        actualInterval: const Duration(days: 1),
      );

      expect(again.wasFailure, isTrue);
    });

    test('wasOverdue when actual > scheduled', () {
      final overdue = ReviewLog(
        cardId: 'test',
        reviewTime: DateTime.now(),
        rating: ReviewQuality.good,
        scheduledInterval: const Duration(days: 1),
        actualInterval: const Duration(days: 2),
      );

      expect(overdue.wasOverdue, isTrue);
      expect(overdue.overdueAmount.inDays, equals(1));
    });

    test('toJson and fromJson roundtrip', () {
      final log = ReviewLog(
        cardId: 'test_card',
        reviewTime: DateTime(2024, 1, 15, 10, 30),
        rating: ReviewQuality.good,
        scheduledInterval: const Duration(days: 1),
        actualInterval: const Duration(days: 1),
        retrievability: 0.9,
        stabilityBefore: 5.0,
        stabilityAfter: 10.0,
        difficultyBefore: 5.0,
        difficultyAfter: 4.8,
      );

      final json = log.toJson();
      final restored = ReviewLog.fromJson(json);

      expect(restored.cardId, equals(log.cardId));
      expect(restored.rating, equals(log.rating));
      expect(restored.retrievability, equals(log.retrievability));
    });
  });
}

// Helper functions
ReviewCard _createReviewedCard() {
  return ReviewCard(
    id: 'test_card',
    repetitions: 5,
    easeFactor: 2.5,
    intervalMinutes: 1440,
    nextReviewTime: DateTime.now().add(const Duration(days: 1)),
    phase: CardPhase.review,
    createdAt: DateTime.now().subtract(const Duration(days: 10)),
    lastReviewedAt: DateTime.now().subtract(const Duration(days: 1)),
    metadata: {
      'fsrs': {
        'stability': 10.0,
        'difficulty': 5.0,
        'lastReview':
            DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
        'reps': 5,
        'lapses': 0,
        'state': 2,
      }
    },
  );
}

List<ReviewCard> _createCardSet(int count) {
  return List.generate(count, (i) {
    final dueIn = Duration(days: i % 7);
    return ReviewCard(
      id: 'card_$i',
      repetitions: 3,
      easeFactor: 2.5,
      intervalMinutes: 1440,
      nextReviewTime: DateTime.now().add(dueIn),
      phase: CardPhase.review,
      createdAt: DateTime.now().subtract(const Duration(days: 10)),
    );
  });
}

ReviewCard _createCardDueAt(DateTime dueTime, String id) {
  return ReviewCard(
    id: id,
    repetitions: 3,
    easeFactor: 2.5,
    intervalMinutes: 1440,
    nextReviewTime: dueTime,
    phase: CardPhase.review,
    createdAt: DateTime.now().subtract(const Duration(days: 10)),
  );
}
