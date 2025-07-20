// Phase 2 Week 5 Tests - AggregateRoot Implementation
// Tests for domain entity modeling patterns with event sourcing

import 'dart:io';
import 'package:test/test.dart';
import 'package:isar/isar.dart';
import 'package:eventador/eventador.dart';

void main() {
  group('Phase 2 Week 5 - AggregateRoot Implementation', () {
    late Isar isar;
    late EventStore eventStore;
    late Directory tempDir;

    setUpAll(() async {
      // Create temporary directory for test database
      tempDir = await Directory.systemTemp.createTemp('eventador_test_');
    });

    setUp(() async {
      // Initialize Isar database for each test
      await Isar.initializeIsarCore(download: true);
      isar = await Isar.open(
        [EventEnvelopeSchema, SnapshotEnvelopeSchema],
        directory: tempDir.path,
        name: 'test_${DateTime.now().millisecondsSinceEpoch}',
      );
      eventStore = IsarEventStore(isar);
      
      // Register event types for deserialization
      EventRegistry.clear();
      EventRegistry.register<AccountCreatedEvent>(
        'AccountCreatedEvent',
        AccountCreatedEvent.fromMap,
      );
      EventRegistry.register<MoneyDepositedEvent>(
        'MoneyDepositedEvent',
        MoneyDepositedEvent.fromMap,
      );
      EventRegistry.register<MoneyWithdrawnEvent>(
        'MoneyWithdrawnEvent',
        MoneyWithdrawnEvent.fromMap,
      );
    });

    tearDown(() async {
      await isar.close();
    });

    tearDownAll(() async {
      // Clean up temporary directory
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    group('BankAccount Aggregate Example', () {
      test('should create and initialize bank account aggregate', () async {
        final account = TestBankAccount(
          aggregateId: 'account-123',
          eventStore: eventStore,
        );

        expect(account.aggregateId, equals('account-123'));
        expect(account.aggregateType, equals('BankAccount'));
        expect(account.persistenceId, equals('BankAccount_account-123'));
        expect(account.isInitialized, isFalse);
        expect(account.state, isNull);
      });

      test('should handle account creation command', () async {
        final account = TestBankAccount(
          aggregateId: 'account-123',
          eventStore: eventStore,
        );

        // Start the actor to trigger recovery
        account.preStart();
        await Future.delayed(Duration(milliseconds: 100)); // Wait for recovery

        // Create account
        final createCommand = CreateAccountCommand(
          aggregateId: 'account-123',
          accountHolderName: 'John Doe',
          initialBalance: 1000.0,
        );

        await account.commandHandler(createCommand);

        expect(account.isInitialized, isTrue);
        expect(account.currentState.accountHolderName, equals('John Doe'));
        expect(account.currentState.balance, equals(1000.0));
        expect(account.currentState.version, equals(1));
      });

      test('should handle deposit command', () async {
        final account = TestBankAccount(
          aggregateId: 'account-123',
          eventStore: eventStore,
        );

        account.preStart();
        await Future.delayed(Duration(milliseconds: 100));

        // Create account
        await account.commandHandler(CreateAccountCommand(
          aggregateId: 'account-123',
          accountHolderName: 'John Doe',
          initialBalance: 1000.0,
        ));

        // Deposit money
        final depositCommand = DepositCommand(
          aggregateId: 'account-123',
          amount: 500.0,
          expectedVersion: 1,
        );

        await account.commandHandler(depositCommand);

        expect(account.currentState.balance, equals(1500.0));
        expect(account.currentState.version, equals(2));
      });

      test('should handle withdrawal command with sufficient funds', () async {
        final account = TestBankAccount(
          aggregateId: 'account-123',
          eventStore: eventStore,
        );

        account.preStart();
        await Future.delayed(Duration(milliseconds: 100));

        // Create account
        await account.commandHandler(CreateAccountCommand(
          aggregateId: 'account-123',
          accountHolderName: 'John Doe',
          initialBalance: 1000.0,
        ));

        // Withdraw money
        final withdrawCommand = WithdrawCommand(
          aggregateId: 'account-123',
          amount: 300.0,
          expectedVersion: 1,
        );

        await account.commandHandler(withdrawCommand);

        expect(account.currentState.balance, equals(700.0));
        expect(account.currentState.version, equals(2));
      });

      test('should reject withdrawal command with insufficient funds', () async {
        final account = TestBankAccount(
          aggregateId: 'account-123',
          eventStore: eventStore,
        );

        account.preStart();
        await Future.delayed(Duration(milliseconds: 100));

        // Create account
        await account.commandHandler(CreateAccountCommand(
          aggregateId: 'account-123',
          accountHolderName: 'John Doe',
          initialBalance: 1000.0,
        ));

        // Try to withdraw more than balance
        final withdrawCommand = WithdrawCommand(
          aggregateId: 'account-123',
          amount: 1500.0,
          expectedVersion: 1,
        );

        expect(
          () => account.commandHandler(withdrawCommand),
          throwsA(isA<CommandHandlingException>()),
        );

        // Balance should remain unchanged
        expect(account.currentState.balance, equals(1000.0));
        expect(account.currentState.version, equals(1));
      });

      test('should enforce optimistic concurrency control', () async {
        final account = TestBankAccount(
          aggregateId: 'account-123',
          eventStore: eventStore,
        );

        account.preStart();
        await Future.delayed(Duration(milliseconds: 100));

        // Create account
        await account.commandHandler(CreateAccountCommand(
          aggregateId: 'account-123',
          accountHolderName: 'John Doe',
          initialBalance: 1000.0,
        ));

        // Try to deposit with wrong expected version
        final depositCommand = DepositCommand(
          aggregateId: 'account-123',
          amount: 500.0,
          expectedVersion: 0, // Wrong version
        );

        expect(
          () => account.commandHandler(depositCommand),
          throwsA(isA<OptimisticConcurrencyException>()),
        );
      });

      test('should recover aggregate state from events', () async {
        // First, create and modify an account
        final account1 = TestBankAccount(
          aggregateId: 'account-123',
          eventStore: eventStore,
        );

        account1.preStart();
        await Future.delayed(Duration(milliseconds: 100));

        await account1.commandHandler(CreateAccountCommand(
          aggregateId: 'account-123',
          accountHolderName: 'John Doe',
          initialBalance: 1000.0,
        ));

        await account1.commandHandler(DepositCommand(
          aggregateId: 'account-123',
          amount: 500.0,
          expectedVersion: 1,
        ));

        await account1.commandHandler(WithdrawCommand(
          aggregateId: 'account-123',
          amount: 200.0,
          expectedVersion: 2,
        ));

        // Create a new instance and verify recovery
        final account2 = TestBankAccount(
          aggregateId: 'account-123',
          eventStore: eventStore,
        );

        account2.preStart();
        await Future.delayed(Duration(milliseconds: 100));

        expect(account2.isInitialized, isTrue);
        expect(account2.currentState.accountHolderName, equals('John Doe'));
        expect(account2.currentState.balance, equals(1300.0));
        expect(account2.currentState.version, equals(3));
      });

      test('should support event replay', () async {
        final account = TestBankAccount(
          aggregateId: 'account-123',
          eventStore: eventStore,
        );

        // Create some events
        final events = [
          AccountCreatedEvent(
            aggregateId: 'account-123',
            accountHolderName: 'John Doe',
            initialBalance: 1000.0,
            version: 1,
          ),
          MoneyDepositedEvent(
            aggregateId: 'account-123',
            amount: 500.0,
            newBalance: 1500.0,
            version: 2,
          ),
          MoneyWithdrawnEvent(
            aggregateId: 'account-123',
            amount: 200.0,
            newBalance: 1300.0,
            version: 3,
          ),
        ];

        // Replay events
        account.replay(events);

        expect(account.isInitialized, isTrue);
        expect(account.currentState.accountHolderName, equals('John Doe'));
        expect(account.currentState.balance, equals(1300.0));
        expect(account.currentState.version, equals(3));
      });

      test('should create and restore from snapshots', () async {
        final account = TestBankAccount(
          aggregateId: 'account-123',
          eventStore: eventStore,
        );

        account.preStart();
        await Future.delayed(Duration(milliseconds: 100));

        // Create and modify account
        await account.commandHandler(CreateAccountCommand(
          aggregateId: 'account-123',
          accountHolderName: 'John Doe',
          initialBalance: 1000.0,
        ));

        await account.commandHandler(DepositCommand(
          aggregateId: 'account-123',
          amount: 500.0,
          expectedVersion: 1,
        ));

        // Create snapshot
        await account.createSnapshot();

        // Create new instance and verify snapshot recovery
        final account2 = TestBankAccount(
          aggregateId: 'account-123',
          eventStore: eventStore,
        );

        account2.preStart();
        await Future.delayed(Duration(milliseconds: 100));

        expect(account2.isInitialized, isTrue);
        expect(account2.currentState.accountHolderName, equals('John Doe'));
        expect(account2.currentState.balance, equals(1500.0));
        expect(account2.currentState.version, equals(2));
      });

      test('should provide aggregate information', () async {
        final account = TestBankAccount(
          aggregateId: 'account-123',
          eventStore: eventStore,
        );

        account.preStart();
        await Future.delayed(Duration(milliseconds: 100));

        await account.commandHandler(CreateAccountCommand(
          aggregateId: 'account-123',
          accountHolderName: 'John Doe',
          initialBalance: 1000.0,
        ));

        final info = account.getAggregateInfo();

        expect(info.aggregateId, equals('account-123'));
        expect(info.aggregateType, equals('BankAccount'));
        expect(info.persistenceId, equals('BankAccount_account-123'));
        expect(info.isInitialized, isTrue);
        expect(info.currentVersion, equals(1));
        expect(info.isRecovered, isTrue);
        expect(info.registeredCommandHandlers, greaterThan(0));
        expect(info.registeredEventHandlers, greaterThan(0));
      });
    });

    group('AggregateRegistry', () {
      test('should register and create aggregates', () {
        AggregateRegistry.clear();

        // Register bank account aggregate
        AggregateRegistry.register<TestBankAccount>(
          'BankAccount',
          (aggregateId, eventStore) => TestBankAccount(
            aggregateId: aggregateId,
            eventStore: eventStore,
          ),
        );

        expect(AggregateRegistry.isRegistered('BankAccount'), isTrue);
        expect(AggregateRegistry.getRegisteredTypes(), contains('BankAccount'));

        // Create aggregate instance
        final account = AggregateRegistry.create(
          'BankAccount',
          'account-123',
          eventStore,
        );

        expect(account, isNotNull);
        expect(account, isA<TestBankAccount>());
        expect(account!.aggregateId, equals('account-123'));
      });

      test('should return null for unregistered aggregate types', () {
        AggregateRegistry.clear();

        final account = AggregateRegistry.create(
          'UnknownAggregate',
          'test-123',
          eventStore,
        );

        expect(account, isNull);
      });
    });

    group('Exception Handling', () {
      test('should throw OptimisticConcurrencyException for version conflicts', () async {
        final account = TestBankAccount(
          aggregateId: 'account-123',
          eventStore: eventStore,
        );

        account.preStart();
        await Future.delayed(Duration(milliseconds: 100));

        await account.commandHandler(CreateAccountCommand(
          aggregateId: 'account-123',
          accountHolderName: 'John Doe',
          initialBalance: 1000.0,
        ));

        expect(
          () => account.checkConcurrency(0),
          throwsA(isA<OptimisticConcurrencyException>()),
        );
      });

      test('should throw StateError for uninitialized aggregate', () {
        final account = TestBankAccount(
          aggregateId: 'account-123',
          eventStore: eventStore,
        );

        expect(
          () => account.currentState,
          throwsA(isA<StateError>()),
        );
      });
    });
  });
}

// Test implementations for BankAccount aggregate

class BankAccountState extends State with ValidatableState, SerializableState, SnapshotableState {
  final String accountHolderName;
  final double balance;
  final bool isActive;

  BankAccountState({
    required this.accountHolderName,
    required this.balance,
    this.isActive = true,
    int version = 0,
    DateTime? lastModified,
  }) : super(version: version, lastModified: lastModified);

  @override
  BankAccountState copyWith({
    String? accountHolderName,
    double? balance,
    bool? isActive,
    int? version,
    DateTime? lastModified,
  }) {
    return BankAccountState(
      accountHolderName: accountHolderName ?? this.accountHolderName,
      balance: balance ?? this.balance,
      isActive: isActive ?? this.isActive,
      version: version ?? this.version,
      lastModified: lastModified ?? this.lastModified,
    );
  }

  @override
  Map<String, dynamic> getStateData() {
    return {
      'accountHolderName': accountHolderName,
      'balance': balance,
      'isActive': isActive,
    };
  }

  static BankAccountState fromMap(Map<String, dynamic> map) {
    return BankAccountState(
      accountHolderName: map['accountHolderName'] as String,
      balance: (map['balance'] as num).toDouble(),
      isActive: map['isActive'] as bool? ?? true,
      version: map['version'] as int? ?? 0,
      lastModified: map['lastModified'] != null
          ? (map['lastModified'] is String 
              ? DateTime.parse(map['lastModified'] as String)
              : map['lastModified'] as DateTime)
          : null,
    );
  }

  @override
  BankAccountState restoreFromSnapshot(Map<String, dynamic> snapshot) {
    return fromMap(snapshot);
  }

  @override
  List<String> getCustomValidationErrors() {
    final errors = <String>[];
    if (accountHolderName.isEmpty) {
      errors.add('Account holder name cannot be empty');
    }
    if (balance < 0) {
      errors.add('Account balance cannot be negative');
    }
    return errors;
  }
}

// Commands
class CreateAccountCommand extends AggregateCommand with ValidatableCommand {
  final String accountHolderName;
  final double initialBalance;

  CreateAccountCommand({
    required String aggregateId,
    required this.accountHolderName,
    required this.initialBalance,
    int? expectedVersion,
  }) : super(
          aggregateId: aggregateId,
          aggregateType: 'BankAccount',
          expectedVersion: expectedVersion,
        );

  @override
  Map<String, dynamic> toMap() {
    final map = super.toMap();
    map.addAll({
      'accountHolderName': accountHolderName,
      'initialBalance': initialBalance,
    });
    return map;
  }

  @override
  List<String> getCustomValidationErrors() {
    final errors = <String>[];
    if (accountHolderName.isEmpty) {
      errors.add('Account holder name cannot be empty');
    }
    if (initialBalance < 0) {
      errors.add('Initial balance cannot be negative');
    }
    return errors;
  }
}

class DepositCommand extends AggregateCommand with ValidatableCommand {
  final double amount;

  DepositCommand({
    required String aggregateId,
    required this.amount,
    int? expectedVersion,
  }) : super(
          aggregateId: aggregateId,
          aggregateType: 'BankAccount',
          expectedVersion: expectedVersion,
        );

  @override
  Map<String, dynamic> toMap() {
    final map = super.toMap();
    map['amount'] = amount;
    return map;
  }

  @override
  List<String> getCustomValidationErrors() {
    final errors = <String>[];
    if (amount <= 0) {
      errors.add('Deposit amount must be positive');
    }
    return errors;
  }
}

class WithdrawCommand extends AggregateCommand with ValidatableCommand {
  final double amount;

  WithdrawCommand({
    required String aggregateId,
    required this.amount,
    int? expectedVersion,
  }) : super(
          aggregateId: aggregateId,
          aggregateType: 'BankAccount',
          expectedVersion: expectedVersion,
        );

  @override
  Map<String, dynamic> toMap() {
    final map = super.toMap();
    map['amount'] = amount;
    return map;
  }

  @override
  List<String> getCustomValidationErrors() {
    final errors = <String>[];
    if (amount <= 0) {
      errors.add('Withdrawal amount must be positive');
    }
    return errors;
  }
}

// Events
class AccountCreatedEvent extends AggregateEventBase with SerializableEvent {
  final String accountHolderName;
  final double initialBalance;

  AccountCreatedEvent({
    required String aggregateId,
    required this.accountHolderName,
    required this.initialBalance,
    String? eventId,
    DateTime? timestamp,
    int? version,
    Map<String, dynamic>? metadata,
  }) : super(
          aggregateId: aggregateId,
          aggregateType: 'BankAccount',
          eventId: eventId,
          timestamp: timestamp,
          version: version,
          metadata: metadata,
        );

  @override
  Map<String, dynamic> getEventData() {
    return {
      'accountHolderName': accountHolderName,
      'initialBalance': initialBalance,
    };
  }

  static AccountCreatedEvent fromMap(Map<String, dynamic> map) {
    return AccountCreatedEvent(
      aggregateId: map['aggregateId'] as String,
      accountHolderName: map['accountHolderName'] as String,
      initialBalance: (map['initialBalance'] as num).toDouble(),
      eventId: map['eventId'] as String?,
      timestamp: map['timestamp'] != null
          ? (map['timestamp'] is String 
              ? DateTime.parse(map['timestamp'] as String)
              : map['timestamp'] as DateTime)
          : null,
      version: map['version'] as int?,
      metadata: map['metadata'] as Map<String, dynamic>?,
    );
  }
}

class MoneyDepositedEvent extends AggregateEventBase with SerializableEvent {
  final double amount;
  final double newBalance;

  MoneyDepositedEvent({
    required String aggregateId,
    required this.amount,
    required this.newBalance,
    String? eventId,
    DateTime? timestamp,
    int? version,
    Map<String, dynamic>? metadata,
  }) : super(
          aggregateId: aggregateId,
          aggregateType: 'BankAccount',
          eventId: eventId,
          timestamp: timestamp,
          version: version,
          metadata: metadata,
        );

  @override
  Map<String, dynamic> getEventData() {
    return {
      'amount': amount,
      'newBalance': newBalance,
    };
  }

  static MoneyDepositedEvent fromMap(Map<String, dynamic> map) {
    return MoneyDepositedEvent(
      aggregateId: map['aggregateId'] as String,
      amount: (map['amount'] as num).toDouble(),
      newBalance: (map['newBalance'] as num).toDouble(),
      eventId: map['eventId'] as String?,
      timestamp: map['timestamp'] != null
          ? (map['timestamp'] is String 
              ? DateTime.parse(map['timestamp'] as String)
              : map['timestamp'] as DateTime)
          : null,
      version: map['version'] as int?,
      metadata: map['metadata'] as Map<String, dynamic>?,
    );
  }
}

class MoneyWithdrawnEvent extends AggregateEventBase with SerializableEvent {
  final double amount;
  final double newBalance;

  MoneyWithdrawnEvent({
    required String aggregateId,
    required this.amount,
    required this.newBalance,
    String? eventId,
    DateTime? timestamp,
    int? version,
    Map<String, dynamic>? metadata,
  }) : super(
          aggregateId: aggregateId,
          aggregateType: 'BankAccount',
          eventId: eventId,
          timestamp: timestamp,
          version: version,
          metadata: metadata,
        );

  @override
  Map<String, dynamic> getEventData() {
    return {
      'amount': amount,
      'newBalance': newBalance,
    };
  }

  static MoneyWithdrawnEvent fromMap(Map<String, dynamic> map) {
    return MoneyWithdrawnEvent(
      aggregateId: map['aggregateId'] as String,
      amount: (map['amount'] as num).toDouble(),
      newBalance: (map['newBalance'] as num).toDouble(),
      eventId: map['eventId'] as String?,
      timestamp: map['timestamp'] != null
          ? (map['timestamp'] is String 
              ? DateTime.parse(map['timestamp'] as String)
              : map['timestamp'] as DateTime)
          : null,
      version: map['version'] as int?,
      metadata: map['metadata'] as Map<String, dynamic>?,
    );
  }
}

// Command Handlers
class CreateAccountCommandHandler extends AggregateCommandHandler<BankAccountState> {
  @override
  String get aggregateId => '';

  @override
  String get aggregateType => 'BankAccount';

  @override
  bool canHandle(Command command) {
    return command is CreateAccountCommand;
  }

  @override
  List<Event> handle(BankAccountState currentState, Command command) {
    final createCommand = command as CreateAccountCommand;

    return [
      AccountCreatedEvent(
        aggregateId: createCommand.aggregateId,
        accountHolderName: createCommand.accountHolderName,
        initialBalance: createCommand.initialBalance,
        version: currentState.version + 1,
      ),
    ];
  }
}

class DepositCommandHandler extends AggregateCommandHandler<BankAccountState> {
  @override
  String get aggregateId => '';

  @override
  String get aggregateType => 'BankAccount';

  @override
  bool canHandle(Command command) {
    return command is DepositCommand;
  }

  @override
  List<Event> handle(BankAccountState currentState, Command command) {
    final depositCommand = command as DepositCommand;
    final newBalance = currentState.balance + depositCommand.amount;

    return [
      MoneyDepositedEvent(
        aggregateId: depositCommand.aggregateId,
        amount: depositCommand.amount,
        newBalance: newBalance,
        version: currentState.version + 1,
      ),
    ];
  }
}

class WithdrawCommandHandler extends AggregateCommandHandler<BankAccountState> {
  @override
  String get aggregateId => '';

  @override
  String get aggregateType => 'BankAccount';

  @override
  bool canHandle(Command command) {
    return command is WithdrawCommand;
  }

  @override
  List<Event> handle(BankAccountState currentState, Command command) {
    final withdrawCommand = command as WithdrawCommand;

    // Business rule: Cannot withdraw more than current balance
    if (withdrawCommand.amount > currentState.balance) {
      throw CommandHandlingException(
        command,
        'Insufficient funds: cannot withdraw ${withdrawCommand.amount}, balance is ${currentState.balance}',
      );
    }

    final newBalance = currentState.balance - withdrawCommand.amount;

    return [
      MoneyWithdrawnEvent(
        aggregateId: withdrawCommand.aggregateId,
        amount: withdrawCommand.amount,
        newBalance: newBalance,
        version: currentState.version + 1,
      ),
    ];
  }
}

// Event Handlers
class AccountCreatedEventHandler extends AggregateEventHandler<BankAccountState> {
  @override
  String get aggregateType => 'BankAccount';

  @override
  bool canApply(Event event) {
    return event is AccountCreatedEvent;
  }

  @override
  BankAccountState apply(BankAccountState currentState, Event event) {
    final createdEvent = event as AccountCreatedEvent;

    return BankAccountState(
      accountHolderName: createdEvent.accountHolderName,
      balance: createdEvent.initialBalance,
      version: createdEvent.version,
      lastModified: createdEvent.timestamp,
    );
  }
}

class MoneyDepositedEventHandler extends AggregateEventHandler<BankAccountState> {
  @override
  String get aggregateType => 'BankAccount';

  @override
  bool canApply(Event event) {
    return event is MoneyDepositedEvent;
  }

  @override
  BankAccountState apply(BankAccountState currentState, Event event) {
    final depositedEvent = event as MoneyDepositedEvent;

    return currentState.copyWith(
      balance: depositedEvent.newBalance,
      version: depositedEvent.version,
      lastModified: depositedEvent.timestamp,
    );
  }
}

class MoneyWithdrawnEventHandler extends AggregateEventHandler<BankAccountState> {
  @override
  String get aggregateType => 'BankAccount';

  @override
  bool canApply(Event event) {
    return event is MoneyWithdrawnEvent;
  }

  @override
  BankAccountState apply(BankAccountState currentState, Event event) {
    final withdrawnEvent = event as MoneyWithdrawnEvent;

    return currentState.copyWith(
      balance: withdrawnEvent.newBalance,
      version: withdrawnEvent.version,
      lastModified: withdrawnEvent.timestamp,
    );
  }
}

// Test BankAccount Aggregate
class TestBankAccount extends AggregateRoot<BankAccountState> {
  TestBankAccount({
    required String aggregateId,
    required EventStore eventStore,
  }) : super(
          aggregateId: aggregateId,
          aggregateType: 'BankAccount',
          eventStore: eventStore,
        ) {
    // Register handlers immediately upon construction
    registerHandlers();
  }

  @override
  void registerHandlers() {
    // Register command handlers
    commandHandlers.register<CreateAccountCommand>(CreateAccountCommandHandler());
    commandHandlers.register<DepositCommand>(DepositCommandHandler());
    commandHandlers.register<WithdrawCommand>(WithdrawCommandHandler());

    // Register event handlers
    eventHandlers.register<AccountCreatedEvent>(AccountCreatedEventHandler());
    eventHandlers.register<MoneyDepositedEvent>(MoneyDepositedEventHandler());
    eventHandlers.register<MoneyWithdrawnEvent>(MoneyWithdrawnEventHandler());
  }

  @override
  BankAccountState createInitialState() {
    return BankAccountState(
      accountHolderName: '',
      balance: 0.0,
      version: 0,
    );
  }

  @override
  Future<BankAccountState> restoreStateFromMap(Map<String, dynamic> map, int sequenceNumber) async {
    return BankAccountState.fromMap(map);
  }
}
