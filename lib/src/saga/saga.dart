import 'package:dactor/dactor.dart';
import 'package:duraq/duraq.dart';
import 'package:dactor/dactor.dart';
import 'package:duraq/duraq.dart';
import 'package:eventador/src/command.dart';
import 'package:eventador/src/event.dart';
import 'package:eventador/src/persistent_actor.dart';
import 'package:eventador/src/saga/saga_command_envelope.dart';
import 'package:eventador/src/saga/saga_state.dart';
import 'package:eventador/src/saga/saga_state_envelope.dart';
import 'package:eventador/src/saga/saga_timeout.dart';
import 'package:eventador/src/storage/cbor_serializer.dart';

/// A base class for implementing Sagas, which are long-running process managers
/// that coordinate actions between multiple actors or services.
///
/// Sagas are persistent actors that use DuraQ for reliable command delivery,
/// timeouts, and compensation actions.
abstract class Saga extends PersistentActor {
  /// The DuraQ queue manager for reliable operational workflows.
  final QueueManager duraqManager;

  Saga({
    required super.persistenceId,
    required super.eventStore,
    required this.duraqManager,
    super.snapshotManager,
  });

  /// The current state of the saga.
  SagaState get sagaState;

  /// Starts the saga with an initial command.
  ///
  /// This method is called to begin the saga's workflow.
  Future<void> startSaga(Command initialCommand);

  /// Saves the current state of the saga to the event store.
  Future<void> saveSagaState() async {
    final stateData = CborSerializer.serializeState(sagaState);

    final envelope = SagaStateEnvelope()
      ..persistenceId = persistenceId
      ..stateData = stateData
      ..stateType = sagaState.runtimeType.toString()
      ..status = SagaStatus.values.byName((sagaState.status as dynamic).name)
      ..lastUpdatedAt = DateTime.now();

    await eventStore.saveSagaState(envelope);
  }

  /// Loads the saga's state from the event store.
  Future<void> loadSagaState() async {
    final envelope = await eventStore.loadSagaState(persistenceId);
    if (envelope != null) {
      final state = CborSerializer.deserializeState(
          envelope.stateData, envelope.stateType);
      // TODO: Find a way to apply the loaded state to the saga instance.
      // This might require making sagaState mutable or using a different pattern.
    }
  }

  /// Handles an event that is relevant to the saga's workflow.
  ///
  /// Sagas subscribe to events from other actors to advance their state.
  Future<void> handleSagaEvent(Event event);

  /// Initiates compensation actions to revert the saga's transactions.
  ///
  /// This is called when a step in the saga fails and the process needs to be
  /// rolled back.
  Future<void> compensate(List<Event> eventsToCompensate);

  /// Sends a command to a target actor using DuraQ for reliable delivery.
  ///
  /// The command is enqueued in a persistent queue and will be delivered with
  /// retry policies.
  Future<void> sendCommand(String actorId, Command command) async {
    final envelope =
        SagaCommandEnvelope(targetActorId: actorId, command: command);
    final commandQueue =
        duraqManager.queue<SagaCommandEnvelope>('saga-commands');
    await commandQueue.enqueue(envelope);
  }

  /// Schedules a timeout message to be delivered back to the saga after a delay.
  ///
  /// This uses DuraQ's scheduled execution feature to ensure the timeout is
  /// delivered reliably, even if the system restarts.
  Future<void> scheduleTimeout(Duration delay, String timeoutId) async {
    final timeoutQueue = duraqManager.queue<SagaTimeout>('saga-timeouts');
    final entry = QueueEntry<SagaTimeout>(
      id: timeoutId,
      data: SagaTimeout(sagaId: persistenceId, timeoutId: timeoutId),
      createdAt: DateTime.now(),
      scheduledFor: DateTime.now().add(delay),
    );
    await timeoutQueue.enqueueEntry(entry);
  }
}
