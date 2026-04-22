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

  factory RoomSession.fromJson(Map<String, dynamic> json) {
    return RoomSession(
      roomId: json['roomId'] as String,
      roomName: json['roomName'] as String,
      members: (json['members'] as List<dynamic>)
          .map((member) => RoomMember.fromJson(member as Map<String, dynamic>))
          .toList(),
      betTargets: (json['betTargets'] as List<dynamic>)
          .map((target) => BetTarget.fromJson(target as Map<String, dynamic>))
          .toList(),
      bets: (json['bets'] as List<dynamic>)
          .map((bet) => PlayerBet.fromJson(bet as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'roomId': roomId,
      'roomName': roomName,
      'members': members.map((member) => member.toJson()).toList(),
      'betTargets': betTargets.map((target) => target.toJson()).toList(),
      'bets': bets.map((bet) => bet.toJson()).toList(),
    };
  }
}
