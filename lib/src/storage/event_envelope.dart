// Isar event storage schema - Phase 1 Week 3 placeholder
// Event envelope for storing events in Isar database

import 'package:isar/isar.dart';

part 'event_envelope.g.dart';

/// Isar collection for storing events
/// This wraps the actual event data with metadata needed for storage and retrieval
@collection
class EventEnvelope {
  /// Auto-incrementing ID for Isar
  Id id = Isar.autoIncrement;
  
  /// Persistence ID of the actor that generated this event
  /// Indexed for fast retrieval by actor
  @Index()
  late String persistenceId;
  
  /// Sequence number within the persistence ID
  /// Used for ordering events and optimistic concurrency
  @Index()
  late int sequenceNumber;
  
  /// CBOR-encoded event data
  /// The actual event is serialized to bytes for efficient storage
  late List<int> eventData;
  
  /// Type of the event (class name)
  /// Used for deserialization and event routing
  late String eventType;
  
  /// Timestamp when the event was persisted
  late DateTime timestamp;
  
  /// Additional metadata as key-value pairs (serialized as CBOR)
  /// Includes correlation IDs, causation IDs, user context, etc.
  late List<int> metadataData;
  
  /// Event ID for deduplication
  /// Indexed for fast lookup
  @Index(unique: true)
  late String eventId;
  
  /// Schema version of the event
  /// Used for event migration and backward compatibility
  late int schemaVersion;
  
  // TODO: Implement in Phase 1 Week 3
  // - CBOR serialization/deserialization
  // - Event type registry for deserialization
  // - Metadata handling and indexing
  // - Performance optimizations
}
