import 'dart:async';
import 'package:dactor/dactor.dart';
import 'package:duraq/duraq.dart';
import '../event.dart';
import '../storage/event_store.dart';
import '../storage/cbor_serializer.dart';
import 'projection.dart';
import 'projection_checkpoint.dart';
import 'projection_read_model.dart';
import 'projection_manager.dart';

/// Actor-based projection processor that integrates with Dactor and DuraQ.
/// 
/// This provides reliable event processing with supervision, retry policies,
/// and integration with the DuraQ operational workflow system.
abstract class ProjectionActor<TReadModel> extends Actor implements Projection<TReadModel> {
  final EventStore _eventStore;
  final QueueManager _duraqManager;
  final String _projectionId;
  
  ProjectionCheckpoint? _checkpoint;
  Timer? _batchTimer;
  final List<Event> _eventBatch = [];
  final int _batchSize;
  final Duration _batchTimeout;
  
  ProjectionActor({
    required String projectionId,
    required EventStore eventStore,
    required QueueManager duraqManager,
    int batchSize = 10,
    Duration batchTimeout = const Duration(seconds: 5),
  }) : _projectionId = projectionId,
       _eventStore = eventStore,
       _duraqManager = duraqManager,
       _batchSize = batchSize,
       _batchTimeout = batchTimeout;

  @override
  String get projectionId => _projectionId;

  /// Current projection status
  ProjectionStatus get status => _checkpoint?.status ?? ProjectionStatus.stopped;

  /// Get projection information
  ProjectionInfo get info {
    final checkpoint = _checkpoint;
    if (checkpoint == null) {
      return ProjectionInfo(
        projectionId: projectionId,
        status: ProjectionStatus.stopped,
        lastProcessedSequence: 0,
        lastUpdated: DateTime.now(),
        eventsProcessed: 0,
      );
    }
    
    return ProjectionInfo(
      projectionId: checkpoint.projectionId,
      status: checkpoint.status,
      lastProcessedSequence: checkpoint.lastProcessedSequence,
      lastUpdated: checkpoint.lastUpdated,
      eventsProcessed: checkpoint.eventsProcessed,
      averageProcessingTime: checkpoint.averageProcessingTimeMs != null
          ? Duration(milliseconds: checkpoint.averageProcessingTimeMs!)
          : null,
      lastError: checkpoint.lastError,
    );
  }

  @override
  void preStart() {
    super.preStart();
    _initializeProjection();
  }

  @override
  void postStop() {
    _batchTimer?.cancel();
    super.postStop();
  }

  @override
  Future<void> onMessage(dynamic message) async {
    try {
      if (message is Event) {
        await _handleEvent(message);
      } else if (message is ProjectionCommand) {
        await _handleCommand(message);
      } else if (message == _BatchTimeout) {
        await _processBatch();
      }
    } catch (error, stackTrace) {
      await _handleError(error, stackTrace);
    }
  }

  /// Initialize the projection by loading checkpoint and starting processing
  Future<void> _initializeProjection() async {
    try {
      await _loadCheckpoint();
      await onStart();
      await _updateStatus(ProjectionStatus.running);
      await _subscribeToEvents();
    } catch (error, stackTrace) {
      await _handleError(error, stackTrace);
    }
  }

  /// Load the projection checkpoint from storage
  Future<void> _loadCheckpoint() async {
    // This would be implemented with Isar queries
    // For now, create a default checkpoint
    _checkpoint = ProjectionCheckpoint()
      ..projectionId = projectionId
      ..status = ProjectionStatus.running
      ..lastProcessedSequence = 0
      ..eventsProcessed = 0
      ..startedAt = DateTime.now()
      ..lastUpdated = DateTime.now();
  }

  /// Subscribe to events via DuraQ
  Future<void> _subscribeToEvents() async {
    for (final eventType in interestedEventTypes) {
      final queueName = 'projection-events-${eventType.toString()}';
      final queue = _duraqManager.queue<Event>(queueName);
      
      // Process events from the queue
      unawaited(_processEventQueue(queue));
    }
  }

  /// Process events from a DuraQ queue
  Future<void> _processEventQueue(Queue<Event> queue) async {
    while (status == ProjectionStatus.running) {
      try {
        await queue.processNext((event) async {
          if (canHandle(event.runtimeType)) {
            context.self.tell(event);
          }
        });
      } catch (error) {
        // Log error and continue processing
        await Future.delayed(const Duration(seconds: 1));
      }
    }
  }

  /// Handle an incoming event
  Future<void> _handleEvent(Event event) async {
    if (!canHandle(event.runtimeType)) {
      return;
    }

    _eventBatch.add(event);
    
    if (_eventBatch.length >= _batchSize) {
      await _processBatch();
    } else {
      _resetBatchTimer();
    }
  }

  /// Handle projection commands
  Future<void> _handleCommand(ProjectionCommand command) async {
    switch (command.type) {
      case ProjectionCommandType.pause:
        await _updateStatus(ProjectionStatus.paused);
        break;
      case ProjectionCommandType.resume:
        await _updateStatus(ProjectionStatus.running);
        await _subscribeToEvents();
        break;
      case ProjectionCommandType.rebuild:
        await rebuild();
        break;
      case ProjectionCommandType.reset:
        await reset();
        break;
      case ProjectionCommandType.getInfo:
        command.completer?.complete(info);
        break;
    }
  }

  /// Process the current batch of events
  Future<void> _processBatch() async {
    if (_eventBatch.isEmpty) return;

    _batchTimer?.cancel();
    final batch = List<Event>.from(_eventBatch);
    _eventBatch.clear();

    final stopwatch = Stopwatch()..start();
    int processedCount = 0;

    try {
      for (final event in batch) {
        final handled = await handle(event);
        if (handled) {
          processedCount++;
          // Events don't have sequence numbers directly - we'll track them separately
          // For now, increment the checkpoint by 1 for each processed event
          final currentCheckpoint = await getCheckpoint();
          await updateCheckpoint(currentCheckpoint + 1);
        }
      }

      stopwatch.stop();
      await _updateProcessingStats(processedCount, stopwatch.elapsed);
      await onBatchComplete(processedCount);
      
    } catch (error, stackTrace) {
      // Re-queue failed events for retry
      await _requeueEvents(batch);
      await _handleError(error, stackTrace);
    }
  }

  /// Reset the batch timer
  void _resetBatchTimer() {
    _batchTimer?.cancel();
    _batchTimer = Timer(_batchTimeout, () {
      context.self.tell(_batchTimeoutInstance);
    });
  }

  /// Re-queue events for retry processing
  Future<void> _requeueEvents(List<Event> events) async {
    for (final event in events) {
      final queueName = 'projection-events-${event.runtimeType.toString()}';
      final queue = _duraqManager.queue<Event>(queueName);
      await queue.enqueue(event);
    }
  }

  /// Update projection status
  Future<void> _updateStatus(ProjectionStatus newStatus) async {
    if (_checkpoint != null) {
      _checkpoint!.status = newStatus;
      _checkpoint!.lastUpdated = DateTime.now();
      // Save checkpoint to storage
    }
  }

  /// Update processing statistics
  Future<void> _updateProcessingStats(int eventsProcessed, Duration elapsed) async {
    if (_checkpoint != null) {
      _checkpoint!.eventsProcessed += eventsProcessed;
      _checkpoint!.lastUpdated = DateTime.now();
      
      // Update average processing time
      final avgMs = elapsed.inMilliseconds / eventsProcessed;
      final currentAvg = _checkpoint!.averageProcessingTimeMs ?? 0;
      _checkpoint!.averageProcessingTimeMs = 
          ((currentAvg + avgMs) / 2).round();
    }
  }

  /// Handle errors during processing
  Future<void> _handleError(dynamic error, StackTrace stackTrace) async {
    await onError(error, stackTrace);
    
    if (_checkpoint != null) {
      _checkpoint!.status = ProjectionStatus.failed;
      _checkpoint!.lastError = error.toString();
      _checkpoint!.lastUpdated = DateTime.now();
    }
    
    // Notify supervisor of the error
    throw ProjectionException(
      'Projection processing failed: $error',
      projectionId,
      error,
    );
  }

  @override
  Future<int> getCheckpoint() async {
    return _checkpoint?.lastProcessedSequence ?? 0;
  }

  @override
  Future<void> updateCheckpoint(int sequenceNumber) async {
    if (_checkpoint != null && sequenceNumber > _checkpoint!.lastProcessedSequence) {
      _checkpoint!.lastProcessedSequence = sequenceNumber;
      _checkpoint!.lastUpdated = DateTime.now();
      // Save checkpoint to storage
    }
  }

  @override
  Future<void> rebuild() async {
    await _updateStatus(ProjectionStatus.rebuilding);
    
    try {
      // Reset read model
      await reset();
      
      // Replay all events from the beginning
      final events = await _eventStore.getEvents('', fromSequence: 0);
      
      // Process events sequentially and update checkpoint
      int sequenceNumber = 0;
      for (final event in events) {
        if (canHandle(event.runtimeType)) {
          await handle(event);
          sequenceNumber++;
          await updateCheckpoint(sequenceNumber);
        }
      }
      
      await _updateStatus(ProjectionStatus.running);
    } catch (error, stackTrace) {
      await _handleError(error, stackTrace);
    }
  }

  @override
  Future<void> reset() async {
    // Clear checkpoint
    if (_checkpoint != null) {
      _checkpoint!.lastProcessedSequence = 0;
      _checkpoint!.eventsProcessed = 0;
      _checkpoint!.lastUpdated = DateTime.now();
    }
    
    // Clear event batch
    _eventBatch.clear();
  }
}


/// Marker for batch timeout messages
class _BatchTimeout implements Message {
  const _BatchTimeout();
  
  @override
  String get correlationId => 'batch-timeout';
  
  @override
  ActorRef? get replyTo => null;
  
  @override
  Map<String, dynamic> get metadata => const {};
  
  @override
  DateTime get timestamp => DateTime.now();
}

const _BatchTimeout _batchTimeoutInstance = _BatchTimeout();
