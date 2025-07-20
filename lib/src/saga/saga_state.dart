/// Represents the possible statuses of a saga.
enum SagaStatus {
  /// The saga is currently executing its workflow.
  running,

  /// The saga has completed successfully.
  completed,

  /// The saga is in the process of compensating for a failure.
  compensating,

  /// The saga has failed and could not be compensated.
  failed,
}

/// A base class for representing the state of a saga.
///
/// It includes the saga's current status and any data it needs to track
/// its progress.
abstract class SagaState {
  /// The current status of the saga.
  final SagaStatus status;

  /// The timestamp of the last update to the saga's state.
  final DateTime lastUpdated;

  SagaState({required this.status, required this.lastUpdated});

  /// Creates a copy of the state with the given fields updated.
  SagaState copyWith({SagaStatus? status, DateTime? lastUpdated});
}
