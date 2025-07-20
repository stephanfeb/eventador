import '../event.dart';
import 'projection_checkpoint.dart';

/// Base interface for event projections that build read models from events.
/// 
/// Projections are responsible for:
/// - Processing events to build read models
/// - Maintaining projection state and checkpoints
/// - Supporting rebuild and reset operations
/// - Providing query interfaces for read models
abstract class Projection<TReadModel> {
  /// Unique identifier for this projection
  String get projectionId;
  
  /// The current read model state
  TReadModel get readModel;
  
  /// List of event types this projection is interested in
  List<Type> get interestedEventTypes;
  
  /// Process an event and update the read model
  /// Returns true if the event was handled, false if ignored
  Future<bool> handle(Event event);
  
  /// Rebuild the projection from scratch by replaying all events
  Future<void> rebuild();
  
  /// Reset the projection state and clear all data
  Future<void> reset();
  
  /// Get the current checkpoint (last processed sequence number)
  Future<int> getCheckpoint();
  
  /// Update the checkpoint after processing events
  Future<void> updateCheckpoint(int sequenceNumber);
  
  /// Check if this projection can handle the given event type
  bool canHandle(Type eventType) {
    return interestedEventTypes.contains(eventType);
  }
  
  /// Lifecycle hook called when projection starts
  Future<void> onStart() async {}
  
  /// Lifecycle hook called when projection stops
  Future<void> onStop() async {}
  
  /// Lifecycle hook called when an error occurs during processing
  Future<void> onError(dynamic error, StackTrace stackTrace) async {}
  
  /// Lifecycle hook called when projection completes a batch of events
  Future<void> onBatchComplete(int eventsProcessed) async {}
}


/// Information about a projection's current state
class ProjectionInfo {
  final String projectionId;
  final ProjectionStatus status;
  final int lastProcessedSequence;
  final DateTime lastUpdated;
  final int eventsProcessed;
  final Duration? averageProcessingTime;
  final String? lastError;
  
  const ProjectionInfo({
    required this.projectionId,
    required this.status,
    required this.lastProcessedSequence,
    required this.lastUpdated,
    required this.eventsProcessed,
    this.averageProcessingTime,
    this.lastError,
  });
  
  @override
  String toString() {
    return 'ProjectionInfo(id: $projectionId, status: $status, '
           'lastSequence: $lastProcessedSequence, processed: $eventsProcessed)';
  }
}

/// Exception thrown when projection operations fail
class ProjectionException implements Exception {
  final String message;
  final String projectionId;
  final dynamic cause;
  
  const ProjectionException(this.message, this.projectionId, [this.cause]);
  
  @override
  String toString() {
    final causeStr = cause != null ? ' (caused by: $cause)' : '';
    return 'ProjectionException[$projectionId]: $message$causeStr';
  }
}
