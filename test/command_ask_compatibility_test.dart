import 'dart:async';
import 'package:test/test.dart';
import 'package:dactor/dactor.dart';
import '../lib/src/command.dart';
import '../lib/src/persistent_actor.dart';
import '../lib/src/storage/event_store.dart';
import '../lib/src/event.dart';
import 'package:eventador/src/saga/saga_state_envelope.dart';

/// Test command to verify ask() compatibility
class TestCommand extends Command {
  final String testData;

  TestCommand({
    required this.testData,
    String? commandId,
    DateTime? timestamp,
    Map<String, dynamic>? metadata,
    ActorRef? replyTo,
    ActorRef? sender,
  }) : super(
    commandId: commandId,
    timestamp: timestamp,
    metadata: metadata,
    replyTo: replyTo,
    sender: sender,
  );

  @override
  Map<String, dynamic> toMap() {
    final map = super.toMap();
    map['testData'] = testData;
    return map;
  }
}

/// Test response message
class TestResponse extends LocalMessage {
  final String result;

  TestResponse({
    required this.result,
    ActorRef? sender,
    String? correlationId,
    ActorRef? replyTo,
    DateTime? timestamp,
    Map<String, dynamic>? metadata,
  }) : super(
    payload: null, // Will be overridden by getter
    sender: sender,
    correlationId: correlationId ?? 'response_${DateTime.now().millisecondsSinceEpoch}',
    replyTo: replyTo,
    timestamp: timestamp ?? DateTime.now(),
    metadata: metadata ?? {},
  );

  @override
  dynamic get payload => this; // Return the response object itself
}

/// Test event
class TestEvent extends Event {
  final String data;

  TestEvent({
    required this.data,
    DateTime? timestamp,
    Map<String, dynamic>? metadata,
  }) : super(
    timestamp: timestamp,
    metadata: metadata,
  );

  @override
  Map<String, dynamic> toJson() => {
    'type': 'test_event',
    'data': data,
    'timestamp': timestamp.toIso8601String(),
    'metadata': metadata,
  };
}

/// Mock event store for testing
class MockEventStore implements EventStore {
  final List<Event> _events = [];

  @override
  Future<void> persistEvent(String persistenceId, Event event, int expectedVersion) async {
    _events.add(event);
  }

  @override
  Future<void> persistEvents(String persistenceId, List<Event> events, int expectedVersion) async {
    _events.addAll(events);
  }

  @override
  Future<List<Event>> getEvents(String persistenceId, {int fromSequence = 0, int? toSequence}) async {
    return _events;
  }

  @override
  Future<int> getHighestSequenceNumber(String persistenceId) async {
    return _events.length;
  }

  @override
  Future<void> saveSnapshot(String persistenceId, dynamic state, int sequenceNumber) async {}

  @override
  Future<SnapshotData?> loadSnapshot(String persistenceId) async {
    return null;
  }

  @override
  Future<void> deleteOldSnapshots(String persistenceId, int keepCount) async {}

  @override
  Future<void> saveSagaState(SagaStateEnvelope envelope) async {}

  @override
  Future<SagaStateEnvelope?> loadSagaState(String persistenceId) async {
    return null;
  }

  @override
  Future<void> close() async {}
}

/// Test actor that handles TestCommand
class TestActor extends PersistentActor {
  TestActor({
    required String persistenceId,
    required EventStore eventStore,
  }) : super(
    persistenceId: persistenceId,
    eventStore: eventStore,
  );

  @override
  Future<void> commandHandler(Command command) async {
    if (command is TestCommand) {
      // Persist an event
      await persistEvent(TestEvent(data: 'processed_${command.testData}'));
      
      // Send response back for ask() operations
      // Use context.sender which is set by Dactor's ask mechanism
      final sender = context.sender;
      if (sender != null) {
        final response = TestResponse(result: 'success_${command.testData}');
        sender.tell(response);
      }
    }
  }

  @override
  void eventHandler(Event event) {
    // Handle events for state reconstruction
    if (event is TestEvent) {
      // Update internal state based on event
    }
  }

  @override
  Future<void> queryHandler(dynamic message) async {
    // Handle non-command messages
    if (message is String && message == 'ping') {
      final sender = context.sender;
      if (sender != null) {
        sender.tell(LocalMessage(payload: 'pong'));
      }
    }
  }
}

/// Non-responsive actor that doesn't send responses (for timeout testing)
class NonResponsiveActor extends PersistentActor {
  NonResponsiveActor({
    required String persistenceId,
    required EventStore eventStore,
  }) : super(
    persistenceId: persistenceId,
    eventStore: eventStore,
  );

  @override
  Future<void> commandHandler(Command command) async {
    if (command is TestCommand) {
      // Persist an event but don't send a response
      await persistEvent(TestEvent(data: 'processed_${command.testData}'));
      // Intentionally not sending a response to test timeout behavior
    }
  }

  @override
  void eventHandler(Event event) {
    // Handle events for state reconstruction
    if (event is TestEvent) {
      // Update internal state based on event
    }
  }

  @override
  Future<void> queryHandler(dynamic message) async {
    // Handle non-command messages but don't respond
  }
}

void main() {
  group('Command Ask Compatibility Tests', () {
    late ActorSystem actorSystem;
    late MockEventStore eventStore;
    late ActorRef testActorRef;

    setUp(() async {
      actorSystem = LocalActorSystem();
      eventStore = MockEventStore();
      
      testActorRef = await actorSystem.spawn(
        'test_actor',
        () => TestActor(
          persistenceId: 'test_actor_1',
          eventStore: eventStore,
        ),
      );
      
      // Give the actor time to initialize and recover
      await Future.delayed(Duration(milliseconds: 100));
    });

    tearDown(() async {
      await actorSystem.shutdown();
    });

    test('Command should work with tell() method', () async {
      final command = TestCommand(testData: 'tell_test');
      
      // This should not throw
      testActorRef.tell(command);
      
      // Give time for processing
      await Future.delayed(Duration(milliseconds: 50));
      
      // Verify event was persisted
      expect(eventStore._events.length, 1);
      expect((eventStore._events.first as TestEvent).data, 'processed_tell_test');
    });

    test('Command should work with ask() method', () async {
      final command = TestCommand(testData: 'ask_test');
      
      // This should not throw and should return a response
      final response = await testActorRef.ask<TestResponse>(command, Duration(seconds: 1));
      
      expect(response, isA<TestResponse>());
      expect(response.result, 'success_ask_test');
      
      // Verify event was persisted
      expect(eventStore._events.length, 1);
      expect((eventStore._events.first as TestEvent).data, 'processed_ask_test');
    });

    test('Command should be instance of LocalMessage', () {
      final command = TestCommand(testData: 'instance_test');
      
      // Verify that Command extends LocalMessage
      expect(command, isA<LocalMessage>());
      expect(command, isA<Message>());
      
      // Verify LocalMessage properties are accessible
      expect(command.correlationId, isNotEmpty);
      expect(command.timestamp, isA<DateTime>());
      expect(command.metadata, isA<Map<String, dynamic>>());
      expect(command.payload, equals(command)); // payload should return the command itself
    });

    test('Command should maintain all original functionality', () {
      final command = TestCommand(
        testData: 'functionality_test',
        commandId: 'custom_id',
        metadata: {'custom': 'value'},
      );
      
      // Verify Command-specific properties
      expect(command.commandId, 'custom_id');
      expect(command.testData, 'functionality_test');
      expect(command.metadata['custom'], 'value');
      
      // Verify serialization works
      final map = command.toMap();
      expect(map['commandId'], 'custom_id');
      expect(map['testData'], 'functionality_test');
      expect(map['type'], 'TestCommand');
    });

    test('Multiple ask() calls should work concurrently', () async {
      final futures = List.generate(5, (index) {
        final command = TestCommand(testData: 'concurrent_$index');
        return testActorRef.ask<TestResponse>(command, Duration(seconds: 1));
      });
      
      final responses = await Future.wait(futures);
      
      expect(responses.length, 5);
      for (int i = 0; i < responses.length; i++) {
        expect(responses[i].result, 'success_concurrent_$i');
      }
      
      // Verify all events were persisted
      expect(eventStore._events.length, 5);
    });

    test('Ask timeout should work correctly', () async {
      // Create a non-responsive actor that doesn't send responses
      final nonResponsiveActor = await actorSystem.spawn(
        'non_responsive',
        () => NonResponsiveActor(
          persistenceId: 'non_responsive',
          eventStore: eventStore,
        ),
      );
      
      // Give the actor time to initialize
      await Future.delayed(Duration(milliseconds: 100));
      
      final command = TestCommand(testData: 'timeout_test');
      
      // This should timeout since the actor doesn't respond
      expect(
        () => nonResponsiveActor.ask<TestResponse>(command, Duration(milliseconds: 100)),
        throwsA(isA<TimeoutException>()),
      );
    });
  });
}
