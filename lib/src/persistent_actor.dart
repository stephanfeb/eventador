// Core persistent actor framework - Phase 1 Week 2 implementation
// Extends Dactor's Actor class with persistence capabilities

import 'dart:async';
import 'package:dactor/dactor.dart';
import 'package:meta/meta.dart';

import 'command.dart';
import 'event.dart';
import 'snapshot_config.dart';
import 'snapshot_manager.dart';
import 'storage/event_store.dart';

/// Base class for persistent actors that survive system restarts
/// Extends Dactor's Actor class with persistence capabilities
abstract class PersistentActor extends Actor {
  final EventStore _eventStore;
  final String _persistenceId;
  final SnapshotManager? _snapshotManager;
  int _sequenceNumber = 0;
  bool _isRecovering = false;
  bool _isRecovered = false;

  /// Create a persistent actor with the given persistence ID and event store
  PersistentActor({
    required String persistenceId,
    required EventStore eventStore,
    SnapshotManager? snapshotManager,
  }) : _persistenceId = persistenceId,
       _eventStore = eventStore,
       _snapshotManager = snapshotManager,
       super() {
    // Validate persistence ID
    if (_persistenceId.isEmpty) {
      throw ArgumentError('Persistence ID cannot be empty');
    }
  }

  /// Unique identifier for this persistent actor
  /// Used to store and retrieve events from the event store
  String get persistenceId => _persistenceId;

  /// Current sequence number for this actor
  /// Incremented with each persisted event
  int get sequenceNumber => _sequenceNumber;

  /// Whether this actor is currently recovering from events
  bool get isRecovering => _isRecovering;

  /// Whether this actor has completed recovery
  bool get isRecovered => _isRecovered;

  /// Current event store instance
  @protected
  EventStore get eventStore => _eventStore;

  @override
  void preStart() {
    super.preStart();
    
    // Register with snapshot manager if available
    _snapshotManager?.registerActor(_persistenceId);
    
    // Start recovery process asynchronously
    _performRecovery();
  }

  @override
  void postStop() {
    super.postStop();
    
    // Unregister from snapshot manager if available
    _snapshotManager?.unregisterActor(_persistenceId);
  }

  /// Handle incoming messages with command/event routing
  @override
  Future<void> onMessage(dynamic message) async {
    if (!_isRecovered && !_isRecovering) {
      // Queue messages until recovery is complete
      await Future.delayed(Duration(milliseconds: 10));
      return onMessage(message);
    }

    if (_isRecovering) {
      // Drop messages during recovery
      return;
    }

    // Route messages based on type
    if (message is Command) {
      await _handleCommand(message);
    } else {
      // Handle regular actor messages - delegate to subclass
      await queryHandler(message);
    }
  }

  /// Handles incoming queries or other non-persistent messages.
  ///
  /// Override this method to handle messages that do not result in state
  /// changes, such as requests for the current state.
  @protected
  Future<void> queryHandler(dynamic message) async {
    // Default implementation - subclasses should override
  }

  /// Handles incoming commands and is responsible for validating them and
  /// generating events.
  ///
  /// This method should not modify the actor's state directly. Instead, it
  /// should call `persistEvent` to save the events that represent the
  /// desired state changes.
  @protected
  Future<void> commandHandler(Command command);

  /// Applies an event to the actor's state.
  ///
  /// This method is called during recovery to rebuild the actor's state from
  /// the event store, and after a new event has been persisted. It is
  /// crucial that this method does not have any side effects other than
  /// modifying the actor's in-memory state.
  @protected
  void eventHandler(Event event);

  /// Persist an event to the event store
  /// Events are immutable and stored permanently
  @protected
  Future<void> persistEvent(Event event) async {
    if (_isRecovering || !_isRecovered) {
      throw StateError('Cannot persist events during recovery or before recovery is complete');
    }

    try {
      // Persist to event store with expected version for optimistic concurrency
      await _eventStore.persistEvent(_persistenceId, event, _sequenceNumber);
      
      // Update sequence number
      _sequenceNumber++;
      
      // Apply event to update state
      eventHandler(event);
      
      // Notify snapshot manager of event persistence
      _snapshotManager?.onEventPersisted(_persistenceId);
      
      // Check if automatic snapshot should be created
      await _checkAndCreateSnapshot();
      
      // Call persistence lifecycle hook
      await onPersist(event);
      
    } catch (e) {
      // Handle persistence failures
      await onPersistFailure(event, e);
      rethrow;
    }
  }

  /// Persist multiple events atomically
  /// All events succeed or all fail together
  @protected
  Future<void> persistEvents(List<Event> events) async {
    if (_isRecovering) {
      throw StateError('Cannot persist events during recovery');
    }

    if (events.isEmpty) return;

    try {
      // Persist all events atomically
      await _eventStore.persistEvents(_persistenceId, events, _sequenceNumber);
      
      // Update sequence number
      _sequenceNumber += events.length;
      
      // Apply all events to update state
      for (final event in events) {
        eventHandler(event);
      }
      
      // Call persistence lifecycle hook
      await onPersistBatch(events);
      
    } catch (e) {
      // Handle persistence failures
      await onPersistBatchFailure(events, e);
      rethrow;
    }
  }

  /// Recover actor state by replaying events
  /// Called during actor initialization
  Future<void> _performRecovery() async {
    _isRecovering = true;
    
    try {
      // Call recovery start hook
      await onRecover();
      
      // Load snapshot if available
      final snapshot = await _eventStore.loadSnapshot(_persistenceId);
      int fromSequence = 0;
      
      if (snapshot != null) {
        // Restore from snapshot
        await onSnapshot(snapshot.state, snapshot.sequenceNumber);
        // Events after snapshot start from the next sequence
        // The snapshot.sequenceNumber represents the current sequence number when snapshot was taken
        // We need to replay events that come after this point
        fromSequence = snapshot.sequenceNumber;
        _sequenceNumber = snapshot.sequenceNumber;
      }
      
      // Replay events from snapshot point or beginning
      final events = await _eventStore.getEvents(_persistenceId, fromSequence: fromSequence);
      
      for (final event in events) {
        // Apply event during replay
        eventHandler(event);
        
        // Call replay hook
        await onReplay(event);
      }
      
      // Update sequence number to highest
      final highestSequence = await _eventStore.getHighestSequenceNumber(_persistenceId);
      _sequenceNumber = highestSequence;
      
      // Mark recovery as complete
      _isRecovered = true;
      
      // Call recovery complete hook
      await onRecoveryComplete();
      
    } catch (e) {
      // Handle recovery failures
      await onRecoveryFailure(e);
      rethrow;
    } finally {
      _isRecovering = false;
    }
  }

  /// Handle command processing with validation
  Future<void> _handleCommand(Command command) async {
    try {
      // Validate command if it supports validation
      if (command is ValidatableCommand) {
        if (!command.validate()) {
          final errors = command.getValidationErrors();
          throw CommandValidationException(command, errors);
        }
      }
      
      // Process the command
      await commandHandler(command);
      
    } catch (e) {
      // Handle command processing failures
      await onCommandFailure(command, e);
      rethrow;
    }
  }

  /// Create a snapshot of current state
  /// Override to provide custom snapshot logic
  @protected
  Future<void> createSnapshot() async {
    final state = await getSnapshotState();
    if (state != null) {
      await _eventStore.saveSnapshot(_persistenceId, state, _sequenceNumber);
      await onSnapshotCreated(state, _sequenceNumber);
    }
  }

  /// Check if automatic snapshot should be created and create it if needed
  Future<void> _checkAndCreateSnapshot() async {
    if (_snapshotManager == null) return;
    
    // Check if snapshot should be created based on policies
    if (_snapshotManager!.shouldCreateSnapshot(_persistenceId)) {
      try {
        final state = await getSnapshotState();
        if (state != null) {
          await _snapshotManager!.createSnapshot(_persistenceId, state);
        }
      } catch (e) {
        // Log error but don't fail the event persistence
        print('Failed to create automatic snapshot for ${_persistenceId}: $e');
      }
    }
  }

  // Lifecycle hooks - override in subclasses

  /// Called at the start of recovery process
  /// Override to perform custom recovery initialization
  @protected
  Future<void> onRecover() async {}

  /// Called for each event during replay
  /// Override to perform custom replay logic
  @protected
  Future<void> onReplay(Event event) async {}

  /// Called after successful event persistence
  /// Override to perform post-persistence actions
  @protected
  Future<void> onPersist(Event event) async {}

  /// Called after successful batch event persistence
  /// Override to perform post-persistence actions for batches
  @protected
  Future<void> onPersistBatch(List<Event> events) async {}

  /// Called when restoring from a snapshot
  /// Override to restore state from snapshot data
  @protected
  Future<void> onSnapshot(dynamic snapshotState, int sequenceNumber) async {}

  /// Called when recovery is complete
  /// Override to perform post-recovery initialization
  @protected
  Future<void> onRecoveryComplete() async {}

  /// Called when a snapshot is created
  /// Override to perform post-snapshot actions
  @protected
  Future<void> onSnapshotCreated(dynamic state, int sequenceNumber) async {}

  // Error handling hooks

  /// Called when event persistence fails
  /// Override to handle persistence failures
  @protected
  Future<void> onPersistFailure(Event event, dynamic error) async {
    // Default: log error (in production, use proper logging)
    print('Event persistence failed for ${_persistenceId}: $error');
  }

  /// Called when batch event persistence fails
  /// Override to handle batch persistence failures
  @protected
  Future<void> onPersistBatchFailure(List<Event> events, dynamic error) async {
    // Default: log error (in production, use proper logging)
    print('Batch event persistence failed for ${_persistenceId}: $error');
  }

  /// Called when command processing fails
  /// Override to handle command failures
  @protected
  Future<void> onCommandFailure(Command command, dynamic error) async {
    // Default: log error (in production, use proper logging)
    print('Command processing failed for ${_persistenceId}: $error');
  }

  /// Called when recovery fails
  /// Override to handle recovery failures
  @protected
  Future<void> onRecoveryFailure(dynamic error) async {
    // Default: log error (in production, use proper logging)
    print('Recovery failed for ${_persistenceId}: $error');
  }

  // Abstract methods for subclasses

  /// Get the current state for snapshot creation
  /// Return null if no snapshot should be created
  @protected
  Future<dynamic> getSnapshotState() async => null;
}

/// Exception thrown when persistence ID is invalid
class InvalidPersistenceIdException implements Exception {
  final String persistenceId;
  final String reason;

  const InvalidPersistenceIdException(this.persistenceId, this.reason);

  @override
  String toString() {
    return 'InvalidPersistenceIdException: $persistenceId - $reason';
  }
}
