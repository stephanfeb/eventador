# Guide: Orchestrating Sagas for Distributed Transactions

This guide provides a deep dive into the Saga pattern and how to implement it in Eventador to manage long-running, distributed transactions.

## 1. Introduction

### What is the Saga Pattern?

A saga is a sequence of local transactions where each transaction updates the database and publishes a message or event to trigger the next transaction in the sequence. If a local transaction fails because it violates a business rule, the saga executes a series of compensating transactions that undo the changes that were made by the preceding transactions.

### Why use Sagas?

In a distributed system, it is often not possible to use traditional atomic (ACID) transactions that span multiple services. Sagas provide a mechanism for maintaining data consistency across services without relying on distributed transactions.

## 2. Creating a Saga

To create a saga, you need to extend the `Saga` base class:

```dart
class MySaga extends Saga {
  MySaga({
    required String persistenceId,
    required EventStore eventStore,
    required QueueManager duraqManager,
  }) : super(
    persistenceId: persistenceId,
    eventStore: eventStore,
    duraqManager: duraqManager,
  );

  // ... implementation ...
}
```

The key components are:

*   `persistenceId`: A unique identifier for the saga instance.
*   `eventStore`: Used to persist the saga's state.
*   `duraqManager`: Used to send commands to other actors and to schedule timeouts.

## 3. Defining the Saga State

The saga's state is stored in a `SagaState` object. You should create a custom state class that extends `SagaState` and contains the data that the saga needs to track.

```dart
class MySagaState extends SagaState {
  final String orderId;
  final bool paymentProcessed;

  MySagaState({
    required this.orderId,
    this.paymentProcessed = false,
    required super.status,
    required super.lastUpdated,
  });

  @override
  MySagaState copyWith({
    SagaStatus? status,
    DateTime? lastUpdated,
    bool? paymentProcessed,
  }) {
    return MySagaState(
      orderId: orderId,
      paymentProcessed: paymentProcessed ?? this.paymentProcessed,
      status: status ?? this.status,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }
}
```

## 4. Starting the Saga

The `startSaga` method is called when the saga is first created. It is responsible for initializing the saga's state and sending the first command.

```dart
@override
Future<void> startSaga(Command initialCommand) async {
  if (initialCommand is CreateOrder) {
    _state = MySagaState(
      orderId: initialCommand.aggregateId,
      status: SagaStatus.running,
      lastUpdated: DateTime.now(),
    );
    await saveSagaState();
    await sendCommand('payment_processor', ProcessPayment(
      aggregateId: _state.orderId,
      amount: initialCommand.amount,
    ));
  }
}
```

## 5. Handling Events

The `handleSagaEvent` method is called when the saga receives an event that it is interested in. It is responsible for updating the saga's state and sending the next command.

```dart
@override
Future<void> handleSagaEvent(Event event) async {
  if (event is PaymentProcessed) {
    _state = _state.copyWith(paymentProcessed: true);
    await saveSagaState();
    await sendCommand('shipping_processor', ShipOrder(
      aggregateId: _state.orderId,
      address: '123 Main St',
    ));
  } else if (event is OrderShipped) {
    _state = _state.copyWith(status: SagaStatus.completed);
    await saveSagaState();
  }
}
```

## 6. Handling Timeouts and Compensation

Sagas can also handle timeouts and execute compensating transactions to undo previous actions. This is a more advanced topic that will be covered in a future guide.

## 7. Full Example

Here is a complete example of an `OrderProcessingSaga`:

```dart
import 'package:eventador/eventador.dart';

// ... (Commands, Events, and Actors defined elsewhere)

class OrderSaga extends Saga {
  late OrderSagaState _state;

  OrderSaga({
    required String persistenceId,
    required EventStore eventStore,
    required QueueManager duraqManager,
  }) : super(
    persistenceId: persistenceId,
    eventStore: eventStore,
    duraqManager: duraqManager,
  );

  @override
  SagaState get sagaState => _state;

  @override
  Future<void> startSaga(Command initialCommand) async {
    if (initialCommand is CreateOrder) {
      _state = OrderSagaState(
        orderId: initialCommand.aggregateId,
        customerId: initialCommand.customerId,
        amount: initialCommand.amount,
        status: SagaStatus.running,
        lastUpdated: DateTime.now(),
      );
      await saveSagaState();
      final command = ProcessPayment(
        aggregateId: _state.orderId,
        amount: _state.amount,
      );
      await sendCommand('payment_processor', command);
    }
  }

  @override
  Future<void> handleSagaEvent(Event event) async {
    if (event is PaymentProcessed) {
      _state = _state.copyWith(paymentProcessed: true);
      await saveSagaState();
      await sendCommand(
        'shipping_processor',
        ShipOrder(
          aggregateId: _state.orderId,
          address: '123 Main St',
        ),
      );
    } else if (event is OrderShipped) {
      _state = _state.copyWith(status: SagaStatus.completed);
      await saveSagaState();
    }
  }
}
