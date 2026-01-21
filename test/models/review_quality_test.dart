import 'package:flutter_spaced_repetition/flutter_spaced_repetition.dart';
import 'package:test/test.dart';

void main() {
  group('ReviewQuality', () {
    test('enum values have correct properties', () {
      expect(ReviewQuality.again.value, 1);
      expect(ReviewQuality.again.label, 'Again');
      expect(ReviewQuality.again.isLapse, true);
      expect(ReviewQuality.again.isSuccess, false);

      expect(ReviewQuality.hard.value, 2);
      expect(ReviewQuality.hard.label, 'Hard');
      expect(ReviewQuality.hard.isLapse, false);
      expect(ReviewQuality.hard.isSuccess, true);

      expect(ReviewQuality.good.value, 3);
      expect(ReviewQuality.good.label, 'Good');
      expect(ReviewQuality.good.isLapse, false);
      expect(ReviewQuality.good.isSuccess, true);

      expect(ReviewQuality.easy.value, 4);
      expect(ReviewQuality.easy.label, 'Easy');
      expect(ReviewQuality.easy.isLapse, false);
      expect(ReviewQuality.easy.isSuccess, true);
      expect(ReviewQuality.easy.isPerfect, true);
    });

    group('fromValue', () {
      test('creates quality from valid values', () {
        expect(ReviewQuality.fromValue(1), ReviewQuality.again);
        expect(ReviewQuality.fromValue(2), ReviewQuality.hard);
        expect(ReviewQuality.fromValue(3), ReviewQuality.good);
        expect(ReviewQuality.fromValue(4), ReviewQuality.easy);
      });

      test('throws on invalid value', () {
        expect(() => ReviewQuality.fromValue(0), throwsArgumentError);
        expect(() => ReviewQuality.fromValue(5), throwsArgumentError);
        expect(() => ReviewQuality.fromValue(-1), throwsArgumentError);
      });
    });

    group('tryFromValue', () {
      test('returns quality for valid values', () {
        expect(ReviewQuality.tryFromValue(1), ReviewQuality.again);
        expect(ReviewQuality.tryFromValue(4), ReviewQuality.easy);
      });

      test('returns null for invalid values', () {
        expect(ReviewQuality.tryFromValue(0), isNull);
        expect(ReviewQuality.tryFromValue(5), isNull);
      });
    });

    group('fromLabel', () {
      test('creates quality from valid labels', () {
        expect(ReviewQuality.fromLabel('Again'), ReviewQuality.again);
        expect(ReviewQuality.fromLabel('Hard'), ReviewQuality.hard);
        expect(ReviewQuality.fromLabel('Good'), ReviewQuality.good);
        expect(ReviewQuality.fromLabel('Easy'), ReviewQuality.easy);
      });

      test('is case insensitive', () {
        expect(ReviewQuality.fromLabel('again'), ReviewQuality.again);
        expect(ReviewQuality.fromLabel('GOOD'), ReviewQuality.good);
        expect(ReviewQuality.fromLabel('eAsY'), ReviewQuality.easy);
      });

      test('throws on invalid label', () {
        expect(() => ReviewQuality.fromLabel('unknown'), throwsArgumentError);
        expect(() => ReviewQuality.fromLabel(''), throwsArgumentError);
      });
    });

    group('tryFromLabel', () {
      test('returns quality for valid labels', () {
        expect(ReviewQuality.tryFromLabel('Again'), ReviewQuality.again);
        expect(ReviewQuality.tryFromLabel('easy'), ReviewQuality.easy);
      });

      test('returns null for invalid labels', () {
        expect(ReviewQuality.tryFromLabel('invalid'), isNull);
        expect(ReviewQuality.tryFromLabel(''), isNull);
      });
    });

    group('serialization', () {
      test('toJson produces valid map', () {
        final json = ReviewQuality.good.toJson();
        expect(json['value'], 3);
        expect(json['label'], 'Good');
      });

      test('fromJson with value', () {
        final json = {'value': 2};
        expect(ReviewQuality.fromJson(json), ReviewQuality.hard);
      });

      test('fromJson with label', () {
        final json = {'label': 'Easy'};
        expect(ReviewQuality.fromJson(json), ReviewQuality.easy);
      });

      test('fromJson throws without value or label', () {
        expect(() => ReviewQuality.fromJson({}), throwsArgumentError);
      });
    });
  });
}
