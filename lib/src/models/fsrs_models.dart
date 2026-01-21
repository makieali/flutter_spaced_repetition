import 'dart:math' as math;

/// FSRS card state tracking stability and difficulty.
///
/// This extends the basic card state with FSRS-specific memory parameters.
class FSRSState {
  /// Creates a new FSRS state.
  const FSRSState({
    this.stability = 0.0,
    this.difficulty = 0.0,
    this.lastReview,
    this.reps = 0,
    this.lapses = 0,
    this.state = FSRSCardState.newCard,
  });

  /// Creates a new card state.
  factory FSRSState.newCard() => const FSRSState();

  /// Creates from JSON.
  factory FSRSState.fromJson(Map<String, dynamic> json) => FSRSState(
        stability: (json['stability'] as num?)?.toDouble() ?? 0.0,
        difficulty: (json['difficulty'] as num?)?.toDouble() ?? 0.0,
        lastReview: json['lastReview'] != null
            ? DateTime.parse(json['lastReview'] as String)
            : null,
        reps: json['reps'] as int? ?? 0,
        lapses: json['lapses'] as int? ?? 0,
        state: FSRSCardState.values[json['state'] as int? ?? 0],
      );

  /// Stability: time (in days) for retrievability to decay from 100% to 90%.
  final double stability;

  /// Difficulty: inherent difficulty of the card (1.0 to 10.0).
  final double difficulty;

  /// Last review timestamp.
  final DateTime? lastReview;

  /// Number of times the card has been reviewed.
  final int reps;

  /// Number of times the card has lapsed.
  final int lapses;

  /// Current state of the card.
  final FSRSCardState state;

  /// Calculates retrievability at the given time.
  ///
  /// Retrievability is the probability of successfully recalling the card.
  /// It decays exponentially over time based on stability.
  double retrievability(DateTime now) {
    if (lastReview == null || stability <= 0) return 0.0;

    final elapsedDays = now.difference(lastReview!).inMinutes / 1440;
    if (elapsedDays <= 0) return 1.0;

    // FSRS formula: R = (1 + t/S * FACTOR)^DECAY
    // Where FACTOR = 19/81 and DECAY = -0.5
    const factor = 19 / 81;
    const decay = -0.5;

    return math.pow(1 + factor * elapsedDays / stability, decay).toDouble();
  }

  /// Days until retrievability drops to target (default 90%).
  double daysUntilTarget(double targetRetention) {
    if (stability <= 0) return 0.0;

    // Inverse of retrievability formula
    // t = S * (R^(1/DECAY) - 1) / FACTOR
    const factor = 19 / 81;
    const decay = -0.5;

    return stability * (math.pow(targetRetention, 1 / decay) - 1) / factor;
  }

  /// Creates a copy with updated values.
  FSRSState copyWith({
    double? stability,
    double? difficulty,
    DateTime? lastReview,
    int? reps,
    int? lapses,
    FSRSCardState? state,
  }) =>
      FSRSState(
        stability: stability ?? this.stability,
        difficulty: difficulty ?? this.difficulty,
        lastReview: lastReview ?? this.lastReview,
        reps: reps ?? this.reps,
        lapses: lapses ?? this.lapses,
        state: state ?? this.state,
      );

  /// Converts to JSON.
  Map<String, dynamic> toJson() => {
        'stability': stability,
        'difficulty': difficulty,
        if (lastReview != null) 'lastReview': lastReview!.toIso8601String(),
        'reps': reps,
        'lapses': lapses,
        'state': state.index,
      };

  @override
  String toString() =>
      'FSRSState(S: ${stability.toStringAsFixed(2)}, '
      'D: ${difficulty.toStringAsFixed(2)}, state: $state)';
}

/// FSRS card states.
enum FSRSCardState {
  /// Card has never been reviewed.
  newCard,

  /// Card is in the learning phase.
  learning,

  /// Card is in the review phase (graduated).
  review,

  /// Card is being relearned after a lapse.
  relearning,
}

/// FSRS algorithm parameters (21 weights).
///
/// These parameters are optimized using machine learning on review history.
/// Default values are from FSRS-5.
class FSRSParameters {
  /// Creates FSRS parameters with the given weights.
  ///
  /// Must have exactly 21 weights.
  FSRSParameters(this.weights) {
    if (weights.length != 21) {
      throw ArgumentError('FSRS parameters must have exactly 21 weights');
    }
  }

  /// Default FSRS-5 parameters optimized on large datasets.
  factory FSRSParameters.defaults() => FSRSParameters([
        0.40255, // w0: Initial stability for Again
        1.18385, // w1: Initial stability for Hard
        3.173, // w2: Initial stability for Good
        15.69105, // w3: Initial stability for Easy
        7.1949, // w4: Difficulty weight
        0.5345, // w5: Difficulty weight
        1.4604, // w6: Difficulty weight
        0.0046, // w7: Difficulty weight
        1.54575, // w8: Stability increase factor
        0.1192, // w9: Stability increase factor
        1.01925, // w10: Stability increase factor
        1.9395, // w11: Stability increase factor
        0.11, // w12: Stability increase factor
        0.29605, // w13: Stability decrease factor (lapse)
        2.2698, // w14: Stability decrease factor (lapse)
        0.2315, // w15: Stability decrease factor (lapse)
        2.9898, // w16: Stability decrease factor (lapse)
        0.51655, // w17: Hard penalty
        0.6621, // w18: Easy bonus
        0.0, // w19: Reserved
        0.0, // w20: Reserved
      ]);

  /// Parameters optimized for language learning.
  factory FSRSParameters.language() => FSRSParameters([
        0.35, 1.1, 2.8, 12.0, 6.5, 0.5, 1.3, 0.005, 1.4, 0.12,
        0.95, 1.8, 0.1, 0.28, 2.1, 0.22, 2.8, 0.5, 0.65, 0.0, 0.0,
      ]);

  /// Parameters optimized for medical/science content.
  factory FSRSParameters.medical() => FSRSParameters([
        0.45, 1.25, 3.5, 18.0, 7.5, 0.55, 1.5, 0.004, 1.6, 0.11,
        1.05, 2.0, 0.12, 0.31, 2.4, 0.24, 3.1, 0.53, 0.68, 0.0, 0.0,
      ]);

  /// Creates from JSON.
  factory FSRSParameters.fromJson(List<dynamic> json) =>
      FSRSParameters(json.map((e) => (e as num).toDouble()).toList());

  /// The 21 weights used by the FSRS algorithm.
  final List<double> weights;

  // Individual weight accessors for clarity
  double get w0 => weights[0];
  double get w1 => weights[1];
  double get w2 => weights[2];
  double get w3 => weights[3];
  double get w4 => weights[4];
  double get w5 => weights[5];
  double get w6 => weights[6];
  double get w7 => weights[7];
  double get w8 => weights[8];
  double get w9 => weights[9];
  double get w10 => weights[10];
  double get w11 => weights[11];
  double get w12 => weights[12];
  double get w13 => weights[13];
  double get w14 => weights[14];
  double get w15 => weights[15];
  double get w16 => weights[16];
  double get w17 => weights[17];
  double get w18 => weights[18];

  /// Converts to JSON.
  List<double> toJson() => weights;

  @override
  String toString() => 'FSRSParameters(${weights.length} weights)';
}

/// FSRS scheduler settings.
class FSRSSettings {
  /// Creates FSRS settings.
  const FSRSSettings({
    this.desiredRetention = 0.9,
    this.maximumInterval = 36500,
    this.learningSteps = const [1, 10],
    this.relearningSteps = const [10],
    this.enableFuzz = true,
    FSRSParameters? parameters,
  }) : _parameters = parameters;

  /// Standard settings with 90% retention.
  factory FSRSSettings.standard() => const FSRSSettings();

  /// High retention settings (95%).
  factory FSRSSettings.highRetention() => const FSRSSettings(
        desiredRetention: 0.95,
      );

  /// Low retention settings (80%) for maintenance.
  factory FSRSSettings.lowRetention() => const FSRSSettings(
        desiredRetention: 0.80,
      );

  /// Creates from JSON.
  factory FSRSSettings.fromJson(Map<String, dynamic> json) => FSRSSettings(
        desiredRetention: (json['desiredRetention'] as num?)?.toDouble() ?? 0.9,
        maximumInterval: json['maximumInterval'] as int? ?? 36500,
        learningSteps:
            (json['learningSteps'] as List?)?.cast<int>() ?? const [1, 10],
        relearningSteps:
            (json['relearningSteps'] as List?)?.cast<int>() ?? const [10],
        enableFuzz: json['enableFuzz'] as bool? ?? true,
        parameters: json['parameters'] != null
            ? FSRSParameters.fromJson(json['parameters'] as List)
            : null,
      );

  final FSRSParameters? _parameters;

  /// The FSRS algorithm parameters.
  FSRSParameters get parameters => _parameters ?? FSRSParameters.defaults();

  /// The desired retention rate (0.7 to 0.97).
  ///
  /// This is the target probability of recall when a card is due.
  /// Default is 0.9 (90% retention).
  final double desiredRetention;

  /// Maximum interval in days.
  final int maximumInterval;

  /// Learning steps for new cards (in minutes).
  final List<int> learningSteps;

  /// Relearning steps for lapsed cards (in minutes).
  final List<int> relearningSteps;

  /// Whether to enable fuzzing (randomization) of intervals.
  final bool enableFuzz;

  /// Creates a copy with updated values.
  FSRSSettings copyWith({
    double? desiredRetention,
    int? maximumInterval,
    List<int>? learningSteps,
    List<int>? relearningSteps,
    bool? enableFuzz,
    FSRSParameters? parameters,
  }) =>
      FSRSSettings(
        desiredRetention: desiredRetention ?? this.desiredRetention,
        maximumInterval: maximumInterval ?? this.maximumInterval,
        learningSteps: learningSteps ?? this.learningSteps,
        relearningSteps: relearningSteps ?? this.relearningSteps,
        enableFuzz: enableFuzz ?? this.enableFuzz,
        parameters: parameters ?? _parameters,
      );

  /// Validates settings.
  void validate() {
    if (desiredRetention < 0.7 || desiredRetention > 0.97) {
      throw ArgumentError(
        'desiredRetention must be between 0.7 and 0.97, got $desiredRetention',
      );
    }
    if (maximumInterval < 1) {
      throw ArgumentError('maximumInterval must be positive');
    }
    if (learningSteps.isEmpty) {
      throw ArgumentError('learningSteps cannot be empty');
    }
    if (relearningSteps.isEmpty) {
      throw ArgumentError('relearningSteps cannot be empty');
    }
  }

  /// Converts to JSON.
  Map<String, dynamic> toJson() => {
        'desiredRetention': desiredRetention,
        'maximumInterval': maximumInterval,
        'learningSteps': learningSteps,
        'relearningSteps': relearningSteps,
        'enableFuzz': enableFuzz,
        'parameters': parameters.toJson(),
      };
}

/// Result of an FSRS scheduling calculation.
class FSRSSchedulingResult {
  /// Creates an FSRS scheduling result.
  const FSRSSchedulingResult({
    required this.state,
    required this.intervalDays,
    required this.nextReview,
    required this.retrievabilityBefore,
    required this.retrievabilityAfter,
  });

  /// The updated FSRS state.
  final FSRSState state;

  /// The scheduled interval in days.
  final double intervalDays;

  /// The scheduled interval as Duration.
  Duration get interval => Duration(minutes: (intervalDays * 1440).round());

  /// The next review time.
  final DateTime nextReview;

  /// Current retrievability (before review).
  final double retrievabilityBefore;

  /// Predicted retrievability after this interval.
  final double retrievabilityAfter;

  @override
  String toString() =>
      'FSRSSchedulingResult(interval: ${intervalDays.toStringAsFixed(1)}d, '
      'R: ${(retrievabilityAfter * 100).toStringAsFixed(0)}%)';
}
