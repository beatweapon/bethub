class PlayerBet {
  const PlayerBet({
    required this.memberId,
    required this.targetId,
    required this.amount,
  });

  final String memberId;
  final String targetId;
  final int amount;

  PlayerBet copyWith({
    String? memberId,
    String? targetId,
    int? amount,
  }) {
    return PlayerBet(
      memberId: memberId ?? this.memberId,
      targetId: targetId ?? this.targetId,
      amount: amount ?? this.amount,
    );
  }
}
