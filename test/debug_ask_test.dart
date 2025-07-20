import 'dart:async';
import 'package:test/test.dart';
import 'package:dactor/dactor.dart';
import '../lib/src/command.dart';
import '../lib/src/persistent_actor.dart';
import '../lib/src/storage/event_store.dart';
import '../lib/src/event.dart';
import 'package:eventador/src/saga/saga_state_envelope.dart';

/// Simple test command
class SimpleCommand extends Command {
  final String data;

  SimpleCommand({
    required this.data,
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
    map['data'] = data;
    return map;
  }
}

/// Simple response
class SimpleResponse extends LocalMessage {
  final String result;
  
  SimpleResponse(this.result) : super(
    payload: null, // Will be overridden by getter
    sender: null,
    correlationId: 'response_${DateTime.now().millisecondsSinceEpoch}',
    replyTo: null,
    timestamp: DateTime.now(),
    metadata: {},
  );

  @override
  dynamic get payload => this; // Return the response object itself
}

/// Simple event
class SimpleEvent extends Event {
  final String data;

  SimpleEvent({
    required this.data,
    DateTime? timestamp,
    Map<String, dynamic>? metadata,
  }) : super(
    timestamp: timestamp,
    metadata: metadata,
  );

  @override
  Map<String, dynamic> toJson() => {
    'type': 'simple_event',
    'data': data,
    'timestamp': timestamp.toIso8601String(),
    'metadata': metadata,
  };
}

/// Mock event store
class SimpleEventStore implements EventStore {
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

/// Simple test actor
class SimpleActor extends PersistentActor {
  SimpleActor({
    required String persistenceId,
    required EventStore eventStore,
  }) : super(
    persistenceId: persistenceId,
    eventStore: eventStore,
  );

  @override
  Future<void> commandHandler(Command command) async {
    print('Received command: $command');
    print('Command type: ${command.runtimeType}');
    print('Context sender: ${context.sender}');
    print('Command replyTo: ${command.replyTo}');
    
    if (command is SimpleCommand) {
      // Persist an event
      await persistEvent(SimpleEvent(data: 'processed_${command.data}'));
      
      // Send response back
      final sender = context.sender;
      if (sender != null) {
        print('Sending response to sender: $sender');
        final response = SimpleResponse('success_${command.data}');
        sender.tell(response);
      } else {
        print('No sender found!');
      }
    }
  }

  @override
  void eventHandler(Event event) {
    // Handle events for state reconstruction
  }

  @override
  Future<void> queryHandler(dynamic message) async {
    // Handle non-command messages
  }
}

void main() {
  group('Debug Ask Tests', () {
    late ActorSystem actorSystem;
    late SimpleEventStore eventStore;
    late ActorRef testActorRef;

    setUp(() async {
      actorSystem = LocalActorSystem();
      eventStore = SimpleEventStore();
      
      testActorRef = await actorSystem.spawn(
        'simple_actor',
        () => SimpleActor(
          persistenceId: 'simple_actor_1',
          eventStore: eventStore,
        ),
      );
      
      // Give the actor time to initialize and recover
      await Future.delayed(Duration(milliseconds: 100));
    });

    tearDown(() async {
      await actorSystem.shutdown();
    });

    test('Simple ask test', () async {
      final command = SimpleCommand(data: 'test');
      
      print('Sending ask request...');
      try {
        final response = await testActorRef.ask<SimpleResponse>(command, Duration(seconds: 2));
        print('Received response: ${response.result}');
        
        expect(response, isA<SimpleResponse>());
        expect(response.result, 'success_test');
      } catch (e) {
        print('Ask failed with error: $e');
        rethrow;
      }
    });
  });
}
