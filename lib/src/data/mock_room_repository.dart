import 'dart:async';

import 'room_repository.dart';
import '../models/bet_target.dart';
import '../models/player_bet.dart';
import '../models/race_status.dart';
import '../models/room_member.dart';
import '../models/room_session.dart';

class MockRoomRepository implements RoomRepository {
  RoomSession? _session;
  StreamController<RoomSession>? _controller;

  @override
  Future<RoomSession> joinRoom({required String userName}) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));

    final isRoomMaster = userName == '管理者';
    final members = <RoomMember>[
      if (!isRoomMaster)
        RoomMember(
          id: 'self',
          name: userName,
          coins: 500,
          isCurrentUser: true,
          role: MemberRole.player,
        ),
      const RoomMember(
          id: 'member-1',
          name: 'Mock Saki',
          coins: 720,
          role: MemberRole.player,
        ),
        const RoomMember(
          id: 'member-2',
          name: 'Mock Taro',
          coins: 430,
          role: MemberRole.player,
        ),
        const RoomMember(
          id: 'member-3',
          name: 'Mock Mina',
          coins: 910,
          role: MemberRole.player,
        ),
    ];

    final session = RoomSession(
      roomId: 'mock-room-001',
      roomName: 'Mock Room',
      members: members,
      betTargets: const [
        BetTarget(
          id: 'target-1',
          name: 'Red Phoenix',
          winRate: 0.42,
          odds: 2.1,
        ),
        BetTarget(id: 'target-2', name: 'Blue Nova', winRate: 0.28, odds: 3.8),
        BetTarget(
          id: 'target-3',
          name: 'Golden Tide',
          winRate: 0.18,
          odds: 5.2,
        ),
        BetTarget(
          id: 'target-4',
          name: 'Silver Fang',
          winRate: 0.12,
          odds: 7.4,
        ),
      ],
      bets: const [
        PlayerBet(memberId: 'member-1', targetId: 'target-1', amount: 120),
        PlayerBet(memberId: 'member-1', targetId: 'target-3', amount: 80),
        PlayerBet(memberId: 'member-2', targetId: 'target-2', amount: 150),
        PlayerBet(memberId: 'member-3', targetId: 'target-4', amount: 300),
      ],
    );

    _session = session;
    _controller?.close();
    _controller = StreamController<RoomSession>.broadcast();
    _controller!.add(session);
    return session;
  }

  @override
  Stream<RoomSession> watchRoom(String roomId) {
    final controller = _controller;
    final session = _session;
    if (controller == null || session == null || session.roomId != roomId) {
      return const Stream<RoomSession>.empty();
    }

    return controller.stream;
  }

  @override
  Future<RoomSession> submitBet({
    required String roomId,
    required String memberId,
    required String targetId,
    required int amount,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 150));

    final session = _session;
    final controller = _controller;
    if (session == null || controller == null || session.roomId != roomId) {
      throw StateError('Room session is not initialized.');
    }

    final nextBets = [...session.bets];
    final index = nextBets.indexWhere(
      (bet) => bet.memberId == memberId && bet.targetId == targetId,
    );

    if (index == -1) {
      nextBets.add(
        PlayerBet(memberId: memberId, targetId: targetId, amount: amount),
      );
    } else {
      nextBets[index] = nextBets[index].copyWith(amount: amount);
    }

    final nextSession = session.copyWith(bets: nextBets);
    _session = nextSession;
    controller.add(nextSession);
    return nextSession;
  }

  @override
  Future<RoomSession> updateRaceStatus({
    required String roomId,
    required RaceStatus status,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 150));

    final session = _session;
    final controller = _controller;
    if (session == null || controller == null || session.roomId != roomId) {
      throw StateError('Room session is not initialized.');
    }

    final nextSession = session.copyWith(raceStatus: status);
    _session = nextSession;
    controller.add(nextSession);
    return nextSession;
  }

  @override
  Future<RoomSession> addBetTarget({
    required String roomId,
    required String targetName,
    required double odds,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 150));

    final session = _session;
    final controller = _controller;
    if (session == null || controller == null || session.roomId != roomId) {
      throw StateError('Room session is not initialized.');
    }

    final newTarget = BetTarget(
      id: 'target-${DateTime.now().millisecondsSinceEpoch}',
      name: targetName,
      winRate: 0.5,
      odds: odds,
    );

    final nextBetTargets = [...session.betTargets, newTarget];
    final nextSession = session.copyWith(betTargets: nextBetTargets);
    _session = nextSession;
    controller.add(nextSession);
    return nextSession;
  }

  @override
  Future<RoomSession> submitRaceResults({
    required String roomId,
    required List<String> memberIds,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 150));

    final session = _session;
    final controller = _controller;
    if (session == null || controller == null || session.roomId != roomId) {
      throw StateError('Room session is not initialized.');
    }

    final nextSession = session.copyWith(
      raceStatus: RaceStatus.finished,
      results: memberIds,
    );
    _session = nextSession;
    controller.add(nextSession);
    return nextSession;
  }

  @override
  Future<void> dispose() async {
    await _controller?.close();
  }
}
