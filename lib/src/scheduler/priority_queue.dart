import 'dart:collection';

import '../models/review_card.dart';

/// A priority queue for cards based on their due dates and phases.
///
/// Cards are ordered by priority:
/// 1. Overdue cards (most overdue first)
/// 2. Learning/relearning cards (due time)
/// 3. New cards
/// 4. Review cards (due time)
///
/// Example:
/// ```dart
/// final queue = CardPriorityQueue();
/// queue.addAll(cards);
///
/// while (queue.isNotEmpty) {
///   final card = queue.removeFirst();
///   // Review the card...
/// }
/// ```
class CardPriorityQueue {
  final SplayTreeSet<_PrioritizedCard> _queue;
  final Map<String, _PrioritizedCard> _cardMap;

  /// Creates an empty priority queue.
  CardPriorityQueue()
      : _queue = SplayTreeSet<_PrioritizedCard>(),
        _cardMap = {};

  /// Creates a priority queue with initial cards.
  factory CardPriorityQueue.from(Iterable<ReviewCard> cards) {
    final queue = CardPriorityQueue();
    queue.addAll(cards);
    return queue;
  }

  /// Number of cards in the queue.
  int get length => _queue.length;

  /// Whether the queue is empty.
  bool get isEmpty => _queue.isEmpty;

  /// Whether the queue has cards.
  bool get isNotEmpty => _queue.isNotEmpty;

  /// Adds a card to the queue.
  void add(ReviewCard card) {
    // Remove existing entry if present
    if (_cardMap.containsKey(card.id)) {
      _queue.remove(_cardMap[card.id]);
    }

    final prioritized = _PrioritizedCard(card);
    _queue.add(prioritized);
    _cardMap[card.id] = prioritized;
  }

  /// Adds multiple cards to the queue.
  void addAll(Iterable<ReviewCard> cards) {
    for (final card in cards) {
      add(card);
    }
  }

  /// Removes and returns the highest priority card.
  ///
  /// Throws [StateError] if the queue is empty.
  ReviewCard removeFirst() {
    if (_queue.isEmpty) {
      throw StateError('Cannot remove from empty queue');
    }

    final first = _queue.first;
    _queue.remove(first);
    _cardMap.remove(first.card.id);
    return first.card;
  }

  /// Returns the highest priority card without removing it.
  ///
  /// Returns null if the queue is empty.
  ReviewCard? peek() {
    if (_queue.isEmpty) return null;
    return _queue.first.card;
  }

  /// Removes a specific card from the queue.
  ///
  /// Returns true if the card was found and removed.
  bool remove(String cardId) {
    final prioritized = _cardMap.remove(cardId);
    if (prioritized != null) {
      _queue.remove(prioritized);
      return true;
    }
    return false;
  }

  /// Updates a card's position in the queue.
  ///
  /// Use this after reviewing a card to update its priority.
  void update(ReviewCard card) {
    add(card); // add handles removal of existing entry
  }

  /// Checks if a card is in the queue.
  bool contains(String cardId) => _cardMap.containsKey(cardId);

  /// Gets a card by ID from the queue.
  ReviewCard? getCard(String cardId) => _cardMap[cardId]?.card;

  /// Removes all cards from the queue.
  void clear() {
    _queue.clear();
    _cardMap.clear();
  }

  /// Returns cards in priority order as a list.
  List<ReviewCard> toList() {
    return _queue.map((p) => p.card).toList();
  }

  /// Returns only due cards in priority order.
  List<ReviewCard> getDueCards({DateTime? asOf}) {
    final now = asOf ?? DateTime.now();
    return _queue
        .where((p) =>
            now.isAfter(p.card.nextReviewTime) ||
            now.isAtSameMomentAs(p.card.nextReviewTime))
        .map((p) => p.card)
        .toList();
  }

  /// Takes the top N cards from the queue.
  List<ReviewCard> take(int count) {
    return _queue.take(count).map((p) => p.card).toList();
  }

  /// Removes and returns the top N cards from the queue.
  List<ReviewCard> removeN(int count) {
    final result = <ReviewCard>[];
    for (var i = 0; i < count && _queue.isNotEmpty; i++) {
      result.add(removeFirst());
    }
    return result;
  }
}

/// Internal wrapper for priority comparison.
class _PrioritizedCard implements Comparable<_PrioritizedCard> {
  final ReviewCard card;
  final int _priority;
  final int _tiebreaker;

  _PrioritizedCard(this.card)
      : _priority = _calculatePriority(card),
        _tiebreaker = card.id.hashCode;

  static int _calculatePriority(ReviewCard card) {
    final now = DateTime.now();
    final overdueMinutes = now.difference(card.nextReviewTime).inMinutes;

    // Base priority by phase (lower = higher priority)
    int basePriority;
    switch (card.phase) {
      case CardPhase.relearning:
        basePriority = 0;
      case CardPhase.learning:
        basePriority = 100000;
      case CardPhase.isNew:
        basePriority = 200000;
      case CardPhase.review:
        basePriority = 300000;
    }

    // Adjust by how overdue (more overdue = lower number = higher priority)
    // Overdue cards get negative adjustment, future cards get positive
    return basePriority - overdueMinutes;
  }

  @override
  int compareTo(_PrioritizedCard other) {
    final priorityCompare = _priority.compareTo(other._priority);
    if (priorityCompare != 0) return priorityCompare;

    // Use tiebreaker for consistent ordering
    return _tiebreaker.compareTo(other._tiebreaker);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _PrioritizedCard && card.id == other.card.id;

  @override
  int get hashCode => card.id.hashCode;
}
