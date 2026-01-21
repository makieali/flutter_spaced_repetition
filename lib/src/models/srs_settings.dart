/// Algorithm type selection for the spaced repetition system.
enum SRSAlgorithmType {
  /// Original SM-2 algorithm by Piotr Wozniak.
  sm2,

  /// Enhanced SM-2 algorithm with improvements.
  sm2Plus,

  /// User-defined custom algorithm.
  custom,
}

/// Comprehensive settings for configuring the spaced repetition algorithm.
///
/// Every setting in this class is actively used by the algorithm - there are
/// no dead configuration options. All values have sensible defaults based on
/// research and practical usage.
///
/// Example:
/// ```dart
/// // Use default Anki-like settings
/// final settings = SRSSettings.anki();
///
/// // Or customize specific values
/// final customSettings = SRSSettings(
///   learningSteps: [Duration(minutes: 1), Duration(minutes: 10)],
///   graduatingInterval: Duration(days: 1),
///   minimumEaseFactor: 1.3,
/// );
/// ```
class SRSSettings {
  // ============================================================
  // LEARNING PHASE SETTINGS
  // ============================================================

  /// Steps (intervals) used during the learning phase.
  ///
  /// When a card is new or has lapsed, it goes through these steps.
  /// Each successful review advances to the next step.
  /// After completing all steps, the card graduates to the review phase.
  ///
  /// Default: [1 minute, 10 minutes] (Anki default)
  final List<Duration> learningSteps;

  /// Number of successful reviews required to graduate from learning.
  ///
  /// Must be >= 1. A card must be answered correctly this many times
  /// before graduating from the learning phase.
  ///
  /// Default: 2 (matching learning steps count)
  final int graduationsRequired;

  /// Number of lapses (Again responses) before the card resets completely.
  ///
  /// If a card lapses this many times, it is considered a "leech" and
  /// may need special attention. Set to 0 to disable.
  ///
  /// Default: 8
  final int lapsesBeforeLeech;

  // ============================================================
  // INTERVAL SETTINGS
  // ============================================================

  /// Interval assigned when a card graduates from learning phase.
  ///
  /// This is the first "real" interval for a card that has completed
  /// all learning steps successfully.
  ///
  /// Default: 1 day
  final Duration graduatingInterval;

  /// Interval assigned when pressing Easy on a new/learning card.
  ///
  /// Allows users to immediately graduate cards they already know
  /// with a longer initial interval.
  ///
  /// Default: 4 days
  final Duration easyInterval;

  /// Minimum interval for any card in the review phase.
  ///
  /// No review card will have an interval shorter than this.
  /// Useful to prevent cards from being shown too frequently.
  ///
  /// Default: 1 day
  final Duration minimumInterval;

  /// Maximum interval for any card.
  ///
  /// No card will have an interval longer than this.
  /// Prevents cards from being forgotten due to extremely long intervals.
  ///
  /// Default: 365 days (1 year)
  final Duration maximumInterval;

  // ============================================================
  // EASE FACTOR SETTINGS
  // ============================================================

  /// Initial ease factor for new cards.
  ///
  /// The ease factor is a multiplier applied to intervals.
  /// Higher values mean faster interval growth.
  ///
  /// Default: 2.5 (SM-2 default)
  final double initialEaseFactor;

  /// Minimum ease factor a card can have.
  ///
  /// Prevents cards from becoming too difficult (showing too often).
  /// Ease factor will never drop below this value.
  ///
  /// Default: 1.3
  final double minimumEaseFactor;

  /// Bonus multiplier applied when answering Easy.
  ///
  /// The interval is multiplied by this factor on top of the ease factor.
  /// Value of 1.0 means no bonus.
  ///
  /// Default: 1.3
  final double easyBonus;

  /// Penalty multiplier applied when answering Hard.
  ///
  /// The interval is multiplied by this factor (should be < 1.0).
  /// Value of 1.0 means no penalty.
  ///
  /// Default: 1.2 (interval multiplied by 1.2 but ease decreases)
  final double hardIntervalMultiplier;

  /// Multiplier applied to interval when a card lapses (Again).
  ///
  /// When a card is forgotten, the new interval becomes:
  /// previous_interval * lapseMultiplier
  ///
  /// Default: 0.0 (start from scratch after lapse)
  final double lapseMultiplier;

  // ============================================================
  // EASE ADJUSTMENT SETTINGS
  // ============================================================

  /// Amount to decrease ease factor on Hard response.
  ///
  /// Ease factor is reduced by this amount when user answers Hard.
  ///
  /// Default: 0.15 (15%)
  final double hardEasePenalty;

  /// Amount to decrease ease factor on Again response.
  ///
  /// Ease factor is reduced by this amount when user answers Again.
  ///
  /// Default: 0.20 (20%)
  final double againEasePenalty;

  /// Amount to increase ease factor on Easy response.
  ///
  /// Ease factor is increased by this amount when user answers Easy.
  ///
  /// Default: 0.15 (15%)
  final double easyEaseBonus;

  // ============================================================
  // ALGORITHM SETTINGS
  // ============================================================

  /// The algorithm implementation to use.
  ///
  /// Default: sm2
  final SRSAlgorithmType algorithmType;

  /// Fuzz factor for interval randomization (0.0 to disable).
  ///
  /// Adds random variation to intervals to prevent "bunching" of reviews.
  /// A value of 0.05 means ±5% randomization.
  ///
  /// Default: 0.05
  final double intervalFuzz;

  /// Creates SRS settings with fully configurable parameters.
  ///
  /// All parameters have sensible defaults. Override only what you need.
  const SRSSettings({
    this.learningSteps = const [
      Duration(minutes: 1),
      Duration(minutes: 10),
    ],
    this.graduationsRequired = 2,
    this.lapsesBeforeLeech = 8,
    this.graduatingInterval = const Duration(days: 1),
    this.easyInterval = const Duration(days: 4),
    this.minimumInterval = const Duration(days: 1),
    this.maximumInterval = const Duration(days: 365),
    this.initialEaseFactor = 2.5,
    this.minimumEaseFactor = 1.3,
    this.easyBonus = 1.3,
    this.hardIntervalMultiplier = 1.2,
    this.lapseMultiplier = 0.0,
    this.hardEasePenalty = 0.15,
    this.againEasePenalty = 0.20,
    this.easyEaseBonus = 0.15,
    this.algorithmType = SRSAlgorithmType.sm2,
    this.intervalFuzz = 0.05,
  });

  /// Creates settings mimicking Anki's defaults.
  ///
  /// These are the standard settings used by the popular Anki app.
  factory SRSSettings.anki() => const SRSSettings(
        learningSteps: [
          Duration(minutes: 1),
          Duration(minutes: 10),
        ],
        graduationsRequired: 2,
        lapsesBeforeLeech: 8,
        graduatingInterval: Duration(days: 1),
        easyInterval: Duration(days: 4),
        minimumInterval: Duration(days: 1),
        maximumInterval: Duration(days: 36500), // 100 years
        initialEaseFactor: 2.5,
        minimumEaseFactor: 1.3,
        easyBonus: 1.3,
        hardIntervalMultiplier: 1.2,
        lapseMultiplier: 0.0,
        hardEasePenalty: 0.15,
        againEasePenalty: 0.20,
        easyEaseBonus: 0.15,
        algorithmType: SRSAlgorithmType.sm2,
        intervalFuzz: 0.05,
      );

  /// Creates settings based on original SuperMemo SM-2 defaults.
  factory SRSSettings.supermemo() => const SRSSettings(
        learningSteps: [
          Duration(minutes: 1),
          Duration(minutes: 6),
        ],
        graduationsRequired: 2,
        lapsesBeforeLeech: 10,
        graduatingInterval: Duration(days: 1),
        easyInterval: Duration(days: 6),
        minimumInterval: Duration(days: 1),
        maximumInterval: Duration(days: 365),
        initialEaseFactor: 2.5,
        minimumEaseFactor: 1.3,
        easyBonus: 1.5,
        hardIntervalMultiplier: 1.0,
        lapseMultiplier: 0.0,
        hardEasePenalty: 0.14,
        againEasePenalty: 0.20,
        easyEaseBonus: 0.10,
        algorithmType: SRSAlgorithmType.sm2,
        intervalFuzz: 0.0,
      );

  /// Creates aggressive settings for faster learning with more reviews.
  ///
  /// Good for beginners or when rapid acquisition is needed.
  factory SRSSettings.aggressive() => const SRSSettings(
        learningSteps: [
          Duration(minutes: 1),
          Duration(minutes: 5),
          Duration(minutes: 10),
        ],
        graduationsRequired: 3,
        lapsesBeforeLeech: 5,
        graduatingInterval: Duration(hours: 12),
        easyInterval: Duration(days: 2),
        minimumInterval: Duration(hours: 12),
        maximumInterval: Duration(days: 180),
        initialEaseFactor: 2.3,
        minimumEaseFactor: 1.5,
        easyBonus: 1.2,
        hardIntervalMultiplier: 1.0,
        lapseMultiplier: 0.0,
        hardEasePenalty: 0.20,
        againEasePenalty: 0.25,
        easyEaseBonus: 0.10,
        algorithmType: SRSAlgorithmType.sm2,
        intervalFuzz: 0.0,
      );

  /// Creates relaxed settings for casual learning with fewer reviews.
  ///
  /// Good for maintenance or when time is limited.
  factory SRSSettings.relaxed() => const SRSSettings(
        learningSteps: [
          Duration(minutes: 10),
          Duration(hours: 1),
        ],
        graduationsRequired: 2,
        lapsesBeforeLeech: 12,
        graduatingInterval: Duration(days: 2),
        easyInterval: Duration(days: 7),
        minimumInterval: Duration(days: 1),
        maximumInterval: Duration(days: 730), // 2 years
        initialEaseFactor: 2.7,
        minimumEaseFactor: 1.2,
        easyBonus: 1.5,
        hardIntervalMultiplier: 1.3,
        lapseMultiplier: 0.25,
        hardEasePenalty: 0.10,
        againEasePenalty: 0.15,
        easyEaseBonus: 0.20,
        algorithmType: SRSAlgorithmType.sm2,
        intervalFuzz: 0.10,
      );

  /// Validates all settings and throws [ArgumentError] if invalid.
  void validate() {
    if (learningSteps.isEmpty) {
      throw ArgumentError.value(
        learningSteps,
        'learningSteps',
        'Learning steps cannot be empty',
      );
    }

    if (graduationsRequired < 1) {
      throw ArgumentError.value(
        graduationsRequired,
        'graduationsRequired',
        'Graduations required must be at least 1',
      );
    }

    if (lapsesBeforeLeech < 0) {
      throw ArgumentError.value(
        lapsesBeforeLeech,
        'lapsesBeforeLeech',
        'Lapses before leech cannot be negative',
      );
    }

    if (graduatingInterval.inSeconds <= 0) {
      throw ArgumentError.value(
        graduatingInterval,
        'graduatingInterval',
        'Graduating interval must be positive',
      );
    }

    if (easyInterval.inSeconds <= 0) {
      throw ArgumentError.value(
        easyInterval,
        'easyInterval',
        'Easy interval must be positive',
      );
    }

    if (minimumInterval.inSeconds <= 0) {
      throw ArgumentError.value(
        minimumInterval,
        'minimumInterval',
        'Minimum interval must be positive',
      );
    }

    if (maximumInterval < minimumInterval) {
      throw ArgumentError.value(
        maximumInterval,
        'maximumInterval',
        'Maximum interval must be >= minimum interval',
      );
    }

    if (initialEaseFactor < minimumEaseFactor) {
      throw ArgumentError.value(
        initialEaseFactor,
        'initialEaseFactor',
        'Initial ease factor must be >= minimum ease factor',
      );
    }

    if (minimumEaseFactor < 1.0) {
      throw ArgumentError.value(
        minimumEaseFactor,
        'minimumEaseFactor',
        'Minimum ease factor must be at least 1.0',
      );
    }

    if (easyBonus < 1.0) {
      throw ArgumentError.value(
        easyBonus,
        'easyBonus',
        'Easy bonus must be at least 1.0',
      );
    }

    if (hardIntervalMultiplier <= 0) {
      throw ArgumentError.value(
        hardIntervalMultiplier,
        'hardIntervalMultiplier',
        'Hard interval multiplier must be positive',
      );
    }

    if (lapseMultiplier < 0 || lapseMultiplier > 1) {
      throw ArgumentError.value(
        lapseMultiplier,
        'lapseMultiplier',
        'Lapse multiplier must be between 0 and 1',
      );
    }

    if (intervalFuzz < 0 || intervalFuzz > 1) {
      throw ArgumentError.value(
        intervalFuzz,
        'intervalFuzz',
        'Interval fuzz must be between 0 and 1',
      );
    }
  }

  /// Creates a copy with specified fields replaced.
  SRSSettings copyWith({
    List<Duration>? learningSteps,
    int? graduationsRequired,
    int? lapsesBeforeLeech,
    Duration? graduatingInterval,
    Duration? easyInterval,
    Duration? minimumInterval,
    Duration? maximumInterval,
    double? initialEaseFactor,
    double? minimumEaseFactor,
    double? easyBonus,
    double? hardIntervalMultiplier,
    double? lapseMultiplier,
    double? hardEasePenalty,
    double? againEasePenalty,
    double? easyEaseBonus,
    SRSAlgorithmType? algorithmType,
    double? intervalFuzz,
  }) {
    return SRSSettings(
      learningSteps: learningSteps ?? this.learningSteps,
      graduationsRequired: graduationsRequired ?? this.graduationsRequired,
      lapsesBeforeLeech: lapsesBeforeLeech ?? this.lapsesBeforeLeech,
      graduatingInterval: graduatingInterval ?? this.graduatingInterval,
      easyInterval: easyInterval ?? this.easyInterval,
      minimumInterval: minimumInterval ?? this.minimumInterval,
      maximumInterval: maximumInterval ?? this.maximumInterval,
      initialEaseFactor: initialEaseFactor ?? this.initialEaseFactor,
      minimumEaseFactor: minimumEaseFactor ?? this.minimumEaseFactor,
      easyBonus: easyBonus ?? this.easyBonus,
      hardIntervalMultiplier:
          hardIntervalMultiplier ?? this.hardIntervalMultiplier,
      lapseMultiplier: lapseMultiplier ?? this.lapseMultiplier,
      hardEasePenalty: hardEasePenalty ?? this.hardEasePenalty,
      againEasePenalty: againEasePenalty ?? this.againEasePenalty,
      easyEaseBonus: easyEaseBonus ?? this.easyEaseBonus,
      algorithmType: algorithmType ?? this.algorithmType,
      intervalFuzz: intervalFuzz ?? this.intervalFuzz,
    );
  }

  /// Converts settings to a JSON-compatible map.
  Map<String, dynamic> toJson() => {
        'learningSteps':
            learningSteps.map((d) => d.inMilliseconds).toList(),
        'graduationsRequired': graduationsRequired,
        'lapsesBeforeLeech': lapsesBeforeLeech,
        'graduatingInterval': graduatingInterval.inMilliseconds,
        'easyInterval': easyInterval.inMilliseconds,
        'minimumInterval': minimumInterval.inMilliseconds,
        'maximumInterval': maximumInterval.inMilliseconds,
        'initialEaseFactor': initialEaseFactor,
        'minimumEaseFactor': minimumEaseFactor,
        'easyBonus': easyBonus,
        'hardIntervalMultiplier': hardIntervalMultiplier,
        'lapseMultiplier': lapseMultiplier,
        'hardEasePenalty': hardEasePenalty,
        'againEasePenalty': againEasePenalty,
        'easyEaseBonus': easyEaseBonus,
        'algorithmType': algorithmType.name,
        'intervalFuzz': intervalFuzz,
      };

  /// Creates settings from a JSON map.
  factory SRSSettings.fromJson(Map<String, dynamic> json) {
    return SRSSettings(
      learningSteps: (json['learningSteps'] as List<dynamic>?)
              ?.map((ms) => Duration(milliseconds: ms as int))
              .toList() ??
          const [Duration(minutes: 1), Duration(minutes: 10)],
      graduationsRequired: json['graduationsRequired'] as int? ?? 2,
      lapsesBeforeLeech: json['lapsesBeforeLeech'] as int? ?? 8,
      graduatingInterval: Duration(
        milliseconds: json['graduatingInterval'] as int? ?? 86400000,
      ),
      easyInterval: Duration(
        milliseconds: json['easyInterval'] as int? ?? 345600000,
      ),
      minimumInterval: Duration(
        milliseconds: json['minimumInterval'] as int? ?? 86400000,
      ),
      maximumInterval: Duration(
        milliseconds: json['maximumInterval'] as int? ?? 31536000000,
      ),
      initialEaseFactor: (json['initialEaseFactor'] as num?)?.toDouble() ?? 2.5,
      minimumEaseFactor: (json['minimumEaseFactor'] as num?)?.toDouble() ?? 1.3,
      easyBonus: (json['easyBonus'] as num?)?.toDouble() ?? 1.3,
      hardIntervalMultiplier:
          (json['hardIntervalMultiplier'] as num?)?.toDouble() ?? 1.2,
      lapseMultiplier: (json['lapseMultiplier'] as num?)?.toDouble() ?? 0.0,
      hardEasePenalty: (json['hardEasePenalty'] as num?)?.toDouble() ?? 0.15,
      againEasePenalty: (json['againEasePenalty'] as num?)?.toDouble() ?? 0.20,
      easyEaseBonus: (json['easyEaseBonus'] as num?)?.toDouble() ?? 0.15,
      algorithmType: SRSAlgorithmType.values.firstWhere(
        (e) => e.name == json['algorithmType'],
        orElse: () => SRSAlgorithmType.sm2,
      ),
      intervalFuzz: (json['intervalFuzz'] as num?)?.toDouble() ?? 0.05,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SRSSettings &&
          runtimeType == other.runtimeType &&
          _listEquals(learningSteps, other.learningSteps) &&
          graduationsRequired == other.graduationsRequired &&
          lapsesBeforeLeech == other.lapsesBeforeLeech &&
          graduatingInterval == other.graduatingInterval &&
          easyInterval == other.easyInterval &&
          minimumInterval == other.minimumInterval &&
          maximumInterval == other.maximumInterval &&
          initialEaseFactor == other.initialEaseFactor &&
          minimumEaseFactor == other.minimumEaseFactor &&
          easyBonus == other.easyBonus &&
          hardIntervalMultiplier == other.hardIntervalMultiplier &&
          lapseMultiplier == other.lapseMultiplier &&
          hardEasePenalty == other.hardEasePenalty &&
          againEasePenalty == other.againEasePenalty &&
          easyEaseBonus == other.easyEaseBonus &&
          algorithmType == other.algorithmType &&
          intervalFuzz == other.intervalFuzz;

  @override
  int get hashCode => Object.hash(
        Object.hashAll(learningSteps),
        graduationsRequired,
        lapsesBeforeLeech,
        graduatingInterval,
        easyInterval,
        minimumInterval,
        maximumInterval,
        initialEaseFactor,
        minimumEaseFactor,
        easyBonus,
        hardIntervalMultiplier,
        lapseMultiplier,
        hardEasePenalty,
        againEasePenalty,
        easyEaseBonus,
        algorithmType,
        intervalFuzz,
      );

  static bool _listEquals<T>(List<T> a, List<T> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  String toString() => 'SRSSettings('
      'algorithmType: $algorithmType, '
      'learningSteps: ${learningSteps.length}, '
      'initialEase: $initialEaseFactor, '
      'minInterval: ${minimumInterval.inDays}d, '
      'maxInterval: ${maximumInterval.inDays}d)';
}
