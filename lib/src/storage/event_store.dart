// Event store interface and Isar implementation - Phase 1 Week 3 implementation
// Core persistence layer for events and snapshots

import 'dart:io';
import 'package:isar/isar.dart';
import '../event.dart';
import 'package:eventador/src/saga/saga_state_envelope.dart';

import '../event.dart';
import 'event_envelope.dart';
import 'snapshot_envelope.dart';
import 'cbor_serializer.dart';

/// Interface for event storage operations
/// Defines the contract for persisting and retrieving events
abstract class EventStore {
  /// Persist a single event
  Future<void> persistEvent(String persistenceId, Event event, int expectedVersion);
  
  /// Persist multiple events atomically
  Future<void> persistEvents(String persistenceId, List<Event> events, int expectedVersion);
  
  /// Retrieve events for a persistence ID starting from a sequence number
  Future<List<Event>> getEvents(String persistenceId, {int fromSequence = 0, int? toSequence});
  
  /// Get the highest sequence number for a persistence ID
  Future<int> getHighestSequenceNumber(String persistenceId);
  
  /// Save a snapshot
  Future<void> saveSnapshot(String persistenceId, dynamic state, int sequenceNumber);
  
  /// Load the latest snapshot
  Future<SnapshotData?> loadSnapshot(String persistenceId);
  
  /// Delete old snapshots (retention policy)
  Future<void> deleteOldSnapshots(String persistenceId, int keepCount);

  /// Save the state of a saga.
  Future<void> saveSagaState(SagaStateEnvelope envelope);

  /// Load the state of a saga.
  Future<SagaStateEnvelope?> loadSagaState(String persistenceId);
  
  /// Close the event store and cleanup resources
  Future<void> close();
}

/// Snapshot data container
class SnapshotData {
  final dynamic state;
  final int sequenceNumber;
  final DateTime timestamp;
  
  const SnapshotData({
    required this.state,
    required this.sequenceNumber,
    required this.timestamp,
  });
}

/// Exception thrown when optimistic concurrency control fails
class ConcurrencyException implements Exception {
  final String message;
  
  const ConcurrencyException(this.message);
  
  @override
  String toString() => 'ConcurrencyException: $message';
}

/// Exception thrown when event store operations fail
class EventStoreException implements Exception {
  final String message;
  final dynamic cause;
  
  const EventStoreException(this.message, [this.cause]);
  
  @override
  String toString() {
    final causeStr = cause != null ? ' (caused by: $cause)' : '';
    return 'EventStoreException: $message$causeStr';
  }
}

/// Isar-based implementation of EventStore
class IsarEventStore implements EventStore {
  final Isar _isar;
  
  /// Required Isar schemas for the event store
  /// Use this when creating an external Isar instance to pass to the constructor
  static const List<CollectionSchema<dynamic>> requiredSchemas = [
    EventEnvelopeSchema,
    SnapshotEnvelopeSchema,
    SagaStateEnvelopeSchema,
  ];
  
  /// Constructor that accepts an external Isar instance
  /// The Isar instance must be opened with the schemas from [requiredSchemas]
  IsarEventStore(this._isar);
  
  /// Factory constructor to create and initialize Isar database
  /// Creates an internal Isar instance with the required schemas
  static Future<IsarEventStore> create({
    required String directory,
    String name = 'eventador',
  }) async {
    // Ensure directory exists
    final dir = Directory(directory);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    await Isar.initializeIsarCore(download: true);

    // Initialize Isar with required schemas
    final isar = await Isar.open(
      requiredSchemas,
      directory: directory,
      name: name,
    );
    
    return IsarEventStore(isar);
  }
  
  @override
  Future<void> persistEvent(String persistenceId, Event event, int expectedVersion) async {
    await _isar.writeTxn(() async {
      // Check optimistic concurrency control
      final currentVersion = await getHighestSequenceNumber(persistenceId);
      if (currentVersion != expectedVersion) {
        throw ConcurrencyException(
          'Expected version $expectedVersion, but current version is $currentVersion'
        );
      }
      
      // Create next sequence number
      final nextSequence = currentVersion + 1;
      
      // Serialize event and metadata
      final eventData = CborSerializer.serializeEvent(event);
      final metadataData = CborSerializer.serializeMetadata(
        event.metadata.cast<String, String>()
      );
      
      // Create event envelope
      final envelope = EventEnvelope()
        ..persistenceId = persistenceId
        ..sequenceNumber = nextSequence
        ..eventData = eventData
        ..eventType = event.runtimeType.toString()
        ..timestamp = event.timestamp
        ..metadataData = metadataData
        ..eventId = event.eventId
        ..schemaVersion = event is VersionedEvent ? event.schemaVersion : 1;
      
      // Store in Isar
      await _isar.eventEnvelopes.put(envelope);
    });
  }
  
  @override
  Future<void> persistEvents(String persistenceId, List<Event> events, int expectedVersion) async {
    if (events.isEmpty) return;
    
    await _isar.writeTxn(() async {
      // Check optimistic concurrency control
      final currentVersion = await getHighestSequenceNumber(persistenceId);
      if (currentVersion != expectedVersion) {
        throw ConcurrencyException(
          'Expected version $expectedVersion, but current version is $currentVersion'
        );
      }
      
      // Create envelopes for all events
      final envelopes = <EventEnvelope>[];
      for (int i = 0; i < events.length; i++) {
        final event = events[i];
        final nextSequence = currentVersion + i + 1;
        
        // Serialize event and metadata
        final eventData = CborSerializer.serializeEvent(event);
        final metadataData = CborSerializer.serializeMetadata(
          event.metadata.cast<String, String>()
        );
        
        // Create event envelope
        final envelope = EventEnvelope()
          ..persistenceId = persistenceId
          ..sequenceNumber = nextSequence
          ..eventData = eventData
          ..eventType = event.runtimeType.toString()
          ..timestamp = event.timestamp
          ..metadataData = metadataData
          ..eventId = event.eventId
          ..schemaVersion = event is VersionedEvent ? event.schemaVersion : 1;
        
        envelopes.add(envelope);
      }
      
      // Store all envelopes atomically
      await _isar.eventEnvelopes.putAll(envelopes);
    });
  }
  
  @override
  Future<List<Event>> getEvents(String persistenceId, {int fromSequence = 0, int? toSequence}) async {
    try {
      final envelopes = await _isar.eventEnvelopes
          .where()
          .persistenceIdEqualTo(persistenceId)
          .sortBySequenceNumber()
          .findAll();
      
      // Filter by sequence range
      final filteredEnvelopes = envelopes.where((envelope) {
        if (envelope.sequenceNumber <= fromSequence) return false;
        if (toSequence != null && envelope.sequenceNumber > toSequence) return false;
        return true;
      }).toList();
      
      final events = <Event>[];
      for (final envelope in filteredEnvelopes) {
        try {
          final event = CborSerializer.deserializeEvent(
            envelope.eventData,
            envelope.eventType,
          );
          events.add(event);
        } catch (e) {
          throw EventStoreException(
            'Failed to deserialize event ${envelope.eventId} of type ${envelope.eventType}',
            e,
          );
        }
      }
      
      return events;
    } catch (e) {
      if (e is EventStoreException) rethrow;
      throw EventStoreException('Failed to get events for $persistenceId', e);
    }
  }
  
  @override
  Future<int> getHighestSequenceNumber(String persistenceId) async {
    try {
      final envelope = await _isar.eventEnvelopes
          .where()
          .persistenceIdEqualTo(persistenceId)
          .sortBySequenceNumberDesc()
          .findFirst();
      
      return envelope?.sequenceNumber ?? 0;
    } catch (e) {
      throw EventStoreException('Failed to get highest sequence number for $persistenceId', e);
    }
  }
  
  @override
  Future<void> saveSnapshot(String persistenceId, dynamic state, int sequenceNumber) async {
    try {
      await _isar.writeTxn(() async {
        // Serialize state and metadata
        final snapshotData = CborSerializer.serializeState(state);
        final metadataData = CborSerializer.serializeMetadata(<String, String>{});
        
        // Create snapshot envelope
        final envelope = SnapshotEnvelope()
          ..persistenceId = persistenceId
          ..sequenceNumber = sequenceNumber
          ..snapshotData = snapshotData
          ..timestamp = DateTime.now()
          ..stateType = state.runtimeType.toString()
          ..schemaVersion = 1
          ..sizeBytes = snapshotData.length
          ..metadataData = metadataData;
        
        // Replace existing snapshot (upsert by unique persistenceId)
        await _isar.snapshotEnvelopes.putByPersistenceId(envelope);
      });
    } catch (e) {
      throw EventStoreException('Failed to save snapshot for $persistenceId', e);
    }
  }
  
  @override
  Future<SnapshotData?> loadSnapshot(String persistenceId) async {
    try {
      final envelope = await _isar.snapshotEnvelopes
          .where()
          .persistenceIdEqualTo(persistenceId)
          .findFirst();
      
      if (envelope == null) {
        return null;
      }
      
      // Deserialize state
      final state = CborSerializer.deserializeState(
        envelope.snapshotData,
        envelope.stateType,
      );
      
      return SnapshotData(
        state: state,
        sequenceNumber: envelope.sequenceNumber,
        timestamp: envelope.timestamp,
      );
    } catch (e) {
      throw EventStoreException('Failed to load snapshot for $persistenceId', e);
    }
  }
  
  @override
  Future<void> deleteOldSnapshots(String persistenceId, int keepCount) async {
    try {
      await _isar.writeTxn(() async {
        // Since we only keep one snapshot per persistence ID (unique index),
        // this method is mainly for future extensibility
        // For now, we just ensure we don't have more than keepCount snapshots
        
        if (keepCount <= 0) {
          // Delete all snapshots for this persistence ID
          await _isar.snapshotEnvelopes
              .where()
              .persistenceIdEqualTo(persistenceId)
              .deleteAll();
        }
        // With unique index on persistenceId, we only have one snapshot max
        // So no additional cleanup needed for keepCount > 0
      });
    } catch (e) {
      throw EventStoreException('Failed to delete old snapshots for $persistenceId', e);
    }
  }
  
  @override
  Future<void> close() async {
    if (_isar.isOpen) {
      await _isar.close();
    }
  }

  @override
  Future<void> saveSagaState(SagaStateEnvelope envelope) async {
    await _isar.writeTxn(() async {
      await _isar.sagaStateEnvelopes.put(envelope);
    });
  }

  @override
  Future<SagaStateEnvelope?> loadSagaState(String persistenceId) async {
    return await _isar.sagaStateEnvelopes.getByPersistenceId(persistenceId);
  }
}
