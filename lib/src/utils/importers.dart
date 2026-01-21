import 'dart:convert';

import '../models/review_card.dart';
import '../models/srs_settings.dart';

/// Result of an import operation.
class ImportResult {
  /// Creates an import result.
  const ImportResult({
    required this.cards,
    required this.settings,
    this.deckName,
    this.deckDescription,
    this.errors = const [],
    this.warnings = const [],
  });

  /// The imported cards.
  final List<ReviewCard> cards;

  /// The imported settings (if any).
  final SRSSettings? settings;

  /// The deck name (if specified).
  final String? deckName;

  /// The deck description (if specified).
  final String? deckDescription;

  /// Any errors that occurred during import.
  final List<String> errors;

  /// Any warnings during import.
  final List<String> warnings;

  /// Whether the import was successful.
  bool get isSuccess => errors.isEmpty;

  /// Number of cards imported.
  int get cardCount => cards.length;
}

/// CSV column mapping configuration.
class CSVMapping {
  /// Creates a CSV mapping configuration.
  const CSVMapping({
    this.idColumn,
    this.frontColumn = 0,
    this.backColumn = 1,
    this.tagsColumn,
    this.deckColumn,
    this.hasHeader = true,
    this.delimiter = ',',
  });

  /// Column index for card ID (auto-generated if null).
  final int? idColumn;

  /// Column index for front content.
  final int frontColumn;

  /// Column index for back content.
  final int backColumn;

  /// Column index for tags (comma-separated).
  final int? tagsColumn;

  /// Column index for deck name.
  final int? deckColumn;

  /// Whether the CSV has a header row.
  final bool hasHeader;

  /// The delimiter character.
  final String delimiter;
}

/// Imports cards from various formats.
class SRSImporter {
  /// Imports cards from CSV data.
  ///
  /// Example:
  /// ```dart
  /// final result = SRSImporter.fromCSV(
  ///   csvContent,
  ///   mapping: CSVMapping(frontColumn: 0, backColumn: 1),
  /// );
  /// ```
  static ImportResult fromCSV(
    String csvContent, {
    CSVMapping mapping = const CSVMapping(),
  }) {
    final cards = <ReviewCard>[];
    final errors = <String>[];
    final warnings = <String>[];

    try {
      final lines = const LineSplitter().convert(csvContent);
      if (lines.isEmpty) {
        return ImportResult(
          cards: [],
          settings: null,
          errors: ['CSV is empty'],
        );
      }

      final startRow = mapping.hasHeader ? 1 : 0;

      for (var i = startRow; i < lines.length; i++) {
        try {
          final columns = _parseCSVLine(lines[i], mapping.delimiter);

          if (columns.length <= mapping.frontColumn ||
              columns.length <= mapping.backColumn) {
            warnings.add('Line $i: Not enough columns');
            continue;
          }

          final front = columns[mapping.frontColumn].trim();
          final back = columns[mapping.backColumn].trim();

          if (front.isEmpty) {
            warnings.add('Line $i: Empty front content');
            continue;
          }

          final id = mapping.idColumn != null && columns.length > mapping.idColumn!
              ? columns[mapping.idColumn!]
              : 'csv_${i}_${DateTime.now().millisecondsSinceEpoch}';

          final tags = mapping.tagsColumn != null &&
                  columns.length > mapping.tagsColumn!
              ? columns[mapping.tagsColumn!].split(',').map((t) => t.trim()).toList()
              : <String>[];

          final deck = mapping.deckColumn != null &&
                  columns.length > mapping.deckColumn!
              ? columns[mapping.deckColumn!].trim()
              : null;

          cards.add(ReviewCard.newCard(
            id: id,
            metadata: {
              'front': front,
              'back': back,
              if (tags.isNotEmpty) 'tags': tags,
              if (deck != null) 'deck': deck,
            },
          ));
        } catch (e) {
          errors.add('Line $i: ${e.toString()}');
        }
      }
    } catch (e) {
      errors.add('Failed to parse CSV: ${e.toString()}');
    }

    return ImportResult(
      cards: cards,
      settings: null,
      warnings: warnings,
      errors: errors,
    );
  }

  /// Imports from JSON export format.
  static ImportResult fromJSON(String jsonContent) {
    final errors = <String>[];

    try {
      final data = jsonDecode(jsonContent) as Map<String, dynamic>;

      final cards = <ReviewCard>[];
      if (data.containsKey('cards')) {
        final cardsJson = data['cards'] as List;
        for (var i = 0; i < cardsJson.length; i++) {
          try {
            cards.add(ReviewCard.fromJson(cardsJson[i] as Map<String, dynamic>));
          } catch (e) {
            errors.add('Card $i: ${e.toString()}');
          }
        }
      }

      SRSSettings? settings;
      if (data.containsKey('settings')) {
        try {
          settings = SRSSettings.fromJson(data['settings'] as Map<String, dynamic>);
        } catch (e) {
          errors.add('Settings: ${e.toString()}');
        }
      }

      return ImportResult(
        cards: cards,
        settings: settings,
        deckName: data['deckName'] as String?,
        deckDescription: data['deckDescription'] as String?,
        errors: errors,
      );
    } catch (e) {
      return ImportResult(
        cards: [],
        settings: null,
        errors: ['Failed to parse JSON: ${e.toString()}'],
      );
    }
  }

  /// Imports from Anki-compatible text format.
  ///
  /// Supports tab-separated front/back format.
  static ImportResult fromAnkiText(String content) {
    final cards = <ReviewCard>[];
    final warnings = <String>[];

    final lines = const LineSplitter().convert(content);

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty || line.startsWith('#')) continue;

      final parts = line.split('\t');
      if (parts.length < 2) {
        warnings.add('Line $i: Expected tab-separated front/back');
        continue;
      }

      final front = parts[0].trim();
      final back = parts[1].trim();
      final tags = parts.length > 2 ? parts[2].split(' ') : <String>[];

      cards.add(ReviewCard.newCard(
        id: 'anki_${i}_${DateTime.now().millisecondsSinceEpoch}',
        metadata: {
          'front': front,
          'back': back,
          if (tags.isNotEmpty) 'tags': tags,
        },
      ));
    }

    return ImportResult(
      cards: cards,
      settings: null,
      warnings: warnings,
    );
  }

  /// Parses a CSV line handling quoted values.
  static List<String> _parseCSVLine(String line, String delimiter) {
    final result = <String>[];
    var current = StringBuffer();
    var inQuotes = false;

    for (var i = 0; i < line.length; i++) {
      final char = line[i];

      if (char == '"') {
        if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
          current.write('"');
          i++;
        } else {
          inQuotes = !inQuotes;
        }
      } else if (char == delimiter && !inQuotes) {
        result.add(current.toString());
        current = StringBuffer();
      } else {
        current.write(char);
      }
    }

    result.add(current.toString());
    return result;
  }
}

/// Exports cards to various formats.
class SRSExporter {
  /// Exports to CSV format.
  static String toCSV(
    List<ReviewCard> cards, {
    bool includeHeader = true,
    String delimiter = ',',
  }) {
    final buffer = StringBuffer();

    if (includeHeader) {
      buffer.writeln('id${delimiter}front${delimiter}back${delimiter}tags');
    }

    for (final card in cards) {
      final front = _escapeCSV(card.metadata?['front']?.toString() ?? '', delimiter);
      final back = _escapeCSV(card.metadata?['back']?.toString() ?? '', delimiter);
      final tags = (card.metadata?['tags'] as List?)?.join(',') ?? '';

      buffer.writeln('${card.id}$delimiter$front$delimiter$back$delimiter$tags');
    }

    return buffer.toString();
  }

  /// Exports to JSON format.
  static String toJSON(
    List<ReviewCard> cards, {
    SRSSettings? settings,
    String? deckName,
    String? deckDescription,
    bool pretty = true,
  }) {
    final data = <String, dynamic>{
      if (deckName != null) 'deckName': deckName,
      if (deckDescription != null) 'deckDescription': deckDescription,
      'exportedAt': DateTime.now().toIso8601String(),
      'version': '1.0.0',
      'cardCount': cards.length,
      'cards': cards.map((c) => c.toJson()).toList(),
      if (settings != null) 'settings': settings.toJson(),
    };

    if (pretty) {
      return const JsonEncoder.withIndent('  ').convert(data);
    }
    return jsonEncode(data);
  }

  /// Exports to Anki-compatible text format.
  static String toAnkiText(List<ReviewCard> cards) {
    final buffer = StringBuffer();

    for (final card in cards) {
      final front = card.metadata?['front']?.toString() ?? '';
      final back = card.metadata?['back']?.toString() ?? '';
      final tags = (card.metadata?['tags'] as List?)?.join(' ') ?? '';

      buffer.write(front.replaceAll('\t', ' ').replaceAll('\n', '<br>'));
      buffer.write('\t');
      buffer.write(back.replaceAll('\t', ' ').replaceAll('\n', '<br>'));
      if (tags.isNotEmpty) {
        buffer.write('\t');
        buffer.write(tags);
      }
      buffer.writeln();
    }

    return buffer.toString();
  }

  static String _escapeCSV(String value, String delimiter) {
    if (value.contains(delimiter) ||
        value.contains('"') ||
        value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }
}

/// Algorithm migration utilities.
class AlgorithmMigration {
  /// Migrates cards from SM-2 to FSRS.
  ///
  /// Converts ease factor and interval to FSRS stability and difficulty.
  static List<ReviewCard> sm2ToFSRS(List<ReviewCard> cards) {
    return cards.map((card) {
      // Convert ease factor to difficulty (inverse relationship)
      // Ease 1.3 -> Difficulty 10, Ease 2.5 -> Difficulty 5
      final difficulty = (10 - (card.easeFactor - 1.3) * 5).clamp(1.0, 10.0);

      // Stability is approximately the interval in days
      final stability = card.intervalMinutes / 1440;

      final metadata = Map<String, dynamic>.from(card.metadata ?? {});
      metadata['fsrs'] = {
        'stability': stability,
        'difficulty': difficulty,
        'lastReview': card.lastReviewedAt?.toIso8601String(),
        'reps': card.repetitions,
        'lapses': card.lapseCount,
        'state': card.phase.index,
      };
      metadata['migratedFrom'] = 'SM-2';
      metadata['migratedAt'] = DateTime.now().toIso8601String();

      return card.copyWith(metadata: metadata);
    }).toList();
  }

  /// Migrates cards from FSRS to SM-2.
  ///
  /// Converts stability and difficulty back to ease factor.
  static List<ReviewCard> fsrsToSM2(List<ReviewCard> cards) {
    return cards.map((card) {
      double easeFactor = card.easeFactor;

      if (card.metadata != null && card.metadata!.containsKey('fsrs')) {
        final fsrs = card.metadata!['fsrs'] as Map<String, dynamic>;
        final difficulty = (fsrs['difficulty'] as num?)?.toDouble() ?? 5.0;
        // Convert difficulty back to ease factor
        easeFactor = (1.3 + (10 - difficulty) / 5 * 1.2).clamp(1.3, 3.0);
      }

      final metadata = Map<String, dynamic>.from(card.metadata ?? {});
      metadata.remove('fsrs');
      metadata['migratedFrom'] = 'FSRS';
      metadata['migratedAt'] = DateTime.now().toIso8601String();

      return card.copyWith(
        easeFactor: easeFactor,
        metadata: metadata,
      );
    }).toList();
  }
}
