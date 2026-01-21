/// Utility class for formatting intervals and durations for display.
///
/// Provides human-readable representations of time intervals.
class IntervalFormatter {
  /// Creates an interval formatter.
  const IntervalFormatter();

  /// Formats a duration in a compact form (e.g., "5m", "2d", "1mo").
  String format(Duration duration) {
    if (duration.isNegative) {
      return '-${format(-duration)}';
    }

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

  /// Formats a duration in a verbose form (e.g., "5 minutes", "2 days").
  String formatVerbose(Duration duration) {
    if (duration.isNegative) {
      return '-${formatVerbose(-duration)}';
    }

    if (duration.inDays >= 365) {
      final years = duration.inDays ~/ 365;
      return years == 1 ? '1 year' : '$years years';
    }

    if (duration.inDays >= 30) {
      final months = duration.inDays ~/ 30;
      return months == 1 ? '1 month' : '$months months';
    }

    if (duration.inDays >= 7) {
      final weeks = duration.inDays ~/ 7;
      return weeks == 1 ? '1 week' : '$weeks weeks';
    }

    if (duration.inDays >= 1) {
      return duration.inDays == 1 ? '1 day' : '${duration.inDays} days';
    }

    if (duration.inHours >= 1) {
      return duration.inHours == 1 ? '1 hour' : '${duration.inHours} hours';
    }

    if (duration.inMinutes >= 1) {
      return duration.inMinutes == 1
          ? '1 minute'
          : '${duration.inMinutes} minutes';
    }

    return duration.inSeconds == 1
        ? '1 second'
        : '${duration.inSeconds} seconds';
  }

  /// Formats a duration with mixed units (e.g., "2d 5h", "1h 30m").
  String formatMixed(Duration duration) {
    if (duration.isNegative) {
      return '-${formatMixed(-duration)}';
    }

    final parts = <String>[];

    var remaining = duration;

    if (remaining.inDays >= 365) {
      final years = remaining.inDays ~/ 365;
      parts.add('${years}y');
      remaining = Duration(days: remaining.inDays % 365);
    }

    if (remaining.inDays >= 30) {
      final months = remaining.inDays ~/ 30;
      parts.add('${months}mo');
      remaining = Duration(days: remaining.inDays % 30);
    }

    if (remaining.inDays >= 1) {
      parts.add('${remaining.inDays}d');
      remaining = Duration(
        hours: remaining.inHours % 24,
        minutes: remaining.inMinutes % 60,
        seconds: remaining.inSeconds % 60,
      );
    }

    if (remaining.inHours >= 1 && parts.length < 2) {
      parts.add('${remaining.inHours}h');
      remaining = Duration(
        minutes: remaining.inMinutes % 60,
        seconds: remaining.inSeconds % 60,
      );
    }

    if (remaining.inMinutes >= 1 && parts.length < 2) {
      parts.add('${remaining.inMinutes}m');
      remaining = Duration(seconds: remaining.inSeconds % 60);
    }

    if (remaining.inSeconds >= 1 && parts.length < 2) {
      parts.add('${remaining.inSeconds}s');
    }

    if (parts.isEmpty) {
      return '0s';
    }

    return parts.join(' ');
  }

  /// Formats a duration as a relative time (e.g., "in 2 days", "3 hours ago").
  String formatRelative(Duration duration) {
    if (duration.isNegative) {
      return '${formatVerbose(-duration)} ago';
    }
    if (duration == Duration.zero) {
      return 'now';
    }
    return 'in ${formatVerbose(duration)}';
  }

  /// Formats a DateTime as a relative time from now.
  String formatRelativeFromNow(DateTime dateTime) {
    final diff = dateTime.difference(DateTime.now());
    return formatRelative(diff);
  }

  /// Formats minutes as a readable duration.
  String formatMinutes(int minutes) {
    return format(Duration(minutes: minutes));
  }

  /// Formats minutes verbosely.
  String formatMinutesVerbose(int minutes) {
    return formatVerbose(Duration(minutes: minutes));
  }

  /// Converts a duration to approximate days (for display).
  String toDaysApproximate(Duration duration) {
    final days = duration.inMinutes / (24 * 60);
    if (days < 1) {
      return '< 1 day';
    }
    if (days < 2) {
      return '1 day';
    }
    return '${days.round()} days';
  }

  /// Gets a color-coded difficulty indicator based on interval.
  ///
  /// Returns a value 0.0 to 1.0 where:
  /// - 0.0 = very short interval (difficult/new)
  /// - 1.0 = very long interval (well-learned)
  double intervalDifficultyScore(Duration interval) {
    final days = interval.inMinutes / (24 * 60);

    if (days <= 0) return 0.0;
    if (days < 1) return 0.1;
    if (days < 7) return 0.3;
    if (days < 30) return 0.5;
    if (days < 90) return 0.7;
    if (days < 365) return 0.9;
    return 1.0;
  }
}

/// Default interval formatter instance for convenience.
const intervalFormatter = IntervalFormatter();

/// Extension on Duration for easy formatting.
extension DurationFormatting on Duration {
  /// Formats this duration in compact form.
  String toCompactString() => intervalFormatter.format(this);

  /// Formats this duration in verbose form.
  String toVerboseString() => intervalFormatter.formatVerbose(this);

  /// Formats this duration with mixed units.
  String toMixedString() => intervalFormatter.formatMixed(this);

  /// Formats this duration as relative time.
  String toRelativeString() => intervalFormatter.formatRelative(this);
}
