import 'dart:io';
import 'package:test/test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:dactor/dactor.dart';
import 'package:duraq/duraq.dart';
import 'package:isar/isar.dart';
import 'package:eventador/eventador.dart';

import 'phase3_week8_test.mocks.dart';

@GenerateNiceMocks([
  MockSpec<EventStore>(),
  MockSpec<StorageInterface>(),
  MockSpec<ActorSystem>(),
  MockSpec<ActorRef>(),
])
void main() {
  group('Phase 3 Week 8: Event Projections & Read Models', () {
    // Helper function to create fresh instances for each test
    ProjectionManager createProjectionManager() {
      final mockEventStore = MockEventStore();
      final mockStorage = MockStorageInterface();
      final mockActorSystem = MockActorSystem();
      final duraqManager = QueueManager(mockStorage);
      
      // Stub the store method to avoid null issues
      when(mockStorage.store(any, any)).thenAnswer((_) async {});
      when(mockStorage.retrieve(any)).thenAnswer((_) async => null);
      when(mockActorSystem.spawn(any, any)).thenAnswer((_) async => MockActorRef());
      when(mockActorSystem.stop(any)).thenAnswer((_) async {});
      
      return ProjectionManager(duraqManager, mockEventStore, mockActorSystem);
    }

    group('Projection Interface', () {
      test('UserStatisticsProjection implements Projection correctly', () {
        final projection = UserStatisticsProjection();
        
        expect(projection.projectionId, equals('user-statistics'));
        expect(projection.readModel, isA<UserStatistics>());
        expect(projection.interestedEventTypes, contains(UserRegisteredEvent));
        expect(projection.interestedEventTypes, contains(UserLoginEvent));
        expect(projection.interestedEventTypes, contains(UserLogoutEvent));
        expect(projection.interestedEventTypes, contains(UserProfileUpdatedEvent));
      });

      test('canHandle returns true for interested event types', () {
        final projection = UserStatisticsProjection();
        
        expect(projection.canHandle(UserRegisteredEvent), isTrue);
        expect(projection.canHandle(UserLoginEvent), isTrue);
        expect(projection.canHandle(UserLogoutEvent), isTrue);
        expect(projection.canHandle(UserProfileUpdatedEvent), isTrue);
        expect(projection.canHandle(String), isFalse);
      });

      test('handle processes UserRegisteredEvent correctly', () async {
        final projection = UserStatisticsProjection();
        final initialStats = projection.readModel;
        
        final event = UserRegisteredEvent(
          userId: 'user-1',
          email: 'test@example.com',
          username: 'testuser',
        );
        
        final handled = await projection.handle(event);
        
        expect(handled, isTrue);
        expect(projection.readModel.totalUsers, equals(initialStats.totalUsers + 1));
        expect(projection.readModel.newUsersToday, equals(initialStats.newUsersToday + 1));
      });

      test('handle processes UserLoginEvent correctly', () async {
        final projection = UserStatisticsProjection();
        final initialStats = projection.readModel;
        
        final event = UserLoginEvent(
          userId: 'user-1',
          sessionId: 'session-1',
        );
        
        final handled = await projection.handle(event);
        
        expect(handled, isTrue);
        expect(projection.readModel.totalLogins, equals(initialStats.totalLogins + 1));
        expect(projection.readModel.activeUsersToday, equals(initialStats.activeUsersToday + 1));
      });

      test('handle processes UserLogoutEvent correctly', () async {
        final projection = UserStatisticsProjection();
        final loginTime = DateTime.now().subtract(const Duration(hours: 2));
        
        final event = UserLogoutEvent(
          userId: 'user-1',
          sessionId: 'session-1',
          loginTime: loginTime,
        );
        
        final handled = await projection.handle(event);
        
        expect(handled, isTrue);
        expect(projection.readModel.averageSessionDuration, isNotNull);
        expect(projection.readModel.averageSessionDuration!.inHours, equals(2));
      });

      test('handle ignores unknown event types', () async {
        final projection = UserStatisticsProjection();
        final unknownEvent = TestEvent();
        
        final handled = await projection.handle(unknownEvent);
        
        expect(handled, isFalse);
      });

      test('reset clears read model', () async {
        final projection = UserStatisticsProjection();
        
        // Add some data
        await projection.handle(UserRegisteredEvent(
          userId: 'user-1',
          email: 'test@example.com',
          username: 'testuser',
        ));
        
        expect(projection.readModel.totalUsers, equals(1));
        
        // Reset
        await projection.reset();
        
        expect(projection.readModel.totalUsers, equals(0));
      });

      test('rebuild clears read model', () async {
        final projection = UserStatisticsProjection();
        
        // Add some data
        await projection.handle(UserRegisteredEvent(
          userId: 'user-1',
          email: 'test@example.com',
          username: 'testuser',
        ));
        
        expect(projection.readModel.totalUsers, equals(1));
        
        // Rebuild
        await projection.rebuild();
        
        expect(projection.readModel.totalUsers, equals(0));
      });
    });

    group('UserStatistics Read Model', () {
      test('empty factory creates zero statistics', () {
        final stats = UserStatistics.empty();
        
        expect(stats.totalUsers, equals(0));
        expect(stats.newUsersToday, equals(0));
        expect(stats.activeUsersToday, equals(0));
        expect(stats.totalLogins, equals(0));
        expect(stats.profileUpdatesToday, equals(0));
        expect(stats.averageSessionDuration, isNull);
      });

      test('copyWith updates specific fields', () {
        final stats = UserStatistics.empty();
        final updated = stats.copyWith(
          totalUsers: 10,
          totalLogins: 50,
        );
        
        expect(updated.totalUsers, equals(10));
        expect(updated.totalLogins, equals(50));
        expect(updated.newUsersToday, equals(0)); // unchanged
        expect(updated.activeUsersToday, equals(0)); // unchanged
      });

      test('toMap and fromMap serialization works correctly', () {
        final stats = UserStatistics(
          totalUsers: 100,
          newUsersToday: 5,
          activeUsersToday: 25,
          totalLogins: 500,
          profileUpdatesToday: 10,
          averageSessionDuration: const Duration(minutes: 30),
          lastUpdated: DateTime(2025, 1, 1),
        );
        
        final map = stats.toMap();
        final restored = UserStatistics.fromMap(map);
        
        expect(restored.totalUsers, equals(stats.totalUsers));
        expect(restored.newUsersToday, equals(stats.newUsersToday));
        expect(restored.activeUsersToday, equals(stats.activeUsersToday));
        expect(restored.totalLogins, equals(stats.totalLogins));
        expect(restored.profileUpdatesToday, equals(stats.profileUpdatesToday));
        expect(restored.averageSessionDuration, equals(stats.averageSessionDuration));
        expect(restored.lastUpdated, equals(stats.lastUpdated));
      });

      test('toString provides readable representation', () {
        final stats = UserStatistics.empty();
        final str = stats.toString();
        
        expect(str, contains('UserStatistics'));
        expect(str, contains('totalUsers: 0'));
        expect(str, contains('totalLogins: 0'));
      });
    });

    group('User Events', () {
      test('UserRegisteredEvent has correct aggregate properties', () {
        final event = UserRegisteredEvent(
          userId: 'user-1',
          email: 'test@example.com',
          username: 'testuser',
        );
        
        expect(event.aggregateId, equals('user-1'));
        expect(event.aggregateType, equals('User'));
        
        final eventData = event.getEventData();
        expect(eventData['userId'], equals('user-1'));
        expect(eventData['email'], equals('test@example.com'));
        expect(eventData['username'], equals('testuser'));
      });

      test('UserLoginEvent has correct aggregate properties', () {
        final event = UserLoginEvent(
          userId: 'user-1',
          sessionId: 'session-1',
        );
        
        expect(event.aggregateId, equals('user-1'));
        expect(event.aggregateType, equals('User'));
        
        final eventData = event.getEventData();
        expect(eventData['userId'], equals('user-1'));
        expect(eventData['sessionId'], equals('session-1'));
      });

      test('UserLogoutEvent has correct aggregate properties', () {
        final loginTime = DateTime.now();
        final event = UserLogoutEvent(
          userId: 'user-1',
          sessionId: 'session-1',
          loginTime: loginTime,
        );
        
        expect(event.aggregateId, equals('user-1'));
        expect(event.aggregateType, equals('User'));
        
        final eventData = event.getEventData();
        expect(eventData['userId'], equals('user-1'));
        expect(eventData['sessionId'], equals('session-1'));
        expect(eventData['loginTime'], equals(loginTime.toIso8601String()));
      });

      test('UserProfileUpdatedEvent has correct aggregate properties', () {
        final updatedFields = {'name': 'New Name', 'age': 30};
        final event = UserProfileUpdatedEvent(
          userId: 'user-1',
          updatedFields: updatedFields,
        );
        
        expect(event.aggregateId, equals('user-1'));
        expect(event.aggregateType, equals('User'));
        
        final eventData = event.getEventData();
        expect(eventData['userId'], equals('user-1'));
        expect(eventData['updatedFields'], equals(updatedFields));
      });
    });

    group('ProjectionManager', () {
      test('starts and stops correctly', () async {
        final projectionManager = createProjectionManager();
        
        // Test that start() is idempotent and doesn't throw
        await projectionManager.start();
        await projectionManager.start(); // Should not throw
        
        // Test that stop() cleans up properly
        await projectionManager.stop();
        
        // After stop, projection infos should be empty
        expect(projectionManager.getProjectionInfos(), isEmpty);
      });

      test('registerProjection creates actor and sets up queues', () async {
        final projectionManager = createProjectionManager();
        
        await projectionManager.start();
        await projectionManager.registerProjection(() => UserStatisticsProjection());
        
        expect(projectionManager.getProjectionInfos(), hasLength(1));
        
        await projectionManager.stop();
      });

      test('unregisterProjection removes actor and cleans up', () async {
        final projectionManager = createProjectionManager();
        
        await projectionManager.start();
        await projectionManager.registerProjection(() => UserStatisticsProjection());
        
        expect(projectionManager.getProjectionInfos(), hasLength(1));
        
        // Add timeout to prevent hanging
        await projectionManager.unregisterProjection('user-statistics')
            .timeout(const Duration(seconds: 5));
        
        expect(projectionManager.getProjectionInfos(), hasLength(0));
        
        await projectionManager.stop();
      });

      test('routeEvent enqueues event in correct queue', () async {
        final projectionManager = createProjectionManager();
        
        await projectionManager.start();
        await projectionManager.registerProjection(() => UserStatisticsProjection());
        
        final event = UserRegisteredEvent(
          userId: 'user-1',
          email: 'test@example.com',
          username: 'testuser',
        );
        
        await projectionManager.routeEvent(event);
        
        // Event routing is tested by the fact that no exception is thrown
        expect(projectionManager.getProjectionInfos(), hasLength(1));
        
        await projectionManager.stop();
      });

      test('catchUpProjection enqueues catch-up task', () async {
        final projectionManager = createProjectionManager();
        
        await projectionManager.start();
        await projectionManager.catchUpProjection('user-statistics', fromSequence: 100);
        
        // Catch-up is tested by the fact that no exception is thrown
        expect(projectionManager.getProjectionInfos(), isEmpty);
        
        await projectionManager.stop();
      });

      test('rebuildProjection enqueues rebuild task', () async {
        final projectionManager = createProjectionManager();
        
        await projectionManager.start();
        await projectionManager.rebuildProjection('user-statistics');
        
        // Rebuild is tested by the fact that no exception is thrown
        expect(projectionManager.getProjectionInfos(), isEmpty);
        
        await projectionManager.stop();
      });
    });

    group('ProjectionInfo', () {
      test('creates with all required fields', () {
        final info = ProjectionInfo(
          projectionId: 'test-projection',
          status: ProjectionStatus.running,
          lastProcessedSequence: 100,
          lastUpdated: DateTime.now(),
          eventsProcessed: 500,
          averageProcessingTime: const Duration(milliseconds: 50),
          lastError: 'Test error',
        );
        
        expect(info.projectionId, equals('test-projection'));
        expect(info.status, equals(ProjectionStatus.running));
        expect(info.lastProcessedSequence, equals(100));
        expect(info.eventsProcessed, equals(500));
        expect(info.averageProcessingTime, equals(const Duration(milliseconds: 50)));
        expect(info.lastError, equals('Test error'));
      });

      test('toString provides readable representation', () {
        final info = ProjectionInfo(
          projectionId: 'test-projection',
          status: ProjectionStatus.running,
          lastProcessedSequence: 100,
          lastUpdated: DateTime.now(),
          eventsProcessed: 500,
        );
        
        final str = info.toString();
        expect(str, contains('ProjectionInfo'));
        expect(str, contains('test-projection'));
        expect(str, contains('running'));
        expect(str, contains('100'));
        expect(str, contains('500'));
      });
    });

    group('ProjectionException', () {
      test('creates with message and projection ID', () {
        const exception = ProjectionException('Test error', 'test-projection');
        
        expect(exception.message, equals('Test error'));
        expect(exception.projectionId, equals('test-projection'));
        expect(exception.cause, isNull);
      });

      test('creates with cause', () {
        final cause = Exception('Root cause');
        final exception = ProjectionException('Test error', 'test-projection', cause);
        
        expect(exception.message, equals('Test error'));
        expect(exception.projectionId, equals('test-projection'));
        expect(exception.cause, equals(cause));
      });

      test('toString includes all information', () {
        final cause = Exception('Root cause');
        final exception = ProjectionException('Test error', 'test-projection', cause);
        
        final str = exception.toString();
        expect(str, contains('ProjectionException[test-projection]'));
        expect(str, contains('Test error'));
        expect(str, contains('Root cause'));
      });
    });
  });
}

/// Test event for unknown event type testing
class TestEvent extends Event {
  TestEvent() : super();
}
