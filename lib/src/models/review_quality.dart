/// Represents the quality of a review response in a spaced repetition system.
///
/// The quality rating determines how the algorithm adjusts the card's ease factor
/// and interval. Higher quality means better recall, leading to longer intervals.
enum ReviewQuality {
  /// Complete failure to recall. Card goes back to learning phase.
  /// Use when: The user had no idea and needed to see the answer.
  again(value: 1, label: 'Again', description: 'Complete blackout, wrong response'),

  /// Correct response with serious difficulty.
  /// Use when: The user recalled with significant hesitation or effort.
  hard(value: 2, label: 'Hard', description: 'Correct with serious difficulty'),

  /// Correct response with some hesitation.
  /// Use when: The user recalled correctly but had to think.
  good(value: 3, label: 'Good', description: 'Correct with some hesitation'),

  /// Perfect response with no hesitation.
  /// Use when: The user recalled instantly and effortlessly.
  easy(value: 4, label: 'Easy', description: 'Perfect, instant recall');

  /// Numeric value for the quality rating (1-4).
  final int value;

  /// Human-readable label for display.
  final String label;

  /// Detailed description of when to use this rating.
  final String description;

  const ReviewQuality({
    required this.value,
    required this.label,
    required this.description,
  });

  /// Returns true if this quality indicates successful recall (hard, good, or easy).
  bool get isSuccess => this != again;

  /// Returns true if this quality indicates a lapse (again).
  bool get isLapse => this == again;

  /// Returns true if this quality represents perfect recall (easy).
  bool get isPerfect => this == easy;

  /// Creates a [ReviewQuality] from an integer value (1-4).
  ///
  /// Throws [ArgumentError] if the value is not between 1 and 4.
  static ReviewQuality fromValue(int value) {
    return switch (value) {
      1 => again,
      2 => hard,
      3 => good,
      4 => easy,
      _ => throw ArgumentError.value(
          value,
          'value',
          'Review quality must be between 1 and 4',
        ),
    };
  }

  /// Attempts to create a [ReviewQuality] from an integer value.
  ///
  /// Returns null if the value is not between 1 and 4.
  static ReviewQuality? tryFromValue(int value) {
    return switch (value) {
      1 => again,
      2 => hard,
      3 => good,
      4 => easy,
      _ => null,
    };
  }

  /// Creates a [ReviewQuality] from a string label (case-insensitive).
  ///
  /// Throws [ArgumentError] if the label is not recognized.
  static ReviewQuality fromLabel(String label) {
    final normalized = label.toLowerCase().trim();
    for (final quality in values) {
      if (quality.label.toLowerCase() == normalized) {
        return quality;
      }
    }
    throw ArgumentError.value(
      label,
      'label',
      'Unknown review quality label. Valid labels: ${values.map((q) => q.label).join(", ")}',
    );
  }

  /// Attempts to create a [ReviewQuality] from a string label.
  ///
  /// Returns null if the label is not recognized.
  static ReviewQuality? tryFromLabel(String label) {
    final normalized = label.toLowerCase().trim();
    for (final quality in values) {
      if (quality.label.toLowerCase() == normalized) {
        return quality;
      }
    }
    return null;
  }

  /// Converts to JSON-compatible map.
  Map<String, dynamic> toJson() => {
        'value': value,
        'label': label,
      };

  /// Creates from JSON map.
  static ReviewQuality fromJson(Map<String, dynamic> json) {
    if (json.containsKey('value')) {
      return fromValue(json['value'] as int);
    }
    if (json.containsKey('label')) {
      return fromLabel(json['label'] as String);
    }
    throw ArgumentError('JSON must contain either "value" or "label"');
  }
}
