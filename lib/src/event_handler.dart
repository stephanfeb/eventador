// Event handler abstractions - Phase 2 Week 4 implementation
// Event handlers apply events to update state

import 'package:meta/meta.dart';

import 'event.dart';
import 'state.dart';

/// Base class for event handlers that apply events to update state
/// Event handlers contain the logic for applying events to state
abstract class EventHandler<TState extends State> {
  /// Apply an event to the current state and return the new state
  /// This is the core method that updates state based on events
  TState apply(TState currentState, Event event);

  /// Check if this handler can apply the given event
  /// Override to provide custom event routing logic
  bool canApply(Event event);

  /// Validate an event before applying
  /// Override to provide custom validation logic
  @protected
  bool validateEvent(TState currentState, Event event) {
    // Basic validation - check if event is valid
    if (event is ValidatableState) {
      return event.isValid();
    }
    return true;
  }

  /// Get validation errors for an event
  /// Override to provide custom validation errors
  @protected
  List<String> getValidationErrors(TState currentState, Event event) {
    final errors = <String>[];
    
    if (event is ValidatableState) {
      errors.addAll(event.getValidationErrors());
    }
    
    // Add custom validation errors
    errors.addAll(getCustomValidationErrors(currentState, event));
    
    return errors;
  }

  /// Override in subclasses to provide custom validation errors
  @protected
  List<String> getCustomValidationErrors(TState currentState, Event event) => [];

  /// Check business invariants after applying event
  /// Override to implement domain-specific invariants
  @protected
  bool checkInvariants(TState newState, Event event) => true;

  /// Get invariant violations
  /// Override to provide specific invariant violation messages
  @protected
  List<String> getInvariantViolations(TState newState, Event event) => [];

  /// Apply an event with full validation and error handling
  /// This is the main entry point for event application
  EventResult<TState> process(TState currentState, Event event) {
    try {
      // Check if this handler can apply the event
      if (!canApply(event)) {
        return EventResult.failure(
          currentState,
          event,
          ['Event ${event.runtimeType} cannot be applied by ${runtimeType}'],
        );
      }

      // Validate the event
      if (!validateEvent(currentState, event)) {
        final errors = getValidationErrors(currentState, event);
        return EventResult.failure(currentState, event, errors);
      }

      // Apply the event
      final newState = apply(currentState, event);
      
      // Check invariants
      if (!checkInvariants(newState, event)) {
        final violations = getInvariantViolations(newState, event);
        return EventResult.failure(currentState, event, violations);
      }

      return EventResult.success(currentState, newState, event);
      
    } catch (e) {
      return EventResult.error(currentState, event, e);
    }
  }
}

/// Specialized event handler for aggregate events
abstract class AggregateEventHandler<TState extends State> extends EventHandler<TState> {
  /// The aggregate type this handler manages
  String get aggregateType;

  @override
  bool canApply(Event event) {
    // Check if event belongs to this aggregate type
    if (event is AggregateEvent) {
      return event.aggregateType == aggregateType;
    }
    return false;
  }

  /// Check aggregate-specific invariants
  @override
  @protected
  bool checkInvariants(TState newState, Event event) {
    // Check version consistency for aggregate events
    if (event is AggregateEvent && newState.version < event.version) {
      // State version should be at least the event version
      return false;
    }
    
    return checkAggregateInvariants(newState, event);
  }

  /// Override to implement aggregate-specific invariants
  @protected
  bool checkAggregateInvariants(TState newState, Event event) => true;

  @override
  @protected
  List<String> getInvariantViolations(TState newState, Event event) {
    final violations = <String>[];
    
    // Check version consistency
    if (event is AggregateEvent && newState.version < event.version) {
      violations.add(
        'State version not updated: state v${newState.version}, event v${event.version}',
      );
    }
    
    violations.addAll(getAggregateInvariantViolations(newState, event));
    return violations;
  }

  /// Override to provide aggregate-specific invariant violations
  @protected
  List<String> getAggregateInvariantViolations(TState newState, Event event) => [];
}

/// Composite event handler that delegates to multiple handlers
class CompositeEventHandler<TState extends State> extends EventHandler<TState> {
  final List<EventHandler<TState>> _handlers;

  CompositeEventHandler(this._handlers);

  @override
  TState apply(TState currentState, Event event) {
    // Find the first handler that can apply the event
    for (final handler in _handlers) {
      if (handler.canApply(event)) {
        return handler.apply(currentState, event);
      }
    }
    
    throw NoEventHandlerException(event);
  }

  @override
  bool canApply(Event event) {
    return _handlers.any((handler) => handler.canApply(event));
  }

  /// Add a handler to the composite
  void addHandler(EventHandler<TState> handler) {
    _handlers.add(handler);
  }

  /// Remove a handler from the composite
  void removeHandler(EventHandler<TState> handler) {
    _handlers.remove(handler);
  }

  /// Get all handlers
  List<EventHandler<TState>> get handlers => List.unmodifiable(_handlers);
}

/// Registry for event handlers
class EventHandlerRegistry<TState extends State> {
  final Map<Type, EventHandler<TState>> _handlers = {};
  final Map<String, EventHandler<TState>> _aggregateHandlers = {};

  /// Register an event handler for a specific event type
  void register<TEvent extends Event>(EventHandler<TState> handler) {
    _handlers[TEvent] = handler;
  }

  /// Register an aggregate event handler
  void registerAggregate(AggregateEventHandler<TState> handler) {
    _aggregateHandlers[handler.aggregateType] = handler;
  }

  /// Get a handler for an event
  EventHandler<TState>? getHandler(Event event) {
    // First try to find by event type
    final handler = _handlers[event.runtimeType];
    if (handler != null && handler.canApply(event)) {
      return handler;
    }

    // Then try aggregate handlers
    if (event is AggregateEvent) {
      final aggregateHandler = _aggregateHandlers[event.aggregateType];
      if (aggregateHandler != null && aggregateHandler.canApply(event)) {
        return aggregateHandler;
      }
    }

    // Finally, search all handlers
    for (final h in _handlers.values) {
      if (h.canApply(event)) {
        return h;
      }
    }

    return null;
  }

  /// Get all registered handlers
  List<EventHandler<TState>> getAllHandlers() {
    return [..._handlers.values, ..._aggregateHandlers.values];
  }

  /// Create a composite handler from all registered handlers
  CompositeEventHandler<TState> createComposite() {
    return CompositeEventHandler<TState>(getAllHandlers());
  }

  /// Clear all registered handlers (useful for testing)
  void clear() {
    _handlers.clear();
    _aggregateHandlers.clear();
  }
}

/// Result of event application
class EventResult<TState extends State> {
  final TState oldState;
  final TState newState;
  final Event event;
  final List<String> errors;
  final dynamic exception;
  final bool isSuccess;

  const EventResult._({
    required this.oldState,
    required this.newState,
    required this.event,
    required this.errors,
    required this.exception,
    required this.isSuccess,
  });

  /// Create a successful event result
  factory EventResult.success(
    TState oldState,
    TState newState,
    Event event,
  ) {
    return EventResult._(
      oldState: oldState,
      newState: newState,
      event: event,
      errors: [],
      exception: null,
      isSuccess: true,
    );
  }

  /// Create a failed event result
  factory EventResult.failure(
    TState state,
    Event event,
    List<String> errors,
  ) {
    return EventResult._(
      oldState: state,
      newState: state,
      event: event,
      errors: errors,
      exception: null,
      isSuccess: false,
    );
  }

  /// Create an error event result
  factory EventResult.error(
    TState state,
    Event event,
    dynamic exception,
  ) {
    return EventResult._(
      oldState: state,
      newState: state,
      event: event,
      errors: ['Event application failed: $exception'],
      exception: exception,
      isSuccess: false,
    );
  }

  /// Whether the event application failed
  bool get isFailure => !isSuccess;

  /// Whether the event application had an exception
  bool get hasException => exception != null;

  /// Whether the state changed
  bool get stateChanged => oldState != newState;

  @override
  String toString() {
    if (isSuccess) {
      return 'EventResult.success(stateChanged: $stateChanged)';
    } else {
      return 'EventResult.failure(errors: ${errors.join(', ')})';
    }
  }
}

/// Event application pipeline for processing multiple events
class EventApplicationPipeline<TState extends State> {
  final EventHandlerRegistry<TState> _registry;

  EventApplicationPipeline(this._registry);

  /// Apply a list of events to a state in sequence
  EventPipelineResult<TState> applyEvents(TState initialState, List<Event> events) {
    TState currentState = initialState;
    final results = <EventResult<TState>>[];
    final errors = <String>[];

    for (final event in events) {
      final handler = _registry.getHandler(event);
      if (handler == null) {
        final error = 'No handler found for event ${event.runtimeType}';
        errors.add(error);
        results.add(EventResult.failure(currentState, event, [error]));
        continue;
      }

      final result = handler.process(currentState, event);
      results.add(result);

      if (result.isSuccess) {
        currentState = result.newState;
      } else {
        errors.addAll(result.errors);
      }
    }

    return EventPipelineResult(
      initialState: initialState,
      finalState: currentState,
      events: events,
      results: results,
      errors: errors,
    );
  }
}

/// Result of applying multiple events through a pipeline
class EventPipelineResult<TState extends State> {
  final TState initialState;
  final TState finalState;
  final List<Event> events;
  final List<EventResult<TState>> results;
  final List<String> errors;

  const EventPipelineResult({
    required this.initialState,
    required this.finalState,
    required this.events,
    required this.results,
    required this.errors,
  });

  /// Whether all events were applied successfully
  bool get isSuccess => errors.isEmpty;

  /// Whether any events failed to apply
  bool get hasFailures => errors.isNotEmpty;

  /// Whether the state changed from initial to final
  bool get stateChanged => initialState != finalState;

  /// Number of events successfully applied
  int get successCount => results.where((r) => r.isSuccess).length;

  /// Number of events that failed to apply
  int get failureCount => results.where((r) => r.isFailure).length;

  @override
  String toString() {
    return 'EventPipelineResult(success: $successCount, failures: $failureCount, stateChanged: $stateChanged)';
  }
}

/// Exception thrown when no event handler is found
class NoEventHandlerException implements Exception {
  final Event event;

  const NoEventHandlerException(this.event);

  @override
  String toString() {
    return 'NoEventHandlerException: No handler found for event ${event.runtimeType}';
  }
}

/// Exception thrown when event handling fails
class EventHandlingException implements Exception {
  final Event event;
  final String message;
  final dynamic cause;

  const EventHandlingException(this.event, this.message, [this.cause]);

  @override
  String toString() {
    final causeStr = cause != null ? ' (caused by: $cause)' : '';
    return 'EventHandlingException for ${event.runtimeType}: $message$causeStr';
  }
}

/// Exception thrown when invariants are violated
class InvariantViolationException implements Exception {
  final Event event;
  final List<String> violations;

  const InvariantViolationException(this.event, this.violations);

  @override
  String toString() {
    return 'InvariantViolationException for ${event.runtimeType}: ${violations.join(', ')}';
  }
}
