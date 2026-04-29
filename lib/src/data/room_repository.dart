import '../models/race_status.dart';
import '../models/room_session.dart';

abstract class RoomRepository {
  Future<void> prewarmServer() async {}

  Future<RoomSession> joinRoom({required String userName});

  Stream<RoomSession> watchRoom(String roomId);

  Future<RoomSession> submitBet({
    required String roomId,
    required String memberId,
    required String targetId,
    required int amount,
  });

  // Room master methods
  Future<RoomSession> updateRaceStatus({
    required String roomId,
    required RaceStatus status,
  });

  Future<RoomSession> addBetTarget({
    required String roomId,
    required String targetName,
  });

  Future<RoomSession> submitRaceResults({
    required String roomId,
    required List<String> betTargetIds,
  });

  Future<void> dispose() async {}
}

class RoomJoinException implements Exception {
  const RoomJoinException(this.message);

  final String message;

  @override
  String toString() => message;
}
