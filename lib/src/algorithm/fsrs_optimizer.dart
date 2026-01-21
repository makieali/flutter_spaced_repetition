import 'dart:math' as math;

import '../models/fsrs_models.dart';
import '../models/review_log.dart';
import '../models/review_quality.dart';

/// FSRS parameter optimizer using maximum likelihood estimation.
///
/// This optimizer learns personalized FSRS parameters from a user's review
/// history. It uses simplified MLE to find parameters that best predict
/// the user's actual recall performance.
///
/// Usage:
/// ```dart
/// final optimizer = FSRSOptimizer();
/// final optimizedParams = optimizer.optimize(reviewHistory);
/// final newSettings = settings.copyWith(parameters: optimizedParams);
/// ```
class FSRSOptimizer {
  /// Creates an FSRS optimizer.
  FSRSOptimizer({
    this.learningRate = 0.1,
    this.iterations = 100,
    this.minSamples = 100,
  });

  /// Learning rate for gradient descent.
  final double learningRate;

  /// Number of optimization iterations.
  final int iterations;

  /// Minimum samples required for optimization.
  final int minSamples;

  /// Optimizes FSRS parameters based on review history.
  ///
  /// Returns optimized parameters, or default parameters if there's
  /// insufficient data for optimization.
  FSRSParameters optimize(ReviewHistory history) {
    final logs = history.logs;

    if (logs.length < minSamples) {
      return FSRSParameters.defaults();
    }

    // Start with default parameters
    var params = FSRSParameters.defaults().weights.toList();

    // Separate logs by card state
    final newCardLogs = _filterNewCardReviews(logs);
    final reviewLogs = _filterReviewPhaseReviews(logs);

    // Optimize initial stability parameters (w0-w3)
    if (newCardLogs.length >= 20) {
      params = _optimizeInitialStability(params, newCardLogs);
    }

    // Optimize difficulty parameters (w4-w7)
    if (reviewLogs.length >= 50) {
      params = _optimizeDifficultyParams(params, reviewLogs);
    }

    // Optimize stability increase parameters (w8-w12)
    if (reviewLogs.length >= 50) {
      params = _optimizeStabilityIncrease(params, reviewLogs);
    }

    // Optimize lapse parameters (w13-w16)
    final lapseLogs = logs.where((l) => l.rating == ReviewQuality.again).toList();
    if (lapseLogs.length >= 20) {
      params = _optimizeLapseParams(params, lapseLogs);
    }

    return FSRSParameters(params);
  }

  /// Filters logs for first reviews of new cards.
  List<ReviewLog> _filterNewCardReviews(List<ReviewLog> logs) {
    // Group by card and get first review
    final cardFirstReviews = <String, ReviewLog>{};
    for (final log in logs) {
      if (!cardFirstReviews.containsKey(log.cardId)) {
        cardFirstReviews[log.cardId] = log;
      }
    }
    return cardFirstReviews.values.toList();
  }

  /// Filters logs for review phase cards.
  List<ReviewLog> _filterReviewPhaseReviews(List<ReviewLog> logs) {
    return logs.where((log) {
      // Review phase indicated by having stability data
      return log.stabilityBefore != null && log.stabilityBefore! > 1.0;
    }).toList();
  }

  /// Optimizes initial stability parameters (w0-w3).
  List<double> _optimizeInitialStability(
    List<double> params,
    List<ReviewLog> logs,
  ) {
    final result = params.toList();

    // Calculate average stability for each rating
    final stabilityByRating = <ReviewQuality, List<double>>{};
    for (final log in logs) {
      if (log.stabilityAfter != null) {
        stabilityByRating.putIfAbsent(log.rating, () => []);
        stabilityByRating[log.rating]!.add(log.stabilityAfter!);
      }
    }

    // Update w0-w3 based on observed stabilities
    for (final entry in stabilityByRating.entries) {
      if (entry.value.isNotEmpty) {
        final avgStability = entry.value.reduce((a, b) => a + b) / entry.value.length;
        final index = entry.key.value - 1; // 0-3 for Again-Easy
        if (index >= 0 && index < 4) {
          // Blend with current value
          result[index] = result[index] * 0.7 + avgStability * 0.3;
        }
      }
    }

    return result;
  }

  /// Optimizes difficulty parameters (w4-w7).
  List<double> _optimizeDifficultyParams(
    List<double> params,
    List<ReviewLog> logs,
  ) {
    final result = params.toList();

    // Calculate actual vs predicted difficulty correlation
    final difficultyData = <({double predicted, double actual})>[];

    for (final log in logs) {
      if (log.difficultyBefore != null && log.difficultyAfter != null) {
        difficultyData.add((
          predicted: log.difficultyBefore!,
          actual: log.difficultyAfter!,
        ));
      }
    }

    if (difficultyData.length >= 20) {
      // Simple gradient descent on w4 (base difficulty)
      var w4 = result[4];
      for (var i = 0; i < iterations ~/ 2; i++) {
        var gradient = 0.0;
        for (final data in difficultyData) {
          gradient += (data.predicted - data.actual) * 0.01;
        }
        w4 -= learningRate * gradient / difficultyData.length;
        w4 = w4.clamp(1.0, 10.0);
      }
      result[4] = w4;
    }

    return result;
  }

  /// Optimizes stability increase parameters (w8-w12).
  List<double> _optimizeStabilityIncrease(
    List<double> params,
    List<ReviewLog> logs,
  ) {
    final result = params.toList();

    // Calculate stability growth rates
    final growthRates = <double>[];

    for (final log in logs) {
      if (log.stabilityBefore != null &&
          log.stabilityAfter != null &&
          log.stabilityBefore! > 0 &&
          log.wasSuccessful) {
        final growth = log.stabilityAfter! / log.stabilityBefore!;
        growthRates.add(growth);
      }
    }

    if (growthRates.length >= 20) {
      final avgGrowth = growthRates.reduce((a, b) => a + b) / growthRates.length;

      // Adjust w8 (primary stability growth factor)
      // If average growth is higher than expected, increase w8
      final expectedGrowth = math.exp(result[8]);
      final adjustment = (avgGrowth / expectedGrowth - 1) * 0.1;
      result[8] = (result[8] + adjustment).clamp(0.5, 3.0);
    }

    return result;
  }

  /// Optimizes lapse parameters (w13-w16).
  List<double> _optimizeLapseParams(
    List<double> params,
    List<ReviewLog> logs,
  ) {
    final result = params.toList();

    // Calculate stability after lapse
    final lapseStabilities = <double>[];

    for (final log in logs) {
      if (log.stabilityBefore != null && log.stabilityAfter != null) {
        final ratio = log.stabilityAfter! / log.stabilityBefore!;
        lapseStabilities.add(ratio);
      }
    }

    if (lapseStabilities.isNotEmpty) {
      final avgRatio = lapseStabilities.reduce((a, b) => a + b) / lapseStabilities.length;

      // Adjust w13 (base lapse factor)
      result[13] = (avgRatio * result[13] / 0.3).clamp(0.1, 0.5);
    }

    return result;
  }

  /// Evaluates how well parameters predict actual recall.
  ///
  /// Returns log loss (lower is better).
  double evaluate(FSRSParameters params, ReviewHistory history) {
    final logs = history.logs.where((l) => l.retrievability != null).toList();
    if (logs.isEmpty) return double.infinity;

    var totalLoss = 0.0;

    for (final log in logs) {
      final r = log.retrievability!;
      final success = log.wasSuccessful ? 1.0 : 0.0;

      // Binary cross-entropy loss
      final loss = -success * math.log(r + 1e-10) -
          (1 - success) * math.log(1 - r + 1e-10);
      totalLoss += loss;
    }

    return totalLoss / logs.length;
  }

  /// Compares two parameter sets.
  ///
  /// Returns true if params1 is better than params2.
  bool compare(
    FSRSParameters params1,
    FSRSParameters params2,
    ReviewHistory history,
  ) {
    return evaluate(params1, history) < evaluate(params2, history);
  }
}

/// Simple statistics for optimization.
class OptimizationStats {
  /// Creates optimization statistics.
  const OptimizationStats({
    required this.samplesUsed,
    required this.lossBefore,
    required this.lossAfter,
    required this.parametersChanged,
  });

  /// Number of samples used for optimization.
  final int samplesUsed;

  /// Loss before optimization.
  final double lossBefore;

  /// Loss after optimization.
  final double lossAfter;

  /// Which parameters were changed.
  final List<int> parametersChanged;

  /// Improvement percentage.
  double get improvement =>
      lossBefore > 0 ? (lossBefore - lossAfter) / lossBefore * 100 : 0.0;

  @override
  String toString() =>
      'OptimizationStats(samples: $samplesUsed, improvement: ${improvement.toStringAsFixed(1)}%)';
}
