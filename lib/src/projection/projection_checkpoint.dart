import 'package:isar/isar.dart';

/// Isar collection for tracking projection checkpoints and state.
/// 
/// This stores the progress of each projection, including the last processed
/// sequence number and current status.
@collection
class ProjectionCheckpoint {
  Id id = Isar.autoIncrement;
  
  /// Unique identifier for the projection
  @Index(unique: true)
  late String projectionId;
  
  /// Last processed event sequence number
  late int lastProcessedSequence;
  
  /// Current status of the projection
  @Enumerated(EnumType.name)
  late ProjectionStatus status;
  
  /// When this checkpoint was last updated
  late DateTime lastUpdated;
  
  /// Total number of events processed by this projection
  late int eventsProcessed;
  
  /// Average processing time per event in milliseconds
  int? averageProcessingTimeMs;
  
  /// Last error message if projection failed
  String? lastError;
  
  /// When the projection was started
  late DateTime startedAt;
  
  /// Version of the projection schema/logic
  late int projectionVersion;
  
  /// Additional metadata as key-value pairs
  @ignore
  late Map<String, String> metadata;
  
  ProjectionCheckpoint() {
    metadata = <String, String>{};
    eventsProcessed = 0;
    lastProcessedSequence = 0;
    projectionVersion = 1;
    startedAt = DateTime.now();
    lastUpdated = DateTime.now();
    status = ProjectionStatus.running;
  }
}

/// Status enum for projections
enum ProjectionStatus {
  running,
  paused,
  failed,
  rebuilding,
  catchingUp,
  stopped,
}
