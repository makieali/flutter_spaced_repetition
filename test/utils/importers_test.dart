import 'dart:convert';

import 'package:flutter_spaced_repetition/flutter_spaced_repetition.dart';
import 'package:test/test.dart';

void main() {
  group('SRSImporter', () {
    group('fromCSV', () {
      test('imports basic CSV with header', () {
        const csv = '''front,back
Hello,Hola
World,Mundo
Test,Prueba''';

        final result = SRSImporter.fromCSV(csv);

        expect(result.isSuccess, isTrue);
        expect(result.cardCount, equals(3));
        expect(result.cards[0].metadata?['front'], equals('Hello'));
        expect(result.cards[0].metadata?['back'], equals('Hola'));
      });

      test('imports CSV without header', () {
        const csv = '''Hello,Hola
World,Mundo''';

        final result = SRSImporter.fromCSV(
          csv,
          mapping: const CSVMapping(hasHeader: false),
        );

        expect(result.isSuccess, isTrue);
        expect(result.cardCount, equals(2));
      });

      test('handles custom delimiter', () {
        const csv = '''front;back
Hello;Hola
World;Mundo''';

        final result = SRSImporter.fromCSV(
          csv,
          mapping: const CSVMapping(delimiter: ';'),
        );

        expect(result.isSuccess, isTrue);
        expect(result.cardCount, equals(2));
      });

      test('handles quoted values with commas', () {
        const csv = '''front,back
"Hello, friend",Hola amigo
World,Mundo''';

        final result = SRSImporter.fromCSV(csv);

        expect(result.isSuccess, isTrue);
        expect(result.cards[0].metadata?['front'], equals('Hello, friend'));
      });

      test('handles empty CSV', () {
        const csv = '';

        final result = SRSImporter.fromCSV(csv);

        expect(result.isSuccess, isFalse);
        expect(result.errors, contains('CSV is empty'));
      });

      test('warns about rows with not enough columns', () {
        const csv = '''front,back
Hello,Hola
Incomplete''';

        final result = SRSImporter.fromCSV(csv);

        expect(result.cardCount, equals(1));
        expect(result.warnings, isNotEmpty);
      });

      test('imports tags column', () {
        const csv = '''front,back,tags
Hello,Hola,spanish,greeting
World,Mundo,spanish''';

        final result = SRSImporter.fromCSV(
          csv,
          mapping: const CSVMapping(tagsColumn: 2),
        );

        expect(result.isSuccess, isTrue);
        expect(result.cards[0].metadata?['tags'], contains('spanish'));
      });

      test('imports custom ID column', () {
        const csv = '''id,front,back
card_1,Hello,Hola
card_2,World,Mundo''';

        final result = SRSImporter.fromCSV(
          csv,
          mapping: const CSVMapping(idColumn: 0, frontColumn: 1, backColumn: 2),
        );

        expect(result.isSuccess, isTrue);
        expect(result.cards[0].id, equals('card_1'));
      });
    });

    group('fromJSON', () {
      test('imports JSON export format', () {
        final json = jsonEncode({
          'deckName': 'Spanish Basics',
          'cards': [
            {
              'id': 'card_1',
              'repetitions': 3,
              'easeFactor': 2.5,
              'intervalMinutes': 1440,
              'nextReviewTime': DateTime.now().toIso8601String(),
              'phase': 'review',
              'createdAt': DateTime.now().toIso8601String(),
            },
          ],
        });

        final result = SRSImporter.fromJSON(json);

        expect(result.isSuccess, isTrue);
        expect(result.cardCount, equals(1));
        expect(result.deckName, equals('Spanish Basics'));
      });

      test('imports settings from JSON', () {
        final json = jsonEncode({
          'cards': [],
          'settings': {
            'algorithmType': 'fsrs',
            'initialEaseFactor': 2.5,
            'minimumEaseFactor': 1.3,
          },
        });

        final result = SRSImporter.fromJSON(json);

        expect(result.isSuccess, isTrue);
        expect(result.settings, isNotNull);
        expect(result.settings?.algorithmType, equals(SRSAlgorithmType.fsrs));
      });

      test('handles invalid JSON', () {
        const json = 'not valid json';

        final result = SRSImporter.fromJSON(json);

        expect(result.isSuccess, isFalse);
        expect(result.errors, isNotEmpty);
      });

      test('handles missing cards array', () {
        final json = jsonEncode({'deckName': 'Empty'});

        final result = SRSImporter.fromJSON(json);

        expect(result.isSuccess, isTrue);
        expect(result.cardCount, equals(0));
      });
    });

    group('fromAnkiText', () {
      test('imports tab-separated format', () {
        const text = '''Hello\tHola
World\tMundo
Test\tPrueba''';

        final result = SRSImporter.fromAnkiText(text);

        expect(result.isSuccess, isTrue);
        expect(result.cardCount, equals(3));
        expect(result.cards[0].metadata?['front'], equals('Hello'));
        expect(result.cards[0].metadata?['back'], equals('Hola'));
      });

      test('imports tags from third column', () {
        const text = '''Hello\tHola\tspanish greeting
World\tMundo\tspanish''';

        final result = SRSImporter.fromAnkiText(text);

        expect(result.isSuccess, isTrue);
        expect(result.cards[0].metadata?['tags'], contains('spanish'));
      });

      test('skips comment lines', () {
        const text = '''# This is a comment
Hello\tHola
# Another comment
World\tMundo''';

        final result = SRSImporter.fromAnkiText(text);

        expect(result.cardCount, equals(2));
      });

      test('skips empty lines', () {
        const text = '''Hello\tHola

World\tMundo''';

        final result = SRSImporter.fromAnkiText(text);

        expect(result.cardCount, equals(2));
      });

      test('warns about invalid lines', () {
        const text = '''Hello\tHola
InvalidLine
World\tMundo''';

        final result = SRSImporter.fromAnkiText(text);

        expect(result.cardCount, equals(2));
        expect(result.warnings, isNotEmpty);
      });
    });
  });

  group('SRSExporter', () {
    group('toCSV', () {
      test('exports cards to CSV', () {
        final cards = [
          ReviewCard.newCard(
            id: 'card_1',
            metadata: {'front': 'Hello', 'back': 'Hola'},
          ),
          ReviewCard.newCard(
            id: 'card_2',
            metadata: {'front': 'World', 'back': 'Mundo'},
          ),
        ];

        final csv = SRSExporter.toCSV(cards);

        expect(csv, contains('id,front,back,tags'));
        expect(csv, contains('card_1,Hello,Hola'));
        expect(csv, contains('card_2,World,Mundo'));
      });

      test('exports without header', () {
        final cards = [
          ReviewCard.newCard(
            id: 'card_1',
            metadata: {'front': 'Hello', 'back': 'Hola'},
          ),
        ];

        final csv = SRSExporter.toCSV(cards, includeHeader: false);

        expect(csv, isNot(contains('id,front,back')));
        expect(csv, contains('card_1,Hello,Hola'));
      });

      test('handles custom delimiter', () {
        final cards = [
          ReviewCard.newCard(
            id: 'card_1',
            metadata: {'front': 'Hello', 'back': 'Hola'},
          ),
        ];

        final csv = SRSExporter.toCSV(cards, delimiter: ';');

        expect(csv, contains('id;front;back;tags'));
      });

      test('escapes values with delimiters', () {
        final cards = [
          ReviewCard.newCard(
            id: 'card_1',
            metadata: {'front': 'Hello, friend', 'back': 'Hola, amigo'},
          ),
        ];

        final csv = SRSExporter.toCSV(cards);

        expect(csv, contains('"Hello, friend"'));
      });

      test('exports tags', () {
        final cards = [
          ReviewCard.newCard(
            id: 'card_1',
            metadata: {
              'front': 'Hello',
              'back': 'Hola',
              'tags': ['spanish', 'greeting']
            },
          ),
        ];

        final csv = SRSExporter.toCSV(cards);

        expect(csv, contains('spanish,greeting'));
      });
    });

    group('toJSON', () {
      test('exports cards to JSON', () {
        final cards = [
          ReviewCard.newCard(id: 'card_1'),
          ReviewCard.newCard(id: 'card_2'),
        ];

        final json = SRSExporter.toJSON(cards);
        final parsed = jsonDecode(json) as Map<String, dynamic>;

        expect(parsed['cardCount'], equals(2));
        expect(parsed['cards'], isA<List>());
      });

      test('exports with settings', () {
        final cards = <ReviewCard>[];
        final settings = SRSSettings.anki();

        final json = SRSExporter.toJSON(cards, settings: settings);
        final parsed = jsonDecode(json) as Map<String, dynamic>;

        expect(parsed['settings'], isNotNull);
      });

      test('exports deck metadata', () {
        final cards = <ReviewCard>[];

        final json = SRSExporter.toJSON(
          cards,
          deckName: 'Spanish',
          deckDescription: 'Basic Spanish vocabulary',
        );
        final parsed = jsonDecode(json) as Map<String, dynamic>;

        expect(parsed['deckName'], equals('Spanish'));
        expect(parsed['deckDescription'], equals('Basic Spanish vocabulary'));
      });

      test('minified JSON when pretty is false', () {
        final cards = [ReviewCard.newCard(id: 'card_1')];

        final prettyJson = SRSExporter.toJSON(cards, pretty: true);
        final minJson = SRSExporter.toJSON(cards, pretty: false);

        expect(minJson.length, lessThan(prettyJson.length));
      });

      test('includes export timestamp', () {
        final cards = <ReviewCard>[];

        final json = SRSExporter.toJSON(cards);
        final parsed = jsonDecode(json) as Map<String, dynamic>;

        expect(parsed['exportedAt'], isNotNull);
      });
    });

    group('toAnkiText', () {
      test('exports to tab-separated format', () {
        final cards = [
          ReviewCard.newCard(
            id: 'card_1',
            metadata: {'front': 'Hello', 'back': 'Hola'},
          ),
          ReviewCard.newCard(
            id: 'card_2',
            metadata: {'front': 'World', 'back': 'Mundo'},
          ),
        ];

        final text = SRSExporter.toAnkiText(cards);

        expect(text, contains('Hello\tHola'));
        expect(text, contains('World\tMundo'));
      });

      test('exports tags in third column', () {
        final cards = [
          ReviewCard.newCard(
            id: 'card_1',
            metadata: {
              'front': 'Hello',
              'back': 'Hola',
              'tags': ['spanish', 'greeting']
            },
          ),
        ];

        final text = SRSExporter.toAnkiText(cards);

        expect(text, contains('spanish greeting'));
      });

      test('replaces newlines with <br>', () {
        final cards = [
          ReviewCard.newCard(
            id: 'card_1',
            metadata: {
              'front': 'Line 1\nLine 2',
              'back': 'Línea 1\nLínea 2',
            },
          ),
        ];

        final text = SRSExporter.toAnkiText(cards);

        expect(text, contains('Line 1<br>Line 2'));
        expect(text, isNot(contains('\n\t'))); // No literal newlines in content
      });

      test('replaces tabs with spaces', () {
        final cards = [
          ReviewCard.newCard(
            id: 'card_1',
            metadata: {
              'front': 'Tab\there',
              'back': 'Back',
            },
          ),
        ];

        final text = SRSExporter.toAnkiText(cards);

        expect(text, contains('Tab here'));
      });
    });
  });

  group('AlgorithmMigration', () {
    group('sm2ToFSRS', () {
      test('converts ease factor to difficulty', () {
        final cards = [
          ReviewCard(
            id: 'card_1',
            repetitions: 5,
            easeFactor: 2.5, // Standard ease
            intervalMinutes: 1440,
            nextReviewTime: DateTime.now(),
            phase: CardPhase.review,
            createdAt: DateTime.now(),
          ),
        ];

        final migrated = AlgorithmMigration.sm2ToFSRS(cards);

        expect(migrated.length, equals(1));
        expect(migrated[0].metadata?['fsrs'], isNotNull);

        final fsrs = migrated[0].metadata!['fsrs'] as Map<String, dynamic>;
        expect(fsrs['difficulty'], isA<double>());
        expect(fsrs['stability'], isA<double>());
      });

      test('adds migration metadata', () {
        final cards = [
          ReviewCard(
            id: 'card_1',
            repetitions: 3,
            easeFactor: 2.5,
            intervalMinutes: 1440,
            nextReviewTime: DateTime.now(),
            phase: CardPhase.review,
            createdAt: DateTime.now(),
          ),
        ];

        final migrated = AlgorithmMigration.sm2ToFSRS(cards);

        expect(migrated[0].metadata?['migratedFrom'], equals('SM-2'));
        expect(migrated[0].metadata?['migratedAt'], isNotNull);
      });

      test('higher ease results in lower difficulty', () {
        final highEaseCard = ReviewCard(
          id: 'high_ease',
          repetitions: 5,
          easeFactor: 3.0, // High ease = easy card
          intervalMinutes: 1440,
          nextReviewTime: DateTime.now(),
          phase: CardPhase.review,
          createdAt: DateTime.now(),
        );

        final lowEaseCard = ReviewCard(
          id: 'low_ease',
          repetitions: 5,
          easeFactor: 1.5, // Low ease = hard card
          intervalMinutes: 1440,
          nextReviewTime: DateTime.now(),
          phase: CardPhase.review,
          createdAt: DateTime.now(),
        );

        final migratedHigh = AlgorithmMigration.sm2ToFSRS([highEaseCard]).first;
        final migratedLow = AlgorithmMigration.sm2ToFSRS([lowEaseCard]).first;

        final highDifficulty =
            (migratedHigh.metadata!['fsrs'] as Map)['difficulty'] as double;
        final lowDifficulty =
            (migratedLow.metadata!['fsrs'] as Map)['difficulty'] as double;

        // Higher ease = lower difficulty
        expect(highDifficulty, lessThan(lowDifficulty));
      });

      test('converts interval to stability', () {
        final card = ReviewCard(
          id: 'card_1',
          repetitions: 5,
          easeFactor: 2.5,
          intervalMinutes: 1440 * 10, // 10 days
          nextReviewTime: DateTime.now(),
          phase: CardPhase.review,
          createdAt: DateTime.now(),
        );

        final migrated = AlgorithmMigration.sm2ToFSRS([card]).first;
        final stability =
            (migrated.metadata!['fsrs'] as Map)['stability'] as double;

        // Stability should be approximately 10 (days)
        expect(stability, closeTo(10, 0.1));
      });
    });

    group('fsrsToSM2', () {
      test('converts difficulty back to ease factor', () {
        final cards = [
          ReviewCard(
            id: 'card_1',
            repetitions: 5,
            easeFactor: 2.5,
            intervalMinutes: 1440,
            nextReviewTime: DateTime.now(),
            phase: CardPhase.review,
            createdAt: DateTime.now(),
            metadata: {
              'fsrs': {
                'stability': 10.0,
                'difficulty': 5.0, // Medium difficulty
              }
            },
          ),
        ];

        final migrated = AlgorithmMigration.fsrsToSM2(cards);

        expect(migrated.length, equals(1));
        // Ease factor should be reasonable
        expect(migrated[0].easeFactor, greaterThanOrEqualTo(1.3));
        expect(migrated[0].easeFactor, lessThanOrEqualTo(3.0));
      });

      test('removes FSRS metadata', () {
        final cards = [
          ReviewCard(
            id: 'card_1',
            repetitions: 5,
            easeFactor: 2.5,
            intervalMinutes: 1440,
            nextReviewTime: DateTime.now(),
            phase: CardPhase.review,
            createdAt: DateTime.now(),
            metadata: {
              'fsrs': {'stability': 10.0, 'difficulty': 5.0}
            },
          ),
        ];

        final migrated = AlgorithmMigration.fsrsToSM2(cards);

        expect(migrated[0].metadata?['fsrs'], isNull);
        expect(migrated[0].metadata?['migratedFrom'], equals('FSRS'));
      });

      test('low difficulty results in high ease factor', () {
        final lowDiffCard = ReviewCard(
          id: 'low_diff',
          repetitions: 5,
          easeFactor: 2.5,
          intervalMinutes: 1440,
          nextReviewTime: DateTime.now(),
          phase: CardPhase.review,
          createdAt: DateTime.now(),
          metadata: {
            'fsrs': {'stability': 10.0, 'difficulty': 2.0}
          },
        );

        final highDiffCard = ReviewCard(
          id: 'high_diff',
          repetitions: 5,
          easeFactor: 2.5,
          intervalMinutes: 1440,
          nextReviewTime: DateTime.now(),
          phase: CardPhase.review,
          createdAt: DateTime.now(),
          metadata: {
            'fsrs': {'stability': 10.0, 'difficulty': 9.0}
          },
        );

        final migratedLow = AlgorithmMigration.fsrsToSM2([lowDiffCard]).first;
        final migratedHigh = AlgorithmMigration.fsrsToSM2([highDiffCard]).first;

        // Lower difficulty = higher ease factor
        expect(migratedLow.easeFactor, greaterThan(migratedHigh.easeFactor));
      });
    });

    group('roundtrip', () {
      test('SM-2 to FSRS to SM-2 preserves approximate ease', () {
        final original = ReviewCard(
          id: 'card_1',
          repetitions: 5,
          easeFactor: 2.5,
          intervalMinutes: 1440,
          nextReviewTime: DateTime.now(),
          phase: CardPhase.review,
          createdAt: DateTime.now(),
        );

        final toFsrs = AlgorithmMigration.sm2ToFSRS([original]).first;
        final backToSm2 = AlgorithmMigration.fsrsToSM2([toFsrs]).first;

        // Ease factor should be similar (not exact due to conversion)
        expect(backToSm2.easeFactor, closeTo(original.easeFactor, 0.5));
      });
    });
  });

  group('ImportResult', () {
    test('isSuccess returns true when no errors', () {
      final result = ImportResult(
        cards: [ReviewCard.newCard(id: 'test')],
        settings: null,
      );

      expect(result.isSuccess, isTrue);
    });

    test('isSuccess returns false when errors exist', () {
      final result = ImportResult(
        cards: [],
        settings: null,
        errors: ['Some error'],
      );

      expect(result.isSuccess, isFalse);
    });

    test('cardCount returns correct count', () {
      final result = ImportResult(
        cards: [
          ReviewCard.newCard(id: 'card_1'),
          ReviewCard.newCard(id: 'card_2'),
        ],
        settings: null,
      );

      expect(result.cardCount, equals(2));
    });
  });

  group('CSVMapping', () {
    test('default values', () {
      const mapping = CSVMapping();

      expect(mapping.frontColumn, equals(0));
      expect(mapping.backColumn, equals(1));
      expect(mapping.hasHeader, isTrue);
      expect(mapping.delimiter, equals(','));
      expect(mapping.idColumn, isNull);
    });

    test('custom values', () {
      const mapping = CSVMapping(
        idColumn: 0,
        frontColumn: 1,
        backColumn: 2,
        tagsColumn: 3,
        hasHeader: false,
        delimiter: '\t',
      );

      expect(mapping.idColumn, equals(0));
      expect(mapping.frontColumn, equals(1));
      expect(mapping.backColumn, equals(2));
      expect(mapping.tagsColumn, equals(3));
      expect(mapping.hasHeader, isFalse);
      expect(mapping.delimiter, equals('\t'));
    });
  });
}
