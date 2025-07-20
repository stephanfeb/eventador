import 'package:eventador/eventador.dart';
import 'package:eventador/src/saga/saga_state_envelope.dart';

/// Example demonstrating Eventador Phase 1 Week 2 - Core Persistent Actor Framework
void main() async {
  print('Eventador - Persistence & Event Sourcing Extension for Dactor');
  print('Phase 1 Week 2 - Core Persistent Actor Framework Complete');
  print('');

  // Create a mock event store for demonstration
  final eventStore = MockEventStore();

  // Example 1: Basic Counter Actor
  print('=== Example 1: Basic Counter Actor ===');
  final counter = CounterActor(
    persistenceId: 'counter-1',
    eventStore: eventStore,
  );

  // Start the actor (triggers recovery)
  counter.preStart();
  await Future.delayed(Duration(milliseconds: 100)); // Allow recovery to complete

  // Send commands
  await counter.onMessage(IncrementCommand(aggregateId: 'counter-1', value: 5));
  await counter.onMessage(IncrementCommand(aggregateId: 'counter-1', value: 3));
  await counter.onMessage(DecrementCommand(aggregateId: 'counter-1', value: 2));

  print('Counter value: ${counter.value}');
  print('Events processed: ${counter.eventCount}');
  print('');

  // Example 2: Snapshot and Recovery
  print('=== Example 2: Snapshot and Recovery ===');
  
  // Create snapshot
  await counter.createSnapshot();
  print('Snapshot created at sequence ${counter.sequenceNumber}');

  // Add more events after snapshot
  await counter.onMessage(IncrementCommand(aggregateId: 'counter-1', value: 10));
  print('After snapshot - Counter value: ${counter.value}');

  // Simulate restart by creating new actor instance
  final recoveredCounter = CounterActor(
    persistenceId: 'counter-1',
    eventStore: eventStore,
  );

  recoveredCounter.preStart();
  await Future.delayed(Duration(milliseconds: 100)); // Allow recovery to complete

  print('Recovered counter value: ${recoveredCounter.value}');
  print('Recovered events processed: ${recoveredCounter.eventCount}');
  print('');

  // Example 3: Command Validation
  print('=== Example 3: Command Validation ===');
  try {
    // This should fail validation
    await counter.onMessage(IncrementCommand(aggregateId: '', value: -5));
  } catch (e) {
    print('Command validation failed as expected: ${e.runtimeType}');
  }
  print('');

  print('Phase 1 Week 2 Implementation Complete!');
  print('');
  print('Features Demonstrated:');
  print('✓ Persistent Actor with event sourcing');
  print('✓ Command processing with validation');
  print('✓ Event persistence and replay');
  print('✓ Snapshot creation and recovery');
  print('✓ Actor restart and state recovery');
  print('✓ CBOR serialization for commands and events');
  print('');
  print('Next Phase: Event Store Integration (Phase 1 Week 3)');
}

// Mock EventStore for demonstration
class MockEventStore implements EventStore {
  final Map<String, List<Event>> _events = {};
  final Map<String, SnapshotData> _snapshots = {};
  final Map<String, int> _sequences = {};

  @override
  Future<void> persistEvent(String persistenceId, Event event, int expectedVersion) async {
    final currentSequence = _sequences[persistenceId] ?? 0;
    if (expectedVersion != currentSequence) {
      throw Exception('Optimistic concurrency violation');
    }
    
    _events.putIfAbsent(persistenceId, () => []);
    _events[persistenceId]!.add(event);
    _sequences[persistenceId] = currentSequence + 1;
  }

  @override
  Future<void> persistEvents(String persistenceId, List<Event> events, int expectedVersion) async {
    final currentSequence = _sequences[persistenceId] ?? 0;
    if (expectedVersion != currentSequence) {
      throw Exception('Optimistic concurrency violation');
    }
    
    _events.putIfAbsent(persistenceId, () => []);
    _events[persistenceId]!.addAll(events);
    _sequences[persistenceId] = currentSequence + events.length;
  }

  @override
  Future<List<Event>> getEvents(String persistenceId, {int fromSequence = 0, int? toSequence}) async {
    final events = _events[persistenceId] ?? [];
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
    // Mock implementation
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

// Example Commands
class IncrementCommand extends Command with ValidatableCommand, TargetedCommand {
  final String _aggregateId;
  final int value;

  IncrementCommand({
    required String aggregateId,
    required this.value,
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
    map['value'] = value;
    return map;
  }

  @override
  List<String> getCustomValidationErrors() {
    final errors = <String>[];
    if (value <= 0) {
      errors.add('Increment value must be positive');
    }
    return errors;
  }
}

class DecrementCommand extends Command with ValidatableCommand, TargetedCommand {
  final String _aggregateId;
  final int value;

  DecrementCommand({
    required String aggregateId,
    required this.value,
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
    map['value'] = value;
    return map;
  }

  @override
  List<String> getCustomValidationErrors() {
    final errors = <String>[];
    if (value <= 0) {
      errors.add('Decrement value must be positive');
    }
    return errors;
  }
}

// Example Events
class CounterIncrementedEvent extends Event with AggregateEvent, SerializableEvent, VersionedEvent {
  final String _aggregateId;
  final int value;

  CounterIncrementedEvent({
    required String aggregateId,
    required this.value,
    String? eventId,
    DateTime? timestamp,
    int? version,
    Map<String, dynamic>? metadata,
  }) : _aggregateId = aggregateId,
       super(eventId: eventId, timestamp: timestamp, version: version, metadata: metadata);

  @override
  String get aggregateId => _aggregateId;

  @override
  String get aggregateType => 'Counter';

  @override
  Map<String, dynamic> getEventData() {
    return {'value': value};
  }
}

class CounterDecrementedEvent extends Event with AggregateEvent, SerializableEvent, VersionedEvent {
  final String _aggregateId;
  final int value;

  CounterDecrementedEvent({
    required String aggregateId,
    required this.value,
    String? eventId,
    DateTime? timestamp,
    int? version,
    Map<String, dynamic>? metadata,
  }) : _aggregateId = aggregateId,
       super(eventId: eventId, timestamp: timestamp, version: version, metadata: metadata);

  @override
  String get aggregateId => _aggregateId;

  @override
  String get aggregateType => 'Counter';

  @override
  Map<String, dynamic> getEventData() {
    return {'value': value};
  }
}

// Example Persistent Actor
class CounterActor extends PersistentActor {
  int _value = 0;
  int _eventCount = 0;

  CounterActor({
    required String persistenceId,
    required EventStore eventStore,
  }) : super(persistenceId: persistenceId, eventStore: eventStore);

  int get value => _value;
  int get eventCount => _eventCount;

  @override
  Future<void> commandHandler(Command command) async {
    if (command is IncrementCommand) {
      final event = CounterIncrementedEvent(
        aggregateId: persistenceId,
        value: command.value,
      );
      await persistEvent(event);
    } else if (command is DecrementCommand) {
      final event = CounterDecrementedEvent(
        aggregateId: persistenceId,
        value: command.value,
      );
      await persistEvent(event);
    }
  }

  @override
  void eventHandler(Event event) {
    _eventCount++;
    
    if (event is CounterIncrementedEvent) {
      _value += event.value;
    } else if (event is CounterDecrementedEvent) {
      _value -= event.value;
    }
  }

  @override
  Future<dynamic> getSnapshotState() async {
    return {
      'value': _value,
      'eventCount': _eventCount,
    };
  }

  @override
  Future<void> onSnapshot(dynamic snapshotState, int sequenceNumber) async {
    if (snapshotState is Map<String, dynamic>) {
      _value = snapshotState['value'] as int? ?? 0;
      _eventCount = snapshotState['eventCount'] as int? ?? 0;
    }
  }
}
