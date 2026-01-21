import 'package:flutter_spaced_repetition/flutter_spaced_repetition.dart';
import 'package:test/test.dart';

void main() {
  group('ReviewCard', () {
    group('newCard factory', () {
      test('creates card with correct defaults', () {
        final card = ReviewCard.newCard(id: 'test_1');

        expect(card.id, 'test_1');
        expect(card.repetitions, 0);
        expect(card.easeFactor, 2.5);
        expect(card.intervalMinutes, 0);
        expect(card.isNew, true);
        expect(card.isInLearningPhase, false);
        expect(card.isInReviewPhase, false);
        expect(card.phase, CardPhase.isNew);
        expect(card.successCount, 0);
        expect(card.failureCount, 0);
        expect(card.streak, 0);
      });

      test('accepts custom ease factor', () {
        final card = ReviewCard.newCard(
          id: 'test_2',
          initialEaseFactor: 3.0,
        );
        expect(card.easeFactor, 3.0);
      });

      test('accepts metadata', () {
        final card = ReviewCard.newCard(
          id: 'test_3',
          metadata: {'deck': 'vocabulary', 'tags': ['spanish']},
        );
        expect(card.metadata?['deck'], 'vocabulary');
        expect(card.metadata?['tags'], ['spanish']);
      });

      test('sets creation time', () {
        final before = DateTime.now();
        final card = ReviewCard.newCard(id: 'test_4');
        final after = DateTime.now();

        expect(card.createdAt.isAfter(before.subtract(const Duration(seconds: 1))), true);
        expect(card.createdAt.isBefore(after.add(const Duration(seconds: 1))), true);
      });
    });

    group('properties', () {
      test('interval returns correct Duration', () {
        final card = ReviewCard.newCard(id: 'test').copyWith(
          intervalMinutes: 1440,
        );
        expect(card.interval, const Duration(days: 1));
      });

      test('totalReviews sums all review types', () {
        final card = ReviewCard.newCard(id: 'test').copyWith(
          successCount: 5,
          failureCount: 2,
          hardCount: 3,
        );
        expect(card.totalReviews, 10);
      });

      test('successRate calculates correctly', () {
        // successCount includes easy responses
        // easyCount is a subset for tracking purposes
        final card = ReviewCard.newCard(id: 'test').copyWith(
          successCount: 10, // includes 2 easy
          easyCount: 2,
          failureCount: 0,
          hardCount: 0,
        );
        expect(card.successRate, 1.0); // 10/10

        final mixedCard = ReviewCard.newCard(id: 'test').copyWith(
          successCount: 5, // includes 1 easy
          easyCount: 1,
          failureCount: 3,
          hardCount: 2,
        );
        // totalReviews = 5 + 3 + 2 = 10
        // successRate = 5/10 = 0.5
        expect(mixedCard.successRate, 0.5);
      });

      test('successRate returns 0 for no reviews', () {
        final card = ReviewCard.newCard(id: 'test');
        expect(card.successRate, 0.0);
      });

      test('formattedInterval formats correctly', () {
        expect(
          ReviewCard.newCard(id: 't').copyWith(intervalMinutes: 60).formattedInterval,
          '1h',
        );
        expect(
          ReviewCard.newCard(id: 't').copyWith(intervalMinutes: 1440).formattedInterval,
          '1d',
        );
        expect(
          ReviewCard.newCard(id: 't').copyWith(intervalMinutes: 10080).formattedInterval,
          '7d',
        );
      });
    });

    group('isDue', () {
      test('returns true for past due time', () {
        final card = ReviewCard.newCard(id: 'test').copyWith(
          nextReviewTime: DateTime.now().subtract(const Duration(hours: 1)),
        );
        expect(card.isDue, true);
      });

      test('returns false for future due time', () {
        final card = ReviewCard.newCard(id: 'test').copyWith(
          nextReviewTime: DateTime.now().add(const Duration(hours: 1)),
        );
        expect(card.isDue, false);
      });
    });

    group('copyWith', () {
      test('preserves unchanged values', () {
        final original = ReviewCard.newCard(id: 'test', metadata: {'key': 'value'});
        final copy = original.copyWith(easeFactor: 2.8);

        expect(copy.id, original.id);
        expect(copy.metadata, original.metadata);
        expect(copy.createdAt, original.createdAt);
        expect(copy.easeFactor, 2.8);
      });

      test('allows changing all fields', () {
        final original = ReviewCard.newCard(id: 'original');
        final modified = original.copyWith(
          id: 'modified',
          repetitions: 5,
          easeFactor: 3.0,
          intervalMinutes: 1440,
          phase: CardPhase.review,
          successCount: 10,
          streak: 5,
          longestStreak: 7,
        );

        expect(modified.id, 'modified');
        expect(modified.repetitions, 5);
        expect(modified.easeFactor, 3.0);
        expect(modified.intervalMinutes, 1440);
        expect(modified.phase, CardPhase.review);
        expect(modified.successCount, 10);
        expect(modified.streak, 5);
        expect(modified.longestStreak, 7);
      });
    });

    group('serialization', () {
      test('toJson and fromJson roundtrip', () {
        final original = ReviewCard.newCard(
          id: 'test_card',
          metadata: {'deck': 'test'},
        ).copyWith(
          repetitions: 3,
          easeFactor: 2.7,
          intervalMinutes: 1440,
          phase: CardPhase.review,
          successCount: 5,
          failureCount: 1,
          streak: 4,
          longestStreak: 6,
        );

        final json = original.toJson();
        final restored = ReviewCard.fromJson(json);

        expect(restored.id, original.id);
        expect(restored.repetitions, original.repetitions);
        expect(restored.easeFactor, original.easeFactor);
        expect(restored.intervalMinutes, original.intervalMinutes);
        expect(restored.phase, original.phase);
        expect(restored.successCount, original.successCount);
        expect(restored.failureCount, original.failureCount);
        expect(restored.streak, original.streak);
        expect(restored.longestStreak, original.longestStreak);
        expect(restored.metadata?['deck'], 'test');
      });

      test('fromJson handles missing optional fields', () {
        final json = {
          'id': 'minimal',
          'nextReviewTime': DateTime.now().toIso8601String(),
          'createdAt': DateTime.now().toIso8601String(),
        };

        final card = ReviewCard.fromJson(json);
        expect(card.id, 'minimal');
        expect(card.repetitions, 0);
        expect(card.easeFactor, 2.5);
        expect(card.phase, CardPhase.isNew);
      });
    });

    group('equality', () {
      test('equal cards are equal', () {
        final time = DateTime.now();
        final card1 = ReviewCard(
          id: 'test',
          nextReviewTime: time,
          createdAt: time,
          easeFactor: 2.5,
          intervalMinutes: 100,
        );
        final card2 = ReviewCard(
          id: 'test',
          nextReviewTime: time,
          createdAt: time,
          easeFactor: 2.5,
          intervalMinutes: 100,
        );

        expect(card1, equals(card2));
        expect(card1.hashCode, equals(card2.hashCode));
      });

      test('different cards are not equal', () {
        final time = DateTime.now();
        final card1 = ReviewCard(
          id: 'test1',
          nextReviewTime: time,
          createdAt: time,
        );
        final card2 = ReviewCard(
          id: 'test2',
          nextReviewTime: time,
          createdAt: time,
        );

        expect(card1, isNot(equals(card2)));
      });
    });
  });
}
