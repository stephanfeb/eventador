import 'package:eventador/src/command.dart';

/// A wrapper for commands sent by a saga to ensure reliable delivery
/// to a specific target actor via DuraQ.
class SagaCommandEnvelope {
  /// The persistence ID of the target actor.
  final String targetActorId;

  /// The command to be delivered.
  final Command command;

  SagaCommandEnvelope({
    required this.targetActorId,
    required this.command,
  });
}
