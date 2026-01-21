import 'review_quality.dart';

/// Preview of intervals for each possible review quality choice.
///
/// This allows UIs to show users what interval each button will produce
/// before they make their choice.
///
/// Example:
/// ```dart
/// final preview = engine.previewIntervals(card);
/// print('Again: ${preview.againInterval}');  // e.g., "1m"
/// print('Hard: ${preview.hardInterval}');    // e.g., "6m"
/// print('Good: ${preview.goodInterval}');    // e.g., "10m"
/// print('Easy: ${preview.easyInterval}');    // e.g., "4d"
/// ```
class IntervalPreview {
  /// Interval if the user selects "Again" (failed to recall).
  final Duration againInterval;

  /// Interval if the user selects "Hard" (recalled with difficulty).
  final Duration hardInterval;

  /// Interval if the user selects "Good" (normal recall).
  final Duration goodInterval;

  /// Interval if the user selects "Easy" (instant recall).
  final Duration easyInterval;

  /// Creates an interval preview with all four quality intervals.
  const IntervalPreview({
    required this.againInterval,
    required this.hardInterval,
    required this.goodInterval,
    required this.easyInterval,
  });

  /// Returns the interval for a specific quality.
  Duration intervalFor(ReviewQuality quality) {
    return switch (quality) {
      ReviewQuality.again => againInterval,
      ReviewQuality.hard => hardInterval,
      ReviewQuality.good => goodInterval,
      ReviewQuality.easy => easyInterval,
    };
  }

  /// Returns a human-readable formatted interval for a specific quality.
  String formattedIntervalFor(ReviewQuality quality) {
    return _formatDuration(intervalFor(quality));
  }

  /// Returns the "Again" interval formatted for display.
  String get formattedAgainInterval => _formatDuration(againInterval);

  /// Returns the "Hard" interval formatted for display.
  String get formattedHardInterval => _formatDuration(hardInterval);

  /// Returns the "Good" interval formatted for display.
  String get formattedGoodInterval => _formatDuration(goodInterval);

  /// Returns the "Easy" interval formatted for display.
  String get formattedEasyInterval => _formatDuration(easyInterval);

  /// Returns all intervals as a map keyed by quality.
  Map<ReviewQuality, Duration> toMap() => {
        ReviewQuality.again: againInterval,
        ReviewQuality.hard: hardInterval,
        ReviewQuality.good: goodInterval,
        ReviewQuality.easy: easyInterval,
      };

  /// Returns all formatted intervals as a map keyed by quality.
  Map<ReviewQuality, String> toFormattedMap() => {
        ReviewQuality.again: formattedAgainInterval,
        ReviewQuality.hard: formattedHardInterval,
        ReviewQuality.good: formattedGoodInterval,
        ReviewQuality.easy: formattedEasyInterval,
      };

  /// Converts to JSON-compatible map.
  Map<String, dynamic> toJson() => {
        'againInterval': againInterval.inMilliseconds,
        'hardInterval': hardInterval.inMilliseconds,
        'goodInterval': goodInterval.inMilliseconds,
        'easyInterval': easyInterval.inMilliseconds,
      };

  /// Creates from JSON map.
  factory IntervalPreview.fromJson(Map<String, dynamic> json) {
    return IntervalPreview(
      againInterval:
          Duration(milliseconds: json['againInterval'] as int? ?? 60000),
      hardInterval:
          Duration(milliseconds: json['hardInterval'] as int? ?? 360000),
      goodInterval:
          Duration(milliseconds: json['goodInterval'] as int? ?? 600000),
      easyInterval:
          Duration(milliseconds: json['easyInterval'] as int? ?? 345600000),
    );
  }

  /// Formats a duration for human-readable display.
  static String _formatDuration(Duration duration) {
    if (duration.inDays >= 365) {
      final years = duration.inDays / 365;
      if (years == years.roundToDouble()) {
        return '${years.round()}y';
      }
      return '${years.toStringAsFixed(1)}y';
    }
    if (duration.inDays >= 30) {
      final months = duration.inDays / 30;
      if (months == months.roundToDouble()) {
        return '${months.round()}mo';
      }
      return '${months.toStringAsFixed(1)}mo';
    }
    if (duration.inDays >= 1) {
      return '${duration.inDays}d';
    }
    if (duration.inHours >= 1) {
      return '${duration.inHours}h';
    }
    if (duration.inMinutes >= 1) {
      return '${duration.inMinutes}m';
    }
    return '${duration.inSeconds}s';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is IntervalPreview &&
          runtimeType == other.runtimeType &&
          againInterval == other.againInterval &&
          hardInterval == other.hardInterval &&
          goodInterval == other.goodInterval &&
          easyInterval == other.easyInterval;

  @override
  int get hashCode => Object.hash(
        againInterval,
        hardInterval,
        goodInterval,
        easyInterval,
      );

  @override
  String toString() => 'IntervalPreview('
      'again: $formattedAgainInterval, '
      'hard: $formattedHardInterval, '
      'good: $formattedGoodInterval, '
      'easy: $formattedEasyInterval)';
}
