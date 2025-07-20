// AggregateRoot implementation - Phase 2 Week 5 implementation
// Domain entity modeling patterns with event sourcing

import 'dart:async';
import 'package:meta/meta.dart';

import 'command.dart';
import 'command_handler.dart';
import 'event.dart';
import 'event_handler.dart';
import 'persistent_actor.dart';
import 'state.dart';
import 'storage/event_store.dart';

/// Base class for aggregate roots in domain-driven design
/// Combines PersistentActor with domain logic and command processing
abstract class AggregateRoot<TState extends State> extends PersistentActor {
  TState? _currentState;
  final CommandHandlerRegistry<TState> _commandHandlers;
  final EventHandlerRegistry<TState> _eventHandlers;
  final String _aggregateType;
  final String _aggregateId;

  /// Create an aggregate root with the specified aggregate ID and type
  AggregateRoot({
    required String aggregateId,
    required String aggregateType,
    required EventStore eventStore,
    CommandHandlerRegistry<TState>? commandHandlers,
    EventHandlerRegistry<TState>? eventHandlers,
  }) : _aggregateId = aggregateId,
       _aggregateType = aggregateType,
       _commandHandlers = commandHandlers ?? CommandHandlerRegistry<TState>(),
       _eventHandlers = eventHandlers ?? EventHandlerRegistry<TState>(),
       super(
         persistenceId: '${aggregateType}_$aggregateId',
         eventStore: eventStore,
       );

  /// The aggregate ID for this aggregate root
  String get aggregateId => _aggregateId;

  /// The aggregate type for this aggregate root
  String get aggregateType => _aggregateType;

  /// Current state of the aggregate
  /// Returns null if the aggregate hasn't been initialized yet
  TState? get state => _currentState;

  /// Current state of the aggregate (non-nullable)
  /// Throws if the aggregate hasn't been initialized
  TState get currentState {
    if (_currentState == null) {
      throw StateError('Aggregate $_aggregateId has not been initialized');
    }
    return _currentState!;
  }

  /// Whether the aggregate has been initialized with state
  bool get isInitialized => _currentState != null;

  /// Command handler registry for this aggregate
  @protected
  CommandHandlerRegistry<TState> get commandHandlers => _commandHandlers;

  /// Event handler registry for this aggregate
  @protected
  EventHandlerRegistry<TState> get eventHandlers => _eventHandlers;

  @override
  void preStart() {
    // Ensure handlers are registered before starting
    if (_commandHandlers.getAllHandlers().isEmpty || _eventHandlers.getAllHandlers().isEmpty) {
      registerHandlers();
    }
    super.preStart();
  }

  /// Register command and event handlers for this aggregate
  /// Override in subclasses to register domain-specific handlers
  @protected
  void registerHandlers();

  /// Create the initial state for this aggregate
  /// Override in subclasses to provide the initial state
  @protected
  TState createInitialState();

  /// Apply an event to the current state and return the new state
  /// This is the core method for event sourcing state transitions
  @protected
  TState applyEvent(TState currentState, Event event) {
    final handler = _eventHandlers.getHandler(event);
    if (handler == null) {
      throw NoEventHandlerException(event);
    }

    final result = handler.process(currentState, event);
    if (result.isFailure) {
      throw EventHandlingException(event, result.errors.join(', '));
    }

    return result.newState;
  }

  /// Handle a command and generate events
  /// This is the core method for command processing
  @protected
  List<Event> handleCommand(TState currentState, Command command) {
    final handler = _commandHandlers.getHandler(command);
    if (handler == null) {
      throw NoCommandHandlerException(command);
    }

    final result = handler.process(currentState, command);
    if (result.isFailure) {
      throw CommandHandlingException(command, result.errors.join(', '));
    }

    return result.events;
  }

  /// Process a command through the full pipeline
  /// This is the main entry point for command processing
  @override
  Future<void> commandHandler(Command command) async {
    try {
      // Ensure aggregate is initialized
      if (!isInitialized) {
        _currentState = createInitialState();
      }

      // Check optimistic concurrency control
      await _checkConcurrency(command);

      // Handle the command and generate events
      final events = handleCommand(currentState, command);

      // Persist all generated events
      if (events.isNotEmpty) {
        await persistEvents(events);
      }

      // Call command processing hook
      await onCommandProcessed(command, events);

    } catch (e) {
      await onCommandFailure(command, e);
      rethrow;
    }
  }

  /// Apply an event to update the aggregate state
  /// This is called during both command processing and recovery
  @override
  void eventHandler(Event event) {
    try {
      // Initialize state if needed
      if (!isInitialized) {
        _currentState = createInitialState();
      }

      // Apply the event to get new state
      final newState = applyEvent(currentState, event);

      // Update current state
      _currentState = newState;

      // Call event application hook
      onEventApplied(event, newState);

    } catch (e) {
      onEventApplicationFailure(event, e);
      rethrow;
    }
  }

  /// Replay events to rebuild aggregate state
  /// Used during recovery and testing
  void replay(List<Event> events) {
    // Reset to initial state
    _currentState = createInitialState();

    // Apply each event in sequence
    for (final event in events) {
      eventHandler(event);
    }
  }

  /// Check optimistic concurrency control for commands
  /// Throws if version conflicts are detected
  Future<void> _checkConcurrency(Command command) async {
    if (command is TargetedCommand && command.expectedVersion != null) {
      final expectedVersion = command.expectedVersion!;
      final currentVersion = isInitialized ? currentState.version : 0;

      if (currentVersion != expectedVersion) {
        throw OptimisticConcurrencyException(
          aggregateId: _aggregateId,
          expectedVersion: expectedVersion,
          actualVersion: currentVersion,
        );
      }
    }
  }

  /// Check optimistic concurrency control with expected version
  /// Public method for explicit concurrency checking
  Future<void> checkConcurrency(int expectedVersion) async {
    final currentVersion = isInitialized ? currentState.version : 0;

    if (currentVersion != expectedVersion) {
      throw OptimisticConcurrencyException(
        aggregateId: _aggregateId,
        expectedVersion: expectedVersion,
        actualVersion: currentVersion,
      );
    }
  }

  /// Get the current state for snapshot creation
  @override
  Future<dynamic> getSnapshotState() async {
    if (!isInitialized) {
      return null;
    }

    // Check if state supports snapshots
    if (currentState is SnapshotableState) {
      final snapshotableState = currentState as SnapshotableState;
      if (snapshotableState.shouldSnapshot) {
        return snapshotableState.createSnapshot();
      }
    }

    // Default: serialize state to map
    return currentState.toMap();
  }

  /// Restore state from snapshot during recovery
  @override
  Future<void> onSnapshot(dynamic snapshotState, int sequenceNumber) async {
    if (snapshotState == null) {
      _currentState = createInitialState();
      return;
    }

    try {
      // Try to restore from snapshot
      _currentState = await restoreFromSnapshot(snapshotState, sequenceNumber);
      
      // Call snapshot restoration hook
      await onSnapshotRestored(_currentState!, sequenceNumber);
      
    } catch (e) {
      // Fallback to initial state if snapshot restoration fails
      _currentState = createInitialState();
      await onSnapshotRestorationFailure(snapshotState, sequenceNumber, e);
    }
  }

  /// Restore state from snapshot data
  /// Override in subclasses to provide custom restoration logic
  @protected
  Future<TState> restoreFromSnapshot(dynamic snapshotData, int sequenceNumber) async {
    if (snapshotData is Map<String, dynamic>) {
      // Try to restore using state registry or custom logic
      return await restoreStateFromMap(snapshotData, sequenceNumber);
    }

    throw ArgumentError('Unsupported snapshot data type: ${snapshotData.runtimeType}');
  }

  /// Restore state from a map representation
  /// Override in subclasses to provide custom map restoration
  @protected
  Future<TState> restoreStateFromMap(Map<String, dynamic> map, int sequenceNumber) async {
    // Default implementation - subclasses should override
    throw UnimplementedError('restoreStateFromMap must be implemented by subclasses');
  }

  /// Validate business rules for the current state
  /// Override in subclasses to implement domain-specific validation
  @protected
  bool validateBusinessRules(TState state) => true;

  /// Get business rule violations for the current state
  /// Override in subclasses to provide specific violation messages
  @protected
  List<String> getBusinessRuleViolations(TState state) => [];

  /// Check if the aggregate can handle a specific command
  /// Override in subclasses for custom command routing
  @protected
  bool canHandleCommand(Command command) {
    return _commandHandlers.getHandler(command) != null;
  }

  /// Check if the aggregate can apply a specific event
  /// Override in subclasses for custom event routing
  @protected
  bool canApplyEvent(Event event) {
    return _eventHandlers.getHandler(event) != null;
  }

  // Lifecycle hooks - override in subclasses

  /// Called after a command has been successfully processed
  /// Override to perform post-command processing actions
  @protected
  Future<void> onCommandProcessed(Command command, List<Event> events) async {}

  /// Called after an event has been applied to the state
  /// Override to perform post-event application actions
  @protected
  void onEventApplied(Event event, TState newState) {}

  /// Called after state has been restored from a snapshot
  /// Override to perform post-snapshot restoration actions
  @protected
  Future<void> onSnapshotRestored(TState state, int sequenceNumber) async {}

  /// Called when snapshot restoration fails
  /// Override to handle snapshot restoration failures
  @protected
  Future<void> onSnapshotRestorationFailure(
    dynamic snapshotData,
    int sequenceNumber,
    dynamic error,
  ) async {
    print('Snapshot restoration failed for aggregate $_aggregateId: $error');
  }

  /// Called when event application fails
  /// Override to handle event application failures
  @protected
  void onEventApplicationFailure(Event event, dynamic error) {
    print('Event application failed for aggregate $_aggregateId: $error');
  }

  /// Get aggregate information for debugging and monitoring
  AggregateInfo getAggregateInfo() {
    return AggregateInfo(
      aggregateId: _aggregateId,
      aggregateType: _aggregateType,
      persistenceId: persistenceId,
      isInitialized: isInitialized,
      currentVersion: isInitialized ? currentState.version : 0,
      sequenceNumber: sequenceNumber,
      isRecovered: isRecovered,
      registeredCommandHandlers: _commandHandlers.getAllHandlers().length,
      registeredEventHandlers: _eventHandlers.getAllHandlers().length,
    );
  }

  @override
  String toString() {
    return 'AggregateRoot(type: $_aggregateType, id: $_aggregateId, version: ${isInitialized ? currentState.version : 0})';
  }
}

/// Information about an aggregate root for debugging and monitoring
class AggregateInfo {
  final String aggregateId;
  final String aggregateType;
  final String persistenceId;
  final bool isInitialized;
  final int currentVersion;
  final int sequenceNumber;
  final bool isRecovered;
  final int registeredCommandHandlers;
  final int registeredEventHandlers;

  const AggregateInfo({
    required this.aggregateId,
    required this.aggregateType,
    required this.persistenceId,
    required this.isInitialized,
    required this.currentVersion,
    required this.sequenceNumber,
    required this.isRecovered,
    required this.registeredCommandHandlers,
    required this.registeredEventHandlers,
  });

  @override
  String toString() {
    return 'AggregateInfo(id: $aggregateId, type: $aggregateType, version: $currentVersion, initialized: $isInitialized, recovered: $isRecovered)';
  }
}

/// Exception thrown when optimistic concurrency control fails
class OptimisticConcurrencyException implements Exception {
  final String aggregateId;
  final int expectedVersion;
  final int actualVersion;

  const OptimisticConcurrencyException({
    required this.aggregateId,
    required this.expectedVersion,
    required this.actualVersion,
  });

  @override
  String toString() {
    return 'OptimisticConcurrencyException for aggregate $aggregateId: expected version $expectedVersion, actual version $actualVersion';
  }
}

/// Exception thrown when aggregate is not initialized
class AggregateNotInitializedException implements Exception {
  final String aggregateId;
  final String aggregateType;

  const AggregateNotInitializedException({
    required this.aggregateId,
    required this.aggregateType,
  });

  @override
  String toString() {
    return 'AggregateNotInitializedException: Aggregate $aggregateType($aggregateId) has not been initialized';
  }
}

/// Exception thrown when business rules are violated
class AggregateBusinessRuleViolationException implements Exception {
  final String aggregateId;
  final String aggregateType;
  final List<String> violations;

  const AggregateBusinessRuleViolationException({
    required this.aggregateId,
    required this.aggregateType,
    required this.violations,
  });

  @override
  String toString() {
    return 'AggregateBusinessRuleViolationException for $aggregateType($aggregateId): ${violations.join(', ')}';
  }
}

/// Base class for aggregate-specific commands
abstract class AggregateCommand extends Command with TargetedCommand {
  final String _aggregateId;
  final String _aggregateType;
  final int? _expectedVersion;

  AggregateCommand({
    required String aggregateId,
    required String aggregateType,
    int? expectedVersion,
    String? commandId,
    DateTime? timestamp,
    Map<String, dynamic>? metadata,
  }) : _aggregateId = aggregateId,
       _aggregateType = aggregateType,
       _expectedVersion = expectedVersion,
       super(
         commandId: commandId,
         timestamp: timestamp,
         metadata: metadata,
       );

  @override
  String get aggregateId => _aggregateId;

  /// The type of aggregate this command targets
  String get aggregateType => _aggregateType;

  @override
  int? get expectedVersion => _expectedVersion;

  @override
  Map<String, dynamic> toMap() {
    final map = super.toMap();
    map['aggregateType'] = _aggregateType;
    return map;
  }
}

/// Base class for aggregate-specific events
abstract class AggregateEventBase extends Event with AggregateEvent {
  final String _aggregateId;
  final String _aggregateType;

  AggregateEventBase({
    required String aggregateId,
    required String aggregateType,
    String? eventId,
    DateTime? timestamp,
    int? version,
    Map<String, dynamic>? metadata,
  }) : _aggregateId = aggregateId,
       _aggregateType = aggregateType,
       super(
         eventId: eventId,
         timestamp: timestamp,
         version: version,
         metadata: metadata,
       );

  @override
  String get aggregateId => _aggregateId;

  @override
  String get aggregateType => _aggregateType;
}

/// Registry for aggregate types and their factory functions
class AggregateRegistry {
  static final Map<String, AggregateRoot Function(String, EventStore)> _registry = {};

  /// Register an aggregate type with its factory function
  static void register<T extends AggregateRoot>(
    String aggregateType,
    T Function(String aggregateId, EventStore eventStore) factory,
  ) {
    _registry[aggregateType] = factory;
  }

  /// Create an aggregate instance
  static AggregateRoot? create(
    String aggregateType,
    String aggregateId,
    EventStore eventStore,
  ) {
    final factory = _registry[aggregateType];
    if (factory == null) {
      return null;
    }

    return factory(aggregateId, eventStore);
  }

  /// Get all registered aggregate types
  static List<String> getRegisteredTypes() {
    return _registry.keys.toList();
  }

  /// Check if an aggregate type is registered
  static bool isRegistered(String aggregateType) {
    return _registry.containsKey(aggregateType);
  }

  /// Clear all registered aggregate types (useful for testing)
  static void clear() {
    _registry.clear();
  }
}
