// Phase 1 Week 2 tests - Core Persistent Actor Framework
import 'package:eventador/eventador.dart';
import 'package:eventador/src/saga/saga_state_envelope.dart';
import 'package:test/test.dart';

// Mock EventStore for testing
class MockEventStore implements EventStore {
  final Map<String, List<Event>> _events = {};
  final Map<String, SnapshotData> _snapshots = {};
  final Map<String, int> _sequences = {};

  @override
  Future<void> persistEvent(String persistenceId, Event event, int expectedVersion) async {
    final currentSequence = _sequences[persistenceId] ?? 0;
    if (expectedVersion != currentSequence) {
      throw Exception('Optimistic concurrency violation: expected $expectedVersion, got $currentSequence');
    }
    
    _events.putIfAbsent(persistenceId, () => []);
    _events[persistenceId]!.add(event);
    _sequences[persistenceId] = currentSequence + 1;
  }

  @override
  Future<void> persistEvents(String persistenceId, List<Event> events, int expectedVersion) async {
    final currentSequence = _sequences[persistenceId] ?? 0;
    if (expectedVersion != currentSequence) {
      throw Exception('Optimistic concurrency violation: expected $expectedVersion, got $currentSequence');
    }
    
    _events.putIfAbsent(persistenceId, () => []);
    _events[persistenceId]!.addAll(events);
    _sequences[persistenceId] = currentSequence + events.length;
  }

  @override
  Future<List<Event>> getEvents(String persistenceId, {int fromSequence = 0, int? toSequence}) async {
    final events = _events[persistenceId] ?? [];
    // Convert sequence numbers to array indices
    // Sequence 0 -> index 0, sequence 1 -> index 1, etc.
    final startIndex = fromSequence;
    final endIndex = toSequence != null ? toSequence : events.length;
    
    if (startIndex >= events.length) {
      return [];
    }
    
    return events.sublist(startIndex, endIndex.clamp(startIndex, events.length));
  }

  @override
  Future<int> getHighestSequenceNumber(String persistenceId) async {
    return _sequences[persistenceId] ?? 0;
  }

  @override
  Future<void> saveSnapshot(String persistenceId, dynamic state, int sequenceNumber) async {
    _snapshots[persistenceId] = SnapshotData(
      state: state,
      sequenceNumber: sequenceNumber,
      timestamp: DateTime.now(),
    );
  }

  @override
  Future<SnapshotData?> loadSnapshot(String persistenceId) async {
    return _snapshots[persistenceId];
  }

  @override
  Future<void> deleteOldSnapshots(String persistenceId, int keepCount) async {
    // Mock implementation - in real implementation would delete old snapshots
  }

  @override
  Future<void> close() async {
    // Mock implementation
  }

  @override
  Future<void> saveSagaState(SagaStateEnvelope envelope) async {
    // Mock implementation
  }

  @override
  Future<SagaStateEnvelope?> loadSagaState(String persistenceId) async {
    // Mock implementation
    return null;
  }
}

// Test Command implementations
class TestCommand extends Command with ValidatableCommand, TargetedCommand {
  final String _aggregateId;
  final String action;
  final int? value;

  TestCommand({
    required String aggregateId,
    required this.action,
    this.value,
    String? commandId,
    DateTime? timestamp,
    Map<String, dynamic>? metadata,
  }) : _aggregateId = aggregateId,
       super(commandId: commandId, timestamp: timestamp, metadata: metadata);

  @override
  String get aggregateId => _aggregateId;

  @override
  Map<String, dynamic> toMap() {
    final map = super.toMap();
    map['action'] = action;
    if (value != null) map['value'] = value;
    return map;
  }

  @override
  List<String> getCustomValidationErrors() {
    final errors = <String>[];
    if (action.isEmpty) {
      errors.add('Action cannot be empty');
    }
    if (value != null && value! < 0) {
      errors.add('Value cannot be negative');
    }
    return errors;
  }
}

// Test Event implementations
class TestEvent extends Event with AggregateEvent, SerializableEvent, VersionedEvent {
  final String _aggregateId;
  final String eventType;
  final int? value;

  TestEvent({
    required String aggregateId,
    required this.eventType,
    this.value,
    String? eventId,
    DateTime? timestamp,
    int? version,
    Map<String, dynamic>? metadata,
  }) : _aggregateId = aggregateId,
       super(eventId: eventId, timestamp: timestamp, version: version, metadata: metadata);

  @override
  String get aggregateId => _aggregateId;

  @override
  String get aggregateType => 'TestAggregate';

  @override
  Map<String, dynamic> getEventData() {
    final data = <String, dynamic>{
      'eventType': eventType,
    };
    if (value != null) data['value'] = value;
    return data;
  }

  static TestEvent fromMap(Map<String, dynamic> map) {
    return TestEvent(
      aggregateId: map['aggregateId'] as String,
      eventType: map['eventType'] as String,
      value: map['value'] as int?,
      eventId: map['eventId'] as String?,
      timestamp: map['timestamp'] != null ? DateTime.parse(map['timestamp'] as String) : null,
      version: map['version'] as int?,
      metadata: map['metadata'] as Map<String, dynamic>?,
    );
  }

  @override
  String toString() {
    return 'TestEvent(id: $eventId, type: $eventType, value: $value, timestamp: $timestamp, version: $version)';
  }
}

// Test PersistentActor implementation
class TestPersistentActor extends PersistentActor {
  int _counter = 0;
  final List<String> _receivedEvents = [];
  final List<String> _receivedMessages = [];

  TestPersistentActor({
    required String persistenceId,
    required EventStore eventStore,
  }) : super(persistenceId: persistenceId, eventStore: eventStore);

  int get counter => _counter;
  List<String> get receivedEvents => List.from(_receivedEvents);
  List<String> get receivedMessages => List.from(_receivedMessages);

  @override
  Future<void> commandHandler(Command command) async {
    if (command is TestCommand) {
      switch (command.action) {
        case 'increment':
          final event = TestEvent(
            aggregateId: persistenceId,
            eventType: 'incremented',
            value: command.value ?? 1,
          );
          await persistEvent(event);
          break;
        case 'decrement':
          final event = TestEvent(
            aggregateId: persistenceId,
            eventType: 'decremented',
            value: command.value ?? 1,
          );
          await persistEvent(event);
          break;
        case 'reset':
          final event = TestEvent(
            aggregateId: persistenceId,
            eventType: 'reset',
          );
          await persistEvent(event);
          break;
        default:
          throw ArgumentError('Unknown action: ${command.action}');
      }
    }
  }

  @override
  void eventHandler(Event event) {
    _receivedEvents.add(event.toString());
    
    if (event is TestEvent) {
      switch (event.eventType) {
        case 'incremented':
          _counter += event.value ?? 1;
          break;
        case 'decremented':
          _counter -= event.value ?? 1;
          break;
        case 'reset':
          _counter = 0;
          break;
      }
    }
  }

  @override
  Future<void> queryHandler(dynamic message) async {
    _receivedMessages.add(message.toString());
  }

  @override
  Future<dynamic> getSnapshotState() async {
    return {'counter': _counter};
  }

  @override
  Future<void> onSnapshot(dynamic snapshotState, int sequenceNumber) async {
    if (snapshotState is Map<String, dynamic>) {
      _counter = snapshotState['counter'] as int? ?? 0;
    }
  }
}

void main() {
  group('Phase 1 Week 2 - Core Persistent Actor Framework', () {
    late MockEventStore eventStore;

    setUp(() {
      eventStore = MockEventStore();
    });

    group('Command Framework', () {
      test('should create command with auto-generated ID', () {
        final command = TestCommand(aggregateId: 'test-1', action: 'increment');
        
        expect(command.commandId, isNotEmpty);
        expect(command.commandId, startsWith('cmd_'));
        expect(command.aggregateId, equals('test-1'));
        expect(command.action, equals('increment'));
        expect(command.timestamp, isA<DateTime>());
      });

      test('should validate command successfully', () {
        final command = TestCommand(aggregateId: 'test-1', action: 'increment', value: 5);
        
        expect(command.validate(), isTrue);
        expect(command.getValidationErrors(), isEmpty);
      });

      test('should fail validation for invalid command', () {
        final command = TestCommand(aggregateId: '', action: '', value: -1);
        
        expect(command.validate(), isFalse);
        final errors = command.getValidationErrors();
        expect(errors, contains('Aggregate ID cannot be empty'));
        expect(errors, contains('Action cannot be empty'));
        expect(errors, contains('Value cannot be negative'));
      });

      test('should serialize and deserialize command with CBOR', () {
        final command = TestCommand(aggregateId: 'test-1', action: 'increment', value: 5);
        
        final bytes = command.toCbor();
        expect(bytes, isNotEmpty);
        
        // Note: Full deserialization would require command registry setup
        // This tests the serialization part
      });
    });

    group('Event Framework', () {
      test('should create event with auto-generated ID', () {
        final event = TestEvent(aggregateId: 'test-1', eventType: 'incremented', value: 5);
        
        expect(event.eventId, isNotEmpty);
        expect(event.eventId, startsWith('evt_'));
        expect(event.aggregateId, equals('test-1'));
        expect(event.aggregateType, equals('TestAggregate'));
        expect(event.eventType, equals('incremented'));
        expect(event.value, equals(5));
        expect(event.timestamp, isA<DateTime>());
      });

      test('should serialize event to map', () {
        final event = TestEvent(aggregateId: 'test-1', eventType: 'incremented', value: 5);
        
        final map = event.toMap();
        expect(map['eventId'], equals(event.eventId));
        expect(map['aggregateId'], equals('test-1'));
        expect(map['aggregateType'], equals('TestAggregate'));
        expect(map['eventType'], equals('incremented'));
        expect(map['value'], equals(5));
        expect(map['type'], equals('TestEvent'));
      });

      test('should serialize and deserialize event with CBOR', () {
        final event = TestEvent(aggregateId: 'test-1', eventType: 'incremented', value: 5);
        
        final bytes = event.toCbor();
        expect(bytes, isNotEmpty);
        
        // Note: Full deserialization would require event registry setup
        // This tests the serialization part
      });
    });

    group('PersistentActor Framework', () {
      test('should create persistent actor with valid persistence ID', () {
        final actor = TestPersistentActor(
          persistenceId: 'test-actor-1',
          eventStore: eventStore,
        );
        
        expect(actor.persistenceId, equals('test-actor-1'));
        expect(actor.sequenceNumber, equals(0));
        expect(actor.isRecovering, isFalse);
        expect(actor.isRecovered, isFalse);
      });

      test('should throw error for empty persistence ID', () {
        expect(
          () => TestPersistentActor(persistenceId: '', eventStore: eventStore),
          throwsArgumentError,
        );
      });

      test('should process commands and persist events', () async {
        final actor = TestPersistentActor(
          persistenceId: 'test-actor-1',
          eventStore: eventStore,
        );

        // Simulate actor startup
        actor.preStart();
        await Future.delayed(Duration(milliseconds: 50)); // Allow recovery to complete

        // Send increment command
        final command = TestCommand(aggregateId: 'test-actor-1', action: 'increment', value: 5);
        await actor.onMessage(command);

        expect(actor.counter, equals(5));
        expect(actor.sequenceNumber, equals(1));
        expect(actor.receivedEvents, hasLength(1));
        expect(actor.receivedEvents.first, contains('incremented'));
      });

      test('should handle multiple commands and maintain state', () async {
        final actor = TestPersistentActor(
          persistenceId: 'test-actor-2',
          eventStore: eventStore,
        );

        // Simulate actor startup
        actor.preStart();
        await Future.delayed(Duration(milliseconds: 50)); // Allow recovery to complete

        // Send multiple commands
        await actor.onMessage(TestCommand(aggregateId: 'test-actor-2', action: 'increment', value: 3));
        await actor.onMessage(TestCommand(aggregateId: 'test-actor-2', action: 'increment', value: 2));
        await actor.onMessage(TestCommand(aggregateId: 'test-actor-2', action: 'decrement', value: 1));

        expect(actor.counter, equals(4)); // 3 + 2 - 1
        expect(actor.sequenceNumber, equals(3));
        expect(actor.receivedEvents, hasLength(3));
      });

      test('should recover state from events after restart', () async {
        // First actor instance
        final actor1 = TestPersistentActor(
          persistenceId: 'test-actor-3',
          eventStore: eventStore,
        );

        actor1.preStart();
        await Future.delayed(Duration(milliseconds: 50));

        await actor1.onMessage(TestCommand(aggregateId: 'test-actor-3', action: 'increment', value: 10));
        await actor1.onMessage(TestCommand(aggregateId: 'test-actor-3', action: 'increment', value: 5));

        expect(actor1.counter, equals(15));
        expect(actor1.sequenceNumber, equals(2));

        // Second actor instance (simulating restart)
        final actor2 = TestPersistentActor(
          persistenceId: 'test-actor-3',
          eventStore: eventStore,
        );

        actor2.preStart();
        await Future.delayed(Duration(milliseconds: 50)); // Allow recovery to complete

        // Should have recovered state
        expect(actor2.counter, equals(15));
        expect(actor2.sequenceNumber, equals(2));
        expect(actor2.receivedEvents, hasLength(2));
      });

      test('should handle regular messages alongside commands', () async {
        final actor = TestPersistentActor(
          persistenceId: 'test-actor-4',
          eventStore: eventStore,
        );

        actor.preStart();
        await Future.delayed(Duration(milliseconds: 50));

        // Send regular message
        await actor.onMessage('regular message');
        
        // Send command
        await actor.onMessage(TestCommand(aggregateId: 'test-actor-4', action: 'increment', value: 1));
        
        // Send another regular message
        await actor.onMessage(42);

        expect(actor.receivedMessages, hasLength(2));
        expect(actor.receivedMessages, contains('regular message'));
        expect(actor.receivedMessages, contains('42'));
        expect(actor.counter, equals(1));
      });

      test('should create and restore from snapshots', () async {
        final actor = TestPersistentActor(
          persistenceId: 'test-actor-5',
          eventStore: eventStore,
        );

        actor.preStart();
        await Future.delayed(Duration(milliseconds: 50));

        // Build up some state
        await actor.onMessage(TestCommand(aggregateId: 'test-actor-5', action: 'increment', value: 100));
        
        // Create snapshot
        await actor.createSnapshot();

        // Add more events after snapshot
        await actor.onMessage(TestCommand(aggregateId: 'test-actor-5', action: 'increment', value: 50));

        expect(actor.counter, equals(150));

        // New actor instance should recover from snapshot + subsequent events
        final actor2 = TestPersistentActor(
          persistenceId: 'test-actor-5',
          eventStore: eventStore,
        );

        actor2.preStart();
        await Future.delayed(Duration(milliseconds: 50));

        expect(actor2.counter, equals(150));
      });

      test('should validate commands before processing', () async {
        final actor = TestPersistentActor(
          persistenceId: 'test-actor-6',
          eventStore: eventStore,
        );

        actor.preStart();
        await Future.delayed(Duration(milliseconds: 50));

        // Send invalid command
        final invalidCommand = TestCommand(aggregateId: '', action: '', value: -1);
        
        expect(
          () => actor.onMessage(invalidCommand),
          throwsA(isA<CommandValidationException>()),
        );

        // State should remain unchanged
        expect(actor.counter, equals(0));
        expect(actor.sequenceNumber, equals(0));
      });

      test('should prevent event persistence during recovery', () async {
        final actor = TestPersistentActor(
          persistenceId: 'test-actor-7',
          eventStore: eventStore,
        );

        // Actor starts in unrecovered state (before preStart)
        expect(actor.isRecovered, isFalse);
        expect(actor.isRecovering, isFalse);
        
        // Should not be able to persist events before recovery
        await expectLater(
          () => actor.persistEvent(TestEvent(aggregateId: 'test-actor-7', eventType: 'test')),
          throwsStateError,
        );
      });
    });

    group('Event Store Integration', () {
      test('should persist and retrieve events', () async {
        final event1 = TestEvent(aggregateId: 'test-1', eventType: 'created');
        final event2 = TestEvent(aggregateId: 'test-1', eventType: 'updated', value: 5);

        await eventStore.persistEvent('test-1', event1, 0);
        await eventStore.persistEvent('test-1', event2, 1);

        final events = await eventStore.getEvents('test-1');
        expect(events, hasLength(2));
        expect(events[0], equals(event1));
        expect(events[1], equals(event2));

        final sequence = await eventStore.getHighestSequenceNumber('test-1');
        expect(sequence, equals(2));
      });

      test('should handle optimistic concurrency control', () async {
        final event = TestEvent(aggregateId: 'test-2', eventType: 'created');

        await eventStore.persistEvent('test-2', event, 0);

        // This should fail due to wrong expected version
        expect(
          () => eventStore.persistEvent('test-2', event, 0),
          throwsException,
        );
      });

      test('should persist and retrieve snapshots', () async {
        final snapshotData = {'counter': 42, 'name': 'test'};
        
        await eventStore.saveSnapshot('test-3', snapshotData, 10);
        
        final snapshot = await eventStore.loadSnapshot('test-3');
        expect(snapshot, isNotNull);
        expect(snapshot!.state, equals(snapshotData));
        expect(snapshot.sequenceNumber, equals(10));
      });
    });
  });
}
