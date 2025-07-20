import 'package:isar/isar.dart';

/// Isar collection for storing projection read models.
/// 
/// This provides generic storage for read models created by projections,
/// using CBOR serialization for efficient storage and retrieval.
@collection
class ProjectionReadModel {
  Id id = Isar.autoIncrement;
  
  /// ID of the projection that owns this read model
  @Index()
  late String projectionId;
  
  /// Unique identifier for this specific read model instance
  @Index()
  late String modelId;
  
  /// CBOR-encoded read model data
  late List<int> modelData;
  
  /// Type name of the read model for deserialization
  late String modelType;
  
  /// When this read model was last updated
  late DateTime lastUpdated;
  
  /// Version of the read model schema
  late int schemaVersion;
  
  /// Size of the serialized data in bytes
  late int sizeBytes;
  
  /// Additional metadata for the read model
  @ignore
  late Map<String, String> metadata;
  
  /// Composite index for efficient queries by projection and model
  @Index(composite: [CompositeIndex('modelId')])
  late String projectionId_modelId;
  
  ProjectionReadModel() {
    metadata = <String, String>{};
    schemaVersion = 1;
    lastUpdated = DateTime.now();
    sizeBytes = 0;
  }
  
  /// Helper to set the composite index
  void setCompositeIndex() {
    projectionId_modelId = '${projectionId}_$modelId';
  }
}

/// Isar collection for storing projection read model indexes.
/// 
/// This allows for efficient querying of read models by custom criteria
/// without having to deserialize the full model data.
@collection
class ProjectionReadModelIndex {
  Id id = Isar.autoIncrement;
  
  /// ID of the projection that owns this index
  @Index()
  late String projectionId;
  
  /// ID of the read model this index points to
  @Index()
  late String modelId;
  
  /// Name of the indexed field
  @Index()
  late String fieldName;
  
  /// String value for the indexed field (if applicable)
  @Index()
  String? stringValue;
  
  /// Numeric value for the indexed field (if applicable)
  @Index()
  double? numericValue;
  
  /// Date value for the indexed field (if applicable)
  @Index()
  DateTime? dateValue;
  
  /// Boolean value for the indexed field (if applicable)
  @Index()
  bool? boolValue;
  
  /// When this index entry was created
  late DateTime createdAt;
  
  /// Composite index for efficient field queries
  @Index(composite: [CompositeIndex('fieldName'), CompositeIndex('stringValue')])
  late String projectionId_fieldName_stringValue;
  
  @Index(composite: [CompositeIndex('fieldName'), CompositeIndex('numericValue')])
  late String projectionId_fieldName_numericValue;
  
  ProjectionReadModelIndex() {
    createdAt = DateTime.now();
  }
  
  /// Helper to set composite indexes
  void setCompositeIndexes() {
    projectionId_fieldName_stringValue = '${projectionId}_${fieldName}_${stringValue ?? ''}';
    projectionId_fieldName_numericValue = '${projectionId}_${fieldName}_${numericValue ?? 0}';
  }
}
