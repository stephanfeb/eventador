// Isar snapshot storage schema - Phase 1 Week 3 placeholder
// Snapshot envelope for storing actor state snapshots in Isar database

import 'package:isar/isar.dart';

part 'snapshot_envelope.g.dart';

/// Isar collection for storing actor state snapshots
/// Snapshots optimize recovery by avoiding replay of all events
@collection
class SnapshotEnvelope {
  /// Auto-incrementing ID for Isar
  Id id = Isar.autoIncrement;
  
  /// Persistence ID of the actor this snapshot belongs to
  /// Unique index ensures only one snapshot per actor (latest)
  @Index(unique: true)
  late String persistenceId;
  
  /// Sequence number of the last event included in this snapshot
  /// Used to determine which events to replay after snapshot
  late int sequenceNumber;
  
  /// CBOR-encoded snapshot data
  /// The actual actor state serialized to bytes
  late List<int> snapshotData;
  
  /// Timestamp when the snapshot was created
  late DateTime timestamp;
  
  /// Type of the state (class name)
  /// Used for deserialization
  late String stateType;
  
  /// Schema version of the snapshot
  /// Used for snapshot migration and backward compatibility
  late int schemaVersion;
  
  /// Size of the snapshot in bytes
  /// Used for monitoring and cleanup policies
  late int sizeBytes;
  
  /// Additional metadata as key-value pairs (serialized as CBOR)
  late List<int> metadataData;
  
  // TODO: Implement in Phase 1 Week 3
  // - CBOR serialization/deserialization for state
  // - Snapshot compression for large states
  // - Snapshot cleanup and retention policies
  // - State type registry for deserialization
  // - Performance monitoring and metrics
}
