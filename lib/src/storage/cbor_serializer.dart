// CBOR serialization utilities for events and snapshots
// Provides efficient binary serialization for Isar storage

import 'dart:convert';
import 'dart:typed_data';
import 'package:cbor/cbor.dart';
import '../event.dart';

/// Utility class for CBOR serialization and deserialization
class CborSerializer {
  /// Serialize an event to CBOR bytes
  static List<int> serializeEvent(Event event) {
    try {
      final eventMap = event.toMap();
      return _serializeMap(eventMap);
    } catch (e) {
      throw EventSerializationException('Failed to serialize event ${event.runtimeType}', e);
    }
  }

  /// Deserialize an event from CBOR bytes
  static Event deserializeEvent(List<int> bytes, String eventType) {
    try {
      final map = _deserializeMap(bytes);
      
      // Ensure the event type matches
      if (map['type'] != eventType) {
        throw EventDeserializationException(
          'Event type mismatch: expected $eventType, got ${map['type']}'
        );
      }
      
      return EventRegistry.fromMap(map);
    } catch (e) {
      if (e is EventDeserializationException) rethrow;
      throw EventDeserializationException('Failed to deserialize event of type $eventType', e);
    }
  }

  /// Serialize a state object to CBOR bytes
  static List<int> serializeState(dynamic state) {
    try {
      if (state == null) {
        return _serializeValue(null);
      }
      
      // If the state has a toMap method, use it
      if (state is Map<String, dynamic>) {
        return _serializeMap(state);
      } else if (_hasToMapMethod(state)) {
        final map = state.toMap() as Map<String, dynamic>;
        return _serializeMap(map);
      } else {
        // Fallback to JSON serialization for complex objects
        final json = jsonEncode(state);
        return _serializeValue(json);
      }
    } catch (e) {
      throw StateSerializationException('Failed to serialize state ${state.runtimeType}', e);
    }
  }

  /// Deserialize a state object from CBOR bytes
  static dynamic deserializeState(List<int> bytes, String stateType) {
    try {
      final value = _deserializeValue(bytes);
      
      // If it's a string, it might be JSON-encoded
      if (value is String) {
        try {
          return jsonDecode(value);
        } catch (_) {
          return value;
        }
      }
      
      return value;
    } catch (e) {
      throw StateDeserializationException('Failed to deserialize state of type $stateType', e);
    }
  }

  /// Serialize metadata map to CBOR bytes
  static List<int> serializeMetadata(Map<String, String> metadata) {
    try {
      return _serializeMap(metadata.cast<String, dynamic>());
    } catch (e) {
      throw MetadataSerializationException('Failed to serialize metadata', e);
    }
  }

  /// Deserialize metadata from CBOR bytes
  static Map<String, String> deserializeMetadata(List<int> bytes) {
    try {
      final map = _deserializeMap(bytes);
      return map.cast<String, String>();
    } catch (e) {
      throw MetadataDeserializationException('Failed to deserialize metadata', e);
    }
  }

  /// Serialize a map to CBOR bytes
  static List<int> _serializeMap(Map<String, dynamic> map) {
    final cborMap = CborMap(map.map((key, value) => MapEntry(CborString(key), _toCborValue(value))));
    return cborEncode(cborMap);
  }

  /// Deserialize a map from CBOR bytes
  static Map<String, dynamic> _deserializeMap(List<int> bytes) {
    final decoded = cborDecode(bytes);
    if (decoded is! CborMap) {
      throw ArgumentError('Expected CBOR map, got ${decoded.runtimeType}');
    }
    
    final result = _fromCborValue(decoded);
    if (result is Map) {
      return Map<String, dynamic>.from(result);
    } else {
      throw ArgumentError('Expected Map from CBOR decoding, got ${result.runtimeType}');
    }
  }

  /// Serialize any value to CBOR bytes
  static List<int> _serializeValue(dynamic value) {
    final cborValue = _toCborValue(value);
    return cborEncode(cborValue);
  }

  /// Deserialize any value from CBOR bytes
  static dynamic _deserializeValue(List<int> bytes) {
    final decoded = cborDecode(bytes);
    return _fromCborValue(decoded);
  }

  /// Convert a Dart value to CBOR value
  static CborValue _toCborValue(dynamic value) {
    if (value == null) return CborNull();
    if (value is String) return CborString(value);
    if (value is int) {
      // Handle large integers
      if (value >= -2147483648 && value <= 2147483647) {
        return CborSmallInt(value);
      } else {
        return CborInt(BigInt.from(value));
      }
    }
    if (value is double) return CborFloat(value);
    if (value is bool) return CborBool(value);
    if (value is DateTime) return CborString(value.toIso8601String());
    if (value is List) return CborList(value.map(_toCborValue).toList());
    if (value is Map) {
      return CborMap(value.map((k, v) => MapEntry(_toCborValue(k), _toCborValue(v))));
    }
    if (value is Uint8List) return CborBytes(value);
    
    // Fallback to string representation
    return CborString(value.toString());
  }

  /// Convert CBOR value to Dart value
  static dynamic _fromCborValue(CborValue value) {
    if (value is CborNull) return null;
    if (value is CborString) {
      final str = value.toString();
      // Try to parse as DateTime if it looks like ISO 8601
      if (_isIso8601String(str)) {
        try {
          return DateTime.parse(str);
        } catch (_) {
          return str;
        }
      }
      return str;
    }
    if (value is CborSmallInt) return value.value;
    if (value is CborInt) return value.toInt();
    if (value is CborFloat) return value.value;
    if (value is CborBool) return value.value;
    if (value is CborList) return value.map(_fromCborValue).toList();
    if (value is CborMap) {
      return Map<String, dynamic>.from(
        value.map((k, v) => MapEntry(_fromCborValue(k).toString(), _fromCborValue(v)))
      );
    }
    if (value is CborBytes) return value.bytes;
    
    return value.toString();
  }

  /// Check if a string looks like an ISO 8601 date
  static bool _isIso8601String(String str) {
    return RegExp(r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}').hasMatch(str);
  }

  /// Check if an object has a toMap method
  static bool _hasToMapMethod(dynamic object) {
    try {
      // Use reflection to check if the object has a toMap method
      if (object == null) return false;
      
      // Check if it's already a Map
      if (object is Map) return true;
      
      // Try to call toMap method
      try {
        final result = object.toMap();
        return result is Map;
      } catch (_) {
        return false;
      }
    } catch (_) {
      return false;
    }
  }

  /// Get the size of serialized data in bytes
  static int getSerializedSize(List<int> bytes) {
    return bytes.length;
  }

  /// Compress CBOR data (simple implementation)
  static List<int> compress(List<int> bytes) {
    // For now, return as-is. Could implement gzip compression later
    return bytes;
  }

  /// Decompress CBOR data
  static List<int> decompress(List<int> bytes) {
    // For now, return as-is. Could implement gzip decompression later
    return bytes;
  }
}

/// Exception thrown when event serialization fails
class EventSerializationException implements Exception {
  final String message;
  final dynamic cause;

  const EventSerializationException(this.message, [this.cause]);

  @override
  String toString() {
    final causeStr = cause != null ? ' (caused by: $cause)' : '';
    return 'EventSerializationException: $message$causeStr';
  }
}

/// Exception thrown when state serialization fails
class StateSerializationException implements Exception {
  final String message;
  final dynamic cause;

  const StateSerializationException(this.message, [this.cause]);

  @override
  String toString() {
    final causeStr = cause != null ? ' (caused by: $cause)' : '';
    return 'StateSerializationException: $message$causeStr';
  }
}

/// Exception thrown when metadata serialization fails
class MetadataSerializationException implements Exception {
  final String message;
  final dynamic cause;

  const MetadataSerializationException(this.message, [this.cause]);

  @override
  String toString() {
    final causeStr = cause != null ? ' (caused by: $cause)' : '';
    return 'MetadataSerializationException: $message$causeStr';
  }
}

/// Exception thrown when metadata deserialization fails
class MetadataDeserializationException implements Exception {
  final String message;
  final dynamic cause;

  const MetadataDeserializationException(this.message, [this.cause]);

  @override
  String toString() {
    final causeStr = cause != null ? ' (caused by: $cause)' : '';
    return 'MetadataDeserializationException: $message$causeStr';
  }
}

/// Exception thrown when state deserialization fails
class StateDeserializationException implements Exception {
  final String message;
  final dynamic cause;

  const StateDeserializationException(this.message, [this.cause]);

  @override
  String toString() {
    final causeStr = cause != null ? ' (caused by: $cause)' : '';
    return 'StateDeserializationException: $message$causeStr';
  }
}
