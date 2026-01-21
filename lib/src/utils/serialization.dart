import 'dart:convert';

import '../models/interval_preview.dart';
import '../models/review_card.dart';
import '../models/review_result.dart';
import '../models/srs_settings.dart';

/// Utility class for serializing and deserializing SRS models.
///
/// Provides methods for converting models to/from JSON strings and maps.
class SRSSerializer {
  /// Creates a serializer instance.
  const SRSSerializer();

  // ============================================================
  // REVIEW CARD
  // ============================================================

  /// Converts a ReviewCard to a JSON string.
  String cardToJson(ReviewCard card, {bool pretty = false}) {
    final encoder =
        pretty ? const JsonEncoder.withIndent('  ') : const JsonEncoder();
    return encoder.convert(card.toJson());
  }

  /// Creates a ReviewCard from a JSON string.
  ReviewCard cardFromJson(String json) {
    final map = jsonDecode(json) as Map<String, dynamic>;
    return ReviewCard.fromJson(map);
  }

  /// Converts a list of ReviewCards to a JSON string.
  String cardsToJson(List<ReviewCard> cards, {bool pretty = false}) {
    final encoder =
        pretty ? const JsonEncoder.withIndent('  ') : const JsonEncoder();
    return encoder.convert(cards.map((c) => c.toJson()).toList());
  }

  /// Creates a list of ReviewCards from a JSON string.
  List<ReviewCard> cardsFromJson(String json) {
    final list = jsonDecode(json) as List<dynamic>;
    return list
        .map((item) => ReviewCard.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  // ============================================================
  // SRS SETTINGS
  // ============================================================

  /// Converts SRSSettings to a JSON string.
  String settingsToJson(SRSSettings settings, {bool pretty = false}) {
    final encoder =
        pretty ? const JsonEncoder.withIndent('  ') : const JsonEncoder();
    return encoder.convert(settings.toJson());
  }

  /// Creates SRSSettings from a JSON string.
  SRSSettings settingsFromJson(String json) {
    final map = jsonDecode(json) as Map<String, dynamic>;
    return SRSSettings.fromJson(map);
  }

  // ============================================================
  // REVIEW RESULT
  // ============================================================

  /// Converts a ReviewResult to a JSON string.
  String resultToJson(ReviewResult result, {bool pretty = false}) {
    final encoder =
        pretty ? const JsonEncoder.withIndent('  ') : const JsonEncoder();
    return encoder.convert(result.toJson());
  }

  /// Creates a ReviewResult from a JSON string.
  ReviewResult resultFromJson(String json) {
    final map = jsonDecode(json) as Map<String, dynamic>;
    return ReviewResult.fromJson(map);
  }

  /// Converts a list of ReviewResults to a JSON string.
  String resultsToJson(List<ReviewResult> results, {bool pretty = false}) {
    final encoder =
        pretty ? const JsonEncoder.withIndent('  ') : const JsonEncoder();
    return encoder.convert(results.map((r) => r.toJson()).toList());
  }

  /// Creates a list of ReviewResults from a JSON string.
  List<ReviewResult> resultsFromJson(String json) {
    final list = jsonDecode(json) as List<dynamic>;
    return list
        .map((item) => ReviewResult.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  // ============================================================
  // INTERVAL PREVIEW
  // ============================================================

  /// Converts an IntervalPreview to a JSON string.
  String previewToJson(IntervalPreview preview, {bool pretty = false}) {
    final encoder =
        pretty ? const JsonEncoder.withIndent('  ') : const JsonEncoder();
    return encoder.convert(preview.toJson());
  }

  /// Creates an IntervalPreview from a JSON string.
  IntervalPreview previewFromJson(String json) {
    final map = jsonDecode(json) as Map<String, dynamic>;
    return IntervalPreview.fromJson(map);
  }

  // ============================================================
  // EXPORT/IMPORT
  // ============================================================

  /// Exports a complete deck (cards + settings) to JSON.
  String exportDeck({
    required List<ReviewCard> cards,
    required SRSSettings settings,
    Map<String, dynamic>? deckMetadata,
    bool pretty = false,
  }) {
    final encoder =
        pretty ? const JsonEncoder.withIndent('  ') : const JsonEncoder();

    final export = {
      'version': '1.0.0',
      'exportedAt': DateTime.now().toIso8601String(),
      'settings': settings.toJson(),
      'cards': cards.map((c) => c.toJson()).toList(),
      if (deckMetadata != null) 'metadata': deckMetadata,
    };

    return encoder.convert(export);
  }

  /// Imports a complete deck from JSON.
  DeckImport importDeck(String json) {
    final map = jsonDecode(json) as Map<String, dynamic>;

    final version = map['version'] as String?;
    final exportedAt = map['exportedAt'] != null
        ? DateTime.parse(map['exportedAt'] as String)
        : null;
    final settings = map['settings'] != null
        ? SRSSettings.fromJson(map['settings'] as Map<String, dynamic>)
        : const SRSSettings();
    final cards = (map['cards'] as List<dynamic>?)
            ?.map((item) => ReviewCard.fromJson(item as Map<String, dynamic>))
            .toList() ??
        [];
    final metadata = map['metadata'] as Map<String, dynamic>?;

    return DeckImport(
      version: version,
      exportedAt: exportedAt,
      settings: settings,
      cards: cards,
      metadata: metadata,
    );
  }
}

/// Result of importing a deck.
class DeckImport {
  /// Version of the export format.
  final String? version;

  /// When the deck was exported.
  final DateTime? exportedAt;

  /// Imported settings.
  final SRSSettings settings;

  /// Imported cards.
  final List<ReviewCard> cards;

  /// Additional deck metadata.
  final Map<String, dynamic>? metadata;

  const DeckImport({
    this.version,
    this.exportedAt,
    required this.settings,
    required this.cards,
    this.metadata,
  });

  @override
  String toString() => 'DeckImport('
      'version: $version, '
      'cards: ${cards.length}, '
      'exportedAt: $exportedAt)';
}

/// Default serializer instance for convenience.
const srsSerializer = SRSSerializer();

/// Extension for easy serialization on ReviewCard.
extension ReviewCardSerialization on ReviewCard {
  /// Converts this card to a JSON string.
  String toJsonString({bool pretty = false}) {
    return srsSerializer.cardToJson(this, pretty: pretty);
  }
}

/// Extension for easy serialization on lists of ReviewCards.
extension ReviewCardListSerialization on List<ReviewCard> {
  /// Converts this list of cards to a JSON string.
  String toJsonString({bool pretty = false}) {
    return srsSerializer.cardsToJson(this, pretty: pretty);
  }
}

/// Extension for easy serialization on SRSSettings.
extension SRSSettingsSerialization on SRSSettings {
  /// Converts these settings to a JSON string.
  String toJsonString({bool pretty = false}) {
    return srsSerializer.settingsToJson(this, pretty: pretty);
  }
}

/// Extension for easy serialization on ReviewResult.
extension ReviewResultSerialization on ReviewResult {
  /// Converts this result to a JSON string.
  String toJsonString({bool pretty = false}) {
    return srsSerializer.resultToJson(this, pretty: pretty);
  }
}
