import 'dart:async';
import 'package:dactor/dactor.dart';
import 'package:duraq/duraq.dart';
import '../event.dart';
import '../storage/event_store.dart';
import 'projection.dart';
import 'projection_checkpoint.dart';

/// Manages multiple projections and coordinates event routing via DuraQ.
/// 
/// The ProjectionManager is responsible for:
/// - Registering and managing projection actors
/// - Routing events to interested projections via DuraQ queues
/// - Coordinating projection catch-up and rebuild operations
/// - Monitoring projection health and performance
class ProjectionManager {
  final QueueManager _duraqManager;
  final EventStore _eventStore;
  final ActorSystem _actorSystem;
  final Map<String, ActorRef> _projectionActors = {};
  final Map<String, ProjectionInfo> _projectionInfos = {};
  
  /// Event routing queues by event type
  final Map<String, Queue<Event>> _eventQueues = {};
  
  /// Projection update queues by projection ID
  final Map<String, Queue<ProjectionUpdate>> _updateQueues = {};
  
  /// Catch-up task queue
  late final Queue<CatchUpTask> _catchUpQueue;
  
  /// Rebuild task queue
  late final Queue<RebuildTask> _rebuildQueue;
  
  /// Whether the manager is running
  bool _isRunning = false;
  
  ProjectionManager(this._duraqManager, this._eventStore, this._actorSystem) {
    _catchUpQueue = _duraqManager.queue<CatchUpTask>('projection-catchup');
    _rebuildQueue = _duraqManager.queue<RebuildTask>('projection-rebuild');
  }
  
  /// Start the projection manager and begin processing
  Future<void> start() async {
    if (_isRunning) return;
    
    _isRunning = true;
    
    // Start background processors
    unawaited(_processCatchUpTasks());
    unawaited(_processRebuildTasks());
    unawaited(_processProjectionUpdates());
  }
  
  /// Stop the projection manager
  Future<void> stop() async {
    _isRunning = false;
    
    // Stop all projection actors
    for (final actor in _projectionActors.values) {
      await _actorSystem.stop(actor);
    }
    
    _projectionActors.clear();
    _projectionInfos.clear();
    _eventQueues.clear();
    _updateQueues.clear();
  }
  
  /// Register a projection with the manager
  Future<void> registerProjection<TReadModel>(
    Projection<TReadModel> Function() projectionFactory,
  ) async {
    final projection = projectionFactory();
    final projectionId = projection.projectionId;
    
    // Spawn the projection actor
    final actorRef = await _actorSystem.spawn(
      'projection-$projectionId',
      () => _createProjectionActor(projection),
    );
    
    _projectionActors[projectionId] = actorRef;
    
    // Subscribe to events for this projection
    await _subscribeToEvents(projection.interestedEventTypes, projectionId);
    
    // Create update queue for this projection
    _updateQueues[projectionId] = _duraqManager.queue<ProjectionUpdate>(
      'projection-updates-$projectionId'
    );
    
    // Initialize projection info
    _projectionInfos[projectionId] = ProjectionInfo(
      projectionId: projectionId,
      status: ProjectionStatus.running,
      lastProcessedSequence: 0,
      lastUpdated: DateTime.now(),
      eventsProcessed: 0,
    );
  }
  
  /// Unregister a projection
  Future<void> unregisterProjection(String projectionId) async {
    final actorRef = _projectionActors.remove(projectionId);
    if (actorRef != null) {
      await _actorSystem.stop(actorRef);
    }
    
    _projectionInfos.remove(projectionId);
    _updateQueues.remove(projectionId);
    
    // Clean up event subscriptions if no other projections need them
    await _cleanupEventSubscriptions();
  }
  
  /// Get information about all registered projections
  List<ProjectionInfo> getProjectionInfos() {
    return _projectionInfos.values.toList();
  }
  
  /// Get information about a specific projection
  Future<ProjectionInfo?> getProjectionInfo(String projectionId) async {
    final actorRef = _projectionActors[projectionId];
    if (actorRef == null) return null;
    
    try {
      final completer = Completer<ProjectionInfo>();
      final command = ProjectionCommand(ProjectionCommandType.getInfo, completer);
      actorRef.tell(command);
      
      return await completer.future.timeout(const Duration(seconds: 5));
    } catch (e) {
      return _projectionInfos[projectionId];
    }
  }
  
  /// Pause a projection
  Future<void> pauseProjection(String projectionId) async {
    final actorRef = _projectionActors[projectionId];
    if (actorRef != null) {
      actorRef.tell(const ProjectionCommand(ProjectionCommandType.pause));
    }
  }
  
  /// Resume a projection
  Future<void> resumeProjection(String projectionId) async {
    final actorRef = _projectionActors[projectionId];
    if (actorRef != null) {
      actorRef.tell(const ProjectionCommand(ProjectionCommandType.resume));
    }
  }
  
  /// Rebuild a projection from scratch
  Future<void> rebuildProjection(String projectionId) async {
    await _rebuildQueue.enqueue(RebuildTask(projectionId: projectionId));
  }
  
  /// Catch up a projection to the latest events
  Future<void> catchUpProjection(String projectionId, {int? fromSequence}) async {
    await _catchUpQueue.enqueue(CatchUpTask(
      projectionId: projectionId,
      fromSequence: fromSequence ?? 0,
    ));
  }
  
  /// Route an event to interested projections
  Future<void> routeEvent(Event event) async {
    final eventType = event.runtimeType.toString();
    final queue = _eventQueues[eventType];
    
    if (queue != null) {
      await queue.enqueue(event);
    }
  }
  
  /// Subscribe to events for a projection
  Future<void> _subscribeToEvents(List<Type> eventTypes, String projectionId) async {
    for (final eventType in eventTypes) {
      final eventTypeName = eventType.toString();
      
      // Create event queue if it doesn't exist
      if (!_eventQueues.containsKey(eventTypeName)) {
        _eventQueues[eventTypeName] = _duraqManager.queue<Event>(
          'projection-events-$eventTypeName'
        );
        
        // Start processing events for this type
        unawaited(_processEventQueue(eventTypeName));
      }
    }
  }
  
  /// Process events from an event queue
  Future<void> _processEventQueue(String eventType) async {
    final queue = _eventQueues[eventType];
    if (queue == null) return;
    
    while (_isRunning) {
      try {
        await queue.processNext((event) async {
          await _routeEventToProjections(event);
        });
      } catch (error) {
        // Log error and continue processing
        await Future.delayed(const Duration(seconds: 1));
      }
    }
  }
  
  /// Route an event to all interested projections
  Future<void> _routeEventToProjections(Event event) async {
    final eventType = event.runtimeType;
    
    for (final entry in _projectionActors.entries) {
      final projectionId = entry.key;
      final actorRef = entry.value;
      
      // Check if this projection is interested in this event type
      // This would normally be done by querying the projection's interestedEventTypes
      // For now, we'll route to all projections and let them filter
      actorRef.tell(event);
    }
  }
  
  /// Process catch-up tasks
  Future<void> _processCatchUpTasks() async {
    while (_isRunning) {
      try {
        await _catchUpQueue.processNext((task) async {
          await _performCatchUp(task);
        });
      } catch (error) {
        // Log error and continue processing
        await Future.delayed(const Duration(seconds: 1));
      }
    }
  }
  
  /// Process rebuild tasks
  Future<void> _processRebuildTasks() async {
    while (_isRunning) {
      try {
        await _rebuildQueue.processNext((task) async {
          await _performRebuild(task);
        });
      } catch (error) {
        // Log error and continue processing
        await Future.delayed(const Duration(seconds: 1));
      }
    }
  }
  
  /// Process projection updates
  Future<void> _processProjectionUpdates() async {
    while (_isRunning) {
      for (final entry in _updateQueues.entries) {
        final projectionId = entry.key;
        final queue = entry.value;
        
        try {
          await queue.processNext((update) async {
            await _processProjectionUpdate(update);
          });
        } catch (error) {
          // Log error and continue processing
        }
      }
      
      await Future.delayed(const Duration(milliseconds: 100));
    }
  }
  
  /// Perform catch-up for a projection
  Future<void> _performCatchUp(CatchUpTask task) async {
    final actorRef = _projectionActors[task.projectionId];
    if (actorRef == null) return;
    
    // Get events from the specified sequence
    final events = await _eventStore.getEvents('', fromSequence: task.fromSequence);
    
    // Send events to the projection actor
    for (final event in events) {
      actorRef.tell(event);
    }
  }
  
  /// Perform rebuild for a projection
  Future<void> _performRebuild(RebuildTask task) async {
    final actorRef = _projectionActors[task.projectionId];
    if (actorRef == null) return;
    
    // Send rebuild command to the projection actor
    actorRef.tell(const ProjectionCommand(ProjectionCommandType.rebuild));
  }
  
  /// Process a projection update
  Future<void> _processProjectionUpdate(ProjectionUpdate update) async {
    final actorRef = _projectionActors[update.projectionId];
    if (actorRef == null) return;
    
    // Send the event to the projection actor
    actorRef.tell(update.event);
  }
  
  /// Clean up unused event subscriptions
  Future<void> _cleanupEventSubscriptions() async {
    // Check if any projections still need specific event types
    // and remove unused event queues
    final usedEventTypes = <String>{};
    
    // Collect all event types still needed by remaining projections
    for (final actorEntry in _projectionActors.entries) {
      // For now, we'll keep all event queues since we don't have direct access
      // to projection's interestedEventTypes after registration
      // In a full implementation, we'd track this information
    }
    
    // For now, just return - proper cleanup would remove unused queues
    // This prevents the hanging issue while maintaining the async signature
    return;
  }
  
  /// Create a projection actor wrapper
  Actor _createProjectionActor<TReadModel>(Projection<TReadModel> projection) {
    // This would create a ProjectionActor instance
    // For now, return a simple actor that forwards to the projection
    return _ProjectionActorWrapper(projection);
  }
}

/// Wrapper actor for projections
class _ProjectionActorWrapper<TReadModel> extends Actor {
  final Projection<TReadModel> _projection;
  
  _ProjectionActorWrapper(this._projection);
  
  @override
  Future<void> onMessage(dynamic message) async {
    if (message is Event) {
      await _projection.handle(message);
    } else if (message is ProjectionCommand) {
      switch (message.type) {
        case ProjectionCommandType.rebuild:
          await _projection.rebuild();
          break;
        case ProjectionCommandType.reset:
          await _projection.reset();
          break;
        case ProjectionCommandType.getInfo:
          // This would need to be implemented properly
          break;
        default:
          break;
      }
    }
  }
}

/// Task for catching up a projection
class CatchUpTask {
  final String projectionId;
  final int fromSequence;
  
  const CatchUpTask({
    required this.projectionId,
    required this.fromSequence,
  });
}

/// Task for rebuilding a projection
class RebuildTask {
  final String projectionId;
  
  const RebuildTask({required this.projectionId});
}

/// Update task for a projection
class ProjectionUpdate {
  final String projectionId;
  final Event event;
  
  const ProjectionUpdate({
    required this.projectionId,
    required this.event,
  });
}

/// Commands for controlling projections
class ProjectionCommand implements Message {
  final ProjectionCommandType type;
  final Completer<ProjectionInfo>? completer;
  
  const ProjectionCommand(this.type, [this.completer]);
  
  @override
  String get correlationId => 'projection-command-${type.name}';
  
  @override
  ActorRef? get replyTo => null;
  
  @override
  Map<String, dynamic> get metadata => const {};
  
  @override
  DateTime get timestamp => DateTime.now();
}

enum ProjectionCommandType {
  pause,
  resume,
  rebuild,
  reset,
  getInfo,
}
