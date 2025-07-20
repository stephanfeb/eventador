import 'dart:async';
import 'dart:io';
import 'package:dactor/dactor.dart';
import 'package:duraq/duraq.dart';
import 'package:eventador/eventador.dart';
import 'package:isar/isar.dart';

// #############################################################################
// 1. Define Commands
// #############################################################################

class CreateOrder extends Command {
  final String aggregateId;
  final String customerId;
  final double amount;

  CreateOrder({
    required this.aggregateId,
    required this.customerId,
    required this.amount,
  }) : super();
}

class ProcessPayment extends Command {
  final String aggregateId;
  final double amount;

  ProcessPayment({required this.aggregateId, required this.amount}) : super();
}

class ShipOrder extends Command {
  final String aggregateId;
  final String address;

  ShipOrder({required this.aggregateId, required this.address}) : super();
}

// #############################################################################
// 2. Define Events
// #############################################################################

class OrderCreated extends Event {
  final String orderId;
  final String customerId;
  final double amount;

  OrderCreated({
    required this.orderId,
    required this.customerId,
    required this.amount,
  });
}

class PaymentProcessed extends Event {
  final String orderId;
  final String transactionId;

  PaymentProcessed({required this.orderId, required this.transactionId});
}

class OrderShipped extends Event {
  final String orderId;
  final String trackingNumber;

  OrderShipped({required this.orderId, required this.trackingNumber});
}

class OrderFailed extends Event {
  final String orderId;
  final String reason;

  OrderFailed({required this.orderId, required this.reason});
}

// #############################################################################
// 3. Define Saga State
// #############################################################################

class OrderSagaState extends SagaState {
  final String orderId;
  final String customerId;
  final double amount;
  final bool paymentProcessed;
  final bool orderShipped;

  OrderSagaState({
    required this.orderId,
    required this.customerId,
    required this.amount,
    required super.status,
    required super.lastUpdated,
    this.paymentProcessed = false,
    this.orderShipped = false,
  });

  @override
  OrderSagaState copyWith({
    SagaStatus? status,
    DateTime? lastUpdated,
    bool? paymentProcessed,
    bool? orderShipped,
  }) {
    return OrderSagaState(
      orderId: orderId,
      customerId: customerId,
      amount: amount,
      status: status ?? this.status,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      paymentProcessed: paymentProcessed ?? this.paymentProcessed,
      orderShipped: orderShipped ?? this.orderShipped,
    );
  }
}

// #############################################################################
// 4. Define the Saga
// #############################################################################

class OrderSaga extends Saga {
  late OrderSagaState _state;

  OrderSaga({
    required String persistenceId,
    required EventStore eventStore,
    required QueueManager duraqManager,
  }) : super(
            persistenceId: persistenceId,
            eventStore: eventStore,
            duraqManager: duraqManager);

  @override
  SagaState get sagaState => _state;

  @override
  void preStart() {
    super.preStart();
    // Subscribe to events that this saga is interested in.
    context.system.eventBus
        .subscribe(context.self);
  }

  @override
  Future<void> commandHandler(Command command) async {
    if (command is CreateOrder) {
      await startSaga(command);
    }
  }

  @override
  void eventHandler(Event event) {
    handleSagaEvent(event);
  }

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
          address: '123 Main St', // Dummy address
        ),
      );
    } else if (event is OrderShipped) {
      _state = _state.copyWith(
        orderShipped: true,
        status: SagaStatus.completed,
      );
      await saveSagaState();
      print('Saga for order ${_state.orderId} completed successfully!');
    } else if (event is OrderFailed) {
      _state = _state.copyWith(status: SagaStatus.failed);
      await saveSagaState();
      print('Saga for order ${_state.orderId} failed: ${event.reason}');
    }
  }

  @override
  Future<void> compensate(List<Event> eventsToCompensate) async {
    // Implement compensation logic here
  }
}

// #############################################################################
// 5. Define Actors
// #############################################################################

class PaymentProcessor extends Actor {
  @override
  Future<void> onMessage(dynamic message) async {
    if (message is ProcessPayment) {
      print('Processing payment for order ${message.aggregateId}');
      // Simulate payment processing
      await Future.delayed(const Duration(seconds: 1));
      final event = PaymentProcessed(
        orderId: message.aggregateId,
        transactionId: 'txn_123',
      );
      // Publish the event to the system event bus
      context.system.eventBus.publish(event);
    }
  }
}

class ShippingProcessor extends Actor {
  @override
  Future<void> onMessage(dynamic message) async {
    if (message is ShipOrder) {
      print('Shipping order ${message.aggregateId}');
      // Simulate shipping
      await Future.delayed(const Duration(seconds: 1));
      final event = OrderShipped(
        orderId: message.aggregateId,
        trackingNumber: 'trk_456',
      );
      // Publish the event to the system event bus
      context.system.eventBus.publish(event);
    }
  }
}

// #############################################################################
// 6. Main execution
// #############################################################################

Future<void> main() async {

  final tempDir = Directory.systemTemp.createTempSync('isar_test_').path;

  // Initialize Isar core
  await Isar.initializeIsarCore(download: true);

  // Create Isar instance with required schemas from both IsarStorage and IsarEventStore
  final isar = await Isar.open(
    [...IsarStorage.requiredSchemas, ...IsarEventStore.requiredSchemas],
    directory: tempDir,
    name: 'tmp_queue',
  );
  final storage = await IsarStorage(isar);
  // Initialize Duraq
  final duraqManager = QueueManager(storage);

  // Initialize Eventador with external Isar instance
  final eventStore = IsarEventStore(isar);
  final actorSystem = LocalActorSystem();

  // The SagaCoordinator is a background processor, not an actor. It's
  // responsible for dequeuing commands and timeouts and delivering them to the
  // appropriate saga instances.
  //
  // We run its processing methods in the background using `unawaited`.
  final sagaCoordinator = SagaCoordinator(duraqManager, eventStore, actorSystem);
  unawaited(sagaCoordinator.processSagaCommands());
  unawaited(sagaCoordinator.processSagaTimeouts());

  // Spawn worker actors
  await actorSystem.spawn('payment_processor', () => PaymentProcessor());
  await actorSystem.spawn('shipping_processor', () => ShippingProcessor());

  // Start the saga
  final orderId = 'order_123';
  final createOrderCommand = CreateOrder(
    aggregateId: orderId,
    customerId: 'customer_456',
    amount: 99.99,
  );

  // Spawn the saga actor
  final saga = await actorSystem.spawn(
    orderId,
    () => OrderSaga(
      persistenceId: orderId,
      eventStore: eventStore,
      duraqManager: duraqManager,
    ),
  );

  print('Starting saga for order $orderId...');
  saga.tell(createOrderCommand);

  // Wait for the saga to complete
  print('Waiting for saga to complete...');
  await Future.delayed(const Duration(seconds: 5));

  // Clean up
  print('Shutting down...');
  await actorSystem.shutdown();
  await isar.close(deleteFromDisk: true);
  print('Example finished.');
}
