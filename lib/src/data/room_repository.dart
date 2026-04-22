import '../models/room_session.dart';

abstract class RoomRepository {
  Future<RoomSession> joinRoom({required String userName});

  Stream<RoomSession> watchRoom(String roomId);

  Future<RoomSession> submitBet({
    required String roomId,
    required String memberId,
    required String targetId,
    required int amount,
  });

  Future<void> dispose() async {}
}

class RoomJoinException implements Exception {
  const RoomJoinException(this.message);

  final String message;

  @override
  String toString() => message;
}
