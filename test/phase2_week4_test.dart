// Phase 2 Week 4 tests - Command/Event/State Abstractions
// Tests for enhanced command/event type system, state management, and event application patterns

import 'package:test/test.dart';
import 'package:eventador/eventador.dart';

// Test implementations for State
class TestState extends State with ValidatableState, SerializableState, SnapshotableState, ComparableState {
  final String name;
  final int value;

  TestState({
    required this.name,
    required this.value,
    int version = 0,
    DateTime? lastModified,
  }) : super(version: version, lastModified: lastModified);

  @override
  State copyWith({int? version, DateTime? lastModified}) {
    return TestState(
      name: name,
      value: value,
      version: version ?? this.version,
      lastModified: lastModified ?? this.lastModified,
    );
  }

  @override
  Map<String, dynamic> getStateData() {
    return {
      'name': name,
      'value': value,
    };
  }

  @override
  List<String> getCustomValidationErrors() {
    final errors = <String>[];
    if (name.isEmpty) {
      errors.add('Name cannot be empty');
    }
    if (value < 0) {
      errors.add('Value cannot be negative');
    }
    return errors;
  }

  @override
  State restoreFromSnapshot(Map<String, dynamic> snapshot) {
    return TestState(
      name: snapshot['name'] as String,
      value: snapshot['value'] as int,
      version: snapshot['version'] as int,
      lastModified: DateTime.parse(snapshot['lastModified'] as String),
    );
  }

  @override
  List<StateChange> getChangesFrom(State other) {
    final changes = super.getChangesFrom(other);
    if (other is TestState) {
      if (name != other.name) {
        changes.add(StateChange.fieldChanged('name', other.name, name));
      }
      if (value != other.value) {
        changes.add(StateChange.fieldChanged('value', other.value, value));
      }
    }
    return changes;
  }

  static TestState fromMap(Map<String, dynamic> map) {
    return TestState(
      name: map['name'] as String,
      value: map['value'] as int,
      version: map['version'] as int,
      lastModified: DateTime.parse(map['lastModified'] as String),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TestState &&
           other.name == name &&
           other.value == value &&
           other.version == version;
  }

  @override
  int get hashCode => Object.hash(name, value, version);
}

// Test implementations for Commands
class TestCommand extends Command with ValidatableCommand, TargetedCommand, CorrelatedCommand {
  final String action;
  final int amount;
  final String _aggregateId;

  TestCommand({
    required this.action,
    required this.amount,
    required String aggregateId,
    String? commandId,
    DateTime? timestamp,
    Map<String, dynamic>? metadata,
  }) : _aggregateId = aggregateId,
       super(commandId: commandId, timestamp: timestamp, metadata: metadata);

  @override
  String get aggregateId => _aggregateId;

  @override
  Map<String, dynamic> toMap() {
    final map = super.toMap();
    map['action'] = action;
    map['amount'] = amount;
    return map;
  }

  @override
  List<String> getCustomValidationErrors() {
    final errors = <String>[];
    if (action.isEmpty) {
      errors.add('Action cannot be empty');
    }
    if (amount <= 0) {
      errors.add('Amount must be positive');
    }
    return errors;
  }

  static TestCommand fromMap(Map<String, dynamic> map) {
    return TestCommand(
      action: map['action'] as String,
      amount: map['amount'] as int,
      aggregateId: map['aggregateId'] as String,
      commandId: map['commandId'] as String,
      timestamp: DateTime.parse(map['timestamp'] as String),
      metadata: Map<String, dynamic>.from(map['metadata'] as Map),
    );
  }
}

// Test implementations for Events
class TestEvent extends Event with AggregateEvent, SerializableEvent, VersionedEvent, CorrelatedEvent {
  final String action;
  final int amount;
  final String _aggregateId;
  final String _aggregateType;

  TestEvent({
    required this.action,
    required this.amount,
    required String aggregateId,
    required String aggregateType,
    String? eventId,
    DateTime? timestamp,
    int? version,
    Map<String, dynamic>? metadata,
  }) : _aggregateId = aggregateId,
       _aggregateType = aggregateType,
       super(eventId: eventId, timestamp: timestamp, version: version, metadata: metadata);

  @override
  String get aggregateId => _aggregateId;

  @override
  String get aggregateType => _aggregateType;

  @override
  Map<String, dynamic> getEventData() {
    return {
      'action': action,
      'amount': amount,
    };
  }

  static TestEvent fromMap(Map<String, dynamic> map) {
    return TestEvent(
      action: map['action'] as String,
      amount: map['amount'] as int,
      aggregateId: map['aggregateId'] as String,
      aggregateType: map['aggregateType'] as String,
      eventId: map['eventId'] as String,
      timestamp: DateTime.parse(map['timestamp'] as String),
      version: map['version'] as int,
      metadata: Map<String, dynamic>.from(map['metadata'] as Map),
    );
  }
}

// Test Command Handler
class TestCommandHandler extends AggregateCommandHandler<TestState> {
  final String _aggregateId;
  final String _aggregateType;

  TestCommandHandler(this._aggregateId, this._aggregateType);

  @override
  String get aggregateId => _aggregateId;

  @override
  String get aggregateType => _aggregateType;

  @override
  List<Event> handle(TestState currentState, Command command) {
    if (command is TestCommand) {
      return [
        TestEvent(
          action: command.action,
          amount: command.amount,
          aggregateId: command.aggregateId,
          aggregateType: _aggregateType,
          version: currentState.version + 1,
        ),
      ];
    }
    return [];
  }

  @override
  bool checkAggregateRules(TestState currentState, Command command) {
    if (command is TestCommand && command.action == 'subtract') {
      return currentState.value >= command.amount;
    }
    return true;
  }

  @override
  List<String> getAggregateRuleViolations(TestState currentState, Command command) {
    final violations = <String>[];
    if (command is TestCommand && command.action == 'subtract') {
      if (currentState.value < command.amount) {
        violations.add('Insufficient value: ${currentState.value} < ${command.amount}');
      }
    }
    return violations;
  }
}

// Test Event Handler
class TestEventHandler extends AggregateEventHandler<TestState> {
  final String _aggregateType;

  TestEventHandler(this._aggregateType);

  @override
  String get aggregateType => _aggregateType;

  @override
  TestState apply(TestState currentState, Event event) {
    if (event is TestEvent) {
      int newValue = currentState.value;
      
      switch (event.action) {
        case 'add':
          newValue += event.amount;
          break;
        case 'subtract':
          newValue -= event.amount;
          break;
        case 'set':
          newValue = event.amount;
          break;
      }

      return TestState(
        name: currentState.name,
        value: newValue,
        version: event.version,
        lastModified: event.timestamp,
      );
    }
    return currentState;
  }

  @override
  bool checkAggregateInvariants(TestState newState, Event event) {
    // Value should never be negative after applying events
    return newState.value >= 0;
  }

  @override
  List<String> getAggregateInvariantViolations(TestState newState, Event event) {
    final violations = <String>[];
    if (newState.value < 0) {
      violations.add('Value cannot be negative: ${newState.value}');
    }
    return violations;
  }
}

void main() {
  group('Phase 2 Week 4 - Command/Event/State Abstractions', () {
    late TestState initialState;
    late TestCommand validCommand;
    late TestEvent validEvent;
    late TestCommandHandler commandHandler;
    late TestEventHandler eventHandler;

    setUp(() {
      initialState = TestState(name: 'test', value: 100);
      validCommand = TestCommand(
        action: 'add',
        amount: 50,
        aggregateId: 'test-aggregate',
      );
      validEvent = TestEvent(
        action: 'add',
        amount: 50,
        aggregateId: 'test-aggregate',
        aggregateType: 'TestAggregate',
        version: 1,
      );
      commandHandler = TestCommandHandler('test-aggregate', 'TestAggregate');
      eventHandler = TestEventHandler('TestAggregate');
    });

    group('State Management', () {
      test('should create state with version and timestamp', () {
        expect(initialState.version, equals(0));
        expect(initialState.lastModified, isA<DateTime>());
        expect(initialState.name, equals('test'));
        expect(initialState.value, equals(100));
      });

      test('should create next version of state', () {
        final nextState = initialState.nextVersion();
        expect(nextState.version, equals(1));
        expect(nextState.lastModified.isAfter(initialState.lastModified), isTrue);
      });

      test('should validate state correctly', () {
        expect(initialState.validate(), isTrue);
        expect(initialState.getValidationErrors(), isEmpty);

        final invalidState = TestState(name: '', value: -1);
        expect(invalidState.validate(), isFalse);
        expect(invalidState.getValidationErrors(), hasLength(2));
      });

      test('should serialize and deserialize state', () {
        final map = initialState.toMap();
        expect(map['name'], equals('test'));
        expect(map['value'], equals(100));
        expect(map['version'], equals(0));

        final restoredState = TestState.fromMap(map);
        expect(restoredState.name, equals(initialState.name));
        expect(restoredState.value, equals(initialState.value));
        expect(restoredState.version, equals(initialState.version));
      });

      test('should create and restore snapshots', () {
        final snapshot = initialState.createSnapshot();
        final restoredState = initialState.restoreFromSnapshot(snapshot) as TestState;
        expect(restoredState.name, equals(initialState.name));
        expect(restoredState.value, equals(initialState.value));
      });

      test('should detect state changes', () {
        final newState = TestState(name: 'updated', value: 200, version: 1);
        expect(newState.hasChangedFrom(initialState), isTrue);

        final changes = newState.getChangesFrom(initialState);
        expect(changes, hasLength(3)); // name, value, version
      });
    });

    group('Command Handling', () {
      test('should process valid command successfully', () {
        final result = commandHandler.process(initialState, validCommand);
        expect(result.isSuccess, isTrue);
        expect(result.events, hasLength(1));
        expect(result.errors, isEmpty);
      });

      test('should reject invalid command', () {
        final invalidCommand = TestCommand(
          action: '',
          amount: -10,
          aggregateId: 'test-aggregate',
        );
        final result = commandHandler.process(initialState, invalidCommand);
        expect(result.isFailure, isTrue);
        expect(result.errors, isNotEmpty);
      });

      test('should enforce business rules', () {
        final subtractCommand = TestCommand(
          action: 'subtract',
          amount: 150, // More than current value
          aggregateId: 'test-aggregate',
        );
        final result = commandHandler.process(initialState, subtractCommand);
        expect(result.isFailure, isTrue);
        expect(result.errors.first, contains('Insufficient value'));
      });

      test('should handle command registry', () {
        final registry = CommandHandlerRegistry<TestState>();
        registry.registerAggregate(commandHandler);

        final handler = registry.getHandler(validCommand);
        expect(handler, isNotNull);
        expect(handler, equals(commandHandler));
      });
    });

    group('Event Handling', () {
      test('should apply event successfully', () {
        final result = eventHandler.process(initialState, validEvent);
        expect(result.isSuccess, isTrue);
        expect(result.stateChanged, isTrue);
        expect(result.newState.value, equals(150)); // 100 + 50
      });

      test('should enforce invariants', () {
        final badEvent = TestEvent(
          action: 'subtract',
          amount: 200, // Would make value negative
          aggregateId: 'test-aggregate',
          aggregateType: 'TestAggregate',
          version: 1,
        );
        final result = eventHandler.process(initialState, badEvent);
        expect(result.isFailure, isTrue);
        expect(result.errors.first, contains('Value cannot be negative'));
      });

      test('should handle event registry', () {
        final registry = EventHandlerRegistry<TestState>();
        registry.registerAggregate(eventHandler);

        final handler = registry.getHandler(validEvent);
        expect(handler, isNotNull);
        expect(handler, equals(eventHandler));
      });

      test('should process event pipeline', () {
        final registry = EventHandlerRegistry<TestState>();
        registry.registerAggregate(eventHandler);
        final pipeline = EventApplicationPipeline<TestState>(registry);

        final events = [
          TestEvent(
            action: 'add',
            amount: 25,
            aggregateId: 'test-aggregate',
            aggregateType: 'TestAggregate',
            version: 1,
          ),
          TestEvent(
            action: 'subtract',
            amount: 10,
            aggregateId: 'test-aggregate',
            aggregateType: 'TestAggregate',
            version: 2,
          ),
        ];

        final result = pipeline.applyEvents(initialState, events);
        expect(result.isSuccess, isTrue);
        expect(result.finalState.value, equals(115)); // 100 + 25 - 10
        expect(result.successCount, equals(2));
      });
    });

    group('Composite Event Handler', () {
      test('should delegate to appropriate handler', () {
        final handler1 = TestEventHandler('Type1');
        final handler2 = TestEventHandler('Type2');
        final composite = CompositeEventHandler<TestState>([handler1, handler2]);

        final event1 = TestEvent(
          action: 'add',
          amount: 10,
          aggregateId: 'test',
          aggregateType: 'Type1',
          version: 1,
        );

        expect(composite.canApply(event1), isTrue);
        final newState = composite.apply(initialState, event1);
        expect(newState.value, equals(110));
      });

      test('should throw when no handler can apply event', () {
        final composite = CompositeEventHandler<TestState>([]);
        expect(
          () => composite.apply(initialState, validEvent),
          throwsA(isA<NoEventHandlerException>()),
        );
      });
    });

    group('State Registry', () {
      test('should register and retrieve state types', () {
        StateRegistry.register<TestState>('TestState', TestState.fromMap);
        expect(StateRegistry.isRegistered('TestState'), isTrue);
        expect(StateRegistry.getRegisteredTypes(), contains('TestState'));

        final map = initialState.toMap();
        final restoredState = StateRegistry.fromMap(map) as TestState;
        expect(restoredState, isA<TestState>());
        expect(restoredState.name, equals(initialState.name));
        expect(restoredState.value, equals(initialState.value));
      });

      test('should throw for unregistered state type', () {
        StateRegistry.clear();
        final map = {'type': 'UnknownState'};
        expect(
          () => StateRegistry.fromMap(map),
          throwsA(isA<ArgumentError>()),
        );
      });
    });

    group('Command Registry', () {
      test('should register and retrieve command types', () {
        CommandRegistry.register<TestCommand>('TestCommand', TestCommand.fromMap);
        expect(CommandRegistry.getRegisteredTypes(), contains('TestCommand'));

        final map = validCommand.toMap();
        final restoredCommand = CommandRegistry.fromMap(map);
        expect(restoredCommand, isA<TestCommand>());
      });
    });

    group('Event Registry', () {
      test('should register and retrieve event types', () {
        EventRegistry.register<TestEvent>('TestEvent', TestEvent.fromMap);
        expect(EventRegistry.getRegisteredTypes(), contains('TestEvent'));

        final map = validEvent.toMap();
        final restoredEvent = EventRegistry.fromMap(map);
        expect(restoredEvent, isA<TestEvent>());
      });
    });

    group('Exception Handling', () {
      test('should handle command validation exceptions', () {
        final invalidCommand = TestCommand(
          action: '',
          amount: -1,
          aggregateId: 'test',
        );
        final exception = CommandValidationException(invalidCommand, ['Invalid command']);
        expect(exception.toString(), contains('CommandValidationException'));
      });

      test('should handle state validation exceptions', () {
        final invalidState = TestState(name: '', value: -1);
        final exception = StateValidationException(invalidState, ['Invalid state']);
        expect(exception.toString(), contains('StateValidationException'));
      });

      test('should handle business rule violations', () {
        final command = TestCommand(action: 'test', amount: 1, aggregateId: 'test');
        final exception = BusinessRuleViolationException(command, ['Rule violated']);
        expect(exception.toString(), contains('BusinessRuleViolationException'));
      });
    });
  });
}
