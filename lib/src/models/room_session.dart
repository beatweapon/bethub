import 'bet_target.dart';
import 'player_bet.dart';
import 'room_member.dart';

class RoomSession {
  const RoomSession({
    required this.roomId,
    required this.roomName,
    required this.members,
    required this.betTargets,
    required this.bets,
  });

  final String roomId;
  final String roomName;
  final List<RoomMember> members;
  final List<BetTarget> betTargets;
  final List<PlayerBet> bets;

  RoomSession copyWith({
    String? roomId,
    String? roomName,
    List<RoomMember>? members,
    List<BetTarget>? betTargets,
    List<PlayerBet>? bets,
  }) {
    return RoomSession(
      roomId: roomId ?? this.roomId,
      roomName: roomName ?? this.roomName,
      members: members ?? this.members,
      betTargets: betTargets ?? this.betTargets,
      bets: bets ?? this.bets,
    );
  }
}
