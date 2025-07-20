// CBOR Serialization Tests - Phase 1 Week 3
// Tests CBOR serialization without Isar dependency

import 'package:test/test.dart';
import 'package:eventador/eventador.dart';

// Test event implementations
class TestEvent extends Event with SerializableEvent, VersionedEvent {
  final String data;
  final int value;

  TestEvent({
    required this.data,
    required this.value,
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
    return {
      'data': data,
      'value': value,
    };
  }

  static TestEvent fromMap(Map<String, dynamic> map) {
    return TestEvent(
      data: map['data'] as String,
      value: map['value'] as int,
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
    return other is TestEvent &&
        other.data == data &&
        other.value == value &&
        other.eventId == eventId;
  }

  @override
  int get hashCode => Object.hash(data, value, eventId);
}

// Test state class
class TestState {
  final int counter;
  final String name;
  final DateTime lastUpdated;

  const TestState({
    required this.counter,
    required this.name,
    required this.lastUpdated,
  });

  Map<String, dynamic> toMap() {
    return {
      'counter': counter,
      'name': name,
      'lastUpdated': lastUpdated.toIso8601String(),
    };
  }

  static TestState fromMap(Map<String, dynamic> map) {
    return TestState(
      counter: map['counter'] as int,
      name: map['name'] as String,
      lastUpdated: DateTime.parse(map['lastUpdated'] as String),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TestState &&
        other.counter == counter &&
        other.name == name &&
        other.lastUpdated == lastUpdated;
  }

  @override
  int get hashCode => Object.hash(counter, name, lastUpdated);
}

void main() {
  group('CBOR Serialization Tests', () {
    setUpAll(() {
      // Register test events
      EventRegistry.register<TestEvent>(
        'TestEvent',
        TestEvent.fromMap,
      );
    });

    tearDownAll(() {
      EventRegistry.clear();
    });

    test('should serialize and deserialize events correctly', () {
      final event = TestEvent(
        data: 'test data',
        value: 42,
        metadata: {'userId': 'user123', 'sessionId': 'session456'},
      );

      final serialized = CborSerializer.serializeEvent(event);
      expect(serialized, isA<List<int>>());
      expect(serialized.isNotEmpty, isTrue);

      final deserialized = CborSerializer.deserializeEvent(
        serialized,
        'TestEvent',
      );

      expect(deserialized, isA<TestEvent>());
      final testEvent = deserialized as TestEvent;
      expect(testEvent.data, equals('test data'));
      expect(testEvent.value, equals(42));
      expect(testEvent.metadata['userId'], equals('user123'));
      expect(testEvent.metadata['sessionId'], equals('session456'));
    });

    test('should serialize and deserialize state objects correctly', () {
      final state = TestState(
        counter: 100,
        name: 'test state',
        lastUpdated: DateTime.now(),
      );

      final serialized = CborSerializer.serializeState(state);
      expect(serialized, isA<List<int>>());
      expect(serialized.isNotEmpty, isTrue);

      final deserialized = CborSerializer.deserializeState(
        serialized,
        'TestState',
      );

      expect(deserialized, isA<Map>());
      final stateMap = deserialized as Map<String, dynamic>;
      expect(stateMap['counter'], equals(100));
      expect(stateMap['name'], equals('test state'));
    });

    test('should serialize and deserialize metadata correctly', () {
      final metadata = {
        'userId': 'user123',
        'sessionId': 'session456',
        'correlationId': 'corr789',
      };

      final serialized = CborSerializer.serializeMetadata(metadata);
      expect(serialized, isA<List<int>>());
      expect(serialized.isNotEmpty, isTrue);

      final deserialized = CborSerializer.deserializeMetadata(serialized);
      expect(deserialized, equals(metadata));
    });

    test('should handle complex data types in serialization', () {
      final event = TestEvent(
        data: 'complex data with special chars: äöü 中文 🚀',
        value: -42,
        metadata: {
          'timestamp': DateTime.now().toIso8601String(),
          'nested': {'key': 'value', 'number': 123},
          'list': ['item1', 'item2', 'item3'],
        },
      );

      final serialized = CborSerializer.serializeEvent(event);
      final deserialized = CborSerializer.deserializeEvent(
        serialized,
        'TestEvent',
      ) as TestEvent;

      expect(deserialized.data, equals(event.data));
      expect(deserialized.value, equals(event.value));
    });

    test('should handle serialization errors gracefully', () {
      expect(
        () => CborSerializer.deserializeEvent([1, 2, 3], 'UnknownEvent'),
        throwsA(isA<EventDeserializationException>()),
      );
    });

    test('should handle large data efficiently', () {
      final largeData = 'x' * 10000; // 10KB string
      final event = TestEvent(data: largeData, value: 1);
      
      final serialized = CborSerializer.serializeEvent(event);
      final deserialized = CborSerializer.deserializeEvent(
        serialized,
        'TestEvent',
      ) as TestEvent;
      
      expect(deserialized.data, equals(largeData));
      expect(deserialized.value, equals(1));
    });

    test('should handle null values correctly', () {
      final state = <String, dynamic>{
        'nullValue': null,
        'stringValue': 'test',
        'intValue': 42,
      };

      final serialized = CborSerializer.serializeState(state);
      final deserialized = CborSerializer.deserializeState(
        serialized,
        'Map',
      ) as Map<String, dynamic>;

      expect(deserialized['nullValue'], isNull);
      expect(deserialized['stringValue'], equals('test'));
      expect(deserialized['intValue'], equals(42));
    });

    test('should handle DateTime serialization correctly', () {
      final now = DateTime.now();
      final event = TestEvent(
        data: 'test',
        value: 1,
        timestamp: now,
      );

      final serialized = CborSerializer.serializeEvent(event);
      final deserialized = CborSerializer.deserializeEvent(
        serialized,
        'TestEvent',
      ) as TestEvent;

      // Compare timestamps (allowing for small differences due to serialization)
      expect(
        deserialized.timestamp.difference(now).inMilliseconds.abs(),
        lessThan(1000),
      );
    });
  });
}
