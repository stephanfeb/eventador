// Event abstractions - Phase 1 Week 2 implementation
// Events represent facts that have occurred

import 'dart:convert';
import 'package:cbor/cbor.dart';
import 'package:dactor/dactor.dart';
import 'package:meta/meta.dart';

/// Base class for all events in the event sourcing system
/// Events represent immutable facts that have occurred and are stored permanently
abstract class Event implements Message {
  final String _eventId;
  final DateTime _timestamp;
  final int _version;
  final Map<String, dynamic> _metadata;

  /// Create an event with optional ID, timestamp, version, and metadata
  Event({
    String? eventId,
    DateTime? timestamp,
    int? version,
    Map<String, dynamic>? metadata,
  }) : _eventId = eventId ?? _generateEventId(),
       _timestamp = timestamp ?? DateTime.now(),
       _version = version ?? 1,
       _metadata = Map<String, dynamic>.from(metadata ?? {});

  /// Unique identifier for this event
  /// Used for deduplication and correlation
  String get eventId => _eventId;

  @override
  String get correlationId => metadata['correlationId'] as String? ?? _eventId;

  @override
  ActorRef? get replyTo => metadata['replyTo'] as ActorRef?;

  /// Timestamp when the event occurred
  DateTime get timestamp => _timestamp;

  /// Version/sequence number of this event within its aggregate
  /// Used for ordering and optimistic concurrency control
  int get version => _version;

  /// Additional metadata for the event
  /// Can include correlation IDs, causation IDs, user context, etc.
  Map<String, dynamic> get metadata => Map<String, dynamic>.from(_metadata);

  /// Generate a unique event ID
  static String _generateEventId() {
    final now = DateTime.now();
    final timestamp = now.millisecondsSinceEpoch;
    final microseconds = now.microsecondsSinceEpoch;
    final random = (microseconds % 100000).toString().padLeft(5, '0');
    return 'evt_${timestamp}_$random';
  }

  /// Convert event to a map for serialization
  /// Override in subclasses to include event-specific data
  @protected
  Map<String, dynamic> toMap() {
    return {
      'eventId': _eventId,
      'timestamp': _timestamp.toIso8601String(),
      'version': _version,
      'metadata': _metadata,
      'type': runtimeType.toString(),
    };
  }

  /// Serialize event to CBOR bytes
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

  /// Create event from CBOR bytes
  /// Subclasses must implement their own fromCbor methods
  static Event fromCbor(List<int> bytes) {
    final decoded = cborDecode(bytes);
    if (decoded is! CborMap) {
      throw ArgumentError('Invalid CBOR data for Event');
    }
    
    final map = Map<String, dynamic>.from(_fromCborValue(decoded) as Map);
    final type = map['type'] as String?;
    
    if (type == null) {
      throw ArgumentError('Event type not found in CBOR data');
    }
    
    // This is a factory method - concrete implementations should register
    // their fromCbor methods in an event registry
    throw UnimplementedError('Event type $type not registered');
  }

  /// Validate the event
  /// Override in subclasses for custom validation
  @protected
  bool isValid() => true;

  /// Get validation errors
  /// Override in subclasses to provide specific error messages
  @protected
  List<String> getValidationErrors() => [];

  @override
  String toString() {
    return '${runtimeType}(id: $_eventId, timestamp: $_timestamp, version: $_version)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Event && other._eventId == _eventId;
  }

  @override
  int get hashCode => _eventId.hashCode;
}

/// Mixin for events that belong to a specific aggregate
mixin AggregateEvent on Event {
  /// The ID of the aggregate this event belongs to
  String get aggregateId;

  /// The type of aggregate this event belongs to
  String get aggregateType;

  @override
  Map<String, dynamic> toMap() {
    final map = super.toMap();
    map['aggregateId'] = aggregateId;
    map['aggregateType'] = aggregateType;
    return map;
  }

  @override
  List<String> getValidationErrors() {
    final errors = super.getValidationErrors();
    
    if (aggregateId.isEmpty) {
      errors.add('Aggregate ID cannot be empty');
    }
    
    if (aggregateType.isEmpty) {
      errors.add('Aggregate type cannot be empty');
    }
    
    return errors;
  }
}

/// Mixin for events that can be serialized
mixin SerializableEvent on Event {
  /// Convert event to a map for serialization
  /// Override in subclasses to include event-specific data
  @override
  Map<String, dynamic> toMap() {
    final map = super.toMap();
    map.addAll(getEventData());
    return map;
  }

  /// Get event-specific data for serialization
  /// Override in subclasses to provide event data
  @protected
  Map<String, dynamic> getEventData() => {};

  /// Create event from a map during deserialization
  /// This is a factory method that should be implemented by concrete event classes
  static Event fromMap(Map<String, dynamic> map) {
    throw UnimplementedError('fromMap must be implemented by concrete event classes');
  }
}

/// Mixin for events that support versioning
mixin VersionedEvent on Event {
  /// Schema version of this event
  /// Used for event migration and backward compatibility
  int get schemaVersion => 1;

  /// Migrate this event to a newer schema version
  /// Override in subclasses to provide migration logic
  Event migrate(int targetVersion) {
    if (targetVersion == schemaVersion) {
      return this;
    }
    
    if (targetVersion < schemaVersion) {
      throw ArgumentError('Cannot migrate to older schema version');
    }
    
    // Default implementation - subclasses should override
    throw UnimplementedError('Migration from version $schemaVersion to $targetVersion not implemented');
  }

  /// Check if this event can be migrated to the target version
  bool canMigrateTo(int targetVersion) {
    return targetVersion >= schemaVersion;
  }

  @override
  Map<String, dynamic> toMap() {
    final map = super.toMap();
    map['schemaVersion'] = schemaVersion;
    return map;
  }
}

/// Mixin for events that have correlation tracking
mixin CorrelatedEvent on Event {
  /// Correlation ID for tracking related events/commands
  @override
  String get correlationId => metadata['correlationId'] as String? ?? eventId;

  /// Causation ID - the ID of the command/event that caused this event
  String? get causationId => metadata['causationId'] as String?;

  /// User context information
  String? get userId => metadata['userId'] as String?;

  /// Session context information
  String? get sessionId => metadata['sessionId'] as String?;

  /// Set correlation tracking information
  void setCorrelation({
    String? correlationId,
    String? causationId,
    String? userId,
    String? sessionId,
  }) {
    if (correlationId != null) _metadata['correlationId'] = correlationId;
    if (causationId != null) _metadata['causationId'] = causationId;
    if (userId != null) _metadata['userId'] = userId;
    if (sessionId != null) _metadata['sessionId'] = sessionId;
  }
}

/// Mixin for events that can be replayed
mixin ReplayableEvent on Event {
  /// Whether this event should be replayed during recovery
  bool get shouldReplay => true;

  /// Whether this event is a snapshot event
  bool get isSnapshot => false;

  /// Priority for replay ordering (higher = earlier)
  int get replayPriority => 0;
}

/// Registry for event types and their deserialization functions
class EventRegistry {
  static final Map<String, Event Function(Map<String, dynamic>)> _registry = {};
  static final Map<String, int> _schemaVersions = {};

  /// Register an event type with its deserialization function
  static void register<T extends Event>(
    String typeName,
    T Function(Map<String, dynamic>) fromMap, {
    int schemaVersion = 1,
  }) {
    _registry[typeName] = fromMap;
    _schemaVersions[typeName] = schemaVersion;
  }

  /// Create an event from a map using the registry
  static Event fromMap(Map<String, dynamic> map) {
    final type = map['type'] as String?;
    if (type == null) {
      throw ArgumentError('Event type not found in map');
    }

    final factory = _registry[type];
    if (factory == null) {
      throw ArgumentError('Event type $type not registered');
    }

    return factory(map);
  }

  /// Create an event from CBOR bytes using the registry
  static Event fromCbor(List<int> bytes) {
    final decoded = cborDecode(bytes);
    if (decoded is! CborMap) {
      throw ArgumentError('Invalid CBOR data for Event');
    }

    final map = Map<String, dynamic>.from(Event._fromCborValue(decoded) as Map);
    return fromMap(map);
  }

  /// Get the current schema version for an event type
  static int getSchemaVersion(String typeName) {
    return _schemaVersions[typeName] ?? 1;
  }

  /// Get all registered event types
  static List<String> getRegisteredTypes() {
    return _registry.keys.toList();
  }

  /// Clear all registered event types (useful for testing)
  static void clear() {
    _registry.clear();
    _schemaVersions.clear();
  }

  /// Check if an event type is registered
  static bool isRegistered(String typeName) {
    return _registry.containsKey(typeName);
  }
}

/// Event migration manager for handling schema evolution
class EventMigrationManager {
  static final Map<String, Map<int, Event Function(Event)>> _migrations = {};

  /// Register a migration function for an event type
  static void registerMigration<T extends Event>(
    String typeName,
    int fromVersion,
    int toVersion,
    T Function(T) migrationFunction,
  ) {
    _migrations.putIfAbsent(typeName, () => {});
    _migrations[typeName]![fromVersion] = (event) => migrationFunction(event as T);
  }

  /// Migrate an event to the latest schema version
  static Event migrate(Event event, int targetVersion) {
    final typeName = event.runtimeType.toString();
    final currentVersion = event is VersionedEvent ? event.schemaVersion : 1;
    
    if (currentVersion == targetVersion) {
      return event;
    }
    
    if (currentVersion > targetVersion) {
      throw ArgumentError('Cannot migrate to older schema version');
    }
    
    Event migratedEvent = event;
    for (int version = currentVersion; version < targetVersion; version++) {
      final migration = _migrations[typeName]?[version];
      if (migration == null) {
        throw ArgumentError('No migration found from version $version to ${version + 1} for $typeName');
      }
      migratedEvent = migration(migratedEvent);
    }
    
    return migratedEvent;
  }

  /// Check if migration is available for an event type
  static bool canMigrate(String typeName, int fromVersion, int toVersion) {
    if (fromVersion >= toVersion) return false;
    
    for (int version = fromVersion; version < toVersion; version++) {
      if (!_migrations.containsKey(typeName) || !_migrations[typeName]!.containsKey(version)) {
        return false;
      }
    }
    
    return true;
  }

  /// Clear all registered migrations (useful for testing)
  static void clear() {
    _migrations.clear();
  }
}

/// Exception thrown when event validation fails
class EventValidationException implements Exception {
  final Event event;
  final List<String> errors;

  const EventValidationException(this.event, this.errors);

  @override
  String toString() {
    return 'EventValidationException for ${event.runtimeType}: ${errors.join(', ')}';
  }
}

/// Exception thrown when event deserialization fails
class EventDeserializationException implements Exception {
  final String message;
  final dynamic cause;

  const EventDeserializationException(this.message, [this.cause]);

  @override
  String toString() {
    final causeStr = cause != null ? ' (caused by: $cause)' : '';
    return 'EventDeserializationException: $message$causeStr';
  }
}

/// Exception thrown when event migration fails
class EventMigrationException implements Exception {
  final Event event;
  final int fromVersion;
  final int toVersion;
  final String message;
  final dynamic cause;

  const EventMigrationException(
    this.event,
    this.fromVersion,
    this.toVersion,
    this.message, [
    this.cause,
  ]);

  @override
  String toString() {
    final causeStr = cause != null ? ' (caused by: $cause)' : '';
    return 'EventMigrationException for ${event.runtimeType} from v$fromVersion to v$toVersion: $message$causeStr';
  }
}
