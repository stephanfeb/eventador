import 'package:dactor/dactor.dart';

/// A message used to signal a timeout within a saga.
///
/// This is typically scheduled and sent by DuraQ to trigger time-based logic
/// in a saga, such as escalating a process that has not completed within
/// a specified time.
class SagaTimeout implements Message {
  /// The persistence ID of the saga that this timeout belongs to.
  final String sagaId;

  /// A unique identifier for this specific timeout, allowing a saga to handle
  /// multiple distinct timeouts.
  final String timeoutId;

  @override
  final DateTime timestamp;

  @override
  final Map<String, dynamic> metadata;

  SagaTimeout({
    required this.sagaId,
    required this.timeoutId,
    DateTime? timestamp,
    Map<String, dynamic>? metadata,
  })  : timestamp = timestamp ?? DateTime.now(),
        metadata = metadata ?? {};

  @override
  String get correlationId => timeoutId;

  @override
  ActorRef? get replyTo => null;
}
