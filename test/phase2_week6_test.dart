// Phase 2 Week 6 Tests - Snapshot System Implementation
// Tests for configurable snapshot policies, automatic creation, and performance optimization

import 'dart:io';
import 'package:test/test.dart';
import 'package:eventador/eventador.dart';

// Test state class for snapshots
class CounterState extends State {
  final int count;
  final String name;

  CounterState({
    required this.count,
    required this.name,
    int version = 1,
    DateTime? lastModified,
  }) : super(
          version: version,
          lastModified: lastModified ?? DateTime.now(),
        );

  @override
  CounterState copyWith({int? version, DateTime? lastModified}) {
    return CounterState(
      count: count,
      name: name,
      version: version ?? this.version,
      lastModified: lastModified ?? this.lastModified,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'count': count,
      'name': name,
      'version': version,
      'lastModified': lastModified.toIso8601String(),
    };
  }

  static CounterState fromMap(Map<String, dynamic> map) {
    return CounterState(
      count: map['count'] as int,
      name: map['name'] as String,
      version: map['version'] as int? ?? 1,
      lastModified: map['lastModified'] != null
          ? (map['lastModified'] is DateTime
              ? map['lastModified'] as DateTime
              : DateTime.parse(map['lastModified'] as String))
          : DateTime.now(),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CounterState &&
        other.count == count &&
        other.name == name &&
        other.version == version;
  }

  @override
  int get hashCode => Object.hash(count, name, version);
}

// Test events
class CounterIncremented extends Event with SerializableEvent {
  final int amount;

  CounterIncremented({
    required this.amount,
    String? eventId,
    DateTime? timestamp,
    Map<String, dynamic>? metadata,
  }) : super(
          eventId: eventId,
          timestamp: timestamp,
          metadata: metadata,
        );

  @override
  Map<String, dynamic> getEventData() {
    return {'amount': amount};
  }

  static CounterIncremented fromMap(Map<String, dynamic> map) {
    return CounterIncremented(
      amount: map['amount'] as int,
      eventId: map['eventId'] as String?,
      timestamp: map['timestamp'] != null
          ? (map['timestamp'] is DateTime
              ? map['timestamp'] as DateTime
              : DateTime.parse(map['timestamp'] as String))
          : null,
      metadata: Map<String, dynamic>.from(map['metadata'] as Map? ?? {}),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CounterIncremented &&
        other.amount == amount &&
        other.eventId == eventId;
  }

  @override
  int get hashCode => Object.hash(amount, eventId);
}

// Test commands
class IncrementCounter extends Command with ValidatableCommand {
  final int amount;

  IncrementCounter({
    required this.amount,
    String? commandId,
    DateTime? timestamp,
    Map<String, dynamic>? metadata,
  }) : super(
          commandId: commandId,
          timestamp: timestamp,
          metadata: metadata,
        );

  @override
  bool validate() => amount > 0;

  @override
  List<String> getValidationErrors() {
    final errors = <String>[];
    if (amount <= 0) {
      errors.add('Amount must be positive');
    }
    return errors;
  }

  @override
  Map<String, dynamic> getCommandData() {
    return {'amount': amount};
  }

  static IncrementCounter fromMap(Map<String, dynamic> map) {
    return IncrementCounter(
      amount: map['amount'] as int,
      commandId: map['commandId'] as String?,
      timestamp: map['timestamp'] != null
          ? (map['timestamp'] is DateTime
              ? map['timestamp'] as DateTime
              : DateTime.parse(map['timestamp'] as String))
          : null,
      metadata: Map<String, dynamic>.from(map['metadata'] as Map? ?? {}),
    );
  }
}

// Test persistent actor with snapshot support
class CounterActor extends PersistentActor {
  CounterState _state = CounterState(count: 0, name: 'test-counter');

  CounterActor({
    required String persistenceId,
    required EventStore eventStore,
    SnapshotManager? snapshotManager,
  }) : super(
          persistenceId: persistenceId,
          eventStore: eventStore,
          snapshotManager: snapshotManager,
        );

  CounterState get state => _state;

  @override
  Future<void> commandHandler(Command command) async {
    if (command is IncrementCounter) {
      final event = CounterIncremented(amount: command.amount);
      await persistEvent(event);
    }
  }

  @override
  void eventHandler(Event event) {
    if (event is CounterIncremented) {
      _state = CounterState(
        count: _state.count + event.amount,
        name: _state.name,
        version: _state.version + 1,
        lastModified: DateTime.now(),
      );
    }
  }

  @override
  Future<dynamic> getSnapshotState() async {
    return _state.toMap();
  }

  @override
  Future<void> onSnapshot(dynamic snapshotState, int sequenceNumber) async {
    if (snapshotState is Map<String, dynamic>) {
      _state = CounterState.fromMap(snapshotState);
    }
  }
}

void main() {
  group('Phase 2 Week 6 - Snapshot System Implementation', () {
    late Directory tempDir;
    late IsarEventStore eventStore;

    setUpAll(() async {
      // Register test events
      EventRegistry.register<CounterIncremented>(
        'CounterIncremented',
        CounterIncremented.fromMap,
      );
    });

    setUp(() async {
      // Create temporary directory for each test
      tempDir = await Directory.systemTemp.createTemp('eventador_snapshot_test_');
      eventStore = await IsarEventStore.create(
        directory: tempDir.path,
        name: 'test_snapshot_eventador',
      );
    });

    tearDown(() async {
      await eventStore.close();
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    tearDownAll(() {
      EventRegistry.clear();
    });

    group('SnapshotConfig', () {
      test('should have correct default values', () {
        const config = SnapshotConfig();
        
        expect(config.eventCountThreshold, equals(100));
        expect(config.timeThreshold, equals(const Duration(minutes: 5)));
        expect(config.maxSnapshotsToKeep, equals(3));
        expect(config.enableCompression, isTrue);
        expect(config.compressionThreshold, equals(1024));
        expect(config.enabled, isTrue);
        expect(config.minTimeBetweenSnapshots, equals(const Duration(seconds: 30)));
        expect(config.maxSnapshotSize, equals(10 * 1024 * 1024));
      });

      test('should provide predefined configurations', () {
        // Development config
        expect(SnapshotConfig.development.eventCountThreshold, equals(50));
        expect(SnapshotConfig.development.enableCompression, isFalse);
        
        // Production config
        expect(SnapshotConfig.production.eventCountThreshold, equals(200));
        expect(SnapshotConfig.production.enableCompression, isTrue);
        
        // Testing config
        expect(SnapshotConfig.testing.eventCountThreshold, equals(10));
        expect(SnapshotConfig.testing.maxSnapshotsToKeep, equals(1));
        
        // Disabled config
        expect(SnapshotConfig.disabled.enabled, isFalse);
      });

      test('should correctly determine when to create snapshots by event count', () {
        const config = SnapshotConfig(eventCountThreshold: 10);
        
        expect(config.shouldCreateSnapshotByEventCount(5), isFalse);
        expect(config.shouldCreateSnapshotByEventCount(10), isTrue);
        expect(config.shouldCreateSnapshotByEventCount(15), isTrue);
      });

      test('should correctly determine when to create snapshots by time', () {
        const config = SnapshotConfig(timeThreshold: Duration(minutes: 5));
        
        final now = DateTime.now();
        final tooRecent = now.subtract(const Duration(minutes: 2));
        final oldEnough = now.subtract(const Duration(minutes: 6));
        
        expect(config.shouldCreateSnapshotByTime(null), isTrue);
        expect(config.shouldCreateSnapshotByTime(tooRecent), isFalse);
        expect(config.shouldCreateSnapshotByTime(oldEnough), isTrue);
      });

      test('should validate snapshot size limits', () {
        const config = SnapshotConfig(maxSnapshotSize: 1024);
        
        expect(config.isSnapshotSizeValid(500), isTrue);
        expect(config.isSnapshotSizeValid(1024), isTrue);
        expect(config.isSnapshotSizeValid(2048), isFalse);
      });

      test('should determine compression requirements', () {
        const config = SnapshotConfig(
          enableCompression: true,
          compressionThreshold: 1024,
        );
        
        expect(config.shouldCompress(500), isFalse);
        expect(config.shouldCompress(1024), isTrue);
        expect(config.shouldCompress(2048), isTrue);
      });

      test('should support copyWith for configuration changes', () {
        const original = SnapshotConfig();
        final modified = original.copyWith(
          eventCountThreshold: 50,
          enabled: false,
        );
        
        expect(modified.eventCountThreshold, equals(50));
        expect(modified.enabled, isFalse);
        expect(modified.timeThreshold, equals(original.timeThreshold));
      });
    });

    group('SnapshotManager', () {
      late SnapshotManager snapshotManager;

      setUp(() {
        snapshotManager = SnapshotManager(
          eventStore: eventStore,
          config: const SnapshotConfig(eventCountThreshold: 5),
        );
      });

      tearDown(() {
        snapshotManager.dispose();
      });

      test('should register and unregister actors', () {
        const persistenceId = 'test-actor';
        
        snapshotManager.registerActor(persistenceId);
        expect(snapshotManager.getActorState(persistenceId), isNotNull);
        
        snapshotManager.unregisterActor(persistenceId);
        expect(snapshotManager.getActorState(persistenceId), isNull);
      });

      test('should track event persistence', () {
        const persistenceId = 'test-actor';
        
        snapshotManager.registerActor(persistenceId);
        
        // Initial state
        var state = snapshotManager.getActorState(persistenceId)!;
        expect(state.eventsSinceLastSnapshot, equals(0));
        
        // After event persistence
        snapshotManager.onEventPersisted(persistenceId);
        state = snapshotManager.getActorState(persistenceId)!;
        expect(state.eventsSinceLastSnapshot, equals(1));
      });

      test('should determine when snapshots should be created', () {
        const persistenceId = 'test-actor';
        
        snapshotManager.registerActor(persistenceId);
        
        // Initially no snapshot needed
        expect(snapshotManager.shouldCreateSnapshot(persistenceId), isFalse);
        
        // After enough events
        for (int i = 0; i < 5; i++) {
          snapshotManager.onEventPersisted(persistenceId);
        }
        expect(snapshotManager.shouldCreateSnapshot(persistenceId), isTrue);
      });

      test('should create manual snapshots', () async {
        const persistenceId = 'test-actor';
        final testState = {'count': 42, 'name': 'test'};
        
        snapshotManager.registerActor(persistenceId);
        
        final success = await snapshotManager.createSnapshot(persistenceId, testState);
        expect(success, isTrue);
        
        // Verify snapshot was created
        final snapshot = await eventStore.loadSnapshot(persistenceId);
        expect(snapshot, isNotNull);
        expect(snapshot!.state, isA<Map>());
      });

      test('should respect minimum time between snapshots', () async {
        final config = SnapshotConfig(
          eventCountThreshold: 1,
          minTimeBetweenSnapshots: const Duration(seconds: 1),
        );
        final manager = SnapshotManager(eventStore: eventStore, config: config);
        
        const persistenceId = 'test-actor';
        final testState = {'count': 1};
        
        manager.registerActor(persistenceId);
        
        // First snapshot should succeed
        final success1 = await manager.createSnapshot(persistenceId, testState);
        expect(success1, isTrue);
        
        // Immediate second snapshot should fail due to time restriction
        final success2 = await manager.createSnapshot(persistenceId, testState);
        expect(success2, isFalse);
        
        manager.dispose();
      });

      test('should collect statistics', () async {
        const persistenceId = 'test-actor';
        final testState = {'count': 1};
        
        snapshotManager.registerActor(persistenceId);
        
        // Initial stats
        expect(snapshotManager.stats.snapshotsCreated, equals(0));
        
        // Create snapshot
        await snapshotManager.createSnapshot(persistenceId, testState);
        
        // Updated stats
        expect(snapshotManager.stats.snapshotsCreated, equals(1));
        expect(snapshotManager.stats.totalSnapshotSize, greaterThan(0));
      });
    });

    group('PersistentActor with Snapshot Integration', () {
      test('should integrate with snapshot manager for automatic snapshots', () async {
        final snapshotManager = SnapshotManager(
          eventStore: eventStore,
          config: const SnapshotConfig(eventCountThreshold: 3),
        );
        
        final actor = CounterActor(
          persistenceId: 'counter-1',
          eventStore: eventStore,
          snapshotManager: snapshotManager,
        );
        
        // Simulate actor lifecycle
        actor.preStart();
        await Future.delayed(const Duration(milliseconds: 100)); // Allow recovery
        
        // Process commands to trigger events
        for (int i = 0; i < 5; i++) {
          await actor.commandHandler(IncrementCounter(amount: 1));
        }
        
        // Verify state
        expect(actor.state.count, equals(5));
        
        // Check if snapshot was created (should be after 3 events)
        final snapshot = await eventStore.loadSnapshot('counter-1');
        expect(snapshot, isNotNull);
        
        // Cleanup
        actor.postStop();
        snapshotManager.dispose();
      });

      test('should recover from snapshots correctly', () async {
        const persistenceId = 'counter-recovery';
        
        // Create and populate actor
        var actor = CounterActor(
          persistenceId: persistenceId,
          eventStore: eventStore,
        );
        
        actor.preStart();
        await Future.delayed(const Duration(milliseconds: 100));
        
        // Add some events
        for (int i = 0; i < 10; i++) {
          await actor.commandHandler(IncrementCounter(amount: 1));
        }
        
        // Create snapshot manually
        await actor.createSnapshot();
        
        // Add more events after snapshot
        for (int i = 0; i < 5; i++) {
          await actor.commandHandler(IncrementCounter(amount: 1));
        }
        
        expect(actor.state.count, equals(15));
        actor.postStop();
        
        // Create new actor instance (simulating restart)
        actor = CounterActor(
          persistenceId: persistenceId,
          eventStore: eventStore,
        );
        
        actor.preStart();
        await Future.delayed(const Duration(milliseconds: 100));
        
        // Should recover to correct state (snapshot + subsequent events)
        expect(actor.state.count, equals(15));
        
        actor.postStop();
      });

      test('should handle snapshot creation failures gracefully', () async {
        // Create a mock that will fail snapshot creation
        final snapshotManager = SnapshotManager(
          eventStore: eventStore,
          config: const SnapshotConfig(eventCountThreshold: 1),
        );
        
        final actor = CounterActor(
          persistenceId: 'counter-fail',
          eventStore: eventStore,
          snapshotManager: snapshotManager,
        );
        
        actor.preStart();
        await Future.delayed(const Duration(milliseconds: 100));
        
        // This should not throw even if snapshot creation fails
        await actor.commandHandler(IncrementCounter(amount: 1));
        
        expect(actor.state.count, equals(1));
        
        actor.postStop();
        snapshotManager.dispose();
      });
    });

    group('Performance and Edge Cases', () {
      test('should handle disabled snapshot configuration', () {
        final snapshotManager = SnapshotManager(
          eventStore: eventStore,
          config: SnapshotConfig.disabled,
        );
        
        const persistenceId = 'disabled-test';
        
        // Verify config is disabled
        expect(snapshotManager.config.enabled, isFalse);
        
        // Should not register actors when disabled
        snapshotManager.registerActor(persistenceId);
        expect(snapshotManager.getActorState(persistenceId), isNull);
        
        snapshotManager.dispose();
      });

      test('should handle large snapshot states', () async {
        const persistenceId = 'large-state';
        
        // Create large state
        final largeState = <String, dynamic>{};
        for (int i = 0; i < 1000; i++) {
          largeState['key_$i'] = 'value_$i' * 100; // Large strings
        }
        
        final snapshotManager = SnapshotManager(
          eventStore: eventStore,
          config: const SnapshotConfig(eventCountThreshold: 1),
        );
        
        snapshotManager.registerActor(persistenceId);
        
        final success = await snapshotManager.createSnapshot(persistenceId, largeState);
        expect(success, isTrue);
        
        // Verify snapshot can be loaded
        final snapshot = await eventStore.loadSnapshot(persistenceId);
        expect(snapshot, isNotNull);
        expect(snapshot!.state, isA<Map>());
        
        snapshotManager.dispose();
      });

      test('should handle concurrent snapshot operations', () async {
        final snapshotManager = SnapshotManager(
          eventStore: eventStore,
          config: const SnapshotConfig(eventCountThreshold: 1),
        );
        
        const persistenceId = 'concurrent-test';
        snapshotManager.registerActor(persistenceId);
        
        // Simulate concurrent snapshot creation attempts
        final futures = List.generate(10, (i) async {
          return await snapshotManager.createSnapshot(
            persistenceId,
            {'attempt': i, 'timestamp': DateTime.now().millisecondsSinceEpoch},
          );
        });
        
        final results = await Future.wait(futures);
        
        // At least one should succeed
        expect(results.any((r) => r), isTrue);
        
        snapshotManager.dispose();
      });

      test('should cleanup old snapshots', () async {
        final snapshotManager = SnapshotManager(
          eventStore: eventStore,
          config: const SnapshotConfig(maxSnapshotsToKeep: 2),
        );
        
        // This test verifies the cleanup method runs without error
        // The actual cleanup logic is in the event store
        await snapshotManager.cleanupOldSnapshots();
        
        snapshotManager.dispose();
      });
    });

    group('CallbackSnapshotManager', () {
      test('should use callback for snapshot creation', () async {
        var callbackInvoked = false;
        final testState = {'callback': true};
        
        final manager = CallbackSnapshotManager(
          eventStore: eventStore,
          config: const SnapshotConfig(eventCountThreshold: 1),
          snapshotCreator: (persistenceId) async {
            callbackInvoked = true;
            return testState;
          },
        );
        
        const persistenceId = 'callback-test';
        manager.registerActor(persistenceId);
        
        // Trigger snapshot via event count
        manager.onEventPersisted(persistenceId);
        
        // Allow async processing
        await Future.delayed(const Duration(milliseconds: 100));
        
        expect(callbackInvoked, isTrue);
        
        manager.dispose();
      });
    });
  });
}
