import 'bet_target.dart';
import 'player_bet.dart';
import 'race_status.dart';
import 'room_member.dart';

class RoomSession {
  const RoomSession({
    required this.roomId,
    required this.roomName,
    required this.members,
    required this.betTargets,
    required this.bets,
    this.raceStatus = RaceStatus.betting,
    this.results = const [],
  });

  final String roomId;
  final String roomName;
  final List<RoomMember> members;
  final List<BetTarget> betTargets;
  final List<PlayerBet> bets;
  final RaceStatus raceStatus;
  final List<String> results; // memberId順の最終順位リスト

  RoomSession copyWith({
    String? roomId,
    String? roomName,
    List<RoomMember>? members,
    List<BetTarget>? betTargets,
    List<PlayerBet>? bets,
    RaceStatus? raceStatus,
    List<String>? results,
  }) {
    return RoomSession(
      roomId: roomId ?? this.roomId,
      roomName: roomName ?? this.roomName,
      members: members ?? this.members,
      betTargets: betTargets ?? this.betTargets,
      bets: bets ?? this.bets,
      raceStatus: raceStatus ?? this.raceStatus,
      results: results ?? this.results,
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
      raceStatus: _raceStatusFromString(json['raceStatus'] as String?),
      results:
          (json['results'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'roomId': roomId,
      'roomName': roomName,
      'members': members.map((member) => member.toJson()).toList(),
      'betTargets': betTargets.map((target) => target.toJson()).toList(),
      'bets': bets.map((bet) => bet.toJson()).toList(),
      'raceStatus': raceStatus.toString(),
      'results': results,
    };
  }

  static RaceStatus _raceStatusFromString(String? value) {
    if (value == null) return RaceStatus.betting;
    return RaceStatus.values.firstWhere(
      (e) => e.toString() == value,
      orElse: () => RaceStatus.betting,
    );
  }
}
