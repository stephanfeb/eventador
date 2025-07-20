# Guide: Testing Persistent Actors and Sagas

This guide provides best practices for testing your event-sourced systems in Eventador.

## 1. Introduction

### Why is Testing Important?

Testing is a critical part of building robust and reliable systems. For event-sourced systems, testing is particularly important to ensure that your business logic is correct and that your actors can recover their state correctly.

## 2. Unit Testing

### Testing Command Handlers

You can unit test your `commandHandler` methods by creating an instance of your actor and sending it a command. You can then use a mock `EventStore` to verify that the correct events were persisted.

```dart
test('should persist event on command', () async {
  final eventStore = MockEventStore();
  final actor = MyActor(
    persistenceId: 'my-actor',
    eventStore: eventStore,
  );

  await actor.commandHandler(MyCommand(value: 42));

  expect(eventStore.persistedEvents, hasLength(1));
  expect(eventStore.persistedEvents.first, isA<MyEvent>());
});
```

### Testing Event Handlers

You can unit test your `eventHandler` methods by creating an instance of your actor and calling the method directly with an event. You can then verify that the actor's state was updated correctly.

```dart
test('should update state on event', () {
  final actor = MyActor(
    persistenceId: 'my-actor',
    eventStore: MockEventStore(),
  );

  actor.eventHandler(MyEvent(value: 42));

  expect(actor.state.value, equals(42));
});
```

## 3. Integration Testing

### Testing Recovery and Snapshotting

You can test your actor's recovery and snapshotting logic by using an in-memory `EventStore` and simulating a restart.

```dart
test('should recover state after restart', () async {
  final eventStore = await IsarEventStore.create(directory: null); // In-memory
  var actor = MyActor(
    persistenceId: 'my-actor',
    eventStore: eventStore,
  );

  // Persist an event
  await actor.commandHandler(MyCommand(value: 42));

  // Simulate a restart
  actor = MyActor(
    persistenceId: 'my-actor',
    eventStore: eventStore,
  );
  await actor.preStart(); // Triggers recovery

  expect(actor.state.value, equals(42));
});
```

## 4. Testing Sagas

Testing sagas is more complex, as it involves multiple actors and asynchronous messages. You can use a similar approach to integration testing, using a mock `QueueManager` to verify that the correct commands are sent.

## 5. Conclusion

By following these testing practices, you can build robust and reliable event-sourced systems with Eventador.
