import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../domain/repositories/session_repository.dart';

// Events
abstract class SessionEvent extends Equatable {
  const SessionEvent();
  @override
  List<Object?> get props => [];
}

class LoadSessions extends SessionEvent {}

class CreateSessionRequested extends SessionEvent {
  final String title;
  final String description;
  final Map<String, dynamic> settings;

  const CreateSessionRequested({
    required this.title,
    required this.description,
    required this.settings,
  });

  @override
  List<Object?> get props => [title, description, settings];
}

class JoinSessionRequested extends SessionEvent {
  final String accessCode;
  final String deviceId;
  final String? name;
  final bool isAnonymous;

  const JoinSessionRequested({
    required this.accessCode,
    required this.deviceId,
    this.name,
    required this.isAnonymous,
  });

  @override
  List<Object?> get props => [accessCode, deviceId, name, isAnonymous];
}

class VerifySessionCodeRequested extends SessionEvent {
  final String accessCode;

  const VerifySessionCodeRequested({required this.accessCode});

  @override
  List<Object?> get props => [accessCode];
}

class UpdateSessionRequested extends SessionEvent {
  final String sessionId;
  final Map<String, dynamic> body;

  const UpdateSessionRequested(this.sessionId, this.body);

  @override
  List<Object?> get props => [sessionId, body];
}

class DeleteSessionRequested extends SessionEvent {
  final String sessionId;

  const DeleteSessionRequested(this.sessionId);

  @override
  List<Object?> get props => [sessionId];
}

// States
abstract class SessionState extends Equatable {
  const SessionState();
  @override
  List<Object?> get props => [];
}

class SessionInitial extends SessionState {}
class SessionLoading extends SessionState {}
class SessionsLoaded extends SessionState {
  final List<Map<String, dynamic>> sessions;
  const SessionsLoaded(this.sessions);
  @override
  List<Object?> get props => [sessions];
}
class SessionCreateSuccess extends SessionState {
  final Map<String, dynamic> session;
  const SessionCreateSuccess(this.session);
  @override
  List<Object?> get props => [session];
}
class SessionJoinSuccess extends SessionState {
  final Map<String, dynamic> session;
  final Map<String, dynamic> participant;

  const SessionJoinSuccess(this.session, this.participant);

  @override
  List<Object?> get props => [session, participant];
}

class SessionVerifySuccess extends SessionState {
  final Map<String, dynamic> session;

  const SessionVerifySuccess(this.session);

  @override
  List<Object?> get props => [session];
}

class SessionFailure extends SessionState {
  final String message;
  const SessionFailure(this.message);
  @override
  List<Object?> get props => [message];
}

// BLoC
class SessionBloc extends Bloc<SessionEvent, SessionState> {
  final SessionRepository sessionRepository;

  SessionBloc(this.sessionRepository) : super(SessionInitial()) {
    on<LoadSessions>(_onLoadSessions);
    on<CreateSessionRequested>(_onCreateSessionRequested);
    on<JoinSessionRequested>(_onJoinSessionRequested);
    on<VerifySessionCodeRequested>(_onVerifySessionCodeRequested);
    on<UpdateSessionRequested>(_onUpdateSessionRequested);
    on<DeleteSessionRequested>(_onDeleteSessionRequested);
  }

  Future<void> _onLoadSessions(LoadSessions event, Emitter<SessionState> emit) async {
    emit(SessionLoading());
    try {
      final list = await sessionRepository.getSessions();
      emit(SessionsLoaded(list));
    } catch (e) {
      emit(SessionFailure(e.toString().replaceAll('Exception: ', '')));
    }
  }

  Future<void> _onCreateSessionRequested(CreateSessionRequested event, Emitter<SessionState> emit) async {
    emit(SessionLoading());
    try {
      final session = await sessionRepository.createSession(
        event.title,
        event.description,
        event.settings,
      );
      emit(SessionCreateSuccess(session));
    } catch (e) {
      emit(SessionFailure(e.toString().replaceAll('Exception: ', '')));
    }
  }

  Future<void> _onJoinSessionRequested(JoinSessionRequested event, Emitter<SessionState> emit) async {
    emit(SessionLoading());
    try {
      final data = await sessionRepository.joinSessionByCode(
        event.accessCode,
        event.deviceId,
        event.name,
        event.isAnonymous,
      );
      final session = Map<String, dynamic>.from(data['session'] as Map);
      final participant = Map<String, dynamic>.from(data['participant'] as Map);
      emit(SessionJoinSuccess(session, participant));
    } catch (e) {
      emit(SessionFailure(e.toString().replaceAll('Exception: ', '')));
    }
  }

  Future<void> _onVerifySessionCodeRequested(VerifySessionCodeRequested event, Emitter<SessionState> emit) async {
    emit(SessionLoading());
    try {
      final session = await sessionRepository.verifySessionCode(event.accessCode);
      emit(SessionVerifySuccess(session));
    } catch (e) {
      emit(SessionFailure(e.toString().replaceAll('Exception: ', '')));
    }
  }

  Future<void> _onUpdateSessionRequested(UpdateSessionRequested event, Emitter<SessionState> emit) async {
    try {
      await sessionRepository.updateSession(event.sessionId, event.body);
      add(LoadSessions());
    } catch (e) {
      emit(SessionFailure(e.toString().replaceAll('Exception: ', '')));
    }
  }

  Future<void> _onDeleteSessionRequested(DeleteSessionRequested event, Emitter<SessionState> emit) async {
    try {
      await sessionRepository.deleteSession(event.sessionId);
      add(LoadSessions());
    } catch (e) {
      emit(SessionFailure(e.toString().replaceAll('Exception: ', '')));
    }
  }
}
