// Command abstractions - Phase 1 Week 2 implementation
// Commands represent intent to change state

import 'dart:convert';
import 'package:cbor/cbor.dart';
import 'package:dactor/dactor.dart';
import 'package:dactor/src/local_message.dart';
import 'package:meta/meta.dart';

/// Base class for all commands in the event sourcing system
/// Commands represent requests to change state and are processed by persistent actors
/// Extends LocalMessage to ensure compatibility with Dactor's ask() method
abstract class Command extends LocalMessage {
  final String _commandId;

  /// Create a command with optional ID, timestamp, and metadata
  Command({
    String? commandId,
    DateTime? timestamp,
    Map<String, dynamic>? metadata,
    ActorRef? replyTo,
    ActorRef? sender,
  }) : _commandId = commandId ?? _generateCommandId(),
       super(
         payload: null, // Will be set by subclasses via getter
         sender: sender,
         correlationId: commandId ?? _generateCommandId(),
         replyTo: replyTo ?? metadata?['replyTo'] as ActorRef?,
         timestamp: timestamp ?? DateTime.now(),
         metadata: Map<String, dynamic>.from(metadata ?? {}),
       );

  /// Unique identifier for this command
  /// Used for deduplication and tracing
  String get commandId => _commandId;

  /// Override payload to return the command itself for LocalMessage compatibility
  @override
  dynamic get payload => this;

  /// Generate a unique command ID
  static String _generateCommandId() {
    final now = DateTime.now();
    final timestamp = now.millisecondsSinceEpoch;
    final random = (timestamp % 10000).toString().padLeft(4, '0');
    return 'cmd_${timestamp}_$random';
  }

  /// Convert command to a map for serialization
  /// Override in subclasses to include command-specific data
  @protected
  Map<String, dynamic> toMap() {
    return {
      'commandId': _commandId,
      'timestamp': timestamp.toIso8601String(),
      'metadata': metadata,
      'type': runtimeType.toString(),
    };
  }

  /// Serialize command to CBOR bytes
  List<int> toCbor() {
    final map = toMap();
    final cborMap = CborMap(map.map((key, value) => MapEntry(CborString(key), _toCborValue(value))));
    return cborEncode(cborMap);
  }

  /// Convert a Dart value to CBOR value
  static CborValue _toCborValue(dynamic value) {
    if (value == null) return CborNull();
    if (value is String) return CborString(value);
    if (value is int) return CborSmallInt(value);
    if (value is double) return CborFloat(value);
    if (value is bool) return CborBool(value);
    if (value is List) return CborList(value.map(_toCborValue).toList());
    if (value is Map) {
      return CborMap(value.map((k, v) => MapEntry(_toCborValue(k), _toCborValue(v))));
    }
    return CborString(value.toString());
  }

  /// Convert CBOR value to Dart value
  static dynamic _fromCborValue(CborValue value) {
    if (value is CborNull) return null;
    if (value is CborString) return value.toString();
    if (value is CborSmallInt) return value.value;
    if (value is CborFloat) return value.value;
    if (value is CborBool) return value.value;
    if (value is CborList) return value.map(_fromCborValue).toList();
    if (value is CborMap) {
      return value.map((k, v) => MapEntry(_fromCborValue(k), _fromCborValue(v)));
    }
    return value.toString();
  }

  /// Create command from CBOR bytes
  /// Subclasses must implement their own fromCbor methods
  static Command fromCbor(List<int> bytes) {
    final decoded = cborDecode(bytes);
    if (decoded is! CborMap) {
      throw ArgumentError('Invalid CBOR data for Command');
    }
    
    final map = Map<String, dynamic>.from(_fromCborValue(decoded) as Map);
    final type = map['type'] as String?;
    
    if (type == null) {
      throw ArgumentError('Command type not found in CBOR data');
    }
    
    // This is a factory method - concrete implementations should register
    // their fromCbor methods in a command registry
    throw UnimplementedError('Command type $type not registered');
  }

  /// Validate the command
  /// Override in subclasses for custom validation
  @protected
  bool isValid() => true;

  /// Get validation errors
  /// Override in subclasses to provide specific error messages
  @protected
  List<String> getValidationErrors() => [];

  @override
  String toString() {
    return '${runtimeType}(id: $_commandId, timestamp: $timestamp)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Command && other._commandId == _commandId;
  }

  @override
  int get hashCode => _commandId.hashCode;
}

/// Mixin for commands that can be validated
mixin ValidatableCommand on Command {
  /// Validate the command before processing
  /// Returns true if valid, false otherwise
  @override
  bool validate() {
    return isValid();
  }

  /// Get validation errors if any
  @override
  List<String> getValidationErrors() {
    final errors = <String>[];
    
    // Basic validation
    if (commandId.isEmpty) {
      errors.add('Command ID cannot be empty');
    }
    
    if (timestamp.isAfter(DateTime.now().add(Duration(minutes: 5)))) {
      errors.add('Command timestamp cannot be in the future');
    }
    
    // Add custom validation errors
    errors.addAll(getCustomValidationErrors());
    
    return errors;
  }

  /// Override in subclasses to provide custom validation errors
  @protected
  List<String> getCustomValidationErrors() => [];

  /// Override in subclasses to provide custom validation logic
  @protected
  @override
  bool isValid() {
    return getValidationErrors().isEmpty;
  }
}

/// Mixin for commands that have a target aggregate
mixin TargetedCommand on Command {
  /// The ID of the aggregate this command targets
  String get aggregateId;

  /// The expected version of the aggregate (for optimistic concurrency)
  int? get expectedVersion => null;

  @override
  Map<String, dynamic> toMap() {
    final map = super.toMap();
    map['aggregateId'] = aggregateId;
    if (expectedVersion != null) {
      map['expectedVersion'] = expectedVersion;
    }
    return map;
  }

  @override
  List<String> getValidationErrors() {
    final errors = super.getValidationErrors();
    
    if (aggregateId.isEmpty) {
      errors.add('Aggregate ID cannot be empty');
    }
    
    if (expectedVersion != null && expectedVersion! < 0) {
      errors.add('Expected version cannot be negative');
    }
    
    return errors;
  }
}

/// Mixin for commands that can be retried
mixin RetryableCommand on Command {
  /// Maximum number of retry attempts
  int get maxRetries => 3;

  /// Current retry attempt (0 = first attempt)
  int get retryAttempt => metadata['retryAttempt'] as int? ?? 0;

  /// Whether this command can be retried
  bool get canRetry => retryAttempt < maxRetries;

  /// Create a new command for retry with incremented attempt count
  Command withRetry() {
    final newMetadata = Map<String, dynamic>.from(metadata);
    newMetadata['retryAttempt'] = retryAttempt + 1;
    newMetadata['originalCommandId'] = commandId;
    
    return _createRetryCommand(newMetadata);
  }

  /// Override in subclasses to create retry command
  @protected
  Command _createRetryCommand(Map<String, dynamic> metadata);
}

/// Mixin for commands that have correlation tracking
mixin CorrelatedCommand on Command {
  /// Correlation ID for tracking related commands/events
  @override
  String get correlationId => metadata['correlationId'] as String? ?? commandId;

  /// Causation ID - the ID of the event/command that caused this command
  String? get causationId => metadata['causationId'] as String?;

  /// User context information
  String? get userId => metadata['userId'] as String?;

  /// Session context information
  String? get sessionId => metadata['sessionId'] as String?;

  /// Set correlation tracking information
  /// Note: Since LocalMessage metadata is immutable, this creates a new command instance
  /// with updated correlation information. Override in concrete command classes.
  void setCorrelation({
    String? correlationId,
    String? causationId,
    String? userId,
    String? sessionId,
  }) {
    // Since LocalMessage metadata is immutable, we need to handle this differently
    // in concrete command implementations. This method serves as documentation
    // for the expected interface.
    throw UnimplementedError(
      'setCorrelation must be implemented in concrete command classes '
      'due to LocalMessage immutability constraints'
    );
  }
}

/// Registry for command types and their deserialization functions
class CommandRegistry {
  static final Map<String, Command Function(Map<String, dynamic>)> _registry = {};

  /// Register a command type with its deserialization function
  static void register<T extends Command>(
    String typeName,
    T Function(Map<String, dynamic>) fromMap,
  ) {
    _registry[typeName] = fromMap;
  }

  /// Create a command from a map using the registry
  static Command fromMap(Map<String, dynamic> map) {
    final type = map['type'] as String?;
    if (type == null) {
      throw ArgumentError('Command type not found in map');
    }

    final factory = _registry[type];
    if (factory == null) {
      throw ArgumentError('Command type $type not registered');
    }

    return factory(map);
  }

  /// Create a command from CBOR bytes using the registry
  static Command fromCbor(List<int> bytes) {
    final decoded = cborDecode(bytes);
    if (decoded is! CborMap) {
      throw ArgumentError('Invalid CBOR data for Command');
    }

    final map = Map<String, dynamic>.from(Command._fromCborValue(decoded) as Map);
    return fromMap(map);
  }

  /// Get all registered command types
  static List<String> getRegisteredTypes() {
    return _registry.keys.toList();
  }

  /// Clear all registered command types (useful for testing)
  static void clear() {
    _registry.clear();
  }
}

/// Exception thrown when command validation fails
class CommandValidationException implements Exception {
  final Command command;
  final List<String> errors;

  const CommandValidationException(this.command, this.errors);

  @override
  String toString() {
    return 'CommandValidationException for ${command.runtimeType}: ${errors.join(', ')}';
  }
}

/// Exception thrown when command processing fails
class CommandProcessingException implements Exception {
  final Command command;
  final String message;
  final dynamic cause;

  const CommandProcessingException(this.command, this.message, [this.cause]);

  @override
  String toString() {
    final causeStr = cause != null ? ' (caused by: $cause)' : '';
    return 'CommandProcessingException for ${command.runtimeType}: $message$causeStr';
  }
}

/// Exception thrown when command deserialization fails
class CommandDeserializationException implements Exception {
  final String message;
  final dynamic cause;

  const CommandDeserializationException(this.message, [this.cause]);

  @override
  String toString() {
    final causeStr = cause != null ? ' (caused by: $cause)' : '';
    return 'CommandDeserializationException: $message$causeStr';
  }
}
