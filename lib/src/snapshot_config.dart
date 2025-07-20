// Snapshot configuration system - Phase 2 Week 6 implementation
// Configurable policies for automatic snapshot creation and retention

import 'dart:math' as math;

/// Configuration for snapshot creation and retention policies
class SnapshotConfig {
  /// Number of events after which a snapshot should be created
  /// Set to 0 to disable event count-based snapshots
  final int eventCountThreshold;
  
  /// Time duration after which a snapshot should be created
  /// Set to null to disable time-based snapshots
  final Duration? timeThreshold;
  
  /// Maximum number of snapshots to keep per persistence ID
  /// Older snapshots will be deleted when this limit is exceeded
  final int maxSnapshotsToKeep;
  
  /// Whether to enable compression for large snapshots
  /// Reduces storage space but increases CPU usage
  final bool enableCompression;
  
  /// Minimum size in bytes before compression is applied
  /// Only relevant if enableCompression is true
  final int compressionThreshold;
  
  /// Whether snapshots are enabled at all
  /// Can be used to completely disable snapshotting
  final bool enabled;
  
  /// Minimum time between snapshots to prevent too frequent snapshots
  /// Helps avoid performance issues with high-frequency events
  final Duration minTimeBetweenSnapshots;
  
  /// Maximum size in bytes for a single snapshot
  /// Snapshots larger than this will be rejected
  final int maxSnapshotSize;

  const SnapshotConfig({
    this.eventCountThreshold = 100,
    this.timeThreshold = const Duration(minutes: 5),
    this.maxSnapshotsToKeep = 3,
    this.enableCompression = true,
    this.compressionThreshold = 1024, // 1KB
    this.enabled = true,
    this.minTimeBetweenSnapshots = const Duration(seconds: 30),
    this.maxSnapshotSize = 10 * 1024 * 1024, // 10MB
  });

  /// Default configuration for development environments
  /// More frequent snapshots for faster feedback
  static const SnapshotConfig development = SnapshotConfig(
    eventCountThreshold: 50,
    timeThreshold: Duration(minutes: 2),
    maxSnapshotsToKeep: 5,
    enableCompression: false, // Faster for development
    minTimeBetweenSnapshots: Duration(seconds: 10),
  );

  /// Default configuration for production environments
  /// Optimized for performance and storage efficiency
  static const SnapshotConfig production = SnapshotConfig(
    eventCountThreshold: 200,
    timeThreshold: Duration(minutes: 10),
    maxSnapshotsToKeep: 2,
    enableCompression: true,
    compressionThreshold: 2048, // 2KB
    minTimeBetweenSnapshots: Duration(minutes: 1),
    maxSnapshotSize: 50 * 1024 * 1024, // 50MB
  );

  /// Configuration for testing environments
  /// Minimal snapshots to speed up tests
  static const SnapshotConfig testing = SnapshotConfig(
    eventCountThreshold: 10,
    timeThreshold: Duration(seconds: 30),
    maxSnapshotsToKeep: 1,
    enableCompression: false,
    minTimeBetweenSnapshots: Duration(seconds: 1),
  );

  /// Disabled snapshot configuration
  /// Completely disables all snapshot functionality
  static const SnapshotConfig disabled = SnapshotConfig(
    enabled: false,
    eventCountThreshold: 0,
    timeThreshold: null,
    maxSnapshotsToKeep: 0,
  );

  /// Check if a snapshot should be created based on event count
  bool shouldCreateSnapshotByEventCount(int eventsSinceLastSnapshot) {
    if (!enabled || eventCountThreshold <= 0) return false;
    return eventsSinceLastSnapshot >= eventCountThreshold;
  }

  /// Check if a snapshot should be created based on time elapsed
  bool shouldCreateSnapshotByTime(DateTime? lastSnapshotTime) {
    if (!enabled || timeThreshold == null) return false;
    if (lastSnapshotTime == null) return true;
    
    final elapsed = DateTime.now().difference(lastSnapshotTime);
    return elapsed >= timeThreshold!;
  }

  /// Check if enough time has passed since the last snapshot
  bool canCreateSnapshotByTime(DateTime? lastSnapshotTime) {
    if (lastSnapshotTime == null) return true;
    
    final elapsed = DateTime.now().difference(lastSnapshotTime);
    return elapsed >= minTimeBetweenSnapshots;
  }

  /// Check if a snapshot size is within limits
  bool isSnapshotSizeValid(int sizeBytes) {
    return sizeBytes <= maxSnapshotSize;
  }

  /// Check if compression should be applied to a snapshot
  bool shouldCompress(int sizeBytes) {
    return enabled && enableCompression && sizeBytes >= compressionThreshold;
  }

  /// Create a copy of this config with modified values
  SnapshotConfig copyWith({
    int? eventCountThreshold,
    Duration? timeThreshold,
    int? maxSnapshotsToKeep,
    bool? enableCompression,
    int? compressionThreshold,
    bool? enabled,
    Duration? minTimeBetweenSnapshots,
    int? maxSnapshotSize,
  }) {
    return SnapshotConfig(
      eventCountThreshold: eventCountThreshold ?? this.eventCountThreshold,
      timeThreshold: timeThreshold ?? this.timeThreshold,
      maxSnapshotsToKeep: maxSnapshotsToKeep ?? this.maxSnapshotsToKeep,
      enableCompression: enableCompression ?? this.enableCompression,
      compressionThreshold: compressionThreshold ?? this.compressionThreshold,
      enabled: enabled ?? this.enabled,
      minTimeBetweenSnapshots: minTimeBetweenSnapshots ?? this.minTimeBetweenSnapshots,
      maxSnapshotSize: maxSnapshotSize ?? this.maxSnapshotSize,
    );
  }

  @override
  String toString() {
    return 'SnapshotConfig('
        'enabled: $enabled, '
        'eventCountThreshold: $eventCountThreshold, '
        'timeThreshold: $timeThreshold, '
        'maxSnapshotsToKeep: $maxSnapshotsToKeep, '
        'enableCompression: $enableCompression, '
        'compressionThreshold: $compressionThreshold, '
        'minTimeBetweenSnapshots: $minTimeBetweenSnapshots, '
        'maxSnapshotSize: $maxSnapshotSize'
        ')';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SnapshotConfig &&
        other.eventCountThreshold == eventCountThreshold &&
        other.timeThreshold == timeThreshold &&
        other.maxSnapshotsToKeep == maxSnapshotsToKeep &&
        other.enableCompression == enableCompression &&
        other.compressionThreshold == compressionThreshold &&
        other.enabled == enabled &&
        other.minTimeBetweenSnapshots == minTimeBetweenSnapshots &&
        other.maxSnapshotSize == maxSnapshotSize;
  }

  @override
  int get hashCode {
    return Object.hash(
      eventCountThreshold,
      timeThreshold,
      maxSnapshotsToKeep,
      enableCompression,
      compressionThreshold,
      enabled,
      minTimeBetweenSnapshots,
      maxSnapshotSize,
    );
  }
}

/// Statistics about snapshot operations
class SnapshotStats {
  /// Total number of snapshots created
  final int snapshotsCreated;
  
  /// Total number of snapshots loaded
  final int snapshotsLoaded;
  
  /// Total number of snapshots deleted
  final int snapshotsDeleted;
  
  /// Total time spent creating snapshots
  final Duration totalCreationTime;
  
  /// Total time spent loading snapshots
  final Duration totalLoadTime;
  
  /// Total size of all snapshots in bytes
  final int totalSnapshotSize;
  
  /// Average snapshot size in bytes
  double get averageSnapshotSize => 
      snapshotsCreated > 0 ? totalSnapshotSize / snapshotsCreated : 0.0;
  
  /// Average creation time per snapshot
  Duration get averageCreationTime => 
      snapshotsCreated > 0 
          ? Duration(microseconds: totalCreationTime.inMicroseconds ~/ snapshotsCreated)
          : Duration.zero;
  
  /// Average load time per snapshot
  Duration get averageLoadTime => 
      snapshotsLoaded > 0 
          ? Duration(microseconds: totalLoadTime.inMicroseconds ~/ snapshotsLoaded)
          : Duration.zero;

  const SnapshotStats({
    this.snapshotsCreated = 0,
    this.snapshotsLoaded = 0,
    this.snapshotsDeleted = 0,
    this.totalCreationTime = Duration.zero,
    this.totalLoadTime = Duration.zero,
    this.totalSnapshotSize = 0,
  });

  /// Create a copy with updated values
  SnapshotStats copyWith({
    int? snapshotsCreated,
    int? snapshotsLoaded,
    int? snapshotsDeleted,
    Duration? totalCreationTime,
    Duration? totalLoadTime,
    int? totalSnapshotSize,
  }) {
    return SnapshotStats(
      snapshotsCreated: snapshotsCreated ?? this.snapshotsCreated,
      snapshotsLoaded: snapshotsLoaded ?? this.snapshotsLoaded,
      snapshotsDeleted: snapshotsDeleted ?? this.snapshotsDeleted,
      totalCreationTime: totalCreationTime ?? this.totalCreationTime,
      totalLoadTime: totalLoadTime ?? this.totalLoadTime,
      totalSnapshotSize: totalSnapshotSize ?? this.totalSnapshotSize,
    );
  }

  /// Add creation statistics
  SnapshotStats addCreation(Duration creationTime, int snapshotSize) {
    return copyWith(
      snapshotsCreated: snapshotsCreated + 1,
      totalCreationTime: totalCreationTime + creationTime,
      totalSnapshotSize: totalSnapshotSize + snapshotSize,
    );
  }

  /// Add load statistics
  SnapshotStats addLoad(Duration loadTime) {
    return copyWith(
      snapshotsLoaded: snapshotsLoaded + 1,
      totalLoadTime: totalLoadTime + loadTime,
    );
  }

  /// Add deletion statistics
  SnapshotStats addDeletion(int count) {
    return copyWith(
      snapshotsDeleted: snapshotsDeleted + count,
    );
  }

  @override
  String toString() {
    return 'SnapshotStats('
        'created: $snapshotsCreated, '
        'loaded: $snapshotsLoaded, '
        'deleted: $snapshotsDeleted, '
        'avgSize: ${averageSnapshotSize.toStringAsFixed(1)} bytes, '
        'avgCreationTime: ${averageCreationTime.inMilliseconds}ms, '
        'avgLoadTime: ${averageLoadTime.inMilliseconds}ms'
        ')';
  }
}
