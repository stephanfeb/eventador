// State management abstractions - Phase 2 Week 4 implementation
// State represents the current state of an aggregate or actor

import 'package:meta/meta.dart';

/// Base class for all state objects in the event sourcing system
/// State represents the current state of an aggregate or actor
abstract class State {
  final int _version;
  final DateTime _lastModified;

  /// Create a state with version and last modified timestamp
  State({
    int version = 0,
    DateTime? lastModified,
  }) : _version = version,
       _lastModified = lastModified ?? DateTime.fromMillisecondsSinceEpoch(0);

  /// Version of this state
  /// Used for optimistic concurrency control
  int get version => _version;

  /// Timestamp when this state was last modified
  DateTime get lastModified => _lastModified;

  /// Create a copy of this state with updated version and timestamp
  /// Subclasses should override to provide type-safe copying
  State copyWith({
    int? version,
    DateTime? lastModified,
  });

  /// Create a new version of this state with incremented version
  State nextVersion([DateTime? timestamp]) {
    return copyWith(
      version: _version + 1,
      lastModified: timestamp ?? DateTime.now(),
    );
  }

  /// Check if this state is newer than another state
  bool isNewerThan(State other) {
    return _version > other._version;
  }

  /// Check if this state is the same version as another state
  bool isSameVersion(State other) {
    return _version == other._version;
  }

  /// Validate the state
  /// Override in subclasses for custom validation
  @protected
  bool isValid() => true;

  /// Get validation errors
  /// Override in subclasses to provide specific error messages
  @protected
  List<String> getValidationErrors() => [];

  /// Convert state to a map for serialization
  /// Override in subclasses to include state-specific data
  @protected
  Map<String, dynamic> toMap() {
    return {
      'version': _version,
      'lastModified': _lastModified.toIso8601String(),
      'type': runtimeType.toString(),
    };
  }

  @override
  String toString() {
    return '${runtimeType}(version: $_version, lastModified: $_lastModified)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is State && 
           other._version == _version && 
           other.runtimeType == runtimeType;
  }

  @override
  int get hashCode => Object.hash(runtimeType, _version);
}

/// Mixin for states that can be validated
mixin ValidatableState on State {
  /// Validate the state before applying changes
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
    if (version < 0) {
      errors.add('State version cannot be negative');
    }
    
    if (lastModified.isAfter(DateTime.now().add(Duration(minutes: 5)))) {
      errors.add('State last modified timestamp cannot be in the future');
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

/// Mixin for states that can be serialized
mixin SerializableState on State {
  /// Convert state to a map for serialization
  /// Override in subclasses to include state-specific data
  @override
  Map<String, dynamic> toMap() {
    final map = super.toMap();
    map.addAll(getStateData());
    return map;
  }

  /// Get state-specific data for serialization
  /// Override in subclasses to provide state data
  @protected
  Map<String, dynamic> getStateData() => {};

  /// Create state from a map during deserialization
  /// This is a factory method that should be implemented by concrete state classes
  static State fromMap(Map<String, dynamic> map) {
    throw UnimplementedError('fromMap must be implemented by concrete state classes');
  }
}

/// Mixin for states that support snapshots
mixin SnapshotableState on State {
  /// Whether this state should be included in snapshots
  bool get shouldSnapshot => true;

  /// Create a snapshot of this state
  /// Override to provide custom snapshot logic
  Map<String, dynamic> createSnapshot() {
    return toMap();
  }

  /// Restore state from a snapshot
  /// Override to provide custom restoration logic
  State restoreFromSnapshot(Map<String, dynamic> snapshot) {
    throw UnimplementedError('restoreFromSnapshot must be implemented by concrete state classes');
  }

  /// Get the size of this state in bytes (approximate)
  /// Used for snapshot optimization decisions
  int getApproximateSize() {
    final json = toMap().toString();
    return json.length * 2; // Rough estimate: 2 bytes per character
  }
}

/// Mixin for states that can be compared for changes
mixin ComparableState on State {
  /// Check if this state has changed compared to another state
  /// Override to provide custom change detection logic
  bool hasChangedFrom(State other) {
    if (other.runtimeType != runtimeType) return true;
    return !isSameVersion(other);
  }

  /// Get the differences between this state and another state
  /// Override to provide detailed change information
  List<StateChange> getChangesFrom(State other) {
    if (other.runtimeType != runtimeType) {
      return [StateChange.typeChanged(other.runtimeType, runtimeType)];
    }
    
    if (!isSameVersion(other)) {
      return [StateChange.versionChanged(other.version, version)];
    }
    
    return [];
  }
}

/// Represents a change between two states
class StateChange {
  final String field;
  final dynamic oldValue;
  final dynamic newValue;
  final StateChangeType type;

  const StateChange({
    required this.field,
    required this.oldValue,
    required this.newValue,
    required this.type,
  });

  /// Create a change for a field value
  factory StateChange.fieldChanged(String field, dynamic oldValue, dynamic newValue) {
    return StateChange(
      field: field,
      oldValue: oldValue,
      newValue: newValue,
      type: StateChangeType.fieldChanged,
    );
  }

  /// Create a change for version
  factory StateChange.versionChanged(int oldVersion, int newVersion) {
    return StateChange(
      field: 'version',
      oldValue: oldVersion,
      newValue: newVersion,
      type: StateChangeType.versionChanged,
    );
  }

  /// Create a change for type
  factory StateChange.typeChanged(Type oldType, Type newType) {
    return StateChange(
      field: 'type',
      oldValue: oldType,
      newValue: newType,
      type: StateChangeType.typeChanged,
    );
  }

  @override
  String toString() {
    return 'StateChange(field: $field, $oldValue -> $newValue, type: $type)';
  }
}

/// Types of state changes
enum StateChangeType {
  fieldChanged,
  versionChanged,
  typeChanged,
}

/// Registry for state types and their deserialization functions
class StateRegistry {
  static final Map<String, State Function(Map<String, dynamic>)> _registry = {};

  /// Register a state type with its deserialization function
  static void register<T extends State>(
    String typeName,
    T Function(Map<String, dynamic>) fromMap,
  ) {
    _registry[typeName] = fromMap;
  }

  /// Create a state from a map using the registry
  static State fromMap(Map<String, dynamic> map) {
    final type = map['type'] as String?;
    if (type == null) {
      throw ArgumentError('State type not found in map');
    }

    final factory = _registry[type];
    if (factory == null) {
      throw ArgumentError('State type $type not registered');
    }

    return factory(map);
  }

  /// Get all registered state types
  static List<String> getRegisteredTypes() {
    return _registry.keys.toList();
  }

  /// Clear all registered state types (useful for testing)
  static void clear() {
    _registry.clear();
  }

  /// Check if a state type is registered
  static bool isRegistered(String typeName) {
    return _registry.containsKey(typeName);
  }
}

/// Exception thrown when state validation fails
class StateValidationException implements Exception {
  final State state;
  final List<String> errors;

  const StateValidationException(this.state, this.errors);

  @override
  String toString() {
    return 'StateValidationException for ${state.runtimeType}: ${errors.join(', ')}';
  }
}

/// Exception thrown when state registry deserialization fails
class StateRegistryDeserializationException implements Exception {
  final String message;
  final dynamic cause;

  const StateRegistryDeserializationException(this.message, [this.cause]);

  @override
  String toString() {
    final causeStr = cause != null ? ' (caused by: $cause)' : '';
    return 'StateRegistryDeserializationException: $message$causeStr';
  }
}

/// Exception thrown when state version conflicts occur
class StateVersionConflictException implements Exception {
  final State currentState;
  final State incomingState;
  final String message;

  const StateVersionConflictException(
    this.currentState,
    this.incomingState,
    this.message,
  );

  @override
  String toString() {
    return 'StateVersionConflictException: $message (current: v${currentState.version}, incoming: v${incomingState.version})';
  }
}
