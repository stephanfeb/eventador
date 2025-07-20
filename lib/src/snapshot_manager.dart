// Snapshot manager - Phase 2 Week 6 implementation
// Handles automatic snapshot creation, retention policies, and optimization

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'snapshot_config.dart';
import 'storage/event_store.dart';

/// Manages automatic snapshot creation and retention policies
class SnapshotManager {
  final EventStore _eventStore;
  final SnapshotConfig _config;
  final Map<String, SnapshotState> _actorStates = {};
  final Map<String, Timer> _timers = {};
  
  SnapshotStats _stats = const SnapshotStats();

  SnapshotManager({
    required EventStore eventStore,
    SnapshotConfig? config,
  }) : _eventStore = eventStore,
       _config = config ?? const SnapshotConfig();

  /// Current snapshot configuration
  SnapshotConfig get config => _config;

  /// Current snapshot statistics
  SnapshotStats get stats => _stats;

  /// Register an actor for snapshot management
  void registerActor(String persistenceId) {
    if (!_config.enabled) return;

    _actorStates[persistenceId] = SnapshotState(
      persistenceId: persistenceId,
      eventsSinceLastSnapshot: 0,
      lastSnapshotTime: null,
      lastEventTime: DateTime.now(),
    );

    // Start time-based snapshot timer if configured
    if (_config.timeThreshold != null) {
      _startSnapshotTimer(persistenceId);
    }
  }

  /// Unregister an actor from snapshot management
  void unregisterActor(String persistenceId) {
    _actorStates.remove(persistenceId);
    _timers[persistenceId]?.cancel();
    _timers.remove(persistenceId);
  }

  /// Notify that an event was persisted for an actor
  void onEventPersisted(String persistenceId) {
    if (!_config.enabled) return;

    final state = _actorStates[persistenceId];
    if (state == null) return;

    // Update event count and time
    final updatedState = state.copyWith(
      eventsSinceLastSnapshot: state.eventsSinceLastSnapshot + 1,
      lastEventTime: DateTime.now(),
    );
    _actorStates[persistenceId] = updatedState;

    // Check if snapshot should be created based on event count
    if (_config.shouldCreateSnapshotByEventCount(updatedState.eventsSinceLastSnapshot)) {
      _scheduleSnapshot(persistenceId, SnapshotTrigger.eventCount);
    }
  }

  /// Manually trigger a snapshot for an actor
  Future<bool> createSnapshot(String persistenceId, dynamic state) async {
    if (!_config.enabled) return false;

    final actorState = _actorStates[persistenceId];
    if (actorState == null) return false;

    // Check if enough time has passed since last snapshot
    if (!_config.canCreateSnapshotByTime(actorState.lastSnapshotTime)) {
      return false;
    }

    return await _performSnapshot(persistenceId, state, SnapshotTrigger.manual);
  }

  /// Check if a snapshot should be created for an actor
  bool shouldCreateSnapshot(String persistenceId) {
    if (!_config.enabled) return false;

    final state = _actorStates[persistenceId];
    if (state == null) return false;

    // Check event count threshold
    if (_config.shouldCreateSnapshotByEventCount(state.eventsSinceLastSnapshot)) {
      return true;
    }

    // Check time threshold - only if we have processed events and enough time has passed
    if (state.eventsSinceLastSnapshot > 0 && 
        _config.shouldCreateSnapshotByTime(state.lastSnapshotTime)) {
      return _config.canCreateSnapshotByTime(state.lastSnapshotTime);
    }

    return false;
  }

  /// Get snapshot information for an actor
  SnapshotState? getActorState(String persistenceId) {
    return _actorStates[persistenceId];
  }

  /// Clean up old snapshots for all actors
  Future<void> cleanupOldSnapshots() async {
    if (!_config.enabled || _config.maxSnapshotsToKeep <= 0) return;

    final futures = _actorStates.keys.map((persistenceId) async {
      try {
        await _eventStore.deleteOldSnapshots(persistenceId, _config.maxSnapshotsToKeep);
      } catch (e) {
        // Log error but continue with other actors
        print('Failed to cleanup snapshots for $persistenceId: $e');
      }
    });

    await Future.wait(futures);
  }

  /// Dispose of the snapshot manager and cleanup resources
  void dispose() {
    for (final timer in _timers.values) {
      timer.cancel();
    }
    _timers.clear();
    _actorStates.clear();
  }

  /// Start a timer for time-based snapshots
  void _startSnapshotTimer(String persistenceId) {
    final timeThreshold = _config.timeThreshold;
    if (timeThreshold == null) return;

    _timers[persistenceId]?.cancel();
    _timers[persistenceId] = Timer.periodic(timeThreshold, (timer) {
      _scheduleSnapshot(persistenceId, SnapshotTrigger.time);
    });
  }

  /// Schedule a snapshot creation
  void _scheduleSnapshot(String persistenceId, SnapshotTrigger trigger) {
    // Use a microtask to avoid blocking the current execution
    scheduleMicrotask(() async {
      try {
        await _triggerSnapshot(persistenceId, trigger);
      } catch (e) {
        print('Failed to create scheduled snapshot for $persistenceId: $e');
      }
    });
  }

  /// Trigger snapshot creation (to be implemented by subclasses or via callback)
  Future<void> _triggerSnapshot(String persistenceId, SnapshotTrigger trigger) async {
    // This is a placeholder - in practice, this would need to communicate
    // with the actual actor to get its current state
    // For now, we just update the trigger time
    final state = _actorStates[persistenceId];
    if (state != null) {
      _actorStates[persistenceId] = state.copyWith(
        lastSnapshotTrigger: trigger,
        lastSnapshotTriggerTime: DateTime.now(),
      );
    }
  }

  /// Perform the actual snapshot creation
  Future<bool> _performSnapshot(String persistenceId, dynamic state, SnapshotTrigger trigger) async {
    final stopwatch = Stopwatch()..start();
    
    try {
      // Get current sequence number
      final sequenceNumber = await _eventStore.getHighestSequenceNumber(persistenceId);
      
      // Create snapshot
      await _eventStore.saveSnapshot(persistenceId, state, sequenceNumber);
      
      stopwatch.stop();
      
      // Update actor state
      final actorState = _actorStates[persistenceId];
      if (actorState != null) {
        _actorStates[persistenceId] = actorState.copyWith(
          eventsSinceLastSnapshot: 0,
          lastSnapshotTime: DateTime.now(),
          lastSnapshotTrigger: trigger,
          lastSnapshotTriggerTime: DateTime.now(),
        );
      }
      
      // Update statistics
      final snapshotSize = _estimateSnapshotSize(state);
      _stats = _stats.addCreation(stopwatch.elapsed, snapshotSize);
      
      return true;
    } catch (e) {
      stopwatch.stop();
      print('Failed to create snapshot for $persistenceId: $e');
      return false;
    }
  }

  /// Estimate the size of a snapshot (rough approximation)
  int _estimateSnapshotSize(dynamic state) {
    if (state == null) return 0;
    
    // This is a rough estimation - in practice, you'd want to
    // serialize the state to get the actual size
    if (state is String) {
      return state.length * 2; // UTF-16 encoding
    } else if (state is List) {
      return state.length * 8; // Rough estimate
    } else if (state is Map) {
      return state.length * 16; // Rough estimate
    } else {
      return 100; // Default estimate
    }
  }
}

/// State tracking for an actor's snapshot management
class SnapshotState {
  final String persistenceId;
  final int eventsSinceLastSnapshot;
  final DateTime? lastSnapshotTime;
  final DateTime lastEventTime;
  final SnapshotTrigger? lastSnapshotTrigger;
  final DateTime? lastSnapshotTriggerTime;

  const SnapshotState({
    required this.persistenceId,
    required this.eventsSinceLastSnapshot,
    required this.lastSnapshotTime,
    required this.lastEventTime,
    this.lastSnapshotTrigger,
    this.lastSnapshotTriggerTime,
  });

  SnapshotState copyWith({
    int? eventsSinceLastSnapshot,
    DateTime? lastSnapshotTime,
    DateTime? lastEventTime,
    SnapshotTrigger? lastSnapshotTrigger,
    DateTime? lastSnapshotTriggerTime,
  }) {
    return SnapshotState(
      persistenceId: persistenceId,
      eventsSinceLastSnapshot: eventsSinceLastSnapshot ?? this.eventsSinceLastSnapshot,
      lastSnapshotTime: lastSnapshotTime ?? this.lastSnapshotTime,
      lastEventTime: lastEventTime ?? this.lastEventTime,
      lastSnapshotTrigger: lastSnapshotTrigger ?? this.lastSnapshotTrigger,
      lastSnapshotTriggerTime: lastSnapshotTriggerTime ?? this.lastSnapshotTriggerTime,
    );
  }

  @override
  String toString() {
    return 'SnapshotState('
        'persistenceId: $persistenceId, '
        'eventsSinceLastSnapshot: $eventsSinceLastSnapshot, '
        'lastSnapshotTime: $lastSnapshotTime, '
        'lastEventTime: $lastEventTime, '
        'lastSnapshotTrigger: $lastSnapshotTrigger'
        ')';
  }
}

/// Reasons why a snapshot was triggered
enum SnapshotTrigger {
  /// Triggered by event count threshold
  eventCount,
  
  /// Triggered by time threshold
  time,
  
  /// Manually triggered
  manual,
  
  /// Triggered during recovery optimization
  recovery,
}

/// Exception thrown when snapshot operations fail
class SnapshotException implements Exception {
  final String message;
  final dynamic cause;

  const SnapshotException(this.message, [this.cause]);

  @override
  String toString() {
    final causeStr = cause != null ? ' (caused by: $cause)' : '';
    return 'SnapshotException: $message$causeStr';
  }
}

/// Callback function type for snapshot creation
typedef SnapshotCreator = Future<dynamic> Function(String persistenceId);

/// Enhanced snapshot manager with callback support
class CallbackSnapshotManager extends SnapshotManager {
  final SnapshotCreator? _snapshotCreator;

  CallbackSnapshotManager({
    required EventStore eventStore,
    SnapshotConfig? config,
    SnapshotCreator? snapshotCreator,
  }) : _snapshotCreator = snapshotCreator,
       super(eventStore: eventStore, config: config);

  @override
  Future<void> _triggerSnapshot(String persistenceId, SnapshotTrigger trigger) async {
    if (_snapshotCreator == null) {
      await super._triggerSnapshot(persistenceId, trigger);
      return;
    }

    try {
      final state = await _snapshotCreator!(persistenceId);
      if (state != null) {
        await _performSnapshot(persistenceId, state, trigger);
      }
    } catch (e) {
      throw SnapshotException('Failed to create snapshot via callback for $persistenceId', e);
    }
  }
}
