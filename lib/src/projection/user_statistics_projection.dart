import '../event.dart';
import '../storage/cbor_serializer.dart';
import 'projection.dart';
import 'projection_checkpoint.dart';

/// Example projection that builds user statistics from events.
/// 
/// This demonstrates how to create a concrete projection that processes
/// user-related events and builds a read model with statistics.
class UserStatisticsProjection extends Projection<UserStatistics> {
  UserStatistics _readModel = UserStatistics.empty();
  
  @override
  String get projectionId => 'user-statistics';
  
  @override
  UserStatistics get readModel => _readModel;
  
  @override
  List<Type> get interestedEventTypes => [
    UserRegisteredEvent,
    UserLoginEvent,
    UserLogoutEvent,
    UserProfileUpdatedEvent,
  ];
  
  @override
  Future<bool> handle(Event event) async {
    switch (event.runtimeType) {
      case UserRegisteredEvent:
        _handleUserRegistered(event as UserRegisteredEvent);
        return true;
      case UserLoginEvent:
        _handleUserLogin(event as UserLoginEvent);
        return true;
      case UserLogoutEvent:
        _handleUserLogout(event as UserLogoutEvent);
        return true;
      case UserProfileUpdatedEvent:
        _handleUserProfileUpdated(event as UserProfileUpdatedEvent);
        return true;
      default:
        return false;
    }
  }
  
  void _handleUserRegistered(UserRegisteredEvent event) {
    _readModel = _readModel.copyWith(
      totalUsers: _readModel.totalUsers + 1,
      newUsersToday: _readModel.newUsersToday + 1,
      lastUpdated: DateTime.now(),
    );
  }
  
  void _handleUserLogin(UserLoginEvent event) {
    _readModel = _readModel.copyWith(
      totalLogins: _readModel.totalLogins + 1,
      activeUsersToday: _readModel.activeUsersToday + 1,
      lastUpdated: DateTime.now(),
    );
  }
  
  void _handleUserLogout(UserLogoutEvent event) {
    // Update session duration statistics
    final sessionDuration = event.timestamp.difference(event.loginTime);
    final avgDuration = _readModel.averageSessionDuration;
    final newAverage = avgDuration != null
        ? Duration(milliseconds: ((avgDuration.inMilliseconds + sessionDuration.inMilliseconds) / 2).round())
        : sessionDuration;
    
    _readModel = _readModel.copyWith(
      averageSessionDuration: newAverage,
      lastUpdated: DateTime.now(),
    );
  }
  
  void _handleUserProfileUpdated(UserProfileUpdatedEvent event) {
    _readModel = _readModel.copyWith(
      profileUpdatesToday: _readModel.profileUpdatesToday + 1,
      lastUpdated: DateTime.now(),
    );
  }
  
  @override
  Future<void> rebuild() async {
    _readModel = UserStatistics.empty();
    // In a real implementation, this would replay all events
  }
  
  @override
  Future<void> reset() async {
    _readModel = UserStatistics.empty();
  }
  
  @override
  Future<int> getCheckpoint() async {
    // This would be loaded from storage
    return 0;
  }
  
  @override
  Future<void> updateCheckpoint(int sequenceNumber) async {
    // This would be saved to storage
  }
  
  @override
  Future<void> onStart() async {
    // Initialize projection
  }
  
  @override
  Future<void> onStop() async {
    // Cleanup projection
  }
  
  @override
  Future<void> onError(dynamic error, StackTrace stackTrace) async {
    // Handle projection errors
    print('UserStatisticsProjection error: $error');
  }
  
  @override
  Future<void> onBatchComplete(int eventsProcessed) async {
    // Called after processing a batch of events
    print('UserStatisticsProjection processed $eventsProcessed events');
  }
}

/// Read model for user statistics
class UserStatistics {
  final int totalUsers;
  final int newUsersToday;
  final int activeUsersToday;
  final int totalLogins;
  final int profileUpdatesToday;
  final Duration? averageSessionDuration;
  final DateTime lastUpdated;
  
  const UserStatistics({
    required this.totalUsers,
    required this.newUsersToday,
    required this.activeUsersToday,
    required this.totalLogins,
    required this.profileUpdatesToday,
    this.averageSessionDuration,
    required this.lastUpdated,
  });
  
  factory UserStatistics.empty() {
    return UserStatistics(
      totalUsers: 0,
      newUsersToday: 0,
      activeUsersToday: 0,
      totalLogins: 0,
      profileUpdatesToday: 0,
      lastUpdated: DateTime.now(),
    );
  }
  
  UserStatistics copyWith({
    int? totalUsers,
    int? newUsersToday,
    int? activeUsersToday,
    int? totalLogins,
    int? profileUpdatesToday,
    Duration? averageSessionDuration,
    DateTime? lastUpdated,
  }) {
    return UserStatistics(
      totalUsers: totalUsers ?? this.totalUsers,
      newUsersToday: newUsersToday ?? this.newUsersToday,
      activeUsersToday: activeUsersToday ?? this.activeUsersToday,
      totalLogins: totalLogins ?? this.totalLogins,
      profileUpdatesToday: profileUpdatesToday ?? this.profileUpdatesToday,
      averageSessionDuration: averageSessionDuration ?? this.averageSessionDuration,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }
  
  Map<String, dynamic> toMap() {
    return {
      'totalUsers': totalUsers,
      'newUsersToday': newUsersToday,
      'activeUsersToday': activeUsersToday,
      'totalLogins': totalLogins,
      'profileUpdatesToday': profileUpdatesToday,
      'averageSessionDurationMs': averageSessionDuration?.inMilliseconds,
      'lastUpdated': lastUpdated.toIso8601String(),
    };
  }
  
  factory UserStatistics.fromMap(Map<String, dynamic> map) {
    return UserStatistics(
      totalUsers: map['totalUsers'] as int,
      newUsersToday: map['newUsersToday'] as int,
      activeUsersToday: map['activeUsersToday'] as int,
      totalLogins: map['totalLogins'] as int,
      profileUpdatesToday: map['profileUpdatesToday'] as int,
      averageSessionDuration: map['averageSessionDurationMs'] != null
          ? Duration(milliseconds: map['averageSessionDurationMs'] as int)
          : null,
      lastUpdated: DateTime.parse(map['lastUpdated'] as String),
    );
  }
  
  @override
  String toString() {
    return 'UserStatistics(totalUsers: $totalUsers, newUsersToday: $newUsersToday, '
           'activeUsersToday: $activeUsersToday, totalLogins: $totalLogins, '
           'profileUpdatesToday: $profileUpdatesToday, '
           'averageSessionDuration: $averageSessionDuration, lastUpdated: $lastUpdated)';
  }
}

/// Example user events for the projection
class UserRegisteredEvent extends Event with AggregateEvent, SerializableEvent {
  final String userId;
  final String email;
  final String username;
  
  UserRegisteredEvent({
    required this.userId,
    required this.email,
    required this.username,
  });
  
  @override
  String get aggregateId => userId;
  
  @override
  String get aggregateType => 'User';
  
  @override
  Map<String, dynamic> getEventData() {
    return {
      'userId': userId,
      'email': email,
      'username': username,
    };
  }
}

class UserLoginEvent extends Event with AggregateEvent, SerializableEvent {
  final String userId;
  final String sessionId;
  
  UserLoginEvent({
    required this.userId,
    required this.sessionId,
  });
  
  @override
  String get aggregateId => userId;
  
  @override
  String get aggregateType => 'User';
  
  @override
  Map<String, dynamic> getEventData() {
    return {
      'userId': userId,
      'sessionId': sessionId,
    };
  }
}

class UserLogoutEvent extends Event with AggregateEvent, SerializableEvent {
  final String userId;
  final String sessionId;
  final DateTime loginTime;
  
  UserLogoutEvent({
    required this.userId,
    required this.sessionId,
    required this.loginTime,
  });
  
  @override
  String get aggregateId => userId;
  
  @override
  String get aggregateType => 'User';
  
  @override
  Map<String, dynamic> getEventData() {
    return {
      'userId': userId,
      'sessionId': sessionId,
      'loginTime': loginTime.toIso8601String(),
    };
  }
}

class UserProfileUpdatedEvent extends Event with AggregateEvent, SerializableEvent {
  final String userId;
  final Map<String, dynamic> updatedFields;
  
  UserProfileUpdatedEvent({
    required this.userId,
    required this.updatedFields,
  });
  
  @override
  String get aggregateId => userId;
  
  @override
  String get aggregateType => 'User';
  
  @override
  Map<String, dynamic> getEventData() {
    return {
      'userId': userId,
      'updatedFields': updatedFields,
    };
  }
}
