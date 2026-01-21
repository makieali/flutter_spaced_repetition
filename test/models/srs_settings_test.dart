import 'package:flutter_spaced_repetition/flutter_spaced_repetition.dart';
import 'package:test/test.dart';

void main() {
  group('SRSSettings', () {
    group('default constructor', () {
      test('has sensible defaults', () {
        const settings = SRSSettings();

        expect(settings.learningSteps.length, 2);
        expect(settings.learningSteps[0], const Duration(minutes: 1));
        expect(settings.learningSteps[1], const Duration(minutes: 10));
        expect(settings.graduationsRequired, 2);
        expect(settings.initialEaseFactor, 2.5);
        expect(settings.minimumEaseFactor, 1.3);
        expect(settings.graduatingInterval, const Duration(days: 1));
        expect(settings.easyInterval, const Duration(days: 4));
        expect(settings.minimumInterval, const Duration(days: 1));
        expect(settings.maximumInterval, const Duration(days: 365));
        expect(settings.algorithmType, SRSAlgorithmType.sm2);
      });
    });

    group('presets', () {
      test('anki preset has expected values', () {
        final settings = SRSSettings.anki();

        expect(settings.learningSteps.length, 2);
        expect(settings.initialEaseFactor, 2.5);
        expect(settings.minimumEaseFactor, 1.3);
        expect(settings.easyBonus, 1.3);
        expect(settings.intervalFuzz, 0.05);
      });

      test('supermemo preset differs from default', () {
        final settings = SRSSettings.supermemo();

        expect(settings.easyBonus, 1.5);
        expect(settings.intervalFuzz, 0.0);
      });

      test('aggressive preset has shorter intervals', () {
        final settings = SRSSettings.aggressive();

        expect(settings.learningSteps.length, 3);
        expect(settings.graduatingInterval, const Duration(hours: 12));
        expect(settings.maximumInterval, const Duration(days: 180));
        expect(settings.graduationsRequired, 3);
      });

      test('relaxed preset has longer intervals', () {
        final settings = SRSSettings.relaxed();

        expect(settings.graduatingInterval, const Duration(days: 2));
        expect(settings.easyInterval, const Duration(days: 7));
        expect(settings.maximumInterval, const Duration(days: 730));
        expect(settings.lapseMultiplier, 0.25);
      });
    });

    group('validate', () {
      test('default settings are valid', () {
        const settings = SRSSettings();
        expect(() => settings.validate(), returnsNormally);
      });

      test('presets are valid', () {
        expect(() => SRSSettings.anki().validate(), returnsNormally);
        expect(() => SRSSettings.supermemo().validate(), returnsNormally);
        expect(() => SRSSettings.aggressive().validate(), returnsNormally);
        expect(() => SRSSettings.relaxed().validate(), returnsNormally);
      });

      test('throws on empty learning steps', () {
        const settings = SRSSettings(learningSteps: []);
        expect(() => settings.validate(), throwsArgumentError);
      });

      test('throws on invalid graduations required', () {
        const settings = SRSSettings(graduationsRequired: 0);
        expect(() => settings.validate(), throwsArgumentError);
      });

      test('throws on negative lapses before leech', () {
        const settings = SRSSettings(lapsesBeforeLeech: -1);
        expect(() => settings.validate(), throwsArgumentError);
      });

      test('throws on invalid interval bounds', () {
        const settings = SRSSettings(
          minimumInterval: Duration(days: 10),
          maximumInterval: Duration(days: 5),
        );
        expect(() => settings.validate(), throwsArgumentError);
      });

      test('throws on initial ease below minimum', () {
        const settings = SRSSettings(
          initialEaseFactor: 1.2,
          minimumEaseFactor: 1.3,
        );
        expect(() => settings.validate(), throwsArgumentError);
      });

      test('throws on minimum ease below 1.0', () {
        const settings = SRSSettings(minimumEaseFactor: 0.9);
        expect(() => settings.validate(), throwsArgumentError);
      });

      test('throws on easy bonus below 1.0', () {
        const settings = SRSSettings(easyBonus: 0.5);
        expect(() => settings.validate(), throwsArgumentError);
      });

      test('throws on invalid lapse multiplier', () {
        const settings = SRSSettings(lapseMultiplier: 1.5);
        expect(() => settings.validate(), throwsArgumentError);
      });

      test('throws on invalid interval fuzz', () {
        const settings = SRSSettings(intervalFuzz: 1.5);
        expect(() => settings.validate(), throwsArgumentError);
      });
    });

    group('copyWith', () {
      test('creates copy with modified values', () {
        const original = SRSSettings();
        final modified = original.copyWith(
          initialEaseFactor: 2.8,
          maximumInterval: const Duration(days: 730),
        );

        expect(modified.initialEaseFactor, 2.8);
        expect(modified.maximumInterval, const Duration(days: 730));
        expect(modified.minimumEaseFactor, original.minimumEaseFactor);
        expect(modified.learningSteps, original.learningSteps);
      });

      test('preserves algorithm type when not changed', () {
        final original = SRSSettings.anki().copyWith(
          algorithmType: SRSAlgorithmType.sm2Plus,
        );
        final copy = original.copyWith(initialEaseFactor: 2.6);

        expect(copy.algorithmType, SRSAlgorithmType.sm2Plus);
      });
    });

    group('serialization', () {
      test('toJson and fromJson roundtrip', () {
        const original = SRSSettings(
          learningSteps: [
            Duration(minutes: 1),
            Duration(minutes: 5),
            Duration(minutes: 10),
          ],
          graduationsRequired: 3,
          initialEaseFactor: 2.6,
          algorithmType: SRSAlgorithmType.sm2Plus,
        );

        final json = original.toJson();
        final restored = SRSSettings.fromJson(json);

        expect(restored.learningSteps.length, 3);
        expect(restored.graduationsRequired, 3);
        expect(restored.initialEaseFactor, 2.6);
        expect(restored.algorithmType, SRSAlgorithmType.sm2Plus);
      });

      test('fromJson handles missing fields with defaults', () {
        final json = <String, dynamic>{};
        final settings = SRSSettings.fromJson(json);

        expect(settings.learningSteps.length, 2);
        expect(settings.initialEaseFactor, 2.5);
        expect(settings.algorithmType, SRSAlgorithmType.sm2);
      });
    });

    group('equality', () {
      test('equal settings are equal', () {
        const settings1 = SRSSettings();
        const settings2 = SRSSettings();

        expect(settings1, equals(settings2));
        expect(settings1.hashCode, equals(settings2.hashCode));
      });

      test('different settings are not equal', () {
        const settings1 = SRSSettings(initialEaseFactor: 2.5);
        const settings2 = SRSSettings(initialEaseFactor: 2.6);

        expect(settings1, isNot(equals(settings2)));
      });
    });
  });
}
