// Command handler abstractions - Phase 2 Week 4 implementation
// Command handlers process commands and generate events

import 'package:meta/meta.dart';

import 'command.dart';
import 'event.dart';
import 'state.dart';

/// Base class for command handlers that process commands and generate events
/// Command handlers contain the business logic for processing commands
abstract class CommandHandler<TState extends State> {
  /// Handle a command and generate events
  /// Returns a list of events that should be persisted
  List<Event> handle(TState currentState, Command command);

  /// Check if this handler can handle the given command
  /// Override to provide custom command routing logic
  bool canHandle(Command command);

  /// Validate a command before handling
  /// Override to provide custom validation logic
  @protected
  bool validateCommand(TState currentState, Command command) {
    // Basic validation - check if command is valid
    if (command is ValidatableCommand) {
      return command.validate();
    }
    return true;
  }

  /// Get validation errors for a command
  /// Override to provide custom validation errors
  @protected
  List<String> getValidationErrors(TState currentState, Command command) {
    final errors = <String>[];
    
    if (command is ValidatableCommand) {
      errors.addAll(command.getValidationErrors());
    }
    
    // Add custom validation errors
    errors.addAll(getCustomValidationErrors(currentState, command));
    
    return errors;
  }

  /// Override in subclasses to provide custom validation errors
  @protected
  List<String> getCustomValidationErrors(TState currentState, Command command) => [];

  /// Check business rules before handling command
  /// Override to implement domain-specific business rules
  @protected
  bool checkBusinessRules(TState currentState, Command command) => true;

  /// Get business rule violations
  /// Override to provide specific business rule error messages
  @protected
  List<String> getBusinessRuleViolations(TState currentState, Command command) => [];

  /// Process a command with full validation and error handling
  /// This is the main entry point for command processing
  CommandResult<TState> process(TState currentState, Command command) {
    try {
      // Check if this handler can handle the command
      if (!canHandle(command)) {
        return CommandResult.failure(
          currentState,
          command,
          ['Command ${command.runtimeType} cannot be handled by ${runtimeType}'],
        );
      }

      // Validate the command
      if (!validateCommand(currentState, command)) {
        final errors = getValidationErrors(currentState, command);
        return CommandResult.failure(currentState, command, errors);
      }

      // Check business rules
      if (!checkBusinessRules(currentState, command)) {
        final violations = getBusinessRuleViolations(currentState, command);
        return CommandResult.failure(currentState, command, violations);
      }

      // Handle the command
      final events = handle(currentState, command);
      
      // Validate generated events
      for (final event in events) {
        if (event is ValidatableState && !event.isValid()) {
          return CommandResult.failure(
            currentState,
            command,
            ['Generated event ${event.runtimeType} is invalid'],
          );
        }
      }

      return CommandResult.success(currentState, command, events);
      
    } catch (e) {
      return CommandResult.error(currentState, command, e);
    }
  }
}

/// Specialized command handler for aggregate commands
abstract class AggregateCommandHandler<TState extends State> extends CommandHandler<TState> {
  /// The aggregate ID this handler is responsible for
  String get aggregateId;

  /// The aggregate type this handler manages
  String get aggregateType;

  @override
  bool canHandle(Command command) {
    // Check if command targets this aggregate
    if (command is TargetedCommand) {
      return command.aggregateId == aggregateId;
    }
    return false;
  }

  /// Check aggregate-specific business rules
  @override
  @protected
  bool checkBusinessRules(TState currentState, Command command) {
    // Check version conflicts for targeted commands
    if (command is TargetedCommand && command.expectedVersion != null) {
      if (currentState.version != command.expectedVersion) {
        return false;
      }
    }
    
    return checkAggregateRules(currentState, command);
  }

  /// Override to implement aggregate-specific business rules
  @protected
  bool checkAggregateRules(TState currentState, Command command) => true;

  @override
  @protected
  List<String> getBusinessRuleViolations(TState currentState, Command command) {
    final violations = <String>[];
    
    // Check version conflicts
    if (command is TargetedCommand && command.expectedVersion != null) {
      if (currentState.version != command.expectedVersion) {
        violations.add(
          'Version conflict: expected ${command.expectedVersion}, got ${currentState.version}',
        );
      }
    }
    
    violations.addAll(getAggregateRuleViolations(currentState, command));
    return violations;
  }

  /// Override to provide aggregate-specific rule violations
  @protected
  List<String> getAggregateRuleViolations(TState currentState, Command command) => [];
}

/// Registry for command handlers
class CommandHandlerRegistry<TState extends State> {
  final Map<Type, CommandHandler<TState>> _handlers = {};
  final Map<String, CommandHandler<TState>> _aggregateHandlers = {};

  /// Register a command handler for a specific command type
  void register<TCommand extends Command>(CommandHandler<TState> handler) {
    _handlers[TCommand] = handler;
  }

  /// Register an aggregate command handler
  void registerAggregate(AggregateCommandHandler<TState> handler) {
    _aggregateHandlers[handler.aggregateId] = handler;
  }

  /// Get a handler for a command
  CommandHandler<TState>? getHandler(Command command) {
    // First try to find by command type
    final handler = _handlers[command.runtimeType];
    if (handler != null && handler.canHandle(command)) {
      return handler;
    }

    // Then try aggregate handlers
    if (command is TargetedCommand) {
      final aggregateHandler = _aggregateHandlers[command.aggregateId];
      if (aggregateHandler != null && aggregateHandler.canHandle(command)) {
        return aggregateHandler;
      }
    }

    // Finally, search all handlers
    for (final h in _handlers.values) {
      if (h.canHandle(command)) {
        return h;
      }
    }

    return null;
  }

  /// Get all registered handlers
  List<CommandHandler<TState>> getAllHandlers() {
    return [..._handlers.values, ..._aggregateHandlers.values];
  }

  /// Clear all registered handlers (useful for testing)
  void clear() {
    _handlers.clear();
    _aggregateHandlers.clear();
  }
}

/// Result of command processing
class CommandResult<TState extends State> {
  final TState state;
  final Command command;
  final List<Event> events;
  final List<String> errors;
  final dynamic exception;
  final bool isSuccess;

  const CommandResult._({
    required this.state,
    required this.command,
    required this.events,
    required this.errors,
    required this.exception,
    required this.isSuccess,
  });

  /// Create a successful command result
  factory CommandResult.success(
    TState state,
    Command command,
    List<Event> events,
  ) {
    return CommandResult._(
      state: state,
      command: command,
      events: events,
      errors: [],
      exception: null,
      isSuccess: true,
    );
  }

  /// Create a failed command result
  factory CommandResult.failure(
    TState state,
    Command command,
    List<String> errors,
  ) {
    return CommandResult._(
      state: state,
      command: command,
      events: [],
      errors: errors,
      exception: null,
      isSuccess: false,
    );
  }

  /// Create an error command result
  factory CommandResult.error(
    TState state,
    Command command,
    dynamic exception,
  ) {
    return CommandResult._(
      state: state,
      command: command,
      events: [],
      errors: ['Command processing failed: $exception'],
      exception: exception,
      isSuccess: false,
    );
  }

  /// Whether the command processing failed
  bool get isFailure => !isSuccess;

  /// Whether the command processing had an exception
  bool get hasException => exception != null;

  @override
  String toString() {
    if (isSuccess) {
      return 'CommandResult.success(events: ${events.length})';
    } else {
      return 'CommandResult.failure(errors: ${errors.join(', ')})';
    }
  }
}

/// Exception thrown when no command handler is found
class NoCommandHandlerException implements Exception {
  final Command command;

  const NoCommandHandlerException(this.command);

  @override
  String toString() {
    return 'NoCommandHandlerException: No handler found for command ${command.runtimeType}';
  }
}

/// Exception thrown when command handling fails
class CommandHandlingException implements Exception {
  final Command command;
  final String message;
  final dynamic cause;

  const CommandHandlingException(this.command, this.message, [this.cause]);

  @override
  String toString() {
    final causeStr = cause != null ? ' (caused by: $cause)' : '';
    return 'CommandHandlingException for ${command.runtimeType}: $message$causeStr';
  }
}

/// Exception thrown when business rules are violated
class BusinessRuleViolationException implements Exception {
  final Command command;
  final List<String> violations;

  const BusinessRuleViolationException(this.command, this.violations);

  @override
  String toString() {
    return 'BusinessRuleViolationException for ${command.runtimeType}: ${violations.join(', ')}';
  }
}
