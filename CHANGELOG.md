# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2025-01-21

### Added

- **Core Models**
  - `ReviewCard` - Complete card state with phase tracking, statistics, and metadata support
  - `ReviewQuality` - Type-safe enum with Again, Hard, Good, Easy ratings
  - `SRSSettings` - 17+ fully configurable parameters (no dead code!)
  - `ReviewResult` - Immutable review outcome with transition metadata
  - `IntervalPreview` - Preview intervals for UI button display

- **Algorithms**
  - `SM2Algorithm` - Classic SuperMemo 2 implementation
  - `SM2PlusAlgorithm` - Enhanced SM-2 with overdue bonus calculation
  - `CustomAlgorithm` - Build your own with interval and ease callbacks
  - `SRSAlgorithm` - Abstract interface for custom implementations

- **Spaced Repetition Engine**
  - `SpacedRepetitionEngine` - Main API for card management
  - Card creation, review processing, batch operations
  - Card suspension, reset, and rescheduling
  - Due card filtering and priority sorting

- **Review Scheduler**
  - `ReviewScheduler` - Session management with configurable limits
  - `SchedulerConfig` - Configure new cards, reviews per session
  - Priority-based card ordering (overdue > learning > new)
  - Multiple scheduling modes (interleaved, new first, review first)

- **Statistics**
  - `CardStatistics` - Per-card metrics (success rate, stability, difficulty)
  - `DeckStatistics` - Aggregate deck analytics
  - `MasteryCalculator` - Mastery levels from Not Started to Expert
  - Streak tracking, retention analysis, workload estimation

- **Utilities**
  - `IntervalFormatter` - Human-readable interval formatting (1m, 10m, 1d, 7d)
  - `SRSValidator` - Input validation for all parameters
  - `SRSSerializer` - Full deck import/export support

- **Configuration Presets**
  - `SRSSettings.anki()` - Standard Anki defaults
  - `SRSSettings.supermemo()` - Original SuperMemo settings
  - `SRSSettings.aggressive()` - Faster learning curve
  - `SRSSettings.relaxed()` - Lower review burden

- **Documentation**
  - Comprehensive README with examples
  - Full API documentation
  - Working example application

### Technical Highlights

- Pure Dart - no dependencies, works everywhere (Flutter, CLI, server)
- 138+ unit and integration tests
- All settings are functional (fixed 9 dead code issues from original)
- Zero hardcoded algorithm values
- Full JSON serialization support
- Immutable card updates

### Credits

- Based on the SM-2 algorithm by Piotr Wozniak
- Inspired by Anki and SuperMemo
- Extracted and improved from the [Revisable app](https://github.com/makieali/revisable-app)
