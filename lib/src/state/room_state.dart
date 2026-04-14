import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/mock_room_repository.dart';
import '../models/room_member.dart';
import '../models/room_session.dart';

class RoomState extends ChangeNotifier {
  RoomState({required MockRoomRepository repository}) : _repository = repository;

  final MockRoomRepository _repository;

  RoomSession? _session;
  bool _isJoining = false;
  bool _isSubmittingBet = false;
  StreamSubscription<RoomSession>? _roomSubscription;

  RoomSession? get session => _session;
  bool get isJoining => _isJoining;
  bool get isSubmittingBet => _isSubmittingBet;

  RoomMember? get currentUser {
    final session = _session;
    if (session == null) {
      return null;
    }

    for (final member in session.members) {
      if (member.isCurrentUser) {
        return member;
      }
    }

    return null;
  }

  Future<void> joinRoom(String userName) async {
    if (_isJoining) {
      return;
    }

    _isJoining = true;
    notifyListeners();

    try {
      final joinedSession = await _repository.joinRoom(userName: userName);
      _session = joinedSession;
      await _roomSubscription?.cancel();
      _roomSubscription = _repository.watchRoom(joinedSession.roomId).listen((
        nextSession,
      ) {
        _session = nextSession;
        notifyListeners();
      });
    } finally {
      _isJoining = false;
      notifyListeners();
    }
  }

  int betAmountFor({
    required String memberId,
    required String targetId,
  }) {
    final session = _session;
    if (session == null) {
      return 0;
    }

    for (final bet in session.bets) {
      if (bet.memberId == memberId && bet.targetId == targetId) {
        return bet.amount;
      }
    }

    return 0;
  }

  int totalBetCoinsFor(String memberId) {
    final session = _session;
    if (session == null) {
      return 0;
    }

    var total = 0;
    for (final bet in session.bets) {
      if (bet.memberId == memberId) {
        total += bet.amount;
      }
    }

    return total;
  }

  Future<int> submitBet({
    required String targetId,
    required int requestedAmount,
  }) async {
    final session = _session;
    final currentUser = this.currentUser;
    if (session == null || currentUser == null) {
      return 0;
    }

    final currentAmount = betAmountFor(
      memberId: currentUser.id,
      targetId: targetId,
    );
    if (requestedAmount < currentAmount) {
      return currentAmount;
    }

    final totalBet = totalBetCoinsFor(currentUser.id);
    final remainingCoins = currentUser.coins - totalBet;
    final maxAllowedAmount = currentAmount + remainingCoins;
    final nextAmount = requestedAmount.clamp(currentAmount, maxAllowedAmount);

    if (nextAmount == currentAmount) {
      return currentAmount;
    }

    _isSubmittingBet = true;
    notifyListeners();

    try {
      final nextSession = await _repository.submitBet(
        roomId: session.roomId,
        memberId: currentUser.id,
        targetId: targetId,
        amount: nextAmount,
      );
      _session = nextSession;
      return nextAmount;
    } finally {
      _isSubmittingBet = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _roomSubscription?.cancel();
    super.dispose();
  }
}
