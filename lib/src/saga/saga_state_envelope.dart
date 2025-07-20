import 'package:isar/isar.dart';
import 'package:eventador/src/saga/saga_state.dart';

part 'saga_state_envelope.g.dart';

/// An Isar collection to store the persistent state of a saga.
@collection
class SagaStateEnvelope {
  Id id = Isar.autoIncrement;

  /// The persistence ID of the saga, used for unique identification.
  @Index(unique: true)
  late String persistenceId;

  /// The CBOR-encoded state of the saga.
  late List<int> stateData;

  /// The fully qualified type name of the saga state.
  late String stateType;

  /// The current status of the saga (e.g., running, completed).
  @enumerated
  late SagaStatus status;

  /// The timestamp of the last update.
  late DateTime lastUpdatedAt;
}
