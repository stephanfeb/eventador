import 'package:test/test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:duraq/duraq.dart';
import 'package:eventador/src/storage/event_store.dart';
import 'package:eventador/src/saga/saga.dart';
import 'package:eventador/src/saga/saga_state.dart';
import 'package:eventador/src/saga/saga_timeout.dart';
import 'package:eventador/src/saga/saga_command_envelope.dart';
import 'package:eventador/src/command.dart';
import 'package:eventador/src/event.dart';
import 'phase3_week7_test.mocks.dart';

@GenerateNiceMocks([
  MockSpec<EventStore>(),
  MockSpec<StorageInterface>(),
  MockSpec<Command>(),
  MockSpec<Event>(),
  MockSpec<SagaState>(),
])
// Concrete Saga for testing
class TestSaga extends Saga {
  @override
  final SagaState sagaState;

  TestSaga({
    required String persistenceId,
    required EventStore eventStore,
    required QueueManager duraqManager,
    required this.sagaState,
  }) : super(
          persistenceId: persistenceId,
          eventStore: eventStore,
          duraqManager: duraqManager,
        );

  @override
  Future<void> compensate(List<Event> eventsToCompensate) async {}

  @override
  Future<void> handleSagaEvent(Event event) async {}

  @override
  Future<void> startSaga(Command initialCommand) async {}

  @override
  Future<void> commandHandler(Command command) async {}

  @override
  void eventHandler(Event event) {}
}

void main() {
  group('Saga', () {
    late MockEventStore mockEventStore;
    late QueueManager duraqManager;
    late MockStorageInterface mockStorage;
    late TestSaga saga;

    setUp(() {
      mockEventStore = MockEventStore();
      mockStorage = MockStorageInterface();
      duraqManager = QueueManager(mockStorage);

      // Stub the store method to avoid null issues on the Future<void> return
      when(mockStorage.store(any, any)).thenAnswer((_) async {});

      saga = TestSaga(
        persistenceId: 'test-saga-1',
        eventStore: mockEventStore,
        duraqManager: duraqManager,
        sagaState: MockSagaState(),
      );
    });

    test('sendCommand uses DuraQ to enqueue command', () async {
      final command = MockCommand();
      when(command.commandId).thenReturn('cmd-1');
      await saga.sendCommand('actor-1', command);

      final captured =
          verify(mockStorage.store('saga-commands', captureAny)).captured.single
              as QueueEntry;
      expect(captured.data, isA<SagaCommandEnvelope>());
      final envelope = captured.data as SagaCommandEnvelope;
      expect(envelope.targetActorId, equals('actor-1'));
      expect(envelope.command, equals(command));
    });

    test('scheduleTimeout uses DuraQ to enqueue scheduled entry', () async {
      final timeoutId = 'timeout-1';
      final delay = Duration(seconds: 30);

      await saga.scheduleTimeout(delay, timeoutId);

      final captured =
          verify(mockStorage.store('saga-timeouts', captureAny)).captured.single
              as QueueEntry;
      expect(captured.id, timeoutId);
      expect((captured.data as SagaTimeout).sagaId, 'test-saga-1');
      expect(captured.scheduledFor, isA<DateTime>());
    });
  });
}
