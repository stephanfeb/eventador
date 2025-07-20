# Guide: Advanced Snapshotting and Performance Tuning

This guide covers advanced techniques for optimizing the performance of your persistent actors in Eventador, with a focus on snapshotting.

## 1. Introduction

### Why is Performance Important?

For systems that process a high volume of events, performance is critical. Slow event processing can lead to high latency and a poor user experience. Snapshotting is one of the most effective tools for optimizing the performance of persistent actors.

## 2. Advanced Snapshot Configuration

The `SnapshotConfig` class allows you to fine-tune the behavior of the snapshot system.

```dart
final customConfig = SnapshotConfig(
  eventCountThreshold: 100,
  timeThreshold: Duration(minutes: 5),
  maxSnapshotsToKeep: 3,
  enableCompression: true,
  compressionThreshold: 2048,
  minTimeBetweenSnapshots: Duration(minutes: 1),
);
```

*   `eventCountThreshold`: The number of events to process before a snapshot is triggered.
*   `timeThreshold`: The amount of time to wait before a snapshot is triggered.
*   `maxSnapshotsToKeep`: The maximum number of snapshots to keep. Older snapshots will be deleted.
*   `enableCompression`: Whether to compress snapshots to save space.
*   `compressionThreshold`: The minimum size of a snapshot before it is compressed.
*   `minTimeBetweenSnapshots`: The minimum amount of time that must pass between snapshots.

## 3. The SnapshotManager

The `SnapshotManager` is responsible for automatically creating snapshots based on the configured policies. You can create a `SnapshotManager` and pass it to your `PersistentActor` to enable automatic snapshotting.

```dart
final snapshotManager = SnapshotManager(
  eventStore: eventStore,
  defaultConfig: SnapshotConfig.production,
);

final actor = MyActor(
  persistenceId: 'my-actor',
  eventStore: eventStore,
  snapshotManager: snapshotManager,
);
```

## 4. Performance Tips

### Use Snapshots Wisely

*   For actors with a high volume of events, take snapshots more frequently.
*   For actors with a low volume of events, take snapshots less frequently to save space.

### Batch Operations

*   Use `persistEvents` to persist multiple events in a single atomic operation. This is much more efficient than calling `persistEvent` multiple times.

### Optimize Serialization

*   Keep your event and state objects as small as possible.
*   Use efficient serialization formats like CBOR.

### Monitor Memory

*   Use the `maxSnapshotsToKeep` setting to prevent unbounded memory growth from old snapshots.

## 5. Benchmarking

It is important to benchmark your persistent actors to identify performance bottlenecks. You can use the `Stopwatch` class to measure the time it takes to process events and create snapshots.

By following these tips, you can ensure that your persistent actors are performant and scalable.
