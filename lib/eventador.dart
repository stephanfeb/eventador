/// Eventador - Persistence & Event Sourcing Extension for Dactor
/// 
/// Industrial-grade event sourcing platform with hybrid architecture combining:
/// - Dactor: High-performance actor model, supervision, and messaging
/// - Isar: Direct permanent event storage for immutable event logs  
/// - DuraQ: Operational workflows for sagas, projections, and command processing
library eventador;

// Core event sourcing abstractions
export 'src/command.dart';
export 'src/event.dart';
export 'src/persistent_actor.dart';

// Phase 2: Event sourcing patterns
export 'src/state.dart';
export 'src/command_handler.dart';
export 'src/event_handler.dart';
export 'src/aggregate_root.dart';

// Storage layer
export 'src/storage/event_store.dart';
export 'src/storage/event_envelope.dart';
export 'src/storage/snapshot_envelope.dart';
export 'src/storage/cbor_serializer.dart';

// Phase 2 Week 6: Snapshot system
export 'src/snapshot_config.dart';
export 'src/snapshot_manager.dart';

// Legacy export (will be removed in Phase 1 Week 2)
export 'src/eventador_base.dart';

// Phase 3: Sagas
export 'src/saga/saga.dart';
export 'src/saga/saga_state.dart';
export 'src/saga/saga_coordinator.dart';
export 'src/saga/saga_command_envelope.dart';
export 'src/saga/saga_state_envelope.dart';
export 'src/saga/saga_timeout.dart';

// Phase 3 Week 8: Projections
export 'src/projection/projection.dart';
export 'src/projection/projection_checkpoint.dart';
export 'src/projection/projection_read_model.dart';
export 'src/projection/projection_actor.dart';
export 'src/projection/projection_manager.dart';
export 'src/projection/user_statistics_projection.dart';
