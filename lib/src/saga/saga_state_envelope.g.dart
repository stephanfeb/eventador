// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'saga_state_envelope.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetSagaStateEnvelopeCollection on Isar {
  IsarCollection<SagaStateEnvelope> get sagaStateEnvelopes => this.collection();
}

const SagaStateEnvelopeSchema = CollectionSchema(
  name: r'SagaStateEnvelope',
  id: -4798130509396218606,
  properties: {
    r'lastUpdatedAt': PropertySchema(
      id: 0,
      name: r'lastUpdatedAt',
      type: IsarType.dateTime,
    ),
    r'persistenceId': PropertySchema(
      id: 1,
      name: r'persistenceId',
      type: IsarType.string,
    ),
    r'stateData': PropertySchema(
      id: 2,
      name: r'stateData',
      type: IsarType.longList,
    ),
    r'stateType': PropertySchema(
      id: 3,
      name: r'stateType',
      type: IsarType.string,
    ),
    r'status': PropertySchema(
      id: 4,
      name: r'status',
      type: IsarType.byte,
      enumMap: _SagaStateEnvelopestatusEnumValueMap,
    )
  },
  estimateSize: _sagaStateEnvelopeEstimateSize,
  serialize: _sagaStateEnvelopeSerialize,
  deserialize: _sagaStateEnvelopeDeserialize,
  deserializeProp: _sagaStateEnvelopeDeserializeProp,
  idName: r'id',
  indexes: {
    r'persistenceId': IndexSchema(
      id: -3073586296047114750,
      name: r'persistenceId',
      unique: true,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'persistenceId',
          type: IndexType.hash,
          caseSensitive: true,
        )
      ],
    )
  },
  links: {},
  embeddedSchemas: {},
  getId: _sagaStateEnvelopeGetId,
  getLinks: _sagaStateEnvelopeGetLinks,
  attach: _sagaStateEnvelopeAttach,
  version: '3.1.0+1',
);

int _sagaStateEnvelopeEstimateSize(
  SagaStateEnvelope object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.persistenceId.length * 3;
  bytesCount += 3 + object.stateData.length * 8;
  bytesCount += 3 + object.stateType.length * 3;
  return bytesCount;
}

void _sagaStateEnvelopeSerialize(
  SagaStateEnvelope object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeDateTime(offsets[0], object.lastUpdatedAt);
  writer.writeString(offsets[1], object.persistenceId);
  writer.writeLongList(offsets[2], object.stateData);
  writer.writeString(offsets[3], object.stateType);
  writer.writeByte(offsets[4], object.status.index);
}

SagaStateEnvelope _sagaStateEnvelopeDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = SagaStateEnvelope();
  object.id = id;
  object.lastUpdatedAt = reader.readDateTime(offsets[0]);
  object.persistenceId = reader.readString(offsets[1]);
  object.stateData = reader.readLongList(offsets[2]) ?? [];
  object.stateType = reader.readString(offsets[3]);
  object.status =
      _SagaStateEnvelopestatusValueEnumMap[reader.readByteOrNull(offsets[4])] ??
          SagaStatus.running;
  return object;
}

P _sagaStateEnvelopeDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readDateTime(offset)) as P;
    case 1:
      return (reader.readString(offset)) as P;
    case 2:
      return (reader.readLongList(offset) ?? []) as P;
    case 3:
      return (reader.readString(offset)) as P;
    case 4:
      return (_SagaStateEnvelopestatusValueEnumMap[
              reader.readByteOrNull(offset)] ??
          SagaStatus.running) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

const _SagaStateEnvelopestatusEnumValueMap = {
  'running': 0,
  'completed': 1,
  'compensating': 2,
  'failed': 3,
};
const _SagaStateEnvelopestatusValueEnumMap = {
  0: SagaStatus.running,
  1: SagaStatus.completed,
  2: SagaStatus.compensating,
  3: SagaStatus.failed,
};

Id _sagaStateEnvelopeGetId(SagaStateEnvelope object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _sagaStateEnvelopeGetLinks(
    SagaStateEnvelope object) {
  return [];
}

void _sagaStateEnvelopeAttach(
    IsarCollection<dynamic> col, Id id, SagaStateEnvelope object) {
  object.id = id;
}

extension SagaStateEnvelopeByIndex on IsarCollection<SagaStateEnvelope> {
  Future<SagaStateEnvelope?> getByPersistenceId(String persistenceId) {
    return getByIndex(r'persistenceId', [persistenceId]);
  }

  SagaStateEnvelope? getByPersistenceIdSync(String persistenceId) {
    return getByIndexSync(r'persistenceId', [persistenceId]);
  }

  Future<bool> deleteByPersistenceId(String persistenceId) {
    return deleteByIndex(r'persistenceId', [persistenceId]);
  }

  bool deleteByPersistenceIdSync(String persistenceId) {
    return deleteByIndexSync(r'persistenceId', [persistenceId]);
  }

  Future<List<SagaStateEnvelope?>> getAllByPersistenceId(
      List<String> persistenceIdValues) {
    final values = persistenceIdValues.map((e) => [e]).toList();
    return getAllByIndex(r'persistenceId', values);
  }

  List<SagaStateEnvelope?> getAllByPersistenceIdSync(
      List<String> persistenceIdValues) {
    final values = persistenceIdValues.map((e) => [e]).toList();
    return getAllByIndexSync(r'persistenceId', values);
  }

  Future<int> deleteAllByPersistenceId(List<String> persistenceIdValues) {
    final values = persistenceIdValues.map((e) => [e]).toList();
    return deleteAllByIndex(r'persistenceId', values);
  }

  int deleteAllByPersistenceIdSync(List<String> persistenceIdValues) {
    final values = persistenceIdValues.map((e) => [e]).toList();
    return deleteAllByIndexSync(r'persistenceId', values);
  }

  Future<Id> putByPersistenceId(SagaStateEnvelope object) {
    return putByIndex(r'persistenceId', object);
  }

  Id putByPersistenceIdSync(SagaStateEnvelope object, {bool saveLinks = true}) {
    return putByIndexSync(r'persistenceId', object, saveLinks: saveLinks);
  }

  Future<List<Id>> putAllByPersistenceId(List<SagaStateEnvelope> objects) {
    return putAllByIndex(r'persistenceId', objects);
  }

  List<Id> putAllByPersistenceIdSync(List<SagaStateEnvelope> objects,
      {bool saveLinks = true}) {
    return putAllByIndexSync(r'persistenceId', objects, saveLinks: saveLinks);
  }
}

extension SagaStateEnvelopeQueryWhereSort
    on QueryBuilder<SagaStateEnvelope, SagaStateEnvelope, QWhere> {
  QueryBuilder<SagaStateEnvelope, SagaStateEnvelope, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension SagaStateEnvelopeQueryWhere
    on QueryBuilder<SagaStateEnvelope, SagaStateEnvelope, QWhereClause> {
  QueryBuilder<SagaStateEnvelope, SagaStateEnvelope, QAfterWhereClause>
      idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: id,
        upper: id,
      ));
    });
  }

  QueryBuilder<SagaStateEnvelope, SagaStateEnvelope, QAfterWhereClause>
      idNotEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            )
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            );
      } else {
        return query
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            )
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            );
      }
    });
  }

  QueryBuilder<SagaStateEnvelope, SagaStateEnvelope, QAfterWhereClause>
      idGreaterThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<SagaStateEnvelope, SagaStateEnvelope, QAfterWhereClause>
      idLessThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<SagaStateEnvelope, SagaStateEnvelope, QAfterWhereClause>
      idBetween(
    Id lowerId,
    Id upperId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: lowerId,
        includeLower: includeLower,
        upper: upperId,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<SagaStateEnvelope, SagaStateEnvelope, QAfterWhereClause>
      persistenceIdEqualTo(String persistenceId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'persistenceId',
        value: [persistenceId],
      ));
    });
  }

  QueryBuilder<SagaStateEnvelope, SagaStateEnvelope, QAfterWhereClause>
      persistenceIdNotEqualTo(String persistenceId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'persistenceId',
              lower: [],
              upper: [persistenceId],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'persistenceId',
              lower: [persistenceId],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'persistenceId',
              lower: [persistenceId],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'persistenceId',
              lower: [],
              upper: [persistenceId],
              includeUpper: false,
            ));
      }
    });
  }
}

extension SagaStateEnvelopeQueryFilter
    on QueryBuilder<SagaStateEnvelope, SagaStateEnvelope, QFilterCondition> {
  QueryBuilder<SagaStateEnvelope, SagaStateEnvelope, QAfterFilterCondition>
      idEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<SagaStateEnvelope, SagaStateEnvelope, QAfterFilterCondition>
      idGreaterThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<SagaStateEnvelope, SagaStateEnvelope, QAfterFilterCondition>
      idLessThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<SagaStateEnvelope, SagaStateEnvelope, QAfterFilterCondition>
      idBetween(
    Id lower,
    Id upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'id',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<SagaStateEnvelope, SagaStateEnvelope, QAfterFilterCondition>
      lastUpdatedAtEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'lastUpdatedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<SagaStateEnvelope, SagaStateEnvelope, QAfterFilterCondition>
      lastUpdatedAtGreaterThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'lastUpdatedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<SagaStateEnvelope, SagaStateEnvelope, QAfterFilterCondition>
      lastUpdatedAtLessThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'lastUpdatedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<SagaStateEnvelope, SagaStateEnvelope, QAfterFilterCondition>
      lastUpdatedAtBetween(
    DateTime lower,
    DateTime upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'lastUpdatedAt',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<SagaStateEnvelope, SagaStateEnvelope, QAfterFilterCondition>
      persistenceIdEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'persistenceId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SagaStateEnvelope, SagaStateEnvelope, QAfterFilterCondition>
      persistenceIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'persistenceId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SagaStateEnvelope, SagaStateEnvelope, QAfterFilterCondition>
      persistenceIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'persistenceId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SagaStateEnvelope, SagaStateEnvelope, QAfterFilterCondition>
      persistenceIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'persistenceId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SagaStateEnvelope, SagaStateEnvelope, QAfterFilterCondition>
      persistenceIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'persistenceId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SagaStateEnvelope, SagaStateEnvelope, QAfterFilterCondition>
      persistenceIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'persistenceId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SagaStateEnvelope, SagaStateEnvelope, QAfterFilterCondition>
      persistenceIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'persistenceId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SagaStateEnvelope, SagaStateEnvelope, QAfterFilterCondition>
      persistenceIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'persistenceId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SagaStateEnvelope, SagaStateEnvelope, QAfterFilterCondition>
      persistenceIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'persistenceId',
        value: '',
      ));
    });
  }

  QueryBuilder<SagaStateEnvelope, SagaStateEnvelope, QAfterFilterCondition>
      persistenceIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'persistenceId',
        value: '',
      ));
    });
  }

  QueryBuilder<SagaStateEnvelope, SagaStateEnvelope, QAfterFilterCondition>
      stateDataElementEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'stateData',
        value: value,
      ));
    });
  }

  QueryBuilder<SagaStateEnvelope, SagaStateEnvelope, QAfterFilterCondition>
      stateDataElementGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'stateData',
        value: value,
      ));
    });
  }

  QueryBuilder<SagaStateEnvelope, SagaStateEnvelope, QAfterFilterCondition>
      stateDataElementLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'stateData',
        value: value,
      ));
    });
  }

  QueryBuilder<SagaStateEnvelope, SagaStateEnvelope, QAfterFilterCondition>
      stateDataElementBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'stateData',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<SagaStateEnvelope, SagaStateEnvelope, QAfterFilterCondition>
      stateDataLengthEqualTo(int length) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'stateData',
        length,
        true,
        length,
        true,
      );
    });
  }

  QueryBuilder<SagaStateEnvelope, SagaStateEnvelope, QAfterFilterCondition>
      stateDataIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'stateData',
        0,
        true,
        0,
        true,
      );
    });
  }

  QueryBuilder<SagaStateEnvelope, SagaStateEnvelope, QAfterFilterCondition>
      stateDataIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'stateData',
        0,
        false,
        999999,
        true,
      );
    });
  }

  QueryBuilder<SagaStateEnvelope, SagaStateEnvelope, QAfterFilterCondition>
      stateDataLengthLessThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'stateData',
        0,
        true,
        length,
        include,
      );
    });
  }

  QueryBuilder<SagaStateEnvelope, SagaStateEnvelope, QAfterFilterCondition>
      stateDataLengthGreaterThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'stateData',
        length,
        include,
        999999,
        true,
      );
    });
  }

  QueryBuilder<SagaStateEnvelope, SagaStateEnvelope, QAfterFilterCondition>
      stateDataLengthBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'stateData',
        lower,
        includeLower,
        upper,
        includeUpper,
      );
    });
  }

  QueryBuilder<SagaStateEnvelope, SagaStateEnvelope, QAfterFilterCondition>
      stateTypeEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'stateType',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SagaStateEnvelope, SagaStateEnvelope, QAfterFilterCondition>
      stateTypeGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'stateType',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SagaStateEnvelope, SagaStateEnvelope, QAfterFilterCondition>
      stateTypeLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'stateType',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SagaStateEnvelope, SagaStateEnvelope, QAfterFilterCondition>
      stateTypeBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'stateType',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SagaStateEnvelope, SagaStateEnvelope, QAfterFilterCondition>
      stateTypeStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'stateType',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SagaStateEnvelope, SagaStateEnvelope, QAfterFilterCondition>
      stateTypeEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'stateType',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SagaStateEnvelope, SagaStateEnvelope, QAfterFilterCondition>
      stateTypeContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'stateType',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SagaStateEnvelope, SagaStateEnvelope, QAfterFilterCondition>
      stateTypeMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'stateType',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SagaStateEnvelope, SagaStateEnvelope, QAfterFilterCondition>
      stateTypeIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'stateType',
        value: '',
      ));
    });
  }

  QueryBuilder<SagaStateEnvelope, SagaStateEnvelope, QAfterFilterCondition>
      stateTypeIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'stateType',
        value: '',
      ));
    });
  }

  QueryBuilder<SagaStateEnvelope, SagaStateEnvelope, QAfterFilterCondition>
      statusEqualTo(SagaStatus value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'status',
        value: value,
      ));
    });
  }

  QueryBuilder<SagaStateEnvelope, SagaStateEnvelope, QAfterFilterCondition>
      statusGreaterThan(
    SagaStatus value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'status',
        value: value,
      ));
    });
  }

  QueryBuilder<SagaStateEnvelope, SagaStateEnvelope, QAfterFilterCondition>
      statusLessThan(
    SagaStatus value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'status',
        value: value,
      ));
    });
  }

  QueryBuilder<SagaStateEnvelope, SagaStateEnvelope, QAfterFilterCondition>
      statusBetween(
    SagaStatus lower,
    SagaStatus upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'status',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }
}

extension SagaStateEnvelopeQueryObject
    on QueryBuilder<SagaStateEnvelope, SagaStateEnvelope, QFilterCondition> {}

extension SagaStateEnvelopeQueryLinks
    on QueryBuilder<SagaStateEnvelope, SagaStateEnvelope, QFilterCondition> {}

extension SagaStateEnvelopeQuerySortBy
    on QueryBuilder<SagaStateEnvelope, SagaStateEnvelope, QSortBy> {
  QueryBuilder<SagaStateEnvelope, SagaStateEnvelope, QAfterSortBy>
      sortByLastUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastUpdatedAt', Sort.asc);
    });
  }

  QueryBuilder<SagaStateEnvelope, SagaStateEnvelope, QAfterSortBy>
      sortByLastUpdatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastUpdatedAt', Sort.desc);
    });
  }

  QueryBuilder<SagaStateEnvelope, SagaStateEnvelope, QAfterSortBy>
      sortByPersistenceId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'persistenceId', Sort.asc);
    });
  }

  QueryBuilder<SagaStateEnvelope, SagaStateEnvelope, QAfterSortBy>
      sortByPersistenceIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'persistenceId', Sort.desc);
    });
  }

  QueryBuilder<SagaStateEnvelope, SagaStateEnvelope, QAfterSortBy>
      sortByStateType() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'stateType', Sort.asc);
    });
  }

  QueryBuilder<SagaStateEnvelope, SagaStateEnvelope, QAfterSortBy>
      sortByStateTypeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'stateType', Sort.desc);
    });
  }

  QueryBuilder<SagaStateEnvelope, SagaStateEnvelope, QAfterSortBy>
      sortByStatus() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'status', Sort.asc);
    });
  }

  QueryBuilder<SagaStateEnvelope, SagaStateEnvelope, QAfterSortBy>
      sortByStatusDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'status', Sort.desc);
    });
  }
}

extension SagaStateEnvelopeQuerySortThenBy
    on QueryBuilder<SagaStateEnvelope, SagaStateEnvelope, QSortThenBy> {
  QueryBuilder<SagaStateEnvelope, SagaStateEnvelope, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<SagaStateEnvelope, SagaStateEnvelope, QAfterSortBy>
      thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<SagaStateEnvelope, SagaStateEnvelope, QAfterSortBy>
      thenByLastUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastUpdatedAt', Sort.asc);
    });
  }

  QueryBuilder<SagaStateEnvelope, SagaStateEnvelope, QAfterSortBy>
      thenByLastUpdatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastUpdatedAt', Sort.desc);
    });
  }

  QueryBuilder<SagaStateEnvelope, SagaStateEnvelope, QAfterSortBy>
      thenByPersistenceId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'persistenceId', Sort.asc);
    });
  }

  QueryBuilder<SagaStateEnvelope, SagaStateEnvelope, QAfterSortBy>
      thenByPersistenceIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'persistenceId', Sort.desc);
    });
  }

  QueryBuilder<SagaStateEnvelope, SagaStateEnvelope, QAfterSortBy>
      thenByStateType() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'stateType', Sort.asc);
    });
  }

  QueryBuilder<SagaStateEnvelope, SagaStateEnvelope, QAfterSortBy>
      thenByStateTypeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'stateType', Sort.desc);
    });
  }

  QueryBuilder<SagaStateEnvelope, SagaStateEnvelope, QAfterSortBy>
      thenByStatus() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'status', Sort.asc);
    });
  }

  QueryBuilder<SagaStateEnvelope, SagaStateEnvelope, QAfterSortBy>
      thenByStatusDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'status', Sort.desc);
    });
  }
}

extension SagaStateEnvelopeQueryWhereDistinct
    on QueryBuilder<SagaStateEnvelope, SagaStateEnvelope, QDistinct> {
  QueryBuilder<SagaStateEnvelope, SagaStateEnvelope, QDistinct>
      distinctByLastUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'lastUpdatedAt');
    });
  }

  QueryBuilder<SagaStateEnvelope, SagaStateEnvelope, QDistinct>
      distinctByPersistenceId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'persistenceId',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<SagaStateEnvelope, SagaStateEnvelope, QDistinct>
      distinctByStateData() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'stateData');
    });
  }

  QueryBuilder<SagaStateEnvelope, SagaStateEnvelope, QDistinct>
      distinctByStateType({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'stateType', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<SagaStateEnvelope, SagaStateEnvelope, QDistinct>
      distinctByStatus() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'status');
    });
  }
}

extension SagaStateEnvelopeQueryProperty
    on QueryBuilder<SagaStateEnvelope, SagaStateEnvelope, QQueryProperty> {
  QueryBuilder<SagaStateEnvelope, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<SagaStateEnvelope, DateTime, QQueryOperations>
      lastUpdatedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'lastUpdatedAt');
    });
  }

  QueryBuilder<SagaStateEnvelope, String, QQueryOperations>
      persistenceIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'persistenceId');
    });
  }

  QueryBuilder<SagaStateEnvelope, List<int>, QQueryOperations>
      stateDataProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'stateData');
    });
  }

  QueryBuilder<SagaStateEnvelope, String, QQueryOperations>
      stateTypeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'stateType');
    });
  }

  QueryBuilder<SagaStateEnvelope, SagaStatus, QQueryOperations>
      statusProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'status');
    });
  }
}
