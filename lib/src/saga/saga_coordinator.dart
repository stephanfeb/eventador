import 'package:dactor/dactor.dart';
import 'package:duraq/duraq.dart';
import 'package:eventador/src/saga/saga_command_envelope.dart';
import 'package:eventador/src/saga/saga_timeout.dart';
import 'package:eventador/src/storage/event_store.dart';

/// Coordinates the operational aspects of sagas using DuraQ.
///
/// This class is responsible for processing commands and timeouts from reliable
/// queues and delivering them to the appropriate saga actors.
///
/// ### Orchestration
/// The `SagaCoordinator` is not an actor and should not be spawned. Instead, it
/// should be instantiated as a plain class, and its `processSagaCommands` and
/// `processSagaTimeouts` methods should be run as background tasks. This is
/// typically done using `unawaited` from `dart:async`.
///
/// #### Example:
/// ```dart
/// final sagaCoordinator = SagaCoordinator(duraqManager, eventStore, actorSystem);
/// unawaited(sagaCoordinator.processSagaCommands());
/// unawaited(sagaCoordinator.processSagaTimeouts());
/// ```
class SagaCoordinator {
  final QueueManager _duraqManager;
  final EventStore _eventStore;
  final ActorSystem _actorSystem;

  SagaCoordinator(this._duraqManager, this._eventStore, this._actorSystem);

  /// Processes saga commands from the 'saga-commands' queue.
  ///
  /// This method should be run in a background process to continuously
  /// deliver commands with DuraQ's reliability and retry policies.
  Future<void> processSagaCommands() async {
    final commandQueue =
        _duraqManager.queue<SagaCommandEnvelope>('saga-commands');

    await commandQueue.processNext((envelope) async {
      final actorRef = _actorSystem.getActor(envelope.targetActorId);
      if (actorRef != null) {
        actorRef.tell(envelope.command);
      } else {
        // TODO: Implement dead-letter queue handling for failed delivery.
        print(
            'Actor not found for command: ${envelope.command.commandId}, target: ${envelope.targetActorId}');
      }
    });
  }

  /// Processes saga timeouts from the 'saga-timeouts' queue.
  ///
  /// This method should be run in a background process to handle scheduled
  /// timeouts.
  Future<void> processSagaTimeouts() async {
    final timeoutQueue = _duraqManager.queue<SagaTimeout>('saga-timeouts');

    await timeoutQueue.processNext((timeout) async {
      final sagaRef = _actorSystem.getActor(timeout.sagaId);
      if (sagaRef != null) {
        sagaRef.tell(timeout);
      } else {
        // TODO: Implement dead-letter queue handling for failed delivery.
        print('Saga not found for timeout: ${timeout.timeoutId}');
      }
    });
  }
}
